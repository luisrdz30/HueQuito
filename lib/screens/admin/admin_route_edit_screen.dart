import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/route_repository.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/services/translation_service.dart';
import 'package:hue_quito/utils/image_picker_helper.dart';

class AdminRouteEditScreen extends ConsumerStatefulWidget {
  final RouteModel? routeModel;

  const AdminRouteEditScreen({super.key, this.routeModel});

  @override
  ConsumerState<AdminRouteEditScreen> createState() => _AdminRouteEditScreenState();
}

class _AdminRouteEditScreenState extends ConsumerState<AdminRouteEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameEsController;
  late TextEditingController _nameEnController;
  late TextEditingController _narrativeEsController;
  late TextEditingController _narrativeEnController;
  late TextEditingController _bannerUrlController;
  late TextEditingController _distanceController;
  late TextEditingController _timeController;
  late TextEditingController _scheduleEsController;
  late TextEditingController _scheduleEnController;
  late TextEditingController _noteEsController;
  late TextEditingController _noteEnController;
  late TextEditingController _tagsController;

  List<Map<String, dynamic>> _stops = [];
  bool _isSaving = false;
  File? _localImageFile;
  bool _showManualUrlInput = false;

  // Estados de traducción individual y global
  bool _isTranslatingAll = false;
  bool _isTranslatingName = false;
  bool _isTranslatingNarrative = false;
  bool _isTranslatingNote = false;

  @override
  void initState() {
    super.initState();
    final r = widget.routeModel;

    _nameEsController = TextEditingController(text: r?.name['es']?.toString() ?? '');
    _nameEnController = TextEditingController(text: r?.name['en']?.toString() ?? '');
    _narrativeEsController = TextEditingController(text: r?.narrative['es']?.toString() ?? '');
    _narrativeEnController = TextEditingController(text: r?.narrative['en']?.toString() ?? '');
    _bannerUrlController = TextEditingController(text: r?.bannerImageUrl ?? '');
    _showManualUrlInput = _bannerUrlController.text.trim().isNotEmpty;
    _distanceController = TextEditingController(text: r?.metrics['distance']?.toString() ?? '2.5 km');
    _timeController = TextEditingController(text: r?.metrics['estimatedTime']?.toString() ?? '1h 30m');

    final sched = r?.recommendedSchedule ?? {};
    final timeMap = sched['time'] is Map ? sched['time'] : {};
    final noteMap = sched['note'] is Map ? sched['note'] : {};
    _scheduleEsController = TextEditingController(text: timeMap['es']?.toString() ?? '10:00 - 17:00');
    _scheduleEnController = TextEditingController(text: timeMap['en']?.toString() ?? timeMap['es']?.toString() ?? '10:00 - 17:00');
    _noteEsController = TextEditingController(text: noteMap['es']?.toString() ?? 'Caminar con calzado cómodo');
    _noteEnController = TextEditingController(text: noteMap['en']?.toString() ?? 'Wear comfortable shoes');

    _tagsController = TextEditingController(text: (r?.tags ?? []).join(', '));

    if (r != null && r.stops.isNotEmpty) {
      _stops = r.stops.map((s) => Map<String, dynamic>.from(s is Map ? s : {})).toList();
    }
  }

  @override
  void dispose() {
    _nameEsController.dispose();
    _nameEnController.dispose();
    _narrativeEsController.dispose();
    _narrativeEnController.dispose();
    _bannerUrlController.dispose();
    _distanceController.dispose();
    _timeController.dispose();
    _scheduleEsController.dispose();
    _scheduleEnController.dispose();
    _noteEsController.dispose();
    _noteEnController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  // --- TRADUCCIÓN AUTOMÁTICA ---
  Future<void> _translateName() async {
    final text = _nameEsController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Escribe primero el nombre en español'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isTranslatingName = true);
    final translated = await TranslationService.translateEsToEn(text);
    if (mounted) {
      setState(() {
        _nameEnController.text = translated;
        _isTranslatingName = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Nombre de la ruta traducido al inglés'),
          backgroundColor: Colors.teal,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _translateNarrative() async {
    final text = _narrativeEsController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Escribe primero la historia/narrativa en español'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isTranslatingNarrative = true);
    final translated = await TranslationService.translateEsToEn(text);
    if (mounted) {
      setState(() {
        _narrativeEnController.text = translated;
        _isTranslatingNarrative = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Historia/narrativa traducida al inglés'),
          backgroundColor: Colors.teal,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _translateNote() async {
    final text = _noteEsController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Escribe primero la sugerencia/nota en español'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isTranslatingNote = true);
    final translated = await TranslationService.translateEsToEn(text);
    if (mounted) {
      setState(() {
        _noteEnController.text = translated;
        _isTranslatingNote = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Sugerencias traducidas al inglés'),
          backgroundColor: Colors.teal,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _translateAll() async {
    final name = _nameEsController.text.trim();
    final narrative = _narrativeEsController.text.trim();
    final note = _noteEsController.text.trim();

    if (name.isEmpty && narrative.isEmpty && note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Ingresa al menos el nombre o la narrativa en español para traducir'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isTranslatingAll = true);

    try {
      if (name.isNotEmpty) {
        final translatedName = await TranslationService.translateEsToEn(name);
        if (mounted) _nameEnController.text = translatedName;
      }

      if (narrative.isNotEmpty) {
        final translatedNarrative = await TranslationService.translateEsToEn(narrative);
        if (mounted) _narrativeEnController.text = translatedNarrative;
      }

      if (note.isNotEmpty) {
        final translatedNote = await TranslationService.translateEsToEn(note);
        if (mounted) _noteEnController.text = translatedNote;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ ¡Traducción de la ruta completada con éxito!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en la traducción: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isTranslatingAll = false);
    }
  }

  // --- SELECTOR INTERACTIVO DE HORARIO RECOMENDADO ---
  Future<void> _pickRouteScheduleRange() async {
    // 1. Hora de Inicio
    final pickedStart = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      helpText: 'HORA DE INICIO DEL TOUR',
      confirmText: 'SIGUIENTE',
      cancelText: 'CANCELAR',
    );
    if (pickedStart == null || !mounted) return;

    // 2. Hora de Cierre
    final pickedEnd = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (pickedStart.hour + 4) % 24, minute: pickedStart.minute),
      helpText: 'HORA DE FINALIZACIÓN DEL TOUR',
      confirmText: 'ESTABLECER',
      cancelText: 'CANCELAR',
    );
    if (pickedEnd == null || !mounted) return;

    final start24 = '${pickedStart.hour.toString().padLeft(2, '0')}:${pickedStart.minute.toString().padLeft(2, '0')}';
    final end24 = '${pickedEnd.hour.toString().padLeft(2, '0')}:${pickedEnd.minute.toString().padLeft(2, '0')}';

    final start12 = _formatTime12(pickedStart);
    final end12 = _formatTime12(pickedEnd);

    setState(() {
      _scheduleEsController.text = '$start24 - $end24';
      _scheduleEnController.text = '$start12 - $end12';
    });
  }

  String _formatTime12(TimeOfDay t) {
    final hour12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    final min = t.minute.toString().padLeft(2, '0');
    return '$hour12:$min $period';
  }

  void _applySchedulePreset(String es, String en) {
    setState(() {
      _scheduleEsController.text = es;
      _scheduleEnController.text = en;
    });
  }

  Widget _buildPresetChip(String label, String es, String en) {
    final isSelected = _scheduleEsController.text == es;
    return InkWell(
      onTap: () => _applySchedulePreset(es, en),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.amber : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }

  // --- SELECCIÓN Y SUBIDA DE IMAGEN A FIREBASE STORAGE ---
  Future<void> _showImageSourceModal() async {
    final file = await ImagePickerHelper.showImageSourceDialog(
      context: context,
      title: 'Foto de Portada del Tour',
      subtitle: 'Elige de dónde quieres cargar la portada de esta ruta',
      includeRemove: _localImageFile != null || _bannerUrlController.text.isNotEmpty,
      onRemove: () {
        setState(() {
          _localImageFile = null;
          _bannerUrlController.clear();
        });
      },
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (file != null) {
      setState(() {
        _localImageFile = file;
      });
    }
  }

  void _addStopDialog() {
    final huecas = ref.read(allHuecasStreamProvider).value ?? [];
    if (huecas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay huecas disponibles para añadir')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final filtered = huecas.where((h) => h.matchesSearch(filter)).toList();

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.add_location_alt, color: Color(0xFF0F172A)),
                  SizedBox(width: 8),
                  Text(
                    'Seleccionar Parada',
                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 380,
                child: Column(
                  children: [
                    TextField(
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, plato o sector...',
                        hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF0F172A)),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (val) => setDialogState(() => filter = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No se encontraron huecas con ese nombre',
                                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (itemCtx, i) {
                                final h = filtered[i];
                                final isAlreadyAdded = _stops.any((s) => s['huecaId'] == h.id);

                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isAlreadyAdded ? Colors.green.shade50 : const Color(0xFF0F172A),
                                    child: Icon(
                                      isAlreadyAdded ? Icons.check : Icons.restaurant,
                                      color: isAlreadyAdded ? Colors.green.shade700 : Colors.amber,
                                      size: 16,
                                    ),
                                  ),
                                  title: Text(
                                    h.name,
                                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(h.sector, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 11)),
                                  trailing: isAlreadyAdded
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Agregada',
                                            style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        )
                                      : const Icon(Icons.add_circle_outline, color: Color(0xFF0F172A), size: 20),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    setState(() {
                                      _stops.add({
                                        'huecaId': h.id,
                                        'huecaName': h.name,
                                        'sector': h.sector,
                                        'order': _stops.length + 1,
                                      });
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cerrar', style: TextStyle(color: Colors.blueGrey.shade600, fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveRoute() async {
    if (!_formKey.currentState!.validate()) return;

    if (_stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Añade al menos 1 hueca como parada al circuito de la ruta'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isNew = widget.routeModel == null;
      final existingId = widget.routeModel?.id ?? '';
      final tags = _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

      String bannerImageUrl = _bannerUrlController.text.trim();

      // Subida de foto a Google Firebase Storage
      if (_localImageFile != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('tour_images/tour_$timestamp.jpg');
        final uploadTask = await storageRef.putFile(_localImageFile!);
        bannerImageUrl = await uploadTask.ref.getDownloadURL();
      }

      final data = {
        if (!isNew) 'id': existingId,
        'name': {
          'es': _nameEsController.text.trim(),
          'en': _nameEnController.text.trim().isNotEmpty ? _nameEnController.text.trim() : _nameEsController.text.trim(),
        },
        'narrative': {
          'es': _narrativeEsController.text.trim(),
          'en': _narrativeEnController.text.trim().isNotEmpty ? _narrativeEnController.text.trim() : _narrativeEsController.text.trim(),
        },
        'bannerImageUrl': bannerImageUrl.isNotEmpty
            ? bannerImageUrl
            : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800',
        'tags': tags,
        'metrics': {
          'distance': _distanceController.text.trim().isNotEmpty ? _distanceController.text.trim() : '2.0 km',
          'estimatedTime': _timeController.text.trim().isNotEmpty ? _timeController.text.trim() : '1h 30m',
        },
        'recommendedSchedule': {
          'time': {
            'es': _scheduleEsController.text.trim(),
            'en': _scheduleEnController.text.trim().isNotEmpty ? _scheduleEnController.text.trim() : _scheduleEsController.text.trim(),
          },
          'note': {
            'es': _noteEsController.text.trim(),
            'en': _noteEnController.text.trim().isNotEmpty ? _noteEnController.text.trim() : _noteEsController.text.trim(),
          },
        },
        'stops': _stops.asMap().entries.map((entry) {
          final idx = entry.key;
          final s = Map<String, dynamic>.from(entry.value);
          s['order'] = idx + 1;
          return s;
        }).toList(),
      };

      await ref.read(routeRepositoryProvider).saveRoute(data);
      ref.invalidate(allRoutesStreamProvider);
      ref.invalidate(routesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNew ? '✅ Ruta turística creada exitosamente' : '✅ Ruta turística actualizada exitosamente'),
            backgroundColor: Colors.teal,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar ruta: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.routeModel == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isNew ? 'Nueva Ruta Gastronómica' : 'Editar Ruta',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                    )
                  : const Icon(Icons.check, size: 16, color: Color(0xFF0F172A)),
              label: Text(
                _isSaving ? 'Guardando...' : 'Guardar',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
              ),
              onPressed: _isSaving ? null : _saveRoute,
            ),
          ),
        ],
      ),
      body: _isSaving
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF0F172A)),
                  const SizedBox(height: 16),
                  Text(
                    _localImageFile != null
                        ? 'Subiendo foto a Firebase Storage y guardando tour...'
                        : 'Guardando datos de la ruta gastronómica...',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner de Traducción Automática Inteligente
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Traducción Automática Multilingüe',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Completa los datos en español y traduce nombre, historia y notas al inglés con un clic.',
                                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isTranslatingAll ? null : _translateAll,
                              icon: _isTranslatingAll
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                                    )
                                  : const Icon(Icons.translate, size: 16),
                              label: Text(
                                _isTranslatingAll ? 'Traduciendo con IA...' : '✨ Traducir Todo al Inglés',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: const Color(0xFF0F172A),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildSectionTitle('Información Principal de la Ruta'),
                    const SizedBox(height: 10),

                    _buildTextField(
                      controller: _nameEsController,
                      label: 'Nombre de la Ruta (Español) *',
                      icon: Icons.title,
                      hint: 'Ej. Ruta Tradicional del Centro Histórico',
                      validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa el nombre en español' : null,
                    ),
                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _nameEnController,
                      label: 'Nombre en Inglés (Traducción)',
                      icon: Icons.translate,
                      hint: 'Ej. Historic Center Traditional Route',
                      suffixIcon: _isTranslatingName
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : IconButton(
                              icon: const Icon(Icons.g_translate, color: Colors.teal),
                              tooltip: 'Traducir solo el nombre',
                              onPressed: _translateName,
                            ),
                    ),
                    const SizedBox(height: 16),
                    _buildBannerImageSection(),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _distanceController,
                            label: 'Distancia Recorrida',
                            icon: Icons.directions_walk,
                            hint: '2.5 km',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            controller: _timeController,
                            label: 'Tiempo Estimado',
                            icon: Icons.timer_outlined,
                            hint: '1h 30m',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _tagsController,
                      label: 'Categorías / Tags (separados por coma)',
                      icon: Icons.tag,
                      hint: 'Centro Histórico, Tradicional, Dulces, Cafetería',
                    ),
                    const SizedBox(height: 22),

                    _buildSectionTitle('Narrativa e Historia del Recorrido'),
                    const SizedBox(height: 10),

                    _buildTextField(
                      controller: _narrativeEsController,
                      label: 'Historia o descripción (Español) *',
                      icon: Icons.auto_stories,
                      maxLines: 3,
                      hint: 'Relata los orígenes de esta ruta gastronómica...',
                      validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa la narrativa en español' : null,
                    ),
                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _narrativeEnController,
                      label: 'Historia o descripción (Inglés)',
                      icon: Icons.translate,
                      maxLines: 3,
                      hint: 'English translation of the narrative...',
                      suffixIcon: _isTranslatingNarrative
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : IconButton(
                              icon: const Icon(Icons.g_translate, color: Colors.teal),
                              tooltip: 'Traducir solo la historia',
                              onPressed: _translateNarrative,
                            ),
                    ),
                    const SizedBox(height: 22),

                    _buildSectionTitle('Horario Recomendado del Tour'),
                    const SizedBox(height: 10),

                    // Tarjeta interactiva de selección de horario
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.access_time_filled, color: Colors.amber, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Horario Sugerido para Realizar el Tour',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      'Selecciona con el reloj o elige una de las plantillas:',
                                      style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Visualizador de horario actual
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.schedule, size: 18, color: Color(0xFF0F172A)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _scheduleEsController.text.isNotEmpty
                                            ? '🇪🇨 Español: ${_scheduleEsController.text}'
                                            : '🇪🇨 Español: Sin horario definido',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _scheduleEsController.text.isNotEmpty ? const Color(0xFF0F172A) : Colors.blueGrey.shade400,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _scheduleEnController.text.isNotEmpty
                                            ? '🇺🇸 English: ${_scheduleEnController.text}'
                                            : '🇺🇸 English: No schedule set',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _scheduleEnController.text.isNotEmpty ? Colors.teal.shade800 : Colors.blueGrey.shade400,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_scheduleEsController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: Colors.blueGrey),
                                    tooltip: 'Limpiar horario',
                                    onPressed: () {
                                      setState(() {
                                        _scheduleEsController.clear();
                                        _scheduleEnController.clear();
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Botón para abrir el reloj interactivo
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _pickRouteScheduleRange,
                              icon: const Icon(Icons.touch_app, size: 18, color: Color(0xFF0F172A)),
                              label: const Text(
                                '🕒 Seleccionar Horario con el Reloj',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: const Color(0xFF0F172A),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Plantillas de acceso rápido
                          const Text(
                            'Atajos Rápidos:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildPresetChip('☀️ Mañana (09:00 - 13:00)', '09:00 - 13:00', '9:00 AM - 1:00 PM'),
                              _buildPresetChip('🍲 Almuerzo (11:30 - 15:30)', '11:30 - 15:30', '11:30 AM - 3:30 PM'),
                              _buildPresetChip('🌆 Tarde/Noche (16:00 - 21:00)', '16:00 - 21:00', '4:00 PM - 9:00 PM'),
                              _buildPresetChip('✨ Todo el Día (09:00 - 19:00)', '09:00 - 19:00', '9:00 AM - 7:00 PM'),
                              _buildPresetChip('🌙 Nocturno (18:00 - 23:00)', '18:00 - 23:00', '6:00 PM - 11:00 PM'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildSectionTitle('Sugerencias para el Visitante'),
                    const SizedBox(height: 10),

                    _buildTextField(
                      controller: _noteEsController,
                      label: 'Sugerencias para el visitante (Español)',
                      icon: Icons.lightbulb_outline,
                      hint: 'Caminar con calzado cómodo y llevar efectivo',
                    ),
                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _noteEnController,
                      label: 'Sugerencias para el visitante (Inglés)',
                      icon: Icons.translate,
                      hint: 'Wear comfortable walking shoes and bring cash',
                      suffixIcon: _isTranslatingNote
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : IconButton(
                              icon: const Icon(Icons.g_translate, color: Colors.teal),
                              tooltip: 'Traducir sugerencias',
                              onPressed: _translateNote,
                            ),
                    ),
                    const SizedBox(height: 26),

                    // Paradas del Circuito
                    Row(
                      children: [
                        Expanded(
                          child: _buildSectionTitle('Paradas (${_stops.length})'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addStopDialog,
                          icon: const Icon(Icons.add_location_alt, size: 16, color: Colors.amber),
                          label: const Text('Añadir Parada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_stops.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.alt_route, size: 40, color: Colors.blueGrey.shade300),
                              const SizedBox(height: 8),
                              const Text(
                                'Aún no has agregado paradas',
                                style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Toca "Añadir Parada" para asociar huecas y definir el orden del recorrido.',
                                style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '💡 Mantén presionado y arrastra para cambiar el orden de las paradas.',
                          style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
                        ),
                      ),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _stops.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = _stops.removeAt(oldIndex);
                            _stops.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (ctx, idx) {
                          final stop = _stops[idx];
                          final name = stop['huecaName'] ?? stop['huecaId'] ?? 'Hueca';
                          final sector = stop['sector'] ?? '';

                          return Container(
                            key: ValueKey('stop_${stop['huecaId']}_$idx'),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ListTile(
                              dense: true,
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.drag_handle, color: Color(0xFF94A3B8), size: 20),
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFF0F172A),
                                    child: Text(
                                      '${idx + 1}',
                                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                              ),
                              subtitle: sector.isNotEmpty ? Text(sector, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 11)) : null,
                              trailing: IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 18),
                                ),
                                tooltip: 'Quitar parada',
                                onPressed: () {
                                  setState(() {
                                    _stops.removeAt(idx);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Botón Inferior Principal
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                        icon: Icon(
                          isNew ? Icons.add_road : Icons.check_circle_outline,
                          color: Colors.amber,
                          size: 20,
                        ),
                        label: Text(
                          isNew ? 'Crear Ruta Gastronómica' : 'Guardar Cambios de la Ruta',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        onPressed: _isSaving ? null : _saveRoute,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBannerImageSection() {
    final hasLocalImage = _localImageFile != null;
    final hasRemoteUrl = _bannerUrlController.text.trim().isNotEmpty;
    final hasImage = hasLocalImage || hasRemoteUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Imagen de Portada del Tour'),
        const SizedBox(height: 4),
        Text(
          'Elige una imagen representativa desde tu dispositivo (se subirá a Google Firebase Storage) o introduce un enlace web.',
          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _showImageSourceModal,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasLocalImage ? Colors.amber.shade700 : const Color(0xFFCBD5E1),
                width: hasLocalImage ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasLocalImage)
                    Image.file(
                      _localImageFile!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  else if (hasRemoteUrl)
                    Image.network(
                      _bannerUrlController.text.trim(),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 44, color: Colors.blueGrey.shade400),
                            const SizedBox(height: 6),
                            Text(
                              'No se pudo cargar la imagen remota',
                              style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_photo_alternate_rounded, size: 36, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Toca para subir portada del tour',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Galería o Cámara • Google Firebase Storage',
                            style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                  // Insignia superior izquierda indicando origen de la imagen
                  if (hasImage)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasLocalImage ? Icons.cloud_upload : Icons.link,
                              size: 13,
                              color: hasLocalImage ? Colors.amber : Colors.cyanAccent,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              hasLocalImage ? 'Listo para Firebase Storage' : 'Enlace Web',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Botón flotante inferior derecho para cambiar la foto
                  if (hasImage)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Cambiar',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Barra de botones rápidos
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _showImageSourceModal,
              icon: const Icon(Icons.add_photo_alternate, size: 16, color: Color(0xFF0F172A)),
              label: Text(
                hasImage ? 'Cambiar Foto' : 'Subir Foto',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            if (hasImage)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _localImageFile = null;
                    _bannerUrlController.clear();
                  });
                },
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                label: const Text(
                  'Quitar',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() => _showManualUrlInput = !_showManualUrlInput);
              },
              icon: Icon(
                _showManualUrlInput ? Icons.keyboard_arrow_up : Icons.link,
                size: 16,
                color: Colors.blueGrey.shade700,
              ),
              label: Text(
                _showManualUrlInput ? 'Ocultar URL' : 'URL manual',
                style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 12),
              ),
            ),
          ],
        ),

        if (_showManualUrlInput) ...[
          const SizedBox(height: 6),
          _buildTextField(
            controller: _bannerUrlController,
            label: 'URL de Imagen Web (Opcional)',
            icon: Icons.image_outlined,
            hint: 'https://...',
            onChanged: (_) => setState(() {}),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Color(0xFF0F172A)),
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
        hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFF0F172A), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
