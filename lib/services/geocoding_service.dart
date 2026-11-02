import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:hue_quito/models/quito_zones.dart';

class LocationPickerResult {
  final LatLng location;
  final String address;
  final String? sector;

  LocationPickerResult({
    required this.location,
    required this.address,
    this.sector,
  });
}

class GeocodingService {
  static final Map<String, LocationPickerResult> _cache = {};

  /// Reverse geocodes coordinates to a human-readable street address and detects the Quito sector.
  static Future<LocationPickerResult> reverseGeocode(double lat, double lng) async {
    final cacheKey = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'HueQuitoApp/1.0 (ec.huequito.app)',
          'Accept-Language': 'es',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final addressMap = (data['address'] as Map<String, dynamic>?) ?? {};

        final road = addressMap['road'] ??
            addressMap['pedestrian'] ??
            addressMap['footway'] ??
            addressMap['path'];
        final houseNumber = addressMap['house_number'];
        final area = addressMap['neighbourhood'] ??
            addressMap['suburb'] ??
            addressMap['quarter'] ??
            addressMap['city_district'] ??
            addressMap['town'] ??
            addressMap['village'];

        String formattedAddress = '';
        if (road != null && road.toString().trim().isNotEmpty) {
          formattedAddress = road.toString().trim();
          if (houseNumber != null && houseNumber.toString().trim().isNotEmpty) {
            formattedAddress += ' ${houseNumber.toString().trim()}';
          }
          if (area != null &&
              area.toString().trim().isNotEmpty &&
              !formattedAddress.toLowerCase().contains(area.toString().toLowerCase())) {
            formattedAddress += ', ${area.toString().trim()}';
          }
        } else {
          final displayName = data['display_name']?.toString() ?? '';
          if (displayName.isNotEmpty) {
            final parts = displayName
                .split(',')
                .map((p) => p.trim())
                .where((p) =>
                    !p.toLowerCase().contains('pichincha') &&
                    !p.toLowerCase().contains('ecuador') &&
                    !RegExp(r'^\d{5,6}$').hasMatch(p))
                .take(3)
                .toList();
            formattedAddress = parts.isNotEmpty ? parts.join(', ') : displayName;
          }
        }

        if (formattedAddress.isEmpty) {
          formattedAddress = 'Quito, Pichincha';
        }

        final sector = detectSector(
          addressComponents: addressMap,
          lat: lat,
          lng: lng,
        );

        final result = LocationPickerResult(
          location: LatLng(lat, lng),
          address: formattedAddress,
          sector: sector,
        );

        _cache[cacheKey] = result;
        return result;
      }
    } catch (_) {
      // In case of network timeout or error, continue to fallback
    }

    final fallbackSector = detectSector(
      addressComponents: {},
      lat: lat,
      lng: lng,
    );
    final fallback = LocationPickerResult(
      location: LatLng(lat, lng),
      address: fallbackSector != null ? 'Sector $fallbackSector, Quito' : 'Quito, Pichincha',
      sector: fallbackSector,
    );
    return fallback;
  }

  /// Detects the matching Quito sector name from address components or coordinates.
  /// Siempre devuelve una de las 4 zonas fijas (ver quito_zones.dart).
  static String? detectSector({
    required Map<String, dynamic> addressComponents,
    required double lat,
    required double lng,
  }) {
    final searchPool = [
      addressComponents['address'],
      addressComponents['road'],
      addressComponents['neighbourhood'],
      addressComponents['suburb'],
      addressComponents['quarter'],
      addressComponents['city_district'],
      addressComponents['town'],
      addressComponents['village'],
      addressComponents['city'],
    ].where((e) => e != null).join(' ').toLowerCase();

    return normalizeQuitoZone(searchPool) ?? zoneFromCoordinates(lat, lng);
  }
}
