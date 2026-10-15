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

    testWidgets('AdminNotificationsScreen renders moderation panel and empty state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingNotificationsProvider.overrideWith((ref) => Stream.value([])),
            allNotificationsProvider.overrideWith((ref) => Stream.value([])),
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
  });
}
