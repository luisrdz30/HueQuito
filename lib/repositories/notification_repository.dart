import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/models/notification_model.dart';

/// Se lanza cuando la hueca ya tiene sus avisos del día en que saldría el nuevo.
class DailyNoticeLimitException implements Exception {
  final String day; // yyyy-MM-dd (hora de Quito)
  DailyNoticeLimitException(this.day);

  @override
  String toString() {
    if (day == NotificationRepository.todayInQuito()) {
      return 'Ya publicaste ${NotificationRepository.maxNoticesPerDay} avisos hoy. Podrás publicar otro mañana.';
    }
    final p = day.split('-');
    return 'Ya tienes ${NotificationRepository.maxNoticesPerDay} avisos para el ${p[2]}/${p[1]}/${p[0]}. Elige otro día.';
  }
}

class NotificationRepository {
  /// Avisos que una hueca puede publicar por día (lo controla la Cloud Function `publicarAviso`).
  /// Un aviso programado cuenta para el día en que sale, no para el día en que se creó.
  static const int maxNoticesPerDay = 2;

  /// Día calendario en Quito (UTC-5, sin horario de verano), igual que en la Cloud Function
  static String dayInQuito(DateTime moment) =>
      moment.toUtc().subtract(const Duration(hours: 5)).toIso8601String().substring(0, 10);

  static String todayInQuito() => dayInQuito(DateTime.now());

  /// Avisos ya usados por día ({'2026-11-04': 1}); acepta el formato anterior {day, count}
  static Map<String, int> usedByDay(Map<String, dynamic>? data) {
    final days = <String, int>{};
    if (data == null) return days;
    final raw = data['days'];
    if (raw is Map) {
      raw.forEach((k, v) => days[k.toString()] = (v as num?)?.toInt() ?? 0);
    }
    final oldDay = data['day']?.toString();
    if (oldDay != null && !days.containsKey(oldDay)) {
      days[oldDay] = (data['count'] as num?)?.toInt() ?? 0;
    }
    return days;
  }

  /// Avisos que le quedan a la hueca para el día en que saldría [publishAt] (hoy si es null)
  static int remainingFor(Map<String, int> used, DateTime? publishAt) {
    final day = dayInQuito(publishAt ?? DateTime.now());
    return (maxNoticesPerDay - (used[day] ?? 0)).clamp(0, maxNoticesPerDay);
  }

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
  }) async {
    final publishAt = scheduledFor != null && scheduledFor.isAfter(DateTime.now()) ? scheduledFor : null;
    if (remainingFor(await usedNoticesByDay(huecaId), publishAt) <= 0) {
      throw DailyNoticeLimitException(dayInQuito(publishAt ?? DateTime.now()));
    }
    // Se crea 'pending': la Cloud Function lo publica si ese día no pasó del límite
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
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'approvedAt': null,
      'rejectedAt': null,
      'rejectionReason': null,
      'createdBy': createdBy,
      'reviewedBy': null,
    });
    return docRef.id;
  }

  // Business: avisos ya usados por día de la hueca
  Future<Map<String, int>> usedNoticesByDay(String huecaId) async {
    try {
      final doc = await _firestore.collection('noticeQuota').doc(huecaId).get();
      return usedByDay(doc.data());
    } catch (_) {
      return {}; // Si no se puede leer, decide la Cloud Function
    }
  }

  Stream<Map<String, int>> streamUsedNoticesByDay(String huecaId) {
    return _firestore.collection('noticeQuota').doc(huecaId).snapshots().map((d) => usedByDay(d.data()));
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
