import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/models/notification_model.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/notification_repository.dart';
import 'package:hue_quito/screens/business/notification_management_screen.dart';
import 'package:hue_quito/screens/admin/admin_notifications_screen.dart';
import 'package:hue_quito/screens/hueca_detail_screen.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/services/ai_generation_service.dart';
import 'package:hue_quito/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Notification System - Model & Serialization Tests', () {
    test('NotificationModel serializes and deserializes accurately with scheduledFor', () {
      final now = DateTime.now();
      final futureDate = now.add(const Duration(days: 2));
      final model = NotificationModel(
        id: 'notif_1',
        huecaId: 'hueca_123',
        huecaName: 'Secos de la Ronda',
        branchId: 'branch_valle',
        branchName: 'Sucursal Valle',
        category: 'promocion',
        title: '¡2x1 en Seco de Chivo!',
        message: 'Aprovecha este fin de semana en nuestra sucursal del Valle.',
        discountTag: '2x1',
        status: 'pending',
        createdAt: now,
        scheduledFor: futureDate,
        createdBy: 'user_owner',
      );

      expect(model.categoryDisplay, 'Promoción');
      expect(model.categoryEmoji, '🏷️');
      expect(model.isScheduled, isTrue);
      expect(model.formattedScheduledDate, isNotNull);

      final map = model.toMap();
      expect(map['huecaId'], 'hueca_123');
      expect(map['category'], 'promocion');
      expect(map['discountTag'], '2x1');
      expect(map['status'], 'pending');
      expect(map['scheduledFor'], isNotNull);
    });

    test('AiGenerationService generates compelling gastronomic copies', () {
      final options = AiGenerationService.generateCopyOptions(
        title: '2x1 en Fritada Quiteña',
        huecaName: 'Hueca Doña Tina',
        category: 'promocion',
        discountTag: '2x1',
      );

      expect(options.length, greaterThanOrEqualTo(3));
      for (final opt in options) {
        expect(opt.isNotEmpty, isTrue);
        expect(opt.contains('Hueca Doña Tina') || opt.contains('Fritada'), isTrue);
      }
    });

    test('UserModel supports subscribedHuecas list correctly', () {
      final user = UserModel(
        uid: 'user_comensal',
        name: 'Carlos Comensal',
        email: 'carlos@test.com',
        profilePicUrl: '',
        gamification: {},
        preferences: {},
        sectorAlbums: [],
        favoriteHuecas: ['hueca_1'],
        subscribedHuecas: ['hueca_1', 'hueca_2'],
        role: 'user',
      );

      expect(user.subscribedHuecas.length, 2);
      expect(user.subscribedHuecas.contains('hueca_1'), isTrue);
      expect(user.subscribedHuecas.contains('hueca_3'), isFalse);
    });

    test('NotificationService tracks shown notifications and prevents duplicates', () async {
      SharedPreferences.setMockInitialValues({'shown_notification_ids': ['notif_existing']});
      final service = NotificationService();
      await service.initialize();

      expect(service.hasBeenShown('notif_existing'), isTrue);
      expect(service.hasBeenShown('notif_new'), isFalse);

      await service.markAsSilentlyProcessed('notif_new');
      expect(service.hasBeenShown('notif_new'), isTrue);

      // Calling again remains marked and idempotent
      await service.markAsSilentlyProcessed('notif_new');
      expect(service.hasBeenShown('notif_new'), isTrue);
    });
  });

  group('Límite de avisos por día de publicación', () {
    test('un aviso programado cuenta para el día en que sale, no para hoy', () {
      final now = DateTime.now();
      final hoy = NotificationRepository.dayInQuito(now);
      final manana = now.add(const Duration(days: 1));
      final used = NotificationRepository.usedByDay({'days': {hoy: 2}});

      expect(NotificationRepository.remainingFor(used, null), 0); // hoy está lleno
      expect(NotificationRepository.remainingFor(used, manana), 2); // mañana sigue libre
    });

    test('lee el formato anterior del contador {day, count}', () {
      final hoy = NotificationRepository.todayInQuito();
      final used = NotificationRepository.usedByDay({'day': hoy, 'count': 1});
      expect(NotificationRepository.remainingFor(used, null), 1);
    });

    test('el mensaje del límite indica el día afectado', () {
      final hoy = NotificationRepository.todayInQuito();
      expect(DailyNoticeLimitException(hoy).toString(), contains('hoy'));
      expect(DailyNoticeLimitException('2030-01-05').toString(), contains('05/01/2030'));
    });
  });

  group('Notification System - UI Widget Tests', () {
    final testHueca = Hueca(
      id: 'h1',
      name: 'Las Corvinas de Don Jimmy',
      description: {'es': 'Tradicionales corvinas fritas.'},
      address: 'Mercado Central',
      sector: 'Centro Histórico',
      location: const GeoPoint(-0.2195, -78.5085),
      phone: '0991234567',
      schedule: {'Lunes - Domingo': '08:00 - 17:00'},
      mainDish: {'name': 'Corvina Frita', 'price': 5.50, 'emoji': '🐟'},
      loyaltyCard: {},
      metrics: {'viewCount': 100, 'favoriteCount': 20},
      secretSticker: {},
      menuItems: [],
      tags: ['Pescado', 'Frituras'],
      priceLevel: '\$',
      rating: 4.8,
      reviewCount: 45,
      images: ['https://images.unsplash.com/photo-1544025162-d76694265947'],
      ownerId: 'owner_1',
      isActive: true,
      branches: [
        HuecaBranch(
          id: 'branch_valle',
          name: 'Sucursal Valle',
          address: 'Av. Ilaló',
          sector: 'Valle de los Chillos',
          location: const GeoPoint(-0.3012, -78.4412),
          phone: '0987654321',
          schedule: {'Lunes': 'Cerrado'},
        ),
      ],
    );

    testWidgets('BusinessNotificationScreen renders form, categories and preview', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myHuecaProvider.overrideWith((ref) => Future.value(testHueca)),
            currentManagedBranchProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: const MaterialApp(
            home: BusinessNotificationScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Avisos'), findsOneWidget);
      expect(find.text('Nuevo aviso'), findsOneWidget);
      expect(find.text('Mis avisos'), findsOneWidget);
      expect(find.text('Te quedan 2 de 2 avisos hoy'), findsOneWidget);
      expect(find.text('¿Qué quieres avisar?'), findsOneWidget);
      expect(find.text('Menú del Día'), findsOneWidget);
      expect(find.text('Promoción'), findsOneWidget);
      expect(find.text('Noticia'), findsOneWidget);
      expect(find.text('Nuevo Plato'), findsOneWidget);
      expect(find.text('Evento'), findsOneWidget);
      // El menú del día se escribe con la sopa y el segundo
      expect(find.text('🍲 Sopa'), findsOneWidget);
      expect(find.text('🍛 Segundo'), findsOneWidget);
      expect(find.text('¿Cuándo sale?'), findsOneWidget);
      expect(find.text('Ahora'), findsOneWidget);
      expect(find.text('Programar'), findsOneWidget);
      expect(find.text('Así lo verán tus clientes'), findsOneWidget);
      expect(find.text('Publicar ahora'), findsOneWidget);

      // Las demás categorías usan título, mensaje y la ayuda con IA
      await tester.tap(find.text('Promoción'));
      await tester.pumpAndSettle();
      expect(find.text('Título'), findsOneWidget);
      expect(find.text('Ayuda con IA ✨'), findsOneWidget);
    });

    testWidgets('BusinessNotificationScreen programa un aviso eligiendo día y hora', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1600));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myHuecaProvider.overrideWith((ref) => Future.value(testHueca)),
            currentManagedBranchProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: const MaterialApp(
            home: BusinessNotificationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Programar'));
      await tester.pumpAndSettle();

      expect(find.text('Día'), findsOneWidget);
      expect(find.text('Hora'), findsOneWidget);
      expect(find.text('Elegir'), findsNWidgets(2));
      // Sin fecha no se puede enviar todavía
      expect(find.text('Elige el día y la hora'), findsOneWidget);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('AdminNotificationsScreen renders moderation panel and empty state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingNotificationsProvider.overrideWith((ref) => Stream.value([])),
            allNotificationsProvider.overrideWith((ref) => Stream.value([])),
            pendingHuecaRequestsProvider.overrideWith((ref) => Stream.value([])),
            newSupportMessagesProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: AdminNotificationsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Moderación de Notificaciones'), findsOneWidget);
      expect(find.text('Pendientes'), findsOneWidget);
      expect(find.text('Historial Completo'), findsOneWidget);
      expect(find.text('Solicitudes'), findsOneWidget);
      expect(find.text('Soporte'), findsOneWidget);
      expect(find.text('¡Al día! No hay notificaciones pendientes.'), findsOneWidget);
    });

    testWidgets('HuecaDetailScreen renders subscription switch and bell action', (tester) async {
      final testUser = UserModel(
        uid: 'user_1',
        name: 'Maria',
        email: 'maria@test.com',
        profilePicUrl: '',
        gamification: {},
        preferences: {},
        sectorAlbums: [],
        favoriteHuecas: [],
        subscribedHuecas: ['h1'], // already subscribed
        role: 'user',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Future.value(testUser)),
          ],
          child: MaterialApp(
            home: HuecaDetailScreen(hueca: testHueca),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_active), findsWidgets);
      expect(find.text('Alertas'), findsOneWidget);
    });
    test('NotificationModel 4-hour validity and remaining time helpers', () {
      final now = DateTime.now();

      final recent = NotificationModel(
        id: 'n_recent',
        huecaId: 'h1',
        huecaName: 'Hueca Test',
        category: 'menu_del_dia',
        title: 'Menú de Hoy',
        message: 'Locro y Fritada',
        status: 'approved',
        createdAt: now.subtract(const Duration(minutes: 30)),
        approvedAt: now.subtract(const Duration(minutes: 30)),
        createdBy: 'uid_1',
      );
      expect(recent.isCurrentlyActive, isTrue);
      expect(recent.remainingMinutes, inInclusiveRange(200, 215));
      expect(recent.formattedTimeRemaining(lang: 'es'), contains('Quedan 3 h'));
      expect(recent.formattedAge(lang: 'es'), contains('Publicado hace 30 min'));

      final expired = NotificationModel(
        id: 'n_expired',
        huecaId: 'h1',
        huecaName: 'Hueca Test',
        category: 'menu_del_dia',
        title: 'Menú Pasado',
        message: 'Ayer',
        status: 'approved',
        createdAt: now.subtract(const Duration(hours: 5)),
        approvedAt: now.subtract(const Duration(hours: 5)),
        createdBy: 'uid_1',
      );
      expect(expired.isCurrentlyActive, isFalse);
      expect(expired.remainingMinutes, 0);

      final unapproved = NotificationModel(
        id: 'n_pending',
        huecaId: 'h1',
        huecaName: 'Hueca Test',
        category: 'promocion',
        title: 'Promo',
        message: 'Pendiente',
        status: 'pending',
        createdAt: now,
        createdBy: 'uid_1',
      );
      expect(unapproved.isCurrentlyActive, isFalse);
    });

    test('NotificationModel handles scheduled menu del dia dormancy and active window correctly', () {
      final now = DateTime.now();
      final futureMenu = NotificationModel(
        id: 'n_future_menu',
        huecaId: 'h1',
        huecaName: 'Hueca Test',
        category: 'menu_del_dia',
        title: 'Menú Programado de Mañana',
        message: 'Locro y Seco',
        status: 'approved',
        createdAt: now,
        approvedAt: now,
        scheduledFor: now.add(const Duration(hours: 3)),
        createdBy: 'uid_1',
      );
      // Dormant until scheduled time
      expect(futureMenu.isScheduled, isTrue);
      expect(futureMenu.isCurrentlyActive, isFalse);
      expect(futureMenu.formattedScheduledDate, isNotNull);

      // Once reached
      final activeScheduledMenu = NotificationModel(
        id: 'n_active_scheduled',
        huecaId: 'h1',
        huecaName: 'Hueca Test',
        category: 'menu_del_dia',
        title: 'Menú Programado Activo',
        message: 'Locro y Seco',
        status: 'approved',
        createdAt: now.subtract(const Duration(hours: 2)),
        approvedAt: now.subtract(const Duration(hours: 2)),
        scheduledFor: now.subtract(const Duration(minutes: 30)),
        createdBy: 'uid_1',
      );
      expect(activeScheduledMenu.isScheduled, isFalse);
      expect(activeScheduledMenu.isCurrentlyActive, isTrue);
      expect(activeScheduledMenu.remainingMinutes, inInclusiveRange(200, 215));
    });

    testWidgets('HuecaDetailScreen renders active 4-hour notification / menu del dia when present', (tester) async {
      final testUser = UserModel(
        uid: 'user_1',
        name: 'Maria',
        email: 'maria@test.com',
        profilePicUrl: '',
        gamification: {},
        preferences: {},
        sectorAlbums: [],
        favoriteHuecas: [],
        subscribedHuecas: ['h1'],
        role: 'user',
      );

      final activeNotif = NotificationModel(
        id: 'notif_active_1',
        huecaId: testHueca.id,
        huecaName: testHueca.name,
        category: 'menu_del_dia',
        title: 'Menú del Día de Doña Tina',
        message: '🍲 Sopa: Locro de Papa\n🍛 Segundo: Seco de Chivo',
        discountTag: 'Almuerzo \$3.50',
        status: 'approved',
        createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
        approvedAt: DateTime.now().subtract(const Duration(minutes: 45)),
        createdBy: 'owner_1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Future.value(testUser)),
            activeHuecaNotificationsProvider(testHueca.id).overrideWith(
              (ref) => Stream.value([activeNotif]),
            ),
          ],
          child: MaterialApp(
            home: HuecaDetailScreen(hueca: testHueca),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AVISOS ACTIVOS / MENÚ DEL DÍA'), findsOneWidget);
      expect(find.text('Menú del Día de Doña Tina'), findsOneWidget);
      expect(find.text('🍲 Sopa: Locro de Papa\n🍛 Segundo: Seco de Chivo'), findsOneWidget);
      expect(find.text('Almuerzo \$3.50'), findsOneWidget);
      expect(find.text('Vigencia: 4 horas'), findsNothing);
    });

    testWidgets('HuecaDetailScreen hides active notification section when empty', (tester) async {
      final testUser = UserModel(
        uid: 'user_1',
        name: 'Maria',
        email: 'maria@test.com',
        profilePicUrl: '',
        gamification: {},
        preferences: {},
        sectorAlbums: [],
        favoriteHuecas: [],
        subscribedHuecas: ['h1'],
        role: 'user',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Future.value(testUser)),
            activeHuecaNotificationsProvider(testHueca.id).overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
          child: MaterialApp(
            home: HuecaDetailScreen(hueca: testHueca),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AVISOS ACTIVOS / MENÚ DEL DÍA'), findsNothing);
      expect(find.text('Menú del Día de Doña Tina'), findsNothing);
    });

    testWidgets('BusinessNotificationScreen bloquea los avisos de una hueca suspendida por falta de pago', (tester) async {
      final suspendida = Hueca(
        id: 'h_susp',
        name: 'Hueca Suspendida',
        description: {'es': 'Prueba'},
        address: 'Centro',
        sector: 'Centro Histórico',
        location: const GeoPoint(-0.2195, -78.5085),
        phone: '0991234567',
        schedule: {'Lunes': '08:00 - 17:00'},
        mainDish: {'name': 'Locro', 'price': 3.0, 'emoji': '🍲'},
        loyaltyCard: {},
        metrics: {'stampsGiven': 150},
        secretSticker: {},
        menuItems: [],
        tags: ['Sopas'],
        priceLevel: '\$',
        rating: 4.5,
        reviewCount: 10,
        images: [],
        ownerId: 'owner_1',
        isActive: true,
        subscription: {'status': 'suspended'},
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myHuecaProvider.overrideWith((ref) => Future.value(suspendida)),
            currentManagedBranchProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: const MaterialApp(home: BusinessNotificationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Avisos pausados'), findsOneWidget);
      expect(find.text('Publicar Aviso'), findsNothing);
    });
  });
}