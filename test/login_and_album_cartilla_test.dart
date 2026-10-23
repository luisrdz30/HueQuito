import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/screens/login_screen.dart';
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

  group('LoginScreen Enhancements', () {
    testWidgets('LoginScreen renders forgot password button and opens recovery dialog', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check fields and forgot password button exist
      expect(find.text('Iniciar Sesión'), findsOneWidget);
      expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);

      // Tap '¿Olvidaste tu contraseña?'
      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.text('Recuperar Contraseña'), findsOneWidget);
      expect(find.text('Enviar Enlace'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      // Tap Cancelar
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Dialog is dismissed
      expect(find.text('Recuperar Contraseña'), findsNothing);
    });

    testWidgets('LoginScreen shows validation when submitting empty or blank credentials', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter only spaces in email
      final emailField = find.widgetWithText(TextField, 'Correo Electrónico');
      await tester.enterText(emailField, '   ');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
      await tester.pumpAndSettle();

      // Error message for empty email
      expect(find.text('Por favor ingresa tu correo electrónico'), findsOneWidget);
    });
  });

  group('AlbumScreen Cartillas Collapsible & 2-Row Display', () {
    final testHueca10 = Hueca(
      id: 'h_10_stamps',
      name: 'Corvinas Tradicionales',
      description: {'es': 'Pescado frito tradicional'},
      address: 'Mercado Central',
      sector: 'Centro Histórico',
      location: const GeoPoint(-0.2195, -78.5085),
      phone: '099111222',
      schedule: {'Lunes - Domingo': '08:00 - 17:00'},
      mainDish: {'name': 'Corvina', 'price': 5.0, 'emoji': '🐟'},
      loyaltyCard: {
        'targetStamps': 10,
        'maxStamps': 10,
        'rewardText': {'es': 'Porción gratis de patacones'},
      },
      metrics: {},
      secretSticker: {},
      menuItems: [],
      tags: ['Pescado'],
      priceLevel: '\$',
      rating: 4.8,
      reviewCount: 30,
      images: [],
      ownerId: 'owner_10',
      isActive: true,
      isSectorConfirmed: true,
      branches: [],
    );

    final testUser = UserModel(
      uid: 'user_tester',
      name: 'Comensal Quiteño',
      email: 'comensal@test.com',
      profilePicUrl: '',
      gamification: {
        'totalStamps': 4,
        'huecaStamps': {
          'h_10_stamps': 4,
        },
      },
      preferences: {},
      sectorAlbums: [],
      favoriteHuecas: [],
      subscribedHuecas: [],
      role: 'user',
    );

    testWidgets('Hueca cartilla starts compact and expands on tap with 2 rows of 5 stamps', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Future.value(testUser)),
            huecasProvider.overrideWith((ref) => Future.value([testHueca10])),
            settingsProvider.overrideWith(() => SettingsNotifier()),
          ],
          child: const MaterialApp(
            home: AlbumScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Name and compact status badge are visible
      expect(find.text('Corvinas Tradicionales'), findsOneWidget);
      expect(find.text('4/10 Sellos'), findsOneWidget);

      // When collapsed, the reward text and grid items (like stamp numbers) are NOT shown
      expect(find.text('Recompensa: Porción gratis de patacones'), findsNothing);
      expect(find.text('10'), findsNothing);

      // Tap on the card to expand it
      await tester.tap(find.text('Corvinas Tradicionales'));
      await tester.pumpAndSettle();

      // Now expanded: Reward is visible
      expect(find.text('Recompensa: Porción gratis de patacones'), findsOneWidget);

      // Numbered unstamped slots (5 to 10) are visible in the 2-row grid!
      expect(find.text('5'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      // Tap again to collapse
      await tester.tap(find.text('Corvinas Tradicionales'));
      await tester.pumpAndSettle();

      // Reward is hidden again
      expect(find.text('Recompensa: Porción gratis de patacones'), findsNothing);
    });
  });
}
