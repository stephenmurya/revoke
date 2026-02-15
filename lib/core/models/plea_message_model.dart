import 'package:cloud_firestore/cloud_firestore.dart';

class PleaMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final bool isSystem;
  final DateTime timestamp;

  PleaMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.isSystem,
    required this.timestamp,
  });

  factory PleaMessageModel.fromJson(Map<String, dynamic> json, String docId) {
    return PleaMessageModel(
      id: docId,
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? 'Member',
      text: json['text'] as String? ?? '',
      isSystem: json['isSystem'] as bool? ?? false,
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'isSystem': isSystem,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
