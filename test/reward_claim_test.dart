import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hue_quito/repositories/reward_claim_repository.dart';
import 'package:hue_quito/repositories/user_repository.dart';

void main() {
  RewardClaim claim({String status = RewardClaim.pending, DateTime? created}) => RewardClaim.fromMap('c1', {
        'huecaId': 'h1',
        'huecaName': 'El Pretil',
        'userId': 'u1',
        'userName': 'Maria',
        'rewardText': 'Café gratis',
        'stampsRequired': 5,
        'status': status,
        'createdAt': Timestamp.fromDate(created ?? DateTime.now()),
      });

  group('QR de canje de premios', () {
    test('El QR generado se reconoce como premio y devuelve su id', () {
      expect(RewardClaim.parseQr(claim().qrData), 'c1');
    });

    test('Rechaza los QR de sellos, de cromos y los textos cualquiera', () {
      expect(RewardClaim.parseQr('{"type":"points","token":"abc","points":3}'), isNull);
      expect(RewardClaim.parseQr('{"type":"cromo","cromo_id":"x"}'), isNull);
      expect(RewardClaim.parseQr('{"type":"reward"}'), isNull);
      expect(RewardClaim.parseQr('https://ejemplo.com'), isNull);
    });

    test('Solo se puede confirmar si está pendiente y no venció (10 minutos)', () {
      expect(claim().canBeConfirmed, isTrue);
      expect(claim(created: DateTime.now().subtract(const Duration(minutes: 11))).canBeConfirmed, isFalse);
      expect(claim(status: RewardClaim.redeemed).canBeConfirmed, isFalse);
      expect(claim(status: RewardClaim.cancelled).canBeConfirmed, isFalse);
    });

    test('El premio por completar una zona son 4 sellos', () {
      expect(UserRepository.zonePrizeStamps, 4);
    });
  });
}
