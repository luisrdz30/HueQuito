import 'dart:convert';
import 'package:http/http.dart' as http;

class DirectionsService {
  // Las claves se configuran en tiempo de compilación mediante --dart-define=MAPS_API_KEY=...
  // para no exponer credenciales privadas en el repositorio.
  static const String _apiKey = String.fromEnvironment('MAPS_API_KEY', defaultValue: '');
  static String get apiKey => _apiKey;

  static Future<Map<String, dynamic>?> getDirections(
    double startLat,
    double startLng,
    double endLat,
    double endLng, {
    String mode = 'walking',
    List<Map<String, double>> waypoints = const [],
  }) async {
    final key = apiKey;
    if (key.isEmpty) {
      return null;
    }

    final String url = 'https://routes.googleapis.com/directions/v2:computeRoutes';

    final travelMode = mode == 'driving' ? 'DRIVE' : 'WALK';

    final Map<String, dynamic> body = {
      "origin": {
        "location": {
          "latLng": {"latitude": startLat, "longitude": startLng}
        }
      },
      "destination": {
        "location": {
          "latLng": {"latitude": endLat, "longitude": endLng}
        }
      },
      "travelMode": travelMode,
      "languageCode": "es-419",
      "units": "METRIC"
    };

    if (waypoints.isNotEmpty) {
      body['intermediates'] = waypoints.map((w) {
        return {
          "location": {
            "latLng": {"latitude": w['lat'], "longitude": w['lng']}
          }
        };
      }).toList();
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': key,
          'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.steps'
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          
          List<dynamic> allSteps = [];
          
          if (route['legs'] != null) {
            for (var leg in route['legs']) {
              if (leg['steps'] != null) {
                for (var s in leg['steps']) {
                  String instruction = s['navigationInstruction']?['instructions'] ?? '';
                  int distanceMeters = s['distanceMeters'] ?? 0;
                  allSteps.add({
                    'html_instructions': instruction,
                    'distance': {'text': '$distanceMeters m'}
                  });
                }
              }
            }
          }

          return {
            'distance': '${route['distanceMeters']} m',
            'duration': route['duration'],
            'polyline': route['polyline']['encodedPolyline'],
            'steps': allSteps,
          };
        }
      }
    } catch (_) {
      // Si la API falla o da timeout, retornamos null para activar el fallback geodésico
    }
    return null;
  }
}
