import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

class QrSecretStickerScreen extends StatefulWidget {
  final String qrSecret;
  final String huecaId;
  final String? branchId;
  final String? branchName;
  final String? stickerName;
  final String? stickerImage;

  const QrSecretStickerScreen({
    super.key,
    required this.qrSecret,
    required this.huecaId,
    this.branchId,
    this.branchName,
    this.stickerName,
    this.stickerImage,
  });

  @override
  State<QrSecretStickerScreen> createState() => _QrSecretStickerScreenState();
}

class _QrSecretStickerScreenState extends State<QrSecretStickerScreen> {
  final GlobalKey _qrKey = GlobalKey();

  Future<void> _shareQr() async {
    try {
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/sticker_qr.png').create();
      await file.writeAsBytes(pngBytes);

      final locationName = widget.branchName != null ? ' en ${widget.branchName}' : '';
      await Share.shareXFiles([XFile(file.path)], text: '¡Encuentra nuestro Sticker Secreto$locationName en HueQuito y gana recompensas!');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al compartir QR: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchNameText = widget.branchName ?? 'Matriz';
    final stickerTitle = widget.stickerName ?? 'Sticker Secreto';

    // Generar el payload del QR en formato JSON estructurado
    final qrData = jsonEncode({
      'type': 'secret_sticker',
      'business_id': widget.huecaId,
      'branch_id': widget.branchId ?? 'matriz',
      'branch_name': branchNameText,
      'sticker_name': stickerTitle,
      'secret': widget.qrSecret,
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('QR Sticker Secreto', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: AppTheme.primary),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.branchName != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront, color: AppTheme.primary, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Local: $branchNameText',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                '¡Imprime este código QR!',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (widget.stickerImage != null && widget.stickerImage!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primary, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.network(
                        widget.stickerImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.star, color: Colors.amber, size: 36),
                      ),
                    ),
                  ),
                ),
              Text(
                'Sticker: $stickerTitle',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Pégalo en algún lugar secreto de tu local para que los usuarios lo escaneen y completen su cartilla.',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Widget a capturar como imagen
              RepaintBoundary(
                key: _qrKey,
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor, // Fondo sólido para la captura
                  padding: EdgeInsets.all(32),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 250.0,
                      backgroundColor: Colors.white,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 40),
              
              ElevatedButton.icon(
                onPressed: _shareQr,
                icon: Icon(Icons.share),
                label: Text('Compartir o Guardar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
