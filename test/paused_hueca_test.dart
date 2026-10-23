import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/screens/home_screen.dart';
import 'package:hue_quito/screens/tour_creator_screen.dart';

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getUrl) {
      return Future.value(_FakeHttpClientRequest());
    }
    return null;
  }
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #close) {
      return Future.value(_FakeHttpClientResponse());
    }
    return null;
  }
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
    0x60, 0x82,
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

Hueca makeHueca({
  required String id,
  required String name,
  required String sector,
  required bool isActive,
}) {
  return Hueca(
    id: id,
    name: name,
    description: {'es': 'Descripción de $name'},
    address: 'Av. Siempre Viva 123',
    sector: sector,
    location: const GeoPoint(-0.18, -78.48),
    phone: '0991234567',
    schedule: {},
    mainDish: {'name': 'Plato $name', 'emoji': '🍲'},
    loyaltyCard: {'targetStamps': 5, 'reward': 'Postre gratis'},
    secretSticker: {'id': 'stk_$id', 'name': 'Cromo $name'},
    menuItems: [],
    tags: ['Tradicional', 'Almuerzo'],
    searchTags: [name.toLowerCase(), sector.toLowerCase()],
    priceLevel: r'$$',
    rating: 4.7,
    reviewCount: 20,
    images: ['https://example.com/photo.jpg'],
    ownerId: 'owner_1',
    isActive: isActive,
    isSectorConfirmed: true,
    metrics: {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  testWidgets('HomeScreen never shows paused huecas in catalog or recommendations', (tester) async {
    final activeHueca = makeHueca(
      id: 'active_1',
      name: 'Hueca Activa Deliciosa',
      sector: 'La Floresta',
      isActive: true,
    );
    final pausedHueca = makeHueca(
      id: 'paused_1',
      name: 'Hueca Pausada Invisible',
      sector: 'La Floresta',
      isActive: false,
    );

    final mockHuecas = [activeHueca, pausedHueca];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          huecasProvider.overrideWith((ref) => Future.value(mockHuecas)),
          currentUserProvider.overrideWith((ref) => Future.value(null)),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Active hueca IS visible
    expect(find.text('Hueca Activa Deliciosa'), findsWidgets);

    // Verify Paused hueca is NEVER visible
    expect(find.text('Hueca Pausada Invisible'), findsNothing);
  });

  testWidgets('TourCreatorScreen catalog list excludes paused huecas', (tester) async {
    final activeHueca = makeHueca(
      id: 'active_1',
      name: 'Hueca Activa Tour',
      sector: 'Centro Histórico',
      isActive: true,
    );
    final pausedHueca = makeHueca(
      id: 'paused_1',
      name: 'Hueca Pausada Tour',
      sector: 'Centro Histórico',
      isActive: false,
    );

    final mockHuecas = [activeHueca, pausedHueca];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          huecasProvider.overrideWith((ref) => Future.value(mockHuecas)),
          currentUserProvider.overrideWith((ref) => Future.value(null)),
        ],
        child: const MaterialApp(
          home: TourCreatorScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Active hueca should appear in the catalog list to add
    expect(find.text('Hueca Activa Tour'), findsWidgets);

    // Paused hueca must not appear anywhere in catalog
    expect(find.text('Hueca Pausada Tour'), findsNothing);
  });
}
