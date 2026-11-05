import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hue_quito/services/directions_service.dart';

void main() {
  final okBody = json.encode({
    'routes': [
      {
        'distanceMeters': 1200,
        'duration': '900s',
        'polyline': {'encodedPolyline': 'abc'},
        'legs': [
          {
            'steps': [
              {
                'distanceMeters': 58,
                'navigationInstruction': {'instructions': 'Dirígete al sur'},
              },
            ],
          },
        ],
      },
    ],
  });

  Future<Map<String, dynamic>?> run(MockClient client) => http.runWithClient(
        () => DirectionsService.getDirections(-0.28, -78.48, -0.22, -78.5),
        () => client,
      );

  setUp(() => DirectionsService.debugApiKey = 'test-key');
  tearDown(() => DirectionsService.debugApiKey = null);

  test('devuelve la ruta real con sus indicaciones', () async {
    final dir = await run(MockClient((_) async => http.Response.bytes(utf8.encode(okBody), 200)));
    expect(dir?['polyline'], 'abc');
    expect((dir?['steps'] as List).single['html_instructions'], 'Dirígete al sur');
  });

  test('reintenta una vez si Google falla temporalmente', () async {
    var calls = 0;
    final dir = await run(MockClient((_) async {
      calls++;
      return calls == 1 ? http.Response('error', 503) : http.Response.bytes(utf8.encode(okBody), 200);
    }));
    expect(calls, 2);
    expect(dir?['polyline'], 'abc');
  });

  test('reintenta una vez si se cae la conexión', () async {
    var calls = 0;
    final dir = await run(MockClient((_) async {
      calls++;
      if (calls == 1) throw http.ClientException('sin red');
      return http.Response.bytes(utf8.encode(okBody), 200);
    }));
    expect(calls, 2);
    expect(dir?['polyline'], 'abc');
  });

  test('no insiste si la clave o la petición son inválidas', () async {
    var calls = 0;
    final dir = await run(MockClient((_) async {
      calls++;
      return http.Response('forbidden', 403);
    }));
    expect(calls, 1);
    expect(dir, isNull);
  });

  test('sin ruta posible devuelve null para usar el trazado aproximado', () async {
    expect(await run(MockClient((_) async => http.Response('{}', 200))), isNull);
  });
}
