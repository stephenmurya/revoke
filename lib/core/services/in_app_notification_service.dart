import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification_model.dart';

class InAppNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _notificationsRef(
    String uid,
  ) {
    return _firestore.collection('users').doc(uid).collection('notifications');
  }

  static Stream<List<AppNotificationModel>> getUserNotifications(String uid) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return Stream<List<AppNotificationModel>>.value(
        const <AppNotificationModel>[],
      );
    }

    return _notificationsRef(normalizedUid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(AppNotificationModel.fromFirestore).toList(),
        );
  }

  static Future<void> markAsRead(String uid, String notificationId) async {
    final normalizedUid = uid.trim();
    final normalizedNotificationId = notificationId.trim();
    if (normalizedUid.isEmpty || normalizedNotificationId.isEmpty) return;

    await _notificationsRef(
      normalizedUid,
    ).doc(normalizedNotificationId).update({'isRead': true});
  }

  static Future<void> markAllAsRead(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;

    const int batchSize = 400;
    while (true) {
      final unreadSnap = await _notificationsRef(
        normalizedUid,
      ).where('isRead', isEqualTo: false).limit(batchSize).get();
      if (unreadSnap.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in unreadSnap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      if (unreadSnap.docs.length < batchSize) return;
    }
  }
}
