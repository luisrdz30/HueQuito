import 'package:flutter_test/flutter_test.dart';
import 'package:hue_quito/services/menu_ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MenuOcrService - Advanced OCR Parser Tests', () {
    test('Parses Format 1: Reference image menu items with descriptions and prices', () async {
      final rawLines = [
        'BANDEJAS',
        '★ SUPER BANDEJA',
        '\$39',
        'Una porción de fritadas acompañadas de papas, tostado, mote, tortillas x 10, aguacate, maduro, queso, habas, choclo x 2, empanadas x 3 y ensalada. Rinde para 5 a 6 personas.',
        '★ BANDEJA AMAZONAS',
        '\$25',
        'Una porción de fritadas acompañadas de papas, tostado y mote. Rinde para 4 a 5 personas.',
        'BANDEJA MEDIANA',
        '\$14',
        'Media porción de fritadas acompañadas de papas, tostado y mote. Rinde para 2 a 3 personas.',
        'PLATO INDIVIDUAL',
        '\$7.50',
        '1/4 de porción de fritadas acompañadas de papas, tostado y mote.',
      ];

      final dishes = await MenuOcrService.parseRawLinesToDishes(rawLines);

      expect(dishes.length, 4);

      expect(dishes[0]['name']['es'], 'Super Bandeja');
      expect(dishes[0]['price'], 39.0);
      expect(dishes[0]['description']['es'], contains('tortillas x 10'));

      expect(dishes[1]['name']['es'], 'Bandeja Amazonas');
      expect(dishes[1]['price'], 25.0);
      expect(dishes[1]['description']['es'], contains('4 a 5 personas'));

      expect(dishes[2]['name']['es'], 'Bandeja Mediana');
      expect(dishes[2]['price'], 14.0);
      expect(dishes[2]['description']['es'], contains('Media porción'));

      expect(dishes[3]['name']['es'], 'Plato Individual');
      expect(dishes[3]['price'], 7.50);
      expect(dishes[3]['description']['es'], contains('1/4 de porción'));
    });

    test('Strips emojis, stars, food symbols, and decorative pictographs', () async {
      final rawText = '''
🍗 SUPER BANDEJA 🔥 \$39
Una porción de fritadas rinde para 5 a 6 personas 🤤
🥩 BANDEJA AMAZONAS ⭐ \$25
Media porción con tostado y mote ✨
🍲 PLATO INDIVIDUAL 👨‍🍳 \$7.50
1/4 de porción de fritadas acompañadas de papas 🥔
''';

      final dishes = await MenuOcrService.parseRawTextToDishes(rawText);

      expect(dishes.length, 3);
      expect(dishes[0]['name']['es'], 'Super Bandeja');
      expect(dishes[0]['price'], 39.0);
      expect(dishes[0]['description']['es'], isNot(contains('🤤')));

      expect(dishes[1]['name']['es'], 'Bandeja Amazonas');
      expect(dishes[1]['price'], 25.0);
      expect(dishes[1]['description']['es'], isNot(contains('✨')));

      expect(dishes[2]['name']['es'], 'Plato Individual');
      expect(dishes[2]['price'], 7.50);
      expect(dishes[2]['description']['es'], isNot(contains('🥔')));
    });

    test('Filters out metadata noise: Wi-Fi, phone numbers, RUC, social media, opening hours', () async {
      final rawText = '''
BIENVENIDOS A HUECA LA TRADICIONAL
Horario: Lunes a Domingo 08h00 - 18h00
Dirección: La Floresta, Quito - Ecuador
Wi-Fi: Clave: fritada123
Pedidos WhatsApp: 0991234567
Instagram: @huecatradicional

BANDEJAS
Super Bandeja \$39
Una porción de fritadas
Bandeja Amazonas \$25
Una porción de fritadas

RUC: 1712345678001
No incluye IVA. Propina sugerida 10%
Gracias por su visita!
''';

      final dishes = await MenuOcrService.parseRawTextToDishes(rawText);

      expect(dishes.length, 2);
      expect(dishes[0]['name']['es'], 'Super Bandeja');
      expect(dishes[0]['price'], 39.0);
      expect(dishes[1]['name']['es'], 'Bandeja Amazonas');
      expect(dishes[1]['price'], 25.0);
    });

    test('Handles title split across lines before price', () async {
      final rawLines = [
        'BANDEJAS',
        'SUPER',
        'BANDEJA',
        '\$39',
        'Una porción de fritadas.',
        'BANDEJA',
        'AMAZONAS',
        '\$25',
        'Una porción de fritadas.',
      ];

      final dishes = await MenuOcrService.parseRawLinesToDishes(rawLines);

      expect(dishes.length, 2);
      expect(dishes[0]['name']['es'], 'Super Bandeja');
      expect(dishes[0]['price'], 39.0);
      expect(dishes[1]['name']['es'], 'Bandeja Amazonas');
      expect(dishes[1]['price'], 25.0);
    });

    test('Handles Ecuadorian menu variety: Seco, Hornado, Encebollado, Jugos', () async {
      final rawText = '''
PLATOS TÍPICOS
Seco de Chivo ... \$4.50
Hornado Pastuso ... \$5.00
Encebollado Mixto ... \$4.00

BEBIDAS
Jarra de Chicha ... \$3.00
Jugo de Mora ... \$1.50
''';

      final dishes = await MenuOcrService.parseRawTextToDishes(rawText);

      expect(dishes.length, 5);
      expect(dishes[0]['name']['es'], 'Seco de Chivo');
      expect(dishes[0]['price'], 4.50);
      expect(dishes[0]['category'], 'Platos Típicos');

      expect(dishes[1]['name']['es'], 'Hornado Pastuso');
      expect(dishes[1]['price'], 5.00);

      expect(dishes[2]['name']['es'], 'Encebollado Mixto');
      expect(dishes[2]['price'], 4.00);

      expect(dishes[3]['name']['es'], 'Jarra de Chicha');
      expect(dishes[3]['price'], 3.00);
      expect(dishes[3]['category'], 'Bebidas');

      expect(dishes[4]['name']['es'], 'Jugo de Mora');
      expect(dishes[4]['price'], 1.50);
      expect(dishes[4]['category'], 'Bebidas');
    });

    test('Parses Image 2: Promotional menu flyer without prices (Picada Mixta, Alitas BBQ, Bacon Burger, Classic Burger)', () async {
      final rawText = '''
PICADA MIXTA
¡Un clásico en nuestro menú! Lomito y pollo salteado, acompañado de los mejores embutidos de la casa, con ese toque perfecto al grill.

ALITAS BBQ
Alitas de pollo premium bañadas en salsa BBQ artesanal. Cocinadas a fuego lento para un sabor ahumado y jugoso. ¡El acompañante ideal para compartir en la mesa!
8 ALITAS 12 ALITAS

BACON BURGER
¿Eres un Toci Lover? Entonces déjate seducir por esta espectacular hamburguesa con sabores que se derriten en tu boca.
(180G)

CLASSIC BURGER
Vegetales frescos, una jugosa carne magra al grill y una lámina de queso con ese aroma inconfundible de nuestras brasas Josper.
(180G)
''';

      final dishes = await MenuOcrService.parseRawTextToDishes(rawText);

      expect(dishes.length, 4);

      expect(dishes[0]['name']['es'], 'Picada Mixta');
      expect(dishes[0]['price'], 0.0);
      expect(dishes[0]['description']['es'], contains('Lomito y pollo salteado'));

      expect(dishes[1]['name']['es'], 'Alitas Bbq');
      expect(dishes[1]['price'], 0.0);
      expect(dishes[1]['description']['es'], contains('Alitas de pollo premium'));

      expect(dishes[2]['name']['es'], 'Bacon Burger');
      expect(dishes[2]['price'], 0.0);
      expect(dishes[2]['description']['es'], contains('Toci Lover'));

      expect(dishes[3]['name']['es'], 'Classic Burger');
      expect(dishes[3]['price'], 0.0);
      expect(dishes[3]['description']['es'], contains('Vegetales frescos'));
    });

    test('Parses Format 3: Grid menu with multi-price variant matrices (Roger\'s Smash Burgers: 6 burgers, 0 duplicate variant dishes)', () async {
      final rawLines = [
        'SMASHED BURGERS',
        'SMASH CLÁSICA',
        '115G, QUESO CHEDDAR, LECHUGA, TOMATE, PICKLES, SALSA ROGERS EN PAN DE PAPA.',
        'SENCILLA \$5,65 COMBO \$8,75 DOBLE \$7,20 COMBO \$10,30',
        'BBQ',
        '195G, DOBLE QUESO CHEDDAR, BACON BITS, SWEET & SMOKEY BBQ SAUCE EN PAN BRIOCHE.',
        'DOBLE \$8,20 COMBO \$11,30',
        'VEGGIE BURGER',
        '115G, BEYOND MEAT, QUESO CHEDDAR, LECHUGA, TOMATE, PICKLES, SALSA ROGERS Y PAN DE PAPA.',
        'BEYOND MEAT',
        'SENCILLA \$8,20 COMBO \$11,30 DOBLE \$12,30 COMBO \$15,40',
        'SMASH BACON CEBOLLITAS',
        '115G, QUESO PEPPER JACK, BACON BITS, CEBOLLITAS CARAMELIZADAS, JALAPEÑO MAYO EN PAN BRIOCHE.',
        'SENCILLA \$6,70 COMBO \$9,80 DOBLE \$8,20 COMBO \$11,30',
        'BIG BABY',
        '195G, DOBLE QUESO EMMENTAL, Y SMOKEY MAYO EN PRETZEL BUN.',
        'DOBLE \$8,20 COMBO \$11,30',
        'PATTY MELT',
        '160G, ULTRA SMASHED, QUESO CHEDDAR, MOZZARELLA, BACON JAM Y SALSA P.M. EN PAN DE MOLDE ARTESANAL.',
        'DOBLE \$7,20 COMBO \$10,30',
      ];

      final dishes = await MenuOcrService.parseRawLinesToDishes(rawLines);

      expect(dishes.length, 6);

      // 1. Smash Clásica
      expect(dishes[0]['name']['es'], 'Smash Clásica');
      expect(dishes[0]['price'], 5.65);
      expect(dishes[0]['description']['es'], contains('115G, QUESO CHEDDAR'));
      expect(dishes[0]['description']['es'], contains('Sencilla: \$5.65'));
      expect(dishes[0]['description']['es'], contains('Combo: \$8.75'));

      // 2. BBQ
      expect(dishes[1]['name']['es'], 'Bbq');
      expect(dishes[1]['price'], 8.20);
      expect(dishes[1]['description']['es'], contains('195G, DOBLE QUESO CHEDDAR'));
      expect(dishes[1]['description']['es'], contains('Doble: \$8.20'));
      expect(dishes[1]['description']['es'], contains('Combo: \$11.30'));

      // 3. Veggie Burger
      expect(dishes[2]['name']['es'], 'Veggie Burger');
      expect(dishes[2]['price'], 8.20);
      expect(dishes[2]['description']['es'], contains('BEYOND MEAT'));

      // 4. Smash Bacon Cebollitas
      expect(dishes[3]['name']['es'], 'Smash Bacon Cebollitas');
      expect(dishes[3]['price'], 6.70);
      expect(dishes[3]['description']['es'], contains('Sencilla: \$6.70'));

      // 5. Big Baby
      expect(dishes[4]['name']['es'], 'Big Baby');
      expect(dishes[4]['price'], 8.20);
      expect(dishes[4]['description']['es'], contains('PRETZEL BUN'));

      // 6. Patty Melt
      expect(dishes[5]['name']['es'], 'Patty Melt');
      expect(dishes[5]['price'], 7.20);
      expect(dishes[5]['description']['es'], contains('ULTRA SMASHED'));

      // Verificar que NO se crearon platos espurios de variantes o logos
      final dishNames = dishes.map((d) => (d['name']['es'] as String).toLowerCase()).toList();
      expect(dishNames, isNot(contains('sencilla')));
      expect(dishNames, isNot(contains('combo')));
      expect(dishNames, isNot(contains('doble')));
      expect(dishNames, isNot(contains('beyond meat')));
    });

    test('Parses Format 4: Real camera fragmented lines with multi-line ingredients, split titles, and separated table rows', () async {
      final rawLines = [
        'SMASHED BURGERS',
        'SMASH CLÁSICA',
        '115G, QUESO CHEDDAR, LECHUGA,',
        'TOMATE, PICKLES, SALSA ROGERS',
        'EN PAN DE PAPA.',
        'SENCILLA COMBO DOBLE COMBO',
        '\$5,65 \$8,75 \$7,20 \$10,30',
        'BBQ',
        '195G, DOBLE QUESO CHEDDAR, BACON BITS,',
        'SWEET & SMOKEY BBQ SAUCE EN PAN BRIOCHE.',
        'DOBLE COMBO',
        '\$8,20 \$11,30',
        'VEGGIE BURGER',
        '115G, BEYOND MEAT, QUESO CHEDDAR,',
        'LECHUGA, TOMATE, PICKLES,',
        'SALSA ROGERS Y PAN DE PAPA.',
        'BEYOND MEAT',
        'SENCILLA COMBO DOBLE COMBO',
        '\$8,20 \$11,30 \$12,30 \$15,40',
        'ROGER\'S',
        'EST. GYE',
        'SMASH BURGERS',
        'R',
        'SMASH BACON',
        'CEBOLLITAS',
        '115G, QUESO PEPPER JACK, BACON BITS,',
        'CEBOLLITAS CARAMELIZADAS, JALAPEÑO MAYO',
        'EN PAN BRIOCHE.',
        'SENCILLA COMBO DOBLE COMBO',
        '\$6,70 \$9,80 \$8,20 \$11,30',
        'BIG BABY',
        '195G, DOBLE QUESO EMMENTAL,',
        'Y SMOKEY MAYO EN PRETZEL BUN.',
        'DOBLE COMBO',
        '\$8,20 \$11,30',
        'PATTY MELT',
        '160G, ULTRA SMASHED, QUESO CHEDDAR,',
        'MOZZARELLA, BACON JAM Y SALSA P.M.',
        'EN PAN DE MOLDE ARTESANAL.',
        'DOBLE COMBO',
        '\$7,20 \$10,30',
      ];

      final dishes = await MenuOcrService.parseRawLinesToDishes(rawLines);

      expect(dishes.length, 6);

      expect(dishes[0]['name']['es'], 'Smash Clásica');
      expect(dishes[0]['price'], 5.65);
      expect(dishes[0]['description']['es'], contains('Sencilla: \$5.65'));

      expect(dishes[1]['name']['es'], 'Bbq');
      expect(dishes[1]['price'], 8.20);

      expect(dishes[2]['name']['es'], 'Veggie Burger');
      expect(dishes[2]['price'], 8.20);

      expect(dishes[3]['name']['es'], 'Smash Bacon Cebollitas');
      expect(dishes[3]['price'], 6.70);

      expect(dishes[4]['name']['es'], 'Big Baby');
      expect(dishes[4]['price'], 8.20);

      expect(dishes[5]['name']['es'], 'Patty Melt');
      expect(dishes[5]['price'], 7.20);
    });
  });
}
