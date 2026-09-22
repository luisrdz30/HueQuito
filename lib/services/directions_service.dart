import 'dart:convert';
import 'package:http/http.dart' as http;

class DirectionsService {
  static const String _apiKey = 'AIzaSyDcxM0KCwFiiZBUj555w2K4xT8czajL8ms';

  static Future<Map<String, dynamic>?> getDirections(double startLat, double startLng, double endLat, double endLng, {String mode = 'walking'}) async {
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

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.steps'
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          List<dynamic> steps = leg['steps'].map((s) {
            String instruction = s['navigationInstruction']?['instructions'] ?? '';
            int distanceMeters = s['distanceMeters'] ?? 0;
            return {
              'html_instructions': instruction,
              'distance': {'text': '$distanceMeters m'}
            };
          }).toList();

          return {
            'distance': '${route['distanceMeters']} m',
            'duration': route['duration'],
            'polyline': route['polyline']['encodedPolyline'],
            'steps': steps,
          };
        } else {
          print("Routes API returned empty: ${response.body}");
        }
      } else {
        print("Routes API HTTP Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Error fetching routes: $e");
    }
    return null;
  }
}
