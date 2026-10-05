import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hue_quito/theme/theme.dart';
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
  Map<PolylineId, Polyline> _polylines = {};
  List<dynamic> _steps = [];
  bool _isLoading = true;

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
    final dir = await DirectionsService.getDirections(
      _currentPosition!.latitude, 
      _currentPosition!.longitude, 
      widget.targetHueca.location.latitude, 
      widget.targetHueca.location.longitude,
      mode: 'walking' // Or driving based on distance, but let's default to walking for tours
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
    final url = Uri.parse('google.navigation:q=$lat,$lng&mode=w'); // mode=w is walking
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      final webUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking');
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
        title: Text('Cómo llegar a ${widget.targetHueca.name}', style: const TextStyle(fontSize: 16)),
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
                  const Center(child: CircularProgressIndicator()),
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
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Indicaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  Expanded(
                    child: _steps.isEmpty 
                      ? const Center(child: Text('Calculando ruta...'))
                      : ListView.builder(
                          itemCount: _steps.length,
                          itemBuilder: (context, index) {
                            final step = _steps[index];
                            return ListTile(
                              leading: const Icon(Icons.turn_right, color: AppTheme.primary),
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
        label: const Text('Ir con Google Maps', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
