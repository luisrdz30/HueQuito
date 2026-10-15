import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/screens/hueca_detail_screen.dart';

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
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

  final testHueca = Hueca(
    id: 'test_hueca_1',
    name: 'Hueca Las Palmeras',
    description: {'es': 'Tradición familiar desde 1980.'},
    address: 'Av. Granados y 6 de Diciembre',
    sector: 'Norte',
    location: const GeoPoint(-0.165, -78.475),
    phone: '0991234567',
    schedule: {'Lunes - Viernes': '08:00 - 18:00'},
    mainDish: {'name': {'es': 'Seco de Chivo'}, 'price': 5.50, 'emoji': '🍲'},
    loyaltyCard: {'totalStamps': 5, 'reward': 'Plato gratis'},
    secretSticker: {'rewardDescription': 'Bebida de cortesía'},
    menuItems: [
      {
        'name': {'es': 'Seco de Chivo'},
        'description': {'es': 'Acompañado de arroz amarillo y maduro'},
        'price': 5.50,
        'image': 'https://images.unsplash.com/test_dish.jpg'
      }
    ],
    tags: ['Tradicional', 'Almuerzos'],
    priceLevel: '\$\$',
    rating: 4.8,
    reviewCount: 35,
    images: [
      'https://images.unsplash.com/photo1.jpg',
      'https://images.unsplash.com/photo2.jpg',
      'https://images.unsplash.com/photo3.jpg',
    ],
    ownerId: 'owner_1',
    isActive: true,
    metrics: {'views': 120},
  );

  final testUser = UserModel(
    uid: 'test_user_1',
    name: 'Juan Perez',
    email: 'juan@test.com',
    profilePicUrl: 'https://via.placeholder.com/150',
    gamification: {'totalStamps': 5, 'level': 1, 'title': 'Novato'},
    preferences: {'favoriteDishes': [], 'dietaryRestrictions': []},
    sectorAlbums: [],
    favoriteHuecas: [],
    role: 'user',
  );

  testWidgets('HuecaDetailScreen renders auto-scrolling photo carousel with dynamic counter', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) async => testUser),
        ],
        child: MaterialApp(
          home: HuecaDetailScreen(hueca: testHueca),
        ),
      ),
    );
    await tester.pump();

    // Verify counter shows 1 de 3 FOTOS
    expect(find.text('1 de 3 FOTOS'), findsOneWidget);

    // Verify fullscreen icon is present
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
  });

  testWidgets('Tapping photo opens full-screen interactive viewer with BoxFit.contain', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) async => testUser),
        ],
        child: MaterialApp(
          home: HuecaDetailScreen(hueca: testHueca),
        ),
      ),
    );
    await tester.pump();

    // Tap on the fullscreen button or the photo
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();

    // Now full screen viewer is displayed
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('1 de 3'), findsOneWidget);
    expect(find.text('Hueca Las Palmeras'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Close full screen
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsNothing);
  });
}
