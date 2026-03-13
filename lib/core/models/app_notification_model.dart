import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.timestamp,
    this.metadata,
  });

  factory AppNotificationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawMetadata = data['metadata'];
    final parsedMetadata = rawMetadata is Map
        ? Map<String, dynamic>.from(rawMetadata)
        : null;

    final rawTimestamp = data['timestamp'];
    final parsedTimestamp = rawTimestamp is Timestamp
        ? rawTimestamp.toDate()
        : DateTime.now();

    final rawType = (data['type'] as String?)?.trim().toLowerCase();

    return AppNotificationModel(
      id: doc.id,
      title: (data['title'] as String?)?.trim() ?? '',
      body: (data['body'] as String?)?.trim() ?? '',
      type: (rawType == null || rawType.isEmpty) ? 'system' : rawType,
      isRead: data['isRead'] as bool? ?? false,
      timestamp: parsedTimestamp,
      metadata: parsedMetadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata ?? const <String, dynamic>{},
    };
  }
}
