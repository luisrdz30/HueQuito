import 'package:flutter/material.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hue_quito/services/directions_service.dart';

class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({super.key});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  GoogleMapController? mapController;
  Position? _currentPosition;
  int _currentStopIndex = 0;
  Map<PolylineId, Polyline> _polylines = {};
  List<dynamic> _currentRouteSteps = [];

  final List<Map<String, dynamic>> _stops = [
    {'name': 'Hornado Conocoto', 'lat': -0.2880, 'lng': -78.4730},
    {'name': 'Empanadas del Parque', 'lat': -0.2885, 'lng': -78.4725},
    {'name': 'Helados de Conocoto', 'lat': -0.2890, 'lng': -78.4735},
  ];

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
      _fetchRoute();
      mapController?.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude), 16.0,
      ));
    }
  }

  Future<void> _fetchRoute() async {
    if (_currentPosition == null) return;
    final dest = _stops[_currentStopIndex];
    
    double distanceToDest = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, dest['lat'], dest['lng']);
    String mode = distanceToDest > 5000 ? 'driving' : 'walking'; // Auto en distancias largas (>5km)

    final dir = await DirectionsService.getDirections(
      _currentPosition!.latitude, 
      _currentPosition!.longitude, 
      dest['lat'], 
      dest['lng'],
      mode: mode
    );
    if (dir != null && dir['polyline'] != null && mounted) {
      List<LatLng> polylineCoordinates = _decodePolyline(dir['polyline']);
      setState(() {
        _polylines[const PolylineId('route')] = Polyline(
          polylineId: const PolylineId('route'),
          color: AppTheme.primary,
          points: polylineCoordinates,
          width: 5,
        );
        _currentRouteSteps = dir['steps'] ?? [];
      });
    } else if (mounted) {
      setState(() {
        _currentRouteSteps = [{'html_instructions': 'No se encontró una ruta disponible. Estás muy lejos o hubo un error.'}];
      });
    }
  }

  Set<Marker> _buildMarkers() {
    Set<Marker> markers = {};
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'Tu ubicación'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        )
      );
    }
    for (int i = 0; i < _stops.length; i++) {
      if (i >= _currentStopIndex) {
        markers.add(
          Marker(
            markerId: MarkerId('stop_$i'),
            position: LatLng(_stops[i]['lat'], _stops[i]['lng']),
            infoWindow: InfoWindow(title: _stops[i]['name']),
            icon: i == _currentStopIndex 
                ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange)
                : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          )
        );
      }
    }
    return markers;
  }

  void _markAsVisited() {
    if (_currentStopIndex < _stops.length - 1) {
      setState(() {
        _currentStopIndex++;
      });
      _fetchRoute();
      final nextStop = _stops[_currentStopIndex];
      mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(nextStop['lat'], nextStop['lng'])));
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¡Felicidades!'),
          content: const Text('Has completado el tour.'),
          actions: [
            TextButton(onPressed: () { ctx.pop(); context.pop(); }, child: const Text('Terminar'))
          ],
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTarget = _stops[_currentStopIndex];

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) => mapController = c,
            initialCameraPosition: CameraPosition(
              target: LatLng(currentTarget['lat'], currentTarget['lng']),
              zoom: 15.0,
            ),
            markers: _buildMarkers(),
            polylines: _polylines.values.toSet(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
                    onPressed: () => context.pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Siguiente parada (${_currentStopIndex + 1}/${_stops.length})', style: const TextStyle(color: AppTheme.textMedium, fontSize: 10)),
                        Text(currentTarget['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentRouteSteps.isNotEmpty)
                    SizedBox(
                      height: 80,
                      child: PageView.builder(
                        itemCount: _currentRouteSteps.length,
                        itemBuilder: (context, index) {
                          final step = _currentRouteSteps[index];
                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.directions_walk, color: AppTheme.primary, size: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(_stripHtml(step['html_instructions'] ?? ''), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    if (step['distance'] != null)
                                      Text(step['distance']['text'], style: const TextStyle(color: AppTheme.textMedium, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    )
                  else
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.directions_walk, color: AppTheme.primary, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Calculando ruta...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              Text('Hacia ${currentTarget['name']}', style: const TextStyle(color: AppTheme.textMedium, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _markAsVisited,
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                          child: const Text('¡Ya llegué!', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          
          Positioned(
            bottom: 180,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: AppTheme.primary),
              onPressed: () {
                if (_currentPosition != null) {
                  mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(_currentPosition!.latitude, _currentPosition!.longitude)));
                } else {
                  _determinePosition();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble()));
    }
    return points;
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ');
  }
}
