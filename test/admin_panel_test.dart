import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/route_repository.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/screens/admin/admin_dashboard_screen.dart';
import 'package:hue_quito/screens/admin/admin_huecas_screen.dart';
import 'package:hue_quito/screens/admin/admin_routes_screen.dart';
import 'package:hue_quito/screens/admin/admin_route_edit_screen.dart';
import 'package:hue_quito/screens/admin/admin_users_screen.dart';

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

  final dummyHueca1 = Hueca(
    id: 'h1',
    name: 'Hornado Doña Rosita',
    description: {'es': 'El mejor hornado de Quito', 'en': 'Best roasted pork'},
    address: 'Av. América y Diguja',
    sector: 'Centro Histórico',
    location: const GeoPoint(-0.22, -78.51),
    phone: '0991234567',
    schedule: {'lunes': '08:00 - 18:00'},
    mainDish: {'name': 'Plato Hornado Completo', 'description': 'Con mote y llapingachos'},
    loyaltyCard: {'targetStamps': 5},
    secretSticker: {'code': 'ROSITA_STICKER'},
    menuItems: [],
    tags: ['Tradicional', 'Hornado'],
    priceLevel: '\$',
    rating: 4.9,
    reviewCount: 38,
    images: ['https://example.com/h1.jpg'],
    ownerId: 'u2',
    isActive: true,
    metrics: {'viewCount': 100, 'favoriteCount': 15, 'routeAdditions': 4, 'stampsGiven': 25},
  );

  final dummyHueca2 = Hueca(
    id: 'h2',
    name: 'Pailas de San Agustín',
    description: {'es': 'Helados centenarios', 'en': 'Centennial ice cream'},
    address: 'Guayaquil y Chile',
    sector: 'Centro Histórico',
    location: const GeoPoint(-0.219, -78.511),
    phone: '0987654321',
    schedule: {},
    mainDish: {'name': 'Helado de mora'},
    loyaltyCard: {},
    secretSticker: {},
    menuItems: [],
    tags: ['Dulces'],
    priceLevel: '\$',
    rating: 4.7,
    reviewCount: 12,
    images: [],
    ownerId: '',
    isActive: false,
    metrics: {},
  );

  final dummyUser1 = UserModel(
    uid: 'u1',
    name: 'Juan Perez',
    email: 'juan@gmail.com',
    profilePicUrl: '',
    gamification: {'totalStamps': 8, 'level': 3, 'title': 'Explorador'},
    preferences: {},
    sectorAlbums: [],
    role: 'user',
  );

  final dummyUser2 = UserModel(
    uid: 'u2',
    name: 'Rosita Dueña',
    email: 'rosita@hornado.ec',
    profilePicUrl: '',
    gamification: {'totalStamps': 0, 'level': 1, 'title': 'Novato'},
    preferences: {},
    sectorAlbums: [],
    role: 'business',
    managedHuecaId: 'h1',
  );

  final dummyRoute = RouteModel(
    id: 'r1',
    name: {'es': 'Ruta del Hornado y Tradición', 'en': 'Pork and Tradition Tour'},
    narrative: {'es': 'Un viaje por los sabores más tradicionales', 'en': 'A trip around traditional flavors'},
    bannerImageUrl: 'https://example.com/route.jpg',
    tags: ['Tradicional', 'Centro'],
    metrics: {'distance': '3.2 km', 'estimatedTime': '2 horas'},
    recommendedSchedule: {'time': {'es': 'Mañanas'}, 'note': {'es': 'Zapatos cómodos'}},
    stops: [
      {'order': 1, 'huecaId': 'h1', 'huecaName': 'Hornado Doña Rosita', 'sector': 'Centro Histórico'},
      {'order': 2, 'huecaId': 'h2', 'huecaName': 'Pailas de San Agustín', 'sector': 'Centro Histórico'},
    ],
  );

  testWidgets('AdminDashboardScreen renders KPIs, metrics and quick actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(450, 950));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allHuecasStreamProvider.overrideWith((ref) => Stream.value([dummyHueca1, dummyHueca2])),
          allUsersStreamProvider.overrideWith((ref) => Stream.value([dummyUser1, dummyUser2])),
          allRoutesStreamProvider.overrideWith((ref) => Stream.value([dummyRoute])),
          pendingNotificationsProvider.overrideWith((ref) => Stream.value([])),
          pendingHuecaRequestsProvider.overrideWith((ref) => Stream.value([])),
          newSupportMessagesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Centro de Control'), findsOneWidget);
    expect(find.text('Métricas Clave'), findsOneWidget);
    expect(find.text('Huecas'), findsOneWidget);
    expect(find.text('Usuarios'), findsOneWidget);
    expect(find.text('Sectores y Cromos'), findsNWidgets(2));
    expect(find.text('Nueva Hueca'), findsOneWidget);
    expect(find.text('Solicitudes Huecas'), findsNWidgets(2));
    expect(find.text('¡No hay avisos pendientes!'), findsOneWidget);
  });

  testWidgets('AdminHuecasScreen renders filters, search and cards with switches', (tester) async {
    await tester.binding.setSurfaceSize(const Size(450, 950));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allHuecasStreamProvider.overrideWith((ref) => Stream.value([dummyHueca1, dummyHueca2])),
        ],
        child: const MaterialApp(
          home: AdminHuecasScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Todas'), findsOneWidget);
    expect(find.text('Activas'), findsOneWidget);
    expect(find.text('Pausadas'), findsOneWidget);
    expect(find.text('Sin Dueño'), findsNWidgets(2)); // 1 en filtro chip, 1 en tarjeta sin dueño

    expect(find.text('Hornado Doña Rosita'), findsOneWidget);
    expect(find.text('Pailas de San Agustín'), findsOneWidget);
    expect(find.text('Dueño Asignado'), findsOneWidget);

    // Switches present for both
    expect(find.byType(Switch), findsNWidgets(2));
  });

  final dummyAdmin = UserModel(
    uid: 'u3',
    name: 'Admin Master',
    email: 'admin@huequito.com',
    profilePicUrl: '',
    gamification: {},
    preferences: {},
    sectorAlbums: [],
    role: 'admin',
  );

  testWidgets('AdminUsersScreen renders user roles, badges and edit action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(450, 950));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allUsersStreamProvider.overrideWith((ref) => Stream.value([dummyUser1, dummyUser2, dummyAdmin])),
          allHuecasStreamProvider.overrideWith((ref) => Stream.value([dummyHueca1])),
        ],
        child: const MaterialApp(
          home: AdminUsersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // dummyUser1 es cliente regular ('user'): DEBE SER EXCLUIDO ("gente x de la app")
    expect(find.text('Juan Perez'), findsNothing);
    expect(find.text('CLIENTE'), findsNothing);

    // dummyUser2 es dueño de negocio ('business'): DEBE MOSTRARSE
    expect(find.text('Rosita Dueña'), findsOneWidget);
    expect(find.text('NEGOCIO'), findsOneWidget);
    expect(find.text('Hueca: Hornado Doña Rosita'), findsOneWidget);

    // dummyAdmin es administrador ('admin'): DEBE MOSTRARSE
    expect(find.text('Admin Master'), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);

    expect(find.text('Crear Cuenta de Negocio'), findsOneWidget);
    expect(find.byIcon(Icons.edit_note), findsNWidgets(2));

    // Tap on Crear Cuenta de Negocio to verify creation dialog
    await tester.tap(find.text('Crear Cuenta de Negocio'));
    await tester.pumpAndSettle();

    expect(find.text('Nombre del Dueño o Representante *'), findsOneWidget);
    expect(find.text('Correo Electrónico *'), findsOneWidget);
    expect(find.text('Definición de contraseña por correo'), findsOneWidget);
    expect(find.text('Asignar a Hueca (Solo 1 hueca):'), findsOneWidget);
    expect(find.text('Cada cuenta de negocio solo puede estar asignada a 1 hueca.'), findsOneWidget);

    // Close dialog
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Verificar que existe botón de eliminar para cada usuario de negocio
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

    // Abrir diálogo de eliminación de usuario
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Eliminar Cuenta'), findsOneWidget);
    expect(find.text('La Hueca NO será eliminada'), findsOneWidget);
    expect(find.textContaining('permanecerá intacta en la plataforma'), findsOneWidget);
    expect(find.textContaining('Escribe "ELIMINAR" abajo para confirmar:'), findsOneWidget);

    // Cancelar diálogo
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets('AdminRoutesScreen renders route card with stops and metrics', (tester) async {
    await tester.binding.setSurfaceSize(const Size(450, 950));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allRoutesStreamProvider.overrideWith((ref) => Stream.value([dummyRoute])),
        ],
        child: const MaterialApp(
          home: AdminRoutesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ruta del Hornado y Tradición'), findsOneWidget);
    expect(find.text('2 paradas'), findsOneWidget);
    expect(find.text('3.2 km'), findsOneWidget);
    expect(find.text('2 horas'), findsOneWidget);
  });

  testWidgets('AdminRouteEditScreen renders bilingual fields, translation banner and buttons', (tester) async {
    await tester.binding.setSurfaceSize(const Size(450, 950));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allHuecasStreamProvider.overrideWith((ref) => Stream.value([dummyHueca1, dummyHueca2])),
        ],
        child: const MaterialApp(
          home: AdminRouteEditScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Nueva Ruta Gastronómica'), findsOneWidget);
    expect(find.text('Traducción Automática Multilingüe'), findsOneWidget);
    expect(find.text('✨ Traducir Todo al Inglés'), findsOneWidget);
    expect(find.text('Nombre de la Ruta (Español) *'), findsOneWidget);
    expect(find.text('Nombre en Inglés (Traducción)'), findsOneWidget);
    expect(find.text('Historia o descripción (Español) *'), findsOneWidget);
    expect(find.text('Historia o descripción (Inglés)'), findsOneWidget);
    expect(find.text('Añadir Parada'), findsOneWidget);
    expect(find.text('Crear Ruta Gastronómica'), findsOneWidget);
  });
}
