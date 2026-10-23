import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';

void main() {
  group('Hueca Search & Filtering Tests', () {
    test('normalizeSearchString strips accents and lowercases', () {
      expect(Hueca.normalizeSearchString('Hamburguesa Clásica con ChimiChurri!'),
          'hamburguesa clasica con chimichurri!');
      expect(Hueca.normalizeSearchString('Café & Dulce de Leche'),
          'cafe & dulce de leche');
    });

    test('extractSearchKeywords extracts meaningful words and creates plurals/singulars', () {
      final data = {
        'name': 'El Rincón del Sabor',
        'sector': 'La Mariscal',
        'address': 'Foch y Reina Victoria',
        'tags': ['tradicional', 'almuerzos'],
        'mainDish': {
          'name': {'es': 'Seco de Chivo', 'en': 'Goat Stew'},
          'description': {'es': 'Delicioso seco cocinado a fuego lento', 'en': 'Delicious stew'},
          'category': 'Plato Fuerte',
        },
        'menuItems': [
          {
            'name': {'es': 'Hamburguesa Casera', 'en': 'Homemade Burger'},
            'description': {'es': 'Carne de res con queso cheddar', 'en': 'Beef patty'},
            'category': 'Comida Rápida',
            'tags': ['artesanal', 'queso'],
          },
          {
            'name': 'Alitas BBQ',
            'category': 'Piqueos',
          }
        ],
      };

      final keywords = Hueca.extractSearchKeywords(data);

      // Verify keywords include words from name, mainDish and menuItems
      expect(keywords.contains('hamburguesa'), isTrue);
      expect(keywords.contains('hamburguesas'), isTrue);
      expect(keywords.contains('chivo'), isTrue);
      expect(keywords.contains('alitas'), isTrue);
      expect(keywords.contains('alita'), isTrue);
      expect(keywords.contains('mariscal'), isTrue);
      expect(keywords.contains('rapida'), isTrue);
      // Verify stop words are excluded
      expect(keywords.contains('del'), isFalse);
      expect(keywords.contains('con'), isFalse);
    });

    test('matchesSearch finds hueca when keyword is only in menuItems (not in main tags)', () {
      final hueca = Hueca(
        id: 'h1',
        name: 'Cafetería Don Pepe',
        description: {'es': 'Cafetería tradicional en el centro de Quito'},
        address: 'Guayaquil y Chile',
        sector: 'Centro Histórico',
        location: const GeoPoint(-0.22, -78.51),
        phone: '0991234567',
        schedule: {},
        mainDish: {
          'name': {'es': 'Café Pasado', 'en': 'Drip Coffee'},
          'category': 'Bebidas',
        },
        loyaltyCard: {},
        secretSticker: {},
        tags: ['cafeteria', 'desayunos', 'tradicion'],
        menuItems: [
          {
            'name': {'es': 'Hamburguesa Doble Queso', 'en': 'Double Cheeseburger'},
            'description': {'es': 'Doble carne a la parrilla con queso fundido'},
            'category': 'Comida Rápida',
            'price': 4.50,
          },
          {
            'name': 'Humitas Tradicionales',
            'price': 1.50,
          }
        ],
        priceLevel: r'$$',
        rating: 4.8,
        reviewCount: 15,
        images: [],
        ownerId: 'owner1',
        isActive: true,
        branches: [],
        metrics: const {},
      );

      // 1. Direct search for dish name in menu
      expect(hueca.matchesSearch('hamburguesa'), isTrue);

      // 2. Plural variation of dish name in menu
      expect(hueca.matchesSearch('hamburguesas'), isTrue);

      // 3. Multi-word search matching dish in menu
      expect(hueca.matchesSearch('hamburguesa queso'), isTrue);

      // 4. Accent-insensitivity search
      expect(hueca.matchesSearch('comida rápida'), isTrue);
      expect(hueca.matchesSearch('comida rapida'), isTrue);

      // 5. Dish description search
      expect(hueca.matchesSearch('parrilla'), isTrue);

      // 6. Another item in menu
      expect(hueca.matchesSearch('humita'), isTrue);
      expect(hueca.matchesSearch('humitas'), isTrue);

      // 7. Unrelated food shouldn't match
      expect(hueca.matchesSearch('sushi'), isFalse);
      expect(hueca.matchesSearch('ceviche'), isFalse);
    });

    test('matchesSearch handles tricky words without infinite recursion', () {
      final hueca = Hueca(
        id: 'h2',
        name: 'Hueca del Arroz',
        description: {'es': 'Especialistas en arroz con camarón'},
        address: 'Av. Amazonas',
        sector: 'La Carolina',
        location: const GeoPoint(-0.21, -78.48),
        phone: '',
        schedule: {},
        mainDish: {'name': 'Arroz Marinero'},
        loyaltyCard: {},
        secretSticker: {},
        tags: ['mariscos'],
        menuItems: [],
        priceLevel: r'$$',
        rating: 4.5,
        reviewCount: 5,
        images: [],
        ownerId: '',
        isActive: true,
        branches: [],
        metrics: const {},
      );

      // Words ending in 'z', 's', or non-'s' should not cause stack overflow
      expect(hueca.matchesSearch('arroz'), isTrue);
      expect(hueca.matchesSearch('arrozs'), isTrue);
      expect(hueca.matchesSearch('camaron'), isTrue);
      expect(hueca.matchesSearch('camarón'), isTrue);
      expect(hueca.matchesSearch('camarones'), isTrue);
      expect(hueca.matchesSearch('maiz'), isFalse);
      expect(hueca.matchesSearch('pan'), isFalse);
    });
  });
}
