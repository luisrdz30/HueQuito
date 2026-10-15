import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/screens/business/dashboard_screen.dart';
import 'package:hue_quito/widgets/delete_hueca_dialog.dart';

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
}

class _FakeHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  group('Business Metrics Tests', () {
    test('Hueca correctly parses zero reviews and custom metrics without hardcoded 225', () {
      final hueca = Hueca(
        id: 'hueca_test',
        name: 'Hueca Real',
        description: {'es': 'Prueba'},
        address: 'Calle Falsa 123',
        sector: 'Centro Histórico',
        location: const GeoPoint(-0.22, -78.51),
        phone: '0999999999',
        schedule: {},
        mainDish: {},
        loyaltyCard: {},
        secretSticker: {},
        menuItems: [],
        tags: [],
        priceLevel: '\$',
        rating: 0.0,
        reviewCount: 0,
        images: [],
        ownerId: 'owner_123',
        isActive: true,
        metrics: {
          'viewCount': 15,
          'favoriteCount': 4,
          'routeAdditions': 2,
          'stampsGiven': 1,
        },
      );

      expect(hueca.reviewCount, 0);
      expect(hueca.rating, 0.0);
      expect(hueca.metrics['favoriteCount'], 4);
      expect(hueca.metrics['routeAdditions'], 2);
      expect(hueca.metrics['viewCount'], 15);
    });

    testWidgets('BusinessDashboardScreen displays live metrics (0 reviews, 4 favorites, 2 routes)', (tester) async {
      final testHueca = Hueca(
        id: 'hueca_test_screen',
        name: 'Hueca Con Métricas Reales',
        description: {'es': 'Descripción real'},
        address: 'Av. Siempre Viva 742',
        sector: 'La Mariscal',
        location: const GeoPoint(-0.20, -78.49),
        phone: '0987654321',
        schedule: {},
        mainDish: {},
        loyaltyCard: {},
        secretSticker: {},
        menuItems: [],
        tags: [],
        priceLevel: '\$\$',
        rating: 0.0,
        reviewCount: 0,
        images: [],
        ownerId: 'owner_test',
        isActive: true,
        metrics: {
          'viewCount': 42,
          'favoriteCount': 4,
          'routeAdditions': 2,
          'stampsGiven': 7,
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myHuecaProvider.overrideWith((ref) => Future.value(testHueca)),
          ],
          child: const MaterialApp(
            home: BusinessDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and titles
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Resumen de Impacto'), findsOneWidget);
      expect(find.text('Vistas Totales del Perfil'), findsOneWidget);

      // Check cards
      expect(find.text('Favoritos'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      expect(find.text('En Rutas'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      expect(find.text('Sellos Dados'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);

      expect(find.text('Reseñas'), findsOneWidget);
      expect(find.text('0'), findsOneWidget); // Specifically verifies it is 0 and NOT 225!

      // Verifies '225' is nowhere in the screen
      expect(find.text('225'), findsNothing);
    });

    testWidgets('showDeleteHuecaConfirmationDialog renders warning items and requires ELIMINAR to enable delete button', (tester) async {
      final testHueca = Hueca(
        id: 'hueca_delete_test',
        name: 'Hueca A Borrar',
        description: {'es': 'Prueba'},
        address: 'Calle Falsa 123',
        sector: 'Centro',
        location: const GeoPoint(-0.22, -78.51),
        phone: '0999999999',
        schedule: {},
        mainDish: {},
        loyaltyCard: {},
        secretSticker: {},
        menuItems: [],
        tags: [],
        priceLevel: '\$',
        rating: 4.0,
        reviewCount: 5,
        images: [],
        ownerId: 'owner_123',
        isActive: true,
        metrics: {},
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return InkWell(
                    onTap: () => showDeleteHuecaConfirmationDialog(
                      context: context,
                      ref: ref,
                      hueca: testHueca,
                    ),
                    child: const Text('Open Dialog'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap to open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog header and warnings
      expect(find.text('Eliminar Hueca'), findsOneWidget);
      expect(find.text('Hueca A Borrar'), findsOneWidget);
      expect(find.textContaining('definitiva e irreversible'), findsOneWidget);

      // Verify bullet items of wiped info
      expect(find.text('Perfil, dirección, ubicación y horarios'), findsOneWidget);
      expect(find.text('Menú completo y todos los platos'), findsOneWidget);
      expect(find.text('Todas las sucursales vinculadas'), findsOneWidget);
      expect(find.text('Tarjetas de fidelización, sellos y cromos'), findsOneWidget);
      expect(find.text('Avisos y notificaciones de la hueca'), findsOneWidget);
      expect(find.text('Historial de sellos y todas las reseñas'), findsOneWidget);

      // Button is initially disabled because text is empty
      final deleteButtonFinder = find.byType(ElevatedButton);
      expect(deleteButtonFinder, findsOneWidget);
      ElevatedButton deleteButton = tester.widget<ElevatedButton>(deleteButtonFinder);
      expect(deleteButton.onPressed, isNull);

      // Enter wrong text
      await tester.enterText(find.byType(TextField), 'NO');
      await tester.pump();
      deleteButton = tester.widget<ElevatedButton>(deleteButtonFinder);
      expect(deleteButton.onPressed, isNull);

      // Enter 'ELIMINAR'
      await tester.enterText(find.byType(TextField), 'ELIMINAR');
      await tester.pump();
      deleteButton = tester.widget<ElevatedButton>(deleteButtonFinder);
      expect(deleteButton.onPressed, isNotNull);

      // Cancel dismisses dialog
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar Hueca'), findsNothing);
    });
  });
}
