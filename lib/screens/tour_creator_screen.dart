import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/route_repository.dart';
import 'package:hue_quito/utils/tour_distance_helper.dart';

class TourCreatorScreen extends ConsumerStatefulWidget {
  const TourCreatorScreen({super.key});

  @override
  ConsumerState<TourCreatorScreen> createState() => _TourCreatorScreenState();
}

class _TourCreatorScreenState extends ConsumerState<TourCreatorScreen> {
  final List<Hueca> _selectedStops = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  String _selectedSector = 'Todos';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = 'Mi Ruta Personalizada';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _addStop(Hueca hueca) {
    if (_selectedStops.any((h) => h.id == hueca.id)) return;
    setState(() {
      _selectedStops.add(hueca);
    });
  }

  void _removeStop(int index) {
    setState(() {
      _selectedStops.removeAt(index);
    });
  }

  void _reorderStops(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final Hueca item = _selectedStops.removeAt(oldIndex);
      _selectedStops.insert(newIndex, item);
    });
  }

  Future<void> _saveTour({bool startNavigation = false}) async {
    if (_selectedStops.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos 2 huecas para armar tu ruta.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = ref.read(currentUserProvider).value;
      final uid = user?.uid ?? 'guest';
      final lang = ref.read(settingsProvider).language;
      final isEn = lang == 'en';

      final metrics = TourDistanceHelper.calculateMetrics(_selectedStops);
      final tourId = 'custom_tour_${DateTime.now().millisecondsSinceEpoch}';

      final title = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : (isEn ? 'My Custom Tour' : 'Mi Tour Personalizado');

      final stopsData = <Map<String, dynamic>>[];
      final sectors = <String>{};

      for (int i = 0; i < _selectedStops.length; i++) {
        final h = _selectedStops[i];
        if (h.sector.isNotEmpty) sectors.add(h.sector);

        final dishName = () {
          if (h.mainDish['name'] is Map) {
            final m = h.mainDish['name'] as Map;
            return (m['es'] ?? m['en'] ?? '').toString();
          }
          return h.mainDish['name']?.toString() ?? '';
        }();

        stopsData.add({
          'order': i + 1,
          'huecaId': h.id,
          'description': {
            'es': dishName.isNotEmpty ? 'Especialidad: $dishName' : 'Parada #${i + 1}',
            'en': dishName.isNotEmpty ? 'Specialty: $dishName' : 'Stop #${i + 1}',
          },
          'dishes': dishName.isNotEmpty ? [dishName] : [],
        });
      }

      final customTour = RouteModel(
        id: tourId,
        name: {'es': title, 'en': title},
        narrative: {
          'es': 'Tour personalizado creado por el usuario con ${_selectedStops.length} paradas.',
          'en': 'Custom tour created by user with ${_selectedStops.length} stops.',
        },
        bannerImageUrl: _selectedStops.first.images.isNotEmpty
            ? _selectedStops.first.images.first
            : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=800&q=80',
        tags: ['Personalizado', ...sectors],
        metrics: {
          'distance': TourDistanceHelper.formatDistance(metrics.totalDistanceKm),
          'estimatedTime': TourDistanceHelper.formatDuration(metrics.totalDurationMinutes, isEn: isEn),
        },
        recommendedSchedule: {
          'time': {'es': 'A tu propio ritmo', 'en': 'At your own pace'},
          'note': {'es': 'Tour personalizado', 'en': 'Custom tour'},
        },
        stops: stopsData,
        creatorId: uid,
        isCustom: true,
        createdAt: DateTime.now(),
      );

      final routeRepo = ref.read(routeRepositoryProvider);
      await routeRepo.saveUserTour(customTour, userId: uid);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEn ? 'Tour saved successfully!' : '¡Tour guardado exitosamente!',
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (startNavigation) {
        context.pushReplacement('/route_navigation', extra: {
          'route': customTour,
          'stops': _selectedStops,
        });
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final isEn = lang == 'en';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final huecasAsync = ref.watch(huecasProvider);
    final metrics = TourDistanceHelper.calculateMetrics(_selectedStops);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEn ? 'Build Tour My Way' : 'Armar Tour a mi Manera',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: Column(
        children: [
          // Metrics summary bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricChip(
                  icon: Icons.storefront_rounded,
                  label: isEn ? 'Stops' : 'Paradas',
                  value: '${_selectedStops.length}',
                ),
                Container(width: 1, height: 28, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                _buildMetricChip(
                  icon: Icons.straighten_rounded,
                  label: isEn ? 'Distance' : 'Distancia',
                  value: TourDistanceHelper.formatDistance(metrics.totalDistanceKm),
                ),
                Container(width: 1, height: 28, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                _buildMetricChip(
                  icon: Icons.directions_car_rounded,
                  label: isEn ? 'By Car' : 'En auto',
                  value: '~${metrics.totalDurationMinutes} min',
                ),
              ],
            ),
          ),

          // Main content: Selected Stops (Reorderable) + Catalog search
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                // Section 1: Selected Stops
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isEn ? 'TOUR STOPS (DRAG TO REORDER)' : 'PARADAS DEL TOUR (ARRASTRA)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedStops.length} huecas',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_selectedStops.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.add_location_alt_outlined, size: 36, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          isEn
                              ? 'No spots added yet'
                              : 'Aún no has agregado paradas',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEn
                              ? 'Browse the list below and tap "+ Add" to assemble your custom route.'
                              : 'Explora la lista de abajo y toca "+ Agregar" para armar tu ruta a tu gusto.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _selectedStops.length,
                    onReorder: _reorderStops,
                    itemBuilder: (context, index) {
                      final hueca = _selectedStops[index];
                      final isLast = index == _selectedStops.length - 1;
                      final leg = index < metrics.legs.length ? metrics.legs[index] : null;

                      return Container(
                        key: ValueKey(hueca.id),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Drag handle icon
                                  const Icon(Icons.drag_indicator_rounded, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  // Stop number badge
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Hueca info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          hueca.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '📍 ${hueca.sector}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white70 : AppTheme.textMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Remove button
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                    onPressed: () => _removeStop(index),
                                  ),
                                ],
                              ),
                            ),
                            // Leg driving time indicator to next stop
                            if (!isLast && leg != null) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 44),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.grey[850] : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[250] ?? Colors.grey[300]!),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.arrow_downward_rounded, size: 12, color: AppTheme.primary),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.directions_car_rounded, size: 13, color: AppTheme.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${TourDistanceHelper.formatDistance(leg.distanceKm)} • ~${leg.durationMinutes} min en auto',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 16),

                // Section 2: Explore Catalog
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    isEn ? 'ADD HUECAS FROM CATALOG' : 'AGREGAR HUECAS DEL CATÁLOGO',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),

                // Search Bar & Sector Filter
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: isEn ? 'Search hueca or dish...' : 'Buscar hueca o plato...',
                              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                              prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Catalog List
                huecasAsync.when(
                  data: (allHuecas) {
                    final query = _searchController.text.toLowerCase().trim();
                    final filtered = allHuecas.where((h) {
                      if (!h.isActive) return false;
                      if (_selectedSector != 'Todos' && _selectedSector != 'All') {
                        if (h.sector.toLowerCase() != _selectedSector.toLowerCase()) return false;
                      }
                      if (query.isEmpty) return true;
                      final name = h.name.toLowerCase();
                      final sector = h.sector.toLowerCase();
                      final dish = () {
                        if (h.mainDish['name'] is Map) {
                          return (h.mainDish['name']['es'] ?? '').toString().toLowerCase();
                        }
                        return h.mainDish['name']?.toString().toLowerCase() ?? '';
                      }();
                      return name.contains(query) || sector.contains(query) || dish.contains(query);
                    }).toList();

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final hueca = filtered[index];
                        final isAlreadyAdded = _selectedStops.any((h) => h.id == hueca.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: hueca.images.isNotEmpty
                                    ? Image.network(
                                        hueca.images.first,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 48,
                                          height: 48,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.restaurant, size: 20),
                                        ),
                                      )
                                    : Container(
                                        width: 48,
                                        height: 48,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.restaurant, size: 20),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hueca.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '📍 ${hueca.sector}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white70 : AppTheme.textMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isAlreadyAdded
                                      ? Colors.grey[400]
                                      : AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: isAlreadyAdded ? null : () => _addStop(hueca),
                                child: Text(
                                  isAlreadyAdded ? (isEn ? 'Added' : 'Agregada') : (isEn ? '+ Add' : '+ Agregar'),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ],
            ),
          ),
        ],
      ),

      // Bottom Bar with Title input and Save Button
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: isEn ? 'Tour Name' : 'Nombre del Tour',
                  labelStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.edit, size: 18, color: AppTheme.primary),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: (_selectedStops.length >= 2 && !_isSaving)
                          ? () => _saveTour(startNavigation: false)
                          : null,
                      child: _isSaving
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.bookmark_added_rounded, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  isEn ? 'Save Tour (${_selectedStops.length} stops)' : 'Guardar Tour (${_selectedStops.length} paradas)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}
