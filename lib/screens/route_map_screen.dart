import 'package:flutter/material.dart';
import 'package:hue_quito/theme/map_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hue_quito/theme/map_style.dart';
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

  final LatLng _quitoCenter = LatLng(-0.2186, -78.5097); // Basilica as center

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
          markerId: MarkerId('user'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: InfoWindow(title: 'Tú'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        )
      );
    }
    
    for (var hueca in huecas) {
      // Filter by sector
      if (_selectedSector != 'Todos' && _selectedSector != 'All') {
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
    if (_selectedSector == 'Todos' || _selectedSector == 'All') {
      _selectedSector = lang == 'es' ? 'Todos' : 'All';
    }
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    return Scaffold(
      body: Stack(
        children: [
          // The Map
          huecasAsync.when(
            data: (huecas) {
              return GoogleMap(style: Theme.of(context).brightness == Brightness.dark ? darkMapStyle : null, 
                onMapCreated: (c) => _mapController = c,
                initialCameraPosition: CameraPosition(target: _quitoCenter, zoom: 14.0),
                markers: _buildMarkers(huecas),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onTap: (_) => setState(() => _selectedHueca = null),
              );
            },
            loading: () => Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text(lang == 'es' ? 'Error al cargar mapa' : 'Error loading map')),
          ),
          
          // Top Overlays
          Positioned(
            top: 16, left: 16, right: 16,
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: lang == 'es' ? 'Buscar hueca, plato o barrio...' : 'Search place, dish, area...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      suffixIcon: GestureDetector(
                        onTap: () {
                          if (_currentPosition != null && _mapController != null) {
                            _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(_currentPosition!.latitude, _currentPosition!.longitude)));
                          }
                        },
                        child: Icon(Icons.my_location, color: AppTheme.primary)
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                
                // Sector Filter Dropdown replacing chips
                huecasAsync.when(
                  data: (huecasList) {
                    final sectors = ['Todos', ...huecasList.map((h) => h.sector).toSet().toList()..sort()];
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSector,
                            icon: Icon(Icons.keyboard_arrow_down, size: 16, color: Theme.of(context).colorScheme.onSurface),
                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
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
                  loading: () => SizedBox.shrink(),
                  error: (_,__) => SizedBox.shrink(),
                ),
              ],
            ),
          ),
          
          // Badge indicator
          Positioned(
            top: 140, left: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: AppTheme.primary, size: 14),
                  SizedBox(width: 4),
                  Text((_selectedSector == 'Todos' || _selectedSector == 'All') ? (lang == 'es' ? 'Mostrando todo' : 'Showing all') : _selectedSector, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  SizedBox(width: 8),
                  Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                  SizedBox(width: 4),
                  huecasAsync.when(
                    data: (h) {
                      final count = _buildMarkers(h).length - (_currentPosition != null ? 1 : 0);
                      return Text('$count ${lang == 'es' ? 'huecas' : 'spots'}', style: TextStyle(fontSize: 10, color: Colors.grey));
                    },
                    loading: () => Text('...', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    error: (e,s) => Text(lang == 'es' ? '0 huecas' : '0 spots', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: Offset(0, 10))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle for swipe down indicator
                    Container(width: 40, height: 4, margin: EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300]), borderRadius: BorderRadius.circular(2))),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.network(_selectedHueca!.images.isNotEmpty ? _selectedHueca!.images.first : 'https://via.placeholder.com/60', width: 60, height: 60, fit: BoxFit.cover),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                  SizedBox(width: 4),
                                  Text(lang == 'es' ? 'Abierto' : 'Open', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                                  Spacer(),
                                  Icon(Icons.star, color: Colors.orange, size: 14),
                                  SizedBox(width: 2),
                                  Text(_selectedHueca!.rating.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(_selectedHueca!.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(_selectedHueca!.sector, style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
                            ],
                          ),
                        )
                      ],
                    ),
                    SizedBox(height: 16),
                    
                    // Info Row
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[100]), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Icon(Icons.restaurant_menu, size: 14, color: AppTheme.primary),
                          SizedBox(width: 6),
                          Expanded(
                            child: RichText(
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface),
                                children: [
                                  TextSpan(text: 'Plato insignia: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: _selectedHueca!.mainDish['name'][lang] ?? _selectedHueca!.mainDish['name']['es']),
                                ]
                              )
                            )
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary, 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: EdgeInsets.symmetric(vertical: 0) // Reduce padding
                            ),
                            onPressed: () => context.push('/navigation', extra: _selectedHueca),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.directions, size: 14),
                                SizedBox(width: 4),
                                Text(lang == 'es' ? 'Cómo llegar' : 'Directions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          flex: 4,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[100]), 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: EdgeInsets.symmetric(vertical: 0)
                            ),
                            onPressed: () => context.push('/hueca_detail', extra: _selectedHueca),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(lang == 'es' ? 'Ver Hueca' : 'View Spot', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontSize: 11)),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios, size: 10, color: Theme.of(context).colorScheme.onSurface),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 6),
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[100]), shape: BoxShape.circle),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              (user?.favoriteHuecas.contains(_selectedHueca!.id) ?? false) ? Icons.favorite : Icons.favorite_border, 
                              color: (user?.favoriteHuecas.contains(_selectedHueca!.id) ?? false) ? Colors.red : Theme.of(context).colorScheme.onSurface, 
                              size: 18
                            ),
                            onPressed: () async {
                              if (user == null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang == 'es' ? 'Inicia sesión para guardar favoritos' : 'Log in to save favorites')));
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
