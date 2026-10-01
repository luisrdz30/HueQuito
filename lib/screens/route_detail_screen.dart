import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hue_quito/repositories/route_repository.dart';

class RouteDetailScreen extends StatelessWidget {
  final Object? routeModel;
  
  const RouteDetailScreen({super.key, this.routeModel});

  @override
  Widget build(BuildContext context) {
    if (routeModel == null || routeModel is! RouteModel) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Ruta no especificada')),
      );
    }
    
    final route = routeModel as RouteModel;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppTheme.primary,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
                  child: IconButton(
                    icon: const Icon(Icons.share, color: AppTheme.textDark),
                    onPressed: () {
                      Share.share('¡Vamos a hacer la ${route.name['es']}! Descárgate HueQuito.');
                    },
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                route.bannerImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.name['es'] ?? 'Ruta',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    route.description['es'] ?? '',
                    style: const TextStyle(color: AppTheme.textMedium, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  
                  // Info Cards
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(children: [Icon(Icons.timer, size: 16, color: AppTheme.textMedium), SizedBox(width: 4), Text('Tiempo', style: TextStyle(color: AppTheme.textMedium, fontSize: 12))]),
                              const SizedBox(height: 4),
                              Text(route.estimatedTime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [Icon(route.transportMethod['es'] == 'A pie' ? Icons.directions_walk : Icons.directions_car, size: 16, color: AppTheme.textMedium), const SizedBox(width: 4), const Text('Distancia', style: TextStyle(color: AppTheme.textMedium, fontSize: 12))]),
                              const SizedBox(height: 4),
                              Text(route.totalDistance, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Map Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/route_map', extra: route),
                      icon: const Icon(Icons.map, color: Colors.white),
                      label: const Text('Ver Mapa de Ruta'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  const Text('Itinerario Sugerido', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // Stops list
                  ...route.stops.map((stop) {
                    int idx = route.stops.indexOf(stop);
                    bool isLast = idx == route.stops.length - 1;
                    return _buildTimelineItem(
                      number: stop['order'].toString(),
                      title: 'Parada ${stop['order']}',
                      description: stop['description']['es'] ?? '',
                      isLast: isLast,
                    );
                  }).toList(),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTimelineItem({required String number, required String title, required String description, bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 30, height: 30,
              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
              child: Center(child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ),
            if (!isLast)
              Container(
                width: 2, height: 80,
                color: AppTheme.primary.withOpacity(0.3),
                margin: const EdgeInsets.symmetric(vertical: 4),
              )
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(color: AppTheme.textMedium, fontSize: 14, height: 1.4)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}
