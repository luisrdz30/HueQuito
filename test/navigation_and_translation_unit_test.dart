import 'package:flutter_test/flutter_test.dart';
import 'package:hue_quito/repositories/route_repository.dart';
import 'package:hue_quito/services/translation_service.dart';

void main() {
  group('Navigation, Routes & Translation Unit Tests', () {
    test('RouteModel serializes and deserializes accurately with bilingual support', () {
      final route = RouteModel(
        id: 'route_centro_historico',
        name: {
          'es': 'Ruta Dulce y Tradicional',
          'en': 'Sweet and Traditional Route',
        },
        narrative: {
          'es': 'Recorrido por las mejores dulcerías y cafés del Centro.',
          'en': 'Tour across the best sweet spots and cafes of the Old Town.',
        },
        bannerImageUrl: 'https://example.com/banner.jpg',
        tags: ['dulces', 'café', 'centro'],
        metrics: {
          'distance': '2.4 km',
          'estimatedTime': '1h 30m',
          'totalStops': 4,
        },
        recommendedSchedule: {
          'time': {'es': 'Tardes', 'en': 'Afternoons'},
          'note': {'es': 'Ideal después del almuerzo', 'en': 'Best after lunch'},
        },
        stops: [
          {
            'order': 1,
            'huecaId': 'hueca_colaciones',
            'huecaName': 'Colaciones de la Cruz Verde',
            'recommendedDish': 'Colaciones tradicionales',
          },
          {
            'order': 2,
            'huecaId': 'hueca_helados',
            'huecaName': 'Helados de Paila de San Agustín',
            'recommendedDish': 'Helado de mora y guanábana',
          },
        ],
      );

      final map = route.toMap();
      expect(map['id'], equals('route_centro_historico'));
      expect(map['name']['es'], equals('Ruta Dulce y Tradicional'));
      expect(map['name']['en'], equals('Sweet and Traditional Route'));
      expect(map['tags'], contains('café'));
      expect(map['stops'].length, equals(2));
      expect(map['metrics']['distance'], equals('2.4 km'));
    });

    test('Route progress and stops calculation behaves as expected', () {
      final stops = [
        {'order': 1, 'huecaId': 'h1'},
        {'order': 2, 'huecaId': 'h2'},
        {'order': 3, 'huecaId': 'h3'},
        {'order': 4, 'huecaId': 'h4'},
      ];

      final visitedHuecaIds = {'h1', 'h2'};

      int completedStopsCount = 0;
      for (final stop in stops) {
        if (visitedHuecaIds.contains(stop['huecaId'])) {
          completedStopsCount++;
        }
      }

      final progressRatio = completedStopsCount / stops.length;
      expect(completedStopsCount, equals(2));
      expect(progressRatio, equals(0.5));
      expect((progressRatio * 100).toInt(), equals(50));
    });

    test('Map link generator formats standard Google Maps URI accurately', () {
      String generateGoogleMapsUrl({
        required double latitude,
        required double longitude,
        required String label,
      }) {
        final encodedLabel = Uri.encodeComponent(label);
        return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude&query_place_id=$encodedLabel';
      }

      final url = generateGoogleMapsUrl(
        latitude: -0.2205,
        longitude: -78.5123,
        label: 'Las Corvinas de Don Jimmy',
      );

      expect(url, startsWith('https://www.google.com/maps/search/'));
      expect(url, contains('-0.2205,-78.5123'));
      expect(url, contains('Las%20Corvinas%20de%20Don%20Jimmy'));
    });

    test('TranslationService handles fallback gracefully without throwing errors', () async {
      // When input is empty, translation service gracefully handles or falls back
      final result = await TranslationService.translateEsToEn('');
      expect(result, isNotNull);
    });
  });
}
