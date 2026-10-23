import 'package:cloud_firestore/cloud_firestore.dart';

class SupportMessage {
  final String id;
  final String huecaId;
  final String huecaName;
  final String? branchId;
  final String? branchName;
  final String senderUid;
  final String senderName;
  final String senderEmail;
  final String subject;
  final String message;
  final String status; // 'new', 'read', 'responded'
  final DateTime createdAt;
  final DateTime? readAt;
  final String? readBy;
  final String? adminResponse;
  final DateTime? respondedAt;
  final String? respondedBy;

  SupportMessage({
    required this.id,
    required this.huecaId,
    required this.huecaName,
    this.branchId,
    this.branchName,
    required this.senderUid,
    required this.senderName,
    required this.senderEmail,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    this.readAt,
    this.readBy,
    this.adminResponse,
    this.respondedAt,
    this.respondedBy,
  });

  factory SupportMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SupportMessage(
      id: doc.id,
      huecaId: data['huecaId']?.toString() ?? '',
      huecaName: data['huecaName']?.toString() ?? '',
      branchId: data['branchId'] as String?,
      branchName: data['branchName'] as String?,
      senderUid: data['senderUid']?.toString() ?? '',
      senderName: data['senderName']?.toString() ?? '',
      senderEmail: data['senderEmail']?.toString() ?? '',
      subject: data['subject']?.toString() ?? 'Consulta general',
      message: data['message']?.toString() ?? '',
      status: data['status']?.toString() ?? 'new',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      readAt: data['readAt'] is Timestamp
          ? (data['readAt'] as Timestamp).toDate()
          : null,
      readBy: data['readBy'] as String?,
      adminResponse: data['adminResponse'] as String?,
      respondedAt: data['respondedAt'] is Timestamp
          ? (data['respondedAt'] as Timestamp).toDate()
          : null,
      respondedBy: data['respondedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'huecaId': huecaId,
      'huecaName': huecaName,
      if (branchId != null) 'branchId': branchId,
      if (branchName != null) 'branchName': branchName,
      'senderUid': senderUid,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'subject': subject,
      'message': message,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      if (readAt != null) 'readAt': Timestamp.fromDate(readAt!),
      if (readBy != null) 'readBy': readBy,
      if (adminResponse != null) 'adminResponse': adminResponse,
      if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!),
      if (respondedBy != null) 'respondedBy': respondedBy,
    };
  }
}

class SupportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _supportCol =>
      _firestore.collection('support_messages');

  // Enviar mensaje de soporte (desde negocio)
  Future<String> submitMessage({
    required String huecaId,
    required String huecaName,
    String? branchId,
    String? branchName,
    required String senderUid,
    required String senderName,
    required String senderEmail,
    required String subject,
    required String message,
  }) async {
    final docRef = await _supportCol.add({
      'huecaId': huecaId,
      'huecaName': huecaName,
      'branchId': branchId,
      'branchName': branchName,
      'senderUid': senderUid,
      'senderName': senderName,
      'senderEmail': senderEmail.trim().toLowerCase(),
      'subject': subject,
      'message': message.trim(),
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
      'readAt': null,
      'readBy': null,
      'adminResponse': null,
      'respondedAt': null,
      'respondedBy': null,
    });
    return docRef.id;
  }

  // Stream de mensajes nuevos para admin (badge / pendientes)
  Stream<List<SupportMessage>> streamNewMessages() {
    return _supportCol
        .where('status', isEqualTo: 'new')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SupportMessage.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Stream de todos los mensajes para admin
  Stream<List<SupportMessage>> streamAllMessages() {
    return _supportCol.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SupportMessage.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Stream de mensajes enviados por una hueca en particular
  Stream<List<SupportMessage>> streamMessagesByHueca(String huecaId) {
    return _supportCol
        .where('huecaId', isEqualTo: huecaId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SupportMessage.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Marcar como leído
  Future<void> markAsRead(String messageId, String adminUid) async {
    await _supportCol.doc(messageId).update({
      'status': 'read',
      'readAt': FieldValue.serverTimestamp(),
      'readBy': adminUid,
    });
  }

  // Responder al mensaje
  Future<void> respondToMessage({
    required String messageId,
    required String adminUid,
    required String response,
  }) async {
    await _supportCol.doc(messageId).update({
      'status': 'responded',
      'adminResponse': response.trim(),
      'respondedAt': FieldValue.serverTimestamp(),
      'respondedBy': adminUid,
      if (FieldValue.serverTimestamp() != null) 'readAt': FieldValue.serverTimestamp(),
      'readBy': adminUid,
    });
  }
}
