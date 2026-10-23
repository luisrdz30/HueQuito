import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';

void main() {
  group('Business Section & Branch Logic Unit Tests', () {
    test('HuecaBranch correctly serializes to and from Map', () {
      final originalBranch = HuecaBranch(
        id: 'branch_floresta_01',
        name: 'Sucursal La Floresta',
        address: 'Av. Madrid y Coruña',
        sector: 'La Floresta',
        location: const GeoPoint(-0.2085, -78.4891),
        phone: '0987654321',
        schedule: {
          'lunes': '10:00 - 20:00',
          'martes': '10:00 - 20:00',
        },
        managerEmail: 'manager.floresta@huequito.ec',
        secretSticker: {
          'id': 'cromo_floresta_01',
          'name': 'El Guagua de Pan',
          'imageUrl': 'https://example.com/sticker1.png',
        },
      );

      final map = originalBranch.toMap();
      expect(map['id'], equals('branch_floresta_01'));
      expect(map['name'], equals('Sucursal La Floresta'));
      expect(map['managerEmail'], equals('manager.floresta@huequito.ec'));
      expect(map['location'], isA<GeoPoint>());

      final restoredBranch = HuecaBranch.fromMap(map);
      expect(restoredBranch.id, equals(originalBranch.id));
      expect(restoredBranch.name, equals(originalBranch.name));
      expect(restoredBranch.address, equals(originalBranch.address));
      expect(restoredBranch.sector, equals(originalBranch.sector));
      expect(restoredBranch.phone, equals(originalBranch.phone));
      expect(restoredBranch.managerEmail, equals(originalBranch.managerEmail));
      expect(restoredBranch.secretSticker?['id'], equals('cromo_floresta_01'));
    });

    test('Hueca.allBranches defaults to a Matriz Principal branch when no branches are defined', () {
      final hueca = Hueca(
        id: 'hueca_simple',
        name: 'Secos de la Ronda',
        description: {'es': 'Tradicional', 'en': 'Traditional'},
        address: 'Calle La Ronda 456',
        sector: 'Centro Histórico',
        location: const GeoPoint(-0.222, -78.514),
        phone: '022987654',
        schedule: {'todos': '08:00 - 18:00'},
        mainDish: {'name': 'Seco de pollo'},
        loyaltyCard: {'maxStamps': 5},
        secretSticker: {'id': 'ronda_sticker', 'name': 'Cromo Ronda'},
        menuItems: [],
        tags: ['tradicional'],
        priceLevel: r'$',
        rating: 4.6,
        reviewCount: 15,
        images: ['https://example.com/ronda.jpg'],
        ownerId: 'owner_ronda',
        isActive: true,
        metrics: {},
        branches: const [], // Empty branches list
      );

      final all = hueca.allBranches;
      expect(all.length, equals(1));
      expect(all.first.id, equals('matriz'));
      expect(all.first.name, equals('Matriz Principal'));
      expect(all.first.address, equals(hueca.address));
      expect(all.first.sector, equals(hueca.sector));
      expect(all.first.secretSticker?['id'], equals('ronda_sticker'));
    });

    test('Business and Manager role authorization check accurately matches owner and branch manager emails', () {
      final branches = [
        HuecaBranch(
          id: 'b1',
          name: 'Sucursal 1',
          address: 'Dir 1',
          sector: 'Norte',
          location: const GeoPoint(0, 0),
          phone: '',
          schedule: {},
          managerEmail: 'BranchManager@GMAIL.COM', // uppercase to test case insensitivity
        ),
      ];

      bool checkIsBusinessOrManager({
        required String userUid,
        required String userEmail,
        required String ownerId,
        required List<HuecaBranch> huecaBranches,
      }) {
        if (ownerId == userUid) return true;
        final normalizedUserEmail = userEmail.trim().toLowerCase();
        for (final b in huecaBranches) {
          if (b.managerEmail != null &&
              b.managerEmail!.trim().toLowerCase() == normalizedUserEmail) {
            return true;
          }
        }
        return false;
      }

      // 1. Dueño general
      expect(
        checkIsBusinessOrManager(
          userUid: 'owner_123',
          userEmail: 'random@test.com',
          ownerId: 'owner_123',
          huecaBranches: branches,
        ),
        isTrue,
      );

      // 2. Administrador de sucursal con correo en minúsculas
      expect(
        checkIsBusinessOrManager(
          userUid: 'manager_uid',
          userEmail: 'branchmanager@gmail.com',
          ownerId: 'owner_123',
          huecaBranches: branches,
        ),
        isTrue,
      );

      // 3. Usuario ajeno no autorizado
      expect(
        checkIsBusinessOrManager(
          userUid: 'unrelated_uid',
          userEmail: 'otro.cliente@gmail.com',
          ownerId: 'owner_123',
          huecaBranches: branches,
        ),
        isFalse,
      );
    });
  });

  group('QR Code Generation and Validation Unit Tests', () {
    test('Points QR payload is generated with correct schema and validates', () {
      final qrData = {
        'type': 'points',
        'business_id': 'hueca_789',
        'points': 1,
        'branch_id': 'branch_01',
        'branch_name': 'Sucursal Cumbayá',
        'created_at': DateTime.now().toIso8601String(),
      };

      final jsonString = jsonEncode(qrData);
      expect(jsonString, isNotEmpty);

      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(decoded['type'], equals('points'));
      expect(decoded['business_id'], equals('hueca_789'));
      expect(decoded['points'], equals(1));
      expect(decoded['branch_id'], equals('branch_01'));
      expect(decoded['branch_name'], equals('Sucursal Cumbayá'));
    });

    test('Secret Sticker QR payload validates correctly with bonus points rules', () {
      final qrData = {
        'type': 'secret_sticker',
        'business_id': 'hueca_456',
        'branch_id': 'matriz',
        'branch_name': 'Matriz Principal',
        'sticker_name': 'Sticker Secreto Monumento',
        'cromo_id': 'cromo_monumento_456',
      };

      final jsonString = jsonEncode(qrData);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['type'], isIn(['secret_sticker', 'cromo']));
      expect(decoded['business_id'], equals('hueca_456'));
      expect(decoded['sticker_name'], isNotEmpty);

      // Unique sticker key rule
      final stickerKey = '${decoded['business_id']}_${decoded['branch_id']}';
      expect(stickerKey, equals('hueca_456_matriz'));
    });

    test('Malformed or legacy raw QR codes are safely rejected without throwing exceptions', () {
      bool isValidHueQuitoQR(String raw) {
        try {
          final data = jsonDecode(raw);
          if (data is Map<String, dynamic>) {
            final type = data['type']?.toString();
            return type == 'points' || type == 'secret_sticker' || type == 'cromo';
          }
        } catch (_) {}
        return false;
      }

      expect(isValidHueQuitoQR('https://google.com'), isFalse);
      expect(isValidHueQuitoQR('PLAIN_TEXT_BARCODE'), isFalse);
      expect(isValidHueQuitoQR('{broken_json: true}'), isFalse);
      expect(isValidHueQuitoQR('{"type": "points", "business_id": "1"}'), isTrue);
      expect(isValidHueQuitoQR('{"type": "secret_sticker", "business_id": "1"}'), isTrue);
    });
  });
}
