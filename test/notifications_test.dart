import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/models/notification_model.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
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

      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.text('Solicitar Notificación'), findsOneWidget);
      expect(find.text('Historial y Estados'), findsOneWidget);
      expect(find.text('Tiempo de Aprobación: 2 horas a 1 día'), findsOneWidget);
      expect(find.text('Categoría del Anuncio'), findsOneWidget);
      expect(find.text('🏷️ Promoción'), findsOneWidget);
      expect(find.text('📢 Noticia'), findsOneWidget);
      expect(find.text('🍲 Nuevo Plato'), findsOneWidget);
      expect(find.text('📅 Evento'), findsOneWidget);
      expect(find.text('Ayuda con IA ✨'), findsOneWidget);
      expect(find.text('¿Cuándo quieres que salga la notificación?'), findsOneWidget);
      expect(find.text('Inmediata'), findsOneWidget);
      expect(find.text('Programada'), findsOneWidget);
      expect(find.text('Vista Previa en el Celular'), findsOneWidget);
      expect(find.text('Solicitar Autorización de Notificación'), findsOneWidget);
    });

    testWidgets('BusinessNotificationScreen opens Menu del Dia modal with scheduling controls', (tester) async {
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

      final openBtn = find.text('Armar o Programar Menú del Día');
      expect(openBtn, findsOneWidget);
      await tester.tap(openBtn);
      await tester.pumpAndSettle();

      expect(find.text('Menú del Día'), findsWidgets);
      expect(find.text('🍲 Sopa'), findsOneWidget);
      expect(find.text('🍛 Segundo (Plato Fuerte)'), findsOneWidget);
      expect(find.text('⏰ ¿Cuándo deseas publicar este menú?'), findsOneWidget);
      expect(find.text('Inmediato'), findsOneWidget);
      expect(find.text('Programar'), findsOneWidget);
      expect(find.text('Confirmar y Ver Vista Previa'), findsOneWidget);
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
  });
}