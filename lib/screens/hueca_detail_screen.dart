import 'package:flutter/material.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class HuecaDetailScreen extends StatefulWidget {
  const HuecaDetailScreen({super.key});

  @override
  State<HuecaDetailScreen> createState() => _HuecaDetailScreenState();
}

class _HuecaDetailScreenState extends State<HuecaDetailScreen> {
  int _selectedTabIndex = 1;
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        toolbarHeight: 70,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
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
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isFavorite ? 'Añadido a favoritos' : 'Eliminado de favoritos'), duration: const Duration(seconds: 1)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            color: AppTheme.textMedium,
            onPressed: () {
              Share.share('¡Ven acompáñame a visitar Hornado San Francisco conmigo en Hue-Quito! 😋🥘\n\nEstá ubicado en Mercado San Francisco, Local 14, Centro Histórico de Quito. Mira dónde queda aquí: https://maps.google.com/?q=-0.220164,-78.512327');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Carousel Placeholder
            SizedBox(
              height: 250,
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      return Image.network(
                        'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=800&q=80',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[300], child: const Icon(Icons.restaurant, size: 50, color: Colors.grey)),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                      child: const Text('1 / 5 FOTOS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
            
            // Header Info
            Container(
              transform: Matrix4.translationValues(0, -20, 0),
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hornado San Francisco', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('De Doña Rosa', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: const Row(children: [Icon(Icons.star, color: AppTheme.primary, size: 16), SizedBox(width: 4), Text('4.8', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))]),
                      ),
                      const SizedBox(width: 8),
                      const Text('(124 reseñas)', style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [Icon(Icons.near_me, color: AppTheme.primary, size: 16), SizedBox(width: 4), Text('Mercado San Francisco', style: TextStyle(fontWeight: FontWeight.bold))]),
                        Text('08:00 - 16:30', style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => _openMapsSheet(context),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.directions), SizedBox(width: 8), Text('Cómo llegar')]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final Uri launchUri = Uri(scheme: 'tel', path: '0991234567');
                            await launchUrl(launchUri);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: AppTheme.textDark, elevation: 0),
                          child: const Column(children: [Icon(Icons.call, size: 20), Text('Llamar', style: TextStyle(fontSize: 10))]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Share.share('¡Ven acompáñame a visitar Hornado San Francisco conmigo en Hue-Quito! 😋🥘\n\nEstá ubicado en Mercado San Francisco, Local 14, Centro Histórico de Quito. Mira dónde queda aquí: https://maps.google.com/?q=-0.220164,-78.512327');
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: AppTheme.textDark, elevation: 0),
                          child: const Column(children: [Icon(Icons.share, size: 20), Text('Enviar', style: TextStyle(fontSize: 10))]),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            
            // Tabs Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildTab('Sobre la Hueca', 0),
                  _buildTab('Menú Tradicional', 1),
                  _buildTab('Ubicación & Horario', 2),
                  _buildTab('Reseñas (184)', 3),
                ],
              ),
            ),
            
            // Content Sections
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSelectedTabContent(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(children: [Icon(Icons.info, color: AppTheme.primary), SizedBox(width: 8), Text('Sobre la Hueca', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
              SizedBox(height: 16),
              Text(
                'El Hornado San Francisco es un ícono gastronómico de Quito. Doña Rosa lleva más de 40 años preparando el tradicional hornado al horno de leña, con cuero reventado, llapingachos, mote y su inconfundible agrio.',
                style: TextStyle(color: AppTheme.textMedium, height: 1.5),
              ),
            ],
          ),
        );
      case 1:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [Icon(Icons.restaurant_menu, color: AppTheme.primary), SizedBox(width: 8), Text('Menú', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
              const SizedBox(height: 16),
              _buildMenuItem('Plato de Hornado Especial', 'Generosa porción de hornado tierno, cuero crocante de campana, 2 tortillas...', '\$4.50', 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=150&q=80'),
              const Divider(),
              _buildMenuItem('Medio Plato Tradicional', 'Carne suave de hornado, 1 llapingacho dorado, mote abundante...', '\$3.00', 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&w=150&q=80'),
            ],
          ),
        );
      case 2:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [Icon(Icons.location_on, color: AppTheme.primary), SizedBox(width: 8), Text('Ubicación & Horarios', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.map, color: AppTheme.textMedium),
                  SizedBox(width: 8),
                  Expanded(child: Text('Mercado San Francisco, Local 14, Centro Histórico de Quito', style: TextStyle(color: AppTheme.textDark))),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 150,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(-0.220164, -78.512327),
                      zoom: 15.0,
                    ),
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    markers: {
                      const Marker(
                        markerId: MarkerId('hueca'),
                        position: LatLng(-0.220164, -78.512327),
                      )
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.schedule, color: AppTheme.textMedium),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lunes - Viernes: 08:00 - 16:30', style: TextStyle(color: AppTheme.textDark)),
                        Text('Sábados - Domingos: 08:00 - 18:00', style: TextStyle(color: AppTheme.textDark)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      case 3:
      default:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Reseñas Quiteñas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text('Calificación verificada por comensales', style: TextStyle(fontSize: 12, color: AppTheme.textMedium))])),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: AppTheme.textDark, elevation: 0), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.edit, size: 16, color: AppTheme.primary), SizedBox(width: 4), Text('Opinar')])),
                ],
              ),
              const SizedBox(height: 16),
              _buildReviewItem('Mateo Cárdenas', '¡El mejor hornado de todo el Centro Histórico! El cuero suena crocante como una galleta...'),
            ],
          ),
        );
    }
  }

  void _openMapsSheet(BuildContext context) async {
    final availableMaps = await MapLauncher.installedMaps;
    if (!context.mounted) return;
    if (availableMaps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay mapas instalados')));
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Abrir ubicación con', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                Wrap(
                  children: <Widget>[
                    for (var map in availableMaps)
                      ListTile(
                        onTap: () => map.showMarker(
                          coords: Coords(-0.220164, -78.512327),
                          title: "Hornado San Francisco",
                          description: "Mercado San Francisco",
                        ),
                        title: Text(map.mapName),
                        leading: Icon(Icons.map),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTab(String title, int index) {
    bool isActive = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isActive ? AppTheme.tertiary : Colors.grey[200], borderRadius: BorderRadius.circular(20)),
        child: Text(title, style: TextStyle(color: isActive ? Colors.white : AppTheme.textMedium, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMenuItem(String title, String desc, String price, String imageUrl) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(color: AppTheme.textMedium, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(price, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: 60, height: 60, color: Colors.grey[300], child: const Icon(Icons.fastfood, color: Colors.grey)))),
      ],
    );
  }

  Widget _buildReviewItem(String name, String review) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 16, child: Text('M')),
              const SizedBox(width: 8),
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
              const Row(children: [Icon(Icons.star, color: AppTheme.primary, size: 12), Icon(Icons.star, color: AppTheme.primary, size: 12), Icon(Icons.star, color: AppTheme.primary, size: 12)]),
            ],
          ),
          const SizedBox(height: 8),
          Text(review, style: const TextStyle(color: AppTheme.textMedium, fontSize: 12)),
        ],
      ),
    );
  }
}
