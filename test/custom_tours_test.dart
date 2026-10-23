import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/utils/tour_distance_helper.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/route_repository.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/widgets/tour_mode_selection_dialog.dart';
import 'package:hue_quito/screens/tour_wizard_screen.dart';
import 'package:hue_quito/screens/tour_creator_screen.dart';

void main() {
  final sampleHueca1 = Hueca(
    id: 'h1',
    name: 'Locros de Doña María',
    description: {'es': 'Sopas y locros tradicionales de Quito', 'en': 'Traditional soups'},
    address: 'Av. América',
    sector: 'Centro',
    location: const GeoPoint(-0.2186, -78.5080),
    phone: '0991111111',
    schedule: {},
    mainDish: {
      'name': {'es': 'Locro de Papa con Queso', 'en': 'Potato and cheese soup'},
      'price': 4.5,
    },
    loyaltyCard: {},
    secretSticker: {},
    menuItems: [],
    tags: ['sopa', 'locro', 'tradicional'],
    priceLevel: '\$',
    rating: 4.8,
    reviewCount: 120,
    images: ['https://example.com/locro.jpg'],
    ownerId: 'owner1',
    isActive: true,
    metrics: {},
  );

  final sampleHueca2Close = Hueca(
    id: 'h2',
    name: 'Hornado San Roque',
    description: {'es': 'Hornado con mote y tortillas', 'en': 'Roast pork with mote'},
    address: 'Calle Rocafuerte',
    sector: 'Centro Histórico',
    location: const GeoPoint(-0.2220, -78.5130), // ~0.6 km from h1
    phone: '0992222222',
    schedule: {},
    mainDish: {
      'name': {'es': 'Hornado Tradicional', 'en': 'Traditional Roast Pork'},
      'price': 5.0,
    },
    loyaltyCard: {},
    secretSticker: {},
    menuItems: [],
    tags: ['hornado', 'chancho', 'cerdo', 'plato fuerte'],
    priceLevel: '\$',
    rating: 4.7,
    reviewCount: 95,
    images: ['https://example.com/hornado.jpg'],
    ownerId: 'owner2',
    isActive: true,
    metrics: {},
  );

  final sampleHueca3Far = Hueca(
    id: 'h3',
    name: 'Heladería San Agustín',
    description: {'es': 'Helados de paila artesanales', 'en': 'Artisanal ice cream'},
    address: 'Guayllabamba',
    sector: 'Norte Lejano',
    location: const GeoPoint(-0.0600, -78.3400), // ~25 km away
    phone: '0993333333',
    schedule: {},
    mainDish: {
      'name': {'es': 'Helado de Paila de Mora y Guanábana', 'en': 'Artisanal Ice Cream'},
      'price': 2.5,
    },
    loyaltyCard: {},
    secretSticker: {},
    menuItems: [],
    tags: ['helado', 'paila', 'dulce', 'postre'],
    priceLevel: '\$',
    rating: 4.9,
    reviewCount: 200,
    images: ['https://example.com/helado.jpg'],
    ownerId: 'owner3',
    isActive: true,
    metrics: {},
  );

  group('TourDistanceHelper Unit Tests', () {
    test('calculateDistanceKm returns accurate distance and handles edge cases', () {
      final distZero = TourDistanceHelper.calculateDistanceKm(0, 0, 0, 0);
      expect(distZero, 0.0);

      final dist = TourDistanceHelper.calculateDistanceKm(
        sampleHueca1.location.latitude,
        sampleHueca1.location.longitude,
        sampleHueca2Close.location.latitude,
        sampleHueca2Close.location.longitude,
      );
      expect(dist, greaterThan(0.2));
      expect(dist, lessThan(3.0));
    });

    test('estimateDrivingMinutes respects Quito city speed and sets minimum to 2 min for non-zero distances', () {
      expect(TourDistanceHelper.estimateDrivingMinutes(0.0), 0);
      expect(TourDistanceHelper.estimateDrivingMinutes(0.4), 2);
      expect(TourDistanceHelper.estimateDrivingMinutes(12.0), greaterThanOrEqualTo(25));
    });

    test('sortHuecasByProximity orders closest first and keeps distant huecas in the list', () {
      final candidates = [sampleHueca3Far, sampleHueca2Close];
      final sorted = TourDistanceHelper.sortHuecasByProximity(
        huecas: candidates,
        fromHueca: sampleHueca1,
      );

      expect(sorted.length, 2);
      // Closest must be first
      expect(sorted.first.hueca.id, sampleHueca2Close.id);
      expect(sorted.first.isClose, isTrue);

      // Distant must still be present at the bottom
      expect(sorted.last.hueca.id, sampleHueca3Far.id);
      expect(sorted.last.isClose, isFalse);
      expect(sorted.last.distanceKm, greaterThan(15.0));
    });

    test('matchesCraving detects proper keywords for soup, heavy dishes, dessert and any', () {
      expect(TourDistanceHelper.matchesCraving(sampleHueca1, TourCravingType.soup), isTrue);
      expect(TourDistanceHelper.matchesCraving(sampleHueca1, TourCravingType.dessert), isFalse);

      expect(TourDistanceHelper.matchesCraving(sampleHueca2Close, TourCravingType.heavy), isTrue);
      expect(TourDistanceHelper.matchesCraving(sampleHueca2Close, TourCravingType.soup), isFalse);

      expect(TourDistanceHelper.matchesCraving(sampleHueca3Far, TourCravingType.dessert), isTrue);
      expect(TourDistanceHelper.matchesCraving(sampleHueca3Far, TourCravingType.any), isTrue);
    });

    test('calculateMetrics calculates cumulative distance, driving minutes and individual legs', () {
      final metrics = TourDistanceHelper.calculateMetrics([sampleHueca1, sampleHueca2Close, sampleHueca3Far]);
      expect(metrics.legs.length, 2);
      expect(metrics.totalDistanceKm, greaterThan(15.0));
      expect(metrics.totalDurationMinutes, greaterThan(30));
    });
  });

  group('Custom Tours UI Widget Tests', () {
    testWidgets('TourModeSelectionDialog renders both mode cards and options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => TourModeSelectionDialog.show(context, language: 'es'),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Crea tu Propio Tour'), findsOneWidget);
      expect(find.text('Tour Asistido por Preguntas'), findsOneWidget);
      expect(find.text('Armar a mi Manera'), findsOneWidget);
      expect(find.text('⭐ Recomendado'), findsOneWidget);
    });

    testWidgets('TourWizardScreen renders stop count selector cards and advances to Stop 1', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            huecasProvider.overrideWith((ref) async => [sampleHueca1, sampleHueca2Close, sampleHueca3Far]),
          ],
          child: const MaterialApp(
            home: TourWizardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Stop Count selection
      expect(find.text('¿Cuántas huecas quieres visitar hoy?'), findsOneWidget);
      expect(find.text('2 Huecas'), findsOneWidget);
      expect(find.text('3 Huecas'), findsOneWidget);
      expect(find.text('4 Huecas'), findsOneWidget);

      // Tap 3 Huecas
      await tester.tap(find.text('3 Huecas'));
      await tester.pumpAndSettle();

      // Check step 1 question
      expect(find.text('PARADA 1 DE 3'), findsOneWidget);
      expect(find.text('¿Cómo arrancamos esta aventura gastronómica en Quito?'), findsOneWidget);
      expect(find.text('🥣 Sopas y Caldos'), findsOneWidget);
      expect(find.text('Locros de Doña María'), findsOneWidget);
    });

    testWidgets('TourCreatorScreen renders search bar, metrics chip and catalog with + Agregar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            huecasProvider.overrideWith((ref) async => [sampleHueca1, sampleHueca2Close]),
          ],
          child: const MaterialApp(
            home: TourCreatorScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Armar Tour a mi Manera'), findsOneWidget);
      expect(find.text('AGREGAR HUECAS DEL CATÁLOGO'), findsOneWidget);
      expect(find.text('+ Agregar'), findsWidgets);

      // Tap + Agregar on first hueca
      await tester.tap(find.text('+ Agregar').first);
      await tester.pumpAndSettle();

      // Verify it was added to the top stops list
      expect(find.text('1 huecas'), findsWidgets);
    });
  });
}
