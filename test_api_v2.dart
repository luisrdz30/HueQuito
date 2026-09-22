import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final String url = 'https://routes.googleapis.com/directions/v2:computeRoutes';
  final Map<String, dynamic> body = {
    "origin": {
      "location": {
        "latLng": {"latitude": -0.288, "longitude": -78.473}
      }
    },
    "destination": {
      "location": {
        "latLng": {"latitude": -0.289, "longitude": -78.4735}
      }
    },
    "travelMode": "WALK",
    "languageCode": "es-419",
    "units": "METRIC"
  };

  final res = await http.post(
    Uri.parse(url),
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': 'AIzaSyDcxM0KCwFiiZBUj555w2K4xT8czajL8ms',
      'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.steps'
    },
    body: json.encode(body),
  );
  print(res.statusCode);
  print(res.body);
}
