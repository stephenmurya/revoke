import 'package:cloud_firestore/cloud_firestore.dart';

enum ScoreTrend { up, down, neutral }

class UserModel {
  final String uid;
  final String? email;
  final String? fullName;
  final String? photoUrl;
  final String? nickname;
  final String? currentStatus;
  final int focusScore;
  final List<int> scoreHistory;
  final DateTime? createdAt;
  final String? squadId;
  final String? squadCode;
  final Map<String, dynamic> notificationPrefs;

  UserModel({
    required this.uid,
    this.email,
    this.fullName,
    this.photoUrl,
    this.nickname,
    this.currentStatus,
    required this.focusScore,
    this.scoreHistory = const [],
    this.createdAt,
    this.squadId,
    this.squadCode,
    this.notificationPrefs = const <String, dynamic>{},
  });

  ScoreTrend get scoreTrend {
    if (scoreHistory.length < 2) return ScoreTrend.neutral;
    final int prev = scoreHistory[scoreHistory.length - 2];
    final int current = scoreHistory.last;
    if (current > prev) return ScoreTrend.up;
    if (current < prev) return ScoreTrend.down;
    return ScoreTrend.neutral;
  }

  bool get wantsShameAlerts => notificationPrefs['shameAlerts'] != false;
  bool get wantsPleaRequests => notificationPrefs['pleaRequests'] != false;
  bool get wantsVerdicts => notificationPrefs['verdicts'] != false;

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final int score = (map['focusScore'] as num?)?.toInt() ?? 500;
    final List<int> history = List<int>.from(
      (map['scoreHistory'] as List?)?.map((e) => (e as num).toInt()) ??
          <int>[score],
    );
    final rawPrefs = map['notificationPrefs'];
    final prefs = rawPrefs is Map
        ? Map<String, dynamic>.from(rawPrefs)
        : <String, dynamic>{};

    return UserModel(
      uid: map['uid'] as String,
      email: map['email'] as String?,
      fullName: map['fullName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      nickname: map['nickname'] as String?,
      currentStatus: (map['currentStatus'] as String?)?.trim(),
      focusScore: score,
      scoreHistory: history,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      squadId: map['squadId'] as String?,
      squadCode: map['squadCode'] as String?,
      notificationPrefs: prefs,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel.fromMap(json);
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'photoUrl': photoUrl,
      'nickname': nickname,
      'currentStatus': currentStatus,
      'focusScore': focusScore,
      'scoreHistory': scoreHistory,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'squadId': squadId,
      'squadCode': squadCode,
      'notificationPrefs': notificationPrefs,
    };
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }
}
