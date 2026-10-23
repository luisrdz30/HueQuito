import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';

void main() {
  group('Client Gamification & Guest Storage Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getGuestGamification returns safe initial defaults when storage is empty', () async {
      final data = await UserRepository.getGuestGamification();

      expect(data['points'], equals(0));
      expect(data['totalStamps'], equals(0));
      expect(data['level'], equals(1));
      expect(data['title'], equals('Explorador'));
      expect(data['huecaStamps'], isEmpty);
      expect(data['collectedStickers'], isEmpty);
    });

    test('saveGuestGamification and getGuestGamification persist and retrieve correctly', () async {
      final testData = {
        'points': 150,
        'totalStamps': 5,
        'level': 2,
        'title': 'Gourmet',
        'huecaStamps': {
          'hueca_centro_1': 3,
          'hueca_floresta_2': 2,
        },
        'collectedStickers': ['hueca_centro_1_matriz', 'hueca_floresta_2_sucursal1'],
      };

      await UserRepository.saveGuestGamification(testData);

      final retrieved = await UserRepository.getGuestGamification();
      expect(retrieved['points'], equals(150));
      expect(retrieved['totalStamps'], equals(5));
      expect(retrieved['level'], equals(2));
      expect(retrieved['title'], equals('Gourmet'));

      final stamps = Map<String, dynamic>.from(retrieved['huecaStamps'] as Map);
      expect(stamps['hueca_centro_1'], equals(3));
      expect(stamps['hueca_floresta_2'], equals(2));

      final stickers = List<String>.from(retrieved['collectedStickers'] as List);
      expect(stickers, contains('hueca_centro_1_matriz'));
      expect(stickers, contains('hueca_floresta_2_sucursal1'));
    });

    test('getGuestGamification gracefully recovers from corrupt JSON data in storage', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guest_gamification', 'INVALID_CORRUPT_JSON{{{');

      final fallback = await UserRepository.getGuestGamification();
      expect(fallback['points'], equals(0));
      expect(fallback['totalStamps'], equals(0));
      expect(fallback['huecaStamps'], isEmpty);
      expect(fallback['collectedStickers'], isEmpty);
    });

    test('Guest sticker collection handles uniqueness correctly without duplicate keys', () async {
      final initial = await UserRepository.getGuestGamification();
      List<dynamic> collected = List.from(initial['collectedStickers'] ?? []);

      const stickerKey = 'hueca_123_matriz';
      if (!collected.contains(stickerKey)) {
        collected.add(stickerKey);
      }
      // Simulate scanning the same secret QR a second time
      if (!collected.contains(stickerKey)) {
        collected.add(stickerKey);
      }

      initial['collectedStickers'] = collected;
      await UserRepository.saveGuestGamification(initial);

      final saved = await UserRepository.getGuestGamification();
      final savedStickers = List<String>.from(saved['collectedStickers'] as List);
      expect(savedStickers.length, equals(1));
      expect(savedStickers.first, equals('hueca_123_matriz'));
    });
  });

  group('Album and Card Calculation Unit Tests', () {
    Hueca createSampleHueca({
      required String id,
      required String name,
      required String sector,
      int maxStamps = 5,
      dynamic rewardText = 'Empanada gratis',
      Map<String, dynamic>? secretSticker,
    }) {
      return Hueca(
        id: id,
        name: name,
        description: {'es': 'Descripción $name', 'en': 'Description $name'},
        address: 'Calle Ficticia 123',
        sector: sector,
        location: const GeoPoint(-0.22, -78.51),
        phone: '0991234567',
        schedule: {'lunes': '09:00 - 18:00'},
        mainDish: {'name': 'Plato típico', 'category': 'Tradicional'},
        loyaltyCard: {
          'maxStamps': maxStamps,
          'rewardText': rewardText,
          'image': 'https://example.com/stamp.png',
        },
        secretSticker: secretSticker ?? {
          'id': '${id}_cromo',
          'name': {'es': 'Cromo de $name', 'en': 'Sticker of $name'},
          'imageUrl': 'https://example.com/sticker.png',
        },
        menuItems: [],
        tags: ['típica', 'quiteña'],
        priceLevel: r'$$',
        rating: 4.8,
        reviewCount: 25,
        images: ['https://example.com/photo1.jpg'],
        ownerId: 'owner_1',
        isActive: true,
        metrics: {'stampsGiven': 10},
      );
    }

    test('Card completion calculation detects completed and pending cards correctly', () {
      final hueca = createSampleHueca(id: 'h1', name: 'Las Corvinas', sector: 'Centro Histórico', maxStamps: 5);

      int currentStamps1 = 3;
      int targetStamps = hueca.loyaltyCard['maxStamps'] as int;
      bool isCompleted1 = currentStamps1 >= targetStamps;
      expect(isCompleted1, isFalse);

      int currentStamps2 = 5;
      bool isCompleted2 = currentStamps2 >= targetStamps;
      expect(isCompleted2, isTrue);

      int currentStampsOver = 7;
      bool isCompletedOver = currentStampsOver >= targetStamps;
      expect(isCompletedOver, isTrue);
    });

    test('Reward text extraction properly resolves Map and String variations in bilingual modes', () {
      final huecaWithStringReward = createSampleHueca(
        id: 'h2',
        name: 'Mote Colonial',
        sector: 'Centro Histórico',
        rewardText: 'Mote con chicharrón de cortesía',
      );

      final huecaWithMapReward = createSampleHueca(
        id: 'h3',
        name: 'Secos de la Floresta',
        sector: 'La Floresta',
        rewardText: {
          'es': 'Seco de chivo gratis',
          'en': 'Free goat stew',
        },
      );

      String getReward(Hueca h, String lang) {
        if (h.loyaltyCard['rewardText'] is Map) {
          return h.loyaltyCard['rewardText'][lang]?.toString() ??
              h.loyaltyCard['rewardText']['es']?.toString() ??
              '';
        } else if (h.loyaltyCard['rewardText'] != null) {
          return h.loyaltyCard['rewardText'].toString();
        }
        return lang == 'es' ? 'Recompensa sorpresa' : 'Surprise reward';
      }

      expect(getReward(huecaWithStringReward, 'es'), equals('Mote con chicharrón de cortesía'));
      expect(getReward(huecaWithStringReward, 'en'), equals('Mote con chicharrón de cortesía'));

      expect(getReward(huecaWithMapReward, 'es'), equals('Seco de chivo gratis'));
      expect(getReward(huecaWithMapReward, 'en'), equals('Free goat stew'));
    });

    test('Sector grouping groups multiple huecas into sorted sector collections', () {
      final huecas = [
        createSampleHueca(id: '1', name: 'Hueca A', sector: 'La Floresta'),
        createSampleHueca(id: '2', name: 'Hueca B', sector: 'Centro Histórico'),
        createSampleHueca(id: '3', name: 'Hueca C', sector: 'La Floresta'),
        createSampleHueca(id: '4', name: 'Hueca D', sector: 'Cumbayá'),
        createSampleHueca(id: '5', name: 'Hueca E', sector: ''), // Fallback sector
      ];

      final Map<String, List<Hueca>> sectorsMap = {};
      for (final h in huecas) {
        final rawSector = h.sector.trim();
        final sectorName = rawSector.isNotEmpty && rawSector != 'Todo Quito'
            ? rawSector
            : 'Centro Histórico';
        sectorsMap.putIfAbsent(sectorName, () => []).add(h);
      }

      final sortedKeys = sectorsMap.keys.toList()..sort();

      expect(sortedKeys, equals(['Centro Histórico', 'Cumbayá', 'La Floresta']));
      expect(sectorsMap['Centro Histórico']!.length, equals(2)); // Hueca B + Hueca E fallback
      expect(sectorsMap['La Floresta']!.length, equals(2));
      expect(sectorsMap['Cumbayá']!.length, equals(1));
    });

    test('Sticker unlock check detects unlock across matriz, branch, and sticker id keys', () {
      final hueca = createSampleHueca(
        id: 'h_special',
        name: 'Café San Agustín',
        sector: 'Centro Histórico',
        secretSticker: {'id': 'custom_sticker_id_999'},
      );

      bool isUnlocked(Hueca h, List<String> collected) {
        final stickerId = h.secretSticker['id']?.toString() ?? '';
        final matrizKey = '${h.id}_matriz';
        if (collected.contains(h.id) ||
            collected.contains(matrizKey) ||
            (stickerId.isNotEmpty && collected.contains(stickerId))) {
          return true;
        }
        for (final b in h.branches) {
          if (collected.contains('${h.id}_${b.id}')) return true;
        }
        return false;
      }

      // Empty collection -> locked
      expect(isUnlocked(hueca, []), isFalse);

      // Unlocked via direct hueca ID
      expect(isUnlocked(hueca, ['h_special']), isTrue);

      // Unlocked via matriz key
      expect(isUnlocked(hueca, ['h_special_matriz']), isTrue);

      // Unlocked via custom sticker id
      expect(isUnlocked(hueca, ['custom_sticker_id_999']), isTrue);

      // Different key -> still locked
      expect(isUnlocked(hueca, ['other_hueca_matriz']), isFalse);
    });
  });
}
