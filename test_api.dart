import 'package:http/http.dart' as http;

void main() async {
  final String url = 'https://maps.googleapis.com/maps/api/directions/json?origin=-0.288,-78.473&destination=-0.289,-78.4735&mode=walking&key=AIzaSyDcxM0KCwFiiZBUj555w2K4xT8czajL8ms';
  final res = await http.get(Uri.parse(url));
  print(res.statusCode);
  print(res.body);
}
