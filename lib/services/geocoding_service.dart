import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

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
  static String? detectSector({
    required Map<String, dynamic> addressComponents,
    required double lat,
    required double lng,
  }) {
    final searchPool = [
      addressComponents['neighbourhood'],
      addressComponents['suburb'],
      addressComponents['quarter'],
      addressComponents['city_district'],
      addressComponents['town'],
      addressComponents['village'],
      addressComponents['city'],
    ].where((e) => e != null).join(' ').toLowerCase();

    // Specific matches based on Quito zones
    if (searchPool.contains('cumbaya') || searchPool.contains('cumbayá')) return 'Cumbayá';
    if (searchPool.contains('tumbaco')) return 'Tumbaco';
    if (searchPool.contains('chillos') ||
        searchPool.contains('sangolqui') ||
        searchPool.contains('sangolquí') ||
        searchPool.contains('san rafael') ||
        searchPool.contains('armenia')) {
      return 'Valle de los Chillos';
    }
    if (searchPool.contains('calderon') || searchPool.contains('calderón') || searchPool.contains('carapungo')) {
      return 'Calderón';
    }
    if (searchPool.contains('conocoto')) return 'Conocoto';
    if (searchPool.contains('floresta')) return 'Floresta';
    if (searchPool.contains('mariscal')) return 'La Mariscal';
    if (searchPool.contains('centro historico') ||
        searchPool.contains('centro histórico') ||
        searchPool.contains('san marcos') ||
        searchPool.contains('la ronda') ||
        searchPool.contains('san roque') ||
        searchPool.contains('san juan') ||
        searchPool.contains('san blas') ||
        searchPool.contains('panecillo')) {
      return 'Centro Histórico';
    }

    // South sectors
    if (searchPool.contains('villaflora') ||
        searchPool.contains('magdalena') ||
        searchPool.contains('solanda') ||
        searchPool.contains('quitumbe') ||
        searchPool.contains('chimbacalle') ||
        searchPool.contains('recreo') ||
        searchPool.contains('guamani') ||
        searchPool.contains('chillogallo')) {
      return 'Sur';
    }

    // North sectors
    if (searchPool.contains('carolina') ||
        searchPool.contains('iñaquito') ||
        searchPool.contains('inaquito') ||
        searchPool.contains('batan') ||
        searchPool.contains('batán') ||
        searchPool.contains('ponceano') ||
        searchPool.contains('cotocollao') ||
        searchPool.contains('carcelen') ||
        searchPool.contains('carcelén') ||
        searchPool.contains('rumipamba') ||
        searchPool.contains('kennedy')) {
      return 'Norte';
    }

    // Geographic bounding box heuristics for Quito
    if (lng > -78.46 && lat < -0.15 && lat > -0.25) return 'Cumbayá';
    if (lat < -0.23) return 'Sur';
    if (lat > -0.19) return 'Norte';
    if (lat <= -0.19 && lat >= -0.23) return 'Centro Histórico';

    return null;
  }
}
