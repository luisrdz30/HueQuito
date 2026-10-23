import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/models/gastronomic_profile.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/subscription_repository.dart';
import 'package:hue_quito/screens/admin/admin_subscriptions_screen.dart';

Hueca _createMockHueca({
  required String id,
  required String name,
  required int stamps,
  String status = 'free_tier',
}) {
  return Hueca(
    id: id,
    name: name,
    description: {'es': 'Hueca de prueba'},
    address: 'Quito Centro',
    sector: 'Centro Histórico',
    location: const GeoPoint(-0.22, -78.51),
    phone: '0999999999',
    schedule: {},
    mainDish: {},
    loyaltyCard: {'maxStamps': 10},
    secretSticker: {},
    menuItems: [],
    tags: ['tradicional'],
    priceLevel: r'$',
    rating: 4.8,
    reviewCount: 10,
    images: [],
    ownerId: 'owner_$id',
    isActive: true,
    isSectorConfirmed: true,
    metrics: {'stampsGiven': stamps},
    subscription: {
      'status': status,
      'lastReceipt': {
        'amount': 4.99,
        'referenceNumber': 'TRX-12345',
        'imageUrl': '',
      },
    },
  );
}

void main() {
  testWidgets('AdminSubscriptionsScreen renders in a compact screen (360x640) without any overflow', (tester) async {
    // Set smaller screen size to rigorously test that neither right nor bottom overflows occur
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockHuecas = [
      _createMockHueca(id: 'h1', name: 'Motes San Juan', stamps: 48, status: 'under_review'),
      _createMockHueca(id: 'h2', name: 'Seco de Chivo', stamps: 52, status: 'active'),
      _createMockHueca(id: 'h3', name: 'Empanadas Centro', stamps: 10, status: 'free_tier'),
    ];

    const mockSettings = SubscriptionSettings(
      monthlyPrice: 4.99,
      freeTierMaxStamps: 50,
      gracePeriodDays: 7,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionSettingsProvider.overrideWith((ref) => Stream.value(mockSettings)),
          huecasProvider.overrideWith((ref) => Future.value(mockHuecas)),
          allHuecasStreamProvider.overrideWith((ref) => Stream.value(mockHuecas)),
        ],
        child: const MaterialApp(
          home: AdminSubscriptionsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Header and title
    expect(find.text('Suscripciones y Pagos'), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);

    // 2. Verify Metric summary pills are present
    expect(find.text('Cerca a Cobro'), findsOneWidget);
    expect(find.text('Meta Alcanzada'), findsOneWidget);
    expect(find.text('En Prueba'), findsOneWidget);

    // 3. Verify Tarifas card is present
    expect(find.text('Tarifas y Datos Bancarios'), findsOneWidget);

    // 4. Verify huecas in the chart
    expect(find.textContaining('Motes San Juan'), findsOneWidget);

    // 5. Scroll down to bring TabBar into view if needed
    final scrollableFinder = find.byType(Scrollable).first;
    await tester.drag(scrollableFinder, const Offset(0, -300));
    await tester.pumpAndSettle();

    // 6. Verify Tab labels rendered
    expect(find.text('Por Validar', skipOffstage: false), findsWidgets);
    expect(find.text('Al Día', skipOffstage: false), findsWidgets);
    expect(find.text('En Gracia / Corte', skipOffstage: false), findsWidgets);

    // 7. Verify zero RenderFlex overflow exceptions were caught
    expect(tester.takeException(), isNull);
  });
}
