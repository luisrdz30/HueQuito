import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hue_quito/theme/theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                  child: const Row(
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
                      child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: const Icon(Icons.flash_on, color: Colors.white, size: 20))
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _controller.switchCamera(),
                      child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 20))
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
                      child: Container(height: 2, decoration: BoxDecoration(color: AppTheme.primary, boxShadow: const [BoxShadow(color: AppTheme.primary, blurRadius: 10)])),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
                  child: const Row(
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.tertiary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: const Row(children: [Icon(Icons.circle, color: AppTheme.tertiary, size: 8), SizedBox(width: 4), Text('QR CONFIRMADO', style: TextStyle(color: AppTheme.tertiary, fontSize: 10, fontWeight: FontWeight.bold))]),
                        ),
                        const Row(children: [Icon(Icons.location_on, color: AppTheme.secondary, size: 12), SizedBox(width: 4), Text('GPS validado', style: TextStyle(color: AppTheme.textMedium, fontSize: 10))]),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Specific UI depending on QR payload
                    if (_scannedData!['type'] == 'points') ...[
                      Row(
                        children: [
                          Container(width: 48, height: 48, decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.restaurant, color: AppTheme.primary)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Local ID: ${_scannedData!['business_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const Text('Consumo registrado', style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.secondary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.stars, color: AppTheme.secondary, size: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('+${_scannedData!['points']} Puntos', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const Text('Añadidos a tu Pasaporte Gastronómico', style: TextStyle(color: AppTheme.textMedium, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_scannedData!['type'] == 'cromo') ...[
                      Row(
                        children: [
                          Container(width: 48, height: 48, decoration: BoxDecoration(color: AppTheme.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.military_tech, color: AppTheme.secondary)),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('¡Has encontrado un cromo secreto!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('Cromo desbloqueado en el local', style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.card_giftcard, color: AppTheme.primary, size: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Cromo: ${_scannedData!['cromo_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const Text('Ve a la pestaña Álbum para verlo', style: TextStyle(color: AppTheme.textMedium, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const Text('QR no reconocido por el sistema Hue-Quito.', style: TextStyle(color: Colors.red)),
                      Text('Contenido: ${_scannedData!['raw']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                    
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _resetScanner,
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.verified), SizedBox(width: 8), Text('Aceptar y continuar')]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _resetScanner,
                      child: const Center(child: Text('¿No es este puesto? Volver a enfocar', style: TextStyle(color: AppTheme.textMedium, fontSize: 12, decoration: TextDecoration.underline))),
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
