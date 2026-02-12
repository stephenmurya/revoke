import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../app_router.dart';
import 'squad_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static StreamSubscription<String>? _tokenRefreshSub;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static void _redirectToAuthFlow() {
    try {
      AppRouter.router.go('/onboarding');
    } catch (_) {
      // Router might not be ready during app bootstrap; ignore safely.
    }
  }

  static Future<User?> signInWithGoogle() async {
    try {
      print('AUTH_DEBUG: Starting Google Sign In process...');

      await _googleSignIn.initialize(
        serverClientId:
            '70325101052-aae5kl5ie7npv94dqtgrktur0ql1ln01.apps.googleusercontent.com',
      );

      print('AUTH_DEBUG: Triggering authenticate()...');
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .authenticate();

      if (googleUser == null) {
        print(
          'AUTH_DEBUG: googleUser is null (User canceled or configuration error).',
        );
        return null;
      }

      print('AUTH_DEBUG: Authenticated Google user: ${googleUser.email}');
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final String? idToken = googleAuth.idToken;
      if (idToken == null) {
        print(
          'AUTH_DEBUG ERROR: idToken is NULL. Check SHA-1 and Web Client ID in Firebase.',
        );
        throw Exception(
          "ID Token is missing. Verify Firebase configuration and SHA-1.",
        );
      }

      print('AUTH_DEBUG: idToken found. Creating Firebase credential...');
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      print('AUTH_DEBUG: Signing into Firebase with credential...');
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        print('AUTH_DEBUG: Firebase sign-in SUCCESS: ${user.uid}');
        await _ensureUserDocument(user);
      }

      return user;
    } catch (e, stack) {
      print('AUTH_DEBUG EXCEPTION: $e');
      print('AUTH_DEBUG STACK: $stack');
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
          'nickname': user.displayName?.split(' ').first ?? 'Warden',
          'focusScore': 500,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('AUTH_DEBUG ERROR: Failed to ensure user document: $e');
      rethrow;
    }
  }

  static Future<void> initializeMessagingTokenSync() async {
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
    } catch (e) {
      print('AUTH_DEBUG: Failed to sync initial FCM token: $e');
    }

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
      } catch (e) {
        print('AUTH_DEBUG: Failed to sync refreshed FCM token: $e');
      }
    });
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

  static Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  static Future<void> signOut() async {
    _redirectToAuthFlow();
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

    final userData = await getUserData();
    final squadId = userData?['squadId'] as String?;

    // 1. Remove from squad if applicable
    if (squadId != null) {
      await SquadService.leaveSquad(user.uid, squadId);
    }

    // 2. Delete user document
    await _firestore.collection('users').doc(user.uid).delete();

    // 3. Delete from Firebase Auth
    await user.delete();

    // 4. Clean up Google Sign-In
    await signOut();
  }
}
