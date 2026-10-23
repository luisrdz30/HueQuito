import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    String? rawCode;
    for (final b in barcodes) {
      final val = b.rawValue ?? b.displayValue;
      if (val != null && val.trim().isNotEmpty) {
        rawCode = val.trim();
        break;
      }
    }
    if (rawCode == null || rawCode.isEmpty) return;

    final lang = ref.read(settingsProvider).language;
    final isEn = lang == 'en';

    Map<String, dynamic>? parsed;
    try {
      final decoded = jsonDecode(rawCode);
      if (decoded is Map<String, dynamic>) {
        parsed = decoded;
      }
    } catch (_) {}

    // Si no es JSON estructurado, verificar si coincide con el secreto de algún cromo en la base de datos
    if (parsed == null) {
      final huecasList = ref.read(huecasProvider).value ?? [];
      Hueca? matchedHueca;
      String matchedBranchId = 'matriz';
      String matchedBranchName = isEn ? 'Main Branch' : 'Matriz Principal';
      String matchedStickerName = isEn ? 'Secret Sticker' : 'Sticker Secreto';

      for (final h in huecasList) {
        final s = h.secretSticker;
        final sSecret = s['qrSecret']?.toString().trim() ?? '';
        final sCode = s['code']?.toString().trim() ?? '';
        final sId = s['id']?.toString().trim() ?? '';

        if ((sSecret.isNotEmpty && sSecret == rawCode) ||
            (sCode.isNotEmpty && sCode == rawCode) ||
            (sId.isNotEmpty && sId == rawCode) ||
            h.id.trim() == rawCode) {
          matchedHueca = h;
          if (s['name'] is Map) {
            matchedStickerName = s['name'][lang]?.toString() ?? s['name']['es']?.toString() ?? matchedStickerName;
          } else if (s['name'] != null && s['name'].toString().isNotEmpty) {
            matchedStickerName = s['name'].toString();
          }
          break;
        }

        for (final b in h.branches) {
          final bs = b.secretSticker;
          if (bs != null) {
            final bsSecret = bs['qrSecret']?.toString().trim() ?? '';
            final bsCode = bs['code']?.toString().trim() ?? '';
            final bsId = bs['id']?.toString().trim() ?? '';
            if ((bsSecret.isNotEmpty && bsSecret == rawCode) ||
                (bsCode.isNotEmpty && bsCode == rawCode) ||
                (bsId.isNotEmpty && bsId == rawCode)) {
              matchedHueca = h;
              matchedBranchId = b.id;
              matchedBranchName = b.name;
              if (bs['name'] is Map) {
                matchedStickerName = bs['name'][lang]?.toString() ?? bs['name']['es']?.toString() ?? matchedStickerName;
              } else if (bs['name'] != null && bs['name'].toString().isNotEmpty) {
                matchedStickerName = bs['name'].toString();
              }
              break;
            }
          }
        }
        if (matchedHueca != null) break;
      }

      if (matchedHueca != null) {
        parsed = {
          'type': 'secret_sticker',
          'business_id': matchedHueca.id,
          'branch_id': matchedBranchId,
          'branch_name': matchedBranchName,
          'sticker_name': matchedStickerName,
          'secret': rawCode,
        };
      } else if (rawCode.toLowerCase().contains('sticker') ||
          rawCode.toLowerCase().contains('cromo') ||
          rawCode.toLowerCase().contains('secreto')) {
        parsed = {
          'type': 'secret_sticker',
          'business_id': '',
          'branch_id': 'matriz',
          'branch_name': isEn ? 'Secret Spot' : 'Puesto Secreto',
          'sticker_name': isEn ? 'Secret Sticker' : 'Sticker Secreto',
          'secret': rawCode,
        };
      } else {
        parsed = {'type': 'unknown', 'raw': rawCode};
      }
    }

    setState(() {
      _scannedData = parsed;
      _isProcessing = false;
    });
  }

  Future<void> _saveScannedData() async {
    if (_scannedData == null) return;
    final lang = ref.read(settingsProvider).language;
    final isEn = lang == 'en';
    
    setState(() => _isProcessing = true);
    
    try {
      // Validar si la hueca está confirmada por administración y activa
      final targetHuecaId = _scannedData!['business_id']?.toString() ?? '';
      if (targetHuecaId.isNotEmpty) {
        final huecasList = ref.read(huecasProvider).value ?? [];
        final matchedHueca = huecasList.where((h) => h.id == targetHuecaId).firstOrNull;
        if (matchedHueca != null && (!matchedHueca.isSectorConfirmed || !matchedHueca.isActive)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isEn
                  ? 'This spot is pending admin confirmation. Stamps cannot be recorded yet.'
                  : 'Esta hueca está pendiente de confirmación por administración. Los sellos no están habilitados aún.'),
              backgroundColor: Colors.amber.shade900,
            ));
          }
          _resetScanner();
          return;
        }
      }

      // Validación de QR de UN SOLO USO para sellos/puntos
      if (_scannedData!['type'] == 'points') {
        final token = _scannedData!['token']?.toString();
        if (token == null || token.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isEn
                  ? 'Invalid QR code. Please request a new code from the store.'
                  : 'Código QR no válido. Solicita al negocio generar uno nuevo.'),
              backgroundColor: Colors.red.shade700,
            ));
          }
          _resetScanner();
          return;
        }

        // 1. Verificar expiración por timestamp (máx 10 minutos)
        final timestamp = (_scannedData!['timestamp'] as num?)?.toInt();
        if (timestamp != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - timestamp > 600000) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(isEn
                    ? 'This QR code has expired. Ask the store for a fresh code.'
                    : 'Este código QR ha expirado. Pide al negocio que genere uno nuevo.'),
                backgroundColor: Colors.amber.shade900,
              ));
            }
            _resetScanner();
            return;
          }
        }

        // 2. Verificar en SharedPreferences local si este dispositivo ya lo canjeó
        final prefs = await SharedPreferences.getInstance();
        final localUsed = prefs.getStringList('redeemed_qr_tokens') ?? [];
        if (localUsed.contains(token)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isEn
                  ? 'This QR code has already been scanned and used.'
                  : 'Este código QR ya fue utilizado y no puede ser usado de nuevo.'),
              backgroundColor: Colors.red.shade700,
            ));
          }
          _resetScanner();
          return;
        }

        // 3. Verificar en Firestore de forma atómica para que NADIE MÁS en otro teléfono pueda canjearlo
        bool alreadyUsedInCloud = false;
        try {
          final tokenRef = FirebaseFirestore.instance.collection('redeemed_qr_tokens').doc(token);
          final snap = await tokenRef.get();
          if (snap.exists) {
            alreadyUsedInCloud = true;
          } else {
            await tokenRef.set({
              'token': token,
              'huecaId': targetHuecaId,
              'branchId': _scannedData!['branch_id'] ?? 'matriz',
              'branchName': _scannedData!['branch_name'] ?? 'Matriz Principal',
              'points': (_scannedData!['points'] as num?)?.toInt() ?? 1,
              'redeemedBy': (await ref.read(userRepositoryProvider).getCurrentUser())?.uid ?? 'guest_local',
              'redeemedAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (_) {
          // Si no hay conexión o en tests headless, nos apoyamos en SharedPreferences
        }

        if (alreadyUsedInCloud) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(isEn
                        ? 'This QR code has already been used by someone else.'
                        : 'Este código QR ya fue utilizado por otro cliente y ya no es válido.'),
                  ),
                ],
              ),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 4),
            ));
          }
          _resetScanner();
          return;
        }

        // Registrar en local como usado
        localUsed.add(token);
        await prefs.setStringList('redeemed_qr_tokens', localUsed);
      }

      final userRepo = ref.read(userRepositoryProvider);
      final user = await userRepo.getCurrentUser();
      if (user == null) {
        // Modo Invitado: Guardar localmente en el dispositivo
        final guestGamification = await UserRepository.getGuestGamification();

        if (_scannedData!['type'] == 'points') {
          final huecaId = _scannedData!['business_id'];
          final stamps = (_scannedData!['points'] as num?)?.toInt() ?? 1;
          final branchId = _scannedData!['branch_id'] ?? 'matriz';
          final branchName = _scannedData!['branch_name'] ?? (isEn ? 'Main Branch' : 'Matriz Principal');

          final huecaStampsMap = Map<String, dynamic>.from(guestGamification['huecaStamps'] ?? {});
          final currentStamps = (huecaStampsMap[huecaId] as num?)?.toInt() ?? 0;
          final currentPoints = (guestGamification['points'] as num?)?.toInt() ?? 0;
          final currentTotal = (guestGamification['totalStamps'] as num?)?.toInt() ?? 0;

          huecaStampsMap[huecaId] = currentStamps + stamps;
          guestGamification['huecaStamps'] = huecaStampsMap;
          guestGamification['points'] = currentPoints + (stamps * 10);
          guestGamification['totalStamps'] = currentTotal + stamps;

          await UserRepository.saveGuestGamification(guestGamification);

          try {
            await FirebaseFirestore.instance.collection('huecas').doc(huecaId).collection('stamp_history').add({
              'userId': 'guest_local',
              'stamps': stamps,
              'branchId': branchId,
              'branchName': branchName,
              'date': FieldValue.serverTimestamp(),
            });
            await FirebaseFirestore.instance.collection('huecas').doc(huecaId).update({
              'metrics.stampsGiven': FieldValue.increment(stamps)
            });
          } catch (_) {}

          ref.invalidate(currentUserProvider);
          ref.invalidate(huecasProvider);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isEn
                  ? 'Stamp from $branchName saved on your device! (Log in to sync with the cloud)'
                  : '¡Sello de $branchName guardado en tu celular! (Inicia sesión para sincronizarlo a la nube)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ));
          }
        } else if (_scannedData!['type'] == 'secret_sticker' || _scannedData!['type'] == 'cromo') {
          final huecaId = _scannedData!['business_id'] ?? '';
          final branchId = _scannedData!['branch_id'] ?? 'matriz';
          final branchName = _scannedData!['branch_name'] ?? (isEn ? 'Main Branch' : 'Matriz Principal');
          final stickerName = _scannedData!['sticker_name'] ?? _scannedData!['cromo_id'] ?? (isEn ? 'Secret Sticker' : 'Sticker Secreto');

          final stickerKey = '${huecaId}_$branchId';
          final secret = _scannedData!['secret']?.toString().trim() ?? '';
          final currentPoints = (guestGamification['points'] as num?)?.toInt() ?? 0;
          List<dynamic> collected = List.from(guestGamification['collectedStickers'] ?? []);
          bool isNew = !collected.contains(stickerKey) && (huecaId.isEmpty || !collected.contains(huecaId));
          if (isNew) {
            guestGamification['points'] = currentPoints + 50;
          }
          if (!collected.contains(stickerKey)) collected.add(stickerKey);
          if (huecaId.isNotEmpty && !collected.contains(huecaId)) collected.add(huecaId);
          if (secret.isNotEmpty && !collected.contains(secret)) collected.add(secret);
          guestGamification['collectedStickers'] = collected;

          await UserRepository.saveGuestGamification(guestGamification);

          if (huecaId.isNotEmpty) {
            try {
              await FirebaseFirestore.instance.collection('huecas').doc(huecaId).collection('sticker_history').add({
                'userId': 'guest_local',
                'branchId': branchId,
                'branchName': branchName,
                'stickerName': stickerName,
                'date': FieldValue.serverTimestamp(),
              });
            } catch (_) {}
          }

          ref.invalidate(currentUserProvider);
          ref.invalidate(huecasProvider);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isNew
                  ? (isEn
                      ? 'New secret sticker "$stickerName" saved on device! (+50 pts)'
                      : '¡Nuevo sticker secreto "$stickerName" guardado en tu celular! (+50 pts)')
                  : (isEn
                      ? 'Sticker "$stickerName" already recorded!'
                      : '¡Sticker "$stickerName" ya registrado!')),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ));
          }
        }
        _resetScanner();
        return;
      }

      if (_scannedData!['type'] == 'points') {
        final huecaId = _scannedData!['business_id']?.toString().trim() ?? '';
        final stamps = (_scannedData!['points'] as num?)?.toInt() ?? 1;
        final branchId = _scannedData!['branch_id']?.toString().trim() ?? 'matriz';
        final branchName = _scannedData!['branch_name'] ?? (isEn ? 'Main Branch' : 'Matriz Principal');
        
        final huecaStampsMap = Map<String, dynamic>.from(user.gamification['huecaStamps'] ?? {});
        final currentStamps = (huecaStampsMap[huecaId] as num?)?.toInt() ?? 0;
        final currentPoints = (user.gamification['points'] as num?)?.toInt() ?? 0;
        final currentTotalStamps = ((user.gamification['totalStamps'] as num?)?.toInt() ?? 0);
        
        Map<String, dynamic> updatedGamification = Map.from(user.gamification);
        huecaStampsMap[huecaId] = currentStamps + stamps;
        updatedGamification['huecaStamps'] = huecaStampsMap;
        updatedGamification['points'] = currentPoints + (stamps * 10);
        updatedGamification['totalStamps'] = currentTotalStamps + stamps;
        
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

        // Refrescar estado Riverpod de inmediato para Mi Álbum y Perfil
        ref.invalidate(currentUserProvider);
        ref.invalidate(huecasProvider);
        ref.invalidate(allHuecasStreamProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEn
                ? 'Stamp from $branchName saved successfully!'
                : '¡Sello de $branchName guardado exitosamente!'),
            backgroundColor: Colors.green,
          ));
        }
      } else if (_scannedData!['type'] == 'secret_sticker' || _scannedData!['type'] == 'cromo') {
        final huecaId = _scannedData!['business_id'] ?? '';
        final branchId = _scannedData!['branch_id'] ?? 'matriz';
        final branchName = _scannedData!['branch_name'] ?? (isEn ? 'Main Branch' : 'Matriz Principal');
        final stickerName = _scannedData!['sticker_name'] ?? _scannedData!['cromo_id'] ?? (isEn ? 'Secret Sticker' : 'Sticker Secreto');
        
        final stickerKey = '${huecaId}_$branchId';
        final secret = _scannedData!['secret']?.toString().trim() ?? '';
        final currentPoints = (user.gamification['points'] as num?)?.toInt() ?? 0;
        
        Map<String, dynamic> updatedGamification = Map.from(user.gamification);
        List<dynamic> collected = List.from(user.gamification['collectedStickers'] ?? []);
        bool isNew = !collected.contains(stickerKey) && (huecaId.isEmpty || !collected.contains(huecaId));
        if (isNew) {
          updatedGamification['points'] = currentPoints + 50; // +50 bonus points
        }
        if (!collected.contains(stickerKey)) collected.add(stickerKey);
        if (huecaId.isNotEmpty && !collected.contains(huecaId)) collected.add(huecaId);
        if (secret.isNotEmpty && !collected.contains(secret)) collected.add(secret);
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

        // Refrescar estado Riverpod de inmediato
        ref.invalidate(currentUserProvider);
        ref.invalidate(huecasProvider);
        ref.invalidate(allHuecasStreamProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isNew 
                ? (isEn
                    ? 'New secret sticker "$stickerName" collected! (+50 pts)'
                    : '¡Nuevo sticker secreto "$stickerName" coleccionado! (+50 pts)')
                : (isEn
                    ? 'Sticker "$stickerName" recorded!'
                    : '¡Sticker "$stickerName" registrado!')),
            backgroundColor: Colors.green,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEn ? 'Error saving: $e' : 'Error al guardar: $e')),
        );
      }
    }
    
    _resetScanner();
  }

  void _resetScanner() {
    if (mounted) {
      setState(() {
        _scannedData = null;
        _isProcessing = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _isProcessing = false;
    _scannedData = null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final isEn = lang == 'en';

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
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
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
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_scanner, color: AppTheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        isEn ? 'Point at the stall QR' : 'Apunta al QR del puesto',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _controller.toggleTorch(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: const Icon(Icons.flash_on, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _controller.switchCamera(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 20),
                      ),
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
                    Center(
                      child: Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5), width: 1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(
                        Icons.center_focus_strong,
                        color: AppTheme.primary.withValues(alpha: 0.5),
                        size: 40,
                      ),
                    ),
                    // Laser (visual only)
                    Positioned(
                      top: 120, left: 10, right: 10,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          boxShadow: const [BoxShadow(color: AppTheme.primary, blurRadius: 10)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            

          
          // Detection Result Sheet
          if (_scannedData != null)
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.tertiary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.circle, color: AppTheme.tertiary, size: 8),
                              const SizedBox(width: 4),
                              Text(
                                isEn ? 'QR CONFIRMED' : 'QR CONFIRMADO',
                                style: const TextStyle(color: AppTheme.tertiary, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppTheme.secondary, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              isEn ? 'GPS validated' : 'GPS validado',
                              style: TextStyle(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Specific UI depending on QR payload
                    if (_scannedData!['type'] == 'points') ...[
                      Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.restaurant, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _scannedData!['branch_name'] != null
                                      ? '${isEn ? "Spot" : "Local"}: ${_scannedData!['branch_name']}'
                                      : 'ID: ${_scannedData!['business_id']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  isEn ? 'Dining recorded' : 'Consumo registrado',
                                  style: TextStyle(
                                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.secondary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.stars, color: AppTheme.secondary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEn
                                        ? '+${_scannedData!['points']} Points'
                                        : '+${_scannedData!['points']} Puntos',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    isEn
                                        ? 'Added to your Gastronomic Passport'
                                        : 'Añadidos a tu Pasaporte Gastronómico',
                                    style: TextStyle(
                                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_scannedData!['type'] == 'cromo' || _scannedData!['type'] == 'secret_sticker') ...[
                      Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.secondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.military_tech, color: AppTheme.secondary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEn ? 'You found a Secret Sticker!' : '¡Has encontrado un Sticker Secreto!',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  _scannedData!['branch_name'] != null
                                      ? '${isEn ? "Spot" : "Local"}: ${_scannedData!['branch_name']}'
                                      : (isEn ? 'Exclusive sticker unlocked' : 'Sticker exclusivo descubierto'),
                                  style: TextStyle(
                                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.card_giftcard, color: AppTheme.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_scannedData!['sticker_name'] ?? _scannedData!['cromo_id'] ?? (isEn ? "Secret Sticker" : "Sticker Secreto")} (+50 pts)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    isEn
                                        ? 'Will be added to your sticker album'
                                        : 'Se añadirá a tu colección de cromos',
                                    style: TextStyle(
                                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        isEn
                            ? 'QR code not recognized by HueQuito.'
                            : 'QR no reconocido por el sistema Hue-Quito.',
                        style: const TextStyle(color: Colors.red),
                      ),
                      Text(
                        '${isEn ? "Content" : "Contenido"}: ${_scannedData!['raw']}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveScannedData,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified),
                            const SizedBox(width: 8),
                            Text(isEn ? 'Redeem & Save' : 'Canjear y Guardar'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _resetScanner,
                      child: Center(
                        child: Text(
                          isEn
                              ? 'Not this spot? Refocus camera'
                              : '¿No es este puesto? Volver a enfocar',
                          style: TextStyle(
                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium),
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
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
