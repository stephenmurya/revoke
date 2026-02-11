import 'package:cloud_firestore/cloud_firestore.dart';

enum ScoreTrend { up, down, neutral }

class UserModel {
  final String uid;
  final String? email;
  final String? fullName;
  final String? photoUrl;
  final String? nickname;
  final int focusScore;
  final List<int> scoreHistory;
  final DateTime? createdAt;
  final String? squadId;
  final String? squadCode;

  UserModel({
    required this.uid,
    this.email,
    this.fullName,
    this.photoUrl,
    this.nickname,
    required this.focusScore,
    this.scoreHistory = const [],
    this.createdAt,
    this.squadId,
    this.squadCode,
  });

  ScoreTrend get scoreTrend {
    if (scoreHistory.length < 2) return ScoreTrend.neutral;
    final int prev = scoreHistory[scoreHistory.length - 2];
    final int current = scoreHistory.last;
    if (current > prev) return ScoreTrend.up;
    if (current < prev) return ScoreTrend.down;
    return ScoreTrend.neutral;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final int score = (json['focusScore'] as num?)?.toInt() ?? 500;
    final List<int> history = List<int>.from(
      (json['scoreHistory'] as List?)?.map((e) => (e as num).toInt()) ??
          <int>[score],
    );

    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String?,
      fullName: json['fullName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      nickname: json['nickname'] as String?,
      focusScore: score,
      scoreHistory: history,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      squadId: json['squadId'] as String?,
      squadCode: json['squadCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'photoUrl': photoUrl,
      'nickname': nickname,
      'focusScore': focusScore,
      'scoreHistory': scoreHistory,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'squadId': squadId,
      'squadCode': squadCode,
    };
  }
}
