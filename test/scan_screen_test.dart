import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/screens/scan_screen.dart';
import 'package:hue_quito/providers/settings_provider.dart';

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
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
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
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

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  group('ScanScreen Confirmation Modal and Dismiss Tests', () {
    final samplePointsData = {
      'type': 'points',
      'business_id': 'test_hueca_1',
      'branch_name': 'Sucursal La Mariscal',
      'points': 2,
      'token': 'tok_abc123',
    };

    testWidgets('Renders confirmation sheet with close button and backdrop when scanned', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ScanScreen(
              initialScannedDataForTesting: samplePointsData,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scan_close_button')), findsOneWidget);
      expect(find.byKey(const Key('scan_backdrop_dismiss')), findsOneWidget);
      expect(find.text('QR CONFIRMADO'), findsOneWidget);
      expect(find.text('Local: Sucursal La Mariscal'), findsOneWidget);
      expect(find.text('+2 Puntos'), findsOneWidget);
      expect(find.text('Canjear y Guardar'), findsOneWidget);
    });

    testWidgets('Tapping X close button dismisses confirmation sheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ScanScreen(
              initialScannedDataForTesting: samplePointsData,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scan_close_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('scan_close_button')));
      await tester.pumpAndSettle();

      // Confirmation sheet and close button should now be gone
      expect(find.byKey(const Key('scan_close_button')), findsNothing);
      expect(find.byKey(const Key('scan_backdrop_dismiss')), findsNothing);
      expect(find.text('QR CONFIRMADO'), findsNothing);
    });

    testWidgets('Tapping outside on backdrop dismisses confirmation sheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ScanScreen(
              initialScannedDataForTesting: samplePointsData,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scan_backdrop_dismiss')), findsOneWidget);

      // Tap on the backdrop above the bottom card
      await tester.tapAt(const Offset(200, 150));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scan_close_button')), findsNothing);
      expect(find.byKey(const Key('scan_backdrop_dismiss')), findsNothing);
    });

    testWidgets('Tapping inside the confirmation sheet does NOT dismiss it', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ScanScreen(
              initialScannedDataForTesting: samplePointsData,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scan_close_button')), findsOneWidget);

      // Tap on the text inside the card
      await tester.tap(find.text('Local: Sucursal La Mariscal'));
      await tester.pumpAndSettle();

      // Card is still visible
      expect(find.byKey(const Key('scan_close_button')), findsOneWidget);
      expect(find.text('QR CONFIRMADO'), findsOneWidget);
    });
  });
}
