import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/route_repository.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';

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
  late TextEditingController _noteEsController;
  late TextEditingController _tagsController;

  List<Map<String, dynamic>> _stops = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.routeModel;

    _nameEsController = TextEditingController(text: r?.name['es']?.toString() ?? '');
    _nameEnController = TextEditingController(text: r?.name['en']?.toString() ?? '');
    _narrativeEsController = TextEditingController(text: r?.narrative['es']?.toString() ?? '');
    _narrativeEnController = TextEditingController(text: r?.narrative['en']?.toString() ?? '');
    _bannerUrlController = TextEditingController(text: r?.bannerImageUrl ?? '');
    _distanceController = TextEditingController(text: r?.metrics['distance']?.toString() ?? '2.5 km');
    _timeController = TextEditingController(text: r?.metrics['estimatedTime']?.toString() ?? '1h 30m');

    final sched = r?.recommendedSchedule ?? {};
    final timeMap = sched['time'] is Map ? sched['time'] : {};
    final noteMap = sched['note'] is Map ? sched['note'] : {};
    _scheduleEsController = TextEditingController(text: timeMap['es']?.toString() ?? '10:00 - 17:00');
    _noteEsController = TextEditingController(text: noteMap['es']?.toString() ?? 'Caminar con calzado cómodo');

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
    _noteEsController.dispose();
    _tagsController.dispose();
    super.dispose();
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
            final filtered = huecas.where((h) => h.name.toLowerCase().contains(filter.toLowerCase())).toList();

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Seleccionar Hueca como Parada', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: Column(
                  children: [
                    TextField(
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Buscar hueca...',
                        hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF0F172A)),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) => setDialogState(() => filter = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (itemCtx, i) {
                          final h = filtered[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.restaurant, color: Color(0xFF0F172A)),
                            title: Text(h.name, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                            subtitle: Text(h.sector, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 11)),
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
                  child: Text('Cancelar', style: TextStyle(color: Colors.blueGrey.shade600)),
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
        const SnackBar(content: Text('⚠️ Añade al menos 1 parada a la ruta'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isNew = widget.routeModel == null;
      final existingId = widget.routeModel?.id ?? '';
      final tags = _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

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
        'bannerImageUrl': _bannerUrlController.text.trim().isNotEmpty
            ? _bannerUrlController.text.trim()
            : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800',
        'tags': tags,
        'metrics': {
          'distance': _distanceController.text.trim(),
          'estimatedTime': _timeController.text.trim(),
        },
        'recommendedSchedule': {
          'time': {
            'es': _scheduleEsController.text.trim(),
            'en': _scheduleEsController.text.trim(),
          },
          'note': {
            'es': _noteEsController.text.trim(),
            'en': _noteEsController.text.trim(),
          },
        },
        'stops': _stops.asMap().entries.map((entry) {
          final idx = entry.key;
          final s = entry.value;
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
            content: Text(isNew ? '✅ Ruta creada exitosamente' : '✅ Ruta actualizada exitosamente'),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(isNew ? 'Nueva Ruta Gastronómica' : 'Editar Ruta', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.amber),
            tooltip: 'Guardar',
            onPressed: _isSaving ? null : _saveRoute,
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Información de la Ruta'),
                    const SizedBox(height: 10),

                    _buildTextField(
                      controller: _nameEsController,
                      label: 'Nombre en Español *',
                      icon: Icons.title,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa el nombre' : null,
                    ),
                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _nameEnController,
                      label: 'Nombre en Inglés (opcional)',
                      icon: Icons.translate,
                    ),
                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _bannerUrlController,
                      label: 'URL de Imagen Banner',
                      icon: Icons.image,
                      hint: 'https://...',
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _distanceController,
                            label: 'Distancia',
                            icon: Icons.directions_walk,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            controller: _timeController,
                            label: 'Tiempo estimado',
                            icon: Icons.timer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _tagsController,
                      label: 'Tags (separados por coma)',
                      icon: Icons.tag,
                      hint: 'Centro Histórico, Tradicional, Dulces',
                    ),
                    const SizedBox(height: 20),

                    _buildSectionTitle('Narrativa e Historia'),
                    const SizedBox(height: 10),

                    _buildTextField(
                      controller: _narrativeEsController,
                      label: 'Historia o descripción (Español) *',
                      icon: Icons.auto_stories,
                      maxLines: 3,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa la narrativa' : null,
                    ),
                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _narrativeEnController,
                      label: 'Historia o descripción (Inglés)',
                      icon: Icons.translate,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    _buildSectionTitle('Horario Recomendado & Notas'),
                    const SizedBox(height: 10),

                    _buildTextField(
                      controller: _scheduleEsController,
                      label: 'Horario recomendado',
                      icon: Icons.access_time,
                    ),
                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _noteEsController,
                      label: 'Notas o sugerencias',
                      icon: Icons.lightbulb_outline,
                    ),
                    const SizedBox(height: 24),

                    // Paradas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Paradas del Circuito (${_stops.length})'),
                        ElevatedButton.icon(
                          onPressed: _addStopDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Añadir Parada'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_stops.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Center(
                          child: Text(
                            'No hay paradas añadidas. Toca "Añadir Parada" para asociar huecas.',
                            style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
                          ),
                        ),
                      )
                    else
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
                            key: ValueKey('stop_$idx'),
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
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFF0F172A),
                                child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              title: Text(name, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                              subtitle: sector.isNotEmpty ? Text(sector, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 11)) : null,
                              trailing: IconButton(
                                icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
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

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        onPressed: _saveRoute,
                        child: Text(
                          isNew ? 'Crear Ruta' : 'Guardar Cambios',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Color(0xFF0F172A)),
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
        hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFF0F172A), size: 20),
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
