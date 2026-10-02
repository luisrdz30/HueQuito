
import io

code = '''import 'package:cloud_firestore/cloud_firestore.dart';

class RouteModel {
  final String id;
  final Map<String, dynamic> name;
  final Map<String, dynamic> narrative;
  final String bannerImageUrl;
  final List<dynamic> tags;
  final Map<String, dynamic> metrics;
  final Map<String, dynamic> recommendedSchedule;
  final List<dynamic> stops; 

  RouteModel({
    required this.id,
    required this.name,
    required this.narrative,
    required this.bannerImageUrl,
    required this.tags,
    required this.metrics,
    required this.recommendedSchedule,
    required this.stops,
  });

  factory RouteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RouteModel(
      id: doc.id,
      name: data['name'] ?? {'es': 'Sin nombre', 'en': 'No name'},
      narrative: data['narrative'] ?? {'es': '', 'en': ''},
      bannerImageUrl: data['bannerImageUrl'] ?? 'https://via.placeholder.com/800x400',
      tags: data['tags'] ?? [],
      metrics: data['metrics'] ?? {'distance': '0 km', 'estimatedTime': '0 min'},
      recommendedSchedule: data['recommendedSchedule'] ?? {'time': {'es': '', 'en': ''}, 'note': {'es': '', 'en': ''}},
      stops: data['stops'] ?? [],
    );
  }
}

class RouteRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<RouteModel>> getRoutes() async {
    try {
      final snapshot = await _db.collection('routes').get();
      return snapshot.docs.map((doc) => RouteModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching routes: ');
      return [];
    }
  }

  Future<void> addRoute(Map<String, dynamic> routeData) async {
    await _db.collection('routes').doc(routeData['id']).set(routeData);
  }
}
'''

with io.open('lib/repositories/route_repository.dart', 'w', encoding='utf-8') as f:
    f.write(code)

