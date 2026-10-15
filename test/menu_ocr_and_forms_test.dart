import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/screens/business/dish_form_screen.dart';
import 'package:hue_quito/screens/business/menu_review_screen.dart';

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
}

class _FakeHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => _FakeHttpClientRequest();
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(_FakeHttpClientResponse());
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientResponse implements HttpClientResponse {
  static final _transparentImage = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
    0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
    0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
    0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
    0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
    0x60, 0x82
  ];

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _transparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_transparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });

  group('Menu & OCR UI Widget Tests', () {
    testWidgets('DishFormScreen renders new dish fields and auto-translation banner', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DishFormScreen(
              huecaId: 'hueca_123',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nuevo Plato Manual'), findsOneWidget);
      expect(find.text('Traducción Bilingüe Automática'), findsOneWidget);
      expect(find.text('Nombre del Plato (Español) *'), findsOneWidget);
      expect(find.text('Nombre en Inglés (English)'), findsOneWidget);
      expect(find.text('Precio *'), findsOneWidget);
      expect(find.text('Categoría'), findsOneWidget);
      expect(find.text('Disponible en la Carta'), findsOneWidget);
      expect(find.text('Añadir Plato al Menú'), findsOneWidget);
    });

    testWidgets('DishFormScreen loads with existing dish data for editing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      final existingDish = {
        'id': 'dish_001',
        'name': {'es': 'Seco de Chivo', 'en': 'Goat Stew'},
        'description': {'es': 'Con arroz amarillo y maduro', 'en': 'With yellow rice'},
        'price': 6.50,
        'category': 'Platos Típicos',
        'imageUrl': '',
        'isAvailable': true,
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DishFormScreen(
              huecaId: 'hueca_123',
              initialDish: existingDish,
              dishIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Editar Plato'), findsOneWidget);
      expect(find.text('Seco de Chivo'), findsOneWidget);
      expect(find.text('Goat Stew'), findsOneWidget);
      expect(find.text('6.5'), findsOneWidget);
      expect(find.text('Platos Típicos'), findsWidgets);
      expect(find.text('Guardar Cambios'), findsOneWidget);
    });

    testWidgets('MenuReviewScreen displays extracted dishes from OCR', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      final detectedDishes = [
        {
          'id': 'dish_ocr_1',
          'name': {'es': 'Ceviche Mixto', 'en': 'Mixed Ceviche'},
          'description': {'es': 'Camarón y pescado', 'en': 'Shrimp and fish'},
          'price': 7.50,
          'category': 'Platos Típicos',
          'imageUrl': '',
        },
        {
          'id': 'dish_ocr_2',
          'name': {'es': 'Jarra de Chicha', 'en': 'Chicha Pitcher'},
          'description': {'es': 'Bebida fermentada de maíz', 'en': 'Fermented corn drink'},
          'price': 3.00,
          'category': 'Bebidas',
          'imageUrl': '',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MenuReviewScreen(
              huecaId: 'hueca_123',
              initialDishes: detectedDishes,
              rawOcrText: 'Ceviche Mixto \$7.50\nJarra de Chicha \$3.00',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Revisar Platos (IA)'), findsOneWidget);
      expect(find.text('Detectamos 2 platos en tu menú. Revisa o corrige los precios y nombres antes de agregarlos.'), findsOneWidget);
      expect(find.text('Ceviche Mixto'), findsOneWidget);
      expect(find.text('Jarra de Chicha'), findsOneWidget);
      expect(find.text('Confirmar y Guardar 2 Platos en Menú'), findsOneWidget);

      // Verify that discarding a dish updates the list
      final deleteButtons = find.byIcon(Icons.delete_outline);
      expect(deleteButtons, findsNWidgets(2));
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Confirmar y Guardar 1 Platos en Menú'), findsOneWidget);
    });
  });
}
