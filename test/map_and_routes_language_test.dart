import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/route_repository.dart';
import 'package:hue_quito/screens/route_list_screen.dart';
import 'package:hue_quito/screens/route_detail_screen.dart';
import 'package:hue_quito/screens/map_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

class MockEnglishSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => SettingsState(language: 'en');
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  final List<Hueca> mockHuecas = [
    Hueca(
      id: 'h1',
      name: 'Las Quesadillas de San Juan',
      description: {'es': 'Tradición centenaria', 'en': 'Centuries-old tradition'},
      sector: 'Centro Histórico',
      address: 'Deifilio Torres s/n',
      location: const GeoPoint(-0.215, -78.505),
      phone: '0999999991',
      schedule: {'monday': '08:00 - 18:00'},
      mainDish: {
        'name': {'es': 'Quesadillas', 'en': 'Quesadillas pastries'},
        'price': 1.5,
        'emoji': '🥐',
      },
      loyaltyCard: {'totalStamps': 5},
      secretSticker: {'rewardDescription': 'Café gratis'},
      menuItems: [],
      tags: ['Tradicional', 'Centro Histórico'],
      priceLevel: '\$',
      rating: 4.8,
      reviewCount: 150,
      images: ['https://example.com/h1.jpg'],
      ownerId: 'owner_1',
      isActive: true,
      metrics: {'views': 100},
      branches: [
        HuecaBranch(
          id: 'b1',
          name: 'Sucursal Cumbayá',
          address: 'Av. Interoceánica',
          sector: 'Cumbayá',
          location: const GeoPoint(-0.201, -78.435),
          phone: '0999999999',
          schedule: {'monday': '09:00 - 19:00'},
        ),
      ],
    ),
    Hueca(
      id: 'h2',
      name: 'Hornado Carmita',
      description: {'es': 'El mejor hornado del valle', 'en': 'The best roasted pork in the valley'},
      sector: 'Conocoto',
      address: 'Parque Central Conocoto',
      location: const GeoPoint(-0.290, -78.480),
      phone: '0999999992',
      schedule: {'monday': '07:00 - 16:00'},
      mainDish: {
        'name': 'Hornado tradicional con llapingachos', // String dish name edge case!
        'price': 4.5,
        'emoji': '🐷',
      },
      loyaltyCard: {'totalStamps': 5},
      secretSticker: {'rewardDescription': 'Bebida gratis'},
      menuItems: [],
      tags: ['Cerdo', 'Tradicional'],
      priceLevel: '\$',
      rating: 4.9,
      reviewCount: 300,
      images: ['https://example.com/h2.jpg'],
      ownerId: 'owner_2',
      isActive: true,
      metrics: {'views': 200},
      branches: [],
    ),
  ];

  final List<RouteModel> mockRoutes = [
    RouteModel(
      id: 'r1',
      name: {'es': 'Ruta Colonial de Sabores', 'en': 'Colonial Flavors Route'},
      narrative: {
        'es': 'Un recorrido sensorial a través de empedrados centenarios.',
        'en': 'A sensory journey through centuries-old cobblestones.',
      },
      bannerImageUrl: 'https://example.com/route1.jpg',
      tags: ['Centro Histórico', 'Tradicional'],
      metrics: {'distance': '2.4 km', 'estimatedTime': '2h 30m'},
      recommendedSchedule: {
        'time': {'es': '09:30 AM a 02:00 PM', 'en': '09:30 AM to 02:00 PM'},
        'note': {'es': 'Momento cumbre para saborear', 'en': 'Peak tasting time'},
      },
      stops: [
        {
          'order': 1,
          'huecaId': 'h1',
          'travelToNext': {
            'duration': '10 min',
            'distance': '800 m',
            'instruction': {'es': 'Camina hacia el norte', 'en': 'Walk northwards'},
          },
        },
        {
          'order': 2,
          'huecaId': 'h2',
        },
      ],
    ),
  ];

  testWidgets('RouteListScreen renders without error in English with string & map dish names', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          huecasProvider.overrideWith((ref) async => mockHuecas),
          userToursStreamProvider.overrideWith((ref) => Stream.value(mockRoutes)),
          settingsProvider.overrideWith(() => MockEnglishSettingsNotifier()),
        ],
        child: const MaterialApp(
          home: RouteListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify English labels are displayed
    expect(find.text('My Gastronomic Tours'), findsOneWidget);
    expect(find.text('My Tours'), findsOneWidget);
    expect(find.text('Interactive Map'), findsOneWidget);
    expect(find.text('Colonial Flavors Route'), findsOneWidget);
    expect(find.text('🍴 Quesadillas pastries'), findsOneWidget);
    expect(find.text('🍴 Hornado tradicional con llapingachos'), findsOneWidget);
  });

  testWidgets('RouteDetailScreen renders without error in English with plain string dish and travel step', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          huecasProvider.overrideWith((ref) async => mockHuecas),
          settingsProvider.overrideWith(() => MockEnglishSettingsNotifier()),
        ],
        child: MaterialApp(
          home: RouteDetailScreen(routeModel: mockRoutes.first),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Colonial Flavors Route'), findsOneWidget);
    expect(find.text('A sensory journey through centuries-old cobblestones.'), findsOneWidget);
    expect(find.text('10 min (800 m) Walk northwards'), findsOneWidget);
    expect(find.text('Quesadillas pastries'), findsOneWidget);
  });

  testWidgets('MapScreen renders without error in English mode with All sectors filter', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          huecasProvider.overrideWith((ref) async => mockHuecas),
          settingsProvider.overrideWith(() => MockEnglishSettingsNotifier()),
        ],
        child: const MaterialApp(
          home: MapScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('All sectors'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Traditional'), findsOneWidget);
    expect(find.text('Seafood'), findsOneWidget);
    expect(find.text('Pork'), findsOneWidget);
  });
}
