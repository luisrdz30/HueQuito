import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DirectionsService {
  // Las claves se configuran en tiempo de compilación mediante --dart-define=MAPS_API_KEY=...
  // para no exponer credenciales privadas en el repositorio.
  static const String _apiKey = String.fromEnvironment('MAPS_API_KEY', defaultValue: '');
  @visibleForTesting
  static String? debugApiKey;
  static String get apiKey => debugApiKey ?? _apiKey;

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

    // Un corte de red o un error temporal de Google no debe dejar al usuario con líneas rectas
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': key,
            'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.steps'
          },
          body: json.encode(body),
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          return _parseRoute(json.decode(utf8.decode(response.bodyBytes)));
        }
        debugPrint('Routes API respondió ${response.statusCode} (intento $attempt): ${response.body}');
        final isTemporary = response.statusCode == 429 || response.statusCode >= 500;
        if (!isTemporary) return null;
      } catch (e) {
        debugPrint('Routes API falló (intento $attempt): $e');
      }
    }
    return null;
  }

  static Map<String, dynamic>? _parseRoute(dynamic data) {
    if (data['routes'] == null || (data['routes'] as List).isEmpty) {
      debugPrint('Routes API no encontró una ruta para estas paradas');
      return null;
    }
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
