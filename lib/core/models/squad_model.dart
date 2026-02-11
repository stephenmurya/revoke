import 'package:cloud_firestore/cloud_firestore.dart';

class SquadModel {
  final String id;
  final String squadCode;
  final String creatorId;
  final List<String> memberIds;
  final DateTime? createdAt;

  SquadModel({
    required this.id,
    required this.squadCode,
    required this.creatorId,
    required this.memberIds,
    this.createdAt,
  });

  factory SquadModel.fromJson(Map<String, dynamic> json, String docId) {
    return SquadModel(
      id: docId,
      squadCode: json['squadCode'] as String,
      creatorId: json['creatorId'] as String,
      memberIds: List<String>.from(json['memberIds'] as List? ?? []),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'squadCode': squadCode,
      'creatorId': creatorId,
      'memberIds': memberIds,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
