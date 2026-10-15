import 'package:cloud_firestore/cloud_firestore.dart';

class HuecaBranch {
  final String id;
  final String name;
  final String address;
  final String sector;
  final GeoPoint location;
  final String phone;
  final Map<String, dynamic> schedule;
  final String? managerEmail;
  final Map<String, dynamic>? secretSticker;

  HuecaBranch({
    required this.id,
    required this.name,
    required this.address,
    required this.sector,
    required this.location,
    required this.phone,
    required this.schedule,
    this.managerEmail,
    this.secretSticker,
  });

  factory HuecaBranch.fromMap(Map<String, dynamic> map, {String? defaultId}) {
    return HuecaBranch(
      id: map['id']?.toString() ?? defaultId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: map['name']?.toString() ?? 'Sucursal',
      address: map['address']?.toString() ?? '',
      sector: map['sector']?.toString() ?? 'Centro',
      location: map['location'] is GeoPoint
          ? map['location'] as GeoPoint
          : const GeoPoint(-0.1807, -78.4678),
      phone: map['phone']?.toString() ?? '',
      schedule: map['schedule'] is Map ? Map<String, dynamic>.from(map['schedule']) : {},
      managerEmail: map['managerEmail']?.toString(),
      secretSticker: map['secretSticker'] is Map ? Map<String, dynamic>.from(map['secretSticker']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'sector': sector,
      'location': location,
      'phone': phone,
      'schedule': schedule,
      if (managerEmail != null && managerEmail!.isNotEmpty) 'managerEmail': managerEmail,
      if (secretSticker != null) 'secretSticker': secretSticker,
    };
  }
}

class Hueca {
  final String id;
  final String name;
  final Map<String, dynamic> description;
  final String address;
  final String sector;
  final GeoPoint location;
  final String phone;
  final Map<String, dynamic> schedule;
  final Map<String, dynamic> mainDish;
  final Map<String, dynamic> loyaltyCard;
  final Map<String, dynamic> secretSticker;
  final List<dynamic> menuItems;
  final List<String> tags;
  final String priceLevel;
  final double rating;
  final int reviewCount;
  final List<String> images;
  final String ownerId;
  final bool isActive;
  final Map<String, dynamic> metrics;
  final List<HuecaBranch> branches;

  Hueca({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.sector,
    required this.location,
    required this.phone,
    required this.schedule,
    required this.mainDish,
    required this.loyaltyCard,
    required this.secretSticker,
    required this.menuItems,
    required this.tags,
    required this.priceLevel,
    required this.rating,
    required this.reviewCount,
    required this.images,
    required this.ownerId,
    required this.isActive,
    required this.metrics,
    this.branches = const [],
  });

  List<HuecaBranch> get allBranches {
    if (branches.isNotEmpty) return branches;
    return [
      HuecaBranch(
        id: 'matriz',
        name: 'Matriz Principal',
        address: address,
        sector: sector,
        location: location,
        phone: phone,
        schedule: schedule,
        secretSticker: secretSticker,
      ),
    ];
  }

  factory Hueca.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    final rawBranches = data['branches'] as List<dynamic>?;
    List<HuecaBranch> parsedBranches = [];
    if (rawBranches != null && rawBranches.isNotEmpty) {
      parsedBranches = rawBranches
          .map((b) => HuecaBranch.fromMap(Map<String, dynamic>.from(b)))
          .toList();
    } else {
      parsedBranches = [
        HuecaBranch(
          id: 'matriz',
          name: 'Matriz Principal',
          address: data['address'] ?? '',
          sector: data['sector'] ?? '',
          location: data['location'] ?? const GeoPoint(0, 0),
          phone: data['phone'] ?? '',
          schedule: data['schedule'] ?? {},
          secretSticker: data['secretSticker'] is Map ? Map<String, dynamic>.from(data['secretSticker']) : null,
        ),
      ];
    }

    return Hueca(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? {},
      address: data['address'] ?? '',
      sector: data['sector'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      phone: data['phone'] ?? '',
      schedule: data['schedule'] ?? {},
      mainDish: data['mainDish'] ?? {},
      loyaltyCard: data['loyaltyCard'] ?? {},
      secretSticker: data['secretSticker'] ?? {},
      menuItems: data['menuItems'] ?? [],
      tags: List<String>.from(data['tags'] ?? []),
      priceLevel: data['priceLevel'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      images: List<String>.from(data['images'] ?? []),
      ownerId: data['ownerId'] ?? '',
      isActive: data['isActive'] ?? true,
      branches: parsedBranches,
      metrics: data['metrics'] ?? {
        'viewCount': 0,
        'favoriteCount': 0,
        'routeAdditions': 0,
        'stampsGiven': 0,
      },
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'sector': sector,
      'location': location,
      'phone': phone,
      'schedule': schedule,
      'mainDish': mainDish,
      'loyaltyCard': loyaltyCard,
      'secretSticker': secretSticker,
      'menuItems': menuItems,
      'tags': tags,
      'priceLevel': priceLevel,
      'rating': rating,
      'reviewCount': reviewCount,
      'images': images,
      'ownerId': ownerId,
      'isActive': isActive,
      'metrics': metrics,
      'branches': branches.map((b) => b.toMap()).toList(),
    };
  }
}

class HuecaRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Hueca>> getHuecas() async {
    final snapshot = await _db.collection('huecas').get();
    return snapshot.docs.map((doc) => Hueca.fromFirestore(doc)).toList();
  }

  Future<Hueca?> getHuecaById(String id) async {
    final doc = await _db.collection('huecas').doc(id).get();
    if (doc.exists) {
      return Hueca.fromFirestore(doc);
    }
    return null;
  }

  Future<void> addHueca(Map<String, dynamic> huecaData) async {
    final id = huecaData['id'];
    await _db.collection('huecas').doc(id).set(huecaData);
  }

  Future<void> addReview(String huecaId, int rating, String comment, String userName, String userPic) async {
    final reviewRef = _db.collection('huecas').doc(huecaId).collection('reviews').doc();
    await reviewRef.set({
      'rating': rating,
      'comment': comment,
      'userName': userName,
      'userPic': userPic,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Recalcular y sincronizar reviewCount y rating en el documento de la hueca
    try {
      final revSnap = await _db.collection('huecas').doc(huecaId).collection('reviews').get();
      final count = revSnap.docs.length;
      double avg = 0.0;
      if (count > 0) {
        final sum = revSnap.docs.fold<num>(0, (prev, d) => prev + (d.data()['rating'] as num? ?? 0));
        avg = double.parse((sum / count).toStringAsFixed(1));
      }
      await _db.collection('huecas').doc(huecaId).update({
        'reviewCount': count,
        'rating': avg,
      });
    } catch (e) {
      print('Error syncing review count on addReview: $e');
    }
  }

  Future<List<Review>> getReviews(String huecaId) async {
    final snapshot = await _db.collection('huecas').doc(huecaId).collection('reviews').orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
  }

  /// Elimina por completo una hueca y toda su información relacionada
  /// (subcolecciones de reseñas, sellos y cromos, avisos, invitaciones de sucursal,
  /// referencias en rutas, favoritos de usuarios y actualiza el rol del propietario a 'user').
  Future<void> deleteHueca(String huecaId) async {
    try {
      final huecaRef = _db.collection('huecas').doc(huecaId);
      final huecaDoc = await huecaRef.get();
      final huecaData = huecaDoc.data();
      final ownerId = huecaData?['ownerId'] as String?;

      // 1. Eliminar subcolecciones (reviews, stamp_history, sticker_history)
      final subcollections = ['reviews', 'stamp_history', 'sticker_history'];
      for (final sub in subcollections) {
        try {
          final subSnap = await huecaRef.collection(sub).get();
          for (final doc in subSnap.docs) {
            await doc.reference.delete();
          }
        } catch (e) {
          print('Error deleting subcollection $sub: $e');
        }
      }

      // 2. Eliminar avisos / notificaciones vinculados a esta hueca
      try {
        final notifSnap = await _db
            .collection('notifications')
            .where('huecaId', isEqualTo: huecaId)
            .get();
        for (final doc in notifSnap.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        print('Error deleting notifications for hueca: $e');
      }

      // 3. Eliminar invitaciones de sucursales vinculadas a esta hueca
      try {
        final invSnap = await _db
            .collection('branch_invitations')
            .where('huecaId', isEqualTo: huecaId)
            .get();
        for (final doc in invSnap.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        print('Error deleting branch invitations: $e');
      }

      // 4. Limpiar paradas en rutas que contengan esta hueca o sus sucursales
      try {
        final branchesList = (huecaData?['branches'] as List<dynamic>?) ?? [];
        final branchIds = <String>{huecaId};
        for (var b in branchesList) {
          if (b is Map && b['id'] != null) {
            branchIds.add(b['id'].toString());
          }
        }

        final routesSnap = await _db.collection('routes').get();
        for (final rDoc in routesSnap.docs) {
          final rData = rDoc.data();
          final stops = rData['stops'] as List<dynamic>?;
          if (stops != null && stops.isNotEmpty) {
            final filteredStops = stops.where((s) {
              if (s is Map) {
                final sId = s['huecaId']?.toString() ?? s['id']?.toString();
                return sId == null || !branchIds.contains(sId);
              } else if (s is String) {
                return !branchIds.contains(s);
              }
              return true;
            }).toList();

            if (filteredStops.length != stops.length) {
              await rDoc.reference.update({'stops': filteredStops});
            }
          }
        }
      } catch (e) {
        print('Error cleaning routes for hueca: $e');
      }

      // 5. Remover de favoritos y suscripciones de usuarios
      try {
        final favUsers = await _db
            .collection('users')
            .where('favoriteHuecas', arrayContains: huecaId)
            .get();
        for (final uDoc in favUsers.docs) {
          await uDoc.reference.update({
            'favoriteHuecas': FieldValue.arrayRemove([huecaId])
          });
        }
      } catch (_) {}

      try {
        final subUsers = await _db
            .collection('users')
            .where('subscribedHuecas', arrayContains: huecaId)
            .get();
        for (final uDoc in subUsers.docs) {
          await uDoc.reference.update({
            'subscribedHuecas': FieldValue.arrayRemove([huecaId])
          });
        }
      } catch (_) {}

      // 6. Si el propietario tenía rol 'business', cambiarlo a 'user'
      if (ownerId != null && ownerId.isNotEmpty) {
        try {
          await _db.collection('users').doc(ownerId).update({
            'role': 'user',
          });
        } catch (e) {
          print('Error resetting owner role: $e');
        }
      }

      // 7. Eliminar el documento principal de la hueca
      await huecaRef.delete();
    } catch (e) {
      print('Error in deleteHueca: $e');
      rethrow;
    }
  }

  /// Recalcula en tiempo real las métricas reales y fidedignas de una hueca
  /// (favoritos, inclusión en rutas, reseñas de la subcolección y calificación).
  Future<Map<String, dynamic>> syncHuecaMetrics(String huecaId) async {
    try {
      final docRef = _db.collection('huecas').doc(huecaId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        return {
          'favoriteCount': 0,
          'routeAdditions': 0,
          'reviewCount': 0,
          'rating': 0.0,
        };
      }
      final data = docSnap.data() as Map<String, dynamic>? ?? {};

      // 1. Conteo real de favoritos desde la colección users
      int realFavs = 0;
      final branchesList = (data['branches'] as List<dynamic>?) ?? [];
      final branchIds = <String>{huecaId};
      for (var b in branchesList) {
        if (b is Map && b['id'] != null && b['id'].toString().isNotEmpty) {
          branchIds.add(b['id'].toString());
        }
      }

      try {
        if (branchIds.length > 1) {
          final favSnap = await _db
              .collection('users')
              .where('favoriteHuecas', arrayContainsAny: branchIds.take(10).toList())
              .get();
          realFavs = favSnap.docs.length;
        } else {
          final favSnap = await _db
              .collection('users')
              .where('favoriteHuecas', arrayContains: huecaId)
              .get();
          realFavs = favSnap.docs.length;
        }
      } catch (e) {
        try {
          final favSnap = await _db
              .collection('users')
              .where('favoriteHuecas', arrayContains: huecaId)
              .get();
          realFavs = favSnap.docs.length;
        } catch (_) {
          realFavs = (data['metrics']?['favoriteCount'] as int?) ?? 0;
        }
      }

      // 2. Conteo real de rutas que contienen esta hueca o sus sucursales
      int realRoutes = 0;
      try {
        final routesSnap = await _db.collection('routes').get();
        final huecaName = (data['name']?.toString() ?? '').toLowerCase().trim();

        for (var rDoc in routesSnap.docs) {
          final rData = rDoc.data();
          final stops = rData['stops'] as List<dynamic>?;
          if (stops != null) {
            final hasHueca = stops.any((s) {
              if (s is Map) {
                final sHuecaId = s['huecaId']?.toString() ?? s['id']?.toString();
                if (sHuecaId != null && branchIds.contains(sHuecaId)) return true;
                final sName = (s['name']?.toString() ?? s['huecaName']?.toString())?.toLowerCase().trim();
                if (sName != null && sName.isNotEmpty && huecaName.isNotEmpty && (sName == huecaName || huecaName.contains(sName))) {
                  return true;
                }
              } else if (s is String) {
                if (branchIds.contains(s)) return true;
              }
              return false;
            });
            if (hasHueca) realRoutes++;
          }
        }
      } catch (e) {
        realRoutes = (data['metrics']?['routeAdditions'] as int?) ?? 0;
      }

      // 3. Conteo real de reseñas y calificación desde subcolección reviews
      int realReviews = 0;
      double realRating = 0.0;
      try {
        final revSnap = await docRef.collection('reviews').get();
        realReviews = revSnap.docs.length;
        if (realReviews > 0) {
          final sum = revSnap.docs.fold<num>(0, (prev, d) {
            final rData = d.data();
            return prev + (rData['rating'] as num? ?? 0);
          });
          realRating = double.parse((sum / realReviews).toStringAsFixed(1));
        }
      } catch (e) {
        realReviews = (data['reviewCount'] as int?) ?? 0;
        realRating = (data['rating'] as num?)?.toDouble() ?? 0.0;
      }

      // 4. Actualizar el documento en Firestore para corregir cualquier valor quemado
      await docRef.set({
        'metrics': {
          'favoriteCount': realFavs,
          'routeAdditions': realRoutes,
        },
        'reviewCount': realReviews,
        'rating': realRating,
      }, SetOptions(merge: true));

      return {
        'favoriteCount': realFavs,
        'routeAdditions': realRoutes,
        'reviewCount': realReviews,
        'rating': realRating,
      };
    } catch (e) {
      print('Error in syncHuecaMetrics: $e');
      return {
        'favoriteCount': 0,
        'routeAdditions': 0,
        'reviewCount': 0,
        'rating': 0.0,
      };
    }
  }

  /// ADMIN: Stream en tiempo real de todas las huecas
  Stream<List<Hueca>> streamAllHuecas() {
    return _db.collection('huecas').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Hueca.fromFirestore(doc)).toList();
    });
  }

  /// ADMIN: Activar o desactivar hueca (visibilidad en la app)
  Future<void> toggleHuecaActive(String huecaId, bool isActive) async {
    await _db.collection('huecas').doc(huecaId).update({'isActive': isActive});
  }

  /// ADMIN: Asignar o transferir dueño a una hueca con garantía estricta 1-a-1
  Future<void> assignHuecaOwner(String huecaId, String newOwnerId) async {
    final cleanOwnerId = newOwnerId.trim();

    // 1. Obtener el dueño actual de la hueca para desvincularlo si cambia
    try {
      final currentHuecaDoc = await _db.collection('huecas').doc(huecaId).get();
      if (currentHuecaDoc.exists) {
        final prevOwnerId = currentHuecaDoc.data()?['ownerId'] as String?;
        if (prevOwnerId != null && prevOwnerId.isNotEmpty && prevOwnerId != cleanOwnerId) {
          await _db.collection('users').doc(prevOwnerId).update({
            'managedHuecaId': FieldValue.delete(),
          });
        }
      }
    } catch (e) {
      print('Error cleaning previous owner of hueca $huecaId: $e');
    }

    if (cleanOwnerId.isNotEmpty) {
      // 2. Si el nuevo dueño ya administraba otra hueca previamente, desvincularlo de ella (1-a-1)
      try {
        final otherHuecas = await _db
            .collection('huecas')
            .where('ownerId', isEqualTo: cleanOwnerId)
            .get();
        for (final doc in otherHuecas.docs) {
          if (doc.id != huecaId) {
            await doc.reference.update({'ownerId': ''});
          }
        }
      } catch (e) {
        print('Error unlinking cleanOwnerId from other huecas: $e');
      }

      // 3. Asignar la hueca al nuevo dueño y actualizar rol y managedHuecaId en su perfil
      await _db.collection('huecas').doc(huecaId).update({'ownerId': cleanOwnerId});
      await _db.collection('users').doc(cleanOwnerId).set({
        'role': 'business',
        'managedHuecaId': huecaId,
      }, SetOptions(merge: true));
    } else {
      // 4. Si se pasa vacío, desvincular el dueño de la hueca
      await _db.collection('huecas').doc(huecaId).update({'ownerId': ''});
    }
  }

  /// ADMIN: Crear o actualizar hueca completa
  Future<void> saveHueca(Map<String, dynamic> huecaData) async {
    final String id = (huecaData['id'] != null && huecaData['id'].toString().isNotEmpty)
        ? huecaData['id'].toString()
        : _db.collection('huecas').doc().id;
    huecaData['id'] = id;
    await _db.collection('huecas').doc(id).set(huecaData, SetOptions(merge: true));
  }

  /// ADMIN: Eliminar reseña y recalcular métricas de la hueca
  Future<void> deleteReview(String huecaId, String reviewId) async {
    await _db.collection('huecas').doc(huecaId).collection('reviews').doc(reviewId).delete();
    try {
      final revSnap = await _db.collection('huecas').doc(huecaId).collection('reviews').get();
      final count = revSnap.docs.length;
      double avg = 0.0;
      if (count > 0) {
        final sum = revSnap.docs.fold<num>(0, (prev, d) => prev + (d.data()['rating'] as num? ?? 0));
        avg = double.parse((sum / count).toStringAsFixed(1));
      }
      await _db.collection('huecas').doc(huecaId).update({
        'reviewCount': count,
        'rating': avg,
      });
    } catch (e) {
      print('Error recalculating reviews after deletion: $e');
    }
  }

  /// ADMIN: Obtener reseñas globales de todas las huecas
  Future<List<Review>> getGlobalReviews({int limit = 50}) async {
    try {
      final snapshot = await _db
          .collectionGroup('reviews')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting global reviews: $e');
      return [];
    }
  }
}

class Review {
  final String id;
  final String huecaId;
  final int rating;
  final String comment;
  final String userName;
  final String userPic;
  final DateTime? createdAt;

  Review({
    this.id = '',
    this.huecaId = '',
    required this.rating,
    required this.comment,
    required this.userName,
    required this.userPic,
    this.createdAt,
  });

  factory Review.fromFirestore(DocumentSnapshot doc, {String huecaId = ''}) {
    Map data = doc.data() as Map<String, dynamic>;
    String hId = huecaId;
    if (hId.isEmpty) {
      try {
        hId = doc.reference.parent.parent?.id ?? '';
      } catch (_) {}
    }
    return Review(
      id: doc.id,
      huecaId: hId,
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      comment: data['comment'] ?? '',
      userName: data['userName'] ?? 'Anónimo',
      userPic: data['userPic'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
