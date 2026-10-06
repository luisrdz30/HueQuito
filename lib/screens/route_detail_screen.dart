import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/repositories/route_repository.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:share_plus/share_plus.dart';

class RouteDetailScreen extends ConsumerWidget {
  final Object? routeModel;
  
  const RouteDetailScreen({super.key, this.routeModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (routeModel == null || routeModel is! RouteModel) {
      return Scaffold(
        appBar: AppBar(title: Text('Error')),
        body: Center(child: Text('Ruta no especificada')),
      );
    }
    
    final route = routeModel as RouteModel;
    final huecasAsync = ref.watch(huecasProvider);
    final lang = ref.watch(settingsProvider).language;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppTheme.primary,
            leading: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
                  child: IconButton(
                    icon: Icon(Icons.share, color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () {
                      final sector = route.tags.isNotEmpty ? route.tags.first.toString() : 'Quito';
                      final huecasList = huecasAsync.value ?? [];
                      List<String> huecaNames = [];
                      for (var stop in route.stops) {
                        final h = huecasList.where((h) => h.id == stop['huecaId']).firstOrNull;
                        if (h != null) huecaNames.add(h.name);
                      }
                      final text = lang == 'es' 
                          ? '¡Acompáñame a este tour por $sector!\nLas huecas que visitaríamos son:\n- ${huecaNames.join('\n- ')}\n\n¡Descarga HueQuito y vamos!'
                          : 'Join me on this tour around $sector!\nThe spots we will visit are:\n- ${huecaNames.join('\n- ')}\n\nDownload HueQuito and let\'s go!';
                      Share.share(text);
                    },
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    route.bannerImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                        stops: [0.4, 0.8, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.explore, color: AppTheme.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              lang == 'es' ? 'CIRCUITO GASTRONÓMICO' : 'GASTRONOMIC CIRCUIT',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          route.name[lang] ?? route.name['es'],
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: route.tags.map<Widget>((tagData) {
                      if (tagData is String) {
                        return Chip(
                          label: Text(tagData, style: TextStyle(fontSize: 12)),
                          backgroundColor: Theme.of(context).cardColor,
                          side: BorderSide.none,
                        );
                      } else if (tagData is Map) {
                        IconData getIcon(String? i) {
                          switch (i) {
                            case 'location_on': return Icons.location_on;
                            case 'restaurant': return Icons.restaurant;
                            case 'family_restroom': return Icons.family_restroom;
                            case 'nights_stay': return Icons.nights_stay;
                            case 'fastfood': return Icons.fastfood;
                            default: return Icons.label;
                          }
                        }
                        return Chip(
                          avatar: Icon(getIcon(tagData['icon']), size: 16, color: AppTheme.textMedium),
                          label: Text(tagData['text']?[lang] ?? tagData['text']?['es'] ?? '', style: TextStyle(fontSize: 12)),
                          backgroundColor: Theme.of(context).cardColor,
                          side: BorderSide.none,
                        );
                      }
                      return SizedBox.shrink();
                    }).toList(),
                  ),
                  SizedBox(height: 16),

                  // Metrics
                  Row(
                    children: [
                      _buildMetricCard(context, Icons.straighten, lang == 'es' ? 'Distancia' : 'Distance', route.metrics['distance'] ?? '-'),
                      SizedBox(width: 8),
                      _buildMetricCard(context, Icons.schedule, lang == 'es' ? 'Tiempo' : 'Time', route.metrics['estimatedTime'] ?? '-'),
                      SizedBox(width: 8),
                      _buildMetricCard(context, Icons.pin_drop, lang == 'es' ? 'Paradas' : 'Stops', '${route.stops.length}'),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Recommended Schedule
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.wb_sunny, color: AppTheme.secondary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (lang == 'es' ? 'Horario recomendado: ${route.recommendedSchedule['time']?[lang] ?? route.recommendedSchedule['time']?['es'] ?? ''}' : 'Recommended schedule: ${route.recommendedSchedule['time']?[lang] ?? route.recommendedSchedule['time']?['en'] ?? ''}'),
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondary),
                              ),
                              SizedBox(height: 4),
                              Text(
                                route.recommendedSchedule['note']?[lang] ?? route.recommendedSchedule['note']?['es'] ?? '',
                                style: TextStyle(color: AppTheme.textMedium, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Narrative
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history_edu, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Text(
                              lang == 'es' ? 'Crónica del Sabor' : 'Flavor Chronicle',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          route.narrative[lang] ?? route.narrative['es'],
                          style: TextStyle(color: AppTheme.textMedium, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Itinerary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.format_list_numbered, color: AppTheme.secondary),
                          SizedBox(width: 8),
                          Text(
                            lang == 'es' ? 'Paradas del Circuito' : 'Circuit Stops',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                      Text(
                        '${route.stops.length} ${lang == 'es' ? 'Huecas' : 'Huecas'}',
                        style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                  SizedBox(height: 16),

                  // Stops Timeline
                  huecasAsync.when(
                    data: (huecasList) {
                      return ListView.builder(
                        padding: EdgeInsets.zero,
                        physics: NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: route.stops.length,
                        itemBuilder: (context, index) {
                          final stop = route.stops[index];
                          final isLast = index == route.stops.length - 1;
                          final hueca = huecasList.firstWhere((h) => h.id == stop['huecaId'], orElse: () => huecasList.first);
                          
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Timeline line and number
                                Column(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${stop['order']}',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                    ),
                                    if (!isLast)
                                      Expanded(
                                        child: Container(
                                          width: 2,
                                          color: Theme.of(context).dividerColor,
                                        ),
                                      )
                                  ],
                                ),
                                SizedBox(width: 16),
                                
                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Stop Card
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        margin: EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              hueca.name,
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            SizedBox(height: 8),
                                            Row(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.network(
                                                    hueca.images.isNotEmpty ? hueca.images[0] : 'https://via.placeholder.com/80',
                                                    width: 64,
                                                    height: 64,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        hueca.mainDish['name'][lang] ?? hueca.mainDish['name']['es'],
                                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Icon(Icons.star, size: 14, color: AppTheme.primary),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            hueca.rating.toString(),
                                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                          ),
                                                        ],
                                                      )
                                                    ],
                                                  ),
                                                )
                                              ],
                                            ),
                                            SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.schedule, size: 14, color: AppTheme.textMedium),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      hueca.schedule['monday'] ?? '',
                                                      style: TextStyle(fontSize: 12, color: AppTheme.textMedium),
                                                    ),
                                                  ],
                                                ),
                                                TextButton.icon(
                                                  onPressed: () {
                                                    context.push('/hueca_detail', extra: hueca);
                                                  },
                                                  icon: Text(
                                                    lang == 'es' ? 'Ver Hueca' : 'View Hueca',
                                                    style: TextStyle(fontSize: 12),
                                                  ),
                                                  label: Icon(Icons.chevron_right, size: 16),
                                                  style: TextButton.styleFrom(
                                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                )
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                      
                                      // Travel Step (if not last)
                                      if (!isLast && stop['travelToNext'] != null)
                                        Padding(
                                          padding: EdgeInsets.only(bottom: 16),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).cardColor.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.directions_walk, size: 14, color: AppTheme.textMedium),
                                                SizedBox(width: 4),
                                                Text(
                                                  '${stop['travelToNext']['duration']} (${stop['travelToNext']['distance']}) ${stop['travelToNext']['instruction'][lang] ?? stop['travelToNext']['instruction']['es']}',
                                                  style: TextStyle(fontSize: 12, color: AppTheme.textMedium),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                    ],
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => Center(child: CircularProgressIndicator()),
                    error: (e, s) => Text('Error: $e'),
                  ),
                  SizedBox(height: 32),
                  // Start Route Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                      onPressed: () {
                        if (huecasAsync.value == null) return;
                        final List<Hueca> routeStops = [];
                        for (var s in route.stops) {
                          final h = huecasAsync.value!.where((h) => h.id == s['huecaId']).firstOrNull;
                          if (h != null) routeStops.add(h);
                        }
                        context.push('/route_navigation', extra: {'route': route, 'stops': routeStops});
                      },
                      icon: Icon(Icons.navigation_outlined, color: Colors.white),
                      label: Text(lang == 'es' ? 'Iniciar Recorrido en GPS' : 'Start GPS Tour', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  SizedBox(height: 32),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: AppTheme.primary),
            ),
            SizedBox(height: 8),
            Text(label.toUpperCase(), style: TextStyle(fontSize: 10, color: AppTheme.textMedium, fontWeight: FontWeight.bold)),
            SizedBox(height: 2),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
