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
  final List<String> searchTags;
  final String priceLevel;
  final double rating;
  final int reviewCount;
  final List<String> images;
  final String ownerId;
  final bool isActive;
  final bool isSectorConfirmed;
  final Map<String, dynamic> metrics;
  final List<HuecaBranch> branches;
  final Map<String, dynamic> subscription;

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
    this.searchTags = const [],
    required this.priceLevel,
    required this.rating,
    required this.reviewCount,
    required this.images,
    required this.ownerId,
    required this.isActive,
    this.isSectorConfirmed = false,
    required this.metrics,
    this.branches = const [],
    this.subscription = const {},
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

  /// Limpia y normaliza cadenas para búsqueda (sin acentos, minúsculas, sin espacios extra)
  static String normalizeSearchString(String str) {
    return str
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('ü', 'u');
  }

  static const Set<String> _stopWords = {
    'de', 'del', 'la', 'el', 'los', 'las', 'un', 'una', 'unos', 'unas',
    'con', 'sin', 'y', 'en', 'para', 'por', 'al', 'a', 'o', 'e', 'u',
    'su', 'sus', 'mi', 'mis', 'tu', 'tus', 'muy', 'mas', 'que', 'se',
    'lo', 'les', 'nos', 'sobre', 'desde', 'hasta', 'hacia', 'entre',
    'the', 'and', 'with', 'for', 'from', 'in', 'of', 'on', 'at', 'to'
  };

  /// Extrae automáticamente palabras clave y etiquetas de búsqueda a partir del nombre,
  /// especialidad, platos del menú, categorías y descripciones de una hueca.
  static List<String> extractSearchKeywords(Map<String, dynamic> data) {
    final Set<String> keywords = <String>{};

    void addWord(String? raw) {
      if (raw == null) return;
      final clean = normalizeSearchString(raw);
      if (clean.isEmpty) return;

      final words = clean
          .split(RegExp(r'[^a-z0-9]+'))
          .where((w) => w.length >= 3 && !_stopWords.contains(w));

      for (final w in words) {
        keywords.add(w);
        if (w.endsWith('es') && w.length > 4) {
          keywords.add(w.substring(0, w.length - 2));
          keywords.add(w.substring(0, w.length - 1));
        } else if (w.endsWith('s') && w.length > 3) {
          keywords.add(w.substring(0, w.length - 1));
        } else if (!w.endsWith('s')) {
          keywords.add('${w}s');
          keywords.add('${w}es');
        }
      }

      final wordList = words.toList();
      if (wordList.length >= 2 && wordList.length <= 3) {
        keywords.add(wordList.join(' '));
      }
    }

    // 1. Tags existentes
    final rawTags = data['tags'];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t != null) {
          keywords.add(normalizeSearchString(t.toString()));
          addWord(t.toString());
        }
      }
    }

    // 2. Nombre de la hueca
    addWord(data['name']?.toString());

    // 3. Sector y dirección
    addWord(data['sector']?.toString());
    addWord(data['address']?.toString());

    // 4. Plato insignia (mainDish)
    final mainDish = data['mainDish'];
    if (mainDish is Map) {
      final nameVal = mainDish['name'];
      if (nameVal is Map) {
        nameVal.forEach((_, v) => addWord(v?.toString()));
      } else {
        addWord(nameVal?.toString());
      }
      addWord(mainDish['nameEn']?.toString());

      final descVal = mainDish['description'];
      if (descVal is Map) {
        descVal.forEach((_, v) => addWord(v?.toString()));
      } else {
        addWord(descVal?.toString());
      }
      addWord(mainDish['descriptionEn']?.toString());
      addWord(mainDish['category']?.toString());
    }

    // 5. Todos los platos del menú (menuItems)
    final menuItems = data['menuItems'];
    if (menuItems is List) {
      for (final item in menuItems) {
        if (item is Map) {
          final iName = item['name'];
          if (iName is Map) {
            iName.forEach((_, v) => addWord(v?.toString()));
          } else {
            addWord(iName?.toString());
          }
          addWord(item['nameEn']?.toString());

          final iDesc = item['description'];
          if (iDesc is Map) {
            iDesc.forEach((_, v) => addWord(v?.toString()));
          } else {
            addWord(iDesc?.toString());
          }
          addWord(item['descriptionEn']?.toString());
          addWord(item['category']?.toString());

          final itemTags = item['tags'];
          if (itemTags is List) {
            for (final it in itemTags) {
              addWord(it?.toString());
            }
          }
        }
      }
    }

    // 6. Sucursales
    final branches = data['branches'];
    if (branches is List) {
      for (final b in branches) {
        if (b is Map) {
          addWord(b['name']?.toString());
          addWord(b['sector']?.toString());
        }
      }
    }

    // 7. Descripción
    final desc = data['description'];
    if (desc is Map) {
      desc.forEach((_, v) => addWord(v?.toString()));
    } else {
      addWord(desc?.toString());
    }

    return keywords.where((k) => k.trim().isNotEmpty).toList();
  }

  /// Comprueba si la hueca coincide con un término de búsqueda (revisa nombre, especialidad,
  /// platos del menú, categorías, descripciones, sucursales y tags).
  bool matchesSearch(String query, {String lang = 'es', bool checkVariations = true}) {
    final cleanQuery = normalizeSearchString(query);
    if (cleanQuery.isEmpty) return true;

    // Tokens para búsqueda multi-palabra (ej. 'hamburguesa doble')
    final queryTokens = cleanQuery
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    // 1. Coincidencia directa en nombre, sector o dirección
    if (normalizeSearchString(name).contains(cleanQuery)) return true;
    if (normalizeSearchString(sector).contains(cleanQuery)) return true;
    if (normalizeSearchString(address).contains(cleanQuery)) return true;

    // 2. Coincidencia en tags y searchTags
    for (final t in tags) {
      if (normalizeSearchString(t).contains(cleanQuery)) return true;
    }
    for (final st in searchTags) {
      if (normalizeSearchString(st).contains(cleanQuery)) return true;
    }

    // 3. Coincidencia en plato insignia (mainDish)
    if (mainDish.isNotEmpty) {
      final nameVal = mainDish['name'];
      if (nameVal is Map) {
        for (final v in nameVal.values) {
          if (v != null && normalizeSearchString(v.toString()).contains(cleanQuery)) return true;
        }
      } else if (nameVal != null && normalizeSearchString(nameVal.toString()).contains(cleanQuery)) {
        return true;
      }
      if (mainDish['nameEn'] != null && normalizeSearchString(mainDish['nameEn'].toString()).contains(cleanQuery)) {
        return true;
      }

      final descVal = mainDish['description'];
      if (descVal is Map) {
        for (final v in descVal.values) {
          if (v != null && normalizeSearchString(v.toString()).contains(cleanQuery)) return true;
        }
      } else if (descVal != null && normalizeSearchString(descVal.toString()).contains(cleanQuery)) {
        return true;
      }
      if (mainDish['descriptionEn'] != null && normalizeSearchString(mainDish['descriptionEn'].toString()).contains(cleanQuery)) {
        return true;
      }
      if (mainDish['category'] != null && normalizeSearchString(mainDish['category'].toString()).contains(cleanQuery)) {
        return true;
      }
    }

    // 4. Coincidencia directa en CADA plato del menú (menuItems)
    for (final item in menuItems) {
      if (item is Map) {
        final itemName = item['name'];
        if (itemName is Map) {
          for (final v in itemName.values) {
            if (v != null && normalizeSearchString(v.toString()).contains(cleanQuery)) return true;
          }
        } else if (itemName != null && normalizeSearchString(itemName.toString()).contains(cleanQuery)) {
          return true;
        }
        if (item['nameEn'] != null && normalizeSearchString(item['nameEn'].toString()).contains(cleanQuery)) {
          return true;
        }

        final itemDesc = item['description'];
        if (itemDesc is Map) {
          for (final v in itemDesc.values) {
            if (v != null && normalizeSearchString(v.toString()).contains(cleanQuery)) return true;
          }
        } else if (itemDesc != null && normalizeSearchString(itemDesc.toString()).contains(cleanQuery)) {
          return true;
        }
        if (item['descriptionEn'] != null && normalizeSearchString(item['descriptionEn'].toString()).contains(cleanQuery)) {
          return true;
        }

        if (item['category'] != null && normalizeSearchString(item['category'].toString()).contains(cleanQuery)) {
          return true;
        }
        if (item['tags'] is List) {
          for (final t in (item['tags'] as List)) {
            if (t != null && normalizeSearchString(t.toString()).contains(cleanQuery)) return true;
          }
        }
      }
    }

    // 5. Coincidencia en descripciones de la hueca
    for (final v in description.values) {
      if (v != null && normalizeSearchString(v.toString()).contains(cleanQuery)) return true;
    }

    // 6. Coincidencia en sucursales
    for (final b in allBranches) {
      if (normalizeSearchString(b.name).contains(cleanQuery)) return true;
      if (normalizeSearchString(b.sector).contains(cleanQuery)) return true;
      if (normalizeSearchString(b.address).contains(cleanQuery)) return true;
    }

    // 7. Búsqueda multi-palabra: Si todos los tokens coinciden en alguna parte de la hueca
    if (queryTokens.length > 1) {
      final allTokensMatched = queryTokens.every((token) => matchesSearch(token, lang: lang, checkVariations: false));
      if (allTokensMatched) return true;
    }

    // 8. Tolerancia singular / plural (ej. usuario busca 'hamburguesas' o 'camarones')
    if (checkVariations) {
      if (cleanQuery.endsWith('es') && cleanQuery.length > 4) {
        final singularEs = cleanQuery.substring(0, cleanQuery.length - 2);
        if (matchesSearch(singularEs, lang: lang, checkVariations: false)) return true;
        final singularS = cleanQuery.substring(0, cleanQuery.length - 1);
        if (matchesSearch(singularS, lang: lang, checkVariations: false)) return true;
      } else if (cleanQuery.endsWith('s') && cleanQuery.length > 3) {
        final singular = cleanQuery.substring(0, cleanQuery.length - 1);
        if (matchesSearch(singular, lang: lang, checkVariations: false)) return true;
      } else if (!cleanQuery.endsWith('s')) {
        final pluralS = '${cleanQuery}s';
        if (matchesSearch(pluralS, lang: lang, checkVariations: false)) return true;
        final pluralEs = '${cleanQuery}es';
        if (matchesSearch(pluralEs, lang: lang, checkVariations: false)) return true;
      }
    }

    return false;
  }

  static bool _parseBool(dynamic val, {bool defaultValue = true}) {
    if (val == null) return defaultValue;
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) {
      final s = val.toLowerCase().trim();
      if (s == 'false' || s == '0' || s == 'no' || s == 'inactive' || s == 'inactiva' || s == 'pausada' || s == 'paused') {
        return false;
      }
      if (s == 'true' || s == '1' || s == 'yes' || s == 'active' || s == 'activa') {
        return true;
      }
    }
    return defaultValue;
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

    final docId = doc.id.trim();
    final dataId = (data['id']?.toString() ?? '').trim();
    final resolvedId = docId.isNotEmpty ? docId : dataId;

    return Hueca(
      id: resolvedId,
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
      searchTags: List<String>.from(data['searchTags'] ?? []),
      priceLevel: data['priceLevel'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      images: List<String>.from(data['images'] ?? []),
      ownerId: data['ownerId'] ?? '',
      isActive: _parseBool(data['isActive']),
      isSectorConfirmed: data['isSectorConfirmed'] ?? (data['isActive'] == true && !data.containsKey('isSectorConfirmed')),
      branches: parsedBranches,
      metrics: data['metrics'] ?? {
        'viewCount': 0,
        'favoriteCount': 0,
        'routeAdditions': 0,
        'stampsGiven': 0,
      },
      subscription: data['subscription'] is Map
          ? Map<String, dynamic>.from(data['subscription'])
          : {},
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
      'searchTags': searchTags,
      'priceLevel': priceLevel,
      'rating': rating,
      'reviewCount': reviewCount,
      'images': images,
      'ownerId': ownerId,
      'isActive': isActive,
      'isSectorConfirmed': isSectorConfirmed,
      'metrics': metrics,
      'branches': branches.map((b) => b.toMap()).toList(),
      'subscription': subscription,
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
    huecaData['searchTags'] = Hueca.extractSearchKeywords(huecaData);
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

      // 6. Si el propietario tenía rol 'business', cambiarlo a 'user' y desvincular hueca
      if (ownerId != null && ownerId.isNotEmpty) {
        try {
          await _db.collection('users').doc(ownerId).update({
            'role': 'user',
            'managedHuecaId': FieldValue.delete(),
            'managedBranchId': FieldValue.delete(),
          });
        } catch (e) {
          print('Error resetting owner role: $e');
        }
      }

      // También revocar rol 'business' a los encargados de sucursales de esta hueca
      final branchesList = (huecaData?['branches'] as List<dynamic>?) ?? [];
      for (var b in branchesList) {
        if (b is Map && b['managerEmail'] != null) {
          final mEmail = b['managerEmail'].toString().trim().toLowerCase();
          if (mEmail.isNotEmpty) {
            try {
              final mSnap = await _db.collection('users').where('email', isEqualTo: mEmail).limit(1).get();
              for (final uDoc in mSnap.docs) {
                await uDoc.reference.update({
                  'role': 'user',
                  'managedHuecaId': FieldValue.delete(),
                  'managedBranchId': FieldValue.delete(),
                });
              }
            } catch (_) {}
          }
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

      // 2. Conteo de veces que los comensales han incluido la hueca en sus tours personalizados
      int realRoutes = (data['metrics']?['routeAdditions'] as int?) ?? 0;
      try {
        final customToursSnap = await _db.collectionGroup('custom_tours').get();
        final huecaName = (data['name']?.toString() ?? '').toLowerCase().trim();
        int customCount = 0;

        for (var rDoc in customToursSnap.docs) {
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
            if (hasHueca) customCount++;
          }
        }
        if (customCount > 0 || customToursSnap.docs.isNotEmpty) {
          realRoutes = customCount;
        }
      } catch (e) {
        // Fallback robusto al contador acumulado en metrics['routeAdditions']
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

  /// ADMIN: Activar o desactivar hueca (visibilidad en la app) con soporte para documentId, dataId y nombre
  Future<void> toggleHuecaActive(String huecaId, bool isActive, {String? huecaName}) async {
    final cleanId = huecaId.trim();
    bool updated = false;

    // 1. Intentar actualizar directamente por Document ID
    if (cleanId.isNotEmpty) {
      try {
        final docRef = _db.collection('huecas').doc(cleanId);
        final docSnap = await docRef.get();
        if (docSnap.exists) {
          await docRef.update({'isActive': isActive});
          updated = true;
        }
      } catch (e) {
        print('Error actualizando por doc ID direct: $e');
      }
    }

    // 2. Si no se actualizó, buscar por campo data['id']
    if (!updated && cleanId.isNotEmpty) {
      try {
        final query = await _db.collection('huecas').where('id', isEqualTo: cleanId).get();
        for (final doc in query.docs) {
          await doc.reference.update({'isActive': isActive});
          updated = true;
        }
      } catch (e) {
        print('Error actualizando por data id: $e');
      }
    }

    // 3. Si no se actualizó, buscar por nombre
    if (!updated) {
      final nameToSearch = (huecaName != null && huecaName.trim().isNotEmpty) ? huecaName.trim() : cleanId;
      if (nameToSearch.isNotEmpty) {
        try {
          final queryName = await _db.collection('huecas').where('name', isEqualTo: nameToSearch).get();
          for (final doc in queryName.docs) {
            await doc.reference.update({'isActive': isActive});
            updated = true;
          }
        } catch (e) {
          print('Error actualizando por name: $e');
        }
      }
    }
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

  /// ADMIN: Crear o actualizar hueca completa (auto-genera tags de búsqueda de menú y platos)
  Future<void> saveHueca(Map<String, dynamic> huecaData) async {
    final String id = (huecaData['id'] != null && huecaData['id'].toString().isNotEmpty)
        ? huecaData['id'].toString()
        : _db.collection('huecas').doc().id;
    huecaData['id'] = id;
    huecaData['searchTags'] = Hueca.extractSearchKeywords(huecaData);
    await _db.collection('huecas').doc(id).set(huecaData, SetOptions(merge: true));
  }

  /// Recalcula y actualiza los searchTags de una hueca en Firestore basándose en sus platos y menú
  Future<void> syncHuecaSearchKeywords(String huecaId) async {
    try {
      final docRef = _db.collection('huecas').doc(huecaId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) return;
      final data = docSnap.data();
      if (data == null) return;
      final searchTags = Hueca.extractSearchKeywords(data);
      await docRef.update({'searchTags': searchTags});
    } catch (e) {
      print('Error in syncHuecaSearchKeywords: $e');
    }
  }

  /// ADMIN: Actualiza el sector de una hueca y opcionalmente marca si está confirmado por el admin
  Future<void> updateHuecaSector(String huecaId, String sector, {bool isConfirmed = true}) async {
    final cleanSector = sector.trim();
    await _db.collection('huecas').doc(huecaId).update({
      'sector': cleanSector,
      'isSectorConfirmed': isConfirmed,
    });
    // Sincronizar palabras clave de búsqueda ya que el sector es un término de búsqueda primario
    await syncHuecaSearchKeywords(huecaId);
  }

  /// ADMIN: Confirmar masivamente sectores de huecas
  Future<void> batchConfirmHuecaSectors(Map<String, String> huecaSectors) async {
    final batch = _db.batch();
    for (final entry in huecaSectors.entries) {
      final docRef = _db.collection('huecas').doc(entry.key);
      batch.update(docRef, {
        'sector': entry.value.trim(),
        'isSectorConfirmed': true,
      });
    }
    await batch.commit();
  }

  /// ADMIN / BUSINESS: Configurar o actualizar el cromo / sticker secreto de una hueca
  Future<void> updateHuecaSecretSticker(String huecaId, Map<String, dynamic> secretSticker) async {
    await _db.collection('huecas').doc(huecaId).update({
      'secretSticker': secretSticker,
    });
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
