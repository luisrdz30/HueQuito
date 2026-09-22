import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  String _selectedCategory = 'Todos';
  Map<String, dynamic>? _selectedHueca;
  
  final Map<String, LatLng> _locations = {
    'Quito': const LatLng(-0.215, -78.50),
    'Centro Histórico': const LatLng(-0.220164, -78.512327),
    'La Floresta': const LatLng(-0.2078, -78.4813),
    'Conocoto': const LatLng(-0.2880, -78.4730),
  };
  String _selectedLocationName = 'Quito';

  // Mock data for Huecas
  final List<Map<String, dynamic>> _allHuecas = [
    {
      'id': '1', 
      'name': 'Hornado San Francisco', 
      'category': 'Hornados & Fritadas', 
      'lat': -0.220164, 
      'lng': -78.512327, 
      'rating': 4.8, 
      'reviews': 124,
      'img': 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=150&q=80',
      'address': 'Sucre y García Moreno',
    },
    {
      'id': '2', 
      'name': 'Ponches Don Michi', 
      'category': 'Cafeterías & Dulces', 
      'lat': -0.2215, 
      'lng': -78.5135, 
      'rating': 4.5, 
      'reviews': 89,
      'img': 'https://images.unsplash.com/photo-1551024601-bec78aea704b?auto=format&fit=crop&w=150&q=80',
      'address': 'Plaza Grande',
    },
    {
      'id': '3', 
      'name': 'Café Modelo', 
      'category': 'Cafeterías & Dulces', 
      'lat': -0.2220, 
      'lng': -78.5140, 
      'rating': 4.7, 
      'reviews': 230,
      'img': 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=150&q=80',
      'address': 'Sucre y Venezuela',
    },
    {
      'id': '4', 
      'name': 'Hornado Conocoto', 
      'category': 'Hornados & Fritadas', 
      'lat': -0.2880, 
      'lng': -78.4730, 
      'rating': 4.6, 
      'reviews': 150,
      'img': 'https://images.unsplash.com/photo-1544025162-831e50527415?auto=format&fit=crop&w=150&q=80',
      'address': 'Parque de Conocoto',
    },
    {
      'id': '5', 
      'name': 'Empanadas del Parque', 
      'category': 'Empanadas & Tradición', 
      'lat': -0.2885, 
      'lng': -78.4725, 
      'rating': 4.4, 
      'reviews': 65,
      'img': 'https://images.unsplash.com/photo-1541592102775-7b3b754988f0?auto=format&fit=crop&w=150&q=80',
      'address': 'Conocoto Centro',
    },
  ];

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
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
        LatLng(position.latitude, position.longitude), 14.0,
      ));
    }
  }

  void _centerOnUser() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 15.0,
      ));
    }
  }

  Set<Marker> _getMarkers() {
    List<Map<String, dynamic>> filtered = _selectedCategory == 'Todos'
        ? _allHuecas
        : _allHuecas.where((h) => h['category'] == _selectedCategory).toList();

    return filtered.map((hueca) {
      return Marker(
        markerId: MarkerId(hueca['id']),
        position: LatLng(hueca['lat'], hueca['lng']),
        onTap: () {
          setState(() {
            _selectedHueca = hueca;
          });
          _mapController?.animateCamera(CameraUpdate.newLatLng(
            LatLng(hueca['lat'], hueca['lng'])
          ));
        },
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _selectedHueca?['id'] == hueca['id'] 
              ? BitmapDescriptor.hueOrange 
              : BitmapDescriptor.hueRed
        ),
      );
    }).toSet();
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
          _selectedHueca = null; // Close bottom sheet when filtering
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textMedium,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hue-Quito', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                Text('Explorar', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMedium)),
              ],
            )
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String result) {
              setState(() {
                _selectedLocationName = result;
              });
              if (_mapController != null) {
                _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
                  _locations[result]!, result == 'Quito' ? 12.0 : 15.0,
                ));
              }
            },
            itemBuilder: (BuildContext context) => _locations.keys.map((String key) {
              return PopupMenuItem<String>(
                value: key,
                child: Text(key),
              );
            }).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppTheme.primary, size: 16),
                  const SizedBox(width: 4),
                  Text(_selectedLocationName, style: const TextStyle(color: AppTheme.textDark, fontSize: 12, fontWeight: FontWeight.bold)),
                  const Icon(Icons.keyboard_arrow_down, color: AppTheme.textMedium, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          // The Map
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(-0.220164, -78.512327), // Centro Histórico as default
                zoom: 14.0,
              ),
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: _getMarkers(),
              onTap: (_) {
                setState(() {
                  _selectedHueca = null;
                });
              },
            ),
          ),
          
          // Top Controls (Search, filters)
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white.withValues(alpha: 0.8), Colors.transparent],
                ),
              ),
              child: Column(
                children: [
                  // Switcher
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(30)),
                    child: Row(
                      children: [
                        Expanded(child: GestureDetector(
                          onTap: () {
                            context.go('/rutas');
                          },
                          child: const Text('Lista de circuitos', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMedium, fontWeight: FontWeight.bold))
                        )),
                        Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.map, size: 16, color: AppTheme.primary), SizedBox(width: 4), Text('Mapa interactivo', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))]))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Search & Location toggle
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar hueca, plato o barrio...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _centerOnUser,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                          child: const Icon(Icons.my_location, color: AppTheme.primary),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Categories
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Todos'),
                        _buildFilterChip('Hornados & Fritadas'),
                        _buildFilterChip('Cafeterías & Dulces'),
                        _buildFilterChip('Picanterías & Caldos'),
                        _buildFilterChip('Marisquerías & Encebollados'),
                        _buildFilterChip('Empanadas & Tradición'),
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
              top: 180, left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppTheme.primary, size: 16),
                    const SizedBox(width: 4),
                    const Text('Mostrando', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('${_getMarkers().length} resultados', style: const TextStyle(color: AppTheme.tertiary, fontSize: 10)),
                  ],
                ),
              ),
            ),
          
          // Bottom Sheet for selected Hueca
          if (_selectedHueca != null)
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _selectedHueca!['img'], 
                            width: 80, height: 80, fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 80, height: 80, color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(_selectedHueca!['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  const Icon(Icons.bookmark_border, color: AppTheme.primary),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text('${_selectedHueca!['rating']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(' (${_selectedHueca!['reviews']} reseñas)', style: const TextStyle(color: AppTheme.textMedium, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, color: AppTheme.textMedium, size: 14),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(_selectedHueca!['address'], style: const TextStyle(color: AppTheme.textMedium, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              context.push('/hueca_detail');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Ver hueca', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
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
