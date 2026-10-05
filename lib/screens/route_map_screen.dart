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
  String _selectedSector = 'Todos';
  String _searchQuery = '';

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
      // Filter by sector
      if (_selectedSector != 'Todos') {
        if (hueca.sector != _selectedSector) continue;
      }
      
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = hueca.name.toLowerCase().contains(q);
        final matchDish = (hueca.mainDish['name']['es'] ?? '').toLowerCase().contains(q);
        final matchSector = hueca.sector.toLowerCase().contains(q);
        if (!matchName && !matchDish && !matchSector) continue;
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
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

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
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: lang == 'es' ? 'Buscar hueca, plato o barrio...' : 'Search place, dish, area...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: GestureDetector(
                        onTap: () {
                          if (_currentPosition != null && _mapController != null) {
                            _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(_currentPosition!.latitude, _currentPosition!.longitude)));
                          }
                        },
                        child: const Icon(Icons.my_location, color: AppTheme.primary)
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Sector Filter Dropdown replacing chips
                huecasAsync.when(
                  data: (huecasList) {
                    final sectors = ['Todos']..addAll(huecasList.map((h) => h.sector).toSet().toList()..sort());
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSector,
                            icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: AppTheme.textDark),
                            style: const TextStyle(fontSize: 13, color: AppTheme.textDark, fontWeight: FontWeight.bold),
                            onChanged: (String? newValue) {
                              if (newValue != null) setState(() => _selectedSector = newValue);
                            },
                            items: sectors.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_,__) => const SizedBox.shrink(),
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
                  Text(_selectedSector == 'Todos' ? 'Mostrando todo' : _selectedSector, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(width: 8),
                  Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  huecasAsync.when(
                    data: (h) {
                      final count = _buildMarkers(h).length - (_currentPosition != null ? 1 : 0);
                      return Text('$count huecas', style: const TextStyle(fontSize: 10, color: Colors.grey));
                    },
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
                                  const Spacer(),
                                  const Icon(Icons.star, color: Colors.orange, size: 14),
                                  const SizedBox(width: 2),
                                  Text(_selectedHueca!.rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(_selectedHueca!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(_selectedHueca!.sector, style: const TextStyle(color: AppTheme.textMedium, fontSize: 12)),
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
                          const Icon(Icons.restaurant_menu, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: RichText(
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: const TextStyle(fontSize: 11, color: AppTheme.textDark),
                                children: [
                                  const TextSpan(text: 'Plato insignia: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: _selectedHueca!.mainDish['name'][lang] ?? _selectedHueca!.mainDish['name']['es']),
                                ]
                              )
                            )
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary, 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(vertical: 0) // Reduce padding
                            ),
                            onPressed: () => context.push('/navigation', extra: _selectedHueca),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.directions, size: 14),
                                SizedBox(width: 4),
                                Text('Cómo llegar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 4,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey[100], 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(vertical: 0)
                            ),
                            onPressed: () => context.push('/hueca_detail', extra: _selectedHueca),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Ver Ficha', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark, fontSize: 11)),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.textDark),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              (user?.favoriteHuecas.contains(_selectedHueca!.id) ?? false) ? Icons.favorite : Icons.favorite_border, 
                              color: (user?.favoriteHuecas.contains(_selectedHueca!.id) ?? false) ? Colors.red : AppTheme.textDark, 
                              size: 18
                            ),
                            onPressed: () async {
                              if (user == null) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inicia sesión para guardar favoritos')));
                                return;
                              }
                              await ref.read(userRepositoryProvider).toggleFavorite(_selectedHueca!.id);
                              ref.invalidate(currentUserProvider);
                            },
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
}
