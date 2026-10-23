import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String huecaId;
  final String huecaName;
  final String? branchId;
  final String? branchName;
  final String category; // 'promocion', 'noticia', 'evento', 'nuevo_plato'
  final String title;
  final String message;
  final String? discountTag;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final DateTime? scheduledFor; // Target date/time when notification should be dispatched
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final String createdBy;
  final String? reviewedBy;

  NotificationModel({
    required this.id,
    required this.huecaId,
    required this.huecaName,
    this.branchId,
    this.branchName,
    required this.category,
    required this.title,
    required this.message,
    this.discountTag,
    this.status = 'pending',
    required this.createdAt,
    this.scheduledFor,
    this.approvedAt,
    this.rejectedAt,
    this.rejectionReason,
    required this.createdBy,
    this.reviewedBy,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NotificationModel(
      id: doc.id,
      huecaId: data['huecaId']?.toString() ?? '',
      huecaName: data['huecaName']?.toString() ?? '',
      branchId: data['branchId']?.toString(),
      branchName: data['branchName']?.toString(),
      category: data['category']?.toString() ?? 'noticia',
      title: data['title']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
      discountTag: data['discountTag']?.toString(),
      status: data['status']?.toString() ?? 'pending',
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      scheduledFor: (data['scheduledFor'] is Timestamp)
          ? (data['scheduledFor'] as Timestamp).toDate()
          : null,
      approvedAt: (data['approvedAt'] is Timestamp)
          ? (data['approvedAt'] as Timestamp).toDate()
          : (data['status'] == 'approved' ? DateTime.now() : null),
      rejectedAt: (data['rejectedAt'] is Timestamp)
          ? (data['rejectedAt'] as Timestamp).toDate()
          : null,
      rejectionReason: data['rejectionReason']?.toString(),
      createdBy: data['createdBy']?.toString() ?? '',
      reviewedBy: data['reviewedBy']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'huecaId': huecaId,
      'huecaName': huecaName,
      'branchId': branchId,
      'branchName': branchName,
      'category': category,
      'title': title,
      'message': message,
      'discountTag': discountTag,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'scheduledFor': scheduledFor != null ? Timestamp.fromDate(scheduledFor!) : null,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'rejectionReason': rejectionReason,
      'createdBy': createdBy,
      'reviewedBy': reviewedBy,
    };
  }

  String get categoryDisplay {
    switch (category) {
      case 'promocion':
        return 'Promoción';
      case 'evento':
        return 'Evento Especial';
      case 'nuevo_plato':
        return 'Nuevo Plato';
      case 'noticia':
      default:
        return 'Noticia';
    }
  }

  String get categoryEmoji {
    switch (category) {
      case 'promocion':
        return '🏷️';
      case 'evento':
        return '📅';
      case 'nuevo_plato':
        return '🍲';
      case 'noticia':
      default:
        return '📢';
    }
  }

  bool get isScheduled =>
      scheduledFor != null && scheduledFor!.isAfter(DateTime.now());

  String? get formattedScheduledDate {
    if (scheduledFor == null) return null;
    final dt = scheduledFor!;
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$min';
  }
}
