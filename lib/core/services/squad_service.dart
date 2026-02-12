import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/plea_message_model.dart';
import '../models/user_model.dart';
import '../models/plea_model.dart';
import 'scoring_service.dart';

class SquadService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    // 1. Find the squad by code
    final querySnapshot = await _firestore
        .collection('squads')
        .where('squadCode', isEqualTo: squadCode.toUpperCase().trim())
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
          final shouldDeleteOldSquad =
              oldMemberIds.length == 1 && oldMemberIds.contains(uid);
          if (shouldDeleteOldSquad) {
            transaction.delete(oldSquadRef);
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
        'squadCode': squadCode.toUpperCase().trim(),
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
    final docRef = _firestore.collection('pleas').doc();
    await docRef.set({
      'userId': uid,
      'userName': userName,
      'squadId': squadId,
      'appName': appName,
      'packageName': packageName,
      'durationMinutes': durationMinutes,
      'reason': reason,
      'participants': [],
      'voteCounts': {'accept': 0, 'reject': 0},
      'votes': {},
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await ScoringService.applyBeggarsTax(uid);
    return docRef.id;
  }

  /// Votes on a plea and updates status if majority reached.
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

    final pleaRef = _firestore.collection('pleas').doc(pleaId);
    String? requesterUid;
    String? finalStatus;

    return _firestore
        .runTransaction((transaction) async {
          final pleaSnap = await transaction.get(pleaRef);
          if (!pleaSnap.exists) throw Exception("PLEA NOT FOUND.");

          final pleaData = pleaSnap.data() ?? <String, dynamic>{};
          requesterUid = pleaSnap.get('userId') as String;
          final participants =
              List<String>.from(pleaData['participants'] as List? ?? const [])
                  .map((uid) => uid.trim())
                  .where((uid) => uid.isNotEmpty)
                  .toSet()
                  .toList();
          final rawVotes = Map<String, dynamic>.from(
            pleaData['votes'] as Map? ?? const {},
          );
          final votes = <String, String>{};
          rawVotes.forEach((uid, rawVote) {
            if (rawVote is bool) {
              votes[uid] = rawVote ? 'accept' : 'reject';
              return;
            }
            if (rawVote is String) {
              final normalized = rawVote.trim().toLowerCase();
              if (normalized == 'accept' || normalized == 'reject') {
                votes[uid] = normalized;
              }
            }
          });

          if (!participants.contains(voterUid)) {
            participants.add(voterUid);
          }

          votes[voterUid] = normalizedVote;

          votes.removeWhere((uid, _) => !participants.contains(uid));

          final acceptVotes = participants
              .where((uid) => votes[uid] == 'accept')
              .length;
          final rejectVotes = participants
              .where((uid) => votes[uid] == 'reject')
              .length;
          final allParticipantsVoted =
              participants.isNotEmpty &&
              participants.every((uid) => votes.containsKey(uid));

          final updates = <String, dynamic>{
            'participants': participants,
            'votes': votes,
            'voteCounts': {'accept': acceptVotes, 'reject': rejectVotes},
          };

          // Attendance rule: finalize only when every attendee has voted.
          if (allParticipantsVoted) {
            // Tie-breaker: reject on tie.
            final resolvedStatus = acceptVotes > rejectVotes
                ? 'approved'
                : 'rejected';
            updates['status'] = resolvedStatus;
            updates['resolvedAt'] = FieldValue.serverTimestamp();
            finalStatus = resolvedStatus;
          }

          transaction.update(pleaRef, updates);
        })
        .then((_) async {
          if (requesterUid == null || finalStatus == null) return;

          if (finalStatus == 'rejected') {
            await ScoringService.applyRejectedPleaPenalty(requesterUid!);
          }

          await ScoringService.syncFocusScore(requesterUid!);
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
    await _firestore.collection('pleas').doc(pleaId).set({
      'participants': FieldValue.arrayUnion([normalizedUid]),
    }, SetOptions(merge: true));
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

    final messagesRef = _firestore
        .collection('pleas')
        .doc(pleaId)
        .collection('messages');
    final messageRef = messagesRef.doc();
    await messageRef.set({
      'senderId': senderId,
      'senderName': senderName,
      'text': normalizedText,
      'timestamp': FieldValue.serverTimestamp(),
    });
    return messageRef.id;
  }

  static Future<void> markPleaForDeletion(String pleaId) async {
    final normalizedPleaId = pleaId.trim();
    if (normalizedPleaId.isEmpty) return;
    await _firestore.collection('pleas').doc(normalizedPleaId).set({
      'markedForDeletion': true,
      'deletionMarkedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
