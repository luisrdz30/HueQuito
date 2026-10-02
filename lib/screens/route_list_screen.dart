import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/repositories/route_repository.dart';
import 'package:hue_quito/utils/seed_routes.dart' as seed_r;

class RouteListScreen extends ConsumerWidget {
  const RouteListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(routesProvider);
    final lang = ref.watch(settingsProvider).language;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 70,
        leading: IconButton(
          icon: const Icon(Icons.cloud_upload, color: AppTheme.primary),
          onPressed: () async {
            await seed_r.seedRoutes(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rutas inyectadas a Firebase')));
          },
        ),
        title: Row(
          children: [
            const Icon(Icons.restaurant, color: AppTheme.primary, size: 32),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hue-Quito', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
                Text(lang == 'es' ? 'Circuitos Gastronómicos' : 'Gastronomic Tours', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMedium)),
              ],
            )
          ],
        ),
      ),
      body: routesAsync.when(
        data: (routes) {
          if (routes.isEmpty) {
            return Center(child: Text(lang == 'es' ? 'No hay rutas disponibles.' : 'No routes available.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: routes.length,
            itemBuilder: (context, index) {
              final route = routes[index];
              return _buildRouteCard(context, route, lang);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, RouteModel route, String lang) {
    return GestureDetector(
      onTap: () => context.push('/route_detail', extra: route),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: Column(
          children: [
            // Image header
            Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                image: DecorationImage(
                  image: NetworkImage(route.bannerImageUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.explore, color: AppTheme.primary, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          lang == 'es' ? 'CIRCUITO GASTRONÓMICO' : 'GASTRONOMIC TOUR',
                          style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      route.name[lang] ?? route.name['es'] ?? 'Ruta',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.pin_drop, color: AppTheme.primary, size: 16),
                          const SizedBox(width: 4),
                          Text('${route.stops.length} ${lang == 'es' ? 'Paradas' : 'Stops'}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.schedule, color: AppTheme.textMedium, size: 16),
                          const SizedBox(width: 4),
                          Text(route.metrics['estimatedTime'] ?? '', style: const TextStyle(color: AppTheme.textMedium)),
                          const SizedBox(width: 12),
                          const Icon(Icons.straighten, color: AppTheme.textMedium, size: 16),
                          const SizedBox(width: 4),
                          Text(route.metrics['distance'] ?? '', style: const TextStyle(color: AppTheme.textMedium)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    route.narrative[lang] ?? route.narrative['es'] ?? '',
                    style: const TextStyle(color: AppTheme.textMedium, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.push('/route_detail', extra: route),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primary)),
                      child: Text(lang == 'es' ? 'Ver Itinerario' : 'View Itinerary', style: const TextStyle(color: AppTheme.primary)),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
