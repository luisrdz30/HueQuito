import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/widgets/brand_logo.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:uuid/uuid.dart';

class BusinessQrScreen extends ConsumerStatefulWidget {
  const BusinessQrScreen({super.key});

  @override
  ConsumerState<BusinessQrScreen> createState() => _BusinessQrScreenState();
}

class _BusinessQrScreenState extends ConsumerState<BusinessQrScreen> {
  int _stampCount = 1;
  late Timer _timer;
  String _qrToken = const Uuid().v4();
  StreamSubscription<DocumentSnapshot>? _tokenSubscription;

  @override
  void initState() {
    super.initState();
    _listenToToken(_qrToken);

    // Refrescar automáticamente cada 60 seg si no ha sido escaneado aún
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        _generateNewToken();
      }
    });
  }

  void _listenToToken(String token) {
    _tokenSubscription?.cancel();
    try {
      _tokenSubscription = FirebaseFirestore.instance
          .collection('redeemed_qr_tokens')
          .doc(token)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.exists && mounted) {
              final data = snapshot.data();
              final stamps = data?['points'] ?? _stampCount;
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '¡Sello ($stamps) escaneado exitosamente! 🎉 Generando nuevo código...',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
              // Rotar de inmediato a un nuevo token para el siguiente comensal
              _generateNewToken();
            }
          });
    } catch (_) {}
  }

  void _generateNewToken() {
    final newToken = const Uuid().v4();
    if (mounted) {
      setState(() {
        _qrToken = newToken;
      });
      _listenToToken(newToken);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _tokenSubscription?.cancel();
    super.dispose();
  }

  void _increment() {
    if (_stampCount < 10) {
      setState(() => _stampCount++);
      _generateNewToken();
    }
  }

  void _decrement() {
    if (_stampCount > 1) {
      setState(() => _stampCount--);
      _generateNewToken();
    }
  }

  void _showHistoryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Historial de Sellos (Hoy)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: Text('Próximamente... aquí verás el historial detallado.', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final huecaAsync = ref.watch(myHuecaProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HueQuitoLogo.symbol(height: 28),
            SizedBox(width: 10),
            Text(
              'Mi QR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Generar Nuevo QR',
            onPressed: () {
              _generateNewToken();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✨ Nuevo código QR de un solo uso generado.'),
                  backgroundColor: AppTheme.primary,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'Historial de Sellos',
            onPressed: () {
              _showHistoryModal(context);
            },
          ),
        ],
      ),
      body: huecaAsync.when(
        data: (hueca) {
          if (hueca == null) {
            return const Center(child: Text('Hueca no encontrada'));
          }

          final managedBranch = ref.watch(currentManagedBranchProvider).value;
          final isOwner = ref.watch(isOwnerProvider).value ?? true;
          final branchId = (!isOwner && managedBranch != null) ? managedBranch.id : 'matriz';
          final branchName = (!isOwner && managedBranch != null) ? managedBranch.name : 'Matriz Principal';

          final qrData = jsonEncode({
            'type': 'points',
            'business_id': hueca.id,
            'branch_id': branchId,
            'branch_name': branchName,
            'points': _stampCount,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'token': _qrToken,
          });

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Gradient Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.storefront, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              branchName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'Generador Dinámico',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Código de un solo uso. Una vez escaneado por el cliente, se desactiva y regenera automáticamente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.white70,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Shifted up QR Card
                Transform.translate(
                  offset: const Offset(0, -50),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 240.0,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black87),
                            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black87),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_clock, color: Colors.green, size: 15),
                                SizedBox(width: 6),
                                Text(
                                  '1 Solo Uso • Se renueva al escanear',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.storefront, color: AppTheme.primary, size: 20),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    hueca.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Controls
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Text(
                          '¿Cuántos sellos entregarás?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildControlButton(Icons.remove, _decrement, isDark),
                            const SizedBox(width: 32),
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[850] : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  )
                                ],
                                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2), width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  '$_stampCount',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 32),
                            _buildControlButton(Icons.add, _increment, isDark),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed, bool isDark) {
    return Material(
      color: isDark ? Colors.grey[800] : Colors.grey[100],
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, color: AppTheme.primary, size: 28),
        ),
      ),
    );
  }
}
