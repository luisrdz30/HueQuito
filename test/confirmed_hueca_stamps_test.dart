import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/screens/album_screen.dart';
import 'package:hue_quito/screens/profile_screen.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  Hueca createTestHueca({
    required String id,
    required String name,
    required String sector,
    required bool isSectorConfirmed,
    bool isActive = true,
  }) {
    return Hueca(
      id: id,
      name: name,
      description: {'es': 'Tradicion andina'},
      address: 'Calle Centro 100',
      sector: sector,
      location: const GeoPoint(-0.22, -78.51),
      phone: '0999999999',
      schedule: {},
      mainDish: {'name': 'Plato Fuerte'},
      loyaltyCard: {'targetStamps': 5, 'reward': 'Bebida de cortesia'},
      secretSticker: {
        'id': 'stk_$id',
        'name': 'Cromo $name',
        'imageUrl': 'https://example.com/$id.png',
        'qrSecret': 'QR_$id',
      },
      menuItems: [],
      tags: [],
      priceLevel: r'$',
      rating: 4.8,
      reviewCount: 15,
      images: [],
      ownerId: 'owner_$id',
      isActive: isActive,
      isSectorConfirmed: isSectorConfirmed,
      metrics: {'stampsGiven': 10},
    );
  }

  group('Confirmed Hueca Stamps & Album Tests', () {
    testWidgets('Unconfirmed hueca stamps do not appear in Cartillas and are not counted in total', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Usuario con sellos en una hueca confirmada (3 sellos) y en una no confirmada (5 sellos)
      final mockUser = UserModel(
        uid: 'user_test_1',
        email: 'cliente@test.com',
        name: 'Comensal Quiteño',
        profilePicUrl: 'https://example.com/avatar.png',
        role: 'user',
        preferences: {},
        gamification: {
          'points': 80,
          'totalStamps': 8, // Suma cruda previa: 3 + 5 = 8
          'huecaStamps': {
            'h_confirmada': 3,
            'h_no_confirmada': 5,
          },
          'collectedStickers': ['h_confirmada_matriz', 'h_no_confirmada_matriz'],
        },
        favoriteHuecas: [],
        subscribedHuecas: [],
        sectorAlbums: [],
      );

      final mockHuecas = [
        createTestHueca(
          id: 'h_confirmada',
          name: 'Hueca Aprobada',
          sector: 'Centro Histórico',
          isSectorConfirmed: true,
        ),
        createTestHueca(
          id: 'h_no_confirmada',
          name: 'Hueca Pendiente',
          sector: 'La Floresta',
          isSectorConfirmed: false, // NO confirmada
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Future.value(mockUser)),
            huecasProvider.overrideWith((ref) => Future.value(mockHuecas)),
            settingsProvider.overrideWith(() => SettingsNotifier()),
          ],
          child: const MaterialApp(
            home: AlbumScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verificar que el contador de Sellos Totales SOLO cuenta los 3 sellos de la confirmada
      expect(find.text('3 Sellos Totales'), findsOneWidget);
      expect(find.text('8 Sellos Totales'), findsNothing);

      // 2. Verificar que en "Cartillas por Hueca" solo aparece la confirmada
      expect(find.text('Hueca Aprobada'), findsOneWidget);
      expect(find.text('Hueca Pendiente'), findsNothing);

      // 3. Cambiar a la pestaña "Cromos por Sector"
      final sectorTab = find.text('Cromos por Sector');
      await tester.tap(sectorTab);
      await tester.pumpAndSettle();

      // El sector "Centro Histórico" (de la hueca confirmada) debe aparecer
      expect(find.text('Centro Histórico'), findsOneWidget);

      // El sector "La Floresta" (de la hueca no confirmada) NO debe aparecer para nada
      expect(find.text('La Floresta'), findsNothing);
    });

    testWidgets('ProfileScreen visited huecas KPI only counts confirmed huecas', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockUser = UserModel(
        uid: 'user_test_2',
        email: 'cliente2@test.com',
        name: 'Maria Exploradora',
        profilePicUrl: 'https://example.com/avatar2.png',
        role: 'user',
        preferences: {},
        gamification: {
          'points': 40,
          'totalStamps': 4,
          'huecaStamps': {
            'h_ok': 4,
            'h_pending': 2,
          },
        },
        favoriteHuecas: [],
        subscribedHuecas: [],
        sectorAlbums: [],
      );

      final mockHuecas = [
        createTestHueca(id: 'h_ok', name: 'Hueca OK', sector: 'Sur', isSectorConfirmed: true),
        createTestHueca(id: 'h_pending', name: 'Hueca Pendiente', sector: 'Norte', isSectorConfirmed: false),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Future.value(mockUser)),
            huecasProvider.overrideWith((ref) => Future.value(mockHuecas)),
            settingsProvider.overrideWith(() => SettingsNotifier()),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe mostrar 1 hueca visitada (solo la confirmada), no 2
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Huecas'), findsOneWidget);
    });
  });
}
