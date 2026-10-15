import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  Map<String, dynamic>? _scannedData;
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _scannedData != null) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final code = barcodes.first.rawValue!;
      setState(() {
        _isProcessing = true;
      });
      
      // Try parsing JSON data
      try {
        final parsed = jsonDecode(code);
        setState(() {
          _scannedData = parsed;
          _isProcessing = false;
        });
      } catch (e) {
        // If it's not JSON, treat it as unknown
        setState(() {
          _scannedData = {'type': 'unknown', 'raw': code};
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _saveScannedData() async {
    if (_scannedData == null) return;
    
    setState(() => _isProcessing = true);
    
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final user = await userRepo.getCurrentUser();
      if (user == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Inicia sesión para guardar sellos')));
        _resetScanner();
        return;
      }
      
      if (_scannedData!['type'] == 'points') {
        final huecaId = _scannedData!['business_id'];
        final stamps = _scannedData!['points'];
        final branchId = _scannedData!['branch_id'] ?? 'matriz';
        final branchName = _scannedData!['branch_name'] ?? 'Matriz Principal';
        
        final currentStamps = (user.gamification['huecaStamps'] ?? {})[huecaId] ?? 0;
        final currentPoints = user.gamification['points'] ?? 0;
        
        Map<String, dynamic> updatedGamification = Map.from(user.gamification);
        updatedGamification['huecaStamps'] = Map<String, dynamic>.from(user.gamification['huecaStamps'] ?? {});
        updatedGamification['huecaStamps'][huecaId] = currentStamps + stamps;
        updatedGamification['points'] = currentPoints + (stamps * 10);
        
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'gamification': updatedGamification
        });
        
        await FirebaseFirestore.instance.collection('huecas').doc(huecaId).collection('stamp_history').add({
          'userId': user.uid,
          'stamps': stamps,
          'branchId': branchId,
          'branchName': branchName,
          'date': FieldValue.serverTimestamp(),
        });
        
        await FirebaseFirestore.instance.collection('huecas').doc(huecaId).update({
          'metrics.stampsGiven': FieldValue.increment(stamps)
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('¡Sello de $branchName guardado exitosamente!'),
            backgroundColor: Colors.green,
          ));
        }
      } else if (_scannedData!['type'] == 'secret_sticker' || _scannedData!['type'] == 'cromo') {
        final huecaId = _scannedData!['business_id'] ?? '';
        final branchId = _scannedData!['branch_id'] ?? 'matriz';
        final branchName = _scannedData!['branch_name'] ?? 'Matriz Principal';
        final stickerName = _scannedData!['sticker_name'] ?? _scannedData!['cromo_id'] ?? 'Sticker Secreto';
        
        final stickerKey = '${huecaId}_$branchId';
        final currentPoints = user.gamification['points'] ?? 0;
        
        Map<String, dynamic> updatedGamification = Map.from(user.gamification);
        List<dynamic> collected = List.from(user.gamification['collectedStickers'] ?? []);
        bool isNew = !collected.contains(stickerKey);
        if (isNew) {
          collected.add(stickerKey);
          updatedGamification['points'] = currentPoints + 50; // +50 bonus points
        }
        updatedGamification['collectedStickers'] = collected;
        
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'gamification': updatedGamification
        });
        
        if (huecaId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('huecas').doc(huecaId).collection('sticker_history').add({
            'userId': user.uid,
            'branchId': branchId,
            'branchName': branchName,
            'stickerName': stickerName,
            'date': FieldValue.serverTimestamp(),
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isNew 
                ? '¡Nuevo sticker secreto "$stickerName" coleccionado! (+50 pts)' 
                : '¡Sticker "$stickerName" registrado!'),
            backgroundColor: Colors.green,
          ));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
    
    _resetScanner();
  }

  void _resetScanner() {
    setState(() {
      _scannedData = null;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera feed
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),
          
          // Scrims
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
          ),
          
          // Header controls
          Positioned(
            top: 50, left: 16, right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      Icon(Icons.qr_code_scanner, color: AppTheme.primary, size: 18),
                      SizedBox(width: 8),
                      Text('Apunta al QR del puesto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _controller.toggleTorch(),
                      child: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: Icon(Icons.flash_on, color: Colors.white, size: 20))
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _controller.switchCamera(),
                      child: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: Icon(Icons.flip_camera_ios, color: Colors.white, size: 20))
                    ),
                  ],
                )
              ],
            ),
          ),
          
          // Viewfinder reticle (only when not scanned)
          if (_scannedData == null)
            Center(
              child: Container(
                width: 250, height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Center(child: Container(width: 50, height: 50, decoration: BoxDecoration(border: Border.all(color: AppTheme.primary.withOpacity(0.5), width: 1), shape: BoxShape.circle))),
                    Center(child: Icon(Icons.center_focus_strong, color: AppTheme.primary.withOpacity(0.5), size: 40)),
                    // Laser (visual only)
                    Positioned(
                      top: 120, left: 10, right: 10,
                      child: Container(height: 2, decoration: BoxDecoration(color: AppTheme.primary, boxShadow: [BoxShadow(color: AppTheme.primary, blurRadius: 10)])),
                    ),
                  ],
                ),
              ),
            ),
            
          if (_scannedData == null)
            Positioned(
              bottom: 120, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.keyboard, color: AppTheme.primary, size: 18),
                      SizedBox(width: 8),
                      Text('Ingresar código manual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          
          // Detection Result Sheet
          if (_scannedData != null)
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.tertiary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [Icon(Icons.circle, color: AppTheme.tertiary, size: 8), SizedBox(width: 4), Text('QR CONFIRMADO', style: TextStyle(color: AppTheme.tertiary, fontSize: 10, fontWeight: FontWeight.bold))]),
                        ),
                        Row(children: [Icon(Icons.location_on, color: AppTheme.secondary, size: 12), SizedBox(width: 4), Text('GPS validado', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), fontSize: 10))]),
                      ],
                    ),
                    SizedBox(height: 12),
                    
                    // Specific UI depending on QR payload
                    if (_scannedData!['type'] == 'points') ...[
                      Row(
                        children: [
                          Container(width: 48, height: 48, decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.restaurant, color: AppTheme.primary)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_scannedData!['branch_name'] != null ? 'Local: ${_scannedData!['branch_name']}' : 'Local ID: ${_scannedData!['business_id']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('Consumo registrado', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), fontSize: 12)),
                              ],
                            ),
                          )
                        ],
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[100]), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.secondary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.stars, color: AppTheme.secondary, size: 20)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('+${_scannedData!['points']} Puntos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('Añadidos a tu Pasaporte Gastronómico', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_scannedData!['type'] == 'cromo' || _scannedData!['type'] == 'secret_sticker') ...[
                      Row(
                        children: [
                          Container(width: 48, height: 48, decoration: BoxDecoration(color: AppTheme.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.military_tech, color: AppTheme.secondary)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('¡Has encontrado un Sticker Secreto!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(
                                  _scannedData!['branch_name'] != null
                                      ? 'Local: ${_scannedData!['branch_name']}'
                                      : 'Sticker exclusivo descubierto',
                                  style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[100]), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.card_giftcard, color: AppTheme.primary, size: 20)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${_scannedData!['sticker_name'] ?? _scannedData!['cromo_id'] ?? "Sticker Secreto"} (+50 pts)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('Se añadirá a tu colección de cromos', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text('QR no reconocido por el sistema Hue-Quito.', style: TextStyle(color: Colors.red)),
                      Text('Contenido: ${_scannedData!['raw']}', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                    
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveScannedData,
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.verified), SizedBox(width: 8), Text('Canjear y Guardar')]),
                      ),
                    ),
                    SizedBox(height: 8),
                    GestureDetector(
                      onTap: _resetScanner,
                      child: Center(child: Text('¿No es este puesto? Volver a enfocar', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), fontSize: 12, decoration: TextDecoration.underline))),
                    ),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}
