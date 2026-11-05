import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/reward_claim_repository.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/theme/theme.dart';

/// QR de un solo uso que el comensal muestra en el local para recibir su premio.
/// Los sellos se descuentan solo cuando el negocio lo escanea y confirma la entrega.
class RewardQrScreen extends ConsumerStatefulWidget {
  final Hueca hueca;
  final UserModel user;
  final String reward;
  final int targetStamps;
  final String lang;

  const RewardQrScreen({
    super.key,
    required this.hueca,
    required this.user,
    required this.reward,
    required this.targetStamps,
    required this.lang,
  });

  @override
  ConsumerState<RewardQrScreen> createState() => _RewardQrScreenState();
}

class _RewardQrScreenState extends ConsumerState<RewardQrScreen> {
  RewardClaim? _claim;
  String? _error;
  StreamSubscription<RewardClaim?>? _sub;
  Timer? _ticker;

  bool get _isEs => widget.lang == 'es';

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _createClaim();
  }

  Future<void> _createClaim() async {
    await _sub?.cancel();
    if (!mounted) return;
    setState(() {
      _claim = null;
      _error = null;
    });
    try {
      final repo = ref.read(rewardClaimRepositoryProvider);
      final id = await repo.create(
        huecaId: widget.hueca.id,
        huecaName: widget.hueca.name,
        userId: widget.user.uid,
        userName: widget.user.name,
        rewardText: widget.reward,
        stampsRequired: widget.targetStamps,
      );
      _sub = repo.watch(id).listen((claim) {
        if (mounted && claim != null) setState(() => _claim = claim);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = _isEs ? 'No se pudo generar el QR. Revisa tu conexión.' : 'Could not create the QR. Check your connection.');
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    // Si sale sin canjear, el QR deja de servir
    final claim = _claim;
    if (claim != null && claim.status == RewardClaim.pending) {
      ref.read(rewardClaimRepositoryProvider).cancel(claim.id).catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEs ? 'Reclamar premio' : 'Claim reward')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [_buildBody(context)],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) return _message(Icons.wifi_off, Colors.redAccent, _error!, retry: true);
    final claim = _claim;
    if (claim == null) {
      return const Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(color: AppTheme.primary));
    }

    switch (claim.status) {
      case RewardClaim.redeemed:
        return _redeemed(context, claim);
      case RewardClaim.rejected:
        return _message(
          Icons.error_outline,
          Colors.redAccent,
          claim.rejectionReason ?? (_isEs ? 'No se pudo canjear este premio.' : 'This reward could not be redeemed.'),
          retry: true,
        );
      case RewardClaim.confirming:
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(height: 16),
              Text(_isEs ? 'Confirmando tu premio...' : 'Confirming your reward...'),
            ],
          ),
        );
    }

    if (claim.isExpired()) {
      return _message(
        Icons.timer_off_outlined,
        Colors.orange,
        _isEs ? 'Este QR venció. Tus sellos siguen intactos.' : 'This QR expired. Your stamps are still safe.',
        retry: true,
      );
    }
    return _qr(context, claim);
  }

  Widget _qr(BuildContext context, RewardClaim claim) {
    final left = claim.expiresAt.difference(DateTime.now());
    final minutes = left.inMinutes;
    final seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
    return Column(
      children: [
        Text(
          _isEs ? 'Muestra este QR en ${widget.hueca.name}' : 'Show this QR at ${widget.hueca.name}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          _isEs ? 'El personal lo escanea y te entrega tu premio.' : 'The staff scans it and gives you your reward.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: QrImageView(data: claim.qrData, size: 240, backgroundColor: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          _isEs ? 'Premio: ${widget.reward}' : 'Reward: ${widget.reward}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          _isEs
              ? 'Se descontarán ${widget.targetStamps} sellos solo cuando el local lo confirme.'
              : '${widget.targetStamps} stamps are deducted only when the place confirms it.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer_outlined, size: 18, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              _isEs ? 'Vence en $minutes:$seconds' : 'Expires in $minutes:$seconds',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _redeemed(BuildContext context, RewardClaim claim) {
    final remaining = claim.stampsRemaining ?? 0;
    return Column(
      children: [
        const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 72),
        const SizedBox(height: 12),
        Text(
          _isEs ? '¡Premio entregado!' : 'Reward delivered!',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _isEs ? 'Tu premio en ${claim.huecaName}: ${claim.rewardText}.' : 'Your reward at ${claim.huecaName}: ${claim.rewardText}.',
          textAlign: TextAlign.center,
        ),
        if (remaining > 0) ...[
          const SizedBox(height: 14),
          Text(
            _isEs
                ? '⭐ Tu siguiente cartilla ya tiene $remaining ${remaining == 1 ? 'sello' : 'sellos'}.'
                : '⭐ Your next card already has $remaining ${remaining == 1 ? 'stamp' : 'stamps'}.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
        const SizedBox(height: 22),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_isEs ? 'Listo' : 'Done'),
        ),
      ],
    );
  }

  Widget _message(IconData icon, Color color, String text, {bool retry = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, color: color, size: 64),
          const SizedBox(height: 14),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          if (retry) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createClaim,
              child: Text(_isEs ? 'Generar otro QR' : 'Create another QR'),
            ),
          ],
        ],
      ),
    );
  }
}
