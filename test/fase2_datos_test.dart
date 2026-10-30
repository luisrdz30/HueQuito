import 'package:flutter_test/flutter_test.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/route_repository.dart';
import 'package:hue_quito/repositories/subscription_repository.dart';

void main() {
  group('Fase 2 - errores de datos', () {
    test('La meta gratuita por defecto es de 100 sellos', () {
      expect(const SubscriptionSettings().freeTierMaxStamps, equals(100));
      expect(SubscriptionSettings.fromMap({}).freeTierMaxStamps, equals(100));
    });

    test('Sucursal sin id guardado obtiene un id estable entre lecturas', () {
      final a = HuecaBranch.fromMap({'name': 'La Floresta'});
      final b = HuecaBranch.fromMap({'name': 'La Floresta'});
      expect(a.id, equals(b.id));
      expect(a.id, equals('sucursal_la_floresta'));
      expect(HuecaBranch.fromMap({'name': 'X'}, defaultId: 'sucursal_2').id, equals('sucursal_2'));
      expect(HuecaBranch.fromMap({'id': 'abc', 'name': 'X'}).id, equals('abc'));
    });

    test('La caché local de tours se separa por cuenta', () {
      expect(RouteRepository.localToursKey(null), equals('guest_custom_tours'));
      expect(RouteRepository.localToursKey('guest'), equals('guest_custom_tours'));
      expect(RouteRepository.localToursKey('uid123'), equals('custom_tours_uid123'));
    });

    test('Solo los tours de invitado se consideran del invitado', () {
      expect(RouteRepository.isGuestTour({'creatorId': null}), isTrue);
      expect(RouteRepository.isGuestTour({'creatorId': 'guest'}), isTrue);
      expect(RouteRepository.isGuestTour({}), isTrue);
      expect(RouteRepository.isGuestTour({'creatorId': 'uid123'}), isFalse);
    });
  });
}
