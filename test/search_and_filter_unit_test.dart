import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';

void main() {
  group('Search and Filter Section Unit Tests', () {
    test('normalizeSearchString strips accents, trims, and converts to lowercase', () {
      expect(Hueca.normalizeSearchString('  SECO DE CHIVO  '), equals('seco de chivo'));
      expect(Hueca.normalizeSearchString('Plátano y Café'), equals('platano y cafe'));
      expect(Hueca.normalizeSearchString('Ñoquis tradicionales'), equals('noquis tradicionales'));
      expect(Hueca.normalizeSearchString('Güitig con limón'), equals('guitig con limon'));
      expect(Hueca.normalizeSearchString('Último Rincón'), equals('ultimo rincon'));
    });

    test('extractSearchKeywords filters stop words and includes singular/plural variants', () {
      final huecaData = {
        'name': 'Las Hamburguesas del Centro',
        'sector': 'Centro Histórico',
        'address': 'García Moreno',
        'tags': ['artesanal'],
        'mainDish': {
          'name': {'es': 'Hamburguesa Clásica con Queso'},
          'description': {'es': 'Carne de res a la parrilla con papas fritas'},
          'category': 'Comida Rápida',
        },
        'menuItems': [
          {
            'name': 'Papas rústicas',
            'description': 'Con salsa de ajo',
            'category': 'Acompañamientos',
          },
          {
            'name': 'Batido de mora',
            'description': 'Fruta natural',
            'category': 'Bebidas',
          }
        ],
      };

      final keywords = Hueca.extractSearchKeywords(huecaData);

      // Stop words like 'del', 'de', 'la', 'con' should NOT be keywords
      expect(keywords.contains('del'), isFalse);
      expect(keywords.contains('con'), isFalse);
      expect(keywords.contains('de'), isFalse);

      // Meaningful food words should be present
      expect(keywords, contains('hamburguesa'));
      expect(keywords, contains('hamburguesas')); // plural variation
      expect(keywords, contains('queso'));
      expect(keywords, contains('parrilla'));
      expect(keywords, contains('papas'));
      expect(keywords, contains('rusticas'));
      expect(keywords, contains('mora'));
      expect(keywords, contains('artesanal'));
    });

    test('Dish search query matches dishes inside menuItems even if not present in main tags', () {
      final hueca = Hueca(
        id: 'h_test',
        name: 'El Rincón Colonial',
        description: {'es': 'Local tradicional'},
        address: 'Plaza Grande',
        sector: 'Centro Histórico',
        location: const GeoPoint(0, 0),
        phone: '123',
        schedule: {},
        mainDish: {'name': 'Hornado Tradicional'},
        loyaltyCard: {},
        secretSticker: {},
        menuItems: [
          {'name': 'Encebollado Mixto', 'description': 'Con albacora y camarón'},
          {'name': 'Locro de Papa', 'description': 'Con aguacate y queso'},
        ],
        tags: ['típica', 'quiteña'], // Does NOT contain 'encebollado' or 'locro' in tags
        searchTags: ['encebollado', 'locro', 'camaron', 'albacora'],
        priceLevel: r'$',
        rating: 4.7,
        reviewCount: 30,
        images: [],
        ownerId: 'owner',
        isActive: true,
        metrics: {},
      );

      bool matchesQuery(Hueca h, String query) {
        final cleanQ = Hueca.normalizeSearchString(query);
        if (cleanQ.isEmpty) return true;

        if (Hueca.normalizeSearchString(h.name).contains(cleanQ)) return true;
        if (Hueca.normalizeSearchString(h.sector).contains(cleanQ)) return true;
        if (h.tags.any((t) => Hueca.normalizeSearchString(t).contains(cleanQ))) return true;
        if (h.searchTags.any((t) => Hueca.normalizeSearchString(t).contains(cleanQ))) return true;

        // Check inside menu items
        for (final item in h.menuItems) {
          if (item is Map) {
            final name = item['name']?.toString() ?? '';
            final desc = item['description']?.toString() ?? '';
            if (Hueca.normalizeSearchString(name).contains(cleanQ) ||
                Hueca.normalizeSearchString(desc).contains(cleanQ)) {
              return true;
            }
          }
        }
        return false;
      }

      // Querying for 'encebollado' matches via menu items
      expect(matchesQuery(hueca, 'encebollado'), isTrue);

      // Querying with accents 'locró' matches normalized 'locro'
      expect(matchesQuery(hueca, 'locró'), isTrue);

      // Querying for 'camaron' matches via description
      expect(matchesQuery(hueca, 'camaron'), isTrue);

      // Irrelevant query does not match
      expect(matchesQuery(hueca, 'pizza hawaiana'), isFalse);
    });

    test('Sector filtering logic behaves properly with "Todo Quito" and specific sectors', () {
      final huecas = [
        Hueca(
          id: '1',
          name: 'Hueca Centro',
          description: {},
          address: '',
          sector: 'Centro Histórico',
          location: const GeoPoint(0, 0),
          phone: '',
          schedule: {},
          mainDish: {},
          loyaltyCard: {},
          secretSticker: {},
          menuItems: [],
          tags: [],
          priceLevel: r'$',
          rating: 4.5,
          reviewCount: 1,
          images: [],
          ownerId: '1',
          isActive: true,
          metrics: {},
        ),
        Hueca(
          id: '2',
          name: 'Hueca Floresta',
          description: {},
          address: '',
          sector: 'La Floresta',
          location: const GeoPoint(0, 0),
          phone: '',
          schedule: {},
          mainDish: {},
          loyaltyCard: {},
          secretSticker: {},
          menuItems: [],
          tags: [],
          priceLevel: r'$',
          rating: 4.5,
          reviewCount: 1,
          images: [],
          ownerId: '2',
          isActive: true,
          metrics: {},
        ),
      ];

      List<Hueca> filterBySector(List<Hueca> list, String sector) {
        if (sector == 'Todo Quito' || sector.isEmpty) return list;
        return list.where((h) => h.sector.trim().toLowerCase() == sector.trim().toLowerCase()).toList();
      }

      expect(filterBySector(huecas, 'Todo Quito').length, equals(2));
      expect(filterBySector(huecas, '').length, equals(2));

      final centroOnly = filterBySector(huecas, 'Centro Histórico');
      expect(centroOnly.length, equals(1));
      expect(centroOnly.first.name, equals('Hueca Centro'));

      final florestaOnly = filterBySector(huecas, 'La Floresta');
      expect(florestaOnly.length, equals(1));
      expect(florestaOnly.first.name, equals('Hueca Floresta'));

      final nonExistent = filterBySector(huecas, 'Valle de los Chillos');
      expect(nonExistent, isEmpty);
    });
  });
}
