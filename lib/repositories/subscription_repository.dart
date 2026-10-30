import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';

/// Configuración global de suscripciones para las huecas
class SubscriptionSettings {
  final double monthlyPrice;
  final int freeTierMaxStamps;
  final int gracePeriodDays;
  final String bankName;
  final String accountType;
  final String accountNumber;
  final String accountHolder;
  final String identificationNumber; // Cédula o RUC
  final String notificationEmail;

  const SubscriptionSettings({
    this.monthlyPrice = 9.99,
    this.freeTierMaxStamps = 100,
    this.gracePeriodDays = 7,
    this.bankName = 'Banco Pichincha',
    this.accountType = 'Cuenta de ahorros',
    this.accountNumber = '2209810135',
    this.accountHolder = 'Hue-Quito',
    this.identificationNumber = '1723456789',
    this.notificationEmail = 'pagos@huequito.com',
  });

  factory SubscriptionSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const SubscriptionSettings();
    return SubscriptionSettings(
      monthlyPrice: (data['monthlyPrice'] as num?)?.toDouble() ?? 9.99,
      freeTierMaxStamps: (data['freeTierMaxStamps'] as num?)?.toInt() ?? 100,
      gracePeriodDays: (data['gracePeriodDays'] as num?)?.toInt() ?? 7,
      bankName: data['bankName']?.toString() ?? 'Banco Pichincha',
      accountType: data['accountType']?.toString() ?? 'Cuenta de ahorros',
      accountNumber: data['accountNumber']?.toString() ?? '2209810135',
      accountHolder: data['accountHolder']?.toString() ?? 'Hue-Quito',
      identificationNumber: data['identificationNumber']?.toString() ?? '1723456789',
      notificationEmail: data['notificationEmail']?.toString() ?? 'pagos@huequito.com',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'monthlyPrice': monthlyPrice,
      'freeTierMaxStamps': freeTierMaxStamps,
      'gracePeriodDays': gracePeriodDays,
      'bankName': bankName,
      'accountType': accountType,
      'accountNumber': accountNumber,
      'accountHolder': accountHolder,
      'identificationNumber': identificationNumber,
      'notificationEmail': notificationEmail,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

enum HuecaSubscriptionState {
  freeTier,     // Dentro de los sellos gratis de prueba (freeTierMaxStamps)
  gracePeriod,  // Llegó a la meta de sellos gratis, dentro de los días de gracia para pagar
  underReview,  // Comprobante de transferencia subido, esperando validación
  active,       // Pago aprobado, suscripción vigente (30 días)
  suspended,    // Gracia vencida sin pagar: no puede entregar sellos
}

class HuecaSubscriptionInfo {
  final HuecaSubscriptionState state;
  final int stampsGiven;
  final int maxFreeStamps;
  final int daysRemainingInGrace;
  final DateTime? gracePeriodEnd;
  final DateTime? nextCutoffDate;
  final DateTime? lastPaymentDate;
  final String? receiptImageUrl;
  final String? referenceNumber;
  final String? rejectionReason;
  final double price;

  const HuecaSubscriptionInfo({
    required this.state,
    required this.stampsGiven,
    required this.maxFreeStamps,
    this.daysRemainingInGrace = 0,
    this.gracePeriodEnd,
    this.nextCutoffDate,
    this.lastPaymentDate,
    this.receiptImageUrl,
    this.referenceNumber,
    this.rejectionReason,
    required this.price,
  });

  bool get isLocked => state == HuecaSubscriptionState.suspended;
  bool get needsPayment => state == HuecaSubscriptionState.gracePeriod || state == HuecaSubscriptionState.suspended;
  bool get isUnderReview => state == HuecaSubscriptionState.underReview;
  bool get isFreeTier => state == HuecaSubscriptionState.freeTier;
  bool get isActive => state == HuecaSubscriptionState.active;
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  try {
    return SubscriptionRepository(FirebaseFirestore.instance);
  } catch (_) {
    return SubscriptionRepository(null);
  }
});

final subscriptionSettingsProvider = StreamProvider<SubscriptionSettings>((ref) {
  try {
    return ref.watch(subscriptionRepositoryProvider).streamSettings();
  } catch (_) {
    return Stream.value(const SubscriptionSettings());
  }
});

class SubscriptionRepository {
  final FirebaseFirestore? _firestore;

  SubscriptionRepository([FirebaseFirestore? firestore]) : _firestore = firestore;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  /// Obtiene los ajustes globales de suscripciones
  Future<SubscriptionSettings> getSettings() async {
    try {
      if (_firestore == null) {
        try {
          final doc = await FirebaseFirestore.instance.collection('settings').doc('subscription').get();
          if (!doc.exists) return const SubscriptionSettings();
          return SubscriptionSettings.fromMap(doc.data());
        } catch (_) {
          return const SubscriptionSettings();
        }
      }
      final doc = await firestore.collection('settings').doc('subscription').get();
      if (!doc.exists) return const SubscriptionSettings();
      return SubscriptionSettings.fromMap(doc.data());
    } catch (_) {
      return const SubscriptionSettings();
    }
  }

  /// Stream en tiempo real de los ajustes globales
  Stream<SubscriptionSettings> streamSettings() {
    try {
      final db = _firestore ?? FirebaseFirestore.instance;
      return db.collection('settings').doc('subscription').snapshots().map((doc) {
        if (!doc.exists) return const SubscriptionSettings();
        return SubscriptionSettings.fromMap(doc.data());
      }).handleError((_) => const SubscriptionSettings());
    } catch (_) {
      return Stream.value(const SubscriptionSettings());
    }
  }

  /// Actualiza los ajustes globales (precio, meta de sellos, banco, etc.)
  Future<void> updateSettings(SubscriptionSettings settings) async {
    await firestore.collection('settings').doc('subscription').set(settings.toMap(), SetOptions(merge: true));
  }

  /// Calcula el estado exacto de suscripción de una hueca
  HuecaSubscriptionInfo evaluateHuecaSubscription({
    required Hueca hueca,
    required SubscriptionSettings settings,
  }) {
    final subData = hueca.subscription;
    final stampsGiven = hueca.metrics['stampsGiven'] is num
        ? (hueca.metrics['stampsGiven'] as num).toInt()
        : 0;
    final maxFreeStamps = settings.freeTierMaxStamps;
    final explicitStatus = subData['status']?.toString();

    final lastReceipt = subData['lastReceipt'] is Map
        ? Map<String, dynamic>.from(subData['lastReceipt'])
        : null;
    final receiptImageUrl = lastReceipt?['imageUrl']?.toString();
    final referenceNumber = lastReceipt?['referenceNumber']?.toString();
    final rejectionReason = lastReceipt?['rejectionReason']?.toString();

    DateTime? nextCutoff;
    if (subData['nextCutoffDate'] != null) {
      if (subData['nextCutoffDate'] is Timestamp) {
        nextCutoff = (subData['nextCutoffDate'] as Timestamp).toDate();
      } else if (subData['nextCutoffDate'] is String) {
        nextCutoff = DateTime.tryParse(subData['nextCutoffDate']);
      }
    }

    DateTime? lastPayment;
    if (subData['lastPaymentDate'] != null) {
      if (subData['lastPaymentDate'] is Timestamp) {
        lastPayment = (subData['lastPaymentDate'] as Timestamp).toDate();
      } else if (subData['lastPaymentDate'] is String) {
        lastPayment = DateTime.tryParse(subData['lastPaymentDate']);
      }
    }

    final now = DateTime.now();

    // 1. Si está explícitamente en revisión
    if (explicitStatus == 'under_review') {
      return HuecaSubscriptionInfo(
        state: HuecaSubscriptionState.underReview,
        stampsGiven: stampsGiven,
        maxFreeStamps: maxFreeStamps,
        receiptImageUrl: receiptImageUrl,
        referenceNumber: referenceNumber,
        price: settings.monthlyPrice,
        nextCutoffDate: nextCutoff,
        lastPaymentDate: lastPayment,
      );
    }

    // 2. Si está activa (suscripción pagada vigente)
    if (explicitStatus == 'active') {
      if (nextCutoff != null && now.isAfter(nextCutoff)) {
        // Venció el mes pagado -> Inicia periodo de gracia de 7 días
        final graceEnd = nextCutoff.add(Duration(days: settings.gracePeriodDays));
        if (now.isAfter(graceEnd)) {
          return HuecaSubscriptionInfo(
            state: HuecaSubscriptionState.suspended,
            stampsGiven: stampsGiven,
            maxFreeStamps: maxFreeStamps,
            price: settings.monthlyPrice,
            rejectionReason: rejectionReason,
          );
        } else {
          final diff = (graceEnd.difference(now).inSeconds / 86400).ceil().clamp(0, settings.gracePeriodDays);
          return HuecaSubscriptionInfo(
            state: HuecaSubscriptionState.gracePeriod,
            stampsGiven: stampsGiven,
            maxFreeStamps: maxFreeStamps,
            daysRemainingInGrace: diff,
            gracePeriodEnd: graceEnd,
            price: settings.monthlyPrice,
            rejectionReason: rejectionReason,
          );
        }
      }
      return HuecaSubscriptionInfo(
        state: HuecaSubscriptionState.active,
        stampsGiven: stampsGiven,
        maxFreeStamps: maxFreeStamps,
        nextCutoffDate: nextCutoff,
        lastPaymentDate: lastPayment,
        price: settings.monthlyPrice,
      );
    }

    // 3. Si aún no llega a la meta de sellos gratuitos
    if (stampsGiven < maxFreeStamps) {
      return HuecaSubscriptionInfo(
        state: HuecaSubscriptionState.freeTier,
        stampsGiven: stampsGiven,
        maxFreeStamps: maxFreeStamps,
        price: settings.monthlyPrice,
      );
    }

    // 4. Llegó a la meta de sellos gratuitos -> Evaluar fecha de inicio de gracia
    DateTime? graceStart;
    if (subData['gracePeriodStartDate'] != null) {
      if (subData['gracePeriodStartDate'] is Timestamp) {
        graceStart = (subData['gracePeriodStartDate'] as Timestamp).toDate();
      } else if (subData['gracePeriodStartDate'] is String) {
        graceStart = DateTime.tryParse(subData['gracePeriodStartDate']);
      }
    }
    graceStart ??= now;

    final graceEnd = graceStart.add(Duration(days: settings.gracePeriodDays));
    if (now.isAfter(graceEnd) || explicitStatus == 'suspended') {
      return HuecaSubscriptionInfo(
        state: HuecaSubscriptionState.suspended,
        stampsGiven: stampsGiven,
        maxFreeStamps: maxFreeStamps,
        price: settings.monthlyPrice,
        rejectionReason: rejectionReason,
      );
    }

    final diff = (graceEnd.difference(now).inSeconds / 86400).ceil().clamp(0, settings.gracePeriodDays);
    return HuecaSubscriptionInfo(
      state: HuecaSubscriptionState.gracePeriod,
      stampsGiven: stampsGiven,
      maxFreeStamps: maxFreeStamps,
      daysRemainingInGrace: diff,
      gracePeriodEnd: graceEnd,
      price: settings.monthlyPrice,
      rejectionReason: rejectionReason,
    );
  }

  /// true si la hueca ya no puede entregar sellos (gracia vencida sin pago).
  Future<bool> isHuecaSuspended(String huecaId) async {
    try {
      final snap = await firestore.collection('huecas').doc(huecaId).get();
      if (!snap.exists) return false;
      final settings = await getSettings();
      return evaluateHuecaSubscription(hueca: Hueca.fromFirestore(snap), settings: settings).isLocked;
    } catch (_) {
      return false; // Sin conexión no se bloquea al comensal; las reglas de Firestore validan igual
    }
  }

  /// Suma los sellos entregados por la hueca. Si con ellos llega a la meta gratuita,
  /// guarda (una sola vez) la fecha de inicio del periodo de gracia.
  Future<void> registerStampsGiven(String huecaId, int stamps) async {
    final settings = await getSettings();
    final docRef = firestore.collection('huecas').doc(huecaId);
    await firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? <String, dynamic>{};
      final metrics = data['metrics'] is Map ? data['metrics'] as Map : const {};
      final sub = data['subscription'] is Map ? data['subscription'] as Map : const {};
      final current = (metrics['stampsGiven'] as num?)?.toInt() ?? 0;
      final status = sub['status']?.toString();

      final update = <String, dynamic>{'metrics.stampsGiven': FieldValue.increment(stamps)};
      if (current + stamps >= settings.freeTierMaxStamps &&
          sub['gracePeriodStartDate'] == null &&
          status != 'active' &&
          status != 'under_review') {
        update['subscription.gracePeriodStartDate'] = FieldValue.serverTimestamp();
      }
      tx.update(docRef, update);
    });
  }

  /// Sube un comprobante de transferencia y pasa el estado a 'under_review'
  Future<void> submitPaymentReceipt({
    required String huecaId,
    required String receiptImageUrl,
    String? referenceNumber,
    required double amount,
  }) async {
    final docRef = firestore.collection('huecas').doc(huecaId);
    final huecaSnap = await docRef.get();
    final huecaName = huecaSnap.data()?['name']?.toString() ?? 'Hueca';

    await docRef.update({
      'subscription.status': 'under_review',
      'subscription.monthlyPrice': amount,
      'subscription.lastReceipt': {
        'imageUrl': receiptImageUrl,
        'referenceNumber': referenceNumber?.trim() ?? '',
        'amount': amount,
        'uploadedAt': FieldValue.serverTimestamp(),
        'rejectionReason': null,
      },
    });

    // Guardar en historial de transferencias
    await docRef.collection('payment_history').add({
      'imageUrl': receiptImageUrl,
      'referenceNumber': referenceNumber?.trim() ?? '',
      'amount': amount,
      'date': FieldValue.serverTimestamp(),
      'status': 'under_review',
    });

    // Crear notificación para administradores
    await firestore.collection('admin_notifications').add({
      'type': 'subscription_receipt',
      'huecaId': huecaId,
      'huecaName': huecaName,
      'amount': amount,
      'referenceNumber': referenceNumber?.trim() ?? '',
      'imageUrl': receiptImageUrl,
      'date': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  /// Administrador aprueba el comprobante de transferencia y activa por 30 días
  Future<void> approvePayment({
    required String huecaId,
    required String adminId,
    int days = 30,
  }) async {
    final docRef = firestore.collection('huecas').doc(huecaId);
    final nextCutoff = DateTime.now().add(Duration(days: days));

    await docRef.update({
      'subscription.status': 'active',
      'subscription.lastPaymentDate': FieldValue.serverTimestamp(),
      'subscription.nextCutoffDate': Timestamp.fromDate(nextCutoff),
      'subscription.approvedBy': adminId,
      'subscription.lastReceipt.rejectionReason': null,
      'isActive': true, // Reactiva automáticamente la hueca si estaba suspendida
    });

    // Notificar al dueño de la hueca
    final snap = await docRef.get();
    final ownerId = snap.data()?['ownerId']?.toString();
    final huecaName = snap.data()?['name']?.toString() ?? 'Hueca';

    if (ownerId != null && ownerId.isNotEmpty) {
      await firestore.collection('notifications').add({
        'userId': ownerId,
        'huecaId': huecaId,
        'huecaName': huecaName,
        'category': 'suscripcion',
        'title': '¡Suscripción Aprobada!',
        'message': 'Tu pago para $huecaName fue validado con éxito. Tu hueca está activa hasta el ${nextCutoff.day}/${nextCutoff.month}/${nextCutoff.year}.',
        'status': 'system',
        'type': 'subscription_approved',
        'createdBy': adminId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    }
  }

  /// Administrador rechaza el comprobante con motivo
  Future<void> rejectPayment({
    required String huecaId,
    required String reason,
  }) async {
    final docRef = firestore.collection('huecas').doc(huecaId);

    await docRef.update({
      'subscription.status': 'grace_period',
      'subscription.lastReceipt.rejectionReason': reason,
    });

    final snap = await docRef.get();
    final ownerId = snap.data()?['ownerId']?.toString();
    final huecaName = snap.data()?['name']?.toString() ?? 'Hueca';

    if (ownerId != null && ownerId.isNotEmpty) {
      await firestore.collection('notifications').add({
        'userId': ownerId,
        'huecaId': huecaId,
        'huecaName': huecaName,
        'category': 'suscripcion',
        'title': 'Comprobante no aprobado',
        'message': 'Hubo una observación con el comprobante de $huecaName: "$reason". Por favor sube un nuevo comprobante.',
        'status': 'system',
        'type': 'subscription_rejected',
        'createdBy': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    }
  }

  /// Suspende una hueca si su plazo venció sin pago
  Future<void> suspendHueca(String huecaId) async {
    await firestore.collection('huecas').doc(huecaId).update({
      'subscription.status': 'suspended',
      'isActive': false,
    });
  }

  /// Stream de todas las huecas que están con comprobante pendiente de verificación
  Stream<List<Hueca>> streamPendingReceiptHuecas() {
    return firestore
        .collection('huecas')
        .where('subscription.status', isEqualTo: 'under_review')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Hueca.fromFirestore(d)).toList());
  }
}
