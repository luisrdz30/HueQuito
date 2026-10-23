import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/widgets/business_onboarding_dialog.dart';
import 'package:hue_quito/screens/admin/admin_hueca_edit_screen.dart';

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
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
    id: 'h_test_1',
    name: 'Seco de Chivo La Esquina',
    description: {'es': 'Sabor tradicional'},
    address: 'Guayaquil y Bolívar',
    sector: 'Centro Histórico',
    location: const GeoPoint(-0.22, -78.51),
    phone: '0998877665',
    schedule: {},
    mainDish: {},
    loyaltyCard: {},
    secretSticker: {},
    menuItems: [],
    tags: [],
    priceLevel: '\$',
    rating: 4.8,
    reviewCount: 15,
    images: [],
    ownerId: 'owner_test',
    isActive: true,
    metrics: {'viewCount': 100, 'favoriteCount': 20, 'routeAdditions': 5, 'stampsGiven': 10},
  );

  testWidgets('BusinessOnboardingDialog renders welcome slide and navigates between slides', (tester) async {
    await tester.binding.setSurfaceSize(const Size(450, 950));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showBusinessOnboardingDialog(context, testHueca, markAsSeen: false),
                child: const Text('Abrir Guía'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir Guía'));
    await tester.pumpAndSettle();

    // Slide 0: Bienvenida
    expect(find.text('¡Bienvenido a HueQuito!'), findsOneWidget);
    expect(find.text('Seco de Chivo La Esquina'), findsOneWidget);
    expect(find.text('Pon tu hueca en orden en 6 sencillos pasos'), findsOneWidget);

    // Navegar al Slide 1 (Perfil)
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Aca pones todo sobre tu negocio'), findsOneWidget);
    expect(find.text('Ir a Perfil'), findsOneWidget);

    // Navegar al Slide 2 (Menú con IA)
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Aca gestionas tu menú con IA'), findsOneWidget);
    expect(find.text('Ir a Menú con IA'), findsOneWidget);

    // Navegar al Slide 3 (Mi QR)
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Aca entregas sellos y puntos con QR'), findsOneWidget);
    expect(find.text('Ver Mi QR'), findsOneWidget);

    // Navegar al Slide 4 (Plan Gratuito y Suscripción)
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Plan Gratuito y Suscripción'), findsOneWidget);
    expect(find.text('Ver Plan y Pagos'), findsOneWidget);

    // Navegar al Slide 5 (Avisos)
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Aca pides notificaciones y avisos'), findsOneWidget);
    expect(find.text('Ir a Avisos'), findsOneWidget);

    // Navegar al Slide 6 (Dashboard y Métricas)
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Aqui estan tus dashboards y métricas'), findsOneWidget);
    expect(find.text('¡Comenzar a Configurar!'), findsOneWidget);
  });

  testWidgets('AdminHuecaEditScreen displays streamlined basic fields for new hueca', (tester) async {
    await tester.binding.setSurfaceSize(const Size(450, 950));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allUsersStreamProvider.overrideWith((ref) => Stream.value([
            UserModel(
              uid: 'u1',
              name: 'Don Carlos Dueño',
              email: 'carlos@hueca.ec',
              profilePicUrl: '',
              gamification: {},
              preferences: {},
              sectorAlbums: [],
              role: 'business',
            ),
          ])),
          allHuecasStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: AdminHuecaEditScreen(), // isNew = true
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Header y banner de creación rápida básica
    expect(find.text('Nueva Hueca'), findsOneWidget);
    expect(find.text('Creación Rápida de Hueca'), findsOneWidget);

    // Campos básicos visibles de inmediato
    expect(find.text('Nombre de la Hueca *'), findsOneWidget);
    expect(find.text('Dirección física *'), findsOneWidget);
    expect(find.text('Cuenta de Negocio / Dueño Asignado'), findsOneWidget);
    expect(find.text('Campos Opcionales (GPS, Fotos, Menú)'), findsOneWidget);
    expect(find.text('Registrar Hueca'), findsOneWidget);
  });
}
