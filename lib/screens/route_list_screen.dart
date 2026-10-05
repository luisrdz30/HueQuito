import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/repositories/route_repository.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/screens/route_map_screen.dart';

class RouteListScreen extends ConsumerStatefulWidget {
  const RouteListScreen({super.key});

  @override
  ConsumerState<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends ConsumerState<RouteListScreen> {
  int _selectedTab = 0; // 0 for List, 1 for Map
  String _selectedFilter = 'Todos los circuitos';

  final List<String> _filters = [
    'Todos los circuitos',
    'A pie (≤ 30 min)',
    'Tradición Histórica',
    'Nocturno'
  ];

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(routesProvider);
    final huecasAsync = ref.watch(huecasProvider);
    final lang = ref.watch(settingsProvider).language;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 90,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant, color: AppTheme.primary, size: 24),
                const SizedBox(width: 8),
                Text('Hue-Quito', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: AppTheme.textMedium),
                      SizedBox(width: 4),
                      Text('Centro Hist...', style: TextStyle(fontSize: 12, color: AppTheme.textDark, fontWeight: FontWeight.bold)),
                      Icon(Icons.keyboard_arrow_down, size: 14, color: AppTheme.textMedium),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage('https://ui-avatars.com/api/?name=User'),
                )
              ],
            ),
            const SizedBox(height: 16),
            Text(lang == 'es' ? 'Circuitos Gastronómicos' : 'Gastronomic Tours', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            Text(lang == 'es' ? 'Recorridos a pie curados para saborear Quito' : 'Curated walking tours to savor Quito', style: const TextStyle(fontSize: 12, color: AppTheme.textMedium)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Toggle Segmented Control
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: _selectedTab == 0 ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.list, size: 18, color: _selectedTab == 0 ? AppTheme.primary : AppTheme.textMedium),
                            const SizedBox(width: 8),
                            Text('Lista de circuitos', style: TextStyle(
                              color: _selectedTab == 0 ? AppTheme.textDark : AppTheme.textMedium,
                              fontWeight: FontWeight.bold,
                              fontSize: 13
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: _selectedTab == 1 ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_outlined, size: 18, color: _selectedTab == 1 ? AppTheme.primary : AppTheme.textMedium),
                            const SizedBox(width: 8),
                            Text('Mapa interactivo', style: TextStyle(
                              color: _selectedTab == 1 ? AppTheme.textDark : AppTheme.textMedium,
                              fontWeight: FontWeight.bold,
                              fontSize: 13
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filters (only for list view)
          if (_selectedTab == 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: _filters.map((f) => GestureDetector(
                    onTap: () => setState(() => _selectedFilter = f),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedFilter == f ? const Color(0xFF4A685D) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _selectedFilter == f ? Colors.transparent : Colors.grey[300]!),
                      ),
                      child: Text(f, style: TextStyle(
                        color: _selectedFilter == f ? Colors.white : AppTheme.textDark,
                        fontWeight: FontWeight.w500,
                        fontSize: 12
                      )),
                    ),
                  )).toList(),
                ),
              ),
            ),

          // Main Content Area
          Expanded(
            child: _selectedTab == 0
                ? routesAsync.when(
                    data: (routes) {
                      if (routes.isEmpty) {
                        return Center(child: Text(lang == 'es' ? 'No hay rutas disponibles.' : 'No routes available.'));
                      }
                      return huecasAsync.when(
                        data: (huecasList) {
                          return ListView.builder(
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: routes.length + 1, // +1 for the footer
                            itemBuilder: (context, index) {
                              if (index == routes.length) {
                                return _buildFooter();
                              }
                              final route = routes[index];
                              bool isFeatured = index == 0; // First item is featured
                              return _buildRouteCard(context, route, lang, huecasList, isFeatured);
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e,s) => const Center(child: Text('Error cargando huecas')),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  )
                : const RouteMapScreen(), // Display Map Screen here!
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.secondary.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.explore, color: AppTheme.secondary, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Prefieres explorar libremente sin ruta fija?', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                SizedBox(height: 4),
                Text('Toca "Mapa interactivo" arriba o filtra para ver todas las huecas directamente en el mapa por categoría.', style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, RouteModel route, String lang, List<Hueca> huecasList, bool isFeatured) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Image
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Image.network(route.bannerImageUrl, height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.7), Colors.transparent]),
                ),
              ),
              Positioned(
                top: 16, left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    children: [
                      Icon(Icons.stars, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('Circuito Popular', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 16, right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    children: [
                      Icon(Icons.star, color: Colors.orange, size: 12),
                      SizedBox(width: 4),
                      Text('4.9 (184)', style: TextStyle(color: AppTheme.textDark, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 16, left: 16, right: 16,
                child: Text(route.name[lang] ?? route.name['es'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.1)),
              )
            ],
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFeatured) ...[
                  Text(route.narrative[lang] ?? route.narrative['es'] ?? '', style: const TextStyle(color: AppTheme.textMedium, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 16),
                  
                  // Metrics Box
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMetricCol(Icons.straighten, route.metrics['distance'] ?? '', 'Distancia'),
                        _buildMetricCol(Icons.directions_walk, route.metrics['estimatedTime'] ?? '', 'A pie'),
                        _buildMetricCol(Icons.storefront, '${route.stops.length} huecas', 'Paradas'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  const Text('PARADAS DEL RECORRIDO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                  const SizedBox(height: 16),
                  
                  // Timeline (Inlined)
                  ...route.stops.map((stop) {
                    final hueca = huecasList.firstWhere((h) => h.id == stop['huecaId'], orElse: () => huecasList.first);
                    final isLast = route.stops.last == stop;
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 24, height: 24,
                                decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                                child: Center(child: Text('${stop['order']}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                              ),
                              if (!isLast) Expanded(child: Container(width: 2, color: AppTheme.primary.withOpacity(0.3))),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(hueca.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                      Text(hueca.sector, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                                      children: [
                                        const TextSpan(text: 'Especialidad: ', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                                        TextSpan(text: hueca.mainDish['name'][lang] ?? hueca.mainDish['name']['es'], style: const TextStyle(color: AppTheme.textMedium)),
                                      ]
                                    ),
                                  )
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                      onPressed: () => context.push('/route_detail', extra: route),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.navigation, size: 18),
                          SizedBox(width: 8),
                          Text('Iniciar recorrido a pie', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      style: TextButton.styleFrom(backgroundColor: Colors.grey[100], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                      onPressed: () {},
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on_outlined, size: 18, color: AppTheme.textDark),
                          SizedBox(width: 8),
                          Text('Ver paradas en mapa', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Compact View
                  Text(route.narrative[lang] ?? route.narrative['es'] ?? '', style: const TextStyle(color: AppTheme.textMedium, fontSize: 13, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.straighten, size: 14, color: AppTheme.primary), const SizedBox(width: 4),
                      Text(route.metrics['distance'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      const Icon(Icons.schedule, size: 14, color: AppTheme.primary), const SizedBox(width: 4),
                      Text(route.metrics['estimatedTime'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      const Icon(Icons.storefront, size: 14, color: AppTheme.primary), const SizedBox(width: 4),
                      Text('${route.stops.length} huecas', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: route.stops.take(2).map((stop) {
                        final hueca = huecasList.firstWhere((h) => h.id == stop['huecaId'], orElse: () => huecasList.first);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 16, height: 16,
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: Center(child: Text('${stop['order']}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text('${hueca.name} • ${hueca.mainDish['name']['es']}', style: const TextStyle(fontSize: 11, color: AppTheme.textDark), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: TextButton(
                      style: TextButton.styleFrom(backgroundColor: Colors.grey[100], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      onPressed: () => context.push('/route_detail', extra: route),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Ver circuito completo', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark, fontSize: 12)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 14, color: AppTheme.textDark),
                        ],
                      ),
                    ),
                  ),
                ]
              ],
            ),
          )
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
