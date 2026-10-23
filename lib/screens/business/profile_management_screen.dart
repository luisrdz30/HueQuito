import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/auth_provider.dart'
    hide currentUserProvider;
import 'package:hue_quito/providers/data_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/services/translation_service.dart';
import 'package:hue_quito/utils/image_picker_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:hue_quito/screens/business/qr_secret_sticker_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:hue_quito/screens/business/location_picker_screen.dart';
import 'package:hue_quito/services/geocoding_service.dart';
import 'package:hue_quito/widgets/delete_hueca_dialog.dart';
import 'dart:convert';

class BusinessProfileScreen extends ConsumerStatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  ConsumerState<BusinessProfileScreen> createState() =>
      _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends ConsumerState<BusinessProfileScreen> {
  void _showEditFieldDialog({
    required BuildContext context,
    required Hueca hueca,
    required String title,
    required String fieldKey,
    required String currentValue,
    bool needsTranslation = false,
    bool isNumber = false,
    HuecaBranch? targetBranch,
  }) {
    final TextEditingController _controller = TextEditingController(
      text: currentValue,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editar $title',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  maxLines: needsTranslation ? 4 : 1,
                  keyboardType: isNumber
                      ? TextInputType.number
                      : TextInputType.text,
                  decoration: InputDecoration(
                    hintText: 'Escribe aquí...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final newValue = _controller.text.trim();
                      if (newValue.isEmpty) return;

                      Navigator.pop(dialogContext); // Close input modal

                      if (targetBranch != null && fieldKey == 'secretSticker.name') {
                        // Guardar nombre del sticker para la sucursal específica
                        List<HuecaBranch> currentBranches = List.from(hueca.allBranches);
                        final idx = currentBranches.indexWhere((b) => b.id == targetBranch.id);
                        if (idx != -1) {
                          Map<String, dynamic> stickerMap = Map.from(currentBranches[idx].secretSticker ?? {});
                          stickerMap['name'] = newValue;
                          if (stickerMap['qrSecret'] == null || stickerMap['qrSecret'].toString().isEmpty) {
                            stickerMap['qrSecret'] = '${hueca.id}_${targetBranch.id}_sticker';
                          }
                          currentBranches[idx] = HuecaBranch(
                            id: currentBranches[idx].id,
                            name: currentBranches[idx].name,
                            address: currentBranches[idx].address,
                            sector: currentBranches[idx].sector,
                            location: currentBranches[idx].location,
                            phone: currentBranches[idx].phone,
                            schedule: currentBranches[idx].schedule,
                            managerEmail: currentBranches[idx].managerEmail,
                            secretSticker: stickerMap,
                          );
                          await FirebaseFirestore.instance
                              .collection('huecas')
                              .doc(hueca.id)
                              .update({'branches': currentBranches.map((b) => b.toMap()).toList()});
                          ref.invalidate(huecasProvider);
                          ref.invalidate(myHuecaProvider);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nombre de sticker guardado para la sucursal'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                        return;
                      }

                      if (needsTranslation) {
                        _showTranslationPreviewDialog(
                          context,
                          hueca,
                          fieldKey,
                          newValue,
                        );
                      } else {
                        // Save directly
                        if (fieldKey == 'image') {
                          List<String> images = List.from(hueca.images);
                          if (images.isNotEmpty) {
                            images[0] = newValue;
                          } else {
                            images.add(newValue);
                          }
                          await FirebaseFirestore.instance
                              .collection('huecas')
                              .doc(hueca.id)
                              .update({'images': images});
                        } else if (isNumber) {
                          await FirebaseFirestore.instance
                              .collection('huecas')
                              .doc(hueca.id)
                              .update({fieldKey: int.tryParse(newValue) ?? 0});
                        } else {
                          await FirebaseFirestore.instance
                              .collection('huecas')
                              .doc(hueca.id)
                              .update({fieldKey: newValue});
                        }
                        ref.invalidate(huecasProvider);
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Guardado exitosamente'),
                              backgroundColor: Colors.green,
                            ),
                          );
                      }
                    },
                    child: Text('Guardar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTagsEditDialog(BuildContext context, Hueca hueca) {
    List<String> currentTags = List.from(hueca.tags);
    final TextEditingController _tagController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Editar Tags (Máx 4)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: currentTags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              onDeleted: () {
                                setStateModal(() => currentTags.remove(tag));
                              },
                            ),
                          )
                          .toList(),
                    ),
                    if (currentTags.length < 4) ...[
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _tagController,
                              decoration: InputDecoration(
                                hintText: 'Añadir nuevo tag...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.add_circle,
                              color: AppTheme.primary,
                              size: 32,
                            ),
                            onPressed: () {
                              final text = _tagController.text.trim();
                              if (text.isNotEmpty &&
                                  currentTags.length < 4 &&
                                  !currentTags.contains(text)) {
                                setStateModal(() {
                                  currentTags.add(text);
                                  _tagController.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          ref.invalidate(huecasProvider);
                          await FirebaseFirestore.instance
                              .collection('huecas')
                              .doc(hueca.id)
                              .update({'tags': currentTags});
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Tags guardados'),
                                backgroundColor: Colors.green,
                              ),
                            );
                        },
                        child: Text('Guardar Cambios'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTranslationPreviewDialog(
    BuildContext context,
    Hueca hueca,
    String fieldKey,
    String newEsText,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return FutureBuilder<String>(
          future: TranslationService.translateEsToEn(newEsText),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Traduciendo automáticamente...',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }

            final newEnText = snapshot.data ?? newEsText;

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.g_translate, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text(
                    'Revisión de Traducción',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu texto (Español):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.only(top: 4, bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(newEsText),
                    ),
                    Text(
                      'Traducción generada (Inglés):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(newEnText),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Al confirmar, se guardarán ambos idiomas para mostrar a los turistas.',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Update Firebase
                    final docRef = FirebaseFirestore.instance
                        .collection('huecas')
                        .doc(hueca.id);

                    if (fieldKey.contains('.')) {
                      final parts = fieldKey.split('.');
                      if (parts.length == 2) {
                        await docRef.update({
                          '${parts[0]}.${parts[1]}.es': newEsText,
                          '${parts[0]}.${parts[1]}.en': newEnText,
                        });
                      }
                    } else {
                      await docRef.update({
                        '$fieldKey.es': newEsText,
                        '$fieldKey.en': newEnText,
                      });
                    }

                    Navigator.pop(dialogContext);
                    ref.invalidate(huecasProvider);
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Guardado exitosamente'),
                          backgroundColor: Colors.green,
                        ),
                      );
                  },
                  child: Text('Confirmar Cambios'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStaticQrDialog(
    BuildContext context,
    String qrSecret,
    String huecaId,
  ) {
    // Generate the static JSON payload for the secret sticker
    final qrData = jsonEncode({
      'type': 'secret_sticker',
      'business_id': huecaId,
      'secret': qrSecret,
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('QR Sticker Secreto', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Imprime este QR y colócalo en un lugar visible de tu local.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                color: Colors.white,
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _showScheduleEditDialog(
    BuildContext context,
    Hueca hueca, {
    HuecaBranch? targetBranch,
  }) {
    Map<String, String> currentSchedule = {};
    if (targetBranch != null && targetBranch.schedule.isNotEmpty) {
      currentSchedule = Map<String, String>.from(targetBranch.schedule);
    } else if (hueca.schedule is Map) {
      currentSchedule = Map<String, String>.from(hueca.schedule as Map);
    }
    final days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];

    // Ensure all days exist
    for (var day in days) {
      if (!currentSchedule.containsKey(day)) {
        currentSchedule[day] = '08:00 - 18:00';
      }
    }

    TimeOfDay parseTime(String timeStr, {required TimeOfDay defaultTime}) {
      try {
        final clean = timeStr.trim();
        final parts = clean.split(':');
        if (parts.length >= 2) {
          final h = int.parse(parts[0].trim());
          final m = int.parse(parts[1].trim().split(' ')[0]);
          return TimeOfDay(hour: h, minute: m);
        }
      } catch (_) {}
      return defaultTime;
    }

    String formatTime24(TimeOfDay t) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.access_time_filled, color: AppTheme.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              targetBranch != null
                                  ? 'Horario de Atención (${targetBranch.name})'
                                  : 'Horario de Atención de la Hueca',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Toca las horas para cambiarlas con el reloj interactivo',
                              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Barra de plantillas y atajos rápidos
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '⚡ Atajos Rápidos:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setStateModal(() {
                                      final baseSchedule = currentSchedule['Lunes'] != 'Cerrado'
                                          ? currentSchedule['Lunes']!
                                          : '09:00 - 18:00';
                                      for (int i = 0; i < 5; i++) {
                                        currentSchedule[days[i]] = baseSchedule;
                                      }
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Horario de lunes aplicado a Lun-Vie'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Copiar a Lun-Vie',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    setStateModal(() {
                                      final baseSchedule = currentSchedule['Lunes'] != 'Cerrado'
                                          ? currentSchedule['Lunes']!
                                          : '09:00 - 18:00';
                                      for (var d in days) {
                                        currentSchedule[d] = baseSchedule;
                                      }
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Horario aplicado a toda la semana'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Copiar a Todos',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildQuickTemplateChip('☀️ 08:00 - 17:00', '08:00 - 17:00', currentSchedule, setStateModal),
                              const SizedBox(width: 6),
                              _buildQuickTemplateChip('🍲 09:00 - 18:00', '09:00 - 18:00', currentSchedule, setStateModal),
                              const SizedBox(width: 6),
                              _buildQuickTemplateChip('🌆 10:00 - 20:00', '10:00 - 20:00', currentSchedule, setStateModal),
                              const SizedBox(width: 6),
                              _buildQuickTemplateChip('🌙 12:00 - 22:00', '12:00 - 22:00', currentSchedule, setStateModal),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Lista de 7 días con selectores táctiles
                  Expanded(
                    child: ListView.separated(
                      itemCount: days.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final day = days[index];
                        final rawSchedule = currentSchedule[day] ?? '08:00 - 18:00';
                        final isClosed = rawSchedule.trim().toLowerCase() == 'cerrado';

                        String startStr = '08:00';
                        String endStr = '18:00';

                        if (!isClosed) {
                          final parts = rawSchedule.split('-');
                          if (parts.length >= 2) {
                            startStr = parts[0].trim();
                            endStr = parts[1].trim();
                          }
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isClosed
                                  ? Colors.red.withValues(alpha: 0.25)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Nombre del día
                              SizedBox(
                                width: 85,
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isClosed ? Colors.blueGrey : null,
                                  ),
                                ),
                              ),

                              // Estado de Horas (o botón Cerrado)
                              Expanded(
                                child: isClosed
                                    ? InkWell(
                                        onTap: () {
                                          setStateModal(() {
                                            currentSchedule[day] = '09:00 - 18:00';
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFFECACA)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.lock_clock, size: 14, color: Color(0xFFDC2626)),
                                              SizedBox(width: 6),
                                              Text(
                                                'Cerrado (Toca para abrir)',
                                                style: TextStyle(
                                                  color: Color(0xFFDC2626),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Botón Hora Apertura
                                          InkWell(
                                            onTap: () async {
                                              final initial = parseTime(startStr, defaultTime: const TimeOfDay(hour: 8, minute: 0));
                                              final picked = await showTimePicker(
                                                context: context,
                                                initialTime: initial,
                                                helpText: 'HORA DE APERTURA ($day)',
                                                confirmText: 'ESTABLECER',
                                                cancelText: 'CANCELAR',
                                              );
                                              if (picked != null) {
                                                setStateModal(() {
                                                  currentSchedule[day] = '${formatTime24(picked)} - $endStr';
                                                });
                                              }
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.access_time, size: 13, color: AppTheme.primary),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    startStr,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 6),
                                            child: Text('a', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                          ),

                                          // Botón Hora Cierre
                                          InkWell(
                                            onTap: () async {
                                              final initial = parseTime(endStr, defaultTime: const TimeOfDay(hour: 18, minute: 0));
                                              final picked = await showTimePicker(
                                                context: context,
                                                initialTime: initial,
                                                helpText: 'HORA DE CIERRE ($day)',
                                                confirmText: 'ESTABLECER',
                                                cancelText: 'CANCELAR',
                                              );
                                              if (picked != null) {
                                                setStateModal(() {
                                                  currentSchedule[day] = '$startStr - ${formatTime24(picked)}';
                                                });
                                              }
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.amber.shade700),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.schedule, size: 13, color: Colors.amber.shade800),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    endStr,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),

                              // Switch / Toggle Cerrado
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isClosed ? 'Cerrado' : 'Abierto',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isClosed ? Colors.red : Colors.green.shade700,
                                    ),
                                  ),
                                  Switch(
                                    value: !isClosed,
                                    activeColor: Colors.green,
                                    inactiveThumbColor: Colors.red,
                                    inactiveTrackColor: Colors.red.shade100,
                                    onChanged: (val) {
                                      setStateModal(() {
                                        if (!val) {
                                          currentSchedule[day] = 'Cerrado';
                                        } else {
                                          currentSchedule[day] = '09:00 - 18:00';
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Botón Guardar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      onPressed: () async {
                        Navigator.pop(dialogContext);

                        if (targetBranch != null) {
                          // Actualizar solo el horario de la sucursal indicada
                          List<HuecaBranch> currentBranches = List.from(hueca.allBranches);
                          final idx = currentBranches.indexWhere((b) => b.id == targetBranch.id);
                          if (idx != -1) {
                            currentBranches[idx] = HuecaBranch(
                              id: currentBranches[idx].id,
                              name: currentBranches[idx].name,
                              address: currentBranches[idx].address,
                              sector: currentBranches[idx].sector,
                              location: currentBranches[idx].location,
                              phone: currentBranches[idx].phone,
                              schedule: currentSchedule,
                              managerEmail: currentBranches[idx].managerEmail,
                              secretSticker: currentBranches[idx].secretSticker,
                            );
                            await FirebaseFirestore.instance
                                .collection('huecas')
                                .doc(hueca.id)
                                .update({'branches': currentBranches.map((b) => b.toMap()).toList()});
                          }
                        } else {
                          // Actualizar horario general / matriz
                          List<HuecaBranch> currentBranches = List.from(hueca.allBranches);
                          if (currentBranches.isNotEmpty) {
                            currentBranches[0] = HuecaBranch(
                              id: currentBranches[0].id,
                              name: currentBranches[0].name,
                              address: currentBranches[0].address,
                              sector: currentBranches[0].sector,
                              location: currentBranches[0].location,
                              phone: currentBranches[0].phone,
                              schedule: currentSchedule,
                              managerEmail: currentBranches[0].managerEmail,
                              secretSticker: currentBranches[0].secretSticker,
                            );
                          }
                          await FirebaseFirestore.instance
                              .collection('huecas')
                              .doc(hueca.id)
                              .update({
                                'schedule': currentSchedule,
                                'branches': currentBranches.map((b) => b.toMap()).toList(),
                              });
                        }

                        ref.invalidate(huecasProvider);
                        ref.invalidate(myHuecaProvider);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(targetBranch != null
                                  ? 'Horario de ${targetBranch.name} guardado con éxito'
                                  : 'Horario guardado con éxito'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      child: const Text('Guardar Horario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickTemplateChip(
    String label,
    String timeRange,
    Map<String, String> schedule,
    StateSetter setStateModal,
  ) {
    return InkWell(
      onTap: () {
        setStateModal(() {
          final days = [
            'Lunes',
            'Martes',
            'Miércoles',
            'Jueves',
            'Viernes',
            'Sábado',
            'Domingo',
          ];
          for (int i = 0; i < 5; i++) {
            schedule[days[i]] = timeRange;
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blueGrey.shade200),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(
    BuildContext context,
    Hueca hueca,
    String fieldKey, {
    HuecaBranch? targetBranch,
  }) async {
    try {
      String pickerTitle = 'Foto de la Hueca';
      if (fieldKey.contains('mainDish')) {
        pickerTitle = 'Foto del Plato Estrella';
      } else if (fieldKey.contains('secretSticker')) {
        pickerTitle = 'Foto del Cromo Secreto';
      }

      final file = await ImagePickerHelper.showImageSourceDialog(
        context: context,
        title: pickerTitle,
        subtitle: 'Elige de dónde quieres cargar la imagen',
        imageQuality: 75,
        maxWidth: 1280,
      );

      if (file == null || !mounted) return;
      String fileName = '${hueca.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String folder = 'hueca_images';
      if (fieldKey.contains('mainDish')) folder = 'dish_images';
      if (fieldKey.contains('secretSticker')) folder = 'sticker_images';

      Reference storageRef = FirebaseStorage.instance.ref().child('$folder/$fileName');

      // Show loading safely
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        ),
      );

      try {
        UploadTask uploadTask = storageRef.putFile(file);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        final docRef = FirebaseFirestore.instance
            .collection('huecas')
            .doc(hueca.id);

        if (targetBranch != null && fieldKey.contains('secretSticker')) {
          // Guardar imagen del sticker para la sucursal específica
          List<HuecaBranch> currentBranches = List.from(hueca.allBranches);
          final idx = currentBranches.indexWhere((b) => b.id == targetBranch.id);
          if (idx != -1) {
            Map<String, dynamic> stickerMap = Map.from(currentBranches[idx].secretSticker ?? {});
            stickerMap['image'] = downloadUrl;
            if (stickerMap['qrSecret'] == null || stickerMap['qrSecret'].toString().isEmpty) {
              stickerMap['qrSecret'] = '${hueca.id}_${targetBranch.id}_sticker';
            }
            currentBranches[idx] = HuecaBranch(
              id: currentBranches[idx].id,
              name: currentBranches[idx].name,
              address: currentBranches[idx].address,
              sector: currentBranches[idx].sector,
              location: currentBranches[idx].location,
              phone: currentBranches[idx].phone,
              schedule: currentBranches[idx].schedule,
              managerEmail: currentBranches[idx].managerEmail,
              secretSticker: stickerMap,
            );
            await docRef.update({
              'branches': currentBranches.map((b) => b.toMap()).toList(),
            });
          }
        } else if (fieldKey == 'image') {
          List<String> images = List.from(hueca.images);
          if (images.isNotEmpty) {
            images[0] = downloadUrl;
          } else {
            images.add(downloadUrl);
          }
          await docRef.update({'images': images});
        } else if (fieldKey.startsWith('loyaltyCard.')) {
          final subKey = fieldKey.substring('loyaltyCard.'.length);
          Map<String, dynamic> updatedLoyalty = Map.from(hueca.loyaltyCard);
          updatedLoyalty[subKey] = downloadUrl;
          if (subKey == 'stampImage') {
            updatedLoyalty['image'] = downloadUrl;
          }
          await docRef.update({'loyaltyCard': updatedLoyalty});
        } else if (fieldKey.startsWith('mainDish.')) {
          final subKey = fieldKey.substring('mainDish.'.length);
          Map<String, dynamic> updatedDish = Map.from(hueca.mainDish);
          updatedDish[subKey] = downloadUrl;
          await docRef.update({'mainDish': updatedDish});
        } else if (fieldKey.contains('.')) {
          final parts = fieldKey.split('.');
          if (parts.length == 2) {
            await docRef.update({'${parts[0]}.${parts[1]}': downloadUrl});
          }
        } else {
          await docRef.update({fieldKey: downloadUrl});
        }

        if (mounted) {
          ref.invalidate(huecasProvider);
          ref.invalidate(myHuecaProvider);
          Navigator.of(context, rootNavigator: true).pop(); // close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imagen subida con éxito'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al subir: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de galería: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImagePreviewDialog(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    height: 260,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No se pudo cargar la imagen'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Cerrar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? imageUrl,
    bool isReadOnly = false,
    VoidCallback? onReadOnlyTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: (imageUrl != null && imageUrl.trim().isNotEmpty)
            ? GestureDetector(
                onTap: () {
                  _showImagePreviewDialog(context, imageUrl.trim(), title);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                      imageUrl.trim(),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isReadOnly ? Colors.grey.withOpacity(0.12) : AppTheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: isReadOnly ? Colors.grey[600] : AppTheme.primary),
                      ),
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              )
            : Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isReadOnly ? Colors.grey.withOpacity(0.12) : AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: isReadOnly ? Colors.grey[600] : AppTheme.primary),
              ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isReadOnly
                      ? (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)
                      : null,
                ),
              ),
            ),
            if (isReadOnly)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Solo Matriz',
                      style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        trailing: Icon(
          isReadOnly ? Icons.visibility_outlined : Icons.edit,
          color: isReadOnly ? Colors.grey[400] : Colors.grey,
          size: 20,
        ),
        onTap: isReadOnly
            ? () {
                if (onReadOnlyTap != null) {
                  onReadOnlyTap();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Solo el dueño o matriz principal puede modificar "$title". Tu perfil de sucursal es de solo lectura.'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            : onTap,
      ),
    );
  }

  Future<void> _updateLocationAndAddress(Hueca hueca, LocationPickerResult result) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('huecas').doc(hueca.id);
      final newGeoPoint = GeoPoint(result.location.latitude, result.location.longitude);
      
      List<HuecaBranch> currentBranches = List.from(hueca.allBranches);
      if (currentBranches.isNotEmpty) {
        currentBranches[0] = HuecaBranch(
          id: currentBranches[0].id,
          name: currentBranches[0].name,
          address: result.address.isNotEmpty ? result.address : currentBranches[0].address,
          sector: (result.sector != null && result.sector!.isNotEmpty) ? result.sector! : currentBranches[0].sector,
          location: newGeoPoint,
          phone: currentBranches[0].phone,
          schedule: currentBranches[0].schedule,
          managerEmail: currentBranches[0].managerEmail,
        );
      }

      final updateData = <String, dynamic>{
        'location': newGeoPoint,
        'branches': currentBranches.map((b) => b.toMap()).toList(),
      };
      if (result.address.isNotEmpty) {
        updateData['address'] = result.address;
      }
      if (result.sector != null && result.sector!.isNotEmpty) {
        updateData['sector'] = result.sector!;
      }

      await docRef.update(updateData);

      ref.invalidate(huecasProvider);
      ref.invalidate(myHuecaProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ubicación y dirección actualizadas: ${result.address}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar ubicación: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final huecaAsync = ref.watch(myHuecaProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Text(
              'Perfil de Hueca',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: huecaAsync.when(
        data: (hueca) {
          if (hueca == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && FirebaseAuth.instance.currentUser == null) {
                context.go('/login');
              }
            });
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.storefront_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'No se encontró un negocio vinculado a esta cuenta.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar Sesión / Cambiar Cuenta'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await ref.read(authRepositoryProvider).signOut();
                        ref.invalidate(currentUserProvider);
                        ref.invalidate(myHuecaProvider);
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          }
          final currentUser = FirebaseAuth.instance.currentUser;
          final userEmail = currentUser?.email?.trim().toLowerCase() ?? '';
          final isOwnerState = ref.watch(isOwnerProvider).value;
          final managedBranchState = ref.watch(currentManagedBranchProvider).value;

          bool isOwner = isOwnerState ?? (currentUser != null && hueca.ownerId == currentUser.uid);
          HuecaBranch? managedBranch = managedBranchState;
          if (!isOwner && managedBranch == null) {
            try {
              managedBranch = hueca.allBranches.firstWhere((b) =>
                  b.managerEmail != null &&
                  b.managerEmail!.trim().toLowerCase() == userEmail);
            } catch (_) {}
          }
          final bool isBranchManager = !isOwner && managedBranch != null;

          final desc = hueca.description is Map
              ? (hueca.description['es']?.toString() ?? '')
              : hueca.description.toString();
          final dishDesc = hueca.mainDish['description'] is Map
              ? (hueca.mainDish['description']['es']?.toString() ?? '')
              : hueca.mainDish['description']?.toString() ?? '';
          final dishName = hueca.mainDish['name'] is Map
              ? (hueca.mainDish['name']['es']?.toString() ?? '')
              : hueca.mainDish['name']?.toString() ?? '';
          final imageUrl = hueca.images.isNotEmpty
              ? hueca.images.first.toString()
              : '';

          final maxStamps = hueca.loyaltyCard['maxStamps'] ?? 8;
          final rewardText = hueca.loyaltyCard['rewardText'] is Map
              ? (hueca.loyaltyCard['rewardText']['es']?.toString() ?? '')
              : hueca.loyaltyCard['rewardText']?.toString() ?? '';
          final stampImage = hueca.loyaltyCard['stampImage']?.toString() ??
              (hueca.loyaltyCard['image']?.toString() ?? '');
          final rewardImage = hueca.loyaltyCard['rewardImage']?.toString() ?? '';

          // Sticker Secreto (propio de la sucursal si es encargado, o de la matriz si es dueño)
          final HuecaBranch? currentBranch = isBranchManager ? managedBranch : null;
          final String currentBranchName = currentBranch?.name ?? 'Sucursal';
          final Map<String, dynamic> activeSticker = currentBranch != null
              ? (currentBranch.secretSticker ?? {})
              : hueca.secretSticker;

          final stickerName = activeSticker['name'] is Map
              ? (activeSticker['name']['es']?.toString() ?? (isBranchManager ? 'Sticker $currentBranchName' : 'Sticker Secreto'))
              : (activeSticker['name']?.toString() ?? (isBranchManager ? 'Sticker $currentBranchName' : 'Sticker Secreto'));

          final stickerImage = activeSticker['image'] is Map
              ? (activeSticker['image']['es']?.toString() ?? '')
              : (activeSticker['image']?.toString() ?? '');

          final branchStickerQrSecret = activeSticker['qrSecret']?.toString() ??
              (currentBranch != null ? '${hueca.id}_${currentBranch.id}_sticker' : (hueca.loyaltyCard['qrSecret']?.toString() ?? 'default_secret'));

          final dishImage = hueca.mainDish['image'] is Map
              ? (hueca.mainDish['image']['es']?.toString() ?? '')
              : hueca.mainDish['image']?.toString() ?? '';

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(huecasProvider);
              ref.invalidate(myHuecaProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: imageUrl.isNotEmpty
                              ? NetworkImage(imageUrl)
                              : null,
                          backgroundColor: Colors.grey[300],
                          child: imageUrl.isEmpty
                              ? Icon(Icons.store, size: 50, color: Colors.white)
                              : null,
                        ),
                        if (isOwner)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: () {
                                _pickAndUploadImage(context, hueca, 'image');
                              },
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isBranchManager) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.shade700.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront, color: Colors.amber.shade900, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Encargado de: $currentBranchName',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 32),
                  Text(
                    'Información General',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  _buildProfileOption(
                    icon: Icons.photo_library,
                    title: 'Fotos de la Hueca (máx 5)',
                    subtitle: 'Gestionar galería y portada',
                    isReadOnly: !isOwner,
                    onTap: () => GoRouter.of(context).push('/business/gallery', extra: hueca.id),
                  ),
                  _buildProfileOption(
                    icon: Icons.store_mall_directory,
                    title: 'Mis Locales / Sucursales',
                    subtitle: isBranchManager
                        ? 'Local asignado: $currentBranchName'
                        : '${hueca.allBranches.length} locales registrados (Matriz y Sucursales)',
                    onTap: () => GoRouter.of(context).push('/business/branches', extra: hueca.id),
                  ),
                  _buildProfileOption(
                    icon: Icons.store,
                    title: 'Nombre de la Hueca',
                    subtitle: hueca.name,
                    isReadOnly: !isOwner,
                    onTap: () => _showEditFieldDialog(
                      context: context,
                      hueca: hueca,
                      title: 'Nombre',
                      fieldKey: 'name',
                      currentValue: hueca.name,
                    ),
                  ),
                  _buildProfileOption(
                    icon: Icons.description,
                    title: 'Descripción (Multilingüe)',
                    subtitle: desc.isEmpty ? 'Añade una descripción' : desc,
                    isReadOnly: !isOwner,
                    onTap: () => _showEditFieldDialog(
                      context: context,
                      hueca: hueca,
                      title: 'Descripción',
                      fieldKey: 'description',
                      currentValue: desc,
                      needsTranslation: true,
                    ),
                  ),
                  _buildProfileOption(
                    icon: Icons.location_on,
                    title: 'Dirección Escrita',
                    subtitle: hueca.address.isEmpty
                        ? 'Añadir dirección'
                        : hueca.address,
                    isReadOnly: !isOwner,
                    onTap: () => _showEditFieldDialog(
                      context: context,
                      hueca: hueca,
                      title: 'Dirección',
                      fieldKey: 'address',
                      currentValue: hueca.address,
                    ),
                  ),
                  _buildProfileOption(
                    icon: Icons.pin_drop,
                    title: 'Fijar Punto en el Mapa (GPS)',
                    subtitle: 'Coordenadas: ${hueca.location.latitude.toStringAsFixed(4)}, ${hueca.location.longitude.toStringAsFixed(4)}',
                    isReadOnly: !isOwner,
                    onTap: () async {
                      final result = await Navigator.push<LocationPickerResult>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocationPickerScreen(
                            initialLocation: LatLng(hueca.location.latitude, hueca.location.longitude),
                          ),
                        ),
                      );
                      if (result != null) {
                        _updateLocationAndAddress(hueca, result);
                      }
                    },
                  ),
                  _buildProfileOption(
                    icon: Icons.tag,
                    title: 'Etiquetas (Tags)',
                    subtitle: hueca.tags.isEmpty
                        ? 'No hay tags'
                        : hueca.tags.join(', '),
                    isReadOnly: !isOwner,
                    onTap: () => _showTagsEditDialog(context, hueca),
                  ),
                  SizedBox(height: 24),

                  _buildProfileOption(
                    icon: Icons.access_time,
                    title: isBranchManager
                        ? 'Horario de Atención ($currentBranchName)'
                        : 'Horario de Atención',
                    subtitle: isBranchManager
                        ? 'Toca para editar el horario de tu sucursal'
                        : 'Toca para editar tu horario',
                    onTap: () => _showScheduleEditDialog(
                      context,
                      hueca,
                      targetBranch: currentBranch,
                    ),
                  ),

                  SizedBox(height: 24),
                  Text(
                    'Plato Insignia',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  _buildProfileOption(
                    icon: Icons.restaurant_menu,
                    title: 'Nombre del Plato',
                    subtitle: dishName.isEmpty
                        ? 'Añade tu mejor plato'
                        : dishName,
                    isReadOnly: !isOwner,
                    onTap: () => _showEditFieldDialog(
                      context: context,
                      hueca: hueca,
                      title: 'Nombre del Plato',
                      fieldKey: 'mainDish.name',
                      currentValue: dishName,
                      needsTranslation: true,
                    ),
                  ),
                  _buildProfileOption(
                    icon: Icons.fastfood,
                    title: 'Descripción del Plato',
                    subtitle: dishDesc.isEmpty
                        ? 'Describe por qué es famoso'
                        : dishDesc,
                    isReadOnly: !isOwner,
                    onTap: () => _showEditFieldDialog(
                      context: context,
                      hueca: hueca,
                      title: 'Descripción del Plato',
                      fieldKey: 'mainDish.description',
                      currentValue: dishDesc,
                      needsTranslation: true,
                    ),
                  ),
                  _buildProfileOption(
                    icon: Icons.image,
                    title: 'Icono/Imagen del Plato',
                    subtitle: dishImage.isEmpty ? 'Subir imagen' : 'Toca para cambiar o previsualizar',
                    imageUrl: dishImage.isNotEmpty ? dishImage : null,
                    isReadOnly: !isOwner,
                    onTap: () {
                      if (dishImage.isNotEmpty) {
                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (bCtx) => SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.visibility, color: Colors.blue),
                                    title: const Text('Previsualizar imagen'),
                                    onTap: () {
                                      Navigator.pop(bCtx);
                                      _showImagePreviewDialog(
                                        context,
                                        dishImage,
                                        dishName.isNotEmpty ? dishName : 'Plato Insignia',
                                      );
                                    },
                                  ),
                                  if (isOwner)
                                    ListTile(
                                      leading: Icon(Icons.photo_library, color: AppTheme.primary),
                                      title: const Text('Cambiar imagen'),
                                      onTap: () {
                                        Navigator.pop(bCtx);
                                        _pickAndUploadImage(context, hueca, 'mainDish.image');
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else {
                        _pickAndUploadImage(context, hueca, 'mainDish.image');
                      }
                    },
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Fidelización y Premios',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  _buildProfileOption(
                    icon: Icons.confirmation_number,
                    title: 'Número de Sellos Necesarios',
                    subtitle: '$maxStamps sellos',
                    isReadOnly: !isOwner,
                    onTap: () => _showEditFieldDialog(
                      context: context,
                      hueca: hueca,
                      title: 'Máx Sellos',
                      fieldKey: 'loyaltyCard.maxStamps',
                      currentValue: maxStamps.toString(),
                      isNumber: true,
                    ),
                  ),
                  _buildProfileOption(
                    icon: Icons.card_giftcard,
                    title: 'Premio por Cartilla Llena',
                    subtitle: rewardText.isEmpty
                        ? 'Define un premio'
                        : rewardText,
                    isReadOnly: !isOwner,
                    onTap: () => _showEditFieldDialog(
                      context: context,
                      hueca: hueca,
                      title: 'Premio Final',
                      fieldKey: 'loyaltyCard.rewardText',
                      currentValue: rewardText,
                      needsTranslation: true,
                    ),
                  ),
                  _buildProfileOption(
                    icon: Icons.stars,
                    title: 'Imagen del Sello / Sticker Normal',
                    subtitle: stampImage.isEmpty
                        ? 'Subir diseño del sello'
                        : 'Toca para cambiar o previsualizar',
                    imageUrl: stampImage.isNotEmpty ? stampImage : null,
                    isReadOnly: !isOwner,
                    onTap: () {
                      if (stampImage.isNotEmpty) {
                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (bCtx) => SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.visibility, color: Colors.blue),
                                    title: const Text('Previsualizar sello'),
                                    onTap: () {
                                      Navigator.pop(bCtx);
                                      _showImagePreviewDialog(
                                        context,
                                        stampImage,
                                        'Sello Normal (Premio)',
                                      );
                                    },
                                  ),
                                  if (isOwner)
                                    ListTile(
                                      leading: Icon(Icons.photo_library, color: AppTheme.primary),
                                      title: const Text('Cambiar diseño del sello'),
                                      onTap: () {
                                        Navigator.pop(bCtx);
                                        _pickAndUploadImage(
                                          context,
                                          hueca,
                                          'loyaltyCard.stampImage',
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else {
                        _pickAndUploadImage(
                          context,
                          hueca,
                          'loyaltyCard.stampImage',
                        );
                      }
                    },
                  ),
                  _buildProfileOption(
                    icon: Icons.redeem,
                    title: 'Imagen del Premio',
                    subtitle: rewardImage.isEmpty
                        ? 'Subir foto del premio'
                        : 'Toca para cambiar o previsualizar',
                    imageUrl: rewardImage.isNotEmpty ? rewardImage : null,
                    isReadOnly: !isOwner,
                    onTap: () {
                      if (rewardImage.isNotEmpty) {
                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (bCtx) => SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.visibility, color: Colors.blue),
                                    title: const Text('Previsualizar premio'),
                                    onTap: () {
                                      Navigator.pop(bCtx);
                                      _showImagePreviewDialog(
                                        context,
                                        rewardImage,
                                        rewardText.isNotEmpty ? 'Premio: $rewardText' : 'Premio de Fidelización',
                                      );
                                    },
                                  ),
                                  if (isOwner)
                                    ListTile(
                                      leading: Icon(Icons.photo_library, color: AppTheme.primary),
                                      title: const Text('Cambiar foto del premio'),
                                      onTap: () {
                                        Navigator.pop(bCtx);
                                        _pickAndUploadImage(
                                          context,
                                          hueca,
                                          'loyaltyCard.rewardImage',
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else {
                        _pickAndUploadImage(
                          context,
                          hueca,
                          'loyaltyCard.rewardImage',
                        );
                      }
                    },
                  ),
                  SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Sticker Secreto',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isBranchManager)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  currentBranchName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.qr_code, size: 18),
                        label: const Text('Ver QR', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QrSecretStickerScreen(
                              qrSecret: branchStickerQrSecret,
                              huecaId: hueca.id,
                              branchId: currentBranch != null ? currentBranch.id : 'matriz',
                              branchName: currentBranch != null ? currentBranch.name : 'Matriz Principal',
                              stickerName: stickerName,
                              stickerImage: stickerImage.isNotEmpty ? stickerImage : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildProfileOption(
                    icon: Icons.star,
                    title: isBranchManager
                        ? 'Nombre del Sticker ($currentBranchName)'
                        : 'Nombre del Sticker',
                    subtitle: stickerName,
                    onTap: () => _showEditFieldDialog(
                      context: context,
                      hueca: hueca,
                      title: isBranchManager
                          ? 'Nombre del Sticker ($currentBranchName)'
                          : 'Nombre del Sticker',
                      fieldKey: 'secretSticker.name',
                      currentValue: stickerName,
                      targetBranch: currentBranch,
                    ),
                  ),
                  _buildProfileOption(
                    icon: Icons.image,
                    title: isBranchManager
                        ? 'Imagen del Sticker ($currentBranchName)'
                        : 'Imagen del Sticker (URL)',
                    subtitle: stickerImage.isEmpty
                        ? (isBranchManager ? 'Subir imagen para esta sucursal' : 'Subir imagen')
                        : 'Toca para cambiar o previsualizar',
                    imageUrl: stickerImage.isNotEmpty ? stickerImage : null,
                    onTap: () {
                      if (stickerImage.isNotEmpty) {
                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (bCtx) => SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.visibility, color: Colors.blue),
                                    title: const Text('Previsualizar imagen'),
                                    onTap: () {
                                      Navigator.pop(bCtx);
                                      _showImagePreviewDialog(
                                        context,
                                        stickerImage,
                                        'Sticker: $stickerName',
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.photo_library, color: AppTheme.primary),
                                    title: const Text('Cambiar imagen'),
                                    onTap: () {
                                      Navigator.pop(bCtx);
                                      _pickAndUploadImage(
                                        context,
                                        hueca,
                                        'secretSticker.image',
                                        targetBranch: currentBranch,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else {
                        _pickAndUploadImage(
                          context,
                          hueca,
                          'secretSticker.image',
                          targetBranch: currentBranch,
                        );
                      }
                    },
                  ),
                  if (isOwner) ...[
                    const SizedBox(height: 24),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.35), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Zona de Peligro',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Si eliminas esta hueca se borrarán definitivamente todos sus datos, platos, fotos, sucursales y códigos QR sin posibilidad de recuperación.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white70
                                  : Colors.black87,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.delete_forever, color: Colors.red),
                              label: const Text(
                                'Eliminar Hueca Permanentemente',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => showDeleteHuecaConfirmationDialog(
                                context: context,
                                ref: ref,
                                hueca: hueca,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 32),
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        'Cerrar Sesión',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Cerrar Sesión'),
                            content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Cerrar Sesión'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(authRepositoryProvider).signOut();
                          ref.invalidate(currentUserProvider);
                          ref.invalidate(myHuecaProvider);
                          ref.invalidate(huecasProvider);
                          ref.invalidate(currentManagedBranchProvider);
                          ref.invalidate(isOwnerProvider);
                          if (context.mounted) {
                            context.go('/login');
                          }
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}
