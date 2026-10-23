import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notificationsCol =>
      _firestore.collection('notifications');

  // Business: Submit a new request
  Future<String> submitNotificationRequest({
    required String huecaId,
    required String huecaName,
    String? branchId,
    String? branchName,
    required String category,
    required String title,
    required String message,
    String? discountTag,
    DateTime? scheduledFor,
    required String createdBy,
    bool autoApprove = false,
  }) async {
    final docRef = await _notificationsCol.add({
      'huecaId': huecaId,
      'huecaName': huecaName,
      'branchId': branchId,
      'branchName': branchName,
      'category': category,
      'title': title,
      'message': message,
      'discountTag': discountTag,
      'scheduledFor': scheduledFor != null ? Timestamp.fromDate(scheduledFor) : null,
      'status': autoApprove ? 'approved' : 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'approvedAt': autoApprove ? Timestamp.now() : null,
      'rejectedAt': null,
      'rejectionReason': null,
      'createdBy': createdBy,
      'reviewedBy': autoApprove ? 'auto_business' : null,
    });
    return docRef.id;
  }

  // User & Diner: Stream active approved notifications for a specific hueca
  // Maximum age: 4 hours (240 minutes) from publication time. If older than 4 hours, it auto-deletes from Firestore
  // to avoid clutter and unwanted records.
  Stream<List<NotificationModel>> streamActiveNotificationsByHueca(String huecaId) {
    return _notificationsCol
        .where('huecaId', isEqualTo: huecaId)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final activeList = <NotificationModel>[];

      for (final doc in snapshot.docs) {
        try {
          final n = NotificationModel.fromFirestore(doc);
          final pubAt = n.effectivePublishedAt;

          // Si fue programada para el futuro, no mostrar todavia
          if (pubAt.isAfter(now)) continue;

          final ageInMinutes = now.difference(pubAt).inMinutes;

          // Si pasaron mas de 4 horas (240 min), se borra automaticamente de Firestore
          if (ageInMinutes > 240) {
            doc.reference.delete().catchError((_) {});
          } else {
            activeList.add(n);
          }
        } catch (_) {}
      }

      activeList.sort((a, b) => b.effectivePublishedAt.compareTo(a.effectivePublishedAt));
      return activeList;
    });
  }

  // Business: Stream notifications for a specific hueca
  Stream<List<NotificationModel>> streamNotificationsByHueca(String huecaId) {
    return _notificationsCol
        .where('huecaId', isEqualTo: huecaId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Admin: Stream pending notifications for moderation
  Stream<List<NotificationModel>> streamPendingNotifications() {
    return _notificationsCol
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Admin: Stream all notifications (for history)
  Stream<List<NotificationModel>> streamAllNotifications() {
    return _notificationsCol.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Admin: Approve
  Future<void> approveNotification(String notificationId, String adminUid) async {
    await _notificationsCol.doc(notificationId).update({
      'status': 'approved',
      'approvedAt': Timestamp.now(),
      'reviewedBy': adminUid,
      'rejectionReason': null,
    });
  }

  // Admin: Reject
  Future<void> rejectNotification({
    required String notificationId,
    required String adminUid,
    required String reason,
  }) async {
    await _notificationsCol.doc(notificationId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'reviewedBy': adminUid,
      'rejectionReason': reason,
    });
  }

  // User: Stream approved notifications
  Stream<List<NotificationModel>> streamApprovedNotifications() {
    return _notificationsCol
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => (b.approvedAt ?? b.createdAt).compareTo(a.approvedAt ?? a.createdAt));
      return list;
    });
  }
}
