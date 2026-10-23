import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/repositories/route_repository.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/screens/route_map_screen.dart';
import 'package:hue_quito/widgets/tour_mode_selection_dialog.dart';

class RouteListScreen extends ConsumerStatefulWidget {
  const RouteListScreen({super.key});

  @override
  ConsumerState<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends ConsumerState<RouteListScreen> {
  int _selectedTab = 0; // 0 for Mis Tours, 1 for Mapa Interactivo

  void _openCreateTourDialog(BuildContext context, String lang) {
    TourModeSelectionDialog.show(context, language: lang);
  }

  Future<void> _confirmDeleteTour(BuildContext context, RouteModel tour, String lang) async {
    final isEn = lang == 'en';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? 'Delete Tour' : 'Eliminar Tour'),
        content: Text(
          isEn
              ? 'Are you sure you want to remove "${tour.name['en'] ?? tour.name['es']}" from your profile?'
              : '¿Estás seguro de que deseas eliminar "${tour.name['es'] ?? tour.name['en']}" de tu perfil?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isEn ? 'Cancel' : 'Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isEn ? 'Delete' : 'Eliminar', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final user = ref.read(currentUserProvider).value;
      final uid = user?.uid ?? 'guest';
      await ref.read(routeRepositoryProvider).deleteUserTour(tour.id, userId: uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEn ? 'Tour deleted' : 'Tour eliminado correctamente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userToursAsync = ref.watch(userToursStreamProvider);
    final huecasAsync = ref.watch(huecasProvider);
    final lang = ref.watch(settingsProvider).language;
    final isEn = lang == 'en';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.restaurant, color: AppTheme.primary, size: 24),
            const SizedBox(width: 8),
            Text(
              'Hue-Quito',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        actions: [
          if (_selectedTab == 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  isEn ? 'New Tour' : 'Crear Tour',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _openCreateTourDialog(context, lang),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Subtitle (Clean layout without overlapping)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn ? 'My Gastronomic Tours' : 'Mis Tours Gastronómicos',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEn ? 'Your custom food routes in Quito' : 'Tus recorridos personalizados para saborear Quito',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : AppTheme.textMedium,
                  ),
                ),
              ],
            ),
          ),

          // Segmented Toggle for "Mis Tours" vs "Mapa interactivo"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  // Tab 0: Mis Tours
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? (isDark ? AppTheme.primary : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: _selectedTab == 0
                              ? [
                                  BoxShadow(
                                    color: isDark
                                        ? AppTheme.primary.withOpacity(0.35)
                                        : Colors.black.withOpacity(0.08),
                                    blurRadius: isDark ? 8 : 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.explore_rounded,
                              size: 18,
                              color: _selectedTab == 0
                                  ? (isDark ? Colors.white : AppTheme.primary)
                                  : (isDark ? Colors.grey[400] : AppTheme.textMedium),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEn ? 'My Tours' : 'Mis Tours',
                              style: TextStyle(
                                color: _selectedTab == 0
                                    ? (isDark ? Colors.white : AppTheme.primary)
                                    : (isDark ? Colors.grey[400] : AppTheme.textMedium),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Tab 1: Mapa interactivo (kept intact)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? (isDark ? AppTheme.primary : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: _selectedTab == 1
                              ? [
                                  BoxShadow(
                                    color: isDark
                                        ? AppTheme.primary.withOpacity(0.35)
                                        : Colors.black.withOpacity(0.08),
                                    blurRadius: isDark ? 8 : 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 18,
                              color: _selectedTab == 1
                                  ? (isDark ? Colors.white : AppTheme.primary)
                                  : (isDark ? Colors.grey[400] : AppTheme.textMedium),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEn ? 'Interactive Map' : 'Mapa interactivo',
                              style: TextStyle(
                                color: _selectedTab == 1
                                    ? (isDark ? Colors.white : AppTheme.primary)
                                    : (isDark ? Colors.grey[400] : AppTheme.textMedium),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main View Content
          Expanded(
            child: _selectedTab == 0
                ? userToursAsync.when(
                    data: (userTours) {
                      return huecasAsync.when(
                        data: (huecasList) {
                          if (userTours.isEmpty) {
                            return _buildEmptyToursState(context, isEn, isDark, lang);
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.only(top: 4, bottom: 120),
                            itemCount: userTours.length,
                            itemBuilder: (context, index) {
                              final tour = userTours[index];
                              return _buildCustomTourCard(
                                context,
                                tour: tour,
                                lang: lang,
                                isEn: isEn,
                                isDark: isDark,
                                huecasList: huecasList,
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Error cargando huecas: $e')),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Error: $err')),
                  )
                : const RouteMapScreen(initialSector: 'Todos'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // EMPTY STATE FOR "MIS TOURS"
  // ==========================================
  Widget _buildEmptyToursState(BuildContext context, bool isEn, bool isDark, String lang) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.explore_outlined, color: AppTheme.primary, size: 48),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isEn ? 'You haven’t created a tour yet!' : '¡Aún no tienes tours creados!',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            isEn
                ? 'Design your own gastronomic adventure in Quito. Answer quick cravings questions to get spots ordered by proximity, or pick your favorite huecas step by step.'
                : 'Diseña tu propio recorrido gastronómico en Quito. Responde unas preguntas de antojo para sugerirte huecas por cercanía, o elígelas libremente parada por parada.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? Colors.white70 : AppTheme.textMedium,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Two creation cards directly inside empty state
          _buildQuickActionCard(
            context,
            isDark: isDark,
            emoji: '🪄',
            title: isEn ? 'Question-guided Tour' : 'Tour Asistido por Preguntas',
            subtitle: isEn
                ? 'We ask what you crave and suggest spots closest to your route.'
                : 'Te preguntamos tus antojos y te sugerimos huecas priorizando cercanía.',
            onTap: () => context.push('/tour_wizard'),
          ),
          const SizedBox(height: 12),

          _buildQuickActionCard(
            context,
            isDark: isDark,
            emoji: '🗺️',
            title: isEn ? 'Build it My Way' : 'Armar a mi Manera',
            subtitle: isEn
                ? 'Manually select huecas, reorder stops and see total driving time.'
                : 'Elige las huecas del catálogo, ordénalas y calcula el tiempo en auto.',
            onTap: () => context.push('/create_tour'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required bool isDark,
    required String emoji,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[250] ?? Colors.grey[300]!,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // CUSTOM TOUR CARD
  // ==========================================
  Widget _buildCustomTourCard(
    BuildContext context, {
    required RouteModel tour,
    required String lang,
    required bool isEn,
    required bool isDark,
    required List<Hueca> huecasList,
  }) {
    // Resolve Huecas for this tour
    final List<Hueca> routeStops = [];
    for (var s in tour.stops) {
      final h = huecasList.where((h) => h.id == s['huecaId']).firstOrNull;
      if (h != null) routeStops.add(h);
    }

    final tourTitle = tour.name[lang] ?? tour.name['es'] ?? (isEn ? 'My Tour' : 'Mi Tour');
    final distanceText = tour.metrics['distance']?.toString() ?? '0 km';
    final timeText = tour.metrics['estimatedTime']?.toString() ?? '0 min';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image & Title Header
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Image.network(
                  tour.bannerImageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: Colors.grey[800],
                    child: const Icon(Icons.restaurant, color: Colors.white, size: 40),
                  ),
                ),
              ),
              Container(
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Badge
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        isEn ? 'My Custom Tour' : 'Tour Personalizado',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Delete Button
              Positioned(
                top: 10,
                right: 10,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.black.withOpacity(0.5),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                    onPressed: () => _confirmDeleteTour(context, tour, lang),
                  ),
                ),
              ),
              // Title
              Positioned(
                bottom: 14,
                left: 16,
                right: 16,
                child: Text(
                  tourTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metrics Box
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMetricCol(Icons.storefront, '${tour.stops.length} huecas', isEn ? 'Stops' : 'Paradas'),
                      _buildMetricCol(Icons.straighten, distanceText, isEn ? 'Distance' : 'Distancia'),
                      _buildMetricCol(Icons.directions_car, timeText, isEn ? 'By Car' : 'En auto'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Stops Timeline
                Text(
                  isEn ? 'STOPS IN THIS TOUR' : 'PARADAS DEL RECORRIDO',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),

                ...List.generate(tour.stops.length, (index) {
                  final stop = tour.stops[index];
                  final hueca = huecasList.firstWhere(
                    (h) => h.id == stop['huecaId'],
                    orElse: () => Hueca(
                      id: stop['huecaId']?.toString() ?? '',
                      name: 'Hueca',
                      description: {'es': ''},
                      address: '',
                      sector: 'Quito',
                      location: const GeoPoint(-0.2186, -78.5080),
                      phone: '',
                      schedule: {},
                      mainDish: {},
                      loyaltyCard: {},
                      secretSticker: {},
                      menuItems: [],
                      tags: [],
                      priceLevel: '\$',
                      rating: 5.0,
                      reviewCount: 1,
                      images: [],
                      ownerId: '',
                      isActive: true,
                      metrics: {},
                    ),
                  );
                  final isLast = index == tour.stops.length - 1;

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: AppTheme.primary.withOpacity(0.3),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        hueca.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      hueca.sector,
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                if (hueca.mainDish['name'] != null)
                                  Builder(builder: (context) {
                                    final dishName = () {
                                      if (hueca.mainDish['name'] is Map) {
                                        final m = hueca.mainDish['name'] as Map;
                                        return (m[lang] ?? m['es'] ?? m['en'] ?? '').toString();
                                      }
                                      return hueca.mainDish['name']?.toString() ?? '';
                                    }();
                                    return Text(
                                      '🍴 $dishName',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white70 : AppTheme.textMedium,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // Action Buttons: Ver Tour & Iniciar Ruta
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.push('/route_detail', extra: tour),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          isEn ? 'View Tour' : 'Ver Tour',
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 1,
                        ),
                        onPressed: () {
                          context.push('/route_navigation', extra: {
                            'route': tour,
                            'stops': routeStops,
                          });
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.navigation, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              isEn ? 'Start Route' : 'Iniciar Ruta',
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
        ],
      ),
    );
  }

  Widget _buildMetricCol(IconData icon, String val, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
