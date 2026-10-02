import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

Future<void> seedHuecas(BuildContext context) async {
  final db = FirebaseFirestore.instance;
  
  final List<Map<String, dynamic>> huecas = [
    // Centro Histórico
    {
      'id': 'hueca_centro_1',
      'name': 'Corvina de Don Jimmy',
      'sector': 'Centro Histórico',
      'address': 'Mercado Central, Av. Pichincha',
      'location': const GeoPoint(-0.2198, -78.5085),
      'description': {
        'es': 'Un clásico del Mercado Central desde hace décadas, famosa por sus corvinas fritas crujientes y ceviches.',
        'en': 'A Central Market classic for decades, famous for its crispy fried corvinas and ceviches.'
      },
      'mainDish': {
        'emoji': '🐟',
        'name': {'es': 'Corvina Frita Especial', 'en': 'Special Fried Corvina'},
        'price': 6.50
      },
      'schedule': {
        'monday': '08:00 - 15:00',
        'tuesday': '08:00 - 15:00',
        'wednesday': '08:00 - 15:00',
        'thursday': '08:00 - 15:00',
        'friday': '08:00 - 15:00',
        'saturday': '08:00 - 16:00',
        'sunday': '08:00 - 16:00'
      },
      'tags': ['Platos Fuertes', 'Tradicional', 'Mariscos'],
      'priceLevel': '\$\$',
      'rating': 4.8,
      'reviewCount': 312,
      'images': ['https://images.unsplash.com/photo-1615719413546-198b25453f85?auto=format&fit=crop&w=600&q=80'],
      'isActive': true,
      'loyaltyCard': {'maxStamps': 5, 'qrSecret': 'don_jimmy_sello', 'rewardText': {'es': '1 Ceviche Gratis', 'en': '1 Free Ceviche'}},
      'secretSticker': {'id': 'cromo_don_jimmy', 'imageUrl': '', 'name': {'es': 'Corvina Dorada', 'en': 'Golden Corvina'}, 'qrSecret': 'don_jimmy_secreto'},
      'menuItems': []
    },
    {
      'id': 'hueca_centro_2',
      'name': 'Heladería San Agustín',
      'sector': 'Centro Histórico',
      'address': 'Guayaquil y Mejía',
      'location': const GeoPoint(-0.2201, -78.5112),
      'description': {
        'es': 'Helados de paila tradicionales batidos a mano en paila de bronce desde 1858.',
        'en': 'Traditional paila ice creams hand-churned in bronze pans since 1858.'
      },
      'mainDish': {
        'emoji': '🍨',
        'name': {'es': 'Helado de Paila Mixto', 'en': 'Mixed Paila Ice Cream'},
        'price': 3.50
      },
      'schedule': {
        'monday': '09:00 - 18:00',
        'tuesday': '09:00 - 18:00',
        'wednesday': '09:00 - 18:00',
        'thursday': '09:00 - 18:00',
        'friday': '09:00 - 18:00',
        'saturday': '09:00 - 18:00',
        'sunday': '09:00 - 18:00'
      },
      'tags': ['Dulces', 'Tradicional', 'Postres'],
      'priceLevel': '\$',
      'rating': 4.9,
      'reviewCount': 521,
      'images': ['https://images.unsplash.com/photo-1558500958-ed19708ac820?auto=format&fit=crop&w=600&q=80'],
      'isActive': true,
      'loyaltyCard': {'maxStamps': 5, 'qrSecret': 'san_agustin_sello', 'rewardText': {'es': '1 Helado Gratis', 'en': '1 Free Ice Cream'}},
      'secretSticker': {'id': 'cromo_san_agustin', 'imageUrl': '', 'name': {'es': 'Paila de Bronce', 'en': 'Bronze Pan'}, 'qrSecret': 'san_agustin_secreto'},
      'menuItems': []
    },
    {
      'id': 'hueca_centro_3',
      'name': 'Las Quesadillas de San Juan',
      'sector': 'Centro Histórico',
      'address': 'Dehesa y Montevideo',
      'location': const GeoPoint(-0.2155, -78.5100),
      'description': {
        'es': 'Las auténticas quesadillas quiteñas, horneadas a leña y acompañadas de un buen chocolate.',
        'en': 'Authentic Quito quesadillas, wood-baked and served with good chocolate.'
      },
      'mainDish': {
        'emoji': '☕',
        'name': {'es': 'Quesadilla con Chocolate', 'en': 'Quesadilla with Chocolate'},
        'price': 4.00
      },
      'schedule': {
        'monday': '08:00 - 19:00',
        'tuesday': '08:00 - 19:00',
        'wednesday': '08:00 - 19:00',
        'thursday': '08:00 - 19:00',
        'friday': '08:00 - 19:00',
        'saturday': '08:00 - 19:00',
        'sunday': '08:00 - 15:00'
      },
      'tags': ['Dulces', 'Tradicional', 'Desayuno'],
      'priceLevel': '\$',
      'rating': 4.7,
      'reviewCount': 189,
      'images': ['https://images.unsplash.com/photo-1495147466023-ac5c588e2e94?auto=format&fit=crop&w=600&q=80'],
      'isActive': true,
      'loyaltyCard': {'maxStamps': 5, 'qrSecret': 'sanjuan_sello', 'rewardText': {'es': '1 Quesadilla', 'en': '1 Quesadilla'}},
      'secretSticker': {'id': 'cromo_sanjuan', 'imageUrl': '', 'name': {'es': 'Horno de Leña', 'en': 'Wood Oven'}, 'qrSecret': 'sanjuan_secreto'},
      'menuItems': []
    },
    
    // La Floresta
    {
      'id': 'hueca_floresta_1',
      'name': 'Tripas de La Floresta',
      'sector': 'La Floresta',
      'address': 'Parque Navarro',
      'location': const GeoPoint(-0.2078, -78.4829),
      'description': {
        'es': 'La clásica Tripa Mishqui al carbón servida con papas y mote en el icónico Parque Navarro.',
        'en': 'The classic charcoal-grilled Tripa Mishqui served with potatoes and mote in the iconic Navarro Park.'
      },
      'mainDish': {
        'emoji': '🍢',
        'name': {'es': 'Plato de Tripa Mishqui', 'en': 'Tripa Mishqui Plate'},
        'price': 3.50
      },
      'schedule': {
        'monday': 'Cerrado',
        'tuesday': '16:00 - 23:00',
        'wednesday': '16:00 - 23:00',
        'thursday': '16:00 - 23:00',
        'friday': '16:00 - 23:00',
        'saturday': '16:00 - 23:00',
        'sunday': '16:00 - 22:00'
      },
      'tags': ['Platos Fuertes', 'Tradicional', 'Carne'],
      'priceLevel': '\$',
      'rating': 4.6,
      'reviewCount': 420,
      'images': ['https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=600&q=80'],
      'isActive': true,
      'loyaltyCard': {'maxStamps': 5, 'qrSecret': 'tripas_sello', 'rewardText': {'es': '1 Porción Extra', 'en': '1 Extra Portion'}},
      'secretSticker': {'id': 'cromo_tripas', 'imageUrl': '', 'name': {'es': 'Parrilla Humeante', 'en': 'Smoking Grill'}, 'qrSecret': 'tripas_secreto'},
      'menuItems': []
    },
    {
      'id': 'hueca_floresta_2',
      'name': 'Empanadas de Morocho La Floresta',
      'sector': 'La Floresta',
      'address': 'Madrid y Toledo',
      'location': const GeoPoint(-0.2091, -78.4842),
      'description': {
        'es': 'Empanadas de morocho crujientes, servidas con ají casero y un buen vaso de morocho dulce.',
        'en': 'Crispy morocho empanadas, served with homemade hot sauce and a good glass of sweet morocho.'
      },
      'mainDish': {
        'emoji': '🥟',
        'name': {'es': 'Combo Morocho y Empanadas', 'en': 'Morocho & Empanadas Combo'},
        'price': 4.00
      },
      'schedule': {
        'monday': '15:00 - 21:00',
        'tuesday': '15:00 - 21:00',
        'wednesday': '15:00 - 21:00',
        'thursday': '15:00 - 21:00',
        'friday': '15:00 - 22:00',
        'saturday': '15:00 - 22:00',
        'sunday': '15:00 - 21:00'
      },
      'tags': ['Platos Fuertes', 'Snacks', 'Tradicional'],
      'priceLevel': '\$',
      'rating': 4.7,
      'reviewCount': 210,
      'images': ['https://images.unsplash.com/photo-1628198622715-095117942152?auto=format&fit=crop&w=600&q=80'],
      'isActive': true,
      'loyaltyCard': {'maxStamps': 5, 'qrSecret': 'empanada_sello', 'rewardText': {'es': '2 Empanadas', 'en': '2 Empanadas'}},
      'secretSticker': {'id': 'cromo_empanada', 'imageUrl': '', 'name': {'es': 'Masa Perfecta', 'en': 'Perfect Dough'}, 'qrSecret': 'empanada_secreto'},
      'menuItems': []
    },
    {
      'id': 'hueca_floresta_3',
      'name': 'Bandera de La Floresta',
      'sector': 'La Floresta',
      'address': 'Av. de los Conquistadores',
      'location': const GeoPoint(-0.2055, -78.4800),
      'description': {
        'es': 'Guatita, seco de chivo y ceviche, todo en un solo plato: La Bandera.',
        'en': 'Guatita, goat stew and ceviche, all in one plate: The Flag.'
      },
      'mainDish': {
        'emoji': '🍛',
        'name': {'es': 'Plato Bandera', 'en': 'Flag Plate'},
        'price': 6.00
      },
      'schedule': {
        'monday': '11:00 - 16:00',
        'tuesday': '11:00 - 16:00',
        'wednesday': '11:00 - 16:00',
        'thursday': '11:00 - 16:00',
        'friday': '11:00 - 16:00',
        'saturday': '11:00 - 17:00',
        'sunday': '11:00 - 17:00'
      },
      'tags': ['Platos Fuertes', 'Sopas', 'Tradicional'],
      'priceLevel': '\$\$',
      'rating': 4.5,
      'reviewCount': 130,
      'images': ['https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=600&q=80'],
      'isActive': true,
      'loyaltyCard': {'maxStamps': 5, 'qrSecret': 'bandera_sello', 'rewardText': {'es': '1 Jugo', 'en': '1 Juice'}},
      'secretSticker': {'id': 'cromo_bandera', 'imageUrl': '', 'name': {'es': 'Tres Sabores', 'en': 'Three Flavors'}, 'qrSecret': 'bandera_secreto'},
      'menuItems': []
    },

    // Conocoto
    {
      'id': 'hueca_conocoto_1',
      'name': 'Hornado de Conocoto',
      'sector': 'Conocoto',
      'address': 'Mercado Central de Conocoto',
      'location': const GeoPoint(-0.2882, -78.4795),
      'description': {
        'es': 'El hornado más crujiente del Valle, servido con tortillas de papa, mote y agrio.',
        'en': 'The crispiest roasted pork in the Valley, served with potato patties, mote and agrio.'
      },
      'mainDish': {
        'emoji': '🍖',
        'name': {'es': 'Plato de Hornado', 'en': 'Hornado Plate'},
        'price': 5.00
      },
      'schedule': {
        'monday': 'Cerrado',
        'tuesday': '08:00 - 15:00',
        'wednesday': '08:00 - 15:00',
        'thursday': '08:00 - 15:00',
        'friday': '08:00 - 15:00',
        'saturday': '08:00 - 16:00',
        'sunday': '08:00 - 16:00'
      },
      'tags': ['Platos Fuertes', 'Tradicional'],
      'priceLevel': '\$\$',
      'rating': 4.8,
      'reviewCount': 350,
      'images': ['https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?auto=format&fit=crop&w=600&q=80'],
      'isActive': true,
      'loyaltyCard': {'maxStamps': 5, 'qrSecret': 'hornado_sello', 'rewardText': {'es': '1 Plato Gratis', 'en': '1 Free Plate'}},
      'secretSticker': {'id': 'cromo_hornado', 'imageUrl': '', 'name': {'es': 'Cuerito Crujiente', 'en': 'Crispy Skin'}, 'qrSecret': 'hornado_secreto'},
      'menuItems': []
    },
    {
      'id': 'hueca_conocoto_2',
      'name': 'Fritadas de la Gata',
      'sector': 'Conocoto',
      'address': 'Vía Antigua a Conocoto',
      'location': const GeoPoint(-0.2800, -78.4820),
      'description': {
        'es': 'Fritada tradicional en paila de bronce, jugosa y llena de sabor.',
        'en': 'Traditional fritada cooked in a bronze pan, juicy and full of flavor.'
      },
      'mainDish': {
        'emoji': '🍲',
        'name': {'es': 'Fritada Completa', 'en': 'Full Fritada'},
        'price': 6.00
      },
      'schedule': {
        'monday': '09:00 - 17:00',
        'tuesday': '09:00 - 17:00',
        'wednesday': '09:00 - 17:00',
        'thursday': '09:00 - 17:00',
        'friday': '09:00 - 18:00',
        'saturday': '09:00 - 18:00',
        'sunday': '09:00 - 18:00'
      },
      'tags': ['Platos Fuertes', 'Tradicional', 'Cerdo'],
      'priceLevel': '\$\$',
      'rating': 4.6,
      'reviewCount': 220,
      'images': ['https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80'],
      'isActive': true,
      'loyaltyCard': {'maxStamps': 5, 'qrSecret': 'fritada_sello', 'rewardText': {'es': '1 Cerveza', 'en': '1 Beer'}},
      'secretSticker': {'id': 'cromo_fritada', 'imageUrl': '', 'name': {'es': 'Mote Calientito', 'en': 'Warm Mote'}, 'qrSecret': 'fritada_secreto'},
      'menuItems': []
    },
    {
      'id': 'hueca_conocoto_3',
      'name': 'Picantería El Puente',
      'sector': 'Conocoto',
      'address': 'Puente de Conocoto 2',
      'location': const GeoPoint(-0.2910, -78.4750),
      'description': {
        'es': 'Especialistas en caldos, yaguarlocro y librillo para revivir a cualquiera.',
        'en': 'Specialists in broths, yaguarlocro and librillo to revive anyone.'
      },
      'mainDish': {
        'emoji': '🥣',
        'name': {'es': 'Yaguarlocro Especial', 'en': 'Special Yaguarlocro'},
        'price': 4.50
      },
      'schedule': {
        'monday': 'Cerrado',
        'tuesday': '08:00 - 15:00',
        'wednesday': '08:00 - 15:00',
        'thursday': '08:00 - 15:00',
        'friday': '08:00 - 15:00',
        'saturday': '08:00 - 16:00',
        'sunday': '08:00 - 16:00'
      },
      'tags': ['Sopas', 'Tradicional', 'Caldos'],
      'priceLevel': '\$',
      'rating': 4.7,
      'reviewCount': 190,
      'images': ['https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=600&q=80'],
      'isActive': true,
      'loyaltyCard': {'maxStamps': 5, 'qrSecret': 'puente_sello', 'rewardText': {'es': '1 Yaguarlocro', 'en': '1 Yaguarlocro'}},
      'secretSticker': {'id': 'cromo_puente', 'imageUrl': '', 'name': {'es': 'Cuchara de Palo', 'en': 'Wooden Spoon'}, 'qrSecret': 'puente_secreto'},
      'menuItems': []
    }
  ];

  for (var h in huecas) {
    await db.collection('huecas').doc(h['id']).set(h);
  }
}
