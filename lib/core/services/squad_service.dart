import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/plea_message_model.dart';
import '../models/user_model.dart';
import '../models/plea_model.dart';
import '../models/squad_log_model.dart';
import '../models/member_rap_sheet_snapshot.dart';
import 'scoring_service.dart';

class PleaNoSquadException implements Exception {
  final String message;

  const PleaNoSquadException([
    this.message = 'Join or create a squad before sending tribunal requests.',
  ]);

  @override
  String toString() => message;
}

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
        'joinCode': squadCode,
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

  /// Joins an existing squad via a secure callable using a 6-digit (REV-XXX) code.
  static Future<String> joinSquad(String squadCode) async {
    final normalizedCode = squadCode.toUpperCase().trim();
    if (normalizedCode.isEmpty) {
      throw Exception('INVALID SQUAD CODE');
    }

    final callable = _functions.httpsCallable('joinSquadByCode');
    try {
      final response = await callable.call({'squadCode': normalizedCode});
      final data = Map<String, dynamic>.from(response.data as Map? ?? const {});
      final squadId = (data['squadId'] as String?)?.trim();
      if (squadId == null || squadId.isEmpty) {
        throw Exception('INVALID_SQUAD_ID');
      }
      return squadId;
    } on FirebaseFunctionsException catch (error) {
      final message = (error.message ?? '').trim();
      if (error.code == 'not-found') {
        throw Exception(message.isEmpty ? 'Invalid squad code' : message);
      }
      if (error.code == 'unauthenticated') {
        throw Exception(
          message.isEmpty ? 'Sign in before joining a squad.' : message,
        );
      }
      throw Exception(
        message.isEmpty ? 'Failed to join squad. Please try again.' : message,
      );
    }
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
    HttpsCallableResult<dynamic> response;
    try {
      response = await callable.call({
        'uid': uid,
        'appName': appName,
        'packageName': packageName,
        'durationMinutes': durationMinutes,
        'reason': reason,
      });
    } on FirebaseFunctionsException catch (error) {
      final reasonCode = _extractReasonCode(error.details);
      final message = (error.message ?? '').trim().toLowerCase();
      final noSquad =
          (error.code == 'failed-precondition' && reasonCode == 'NO_SQUAD') ||
          message.contains('not in a squad');
      if (noSquad) {
        throw const PleaNoSquadException();
      }
      rethrow;
    }

    final data = Map<String, dynamic>.from(response.data as Map? ?? const {});
    final pleaId = (data['pleaId'] as String?)?.trim();
    if (pleaId == null || pleaId.isEmpty) {
      throw Exception('INVALID_PLEA_ID');
    }

    await ScoringService.applyBeggarsTax(uid);
    return pleaId;
  }

  static String? _extractReasonCode(dynamic details) {
    if (details is! Map) return null;
    final normalized = Map<String, dynamic>.from(details);
    final raw = normalized['reasonCode']?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return raw.toUpperCase();
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
    await callable.call({'pleaId': pleaId, 'choice': normalizedVote});
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
      return Stream.value(const <PleaModel>[]);
    }

    return _firestore
        .collection('pleas')
        .where('squadId', isEqualTo: normalizedSquadId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
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

  static Future<MemberRapSheetSnapshot?> getMemberRapSheetSnapshot(
    String targetUid,
  ) async {
    final normalizedTargetUid = targetUid.trim();
    if (normalizedTargetUid.isEmpty) return null;

    final callable = _functions.httpsCallable('getMemberRapSheetSnapshot');
    final response = await callable.call({'targetUid': normalizedTargetUid});
    final data = Map<String, dynamic>.from(response.data as Map? ?? const {});
    final snapshotRaw = data['snapshot'];
    if (snapshotRaw is! Map) return null;
    final snapshotMap = Map<String, dynamic>.from(snapshotRaw);
    return MemberRapSheetSnapshot.fromMap(snapshotMap);
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

  static Future<void> saluteSquadLog({
    required String squadId,
    required String logId,
  }) async {
    final normalizedSquadId = squadId.trim();
    final normalizedLogId = logId.trim();
    if (normalizedSquadId.isEmpty || normalizedLogId.isEmpty) {
      throw Exception('INVALID_ARGUMENTS');
    }

    final callable = _functions.httpsCallable('saluteSquadLog');
    await callable.call({
      'squadId': normalizedSquadId,
      'logId': normalizedLogId,
    });
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
    final userRef = _firestore.collection('users').doc(uid);

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

      transaction.update(userRef, {'squadId': null, 'squadCode': null});
    });
  }
}
