import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hue_quito/widgets/client_onboarding_dialog.dart';
import 'package:hue_quito/screens/profile_screen.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/repositories/user_repository.dart';

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

  group('Client Onboarding & Tutorial Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('ClientOnboardingDialog renders slide 0 and advances with Siguiente across 6 slides', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClientOnboardingDialog(lang: 'es'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar Slide 0 (Descubre Huecas)
      expect(find.text('Guía del Comensal'), findsOneWidget);
      expect(find.text('Paso 1 de 6'), findsOneWidget);
      expect(find.text('Descubre las Mejores Huecas'), findsOneWidget);
      expect(find.text('Saltar'), findsOneWidget);

      // Avanzar al Slide 1 (Mapa Interactivo)
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('Paso 2 de 6'), findsOneWidget);
      expect(find.text('Mapa Interactivo en Vivo'), findsOneWidget);
      expect(find.text('Atrás'), findsOneWidget);

      // Avanzar al Slide 2 (Rutas)
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('Paso 3 de 6'), findsOneWidget);
      expect(find.text('Rutas Culinarias Guiadas'), findsOneWidget);

      // Avanzar al Slide 3 (Sellos)
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('Paso 4 de 6'), findsOneWidget);
      expect(find.text('Cartilla Digital de Sellos'), findsOneWidget);

      // Avanzar al Slide 4 (Cromos)
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('Paso 5 de 6'), findsOneWidget);
      expect(find.text('Álbum de Cromos por Sector'), findsOneWidget);

      // Avanzar al Slide 5 (Escaneo y final)
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('Paso 6 de 6'), findsOneWidget);
      expect(find.text('¡Todo Listo para Empezar!'), findsOneWidget);
      expect(find.text('¡A Comer!'), findsOneWidget);
    });

    testWidgets('ClientOnboardingDialog Skip button marks tutorial as seen', (tester) async {
      SharedPreferences.setMockInitialValues({'has_seen_client_tutorial': false});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showClientOnboardingDialog(ctx, markAsSeen: true),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Saltar'), findsOneWidget);
      await tester.tap(find.text('Saltar'));
      await tester.pumpAndSettle();

      // Dialog closed
      expect(find.text('Descubre las Mejores Huecas'), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_seen_client_tutorial'), isTrue);
    });

    testWidgets('ProfileScreen renders Tutorial de la App option and triggers dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockUser = UserModel(
        uid: 'user_client',
        name: 'Maria Comensal',
        email: 'maria@test.com',
        profilePicUrl: 'https://example.com/avatar.png',
        gamification: {'points': 100},
        preferences: {},
        sectorAlbums: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Future.value(mockUser)),
            huecasProvider.overrideWith((ref) => Future.value([])),
            settingsProvider.overrideWith(() => SettingsNotifier()),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to find "Tutorial de la App"
      final tutorialTile = find.text('Tutorial de la App');
      expect(tutorialTile, findsOneWidget);

      // Tap to open tutorial from Profile
      await tester.tap(tutorialTile);
      await tester.pumpAndSettle();

      // Dialog is displayed
      expect(find.text('Guía del Comensal'), findsOneWidget);
      expect(find.text('Descubre las Mejores Huecas'), findsOneWidget);
    });

    test('Guest gamification save and get works via SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});

      final initial = await UserRepository.getGuestGamification();
      expect(initial['points'], equals(0));
      expect(initial['totalStamps'], equals(0));

      final toSave = {
        'points': 50,
        'totalStamps': 2,
        'level': 1,
        'title': 'Explorador',
        'huecaStamps': {'hueca_1': 2},
        'collectedStickers': ['hueca_1_matriz'],
      };
      await UserRepository.saveGuestGamification(toSave);

      final retrieved = await UserRepository.getGuestGamification();
      expect(retrieved['points'], equals(50));
      expect(retrieved['totalStamps'], equals(2));
      expect((retrieved['huecaStamps'] as Map)['hueca_1'], equals(2));
      expect((retrieved['collectedStickers'] as List), contains('hueca_1_matriz'));
    });
  });
}
