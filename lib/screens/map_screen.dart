import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final LatLng _quitoCenter = LatLng(-0.2186, -78.5097); // Basilica as center
  
  Hueca? _selectedHueca;
  String _selectedCategory = 'Todos';

  void _centerOnUser() {
    _mapController.move(_quitoCenter, 15.0);
  }

  List<Marker> _getMarkers(List<Hueca> huecas) {
    List<Hueca> filtered = _selectedCategory == 'Todos' 
        ? huecas 
        : huecas.where((h) => h.tags.contains(_selectedCategory)).toList();
        
    return filtered.map((hueca) {
      bool isSelected = _selectedHueca != null && _selectedHueca!.id == hueca.id;
      return Marker(
        point: LatLng(hueca.location.latitude, hueca.location.longitude),
        width: isSelected ? 50 : 40,
        height: isSelected ? 50 : 40,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedHueca = hueca;
            });
            // Slightly offset center to make room for bottom sheet
            _mapController.move(LatLng(hueca.location.latitude - 0.002, hueca.location.longitude), 16.0);
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.secondary : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary, width: isSelected ? 3 : 2),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: isSelected ? 8 : 4, offset: Offset(0, 4))
              ]
            ),
            child: Center(
              child: Text(
                hueca.mainDish['emoji'] ?? '🍲',
                style: TextStyle(fontSize: isSelected ? 24 : 18),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = _selectedCategory == label;
    return Padding(
      padding: EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            _selectedCategory = selected ? label : 'Todos';
            _selectedHueca = null;
          });
        },
        selectedColor: AppTheme.primary.withOpacity(0.2),
        checkmarkColor: AppTheme.primary,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        side: BorderSide(color: isSelected ? AppTheme.primary : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300])!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final huecasAsync = ref.watch(huecasProvider);

    return Scaffold(
      body: huecasAsync.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (huecas) {
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _quitoCenter,
                  initialZoom: 14.0,
                  onTap: (tapPosition, point) {
                    setState(() {
                      _selectedHueca = null;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: Theme.of(context).brightness == Brightness.dark ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png' : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'ec.huequito.app',
                    errorImage: NetworkImage('https://tile.openstreetmap.org/0/0/0.png'),
                  ),
                  MarkerLayer(
                    markers: _getMarkers(huecas),
                  ),
                ],
              ),
              
              // Top Overlay (Search & Filters)
              Positioned(
                top: 48, left: 16, right: 16,
                child: SafeArea(
                  child: Column(
                    children: [
                      // Search & Location toggle
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Buscar hueca, plato o barrio...',
                                prefixIcon: Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                                contentPadding: EdgeInsets.symmetric(vertical: 0),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          GestureDetector(
                            onTap: _centerOnUser,
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Theme.of(context).cardColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                              child: Icon(Icons.my_location, color: AppTheme.primary),
                            ),
                          )
                        ],
                      ),
                      SizedBox(height: 12),
                      // Categories
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('Todos'),
                            _buildFilterChip('Tradicional'),
                            _buildFilterChip('Mariscos'),
                            _buildFilterChip('Cerdo'),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              
              // Badges on map
              if (_selectedHueca == null)
                Positioned(
                  top: 150, left: 16,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor.withOpacity(0.9), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: AppTheme.primary, size: 16),
                        SizedBox(width: 4),
                        Text('Mostrando', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        SizedBox(width: 8),
                        Text('${_getMarkers(huecas).length} resultados', style: TextStyle(color: AppTheme.tertiary, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              
              // Bottom Sheet for selected Hueca
              if (_selectedHueca != null)
                Positioned(
                  bottom: 16, left: 16, right: 16,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300]), borderRadius: BorderRadius.circular(2)))),
                        SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _selectedHueca!.images.isNotEmpty ? _selectedHueca!.images[0] : 'https://via.placeholder.com/150', 
                                width: 80, height: 80, fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 80, height: 80, color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]),
                                  child: Icon(Icons.image_not_supported, color: Colors.grey),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(_selectedHueca!.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      Icon(Icons.bookmark_border, color: AppTheme.primary),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.star, color: Colors.amber, size: 16),
                                      SizedBox(width: 4),
                                      Text('${_selectedHueca!.rating}', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text(' (${_selectedHueca!.reviewCount} reseñas)', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), fontSize: 12)),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), size: 14),
                                      SizedBox(width: 4),
                                      Expanded(child: Text(_selectedHueca!.address, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  context.push('/hueca_detail'); // We can pass the id later
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Ver hueca', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                )
            ],
          );
        }
      ),
    );
  }
}
