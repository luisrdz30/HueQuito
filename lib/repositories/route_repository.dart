import 'package:cloud_firestore/cloud_firestore.dart';

class RouteModel {
  final String id;
  final Map<String, dynamic> name;
  final Map<String, dynamic> description;
  final String totalDistance;
  final String estimatedTime;
  final Map<String, dynamic> transportMethod;
  final String bannerImageUrl;
  final List<dynamic> stops; // [{order, huecaId, description}]

  RouteModel({
    required this.id,
    required this.name,
    required this.description,
    required this.totalDistance,
    required this.estimatedTime,
    required this.transportMethod,
    required this.bannerImageUrl,
    required this.stops,
  });

  factory RouteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RouteModel(
      id: doc.id,
      name: data['name'] ?? {'es': 'Sin nombre', 'en': 'No name'},
      description: data['description'] ?? {'es': '', 'en': ''},
      totalDistance: data['totalDistance'] ?? '0 km',
      estimatedTime: data['estimatedTime'] ?? '0 min',
      transportMethod: data['transportMethod'] ?? {'es': '', 'en': ''},
      bannerImageUrl: data['bannerImageUrl'] ?? 'https://via.placeholder.com/800x400',
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
      print('Error fetching routes: $e');
      return [];
    }
  }
}
