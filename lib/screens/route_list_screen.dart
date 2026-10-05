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
  String _selectedSector = 'Todos';

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
                // Sector Filter Dropdown
                if (_selectedTab == 0)
                  huecasAsync.when(
                    data: (huecasList) {
                      final sectors = ['Todos']..addAll(huecasList.map((h) => h.sector).toSet().toList()..sort());
                      return Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSector,
                            icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: AppTheme.textMedium),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textDark, fontWeight: FontWeight.bold),
                            onChanged: (String? newValue) {
                              if (newValue != null) setState(() => _selectedSector = newValue);
                            },
                            items: sectors.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 14, color: AppTheme.textMedium),
                                    const SizedBox(width: 4),
                                    Text(value.length > 15 ? '${value.substring(0,12)}...' : value),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_,__) => const SizedBox.shrink(),
                  ),
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

          // Main Content Area
          Expanded(
            child: _selectedTab == 0
                ? routesAsync.when(
                    data: (routes) {
                      return huecasAsync.when(
                        data: (huecasList) {
                          // Filter routes by selected sector
                          List<RouteModel> filteredRoutes = routes;
                          if (_selectedSector != 'Todos') {
                            filteredRoutes = routes.where((route) {
                              // Check if any stop in the route belongs to the selected sector
                              return route.stops.any((stop) {
                                final hueca = huecasList.firstWhere((h) => h.id == stop['huecaId'], orElse: () => huecasList.first);
                                return hueca.sector == _selectedSector;
                              });
                            }).toList();
                          }

                          if (filteredRoutes.isEmpty) {
                            return Center(child: Text(lang == 'es' ? 'No hay rutas en este sector.' : 'No routes in this area.'));
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: filteredRoutes.length + 1, // +1 for the footer
                            itemBuilder: (context, index) {
                              if (index == filteredRoutes.length) {
                                return _buildFooter();
                              }
                              final route = filteredRoutes[index];
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
                Text('Toca "Mapa interactivo" arriba o filtra para ver todas las huecas directamente en el mapa por sector.', style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.push('/route_detail', extra: route),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Ver Tour', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), padding: const EdgeInsets.symmetric(vertical: 12)),
                          onPressed: () {
                            // Find all huecas for this route
                            final List<Hueca> routeStops = [];
                            for (var s in route.stops) {
                              final h = huecasList.where((h) => h.id == s['huecaId']).firstOrNull;
                              if (h != null) routeStops.add(h);
                            }
                            context.push('/route_navigation', extra: {'route': route, 'stops': routeStops});
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.navigation, size: 16, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Iniciar Ruta', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
