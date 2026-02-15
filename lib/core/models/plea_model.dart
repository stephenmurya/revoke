import 'package:cloud_firestore/cloud_firestore.dart';

class PleaModel {
  final String id;
  final String userId;
  final String userName;
  final String squadId;
  final String appName;
  final String packageName;
  final int durationMinutes;
  final String reason;
  final List<String> participants;
  final Map<String, int> voteCounts;
  final Map<String, String> votes;
  final String status;
  final DateTime createdAt;

  PleaModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.squadId,
    required this.appName,
    required this.packageName,
    required this.durationMinutes,
    required this.reason,
    required this.participants,
    required this.voteCounts,
    required this.votes,
    required this.status,
    required this.createdAt,
  });

  factory PleaModel.fromJson(Map<String, dynamic> json, String docId) {
    // Be tolerant of partially-written documents (e.g. serverTimestamp fields that are
    // temporarily null in the local snapshot). A model parse error would propagate as
    // a Stream error and can cause UI flicker, focus loss, and "ACCESS DENIED" noise.
    final rawVotes = Map<String, dynamic>.from(json['votes'] as Map? ?? {});
    final normalizedVotes = <String, String>{};
    rawVotes.forEach((uid, vote) {
      if (vote is bool) {
        normalizedVotes[uid] = vote ? 'accept' : 'reject';
      } else if (vote is String) {
        final normalized = vote.trim().toLowerCase();
        if (normalized == 'accept' || normalized == 'reject') {
          normalizedVotes[uid] = normalized;
        }
      }
    });

    final rawVoteCounts = Map<String, dynamic>.from(
      json['voteCounts'] as Map? ?? {},
    );
    final acceptVotes =
        (rawVoteCounts['accept'] as num?)?.toInt() ??
        normalizedVotes.values.where((v) => v == 'accept').length;
    final rejectVotes =
        (rawVoteCounts['reject'] as num?)?.toInt() ??
        normalizedVotes.values.where((v) => v == 'reject').length;

    final createdAtRaw = json['createdAt'];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : DateTime.now();

    return PleaModel(
      id: docId,
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Member',
      squadId: json['squadId'] as String? ?? '',
      appName: json['appName'] as String? ?? 'App',
      packageName: json['packageName'] as String? ?? '',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 5,
      reason: json['reason'] as String? ?? '',
      participants: List<String>.from(
        json['participants'] as List? ?? const [],
      ),
      voteCounts: {'accept': acceptVotes, 'reject': rejectVotes},
      votes: normalizedVotes,
      status: json['status'] as String? ?? 'active',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'squadId': squadId,
      'appName': appName,
      'packageName': packageName,
      'durationMinutes': durationMinutes,
      'reason': reason,
      'participants': participants,
      'voteCounts': voteCounts,
      'votes': votes,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
