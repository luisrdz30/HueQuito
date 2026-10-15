import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/screens/business/branch_management_screen.dart';
import 'package:hue_quito/screens/business/gallery_management_screen.dart';
import 'package:hue_quito/screens/business/qr_secret_sticker_screen.dart';
import 'package:hue_quito/screens/business/qr_generator_screen.dart';
import 'package:hue_quito/services/geocoding_service.dart';
import 'package:hue_quito/utils/map_navigation_helper.dart';

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
    return Stream.value(_transparentImage).listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });

  group('HuecaBranch & Hueca Model Tests', () {
    test('HuecaBranch serialization and deserialization', () {
      final branch = HuecaBranch(
        id: 'branch_1',
        name: 'Sucursal Cumbayá',
        address: 'Av. Interoceánica',
        sector: 'Cumbayá',
        location: const GeoPoint(-0.20, -78.43),
        phone: '0991234567',
        schedule: {'Lunes': '09:00 - 18:00'},
        managerEmail: 'encargado@gmail.com',
      );

      final map = branch.toMap();
      expect(map['id'], 'branch_1');
      expect(map['name'], 'Sucursal Cumbayá');
      expect(map['managerEmail'], 'encargado@gmail.com');

      final fromMap = HuecaBranch.fromMap(map);
      expect(fromMap.id, 'branch_1');
      expect(fromMap.name, 'Sucursal Cumbayá');
      expect(fromMap.managerEmail, 'encargado@gmail.com');
      expect(fromMap.sector, 'Cumbayá');
    });

    test('Hueca fallback to default branch when branches list is empty', () {
      final huecaWithoutBranches = Hueca(
        id: 'h1',
        name: 'Hueca La Tradición',
        description: {'es': 'Rica comida'},
        address: 'Calle Guayaquil 123',
        sector: 'Centro Histórico',
        location: const GeoPoint(-0.22, -78.51),
        phone: '022987654',
        schedule: {'Lunes': '08:00 - 16:00'},
        mainDish: {'name': 'Seco de Chivo', 'price': 5.0},
        loyaltyCard: {'maxStamps': 8},
        secretSticker: {},
        menuItems: [],
        tags: ['Almuerzos'],
        priceLevel: '\$',
        rating: 4.8,
        reviewCount: 15,
        images: ['https://example.com/img1.jpg'],
        ownerId: 'owner_123',
        isActive: true,
        metrics: {},
        branches: [],
      );

      expect(huecaWithoutBranches.allBranches.length, 1);
      final defaultBranch = huecaWithoutBranches.allBranches.first;
      expect(defaultBranch.name, 'Matriz Principal');
      expect(defaultBranch.address, 'Calle Guayaquil 123');
      expect(defaultBranch.sector, 'Centro Histórico');
    });

    test('Hueca returns explicitly defined branches', () {
      final b1 = HuecaBranch(
        id: 'b1',
        name: 'Matriz Centro',
        address: 'Calle Chile 456',
        sector: 'Centro Histórico',
        location: const GeoPoint(-0.22, -78.51),
        phone: '022111111',
        schedule: {},
      );
      final b2 = HuecaBranch(
        id: 'b2',
        name: 'Sucursal Sur',
        address: 'Av. Maldonado',
        sector: 'Sur',
        location: const GeoPoint(-0.26, -78.53),
        phone: '022222222',
        schedule: {},
        managerEmail: 'sur@gmail.com',
      );

      final huecaWithBranches = Hueca(
        id: 'h2',
        name: 'Hueca Con Sucursales',
        description: {},
        address: 'Calle Chile 456',
        sector: 'Centro Histórico',
        location: const GeoPoint(-0.22, -78.51),
        phone: '022111111',
        schedule: {},
        mainDish: {},
        loyaltyCard: {},
        secretSticker: {},
        menuItems: [],
        tags: [],
        priceLevel: '\$',
        rating: 5.0,
        reviewCount: 1,
        images: ['https://example.com/img1.jpg'],
        ownerId: 'owner_456',
        isActive: true,
        metrics: {},
        branches: [b1, b2],
      );

      expect(huecaWithBranches.allBranches.length, 2);
      expect(huecaWithBranches.allBranches[0].name, 'Matriz Centro');
      expect(huecaWithBranches.allBranches[1].name, 'Sucursal Sur');
      expect(huecaWithBranches.allBranches[1].managerEmail, 'sur@gmail.com');
    });
  });

  group('UI Widget Rendering Tests (No red screens / exceptions)', () {
    final mockHueca = Hueca(
      id: 'mock_1',
      name: 'Hueca Test',
      description: {'es': 'Prueba'},
      address: 'Calle Falsa 123',
      sector: 'Norte',
      location: const GeoPoint(-0.18, -78.48),
      phone: '0990000000',
      schedule: {},
      mainDish: {},
      loyaltyCard: {},
      secretSticker: {},
      menuItems: [],
      tags: [],
      priceLevel: '\$',
      rating: 4.5,
      reviewCount: 10,
      images: ['https://via.placeholder.com/150'],
      ownerId: 'owner_test',
      isActive: true,
      metrics: {},
      branches: [
        HuecaBranch(
          id: 'b_matriz',
          name: 'Matriz Norte',
          address: 'Calle Falsa 123',
          sector: 'Norte',
          location: const GeoPoint(-0.18, -78.48),
          phone: '0990000000',
          schedule: {},
        ),
        HuecaBranch(
          id: 'b_cumbaya',
          name: 'Sucursal Cumbayá',
          address: 'Plaza Cumbayá',
          sector: 'Cumbayá',
          location: const GeoPoint(-0.20, -78.43),
          phone: '0991111111',
          schedule: {},
          managerEmail: 'manager@test.com',
        ),
      ],
    );

    testWidgets('BranchManagementScreen renders branches list without errors', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myHuecaProvider.overrideWith((ref) => Future.value(mockHueca)),
            isOwnerProvider.overrideWith((ref) => Future.value(true)),
            currentManagedBranchProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: const MaterialApp(
            home: BranchManagementScreen(huecaId: 'mock_1'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Mis Locales / Sucursales'), findsOneWidget);
      expect(find.text('Matriz Norte'), findsOneWidget);
      expect(find.text('Sucursal Cumbayá'), findsOneWidget);
      expect(find.text('Matriz'), findsOneWidget);
      expect(find.text('Nuevo Local'), findsOneWidget);
      expect(find.text('Encargado: manager@test.com'), findsOneWidget);
    });

    testWidgets('BranchManagementScreen renders in Admin mode with admin header and no business panel', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allHuecasStreamProvider.overrideWith((ref) => Stream.value([mockHueca])),
          ],
          child: const MaterialApp(
            home: BranchManagementScreen(huecaId: 'mock_1', isAdminMode: true),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Locales: Hueca Test'), findsOneWidget);
      expect(find.text('Administración Central de Locales'), findsOneWidget);
      expect(find.text('Matriz Norte'), findsOneWidget);
      expect(find.text('Sucursal Cumbayá'), findsOneWidget);
      expect(find.text('Nuevo Local'), findsOneWidget);
    });

    testWidgets('GalleryManagementScreen renders gallery photos without errors', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myHuecaProvider.overrideWith((ref) => Future.value(mockHueca)),
          ],
          child: const MaterialApp(
            home: GalleryManagementScreen(huecaId: 'mock_1'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Fotos de la Hueca'), findsOneWidget);
      expect(find.text('Portada'), findsOneWidget);
      expect(find.text('Subir Foto (1/5)'), findsOneWidget);
    });
  });

  group('GeocodingService Tests', () {
    test('detectSector correctly resolves known sectors in Quito', () {
      expect(
        GeocodingService.detectSector(
          addressComponents: {'neighbourhood': 'Cumbayá'},
          lat: -0.2018,
          lng: -78.4312,
        ),
        equals('Cumbayá'),
      );

      expect(
        GeocodingService.detectSector(
          addressComponents: {'city_district': 'Centro Histórico'},
          lat: -0.2228,
          lng: -78.5147,
        ),
        equals('Centro Histórico'),
      );

      expect(
        GeocodingService.detectSector(
          addressComponents: {'quarter': 'La Mariscal'},
          lat: -0.2025,
          lng: -78.4912,
        ),
        equals('La Mariscal'),
      );

      expect(
        GeocodingService.detectSector(
          addressComponents: {'suburb': 'Villaflora'},
          lat: -0.2482,
          lng: -78.5204,
        ),
        equals('Sur'),
      );

      expect(
        GeocodingService.detectSector(
          addressComponents: {'neighbourhood': 'La Carolina'},
          lat: -0.1806,
          lng: -78.4848,
        ),
        equals('Norte'),
      );
    });
  });

  group('Branch Secret Sticker and QR Screen Tests', () {
    test('HuecaBranch preserves secretSticker in toMap and fromMap', () {
      final branch = HuecaBranch(
        id: 'branch_sur',
        name: 'Sucursal Sur',
        address: 'Av. Maldonado 100',
        sector: 'Sur',
        location: const GeoPoint(-0.25, -78.52),
        phone: '0987654321',
        schedule: {'Lunes': '10:00 - 19:00'},
        managerEmail: 'encargado_sur@gmail.com',
        secretSticker: {
          'name': 'Fritada Dorada del Sur',
          'image': 'https://example.com/sticker_sur.png',
          'qrSecret': 'secret_sur_123',
        },
      );

      final map = branch.toMap();
      expect(map['secretSticker'], isNotNull);
      expect(map['secretSticker']['name'], 'Fritada Dorada del Sur');
      expect(map['secretSticker']['qrSecret'], 'secret_sur_123');

      final parsed = HuecaBranch.fromMap(map);
      expect(parsed.secretSticker, isNotNull);
      expect(parsed.secretSticker!['name'], 'Fritada Dorada del Sur');
      expect(parsed.secretSticker!['qrSecret'], 'secret_sur_123');
    });

    testWidgets('QrSecretStickerScreen renders with branch badge and sticker title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: QrSecretStickerScreen(
            qrSecret: 'branch_secret_xyz',
            huecaId: 'hueca_123',
            branchId: 'branch_cumbaya',
            branchName: 'Sucursal Cumbayá',
            stickerName: 'Corvina Especial Cumbayá',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('QR Sticker Secreto'), findsOneWidget);
      expect(find.text('Local: Sucursal Cumbayá'), findsOneWidget);
      expect(find.text('Sticker: Corvina Especial Cumbayá'), findsOneWidget);
      expect(find.text('¡Imprime este código QR!'), findsOneWidget);
    });

    testWidgets('BusinessQrScreen renders branch chip badge', (tester) async {
      final mockHueca = Hueca(
        id: 'h1',
        name: 'Hueca Don Jimmy',
        description: {},
        address: 'Av. Principal',
        sector: 'Centro',
        location: const GeoPoint(0, 0),
        phone: '022334455',
        schedule: {},
        mainDish: {},
        loyaltyCard: {},
        secretSticker: {},
        menuItems: [],
        tags: [],
        priceLevel: '\$',
        rating: 5.0,
        reviewCount: 10,
        images: [],
        ownerId: 'owner_user',
        isActive: true,
        metrics: {},
        branches: [
          HuecaBranch(
            id: 'b_sur',
            name: 'Sucursal Sur',
            address: 'Av. Sur',
            sector: 'Sur',
            location: const GeoPoint(0, 0),
            phone: '0999999999',
            schedule: {},
            managerEmail: 'sur_manager@gmail.com',
          ),
        ],
      );

      final branchSur = mockHueca.branches.first;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myHuecaProvider.overrideWith((ref) => Future.value(mockHueca)),
            isOwnerProvider.overrideWith((ref) => Future.value(false)),
            currentManagedBranchProvider.overrideWith((ref) => Future.value(branchSur)),
          ],
          child: const MaterialApp(
            home: BusinessQrScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Generador Dinámico'), findsOneWidget);
      expect(find.text('Sucursal Sur'), findsOneWidget);
    });

    testWidgets('MapNavigationHelper shows branch selection sheet when hueca has multiple branches', (tester) async {
      final multiBranchHueca = Hueca(
        id: 'multi_branch_h',
        name: 'Hornados Don Viche',
        description: {},
        address: 'Av. La Floresta 123',
        sector: 'La Floresta',
        location: const GeoPoint(-0.21, -78.49),
        phone: '0991234567',
        schedule: {},
        loyaltyCard: {},
        secretSticker: {},
        mainDish: const {'name': 'Hornado', 'price': 5.0},
        menuItems: [],
        tags: ['Comida Típica'],
        priceLevel: '\$',
        rating: 4.8,
        reviewCount: 35,
        images: [],
        ownerId: 'owner_user',
        isActive: true,
        metrics: {},
        branches: [
          HuecaBranch(
            id: 'matriz',
            name: 'Matriz La Floresta',
            address: 'Av. La Floresta 123',
            sector: 'Centro-Norte',
            location: const GeoPoint(-0.21, -78.49),
            phone: '0991234567',
            schedule: {},
          ),
          HuecaBranch(
            id: 'b_cumbaya',
            name: 'Sucursal Cumbayá',
            address: 'Av. Interoceánica km 10',
            sector: 'Cumbayá',
            location: const GeoPoint(-0.20, -78.43),
            phone: '0997654321',
            schedule: {},
          ),
        ],
      );

      int? selectedIdx;
      HuecaBranch? selectedBranch;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      MapNavigationHelper.openDirections(
                        context: context,
                        hueca: multiBranchHueca,
                        language: 'es',
                        initialBranchIndex: 0,
                        onBranchSelected: (idx, b) {
                          selectedIdx = idx;
                          selectedBranch = b;
                        },
                      );
                    },
                    child: const Text('Cómo llegar'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Tap 'Cómo llegar' button
      await tester.tap(find.text('Cómo llegar'));
      await tester.pumpAndSettle();

      // Expect the branch selection sheet to appear
      expect(find.text('¿A cuál sucursal deseas ir?'), findsOneWidget);
      expect(find.text('Matriz La Floresta'), findsOneWidget);
      expect(find.text('Sucursal Cumbayá'), findsOneWidget);
      expect(find.text('Sector: Cumbayá'), findsOneWidget);

      // Tap on 'Sucursal Cumbayá'
      await tester.tap(find.text('Sucursal Cumbayá'));
      await tester.pumpAndSettle();

      // Expect the callback to have fired with index 1
      expect(selectedIdx, 1);
      expect(selectedBranch?.name, 'Sucursal Cumbayá');
    });
  });
}

