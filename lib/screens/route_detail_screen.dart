import 'package:flutter/material.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/services/directions_service.dart';
import 'package:share_plus/share_plus.dart';

class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({super.key});

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  bool _isFavorite = false;
  String _leg1Info = 'Calculando...';
  String _leg2Info = 'Calculando...';
  String _leg3Info = 'Calculando...';

  @override
  void initState() {
    super.initState();
    _fetchDirections();
  }

  Future<void> _fetchDirections() async {
    // Coordenadas aproximadas
    // 1. Ponches Don Michi (-0.2215, -78.5135)
    // 2. Hornado San Francisco (-0.220164, -78.512327)
    // 3. Colaciones Cruz Verde (-0.2220, -78.5150)
    // 4. Morocho Doña Tina (-0.2235, -78.5165)
    
    final leg1 = await DirectionsService.getDirections(-0.2215, -78.5135, -0.220164, -78.512327);
    if (mounted && leg1 != null) {
      setState(() {
        _leg1Info = '${leg1['duration']} (${leg1['distance']}) hacia Plaza San Francisco';
      });
    } else {
      if (mounted) setState(() => _leg1Info = '7 min (550 m) hacia Plaza San Francisco');
    }

    final leg2 = await DirectionsService.getDirections(-0.220164, -78.512327, -0.2220, -78.5150);
    if (mounted && leg2 != null) {
      setState(() {
        _leg2Info = '${leg2['duration']} (${leg2['distance']}) por Calle Bolívar';
      });
    } else {
      if (mounted) setState(() => _leg2Info = '5 min (380 m) por Calle Bolívar');
    }

    final leg3 = await DirectionsService.getDirections(-0.2220, -78.5150, -0.2235, -78.5165);
    if (mounted && leg3 != null) {
      setState(() {
        _leg3Info = '${leg3['duration']} (${leg3['distance']}) hacia Barrio San Roque';
      });
    } else {
      if (mounted) setState(() => _leg3Info = '8 min (650 m) hacia Barrio San Roque');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        toolbarHeight: 70,
        title: Row(
          children: [
            const Icon(Icons.restaurant, color: AppTheme.primary, size: 32),
            const SizedBox(width: 8),
            Text('Spot Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
            color: _isFavorite ? Colors.red : AppTheme.secondary,
            onPressed: () {
              setState(() {
                _isFavorite = !_isFavorite;
              });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isFavorite ? 'Ruta añadida a favoritos' : 'Ruta eliminada de favoritos'), duration: const Duration(seconds: 1)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            color: AppTheme.textMedium,
            onPressed: () {
              Share.share('¡Acompáñame a hacer la ruta gastronómica "Ruta de los Sabores Tradicionales" en Hue-Quito! 😋🥘\n\nDescubre más de 4 huecas en el Centro Histórico: https://maps.google.com/?q=-0.220164,-78.512327');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map Hero Banner
            Stack(
              children: [
                Image.network(
                  'https://images.unsplash.com/photo-1596422846543-74c6c19034f5?auto=format&fit=crop&w=800&q=80',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(height: 200, color: Colors.grey[300], child: const Icon(Icons.image, size: 50, color: Colors.grey)),
                ),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.explore, color: AppTheme.primary, size: 16),
                          const SizedBox(width: 4),
                          Text('Circuito Gastronómico #01'.toUpperCase(), style: TextStyle(color: AppTheme.primary.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ],
                      ),
                      const Text('Ruta Colonial de Sabores', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              ],
            ),
            
            // Tags
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  _buildTag(Icons.location_on, 'Centro Histórico', AppTheme.secondary.withValues(alpha: 0.1), AppTheme.secondary),
                  _buildTag(Icons.restaurant, 'Platos Típicos', AppTheme.tertiary.withValues(alpha: 0.1), AppTheme.tertiary),
                  _buildTag(Icons.family_restroom, 'Apto Familiar', Colors.grey[200]!, AppTheme.textMedium),
                ],
              ),
            ),
            
            // Key Metrics
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(child: _buildMetricCard(Icons.straighten, 'Distancia', '2.4 km', AppTheme.primary)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard(Icons.schedule, 'Tiempo', '2h 30m', AppTheme.secondary)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard(Icons.pin_drop, 'Paradas', '4 Puntos', AppTheme.primary.withValues(alpha: 0.5))),
                ],
              ),
            ),
            
            // Alert Callout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.wb_sunny, color: AppTheme.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Horario recomendado: 09:30 AM a 02:00 PM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('Momento cumbre para saborear el cuero crocante de hornado recién horneado y degustar el ponche esponjoso caliente con canela.', style: TextStyle(color: Colors.black.withValues(alpha: 0.7), fontSize: 12)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            
            // Narrative
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [Icon(Icons.history_edu, color: AppTheme.primary), SizedBox(width: 8), Text('Crónica del Sabor Quiteño', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                    const SizedBox(height: 8),
                    Text('Un recorrido sensorial a través de empedrados centenarios que serpentean desde los soportales de la Plaza de la Independencia, pasando por la mística plazoleta de San Francisco, hasta el corazón bullicioso de San Roque. Aquí la cocina conventual colonial abraza el fogón popular andino.', style: TextStyle(color: Colors.black.withValues(alpha: 0.6), fontSize: 14, height: 1.5)),
                  ],
                ),
              ),
            ),
            
            // Itinerary
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [Icon(Icons.format_list_numbered, color: AppTheme.secondary), SizedBox(width: 8), Text('Paradas del Circuito', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
                      Text('4 Hitos Gastronómicos', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  _buildStopCard(context,
                    1,
                    'Ponches Don Michi',
                    'Plaza Grande',
                    'Famosos ponches calientes para empezar.',
                    'https://images.unsplash.com/photo-1544148103-0773bf10d330?auto=format&fit=crop&w=800&q=80',
                  ),
                  _buildTravelInfo(_leg1Info),
                  
                  _buildStopCard(context,
                    2,
                    'Hornado San Francisco',
                    'Mercado San Francisco',
                    'Hornado con cuero crocante y mote.',
                    'https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&w=800&q=80',
                  ),
                  _buildTravelInfo(_leg2Info),
                  
                  _buildStopCard(context,
                    3,
                    'Colaciones Cruz Verde',
                    'Calle Bolívar & Guayaquil',
                    'Dulces tradicionales de maní y miel.',
                    'https://images.unsplash.com/photo-1582293041079-7814c2f12063?auto=format&fit=crop&w=800&q=80',
                  ),
                  _buildTravelInfo(_leg3Info),
                  
                  _buildStopCard(context,
                    4,
                    'Morocho Doña Tina',
                    'San Roque',
                    'Morocho dulce con empanadas de viento.',
                    'https://images.unsplash.com/photo-1574126154517-d1e0d89ef734?auto=format&fit=crop&w=800&q=80',
                  ),
                  
                  const SizedBox(height: 80), // Padding for sticky bottom
                ],
              ),
            )
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => context.push('/route_map'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.navigation),
                SizedBox(width: 8),
                Text('Iniciar Recorrido en GPS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(IconData icon, String title, String value, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 10, color: AppTheme.textMedium, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStopCard(BuildContext context, int number, String title, String location, String desc, String imageUrl) {
    return GestureDetector(
      onTap: () => context.push('/hueca_detail'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 12),
            decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
            child: Center(child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [const Icon(Icons.circle, size: 8, color: AppTheme.tertiary), const SizedBox(width: 4), Text(location, style: const TextStyle(fontSize: 10, color: AppTheme.tertiary, fontWeight: FontWeight.bold))]),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppTheme.tertiary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: const Text('Abierto', style: TextStyle(color: AppTheme.tertiary, fontSize: 10, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: 80, height: 80, color: Colors.grey[300], child: const Icon(Icons.fastfood, color: Colors.grey)))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Especialidad Tradicional', style: TextStyle(fontSize: 10, color: AppTheme.textMedium)),
                            Text(desc, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            const Row(children: [Icon(Icons.star, size: 12, color: AppTheme.primary), SizedBox(width: 2), Text('4.9', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold))]),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(children: [Icon(Icons.schedule, size: 14, color: AppTheme.textMedium), SizedBox(width: 4), Text('08:30 - 18:00', style: TextStyle(fontSize: 12, color: AppTheme.textMedium))]),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)), child: const Row(children: [Text('Ver Ficha', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)), Icon(Icons.chevron_right, size: 16, color: AppTheme.primary)])),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTravelInfo(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 8, bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_walk, size: 14, color: AppTheme.textMedium),
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textMedium)),
          ],
        ),
      ),
    );
  }
}
