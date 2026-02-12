import 'package:cloud_firestore/cloud_firestore.dart';

class PleaMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;

  PleaMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  factory PleaMessageModel.fromJson(Map<String, dynamic> json, String docId) {
    return PleaMessageModel(
      id: docId,
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? 'Member',
      text: json['text'] as String? ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
