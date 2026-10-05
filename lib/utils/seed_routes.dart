import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> seedRoutes(BuildContext context) async {
  final db = FirebaseFirestore.instance;

  // Delete old routes first
  final oldRoutes = await db.collection('routes').get();
  for (var doc in oldRoutes.docs) {
    await doc.reference.delete();
  }

  // Fetch all huecas
  final huecasSnapshot = await db.collection('huecas').get();
  final huecas = huecasSnapshot.docs.map((d) => d.data()).toList();

  Map<String, List<Map<String, dynamic>>> huecasBySector = {};
  for (var h in huecas) {
    final sector = h['sector'] ?? 'Desconocido';
    huecasBySector.putIfAbsent(sector, () => []).add(h);
  }

  List<Map<String, dynamic>> routes = [];

  void createRoute(String sectorName, String routeEs, String routeEn, String narEs, String narEn, String banner, List<String> tags) {
    final sectorHuecas = huecasBySector[sectorName] ?? [];
    if (sectorHuecas.isEmpty) return;

    List<Map<String, dynamic>> stops = [];
    for (int i = 0; i < sectorHuecas.length && i < 3; i++) {
      stops.add({
        'order': i + 1,
        'huecaId': sectorHuecas[i]['id'],
        'estimatedTimeHere': '45 min'
      });
    }

    routes.add({
      'name': {'es': routeEs, 'en': routeEn},
      'narrative': {'es': narEs, 'en': narEn},
      'bannerImageUrl': banner,
      'tags': tags,
      'metrics': {'distance': '2.4 km', 'estimatedTime': '2h 30m'},
      'recommendedSchedule': {
        'time': {'es': '09:30 AM a 02:00 PM', 'en': '09:30 AM to 02:00 PM'},
        'note': {'es': 'Momento cumbre para saborear', 'en': 'Peak time to taste'}
      },
      'stops': stops,
    });
  }

  createRoute(
    'Centro Histórico', 
    'Ruta Colonial de Sabores', 
    'Colonial Flavors Route',
    'Un recorrido sensorial a través de empedrados centenarios que serpentean desde los soportales de la Plaza de la Independencia, pasando por la mística plazoleta de San Francisco, hasta el corazón bullicioso de San Roque. Aquí la cocina conventual colonial abraza el fogón popular andino.',
    'A sensory journey through centuries-old cobblestones winding from the arcades of Independence Square, past the mystical San Francisco plaza, to the bustling heart of San Roque. Here, colonial convent cuisine embraces the popular Andean hearth.',
    'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?auto=format&fit=crop&q=80&w=800',
    ['Centro Histórico', 'Platos Típicos', 'Apto Familiar']
  );

  createRoute(
    'Conocoto', 
    'Sendero del Hornado', 
    'Hornado Trail',
    'Descubre el valle de Conocoto a través de su plato estrella. Este circuito te lleva a degustar las recetas familiares mejor guardadas de cerdos horneados a fuego lento con leña de eucalipto.',
    'Discover the Conocoto valley through its star dish. This circuit takes you to taste the best-kept family recipes of slow-roasted pork with eucalyptus wood.',
    'https://images.unsplash.com/photo-1544025162-836e2978ff8a?auto=format&fit=crop&q=80&w=800',
    ['Tradicional', 'Carnes', 'Fines de semana']
  );

  createRoute(
    'La Floresta', 
    'Bohemia y Sabor', 
    'Bohemian Flavor',
    'La Floresta no es solo arte y cultura; también es la cuna de innovadores platillos ecuatorianos y fusiones únicas. Recorre las calles llenas de murales mientras pruebas la esencia gastronómica moderna.',
    'La Floresta is not only art and culture; it is also the cradle of innovative Ecuadorian dishes and unique fusions. Walk the mural-filled streets while tasting the modern gastronomic essence.',
    'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&q=80&w=800',
    ['Urbano', 'Arte', 'Fusiones']
  );

  for (var r in routes) {
    await db.collection('routes').add(r);
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('3 Rutas Creadas! (Anteriores borradas)')));
  }
}
