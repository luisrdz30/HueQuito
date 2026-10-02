import 'package:flutter/material.dart';
import 'package:hue_quito/repositories/route_repository.dart';

Future<void> seedRoutes(BuildContext context) async {
  final repo = RouteRepository();

  final route1 = {
    'id': 'ruta_01',
    'name': {
      'es': 'Ruta Colonial de Sabores',
      'en': 'Colonial Flavors Route'
    },
    'narrative': {
      'es': 'Un recorrido sensorial a través de empedrados centenarios que serpentean por el Centro Histórico. Inicia en San Juan con las famosas quesadillas, baja a la mítica Heladería San Agustín y culmina en el bullicio del Mercado Central con la corvina.',
      'en': 'A sensory journey through centuries-old cobblestones in the Historic Center. Starts in San Juan with the famous quesadillas, goes down to the mythical San Agustín ice cream shop, and ends in the bustling Central Market with corvina.'
    },
    'bannerImageUrl': 'https://lh3.googleusercontent.com/aida/AEtjO1UlqkyPYbg08vZp-Tr0LV0ZLcEOPheQAEviSYtOZEUez01sec1kQbjtHvdUlXtSINk4e93fN3Y17xDquKlT_mS3j1NtrtxQNmvRL01NGFj5mH0M7hDxM7bZGefwtf_VkW5kfx6x6Ei5RjlgYycfaU0n9gtF-fs9Pc0WCMpA9_yte0GYXOwQqFw_CYudrng7IwiNA-yrRGQmMbKwXZV97ZrhUPN_IQmGoA0jdscqI1nQAsTife0RG_YvGpe4',
    'tags': [
      {'icon': 'location_on', 'text': {'es': 'Centro Histórico', 'en': 'Historic Center'}},
      {'icon': 'restaurant', 'text': {'es': 'Platos Típicos', 'en': 'Typical Dishes'}},
      {'icon': 'family_restroom', 'text': {'es': 'Apto Familiar', 'en': 'Family Friendly'}}
    ],
    'metrics': {
      'distance': '2.4 km',
      'estimatedTime': '2h 30m'
    },
    'recommendedSchedule': {
      'time': {'es': '09:30 AM a 02:00 PM', 'en': '09:30 AM to 02:00 PM'},
      'note': {
        'es': 'Momento cumbre para saborear el almuerzo quiteño en los mercados.',
        'en': 'Peak time to savor the traditional lunch in the local markets.'
      }
    },
    'stops': [
      {
        'order': 1,
        'huecaId': 'hueca_003',
        'travelToNext': {
          'mode': 'walk',
          'duration': '15 min',
          'distance': '1.1 km',
          'instruction': {
            'es': 'bajada hacia Plaza Grande',
            'en': 'downhill towards Plaza Grande'
          }
        }
      },
      {
        'order': 2,
        'huecaId': 'hueca_002',
        'travelToNext': {
          'mode': 'walk',
          'duration': '10 min',
          'distance': '750 m',
          'instruction': {
            'es': 'por calle Guayaquil hacia el Mercado',
            'en': 'via Guayaquil street towards the Market'
          }
        }
      },
      {
        'order': 3,
        'huecaId': 'hueca_001',
        'travelToNext': null
      }
    ]
  };

  final route2 = {
    'id': 'ruta_02',
    'name': {
      'es': 'Tardeada en La Floresta',
      'en': 'Evening in La Floresta'
    },
    'narrative': {
      'es': 'Descubre los olores nocturnos del barrio bohemio de La Floresta. Empezando con empanadas calientes al final de la tarde, pasando a las emblemáticas tripas de la vicentina y cerrando con una increíble bandera marinera.',
      'en': 'Discover the night aromas of the bohemian neighborhood of La Floresta. Starting with hot empanadas in the late afternoon, moving to the iconic tripe, and ending with an amazing seafood bandera.'
    },
    'bannerImageUrl': 'https://plus.unsplash.com/premium_photo-1661963054563-ce928e592186?q=80&w=2000&auto=format&fit=crop',
    'tags': [
      {'icon': 'location_on', 'text': {'es': 'La Floresta', 'en': 'La Floresta'}},
      {'icon': 'nights_stay', 'text': {'es': 'Nocturno', 'en': 'Nightly'}},
      {'icon': 'fastfood', 'text': {'es': 'Comida Rápida', 'en': 'Street Food'}}
    ],
    'metrics': {
      'distance': '1.2 km',
      'estimatedTime': '1h 45m'
    },
    'recommendedSchedule': {
      'time': {'es': '05:00 PM a 09:00 PM', 'en': '05:00 PM to 09:00 PM'},
      'note': {
        'es': 'Perfecto para cuando empieza a bajar el sol y se encienden los fogones.',
        'en': 'Perfect for when the sun goes down and the street stoves light up.'
      }
    },
    'stops': [
      {
        'order': 1,
        'huecaId': 'hueca_005',
        'travelToNext': {
          'mode': 'walk',
          'duration': '5 min',
          'distance': '400 m',
          'instruction': {
            'es': 'caminando por el parque',
            'en': 'walking through the park'
          }
        }
      },
      {
        'order': 2,
        'huecaId': 'hueca_004',
        'travelToNext': {
          'mode': 'walk',
          'duration': '2 min',
          'distance': '150 m',
          'instruction': {
            'es': 'cruzando la calle',
            'en': 'crossing the street'
          }
        }
      },
      {
        'order': 3,
        'huecaId': 'hueca_006',
        'travelToNext': null
      }
    ]
  };

  await repo.addRoute(route1);
  await repo.addRoute(route2);
  print('Routes seeded');
}
