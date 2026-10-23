import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/route_repository.dart';
import 'package:hue_quito/utils/tour_distance_helper.dart';

class TourWizardScreen extends ConsumerStatefulWidget {
  const TourWizardScreen({super.key});

  @override
  ConsumerState<TourWizardScreen> createState() => _TourWizardScreenState();
}

class _TourWizardScreenState extends ConsumerState<TourWizardScreen> {
  // Wizard state
  int _currentStep = 0; // 0 = Choose stop count, 1..N = Choose stops, N+1 = Summary
  int _totalStops = 3;  // Default 3 stops
  final List<Hueca> _selectedHuecas = [];
  TourCravingType _selectedCraving = TourCravingType.soup;
  late TextEditingController _titleController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'Mi Tour Gastronómico');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _onStopCountSelected(int count) {
    setState(() {
      _totalStops = count;
      _selectedHuecas.clear();
      _currentStep = 1;
      _selectedCraving = TourCravingType.soup; // Default initial craving
    });
  }

  void _onHuecaSelected(Hueca hueca) {
    setState(() {
      if (_selectedHuecas.length >= _currentStep) {
        _selectedHuecas[_currentStep - 1] = hueca;
      } else {
        _selectedHuecas.add(hueca);
      }
    });
  }

  void _advanceToNextStop() {
    if (_selectedHuecas.length < _currentStep) return;

    if (_currentStep < _totalStops) {
      setState(() {
        _currentStep++;
        // Pre-select smart next craving based on what was eaten
        if (_currentStep == 2) {
          _selectedCraving = TourCravingType.heavy;
        } else if (_currentStep >= 3) {
          _selectedCraving = TourCravingType.dessert;
        }
      });
    } else {
      // Generate default custom tour title
      final first = _selectedHuecas.first.name;
      final last = _selectedHuecas.last.name;
      _titleController.text = 'Tour: $first a $last';
      setState(() {
        _currentStep = _totalStops + 1; // Summary step
      });
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        if (_currentStep > 0 && _selectedHuecas.length >= _currentStep) {
          // Keep selection or allow changing
        }
      });
    } else {
      context.pop();
    }
  }

  Future<void> _saveTour({bool startNavigation = false}) async {
    if (_selectedHuecas.length < 2) return;
    setState(() => _isSaving = true);

    try {
      final user = ref.read(currentUserProvider).value;
      final uid = user?.uid ?? 'guest';
      final lang = ref.read(settingsProvider).language;
      final isEn = lang == 'en';

      final metrics = TourDistanceHelper.calculateMetrics(_selectedHuecas);
      final tourId = 'custom_tour_${DateTime.now().millisecondsSinceEpoch}';

      final title = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : (isEn ? 'My Custom Tour' : 'Mi Tour Personalizado');

      final stopsData = <Map<String, dynamic>>[];
      final sectors = <String>{};

      for (int i = 0; i < _selectedHuecas.length; i++) {
        final h = _selectedHuecas[i];
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
          'es': 'Tour personalizado creado por el usuario con ${_selectedHuecas.length} paradas gastronómicas.',
          'en': 'Custom food tour created by user with ${_selectedHuecas.length} delicious stops.',
        },
        bannerImageUrl: _selectedHuecas.first.images.isNotEmpty
            ? _selectedHuecas.first.images.first
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
                  isEn ? 'Tour saved successfully to your profile!' : '¡Tour guardado con éxito en tu perfil!',
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (startNavigation) {
        // Open navigation immediately
        context.pushReplacement('/route_navigation', extra: {
          'route': customTour,
          'stops': _selectedHuecas,
        });
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el tour: $e'),
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

    return WillPopScope(
      onWillPop: () async {
        if (_currentStep > 0) {
          _goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
            onPressed: _goBack,
          ),
          title: Text(
            _currentStep == 0
                ? (isEn ? 'Plan Tour' : 'Diseña tu Tour')
                : (_currentStep <= _totalStops
                    ? (isEn ? 'Stop $_currentStep of $_totalStops' : 'Parada $_currentStep de $_totalStops')
                    : (isEn ? 'Tour Summary' : 'Resumen del Tour')),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: LinearProgressIndicator(
              value: (_currentStep) / (_totalStops + 1),
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
        ),
        body: _buildCurrentStep(isEn, isDark),
      ),
    );
  }

  Widget _buildCurrentStep(bool isEn, bool isDark) {
    if (_currentStep == 0) {
      return _buildStopCountStep(isEn, isDark);
    } else if (_currentStep <= _totalStops) {
      return _buildStopSelectionStep(isEn, isDark);
    } else {
      return _buildSummaryStep(isEn, isDark);
    }
  }

  // ==========================================
  // STEP 0: SELECT STOP COUNT (2, 3, 4)
  // ==========================================
  Widget _buildStopCountStep(bool isEn, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Create your custom route' : 'Crea tu circuito gastronómico',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEn
                          ? 'Choose how many stops you want to make today. We will suggest matching spots in Quito ordered by proximity.'
                          : 'Elige cuántas paradas te gustaría hacer hoy. Te sugeriremos huecas de Quito priorizando las más cercanas entre sí.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : AppTheme.textMedium,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text(
          isEn ? 'How many huecas do you want to visit today?' : '¿Cuántas huecas quieres visitar hoy?',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          isEn ? 'Select the size of your food tour:' : 'Selecciona el tamaño de tu recorrido:',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : AppTheme.textMedium),
        ),
        const SizedBox(height: 20),

        // 2 Huecas (Ruta Express)
        _buildStopCountCard(
          isDark: isDark,
          count: 2,
          emoji: '⚡',
          badge: isEn ? 'Express Route • ~1 to 2h' : 'Ruta Express • ~1 a 2 horas',
          title: isEn ? '2 Huecas' : '2 Huecas',
          subtitle: isEn
              ? 'Great for a relaxed lunch followed by dessert or specialty coffee.'
              : 'Ideal para un buen almuerzo y su respectivo postre o café sin prisas.',
          onTap: () => _onStopCountSelected(2),
        ),
        const SizedBox(height: 16),

        // 3 Huecas (Ruta Clásica)
        _buildStopCountCard(
          isDark: isDark,
          count: 3,
          isRecommended: true,
          emoji: '⭐',
          badge: isEn ? 'Classic Route • Most Popular' : 'Ruta Clásica • Recomendada',
          title: isEn ? '3 Huecas' : '3 Huecas',
          subtitle: isEn
              ? 'The authentic Quito foodie experience: warm soup, main traditional dish, and a sweet finish.'
              : 'La experiencia completa: entrada calientita, plato fuerte y remate dulce.',
          onTap: () => _onStopCountSelected(3),
        ),
        const SizedBox(height: 16),

        // 4 Huecas (Tour Glotón)
        _buildStopCountCard(
          isDark: isDark,
          count: 4,
          emoji: '👑',
          badge: isEn ? 'Foodie Master • All Day' : 'Tour Glotón • Todo el día',
          title: isEn ? '4 Huecas' : '4 Huecas',
          subtitle: isEn
              ? 'An epic Quito route to taste soups, traditional dishes, artisanal ice cream, and evening street food.'
              : 'Recorrido épico para saborear Quito de inicio a fin con amigos o familia.',
          onTap: () => _onStopCountSelected(4),
        ),
      ],
    );
  }

  Widget _buildStopCountCard({
    required bool isDark,
    required int count,
    required String emoji,
    required String badge,
    required String title,
    required String subtitle,
    bool isRecommended = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isRecommended
                  ? AppTheme.primary
                  : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
              width: isRecommended ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isRecommended
                    ? AppTheme.primary.withOpacity(0.12)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isRecommended
                      ? AppTheme.primary.withOpacity(0.15)
                      : (isDark ? Colors.grey[800] : Colors.grey[100]),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isRecommended
                            ? AppTheme.primary.withOpacity(0.12)
                            : (isDark ? Colors.grey[800] : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isRecommended ? AppTheme.primary : (isDark ? Colors.white70 : AppTheme.textMedium),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark ? Colors.white70 : AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // STEP 1..N: DYNAMIC STOP SELECTION
  // ==========================================
  Widget _buildStopSelectionStep(bool isEn, bool isDark) {
    final huecasAsync = ref.watch(huecasProvider);
    final Hueca? previousHueca = _currentStep > 1 && _selectedHuecas.isNotEmpty
        ? _selectedHuecas[_currentStep - 2]
        : null;

    final currentSelectedHueca = _selectedHuecas.length >= _currentStep
        ? _selectedHuecas[_currentStep - 1]
        : null;

    return Column(
      children: [
        // Question Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isEn ? 'STOP $_currentStep OF $_totalStops' : 'PARADA $_currentStep DE $_totalStops',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  if (previousHueca != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEn ? 'From: ${previousHueca.name}' : 'Desde: ${previousHueca.name}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white70 : AppTheme.textMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _getQuestionTitle(previousHueca, isEn),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),

              // Craving chips selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _getCravingOptions(isEn).map((opt) {
                    final isSelected = _selectedCraving == opt.type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(opt.label),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCraving = opt.type);
                          }
                        },
                        selectedColor: AppTheme.primary.withOpacity(0.2),
                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? AppTheme.primary
                              : (isDark ? Colors.white70 : AppTheme.textMedium),
                        ),
                        side: BorderSide(
                          color: isSelected ? AppTheme.primary : Colors.transparent,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // List of candidate huecas
        Expanded(
          child: huecasAsync.when(
            data: (allHuecas) {
              // 1. Filter by craving
              List<Hueca> candidates = allHuecas.where((h) {
                if (!h.isActive) return false;
                // Do not re-pick huecas already selected in previous steps
                if (_selectedHuecas.take(_currentStep - 1).any((sh) => sh.id == h.id)) {
                  return false;
                }
                return TourDistanceHelper.matchesCraving(h, _selectedCraving);
              }).toList();

              // Fallback if matching category is empty
              final bool usedFallback = candidates.isEmpty;
              if (usedFallback) {
                candidates = allHuecas.where((h) =>
                    h.isActive &&
                    !_selectedHuecas.take(_currentStep - 1).any((sh) => sh.id == h.id)
                ).toList();
              }

              // 2. Sort by proximity if from previousHueca exists
              List<HuecaDistanceItem> items = [];
              if (previousHueca != null) {
                items = TourDistanceHelper.sortHuecasByProximity(
                  huecas: candidates,
                  fromHueca: previousHueca,
                );
              } else {
                // First stop: sort by rating / reviewCount
                candidates.sort((a, b) => b.rating.compareTo(a.rating));
                items = candidates.map((h) => HuecaDistanceItem(
                  hueca: h,
                  distanceKm: 0.0,
                  drivingMinutes: 0,
                  isClose: false,
                )).toList();
              }

              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      isEn
                          ? 'No matching huecas found. Try choosing another craving category above.'
                          : 'No se encontraron huecas con este antojo. Intenta seleccionar otra categoría arriba.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 90),
                itemCount: items.length + (previousHueca != null ? 1 : 0),
                itemBuilder: (context, index) {
                  // If second stop onwards, show an informative hint banner at index 0
                  if (previousHueca != null && index == 0) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.near_me_rounded, color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isEn
                                  ? 'Spots are ordered by proximity from ${previousHueca.name}. Closest first, but all spots remain available below!'
                                  : 'Huecas ordenadas por cercanía desde ${previousHueca.name}. ¡Las más cercanas primero, y todas las opciones disponibles abajo!',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final item = items[previousHueca != null ? index - 1 : index];
                  final isSelected = currentSelectedHueca?.id == item.hueca.id;

                  return _buildHuecaCard(
                    context,
                    item: item,
                    isSelected: isSelected,
                    showDistance: previousHueca != null,
                    isEn: isEn,
                    isDark: isDark,
                    onTap: () => _onHuecaSelected(item.hueca),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),

        // Bottom Confirmation Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentSelectedHueca != null
                          ? AppTheme.primary
                          : (isDark ? Colors.grey[800] : Colors.grey[300]),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: currentSelectedHueca != null ? _advanceToNextStop : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentStep < _totalStops
                              ? (isEn
                                  ? 'Confirm Stop $_currentStep & Continue'
                                  : 'Confirmar Parada $_currentStep y Continuar')
                              : (isEn ? 'See Tour Summary' : 'Ver Resumen del Tour'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHuecaCard(
    BuildContext context, {
    required HuecaDistanceItem item,
    required bool isSelected,
    required bool showDistance,
    required bool isEn,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final hueca = item.hueca;
    final dishName = () {
      if (hueca.mainDish['name'] is Map) {
        final m = hueca.mainDish['name'] as Map;
        return (m['es'] ?? m['en'] ?? '').toString();
      }
      return hueca.mainDish['name']?.toString() ?? '';
    }();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? AppTheme.primary
              : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
          width: isSelected ? 2.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppTheme.primary.withOpacity(0.12)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: hueca.images.isNotEmpty
                      ? Image.network(
                          hueca.images.first,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[300],
                            child: const Icon(Icons.restaurant, color: Colors.grey),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.restaurant, color: Colors.grey),
                        ),
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Proximity Badge (Rule: Closest at top with green badge, distant below)
                      if (showDistance) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.isClose
                                    ? const Color(0xFF10B981).withOpacity(0.15)
                                    : (isDark ? Colors.grey[800] : Colors.grey[200]),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.directions_car_rounded,
                                    size: 12,
                                    color: item.isClose
                                        ? const Color(0xFF059669)
                                        : (isDark ? Colors.white70 : AppTheme.textMedium),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${TourDistanceHelper.formatDistance(item.distanceKm)} • ~${item.drivingMinutes} min en auto',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: item.isClose
                                          ? const Color(0xFF059669)
                                          : (isDark ? Colors.white70 : AppTheme.textMedium),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (item.isClose) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isEn ? 'Very close' : 'Muy cerca',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],

                      Text(
                        hueca.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 2),
                          Text(
                            hueca.sector,
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.star, size: 12, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            hueca.rating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (dishName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '🍴 $dishName',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : AppTheme.textMedium,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Checkbox / Select indicator
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 6),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : Colors.grey[400]!,
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // FINAL STEP: SUMMARY & SAVE
  // ==========================================
  Widget _buildSummaryStep(bool isEn, bool isDark) {
    final metrics = TourDistanceHelper.calculateMetrics(_selectedHuecas);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Success Celebration Header
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primary,
                AppTheme.primary.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.3),
                blurRadius: 12,
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
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.celebration, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEn ? 'Your custom tour is ready!' : '¡Tu tour gastronómico está listo!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                isEn
                    ? 'A personalized route designed around your cravings, optimized by driving proximity.'
                    : 'Un recorrido personalizado según tus antojos, optimizado por cercanía en vehículo.',
                style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Tour Title Editable Field
        Text(
          isEn ? 'Tour Name' : 'Nombre de tu Tour',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.edit, color: AppTheme.primary, size: 20),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[250] ?? Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Metrics Row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryMetric(
                icon: Icons.storefront_rounded,
                value: '${_selectedHuecas.length} huecas',
                label: isEn ? 'Stops' : 'Paradas',
              ),
              Container(width: 1, height: 35, color: isDark ? Colors.grey[800] : Colors.grey[300]),
              _buildSummaryMetric(
                icon: Icons.straighten_rounded,
                value: TourDistanceHelper.formatDistance(metrics.totalDistanceKm),
                label: isEn ? 'Total Distance' : 'Distancia total',
              ),
              Container(width: 1, height: 35, color: isDark ? Colors.grey[800] : Colors.grey[300]),
              _buildSummaryMetric(
                icon: Icons.directions_car_rounded,
                value: '~${metrics.totalDurationMinutes} min',
                label: isEn ? 'Driving time' : 'Tiempo en auto',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Route Timeline of stops
        Text(
          isEn ? 'STOPS ITINERARY' : 'ITINERARIO DE PARADAS',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 14),

        ...List.generate(_selectedHuecas.length, (index) {
          final hueca = _selectedHuecas[index];
          final isLast = index == _selectedHuecas.length - 1;
          final leg = index < metrics.legs.length ? metrics.legs[index] : null;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: hueca.images.isNotEmpty
                          ? Image.network(
                              hueca.images.first,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 44,
                                height: 44,
                                color: Colors.grey[300],
                                child: const Icon(Icons.restaurant, size: 20),
                              ),
                            )
                          : Container(
                              width: 44,
                              height: 44,
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
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
                  ],
                ),
              ),

              if (!isLast && leg != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 28),
                      Container(width: 2, height: 26, color: AppTheme.primary.withOpacity(0.4)),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_car_rounded, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              '${TourDistanceHelper.formatDistance(leg.distanceKm)} • ~${leg.durationMinutes} min en auto',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 10),
              ],
            ],
          );
        }),

        const SizedBox(height: 24),

        // Action Buttons
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: _isSaving ? null : () => _saveTour(startNavigation: false),
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bookmark_added_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isEn ? 'Save Tour in My Profile' : 'Guardar Tour en mi Perfil',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),

        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.primary, width: 1.8),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: _isSaving ? null : () => _saveTour(startNavigation: true),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.navigation_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                isEn ? 'Save & Start Navigation' : 'Guardar e Iniciar Recorrido',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSummaryMetric({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary, size: 22),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  String _getQuestionTitle(Hueca? prev, bool isEn) {
    if (_currentStep == 1) {
      return isEn
          ? 'How do we kick off this Quito foodie tour?'
          : '¿Cómo arrancamos esta aventura gastronómica en Quito?';
    }

    final prevName = prev?.name ?? '';
    if (_currentStep == 2) {
      return isEn
          ? 'Great start at $prevName! What is the main craving now?'
          : '¡Buenazo el arranque en $prevName! ¿Con qué plato fuerte o antojo seguimos?';
    }

    if (_currentStep == _totalStops) {
      return isEn
          ? 'And what about dessert, coffee, or a late bite to wrap up?'
          : '¿Y el postrecito, café o bajón para cerrar con broche de oro?';
    }

    return isEn
        ? 'Next stop from $prevName: what are you in the mood for?'
        : 'Siguiente parada desde $prevName: ¿qué te pide el cuerpo ahora?';
  }

  List<({TourCravingType type, String label})> _getCravingOptions(bool isEn) {
    return [
      (type: TourCravingType.soup, label: isEn ? '🥣 Soups & Broths' : '🥣 Sopas y Caldos'),
      (type: TourCravingType.heavy, label: isEn ? '🍖 Traditional Mains' : '🍖 Platos Fuertes'),
      (type: TourCravingType.seafood, label: isEn ? '🐟 Seafood & Ceviche' : '🐟 Mariscos y Ceviche'),
      (type: TourCravingType.streetFood, label: isEn ? '🍔 Street Food' : '🍔 Comida Rápida'),
      (type: TourCravingType.snacks, label: isEn ? '🥟 Empanadas & Snacks' : '🥟 Picaditas'),
      (type: TourCravingType.dessert, label: isEn ? '🍨 Ice Cream & Sweets' : '🍨 Dulces y Postres'),
      (type: TourCravingType.any, label: isEn ? '🌟 All Huecas' : '🌟 Todas las Huecas'),
    ];
  }
}
