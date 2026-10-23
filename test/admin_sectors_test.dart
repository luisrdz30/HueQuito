import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/screens/admin/admin_sectors_screen.dart';
import 'package:hue_quito/screens/album_screen.dart';

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

  group('Admin Sectors & Cromos Grouping Tests', () {
    test('Hueca model parses and stores isSectorConfirmed properly', () {
      final hueca = Hueca(
        id: 'h1',
        name: 'Hueca Colonial',
        description: {'es': 'Tradición'},
        address: 'García Moreno y Sucre',
        sector: 'Centro Histórico',
        location: const GeoPoint(-0.2201, -78.5123),
        phone: '0999999999',
        schedule: {},
        mainDish: {'name': 'Empanadas de Viento'},
        loyaltyCard: {'targetStamps': 5},
        secretSticker: {
          'id': 'stk_1',
          'name': 'Cromo Virreinal',
          'qrSecret': 'SEC_VIRREY_123',
          'imageUrl': 'https://example.com/stk.png'
        },
        menuItems: [],
        tags: ['tradicional'],
        priceLevel: '\$',
        rating: 4.8,
        reviewCount: 15,
        images: ['https://example.com/img1.png'],
        ownerId: 'owner1',
        isActive: true,
        isSectorConfirmed: true,
        metrics: {},
      );

      expect(hueca.isSectorConfirmed, isTrue);
      expect(hueca.sector, equals('Centro Histórico'));
      expect(hueca.secretSticker['qrSecret'], equals('SEC_VIRREY_123'));

      final map = hueca.toMap();
      expect(map['isSectorConfirmed'], isTrue);
      expect(map['sector'], equals('Centro Histórico'));
    });

    testWidgets('AdminSectorsScreen renders grouped sectors and hueca items', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockHuecas = [
        Hueca(
          id: 'h_centro_1',
          name: 'La Tradición Quiteña',
          description: {'es': 'Sabor colonial'},
          address: 'Calle La Ronda 123',
          sector: 'Centro Histórico',
          location: const GeoPoint(-0.2230, -78.5140),
          phone: '0987654321',
          schedule: {},
          mainDish: {'name': 'Seco de Chivo'},
          loyaltyCard: {},
          secretSticker: {
            'id': 'stk_centro',
            'name': 'Cromo Balcón Colonial',
            'imageUrl': 'https://example.com/stk1.png',
            'qrSecret': 'QR_SEC_1',
          },
          menuItems: [],
          tags: [],
          priceLevel: '\$',
          rating: 4.9,
          reviewCount: 30,
          images: ['https://example.com/hueca1.png'],
          ownerId: 'owner1',
          isActive: true,
          isSectorConfirmed: true,
          metrics: {},
        ),
        Hueca(
          id: 'h_floresta_1',
          name: 'Café de la Ocho',
          description: {'es': 'Arte y café'},
          address: 'Madrid y Toledo',
          sector: 'La Floresta',
          location: const GeoPoint(-0.2100, -78.4850),
          phone: '0987654322',
          schedule: {},
          mainDish: {'name': 'Humitas'},
          loyaltyCard: {},
          secretSticker: {}, // sin sticker
          menuItems: [],
          tags: [],
          priceLevel: '\$\$',
          rating: 4.6,
          reviewCount: 12,
          images: [],
          ownerId: 'owner2',
          isActive: true,
          isSectorConfirmed: false, // pendiente de confirmar
          metrics: {},
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allHuecasStreamProvider.overrideWith((ref) => Stream.value(mockHuecas)),
          ],
          child: const MaterialApp(
            home: AdminSectorsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar AppBar y Banner
      expect(find.text('Sectores y Cromos'), findsOneWidget);
      expect(find.text('Organizador de Álbum por Sector'), findsOneWidget);

      // Verificar que ambos sectores aparecen agrupados
      expect(find.text('Centro Histórico'), findsWidgets);
      expect(find.text('La Floresta'), findsWidgets);

      // Verificar que las huecas aparecen dentro de sus grupos
      expect(find.text('La Tradición Quiteña'), findsOneWidget);
      expect(find.text('Café de la Ocho'), findsOneWidget);

      // Hueca con cromo configurado
      expect(find.text('Cromo Balcón Colonial'), findsOneWidget);

      // Hueca sin cromo configurado
      expect(find.text('Sin cromo secreto asignado'), findsOneWidget);

      // Botón Confirmar Todo
      expect(find.text('Confirmar Todo'), findsOneWidget);
    });

    testWidgets('AlbumScreen displays dynamic Cromos por Sector with progress and unlocks', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockUser = UserModel(
        uid: 'user123',
        email: 'viajero@test.com',
        name: 'Carlos Explorador',
        profilePicUrl: '',
        role: 'user',
        preferences: {},
        gamification: {
          'points': 150,
          'collectedStickers': ['h_centro_1_matriz'], // tiene el cromo del Centro Histórico
          'huecaStamps': {'h_centro_1': 3},
        },
        favoriteHuecas: [],
        subscribedHuecas: [],
        sectorAlbums: [],
      );

      final mockHuecas = [
        Hueca(
          id: 'h_centro_1',
          name: 'La Tradición Quiteña',
          description: {'es': 'Sabor colonial'},
          address: 'Calle La Ronda 123',
          sector: 'Centro Histórico',
          location: const GeoPoint(-0.2230, -78.5140),
          phone: '0987654321',
          schedule: {},
          mainDish: {'name': 'Seco de Chivo'},
          loyaltyCard: {'targetStamps': 5},
          secretSticker: {
            'id': 'stk_centro',
            'name': 'Cromo Balcón Colonial',
            'imageUrl': 'https://example.com/stk1.png',
            'qrSecret': 'QR_SEC_1',
          },
          menuItems: [],
          tags: [],
          priceLevel: '\$',
          rating: 4.9,
          reviewCount: 30,
          images: [],
          ownerId: 'owner1',
          isActive: true,
          isSectorConfirmed: true,
          metrics: {},
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

      // Cambiar a la pestaña "Cromos por Sector"
      final sectorTab = find.text('Cromos por Sector');
      expect(sectorTab, findsOneWidget);
      await tester.tap(sectorTab);
      await tester.pumpAndSettle();

      // Verificar que aparece el sector "Centro Histórico" con su progreso
      expect(find.text('Centro Histórico'), findsOneWidget);
      expect(find.text('¡Completo!'), findsOneWidget);

      // Tocar en la tarjeta de sector para abrir el modal de cromos
      await tester.tap(find.text('Centro Histórico'));
      await tester.pumpAndSettle();

      // Verificar contenido del modal interactivo
      expect(find.text('Cromos de Centro Histórico'), findsOneWidget);
      expect(find.text('Cromo Balcón Colonial'), findsOneWidget);
    });
  });
}
