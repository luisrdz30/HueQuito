import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class HuecaRequest {
  final String id;
  final String huecaName;
  final String address;
  final String sector;
  final String phone;
  final String description;
  final String mainDish;
  final String ownerName;
  final String ownerEmail;
  final String? photoUrl;
  final String requestedBy;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;
  final String? adminNotes;
  final String? createdHuecaId;

  HuecaRequest({
    required this.id,
    required this.huecaName,
    required this.address,
    required this.sector,
    required this.phone,
    required this.description,
    required this.mainDish,
    required this.ownerName,
    required this.ownerEmail,
    this.photoUrl,
    required this.requestedBy,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
    this.adminNotes,
    this.createdHuecaId,
  });

  factory HuecaRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return HuecaRequest(
      id: doc.id,
      huecaName: data['huecaName']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      sector: data['sector']?.toString() ?? 'Centro Histórico',
      phone: data['phone']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      mainDish: data['mainDish']?.toString() ?? '',
      ownerName: data['ownerName']?.toString() ?? '',
      ownerEmail: data['ownerEmail']?.toString() ?? '',
      photoUrl: data['photoUrl'] as String?,
      requestedBy: data['requestedBy']?.toString() ?? '',
      status: data['status']?.toString() ?? 'pending',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      reviewedAt: data['reviewedAt'] is Timestamp
          ? (data['reviewedAt'] as Timestamp).toDate()
          : null,
      reviewedBy: data['reviewedBy'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      adminNotes: data['adminNotes'] as String?,
      createdHuecaId: data['createdHuecaId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'huecaName': huecaName,
      'address': address,
      'sector': sector,
      'phone': phone,
      'description': description,
      'mainDish': mainDish,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'requestedBy': requestedBy,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (adminNotes != null) 'adminNotes': adminNotes,
      if (createdHuecaId != null) 'createdHuecaId': createdHuecaId,
    };
  }
}

class HuecaRequestRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _requestsCol =>
      _firestore.collection('hueca_requests');

  // Sube una foto a Storage para la solicitud
  Future<String?> uploadRequestPhoto(File file, String userId) async {
    try {
      final fileName = 'request_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('hueca_requests/$fileName');
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error subiendo foto de solicitud: $e');
      return null;
    }
  }

  // Enviar una nueva solicitud de registro de hueca
  Future<String> submitRequest({
    required String huecaName,
    required String address,
    required String sector,
    required String phone,
    required String description,
    required String mainDish,
    required String ownerName,
    required String ownerEmail,
    String? photoUrl,
    required String requestedBy,
  }) async {
    final docRef = await _requestsCol.add({
      'huecaName': huecaName.trim(),
      'address': address.trim(),
      'sector': sector.trim(),
      'phone': phone.trim(),
      'description': description.trim(),
      'mainDish': mainDish.trim(),
      'ownerName': ownerName.trim(),
      'ownerEmail': ownerEmail.trim().toLowerCase(),
      'photoUrl': photoUrl,
      'requestedBy': requestedBy,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
      'reviewedBy': null,
      'rejectionReason': null,
      'adminNotes': null,
      'createdHuecaId': null,
    });
    return docRef.id;
  }

  // Stream de solicitudes pendientes (para admin)
  Stream<List<HuecaRequest>> streamPendingRequests() {
    return _requestsCol
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => HuecaRequest.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Stream de todas las solicitudes (para historial admin)
  Stream<List<HuecaRequest>> streamAllRequests() {
    return _requestsCol.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => HuecaRequest.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Stream de solicitudes creadas por un usuario en particular
  Stream<List<HuecaRequest>> streamUserRequests(String userId) {
    return _requestsCol
        .where('requestedBy', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => HuecaRequest.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Rechazar solicitud
  Future<void> rejectRequest({
    required String requestId,
    required String adminUid,
    required String reason,
  }) async {
    await _requestsCol.doc(requestId).update({
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': adminUid,
      'rejectionReason': reason.trim(),
    });
  }

  // Marcar como aprobada y vincular la hueca creada
  Future<void> markApproved({
    required String requestId,
    required String adminUid,
    required String createdHuecaId,
    String? adminNotes,
  }) async {
    await _requestsCol.doc(requestId).update({
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': adminUid,
      'createdHuecaId': createdHuecaId,
      if (adminNotes != null) 'adminNotes': adminNotes.trim(),
      'rejectionReason': null,
    });
  }
}
