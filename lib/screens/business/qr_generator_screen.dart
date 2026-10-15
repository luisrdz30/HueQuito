import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart'; // Ensure you have intl package if not already. If not, I won't use it, just basic dart.

class BusinessQrScreen extends ConsumerStatefulWidget {
  const BusinessQrScreen({super.key});

  @override
  ConsumerState<BusinessQrScreen> createState() => _BusinessQrScreenState();
}

class _BusinessQrScreenState extends ConsumerState<BusinessQrScreen> {
  int _stampCount = 1;
  late Timer _timer;
  String _qrToken = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    // Refresh QR token every 30 seconds to prevent screenshots/fraud
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {
          _qrToken = const Uuid().v4();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _increment() {
    if (_stampCount < 10) {
      setState(() => _stampCount++);
    }
  }

  void _decrement() {
    if (_stampCount > 1) {
      setState(() => _stampCount--);
    }
  }

  void _showHistoryModal(BuildContext context) {
    // Basic history modal, can be populated properly from Firestore later
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(24),
          child: Column(
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
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final huecaAsync = ref.watch(myHuecaProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Text('Mi QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: Colors.white),
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
            return Center(child: Text('Hueca no encontrada'));
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
            physics: AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Gradient Section
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 80),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.only(
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
                      Text(
                        'Generador Dinámico',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'El código se actualiza cada 30 seg. para evitar fraudes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Shifted up QR Card
                Transform.translate(
                  offset: Offset(0, -50),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 30,
                            offset: Offset(0, 15),
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
                            eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black87),
                            dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black87),
                          ),
                          SizedBox(height: 24),
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.storefront, color: AppTheme.primary, size: 20),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    hueca.name,
                                    style: TextStyle(
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
                  offset: Offset(0, -20),
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
                        SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildControlButton(Icons.remove, _decrement, isDark),
                            SizedBox(width: 32),
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
                                    offset: Offset(0, 5),
                                  )
                                ],
                                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2), width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  '$_stampCount',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 32),
                            _buildControlButton(Icons.add, _increment, isDark),
                          ],
                        ),
                        SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed, bool isDark) {
    return Material(
      color: isDark ? Colors.grey[800] : Colors.grey[100],
      shape: CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          child: Icon(icon, color: AppTheme.primary, size: 28),
        ),
      ),
    );
  }
}
