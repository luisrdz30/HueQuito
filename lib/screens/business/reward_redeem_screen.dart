import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/reward_claim_repository.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/utils/back_navigation.dart';

/// El negocio escanea el QR de premio del comensal, revisa qué le toca y confirma la entrega.
class RewardRedeemScreen extends ConsumerStatefulWidget {
  const RewardRedeemScreen({super.key});

  @override
  ConsumerState<RewardRedeemScreen> createState() => _RewardRedeemScreenState();
}

class _RewardRedeemScreenState extends ConsumerState<RewardRedeemScreen> {
  bool _reading = false;
  bool _confirming = false;
  RewardClaim? _claim;
  String? _error;
  StreamSubscription<RewardClaim?>? _sub;
  Timer? _timeout;

  @override
  void dispose() {
    _sub?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  void _reset() {
    _sub?.cancel();
    _timeout?.cancel();
    setState(() {
      _reading = false;
      _confirming = false;
      _claim = null;
      _error = null;
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_reading || _claim != null || _error != null) return;
    String? raw;
    for (final b in capture.barcodes) {
      raw = b.rawValue ?? b.displayValue;
      if (raw != null) break;
    }
    if (raw == null) return;

    setState(() => _reading = true);
    final claimId = RewardClaim.parseQr(raw);
    if (claimId == null) {
      setState(() {
        _reading = false;
        _error = 'Este no es un QR de premio. Pídele al cliente que abra "Reclamar premio" en su cartilla.';
      });
      return;
    }

    String? error;
    RewardClaim? claim;
    try {
      claim = await ref.read(rewardClaimRepositoryProvider).get(claimId);
      final hueca = await ref.read(myHuecaProvider.future);
      if (claim == null) {
        error = 'No encontramos este QR.';
      } else if (hueca == null || claim.huecaId != hueca.id) {
        error = 'Este premio es de otra hueca (${claim.huecaName}).';
      } else if (claim.status == RewardClaim.redeemed) {
        error = 'Este QR ya se usó. El premio ya fue entregado.';
      } else if (!claim.canBeConfirmed) {
        error = 'Este QR ya no es válido. Pídele al cliente que genere uno nuevo.';
      }
    } catch (_) {
      // Las reglas no dejan leer el canje de otra hueca
      error = 'No se pudo validar este QR. Puede ser de otra hueca o falta conexión.';
    }
    if (!mounted) return;
    setState(() {
      _reading = false;
      _error = error;
      _claim = error == null ? claim : null;
    });
  }

  Future<void> _confirm() async {
    final claim = _claim;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (claim == null || uid == null) return;
    setState(() => _confirming = true);
    final repo = ref.read(rewardClaimRepositoryProvider);
    try {
      _sub = repo.watch(claim.id).listen((updated) {
        if (!mounted || updated == null) return;
        if (updated.status == RewardClaim.redeemed || updated.status == RewardClaim.rejected) {
          _timeout?.cancel();
          setState(() {
            _claim = updated;
            _confirming = false;
          });
        }
      });
      _timeout = Timer(const Duration(seconds: 30), () {
        if (!mounted || !_confirming) return;
        _sub?.cancel();
        setState(() {
          _confirming = false;
          _claim = null;
          _error = 'El servidor tardó demasiado. Pídele al cliente que revise si el premio se descontó antes de entregarlo.';
        });
      });
      await repo.confirm(claim.id, uid);
    } catch (_) {
      _timeout?.cancel();
      await _sub?.cancel();
      if (!mounted) return;
      setState(() {
        _confirming = false;
        _claim = null;
        _error = 'No se pudo confirmar. El QR pudo haber vencido; pídele al cliente que genere uno nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showScanner = _claim == null && _error == null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Canjear premio'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => goBack(context, fallback: '/business/qr'),
        ),
      ),
      body: showScanner ? _scanner() : SafeArea(child: _result()),
    );
  }

  Widget _scanner() {
    return Stack(
      children: [
        MobileScanner(onDetect: _onDetect),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.black.withValues(alpha: 0.65),
            child: Text(
              _reading ? 'Validando...' : 'Apunta al QR de premio que te muestra el cliente',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _result() {
    if (_error != null) {
      return _panel(Icons.error_outline, Colors.redAccent, 'No se puede canjear', _error!);
    }
    final claim = _claim!;
    if (claim.status == RewardClaim.redeemed) {
      return _panel(
        Icons.check_circle,
        AppTheme.accentGreen,
        '¡Listo! Entrega el premio',
        '${claim.rewardText} para ${claim.userName}. Se descontaron ${claim.stampsRequired} sellos y este QR ya no sirve.',
      );
    }
    if (claim.status == RewardClaim.rejected) {
      return _panel(Icons.error_outline, Colors.redAccent, 'No se puede canjear', claim.rejectionReason ?? 'El premio fue rechazado.');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.card_giftcard, color: AppTheme.primary, size: 64),
          const SizedBox(height: 14),
          const Text('Premio válido', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          _row('Cliente', claim.userName),
          _row('Premio', claim.rewardText),
          _row('Sellos a descontar', '${claim.stampsRequired}'),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _confirming ? null : _confirm,
              icon: _confirming
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(_confirming ? 'Confirmando...' : 'Entregar premio', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _confirming ? null : _reset, child: const Text('Cancelar')),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _panel(IconData icon, Color color, String title, String text) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 72),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.35)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear otro QR'),
            ),
          ],
        ),
      ),
    );
  }
}
