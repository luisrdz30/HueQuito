import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hue_quito/models/menu_categories.dart';
import 'package:hue_quito/models/quito_zones.dart';

void main() {
  group('Zonas de Quito', () {
    test('los sectores y barrios viejos caen en una de las 4 zonas', () {
      expect(normalizeQuitoZone('Centro Histórico'), 'Centro');
      expect(normalizeQuitoZone('La Ronda'), 'Centro');
      expect(normalizeQuitoZone('La Mariscal'), 'Norte');
      expect(normalizeQuitoZone('Iñaquito / La Carolina'), 'Norte');
      expect(normalizeQuitoZone('Villaflora'), 'Sur');
      expect(normalizeQuitoZone('Conocoto'), 'Valles');
      expect(normalizeQuitoZone('Cumbayá'), 'Valles');
      expect(normalizeQuitoZone('Valle de los Chillos'), 'Valles');
      expect(normalizeQuitoZone('Valles'), 'Valles');
      expect(normalizeQuitoZone('Todo Quito'), isNull);
      expect(normalizeQuitoZone(''), isNull);
    });

    test('las coordenadas dan una zona razonable', () {
      expect(zoneFromCoordinates(-0.2199, -78.5070), 'Centro'); // Mercado Central
      expect(zoneFromCoordinates(-0.1800, -78.4850), 'Norte'); // La Carolina
      expect(zoneFromCoordinates(-0.2450, -78.5200), 'Sur'); // Villaflora
      expect(zoneFromCoordinates(-0.2930, -78.4750), 'Valles'); // Conocoto
      expect(zoneFromCoordinates(-0.2000, -78.4300), 'Valles'); // Cumbayá
    });
  });

  group('Categorías del menú', () {
    test('agrupa nombres viejos y ordena sugeridas antes que propias', () {
      final items = [
        {'category': 'Bebidas'},
        {'category': 'Combos'},
        {'category': 'Sopas'},
        {'category': 'Entradas y Guarniciones'},
        {},
      ];
      expect(dishCategory(items[2]), 'Sopas y Caldos');
      expect(dishCategory(items[3]), 'Entradas');
      expect(dishCategory(items[4]), 'Otros');
      expect(menuCategoriesOf(items), ['Entradas', 'Sopas y Caldos', 'Bebidas', 'Otros', 'Combos']);
    });
  });

  test('el archivo de huecas iniciales usa solo las 4 zonas y categorías conocidas', () {
    final seed = jsonDecode(File('assets/seed/huecas_quito.json').readAsStringSync()) as List;
    expect(seed, hasLength(20));
    for (final h in seed) {
      expect(quitoZoneIds, contains(h['sector']), reason: h['name']);
      expect(h['isActive'], isTrue);
      for (final item in h['menuItems']) {
        expect(menuCategoryById(dishCategory(item)), isNotNull, reason: '${h['name']}: ${item['category']}');
      }
    }
  });
}
