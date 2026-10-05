import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/services/directions_service.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  final Hueca targetHueca;
  const NavigationScreen({super.key, required this.targetHueca});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Map<PolylineId, Polyline> _polylines = {};
  List<dynamic> _steps = [];
  bool _isLoading = true;
  String _travelMode = 'walking'; // 'walking' or 'driving'

  @override
  void initState() {
    super.initState();
    _initNavigation();
  }

  Future<void> _initNavigation() async {
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
      setState(() => _currentPosition = position);
      await _fetchRoute();
    }
  }

  Future<void> _fetchRoute() async {
    if (_currentPosition == null) return;
    
    setState(() => _isLoading = true);

    final dir = await DirectionsService.getDirections(
      _currentPosition!.latitude, 
      _currentPosition!.longitude, 
      widget.targetHueca.location.latitude, 
      widget.targetHueca.location.longitude,
      mode: _travelMode
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
        _steps = dir['steps'] ?? [];
        _isLoading = false;
      });

      // Fit bounds
      if (polylineCoordinates.isNotEmpty && _mapController != null) {
        LatLngBounds bounds = _boundsFromLatLngList(polylineCoordinates);
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
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

      poly.add(LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble()));
    }
    return poly;
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(northeast: LatLng(x1!, y1!), southwest: LatLng(x0!, y0!));
  }

  void _openGoogleMaps() async {
    final lat = widget.targetHueca.location.latitude;
    final lng = widget.targetHueca.location.longitude;
    final mapMode = _travelMode == 'walking' ? 'w' : 'd';
    final url = Uri.parse('google.navigation:q=$lat,$lng&mode=$mapMode'); 
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      final webUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=$_travelMode');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    }
  }

  String _stripHtml(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '');
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    Set<Marker> markers = {
      Marker(
        markerId: MarkerId(widget.targetHueca.id),
        position: LatLng(widget.targetHueca.location.latitude, widget.targetHueca.location.longitude),
        infoWindow: InfoWindow(title: widget.targetHueca.name),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      )
    };
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        )
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(lang == 'es' ? 'A ${widget.targetHueca.name}' : 'To ${widget.targetHueca.name}', style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.map, color: AppTheme.primary),
            onPressed: _openGoogleMaps,
            tooltip: 'Abrir en Google Maps',
          )
        ],
      ),
      body: Column(
        children: [
          // Travel Mode Toggle
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_travelMode != 'walking') {
                        setState(() => _travelMode = 'walking');
                        _fetchRoute();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _travelMode == 'walking' ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _travelMode == 'walking' ? AppTheme.primary : Colors.grey[300]!)
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_walk, color: _travelMode == 'walking' ? AppTheme.primary : Colors.grey),
                          const SizedBox(width: 8),
                          Text(lang == 'es' ? 'A pie' : 'Walking', style: TextStyle(
                            color: _travelMode == 'walking' ? AppTheme.primary : Colors.grey,
                            fontWeight: FontWeight.bold
                          ))
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_travelMode != 'driving') {
                        setState(() => _travelMode = 'driving');
                        _fetchRoute();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _travelMode == 'driving' ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _travelMode == 'driving' ? AppTheme.primary : Colors.grey[300]!)
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car, color: _travelMode == 'driving' ? AppTheme.primary : Colors.grey),
                          const SizedBox(width: 8),
                          Text(lang == 'es' ? 'En carro' : 'Driving', style: TextStyle(
                            color: _travelMode == 'driving' ? AppTheme.primary : Colors.grey,
                            fontWeight: FontWeight.bold
                          ))
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: (c) => _mapController = c,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(widget.targetHueca.location.latitude, widget.targetHueca.location.longitude), 
                    zoom: 14.0
                  ),
                  markers: markers,
                  polylines: _polylines.values.toSet(),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
                if (_isLoading)
                  Center(child: CircularProgressIndicator()),
              ]
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(lang == 'es' ? 'Indicaciones' : 'Directions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  Expanded(
                    child: _steps.isEmpty 
                      ? Center(child: Text(lang == 'es' ? 'Calculando ruta...' : 'Calculating route...'))
                      : ListView.builder(
                          itemCount: _steps.length,
                          itemBuilder: (context, index) {
                            final step = _steps[index];
                            return ListTile(
                              leading: Icon(
                                _travelMode == 'walking' ? Icons.directions_walk : Icons.directions_car, 
                                color: AppTheme.primary
                              ),
                              title: Text(_stripHtml(step['html_instructions'] ?? '')),
                              subtitle: Text(step['distance']?['text'] ?? ''),
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openGoogleMaps,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.directions),
        label: Text(lang == 'es' ? 'Ir con Google Maps' : 'Open in Google Maps', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
