import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/subscription_repository.dart';
import 'package:hue_quito/repositories/user_repository.dart';

void main() {
  group('SubscriptionSettings Unit Tests', () {
    test('Default values match agreed specifications (\$9.99, 50 stamps, 7 days grace, Pichincha)', () {
      const settings = SubscriptionSettings();
      expect(settings.monthlyPrice, equals(9.99));
      expect(settings.freeTierMaxStamps, equals(50));
      expect(settings.gracePeriodDays, equals(7));
      expect(settings.bankName, equals('Banco Pichincha'));
      expect(settings.accountType, equals('Cuenta de ahorros'));
      expect(settings.accountNumber, equals('2209810135'));
      expect(settings.accountHolder, equals('Hue-Quito'));
    });

    test('Serialization toMap and fromMap works accurately', () {
      final custom = SubscriptionSettings.fromMap({
        'monthlyPrice': 12.50,
        'freeTierMaxStamps': 80,
        'gracePeriodDays': 10,
        'bankName': 'Banco Guayaquil',
        'accountType': 'Cuenta Corriente',
        'accountNumber': '99887766',
        'accountHolder': 'Fundación HueQuito',
        'identificationNumber': '1799999999001',
        'notificationEmail': 'admin@huequito.ec',
      });

      expect(custom.monthlyPrice, equals(12.50));
      expect(custom.freeTierMaxStamps, equals(80));
      expect(custom.gracePeriodDays, equals(10));
      expect(custom.bankName, equals('Banco Guayaquil'));

      final map = custom.toMap();
      expect(map['monthlyPrice'], equals(12.50));
      expect(map['freeTierMaxStamps'], equals(80));
      expect(map['gracePeriodDays'], equals(10));
      expect(map['accountNumber'], equals('99887766'));
    });
  });

  group('Subscription Lifecycle State Machine Tests', () {
    final subRepo = SubscriptionRepository();
    const settings = SubscriptionSettings(
      freeTierMaxStamps: 50,
      gracePeriodDays: 7,
      monthlyPrice: 9.99,
    );

    Hueca createHuecaWithMetrics({
      required int stampsGiven,
      Map<String, dynamic> subscription = const {},
      bool isActive = true,
    }) {
      return Hueca(
        id: 'hueca_test',
        name: 'Hueca de Prueba',
        description: {'es': 'Desc'},
        address: 'Quito',
        sector: 'Centro Histórico',
        location: const GeoPoint(0, 0),
        phone: '0999999999',
        schedule: {},
        mainDish: {},
        loyaltyCard: {'maxStamps': 10},
        secretSticker: {},
        menuItems: [],
        tags: [],
        priceLevel: r'$',
        rating: 5.0,
        reviewCount: 1,
        images: [],
        ownerId: 'owner_1',
        isActive: isActive,
        metrics: {'stampsGiven': stampsGiven},
        subscription: subscription,
      );
    }

    test('Hueca with < 50 stamps is in freeTier state', () {
      final hueca = createHuecaWithMetrics(stampsGiven: 35);
      final info = subRepo.evaluateHuecaSubscription(hueca: hueca, settings: settings);

      expect(info.state, equals(HuecaSubscriptionState.freeTier));
      expect(info.isFreeTier, isTrue);
      expect(info.needsPayment, isFalse);
      expect(info.isLocked, isFalse);
      expect(info.stampsGiven, equals(35));
      expect(info.maxFreeStamps, equals(50));
    });

    test('Hueca reaching 50 stamps enters gracePeriod with days countdown', () {
      final hueca = createHuecaWithMetrics(
        stampsGiven: 52,
        subscription: {
          'gracePeriodStartDate': DateTime.now().toIso8601String(),
        },
      );
      final info = subRepo.evaluateHuecaSubscription(hueca: hueca, settings: settings);

      expect(info.state, equals(HuecaSubscriptionState.gracePeriod));
      expect(info.needsPayment, isTrue);
      expect(info.isLocked, isFalse);
      expect(info.daysRemainingInGrace, greaterThan(0));
      expect(info.daysRemainingInGrace, lessThanOrEqualTo(7));
    });

    test('Hueca with expired grace period is suspended', () {
      final expiredStart = DateTime.now().subtract(const Duration(days: 8));
      final hueca = createHuecaWithMetrics(
        stampsGiven: 60,
        subscription: {
          'gracePeriodStartDate': expiredStart.toIso8601String(),
        },
      );
      final info = subRepo.evaluateHuecaSubscription(hueca: hueca, settings: settings);

      expect(info.state, equals(HuecaSubscriptionState.suspended));
      expect(info.isLocked, isTrue);
      expect(info.needsPayment, isTrue);
    });

    test('Hueca with uploaded receipt is underReview and not locked', () {
      final hueca = createHuecaWithMetrics(
        stampsGiven: 55,
        subscription: {
          'status': 'under_review',
          'lastReceipt': {
            'imageUrl': 'https://storage/receipt.jpg',
            'referenceNumber': 'TRF-123456',
            'amount': 9.99,
          },
        },
      );
      final info = subRepo.evaluateHuecaSubscription(hueca: hueca, settings: settings);

      expect(info.state, equals(HuecaSubscriptionState.underReview));
      expect(info.isUnderReview, isTrue);
      expect(info.isLocked, isFalse);
      expect(info.referenceNumber, equals('TRF-123456'));
    });

    test('Approved subscription is active with valid cutoff date', () {
      final nextCutoff = DateTime.now().add(const Duration(days: 25));
      final hueca = createHuecaWithMetrics(
        stampsGiven: 120,
        subscription: {
          'status': 'active',
          'nextCutoffDate': nextCutoff.toIso8601String(),
        },
      );
      final info = subRepo.evaluateHuecaSubscription(hueca: hueca, settings: settings);

      expect(info.state, equals(HuecaSubscriptionState.active));
      expect(info.isActive, isTrue);
      expect(info.isLocked, isFalse);
      expect(info.nextCutoffDate, isNotNull);
    });
  });

  group('Excess Stickers & Reward Claim Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Guest claiming reward preserves excess stamps (e.g. 13 stamps - 10 target = 3 remaining)', () async {
      final repo = UserRepository();

      // Setup initial guest data with 13 stamps (8 initial + 5 received)
      await UserRepository.saveGuestGamification({
        'points': 130,
        'totalStamps': 13,
        'huecaStamps': {
          'hueca_corvinas': 13,
        },
        'rewardsCount': 0,
      });

      // User claims reward for 10 stamps
      const targetStamps = 10;
      final remaining = await repo.claimHuecaReward(
        uid: 'guest',
        huecaId: 'hueca_corvinas',
        targetStamps: targetStamps,
        rewardText: 'Porción de corvina frita',
      );

      // Verify that instead of wiping to 0, 3 stamps remain
      expect(remaining, equals(3));

      final updated = await UserRepository.getGuestGamification();
      final stampsMap = Map<String, dynamic>.from(updated['huecaStamps'] as Map);
      expect(stampsMap['hueca_corvinas'], equals(3));
      expect(updated['rewardsCount'], equals(1));
    });

    test('Multiple rewards can be claimed if surplus is large (e.g. 23 stamps)', () async {
      final repo = UserRepository();

      await UserRepository.saveGuestGamification({
        'points': 230,
        'totalStamps': 23,
        'huecaStamps': {
          'hueca_motes': 23,
        },
        'rewardsCount': 0,
      });

      // First claim: 23 - 10 = 13
      final rem1 = await repo.claimHuecaReward(
        uid: 'guest',
        huecaId: 'hueca_motes',
        targetStamps: 10,
        rewardText: 'Mote gratis',
      );
      expect(rem1, equals(13));

      // Second claim: 13 - 10 = 3
      final rem2 = await repo.claimHuecaReward(
        uid: 'guest',
        huecaId: 'hueca_motes',
        targetStamps: 10,
        rewardText: 'Mote gratis',
      );
      expect(rem2, equals(3));

      final updated = await UserRepository.getGuestGamification();
      expect(updated['rewardsCount'], equals(2));
    });
  });
}
