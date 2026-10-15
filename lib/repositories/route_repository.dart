import 'package:cloud_firestore/cloud_firestore.dart';

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
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    Map<String, dynamic> parseLangMap(dynamic val, String defaultText) {
      if (val is Map) return Map<String, dynamic>.from(val);
      if (val is String) return {'es': val, 'en': val};
      return {'es': defaultText, 'en': defaultText};
    }

    return RouteModel(
      id: doc.id,
      name: parseLangMap(data['name'], 'Sin nombre'),
      narrative: parseLangMap(data['narrative'], ''),
      bannerImageUrl: data['bannerImageUrl']?.toString() ?? 'https://via.placeholder.com/800x400',
      tags: data['tags'] is List ? List<dynamic>.from(data['tags']) : [],
      metrics: data['metrics'] is Map ? Map<String, dynamic>.from(data['metrics']) : {'distance': '0 km', 'estimatedTime': '0 min'},
      recommendedSchedule: data['recommendedSchedule'] is Map
          ? Map<String, dynamic>.from(data['recommendedSchedule'])
          : {'time': {'es': '', 'en': ''}, 'note': {'es': '', 'en': ''}},
      stops: data['stops'] is List ? List<dynamic>.from(data['stops']) : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'narrative': narrative,
      'bannerImageUrl': bannerImageUrl,
      'tags': tags,
      'metrics': metrics,
      'recommendedSchedule': recommendedSchedule,
      'stops': stops,
    };
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

  Stream<List<RouteModel>> streamRoutes() {
    return _db.collection('routes').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => RouteModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> addRoute(Map<String, dynamic> routeData) async {
    final String id = routeData['id'] ?? _db.collection('routes').doc().id;
    routeData['id'] = id;
    await _db.collection('routes').doc(id).set(routeData);
  }

  Future<void> saveRoute(Map<String, dynamic> routeData) async {
    final String id = (routeData['id'] != null && routeData['id'].toString().isNotEmpty)
        ? routeData['id'].toString()
        : _db.collection('routes').doc().id;
    routeData['id'] = id;
    await _db.collection('routes').doc(id).set(routeData, SetOptions(merge: true));
  }

  Future<void> deleteRoute(String routeId) async {
    await _db.collection('routes').doc(routeId).delete();
  }
}
