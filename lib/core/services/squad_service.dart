import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/plea_message_model.dart';
import '../models/user_model.dart';
import '../models/plea_model.dart';
import '../models/squad_log_model.dart';
import 'scoring_service.dart';

class SquadService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  /// Helper to generate a 6-character alphanumeric squad code.
  static String _generateSquadCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final code = String.fromCharCodes(
      Iterable.generate(
        3,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
    return 'REV-$code';
  }

  /// Creates a new squad for the user.
  /// Uses transaction.set with merge to prevent "Permission Denied" if the user doc is missing.
  static Future<void> createSquad(String uid) async {
    final squadCode = _generateSquadCode();
    final squadRef = _firestore.collection('squads').doc();
    final userRef = _firestore.collection('users').doc(uid);

    return _firestore.runTransaction((transaction) async {
      // 1. Create the Squad document
      transaction.set(squadRef, {
        'squadCode': squadCode,
        'creatorId': uid,
        'memberIds': [uid],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Update the User document (using set + merge to ensure it exists)
      transaction.set(userRef, {
        'squadId': squadRef.id,
        'squadCode': squadCode,
      }, SetOptions(merge: true));
    });
  }

  /// Joins an existing squad using a 6-digit (REV-XXX) code.
  /// Updates both the /squads document and the user's /users document atomically.
  static Future<void> joinSquad(String uid, String squadCode) async {
    final normalizedCode = squadCode.toUpperCase().trim();
    // 1. Find the squad by code
    final querySnapshot = await _firestore
        .collection('squads')
        .where('squadCode', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('SQUAD NOT FOUND: Check the code and try again.');
    }

    final squadDoc = querySnapshot.docs.first;
    final squadRef = squadDoc.reference;
    final userRef = _firestore.collection('users').doc(uid);

    return _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final freshSquadSnapshot = await transaction.get(squadRef);
      final memberIds = List<String>.from(
        freshSquadSnapshot.get('memberIds') as List,
      );

      final oldSquadId = userSnapshot.data()?['squadId'] as String?;
      if (oldSquadId != null &&
          oldSquadId.isNotEmpty &&
          oldSquadId != squadRef.id) {
        final oldSquadRef = _firestore.collection('squads').doc(oldSquadId);
        final oldSquadSnapshot = await transaction.get(oldSquadRef);

        if (oldSquadSnapshot.exists) {
          final oldMemberIds = List<String>.from(
            oldSquadSnapshot.get('memberIds') as List,
          );
          oldMemberIds.remove(uid);
          final shouldDeleteOldSquad = oldMemberIds.isEmpty;
          if (shouldDeleteOldSquad) {
            transaction.delete(oldSquadRef);
          } else {
            transaction.update(oldSquadRef, {'memberIds': oldMemberIds});
          }
        }
      }

      if (!memberIds.contains(uid)) {
        memberIds.add(uid);
      }

      // 2. Update the Squad document
      transaction.update(squadRef, {'memberIds': memberIds});

      // 3. Update the User document
      transaction.update(userRef, {
        'squadId': squadRef.id,
        'squadCode': normalizedCode,
      });
    });
  }

  /// Returns a stream of users who are members of the same squad.
  static Stream<List<UserModel>> getSquadMembersStream(String squadId) {
    return _firestore
        .collection('users')
        .where('squadId', isEqualTo: squadId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserModel.fromJson(doc.data()))
              .toList();
        });
  }

  /// Creates a new emergency unlock plea.
  static Future<String> createPlea({
    required String uid,
    required String userName,
    required String squadId,
    required String appName,
    required String packageName,
    required int durationMinutes,
    required String reason,
  }) async {
    final callable = _functions.httpsCallable('createPlea');
    final response = await callable.call({
      'uid': uid,
      'appName': appName,
      'packageName': packageName,
      'durationMinutes': durationMinutes,
      'reason': reason,
    });

    final data = Map<String, dynamic>.from(response.data as Map? ?? const {});
    final pleaId = (data['pleaId'] as String?)?.trim();
    if (pleaId == null || pleaId.isEmpty) {
      throw Exception('INVALID_PLEA_ID');
    }

    await ScoringService.applyBeggarsTax(uid);
    return pleaId;
  }

  /// Submits a vote choice for a plea.
  /// Verdict resolution is handled server-side by Cloud Functions.
  static Future<void> voteOnPlea(
    String pleaId,
    String voterUid,
    bool vote,
  ) async {
    final voteChoice = vote ? 'accept' : 'reject';
    return voteOnPleaChoice(pleaId, voterUid, voteChoice);
  }

  static Future<void> voteOnPleaChoice(
    String pleaId,
    String voterUid,
    String voteChoice,
  ) async {
    final normalizedVote = voteChoice.trim().toLowerCase();
    if (normalizedVote != 'accept' && normalizedVote != 'reject') {
      throw Exception('INVALID VOTE');
    }

    final currentUid = voterUid.trim();
    if (currentUid.isEmpty) {
      throw Exception('INVALID_VOTER_UID');
    }

    final callable = _functions.httpsCallable('castVote');
    await callable.call({
      'pleaId': pleaId,
      'choice': normalizedVote,
    });
  }

  /// Returns a stream of approved pleas for a specific user.
  static Stream<List<PleaModel>> getUserApprovedPleasStream(String uid) {
    return _firestore
        .collection('pleas')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PleaModel.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  /// Returns a stream of active pleas for a squad.
  static Stream<List<PleaModel>> getActivePleasStream(String squadId) {
    final normalizedSquadId = squadId.trim();
    if (normalizedSquadId.isEmpty) {
      print(
        'PLEA_DEBUG: getActivePleasStream called with empty squadId. Returning empty stream.',
      );
      return Stream.value(const <PleaModel>[]);
    }

    print(
      'PLEA_DEBUG: Listening for active pleas in squadId=$normalizedSquadId',
    );

    return _firestore
        .collection('pleas')
        .where('squadId', isEqualTo: normalizedSquadId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          for (final change in snapshot.docChanges) {
            final data = change.doc.data();
            final changedSquadId = data?['squadId'];
            final changedUserId = data?['userId'];
            final changedStatus = data?['status'];
            print(
              'PLEA_DEBUG: ${change.type.name.toUpperCase()} plea=${change.doc.id} squadId=$changedSquadId userId=$changedUserId status=$changedStatus',
            );
          }

          print(
            'PLEA_DEBUG: Active plea snapshot for squadId=$normalizedSquadId count=${snapshot.docs.length}',
          );

          return snapshot.docs
              .map((doc) => PleaModel.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  static Stream<PleaModel?> getPleaStream(String pleaId) {
    final normalizedPleaId = pleaId.trim();
    if (normalizedPleaId.isEmpty) return Stream.value(null);

    return _firestore.collection('pleas').doc(normalizedPleaId).snapshots().map(
      (snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return PleaModel.fromJson(snapshot.data()!, snapshot.id);
      },
    );
  }

  static Future<void> joinPleaSession(String pleaId, String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;
    final callable = _functions.httpsCallable('joinPleaSession');
    await callable.call({'pleaId': pleaId});
  }

  static Future<String> sendPleaMessage({
    required String pleaId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw Exception('MESSAGE CANNOT BE EMPTY.');
    }

    // Server-authoritative message send (anti-spam enforced in callable).
    final callable = _functions.httpsCallable('sendPleaMessage');
    final response = await callable.call({
      'pleaId': pleaId,
      'text': normalizedText,
    });

    final data = Map<String, dynamic>.from(response.data as Map? ?? const {});
    final messageId = (data['messageId'] as String?)?.trim();
    if (messageId == null || messageId.isEmpty) {
      throw Exception('INVALID_MESSAGE_ID');
    }
    return messageId;
  }

  static Future<void> markPleaForDeletion(String pleaId) async {
    final normalizedPleaId = pleaId.trim();
    if (normalizedPleaId.isEmpty) return;
    final callable = _functions.httpsCallable('markPleaForDeletion');
    await callable.call({'pleaId': normalizedPleaId});
  }

  static Stream<List<PleaMessageModel>> getPleaMessagesStream(String pleaId) {
    return _firestore
        .collection('pleas')
        .doc(pleaId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PleaMessageModel.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  static Stream<List<SquadLogModel>> getSquadLogs(String squadId) {
    final normalizedSquadId = squadId.trim();
    if (normalizedSquadId.isEmpty) {
      return Stream.value(const <SquadLogModel>[]);
    }

    return _firestore
        .collection('squads')
        .doc(normalizedSquadId)
        .collection('logs')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SquadLogModel.fromFirestore(doc))
              .toList(),
        );
  }

  static Future<void> castStone(String userId, String squadId) async {
    final targetUserId = userId.trim();
    final normalizedSquadId = squadId.trim();
    if (targetUserId.isEmpty || normalizedSquadId.isEmpty) {
      throw Exception('INVALID_ARGUMENTS');
    }
    final callable = _functions.httpsCallable('castStone');
    await callable.call({
      'targetUserId': targetUserId,
      'squadId': normalizedSquadId,
    });
  }

  static Future<void> prayForUser(String userId, String squadId) async {
    final targetUserId = userId.trim();
    final normalizedSquadId = squadId.trim();
    if (targetUserId.isEmpty || normalizedSquadId.isEmpty) {
      throw Exception('INVALID_ARGUMENTS');
    }
    final callable = _functions.httpsCallable('prayFor');
    await callable.call({
      'targetUserId': targetUserId,
      'squadId': normalizedSquadId,
    });
  }

  static Future<void> postBail(String userId, String squadId) async {
    final targetUserId = userId.trim();
    final normalizedSquadId = squadId.trim();
    if (targetUserId.isEmpty || normalizedSquadId.isEmpty) {
      throw Exception('INVALID_ARGUMENTS');
    }
    final callable = _functions.httpsCallable('postBail');
    await callable.call({
      'targetUserId': targetUserId,
      'squadId': normalizedSquadId,
    });
  }

  /// Removes a user from their squad.
  static Future<void> leaveSquad(String uid, String squadId) async {
    final squadRef = _firestore.collection('squads').doc(squadId);

    return _firestore.runTransaction((transaction) async {
      final freshSquadSnapshot = await transaction.get(squadRef);
      if (!freshSquadSnapshot.exists) return;

      final memberIds = List<String>.from(
        freshSquadSnapshot.get('memberIds') as List,
      );

      memberIds.remove(uid);

      if (memberIds.isEmpty) {
        transaction.delete(squadRef);
      } else {
        transaction.update(squadRef, {'memberIds': memberIds});
      }
    });
  }
}
