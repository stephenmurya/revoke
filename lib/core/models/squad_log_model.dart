import 'package:cloud_firestore/cloud_firestore.dart';

class SquadLogModel {
  final String id;
  final String type; // plea_request | verdict | violation | regime_adopt
  final String title;
  final String userId;
  final String userName;
  final String userAvatar;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final Map<String, String> reactions; // userId -> reactionType

  const SquadLogModel({
    required this.id,
    required this.type,
    required this.title,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.timestamp,
    required this.metadata,
    required this.reactions,
  });

  factory SquadLogModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawTimestamp = data['timestamp'];
    final ts = rawTimestamp is Timestamp ? rawTimestamp.toDate() : DateTime.now();

    final rawMetadata = data['metadata'];
    final metadata = rawMetadata is Map
        ? Map<String, dynamic>.from(rawMetadata)
        : <String, dynamic>{};

    final rawReactions = data['reactions'];
    final reactions = <String, String>{};
    if (rawReactions is Map) {
      rawReactions.forEach((key, value) {
        final uid = key?.toString().trim() ?? '';
        final reaction = value?.toString().trim() ?? '';
        if (uid.isEmpty || reaction.isEmpty) return;
        reactions[uid] = reaction;
      });
    }

    return SquadLogModel(
      id: doc.id,
      type: (data['type'] as String?)?.trim() ?? '',
      title: (data['title'] as String?)?.trim() ?? '',
      userId: (data['userId'] as String?)?.trim() ?? '',
      userName: (data['userName'] as String?)?.trim() ?? '',
      userAvatar: (data['userAvatar'] as String?)?.trim() ?? '',
      timestamp: ts,
      metadata: metadata,
      reactions: reactions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'title': title,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
      'reactions': reactions,
    };
  }
}
