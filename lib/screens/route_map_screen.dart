import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';

class RouteMapScreen extends ConsumerStatefulWidget {
  const RouteMapScreen({super.key});

  @override
  ConsumerState<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends ConsumerState<RouteMapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Hueca? _selectedHueca;
  String _selectedFilter = 'Todos';

  final LatLng _quitoCenter = const LatLng(-0.2186, -78.5097); // Basilica as center

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return; 

    Position position = await Geolocator.getCurrentPosition();

    if (mounted) {
      setState(() {
        _currentPosition = position;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude), 15.0,
      ));
    }
  }

  Set<Marker> _buildMarkers(List<Hueca> huecas) {
    Set<Marker> markers = {};
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'Tú'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        )
      );
    }
    
    for (var hueca in huecas) {
      if (_selectedFilter != 'Todos') {
        if (!hueca.tags.any((t) => t.toLowerCase().contains(_selectedFilter.toLowerCase()))) continue;
      }
      
      bool isSelected = _selectedHueca != null && _selectedHueca!.id == hueca.id;
      
      markers.add(
        Marker(
          markerId: MarkerId(hueca.id),
          position: LatLng(hueca.location.latitude, hueca.location.longitude),
          infoWindow: InfoWindow(title: hueca.name),
          icon: isSelected 
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: () {
            setState(() { _selectedHueca = hueca; });
            _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(hueca.location.latitude - 0.002, hueca.location.longitude)));
          }
        )
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final huecasAsync = ref.watch(huecasProvider);
    final lang = ref.watch(settingsProvider).language;

    return Scaffold(
      body: Stack(
        children: [
          // The Map
          huecasAsync.when(
            data: (huecas) {
              return GoogleMap(
                onMapCreated: (c) => _mapController = c,
                initialCameraPosition: CameraPosition(target: _quitoCenter, zoom: 14.0),
                markers: _buildMarkers(huecas),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onTap: (_) => setState(() => _selectedHueca = null),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => const Center(child: Text('Error al cargar mapa')),
          ),
          
          // Top Overlays
          Positioned(
            top: 16, left: 16, right: 16,
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: lang == 'es' ? 'Buscar hueca, plato o barrio...' : 'Search place, dish, area...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: const Icon(Icons.my_location, color: AppTheme.primary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Todos', isSelected: _selectedFilter == 'Todos'),
                      _buildFilterChip('Hornados', isSelected: _selectedFilter == 'Hornados'),
                      _buildFilterChip('Cafeterías', isSelected: _selectedFilter == 'Cafeterías'),
                      _buildFilterChip('Sopas', isSelected: _selectedFilter == 'Sopas'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Badge indicator
          Positioned(
            top: 140, left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppTheme.primary, size: 14),
                  const SizedBox(width: 4),
                  const Text('Centro Histórico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(width: 8),
                  Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  huecasAsync.when(
                    data: (h) => Text('${h.length} huecas', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    loading: () => const Text('...', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    error: (e,s) => const Text('0 huecas', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                ],
              ),
            ),
          ),
          
          // Floating Bottom Card (Selected Hueca)
          if (_selectedHueca != null)
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle for swipe down indicator
                    Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.network(_selectedHueca!.images.isNotEmpty ? _selectedHueca!.images.first : 'https://via.placeholder.com/60', width: 60, height: 60, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  const Text('Abierto', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                                  const SizedBox(width: 4),
                                  const Text('17:00', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                  const Spacer(),
                                  const Icon(Icons.star, color: Colors.orange, size: 14),
                                  const SizedBox(width: 2),
                                  Text(_selectedHueca!.rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(_selectedHueca!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(_selectedHueca!.mainDish['name'][lang] ?? _selectedHueca!.mainDish['name']['es'], style: const TextStyle(color: AppTheme.textMedium, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Info Row
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Expanded(child: Text(_selectedHueca!.sector, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Container(width: 1, height: 12, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 8)),
                          const Icon(Icons.directions_walk, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          const Text('5 min (300m)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Gamification Row
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(color: AppTheme.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Sello QR disponible en el puesto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                          Text('+50 PTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                            onPressed: () {},
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.directions, size: 16),
                                SizedBox(width: 4),
                                Text('Cómo llegar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(backgroundColor: Colors.grey[100], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                            onPressed: () => context.push('/hueca_detail', extra: _selectedHueca),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Ver Ficha', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark, fontSize: 12)),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.textDark),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                          child: IconButton(
                            icon: const Icon(Icons.bookmark_border, color: AppTheme.textDark, size: 20),
                            onPressed: () {},
                          ),
                        )
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

  Widget _buildFilterChip(String text, {required bool isSelected}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = text),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primary : Colors.transparent),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
        ),
        child: Row(
          children: [
            if (text == 'Hornados' || text == 'Cafeterías') ...[
              Icon(text == 'Hornados' ? Icons.kebab_dining : Icons.coffee, size: 14, color: AppTheme.primary),
              const SizedBox(width: 4),
            ],
            Text(text, style: TextStyle(
              color: AppTheme.textDark,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12
            )),
          ],
        ),
      ),
    );
  }
}
