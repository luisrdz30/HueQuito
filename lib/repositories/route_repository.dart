import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RouteModel {
  final String id;
  final Map<String, dynamic> name;
  final Map<String, dynamic> narrative;
  final String bannerImageUrl;
  final List<dynamic> tags;
  final Map<String, dynamic> metrics;
  final Map<String, dynamic> recommendedSchedule;
  final List<dynamic> stops;
  final String? creatorId;
  final bool isCustom;
  final DateTime? createdAt;

  RouteModel({
    required this.id,
    required this.name,
    required this.narrative,
    required this.bannerImageUrl,
    required this.tags,
    required this.metrics,
    required this.recommendedSchedule,
    required this.stops,
    this.creatorId,
    this.isCustom = false,
    this.createdAt,
  });

  factory RouteModel.fromMap(Map<String, dynamic> data, String docId) {
    Map<String, dynamic> parseLangMap(dynamic val, String defaultText) {
      if (val is Map) return Map<String, dynamic>.from(val);
      if (val is String) return {'es': val, 'en': val};
      return {'es': defaultText, 'en': defaultText};
    }

    DateTime? parsedDate;
    if (data['createdAt'] is Timestamp) {
      parsedDate = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      parsedDate = DateTime.tryParse(data['createdAt']);
    } else if (data['createdAt'] is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(data['createdAt']);
    }

    return RouteModel(
      id: docId,
      name: parseLangMap(data['name'], 'Sin nombre'),
      narrative: parseLangMap(data['narrative'], ''),
      bannerImageUrl: data['bannerImageUrl']?.toString() ?? 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=800&q=80',
      tags: data['tags'] is List ? List<dynamic>.from(data['tags']) : [],
      metrics: data['metrics'] is Map ? Map<String, dynamic>.from(data['metrics']) : {'distance': '0 km', 'estimatedTime': '0 min'},
      recommendedSchedule: data['recommendedSchedule'] is Map
          ? Map<String, dynamic>.from(data['recommendedSchedule'])
          : {'time': {'es': '', 'en': ''}, 'note': {'es': '', 'en': ''}},
      stops: data['stops'] is List ? List<dynamic>.from(data['stops']) : [],
      creatorId: data['creatorId']?.toString(),
      isCustom: data['isCustom'] == true,
      createdAt: parsedDate,
    );
  }

  factory RouteModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return RouteModel.fromMap(data, doc.id);
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
      'creatorId': creatorId,
      'isCustom': isCustom,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'id': id,
      'name': name,
      'narrative': narrative,
      'bannerImageUrl': bannerImageUrl,
      'tags': tags,
      'metrics': metrics,
      'recommendedSchedule': recommendedSchedule,
      'stops': stops,
      'creatorId': creatorId,
      'isCustom': isCustom,
      'createdAt': createdAt?.toIso8601String(),
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
      print('Error fetching routes: $e');
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

  // ==========================================
  // TOURS PERSONALIZADOS DEL USUARIO (CUSTOM TOURS)
  // ==========================================

  /// Obtiene los tours creados por el usuario (en Firestore si está autenticado, o en SharedPreferences si es invitado)
  Future<List<RouteModel>> getUserTours({String? userId}) async {
    final List<RouteModel> results = [];

    // 1. Cargar tours locales de SharedPreferences (invitado o caché local)
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('guest_custom_tours');
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        for (var item in list) {
          if (item is Map) {
            results.add(RouteModel.fromMap(
              Map<String, dynamic>.from(item),
              item['id']?.toString() ?? '',
            ));
          }
        }
      }
    } catch (_) {}

    // 2. Si el usuario está autenticado, cargar desde Firestore
    if (userId != null && userId.isNotEmpty && userId != 'guest') {
      try {
        final snap = await _db
            .collection('users')
            .doc(userId)
            .collection('custom_tours')
            .orderBy('createdAt', descending: true)
            .get();

        final firestoreTours = snap.docs.map((d) => RouteModel.fromFirestore(d)).toList();

        // Combinar evitando duplicados por ID
        final existingIds = results.map((r) => r.id).toSet();
        for (var ft in firestoreTours) {
          if (!existingIds.contains(ft.id)) {
            results.add(ft);
            existingIds.add(ft.id);
          }
        }
      } catch (e) {
        print('Error fetching user tours from Firestore: $e');
      }
    }

    // Ordenar de más reciente a más antiguo
    results.sort((a, b) {
      final aDate = a.createdAt ?? DateTime(2020);
      final bDate = b.createdAt ?? DateTime(2020);
      return bDate.compareTo(aDate);
    });

    return results;
  }

  /// Stream reactivo de tours del usuario
  Stream<List<RouteModel>> streamUserTours(String? userId) {
    if (userId == null || userId.isEmpty || userId == 'guest') {
      return Stream.fromFuture(getUserTours(userId: userId));
    }

    return _db
        .collection('users')
        .doc(userId)
        .collection('custom_tours')
        .snapshots()
        .map((snapshot) {
          final tours = snapshot.docs.map((d) => RouteModel.fromFirestore(d)).toList();
          tours.sort((a, b) {
            final aDate = a.createdAt ?? DateTime(2020);
            final bDate = b.createdAt ?? DateTime(2020);
            return bDate.compareTo(aDate);
          });
          return tours;
        });
  }

  /// Guarda un nuevo tour creado por el usuario (en Firestore y/o SharedPreferences)
  Future<void> saveUserTour(RouteModel tour, {String? userId}) async {
    // 1. Guardar siempre una copia local en SharedPreferences para acceso offline rápido
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('guest_custom_tours');
      List<dynamic> list = [];
      if (str != null && str.isNotEmpty) {
        list = jsonDecode(str);
      }
      list.removeWhere((item) => item is Map && item['id'] == tour.id);
      list.insert(0, tour.toJsonMap());
      await prefs.setString('guest_custom_tours', jsonEncode(list));
    } catch (_) {}

    // 2. Si está autenticado, guardar en Firestore en su subcolección
    if (userId != null && userId.isNotEmpty && userId != 'guest') {
      try {
        await _db
            .collection('users')
            .doc(userId)
            .collection('custom_tours')
            .doc(tour.id)
            .set(tour.toMap(), SetOptions(merge: true));
      } catch (e) {
        print('Error saving user tour to Firestore: $e');
      }
    }

    // 3. Registrar impacto en las métricas de las huecas agregadas a este tour personalizado
    for (final stop in tour.stops) {
      if (stop is Map) {
        final hId = (stop['huecaId'] ?? stop['id'])?.toString();
        if (hId != null && hId.isNotEmpty) {
          try {
            await _db.collection('huecas').doc(hId).update({
              'metrics.routeAdditions': FieldValue.increment(1),
            });
          } catch (_) {
            try {
              await _db.collection('huecas').doc(hId).set({
                'metrics': {
                  'routeAdditions': FieldValue.increment(1),
                }
              }, SetOptions(merge: true));
            } catch (_) {}
          }
        }
      }
    }
  }

  /// Elimina un tour personalizado creado por el usuario
  Future<void> deleteUserTour(String tourId, {String? userId}) async {
    // 1. Eliminar de SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('guest_custom_tours');
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        list.removeWhere((item) => item is Map && item['id'] == tourId);
        await prefs.setString('guest_custom_tours', jsonEncode(list));
      }
    } catch (_) {}

    // 2. Si está autenticado, eliminar de Firestore
    if (userId != null && userId.isNotEmpty && userId != 'guest') {
      try {
        await _db
            .collection('users')
            .doc(userId)
            .collection('custom_tours')
            .doc(tourId)
            .delete();
      } catch (e) {
        print('Error deleting user tour from Firestore: $e');
      }
    }
  }
}
