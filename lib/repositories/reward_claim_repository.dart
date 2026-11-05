import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Canje de un premio con QR. El comensal lo crea y lo muestra; el negocio lo escanea y lo
/// confirma; la Cloud Function `canjearPremio` descuenta los sellos e invalida el QR.
class RewardClaim {
  /// Tiempo que dura un QR de canje (igual en las reglas y en la Cloud Function)
  static const Duration validity = Duration(minutes: 10);

  static const String pending = 'pending';
  static const String confirming = 'confirming';
  static const String redeemed = 'redeemed';
  static const String rejected = 'rejected';
  static const String cancelled = 'cancelled';

  final String id;
  final String huecaId;
  final String huecaName;
  final String userId;
  final String userName;
  final String rewardText;
  final int stampsRequired;
  final String status;
  final DateTime createdAt;
  final String? rejectionReason;
  final int? stampsRemaining;

  const RewardClaim({
    required this.id,
    required this.huecaId,
    required this.huecaName,
    required this.userId,
    required this.userName,
    required this.rewardText,
    required this.stampsRequired,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
    this.stampsRemaining,
  });

  factory RewardClaim.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    return RewardClaim(
      id: id,
      huecaId: data['huecaId']?.toString() ?? '',
      huecaName: data['huecaName']?.toString() ?? '',
      userId: data['userId']?.toString() ?? '',
      userName: data['userName']?.toString() ?? '',
      rewardText: data['rewardText']?.toString() ?? '',
      stampsRequired: (data['stampsRequired'] as num?)?.toInt() ?? 0,
      status: data['status']?.toString() ?? pending,
      // Sin ack del servidor todavía no hay fecha: el QR se acaba de crear
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
      rejectionReason: data['rejectionReason']?.toString(),
      stampsRemaining: (data['stampsRemaining'] as num?)?.toInt(),
    );
  }

  DateTime get expiresAt => createdAt.add(validity);
  bool isExpired([DateTime? now]) => (now ?? DateTime.now()).isAfter(expiresAt);

  /// Se puede entregar: sigue pendiente y no venció
  bool get canBeConfirmed => status == pending && !isExpired();

  String get qrData => encodeQr(id, huecaId);

  static String encodeQr(String claimId, String huecaId) =>
      jsonEncode({'type': 'reward', 'token': claimId, 'business_id': huecaId});

  /// Devuelve el id del canje si el código leído es un QR de premio; si no, null.
  static String? parseQr(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is Map && data['type'] == 'reward') {
        final token = data['token']?.toString() ?? '';
        return token.isNotEmpty ? token : null;
      }
    } catch (_) {}
    return null;
  }
}

class RewardClaimRepository {
  final FirebaseFirestore _db;
  RewardClaimRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _claims => _db.collection('reward_claims');

  /// Comensal: crea el QR de canje. La función vuelve a calcular los sellos al confirmarlo.
  Future<String> create({
    required String huecaId,
    required String huecaName,
    required String userId,
    required String userName,
    required String rewardText,
    required int stampsRequired,
  }) async {
    final doc = await _claims.add({
      'huecaId': huecaId,
      'huecaName': huecaName,
      'userId': userId,
      'userName': userName,
      'rewardText': rewardText,
      'stampsRequired': stampsRequired,
      'status': RewardClaim.pending,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<RewardClaim?> watch(String claimId) => _claims
      .doc(claimId)
      .snapshots()
      .map((d) => d.exists ? RewardClaim.fromMap(d.id, d.data()!) : null);

  Future<RewardClaim?> get(String claimId) async {
    final doc = await _claims.doc(claimId).get();
    return doc.exists ? RewardClaim.fromMap(doc.id, doc.data()!) : null;
  }

  /// Comensal: invalida el QR si sale de la pantalla sin canjearlo
  Future<void> cancel(String claimId) =>
      _claims.doc(claimId).update({'status': RewardClaim.cancelled});

  /// Negocio: confirma la entrega; la Cloud Function hace el resto
  Future<void> confirm(String claimId, String staffUid) => _claims.doc(claimId).update({
        'status': RewardClaim.confirming,
        'confirmedBy': staffUid,
        'confirmedAt': FieldValue.serverTimestamp(),
      });
}

final rewardClaimRepositoryProvider = Provider<RewardClaimRepository>((ref) {
  return RewardClaimRepository(FirebaseFirestore.instance);
});
