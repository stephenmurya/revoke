import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../app_router.dart';
import 'squad_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static StreamSubscription<String>? _tokenRefreshSub;
  static const int _deleteBatchSize = 400;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static void _redirectToAuthFlow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        AppRouter.router.go('/onboarding?force_auth=1');
      } catch (_) {
        // Router might not be ready during app bootstrap; ignore safely.
      }
    });
  }

  static Future<User?> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize(
        serverClientId:
            '70325101052-aae5kl5ie7npv94dqtgrktur0ql1ln01.apps.googleusercontent.com',
      );

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final String? idToken = googleAuth.idToken;
      if (idToken == null) {
        throw Exception(
          "ID Token is missing. Verify Firebase configuration and SHA-1.",
        );
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        await _ensureUserDocument(user);
      }

      return user;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> _ensureUserDocument(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final String? token = await FirebaseMessaging.instance.getToken();

      // Use set with SetOptions(merge: true) to:
      // 1. Create the document if it doesn't exist.
      // 2. Update existing data (like photoUrl) if it does.
      // 3. Preserve fields like 'squadId' or 'focusScore' so they aren't reset to null.
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'fullName': user.displayName,
        'photoUrl': user.photoURL,
        'fcmToken': token,
        'lastLogin': FieldValue.serverTimestamp(),
        // Only set these defaults if the document is being created for the first time
        // by using a transaction or checking snapshot, but merge is safer here.
      }, SetOptions(merge: true));

      // 💡 If focusScore or other defaults are missing, we ensure they exist
      final snapshot = await userDoc.get();
      if (!snapshot.exists || snapshot.data()?['focusScore'] == null) {
        await userDoc.set({
          'focusScore': 500,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      rethrow;
    }
  }

  static Future<void> initializeMessagingTokenSync() async {
    _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) async {
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null || token.isEmpty) return;
      try {
        await _firestore.collection('users').doc(refreshedUser.uid).set({
          'fcmToken': token,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    });

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  static Future<void> updateNickname(String nickname) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final normalized = nickname.trim();
    if (normalized.isEmpty) return;

    await _firestore.collection('users').doc(user.uid).update({
      'nickname': normalized,
    });
  }

  static Future<void> updateNotificationPref(String key, bool value) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return;

    await _firestore.collection('users').doc(user.uid).update({
      'notificationPrefs.$normalizedKey': value,
    });
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  static Future<void> signOut() async {
    _redirectToAuthFlow();
    AppRouter.clearSessionCaches();
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
    await _auth.signOut();
  }

  /// Validates if the current session is still valid (user document exists).
  static Future<bool> validateSession() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await signOut();
      return false;
    }
    return true;
  }

  /// Deletes the current user's account and all associated data.
  static Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _redirectToAuthFlow();
    AppRouter.clearSessionCaches();

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    final uid = user.uid;
    final userRef = _firestore.collection('users').doc(uid);

    try {
      final userData = await getUserData();
      final squadId = (userData?['squadId'] as String?)?.trim();

      // 1. Remove from squad if applicable
      if (squadId != null && squadId.isNotEmpty) {
        await SquadService.leaveSquad(uid, squadId);
      }

      // 2. Delete known user sub-collections before removing the root user doc.
      for (final subcollection in const <String>[
        'notifications',
        'scoreEvents',
        'focusStats',
        'regimes',
      ]) {
        await _deleteSubcollection(userRef, subcollection);
      }

      // 3. Delete user document
      await userRef.delete();

      // 4. Delete Firebase Auth user (reauth if required)
      await _deleteAuthUserWithReauth(user);
    } finally {
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
      await _auth.signOut();
    }
  }

  static Future<void> _deleteSubcollection(
    DocumentReference<Map<String, dynamic>> userRef,
    String subcollection,
  ) async {
    while (true) {
      final snapshot = await userRef
          .collection(subcollection)
          .limit(_deleteBatchSize)
          .get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < _deleteBatchSize) return;
    }
  }

  static Future<void> _deleteAuthUserWithReauth(User user) async {
    try {
      await user.delete();
      return;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') {
        rethrow;
      }
    }

    await _googleSignIn.initialize(
      serverClientId:
          '70325101052-aae5kl5ie7npv94dqtgrktur0ql1ln01.apps.googleusercontent.com',
    );

    final googleUser = await _googleSignIn.authenticate();

    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'reauth-failed',
        message: 'Missing Google ID token for re-authentication.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await user.reauthenticateWithCredential(credential);
    await user.delete();
  }
}
