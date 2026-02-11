import 'package:cloud_firestore/cloud_firestore.dart';

class PleaModel {
  final String id;
  final String userId;
  final String userName;
  final String squadId;
  final String appName;
  final String packageName;
  final Map<String, bool> votes;
  final String status;
  final DateTime createdAt;

  PleaModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.squadId,
    required this.appName,
    required this.packageName,
    required this.votes,
    required this.status,
    required this.createdAt,
  });

  factory PleaModel.fromJson(Map<String, dynamic> json, String docId) {
    return PleaModel(
      id: docId,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      squadId: json['squadId'] as String,
      appName: json['appName'] as String,
      packageName: json['packageName'] as String? ?? '',
      votes: Map<String, bool>.from(json['votes'] as Map? ?? {}),
      status: json['status'] as String? ?? 'pending',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'squadId': squadId,
      'appName': appName,
      'packageName': packageName,
      'votes': votes,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
