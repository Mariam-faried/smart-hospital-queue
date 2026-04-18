import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _firestore;

  NotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _notificationsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('notifications');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamNotifications(
    String uid, {
    int limit = 100,
  }) {
    return _notificationsRef(
      uid,
    ).orderBy('createdAt', descending: true).limit(limit).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamUnreadNotifications(
    String uid, {
    int limit = 99,
  }) {
    return _notificationsRef(
      uid,
    ).where('isRead', isEqualTo: false).limit(limit).snapshots();
  }

  Future<void> createPatientNotification({
    required String uid,
    required String title,
    required String message,
    required String type,
    String? appointmentId,
    String? doctorId,
    int? actionTab,
    Map<String, dynamic>? metadata,
  }) async {
    await _notificationsRef(uid).add({
      'title': title.trim(),
      'message': message.trim(),
      'type': type.trim().isEmpty ? 'general' : type.trim(),
      'isRead': false,
      'appointmentId': appointmentId,
      'doctorId': doctorId,
      'actionTab': actionTab,
      'metadata': metadata ?? const <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'readAt': null,
    });
  }

  Future<void> markAsRead({
    required String uid,
    required String notificationId,
  }) async {
    await _notificationsRef(uid).doc(notificationId).set({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markAllAsRead(String uid) async {
    final unreadSnapshot = await _notificationsRef(
      uid,
    ).where('isRead', isEqualTo: false).get();
    if (unreadSnapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in unreadSnapshot.docs) {
      batch.set(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }
}
