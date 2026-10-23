import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String profilePicUrl;
  final Map<String, dynamic> gamification;
  final Map<String, dynamic> preferences;
  final List<dynamic> sectorAlbums;
  final List<String> favoriteHuecas; // will populate later
  final List<String> subscribedHuecas; // huecas for push/local notifications
  final String role;
  final String? managedHuecaId;
  final String? managedBranchId;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.profilePicUrl,
    required this.gamification,
    required this.preferences,
    required this.sectorAlbums,
    this.favoriteHuecas = const [],
    this.subscribedHuecas = const [],
    this.role = 'user',
    this.managedHuecaId,
    this.managedBranchId,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? 'Usuario',
      email: data['email'] ?? '',
      role: data['role'] ?? 'user',
      profilePicUrl: data['profilePicUrl'] ?? 'https://via.placeholder.com/150',
      gamification: data['gamification'] ?? {'totalStamps': 0, 'level': 1, 'title': 'Novato'},
      preferences: data['preferences'] ?? {'favoriteDishes': [], 'dietaryRestrictions': []},
      sectorAlbums: [], // Load separately or assume empty for now
      favoriteHuecas: List<String>.from(data['favoriteHuecas'] ?? []),
      subscribedHuecas: List<String>.from(data['subscribedHuecas'] ?? []),
      managedHuecaId: data['managedHuecaId'] as String?,
      managedBranchId: data['managedBranchId'] as String?,
    );
  }
}

class UserRepository {
  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _firebaseAuth;

  UserRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore,
        _firebaseAuth = auth;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;

  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final docRef = _db.collection('users').doc(user.uid);
      var doc = await docRef.get();
      
      if (!doc.exists) {
        // Create the user document with default values
        await docRef.set({
          'uid': user.uid,
          'name': user.displayName ?? 'Usuario',
          'email': user.email ?? '',
          'role': 'user',
          'profilePicUrl': user.photoURL ?? 'https://ui-avatars.com/api/?name=${user.displayName ?? 'Usuario'}&background=random',
          'gamification': {'totalStamps': 0, 'level': 1, 'title': 'Novato'},
          'preferences': {'favoriteDishes': [], 'dietaryRestrictions': []},
          'favoriteHuecas': [],
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        doc = await docRef.get();
      }
      
      if (doc.exists) {
        UserModel userModel = UserModel.fromFirestore(doc);

        // If Firestore had a placeholder name/pic, but Google Auth has real name/photo, sync them!
        final googleName = user.displayName;
        final googlePhoto = user.photoURL;
        final bool shouldUpdateName = googleName != null &&
            googleName.trim().isNotEmpty &&
            (userModel.name == 'Usuario' || userModel.name == 'Invitado' || userModel.name.trim().isEmpty);
        final bool shouldUpdatePhoto = googlePhoto != null &&
            googlePhoto.trim().isNotEmpty &&
            (userModel.profilePicUrl.isEmpty ||
                userModel.profilePicUrl.contains('placeholder') ||
                userModel.profilePicUrl.contains('ui-avatars'));

        if (shouldUpdateName || shouldUpdatePhoto) {
          final updates = <String, dynamic>{};
          if (shouldUpdateName) updates['name'] = googleName;
          if (shouldUpdatePhoto) updates['profilePicUrl'] = googlePhoto;
          if (user.email != null && user.email!.isNotEmpty && userModel.email.isEmpty) {
            updates['email'] = user.email;
          }
          try {
            await docRef.set(updates, SetOptions(merge: true));
            userModel = UserModel(
              uid: userModel.uid,
              name: shouldUpdateName ? googleName : userModel.name,
              email: updates.containsKey('email') ? user.email! : userModel.email,
              role: userModel.role,
              profilePicUrl: shouldUpdatePhoto ? googlePhoto : userModel.profilePicUrl,
              gamification: userModel.gamification,
              preferences: userModel.preferences,
              sectorAlbums: userModel.sectorAlbums,
              favoriteHuecas: userModel.favoriteHuecas,
              subscribedHuecas: userModel.subscribedHuecas,
              managedHuecaId: userModel.managedHuecaId,
              managedBranchId: userModel.managedBranchId,
            );
          } catch (_) {}
        }

        // Also fetch sector albums safely
        try {
          final albums = await _db.collection('users').doc(user.uid).collection('sector_albums').get();
          userModel.sectorAlbums.addAll(albums.docs.map((d) => d.data()).toList());
        } catch (albumError) {
          print('Warning: error fetching sector albums: $albumError');
        }

        return userModel;
      }
    } catch (e) {
      print('Error fetching user: $e');
    }

    // Resilient fallback: If Firebase Auth is authenticated, NEVER return null (which drops to guest mode)!
    return UserModel(
      uid: user.uid,
      name: (user.displayName != null && user.displayName!.trim().isNotEmpty) ? user.displayName! : 'Usuario',
      email: user.email ?? '',
      role: 'user',
      profilePicUrl: user.photoURL ?? 'https://ui-avatars.com/api/?name=${user.displayName ?? 'Usuario'}&background=random',
      gamification: {'totalStamps': 0, 'level': 1, 'title': 'Novato'},
      preferences: {'favoriteDishes': [], 'dietaryRestrictions': []},
      sectorAlbums: [],
      favoriteHuecas: [],
    );
  }
  
  Future<void> toggleFavorite(String huecaId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final currentFavs = List<String>.from(data['favoriteHuecas'] ?? []);
      final bool wasFavorite = currentFavs.contains(huecaId);
      if (wasFavorite) {
        currentFavs.remove(huecaId);
      } else {
        currentFavs.add(huecaId);
      }
      await docRef.update({'favoriteHuecas': currentFavs});

      // Synchronize favoriteCount in the hueca document
      try {
        final countSnap = await _db
            .collection('users')
            .where('favoriteHuecas', arrayContains: huecaId)
            .get();
        try {
          await _db.collection('huecas').doc(huecaId).update({
            'metrics.favoriteCount': countSnap.docs.length,
          });
        } catch (_) {
          await _db.collection('huecas').doc(huecaId).set({
            'metrics': {
              'favoriteCount': countSnap.docs.length,
            }
          }, SetOptions(merge: true));
        }
      } catch (e) {
        try {
          await _db.collection('huecas').doc(huecaId).update({
            'metrics.favoriteCount': FieldValue.increment(wasFavorite ? -1 : 1),
          });
        } catch (_) {}
      }
    }
  }

  Future<void> toggleNotificationSubscription(String huecaId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final currentSubs = List<String>.from(data['subscribedHuecas'] ?? []);
      if (currentSubs.contains(huecaId)) {
        currentSubs.remove(huecaId);
      } else {
        currentSubs.add(huecaId);
      }
      await docRef.update({'subscribedHuecas': currentSubs});
    }
  }

  Future<void> updateRole(String newRole) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({
      'role': newRole,
    });
  }

  Future<void> updatePreferences(Map<String, dynamic> newPrefs) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({
      'preferences': newPrefs
    });
  }

  /// ADMIN: Stream de todos los usuarios (deduplicados por correo)
  Stream<List<UserModel>> streamAllUsers() {
    return _db.collection('users').snapshots().map((snapshot) {
      final Map<String, UserModel> usersByEmail = {};
      for (final doc in snapshot.docs) {
        final user = UserModel.fromFirestore(doc);
        final emailKey = user.email.trim().toLowerCase();
        if (emailKey.isEmpty) {
          usersByEmail[user.uid] = user;
          continue;
        }
        if (!usersByEmail.containsKey(emailKey)) {
          usersByEmail[emailKey] = user;
        } else {
          // Si hay duplicados con el mismo correo: preferir el UID real de Firebase Auth
          final existing = usersByEmail[emailKey]!;
          final existingIsEmailId = existing.uid.contains('@');
          final userIsEmailId = user.uid.contains('@');
          if (existingIsEmailId && !userIsEmailId) {
            usersByEmail[emailKey] = user;
          } else if (!existingIsEmailId && userIsEmailId) {
            // mantener el existente
          } else if (existing.name == 'Usuario' && user.name.isNotEmpty && user.name != 'Usuario') {
            usersByEmail[emailKey] = user;
          }
        }
      }
      return usersByEmail.values.toList();
    });
  }

  /// ADMIN: Obtener todos los usuarios (deduplicados por correo)
  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await _db.collection('users').get();
    final Map<String, UserModel> usersByEmail = {};
    for (final doc in snapshot.docs) {
      final user = UserModel.fromFirestore(doc);
      final emailKey = user.email.trim().toLowerCase();
      if (emailKey.isEmpty) {
        usersByEmail[user.uid] = user;
        continue;
      }
      if (!usersByEmail.containsKey(emailKey)) {
        usersByEmail[emailKey] = user;
      } else {
        final existing = usersByEmail[emailKey]!;
        if (existing.uid.contains('@') && !user.uid.contains('@')) {
          usersByEmail[emailKey] = user;
        } else if (existing.name == 'Usuario' && user.name.isNotEmpty && user.name != 'Usuario') {
          usersByEmail[emailKey] = user;
        }
      }
    }
    return usersByEmail.values.toList();
  }

  /// ADMIN: Cambiar rol de cualquier usuario
  Future<void> updateUserRoleByAdmin(String uid, String newRole) async {
    final updates = <String, dynamic>{'role': newRole};
    if (newRole != 'business') {
      updates['managedHuecaId'] = FieldValue.delete();
      updates['managedBranchId'] = FieldValue.delete();
      // Si deja de ser negocio, desvincular cualquier hueca que tuviese asignada
      try {
        final ownedHuecas = await _db
            .collection('huecas')
            .where('ownerId', isEqualTo: uid)
            .get();
        for (final doc in ownedHuecas.docs) {
          await doc.reference.update({'ownerId': ''});
        }
      } catch (e) {
        print('Error clearing owned huecas for user $uid: $e');
      }
    }
    await _db.collection('users').doc(uid).set(updates, SetOptions(merge: true));
  }

  /// ADMIN: Asignar o desvincular hueca administrada a un usuario de negocio (Dueño General)
  /// Garantiza la regla 1-a-1: Cada cuenta de negocio solo puede estar asignada a 1 hueca/local.
  Future<void> assignHuecaToBusinessUser(String uid, String? huecaId) async {
    final cleanHuecaId = (huecaId != null && huecaId.trim().isNotEmpty) ? huecaId.trim() : null;

    // Obtener correo del usuario para desvincular de sucursales si tuviese alguna
    String userEmail = '';
    try {
      final uDoc = await _db.collection('users').doc(uid).get();
      userEmail = (uDoc.data()?['email'] ?? '').toString().trim().toLowerCase();
    } catch (_) {}

    // 1. Desvincular al usuario de cualquier otra hueca que tuviese asignada previamente como dueño
    try {
      final prevHuecas = await _db
          .collection('huecas')
          .where('ownerId', isEqualTo: uid)
          .get();
      for (final doc in prevHuecas.docs) {
        if (doc.id != cleanHuecaId) {
          await doc.reference.update({'ownerId': ''});
        }
      }
    } catch (e) {
      print('Error cleaning previous huecas for user $uid: $e');
    }

    // 2. Desvincular de sucursales si tenía alguna asignada (regla 1-a-1)
    if (userEmail.isNotEmpty) {
      try {
        final allHuecas = await _db.collection('huecas').get();
        for (final doc in allHuecas.docs) {
          final rawBranches = doc.data()['branches'] as List<dynamic>?;
          if (rawBranches != null && rawBranches.isNotEmpty) {
            bool changed = false;
            final updatedBranches = rawBranches.map((b) {
              final bm = Map<String, dynamic>.from(b as Map);
              if (bm['managerEmail']?.toString().trim().toLowerCase() == userEmail) {
                bm.remove('managerEmail');
                changed = true;
              }
              return bm;
            }).toList();
            if (changed) {
              await doc.reference.update({'branches': updatedBranches});
            }
          }
        }
      } catch (_) {}
    }

    if (cleanHuecaId != null) {
      // 3. Si la nueva hueca tenía otro dueño anterior, desvincular a ese dueño anterior
      try {
        final targetDoc = await _db.collection('huecas').doc(cleanHuecaId).get();
        if (targetDoc.exists) {
          final oldOwnerId = targetDoc.data()?['ownerId'] as String?;
          if (oldOwnerId != null && oldOwnerId.isNotEmpty && oldOwnerId != uid) {
            await _db.collection('users').doc(oldOwnerId).update({
              'managedHuecaId': FieldValue.delete(),
              'managedBranchId': FieldValue.delete(),
            });
          }
        }
      } catch (e) {
        print('Error unlinking old owner of hueca $cleanHuecaId: $e');
      }

      // 4. Asignar la hueca al usuario
      await _db.collection('huecas').doc(cleanHuecaId).update({'ownerId': uid});
      await _db.collection('users').doc(uid).set({
        'role': 'business',
        'managedHuecaId': cleanHuecaId,
        'managedBranchId': FieldValue.delete(),
      }, SetOptions(merge: true));
    } else {
      // Desvinculación de hueca
      await _db.collection('users').doc(uid).update({
        'managedHuecaId': FieldValue.delete(),
        'managedBranchId': FieldValue.delete(),
      });
    }
  }

  /// ADMIN: Asignar un usuario de negocio a una sucursal específica de una hueca
  /// Respeta la regla de 1-a-1: Si el usuario era dueño de una hueca o encargado de otro local,
  /// se desvinculan las asignaciones previas.
  Future<void> assignBranchToBusinessUser({
    required String uid,
    required String email,
    required String huecaId,
    required String branchId,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Desvincular de cualquier hueca donde sea dueño general
    try {
      final prevHuecas = await _db
          .collection('huecas')
          .where('ownerId', isEqualTo: uid)
          .get();
      for (final doc in prevHuecas.docs) {
        await doc.reference.update({'ownerId': ''});
      }
    } catch (e) {
      print('Error unlinking previous hueca owner: $e');
    }

    // 2. Desvincular este correo de cualquier otra sucursal y asignar a la sucursal deseada
    try {
      final allHuecas = await _db.collection('huecas').get();
      for (final doc in allHuecas.docs) {
        final data = doc.data();
        final rawBranches = data['branches'] as List<dynamic>?;
        if (rawBranches != null && rawBranches.isNotEmpty) {
          bool changed = false;
          final updatedBranches = rawBranches.map((b) {
            final bm = Map<String, dynamic>.from(b as Map);
            final currentManager = bm['managerEmail']?.toString().trim().toLowerCase();
            if (doc.id == huecaId && bm['id'] == branchId) {
              bm['managerEmail'] = cleanEmail;
              changed = true;
            } else if (currentManager == cleanEmail) {
              bm.remove('managerEmail');
              changed = true;
            }
            return bm;
          }).toList();
          if (changed) {
            await doc.reference.update({'branches': updatedBranches});
          }
        }
      }
    } catch (e) {
      print('Error assigning branch to user: $e');
    }

    // 3. Actualizar documento del usuario
    await _db.collection('users').doc(uid).set({
      'role': 'business',
      'managedHuecaId': huecaId,
      'managedBranchId': branchId,
    }, SetOptions(merge: true));
  }

  /// ADMIN: Desvincular completamente una cuenta de negocio de cualquier hueca y sucursal
  Future<void> unassignBusinessUser(String uid, String email) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Quitar dueño general
    try {
      final prevHuecas = await _db
          .collection('huecas')
          .where('ownerId', isEqualTo: uid)
          .get();
      for (final doc in prevHuecas.docs) {
        await doc.reference.update({'ownerId': ''});
      }
    } catch (_) {}

    // 2. Quitar de cualquier sucursal
    try {
      final allHuecas = await _db.collection('huecas').get();
      for (final doc in allHuecas.docs) {
        final rawBranches = doc.data()['branches'] as List<dynamic>?;
        if (rawBranches != null && rawBranches.isNotEmpty) {
          bool changed = false;
          final updatedBranches = rawBranches.map((b) {
            final bm = Map<String, dynamic>.from(b as Map);
            if (bm['managerEmail']?.toString().trim().toLowerCase() == cleanEmail) {
              bm.remove('managerEmail');
              changed = true;
            }
            return bm;
          }).toList();
          if (changed) {
            await doc.reference.update({'branches': updatedBranches});
          }
        }
      }
    } catch (_) {}

    // 3. Limpiar documento de usuario
    await _db.collection('users').doc(uid).update({
      'managedHuecaId': FieldValue.delete(),
      'managedBranchId': FieldValue.delete(),
    });
  }

  /// ADMIN: Eliminar completamente una cuenta de usuario del sistema
  /// REGLA ESTRICTA: La hueca o sucursal asociada NUNCA se elimina. Solo se
  /// desvincula y queda en estado sin administrador para futura reasignación.
  Future<void> deleteUser(String uid, {String? email}) async {
    final cleanEmail = (email ?? '').trim().toLowerCase();

    // 1. Desvincular de huecas generales donde sea ownerId
    try {
      final prevHuecas = await _db
          .collection('huecas')
          .where('ownerId', isEqualTo: uid)
          .get();
      for (final doc in prevHuecas.docs) {
        await doc.reference.update({'ownerId': ''});
      }
    } catch (e) {
      print('Aviso desvinculando ownerId en deleteUser: $e');
    }

    // 2. Desvincular de sucursales donde su email sea managerEmail
    if (cleanEmail.isNotEmpty) {
      try {
        final allHuecas = await _db.collection('huecas').get();
        for (final doc in allHuecas.docs) {
          final rawBranches = doc.data()['branches'] as List<dynamic>?;
          if (rawBranches != null && rawBranches.isNotEmpty) {
            bool changed = false;
            final updatedBranches = rawBranches.map((b) {
              final bm = Map<String, dynamic>.from(b as Map);
              if (bm['managerEmail']?.toString().trim().toLowerCase() == cleanEmail) {
                bm.remove('managerEmail');
                changed = true;
              }
              return bm;
            }).toList();
            if (changed) {
              await doc.reference.update({'branches': updatedBranches});
            }
          }
        }
      } catch (e) {
        print('Aviso desvinculando managerEmail en deleteUser: $e');
      }

      // 3. Eliminar invitaciones de sucursal pendientes para este correo
      try {
        await _db.collection('branch_invitations').doc(cleanEmail).delete();
      } catch (_) {}
    }

    // 4. Eliminar documento del usuario en Firestore
    await _db.collection('users').doc(uid).delete();
  }

  /// ADMIN: Crear o actualizar cuenta de usuario con rol 'business' desde el panel de admin o aprobación de solicitud.
  /// Si el correo ya pertenece a un usuario registrado (ej. ingresó con Google o creó cuenta como comensal),
  /// se limpia su historial antiguo de cliente (favoritos, álbumes, etc.) y se transforma su cuenta para
  /// que gestione la hueca sin provocar error de correo duplicado.
  /// Si es una cuenta nueva, genera una clave temporal segura y envía el correo para definir contraseña.
  Future<UserModel> createBusinessAccount({
    required String name,
    required String email,
    String? password,
    String? assignedHuecaId,
    String? assignedBranchId,
    String? preferredUid,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Verificar si ya existe un usuario en Firestore con este UID o email
    String? targetUid = (preferredUid != null && preferredUid.isNotEmpty && !preferredUid.startsWith('anon_'))
        ? preferredUid
        : null;

    if (targetUid != null) {
      final docCheck = await _db.collection('users').doc(targetUid).get();
      if (!docCheck.exists) {
        targetUid = null;
      }
    }

    if (targetUid == null) {
      // Buscar por email exacto (minúsculas)
      final snap = await _db
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        targetUid = snap.docs.first.id;
      } else {
        // Búsqueda case-insensitive por si se guardó con mayúsculas
        try {
          final allUsers = await _db.collection('users').get();
          for (final doc in allUsers.docs) {
            final userEmail = doc.data()['email']?.toString().trim().toLowerCase();
            if (userEmail == cleanEmail) {
              targetUid = doc.id;
              break;
            }
          }
        } catch (_) {}
      }
    }

    // 2. Si ya existe el usuario: Limpiar datos antiguos de explorador/comensal y convertirlo a business
    if (targetUid != null) {
      // Limpiar álbumes antiguos de explorador en subcolección
      try {
        final albumsSnap = await _db.collection('users').doc(targetUid).collection('sector_albums').get();
        for (final albumDoc in albumsSnap.docs) {
          await albumDoc.reference.delete();
        }
      } catch (e) {
        print('Aviso limpiando albumes de explorador: $e');
      }

      // Decrementar métricas de favoritos en las huecas que tenía marcadas
      try {
        final oldDoc = await _db.collection('users').doc(targetUid).get();
        final oldFavs = List<String>.from(oldDoc.data()?['favoriteHuecas'] ?? []);
        for (final fHuecaId in oldFavs) {
          _db.collection('huecas').doc(fHuecaId).set({
            'metrics': {'favoriteCount': FieldValue.increment(-1)}
          }, SetOptions(merge: true));
        }
      } catch (_) {}

      final updatedData = <String, dynamic>{
        'uid': targetUid,
        'name': name.trim(),
        'email': cleanEmail,
        'role': 'business',
        'profilePicUrl': 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name.trim())}&background=0F172A&color=ffffff',
        'gamification': {'totalStamps': 0, 'level': 1, 'title': 'Dueño de Negocio'},
        'preferences': {'favoriteDishes': [], 'dietaryRestrictions': []},
        'favoriteHuecas': [],
        'subscribedHuecas': [],
      };

      if (assignedHuecaId != null && assignedHuecaId.trim().isNotEmpty) {
        updatedData['managedHuecaId'] = assignedHuecaId.trim();
        if (assignedBranchId != null && assignedBranchId.trim().isNotEmpty) {
          updatedData['managedBranchId'] = assignedBranchId.trim();
        } else {
          updatedData['managedBranchId'] = FieldValue.delete();
        }
      }

      await _db.collection('users').doc(targetUid).set(updatedData, SetOptions(merge: true));

      if (assignedHuecaId != null && assignedHuecaId.trim().isNotEmpty) {
        if (assignedBranchId != null && assignedBranchId.trim().isNotEmpty) {
          await assignBranchToBusinessUser(
            uid: targetUid,
            email: cleanEmail,
            huecaId: assignedHuecaId.trim(),
            branchId: assignedBranchId.trim(),
          );
        } else {
          await assignHuecaToBusinessUser(targetUid, assignedHuecaId.trim());
        }
      }

      // Enviar correo de restablecimiento/definición de contraseña por si acaso
      try {
        await _auth.setLanguageCode('es');
        await _auth.sendPasswordResetEmail(email: cleanEmail);
      } catch (e) {
        print('Aviso: No se pudo enviar el correo de definición de contraseña: $e');
      }

      final docSnap = await _db.collection('users').doc(targetUid).get();
      return UserModel.fromFirestore(docSnap);
    }

    // 3. Si NO existe el usuario: Crear nueva cuenta en Firebase Auth con app secundaria
    final tempAppName = 'AdminUserCreator_${DateTime.now().millisecondsSinceEpoch}';
    FirebaseApp? tempApp;
    UserCredential? cred;

    final initialPassword = (password != null && password.trim().isNotEmpty)
        ? password.trim()
        : 'HueQuito_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}!Aa9';

    try {
      tempApp = await Firebase.initializeApp(
        name: tempAppName,
        options: Firebase.app().options,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      cred = await tempAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: initialPassword,
      );

      await cred.user?.updateDisplayName(name.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // En caso de que exista en Auth pero no en Firestore con ese email:
        final existingByEmail = await _db.collection('users').where('email', isEqualTo: cleanEmail).limit(1).get();
        if (existingByEmail.docs.isNotEmpty) {
          return await createBusinessAccount(
            name: name,
            email: email,
            preferredUid: existingByEmail.docs.first.id,
            assignedHuecaId: assignedHuecaId,
            assignedBranchId: assignedBranchId,
          );
        }
      }
      rethrow;
    } finally {
      if (tempApp != null) {
        await tempApp.delete();
      }
    }

    final newUid = cred!.user!.uid;

    final userData = <String, dynamic>{
      'uid': newUid,
      'name': name.trim(),
      'email': cleanEmail,
      'role': 'business',
      'profilePicUrl': 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name.trim())}&background=0F172A&color=ffffff',
      'gamification': {'totalStamps': 0, 'level': 1, 'title': 'Dueño de Negocio'},
      'preferences': {'favoriteDishes': [], 'dietaryRestrictions': []},
      'favoriteHuecas': [],
      'subscribedHuecas': [],
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (assignedHuecaId != null && assignedHuecaId.trim().isNotEmpty) {
      userData['managedHuecaId'] = assignedHuecaId.trim();
      if (assignedBranchId != null && assignedBranchId.trim().isNotEmpty) {
        userData['managedBranchId'] = assignedBranchId.trim();
      }
    }

    await _db.collection('users').doc(newUid).set(userData);

    if (assignedHuecaId != null && assignedHuecaId.trim().isNotEmpty) {
      if (assignedBranchId != null && assignedBranchId.trim().isNotEmpty) {
        await assignBranchToBusinessUser(
          uid: newUid,
          email: cleanEmail,
          huecaId: assignedHuecaId.trim(),
          branchId: assignedBranchId.trim(),
        );
      } else {
        await assignHuecaToBusinessUser(newUid, assignedHuecaId.trim());
      }
    }

    // Enviar correo para que el dueño/encargado defina su propia contraseña
    try {
      await _auth.setLanguageCode('es');
      await _auth.sendPasswordResetEmail(email: cleanEmail);
    } catch (e) {
      print('Aviso: No se pudo enviar el correo de definición de contraseña: $e');
    }

    final docSnap = await _db.collection('users').doc(newUid).get();
    return UserModel.fromFirestore(docSnap);
  }

  /// Obtiene la gamificación almacenada localmente para usuarios en modo invitado
  static Future<Map<String, dynamic>> getGuestGamification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('guest_gamification');
      if (str != null && str.isNotEmpty) {
        return Map<String, dynamic>.from(jsonDecode(str));
      }
    } catch (_) {}
    return {
      'points': 0,
      'totalStamps': 0,
      'level': 1,
      'title': 'Explorador',
      'huecaStamps': <String, dynamic>{},
      'collectedStickers': <dynamic>[],
    };
  }

  /// Guarda la gamificación del usuario invitado en SharedPreferences
  static Future<void> saveGuestGamification(Map<String, dynamic> gamification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guest_gamification', jsonEncode(gamification));
    } catch (_) {}
  }

  /// Si un usuario invitado inicia sesión o se registra, migra automáticamente sus sellos y cromos locales a su cuenta en la nube
  Future<void> migrateGuestDataToUser(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('guest_gamification');
      if (str == null || str.isEmpty) return;
      final guestData = Map<String, dynamic>.from(jsonDecode(str));

      final docRef = _db.collection('users').doc(uid);
      final doc = await docRef.get();
      if (!doc.exists) return;
      final userData = doc.data() ?? {};
      final userGamification = Map<String, dynamic>.from(userData['gamification'] ?? {});

      // 1. Fusionar sellos por hueca
      final guestStamps = Map<String, dynamic>.from(guestData['huecaStamps'] ?? {});
      final userStamps = Map<String, dynamic>.from(userGamification['huecaStamps'] ?? {});
      guestStamps.forEach((k, v) {
        final current = (userStamps[k] as num?)?.toInt() ?? 0;
        final guestCount = (v as num?)?.toInt() ?? 0;
        userStamps[k] = current + guestCount;
      });

      // 2. Fusionar cromos secretos
      final guestStickers = List<dynamic>.from(guestData['collectedStickers'] ?? []);
      final userStickers = Set<dynamic>.from(userGamification['collectedStickers'] ?? []);
      userStickers.addAll(guestStickers);

      // 3. Fusionar puntos y sellos totales
      final guestPoints = (guestData['points'] as num?)?.toInt() ?? 0;
      final userPoints = (userGamification['points'] as num?)?.toInt() ?? 0;
      final guestTotalStamps = (guestData['totalStamps'] as num?)?.toInt() ?? 0;
      final userTotalStamps = (userGamification['totalStamps'] as num?)?.toInt() ?? 0;
      final guestRewards = (guestData['rewardsCount'] as num?)?.toInt() ?? 0;
      final userRewards = (userGamification['rewardsCount'] as num?)?.toInt() ?? 0;

      userGamification['huecaStamps'] = userStamps;
      userGamification['collectedStickers'] = userStickers.toList();
      userGamification['points'] = userPoints + guestPoints;
      userGamification['totalStamps'] = userTotalStamps + guestTotalStamps;
      userGamification['rewardsCount'] = userRewards + guestRewards;

      await docRef.update({'gamification': userGamification});
      await prefs.remove('guest_gamification');

      // 4. Migrar perfil gastronómico descubierto en el quiz
      final guestPersona = prefs.getString('guest_persona') ?? prefs.getString('last_selected_persona');
      if (guestPersona != null && guestPersona.isNotEmpty) {
        final currentPrefs = Map<String, dynamic>.from(userData['preferences'] ?? {});
        currentPrefs['persona'] = guestPersona;
        await docRef.update({'preferences': currentPrefs});
        await prefs.setString('last_selected_persona', guestPersona);
      }

      // 5. Migrar sector seleccionado en el quiz
      final guestSector = prefs.getString('guest_sector') ?? prefs.getString('last_selected_sector');
      if (guestSector != null && guestSector.isNotEmpty) {
        final currentPrefs = Map<String, dynamic>.from(userData['preferences'] ?? {});
        currentPrefs['sector'] = guestSector;
        await docRef.update({'preferences': currentPrefs});
        await prefs.setString('last_selected_sector', guestSector);
      }

      // 6. Migrar tours personalizados creados como invitado
      final guestToursStr = prefs.getString('guest_custom_tours');
      if (guestToursStr != null && guestToursStr.isNotEmpty) {
        final List<dynamic> guestTours = jsonDecode(guestToursStr);
        final batch = _db.batch();
        for (var t in guestTours) {
          if (t is Map) {
            final tourMap = Map<String, dynamic>.from(t);
            final tourId = tourMap['id']?.toString() ?? _db.collection('users').doc(uid).collection('custom_tours').doc().id;
            tourMap['id'] = tourId;
            tourMap['creatorId'] = uid;
            final tourDoc = _db.collection('users').doc(uid).collection('custom_tours').doc(tourId);
            batch.set(tourDoc, tourMap, SetOptions(merge: true));
          }
        }
        await batch.commit();
      }
    } catch (e) {
      print('Error migrating guest data: $e');
    }
  }

  /// Canjea el premio de una hueca. Descuenta únicamente [targetStamps] requeridos,
  /// conservando los sellos excedentes para la siguiente cartilla (ej. 13 - 10 = 3 restantes)
  /// e incrementa el contador de recompensas del usuario.
  Future<int> claimHuecaReward({
    required String? uid,
    required String huecaId,
    required int targetStamps,
    required String rewardText,
  }) async {
    final isGuest = uid == null || uid.isEmpty || uid == 'guest';

    if (isGuest) {
      final guestData = await getGuestGamification();
      final huecaStamps = Map<String, dynamic>.from(guestData['huecaStamps'] ?? {});
      final currentStamps = (huecaStamps[huecaId] as num?)?.toInt() ?? 0;

      final remainingStamps = currentStamps >= targetStamps ? (currentStamps - targetStamps) : 0;
      huecaStamps[huecaId] = remainingStamps;
      guestData['huecaStamps'] = huecaStamps;

      final rewardsCount = (guestData['rewardsCount'] as num?)?.toInt() ?? 0;
      guestData['rewardsCount'] = rewardsCount + 1;

      await saveGuestGamification(guestData);

      try {
        await _db.collection('huecas').doc(huecaId).collection('redemptions').add({
          'userId': 'guest_local',
          'rewardText': rewardText,
          'stampsUsed': targetStamps,
          'stampsRemaining': remainingStamps,
          'date': FieldValue.serverTimestamp(),
        });
        await _db.collection('huecas').doc(huecaId).update({
          'metrics.rewardsRedeemed': FieldValue.increment(1),
        });
      } catch (_) {}

      return remainingStamps;
    } else {
      final docRef = _db.collection('users').doc(uid);
      final doc = await docRef.get();
      final userData = doc.data() ?? {};
      final gamification = Map<String, dynamic>.from(userData['gamification'] ?? {});
      final huecaStamps = Map<String, dynamic>.from(gamification['huecaStamps'] ?? {});
      final currentStamps = (huecaStamps[huecaId] as num?)?.toInt() ?? 0;

      final remainingStamps = currentStamps >= targetStamps ? (currentStamps - targetStamps) : 0;
      huecaStamps[huecaId] = remainingStamps;
      gamification['huecaStamps'] = huecaStamps;

      final rewardsCount = (gamification['rewardsCount'] as num?)?.toInt() ?? 0;
      gamification['rewardsCount'] = rewardsCount + 1;

      await docRef.update({'gamification': gamification});

      try {
        await _db.collection('huecas').doc(huecaId).collection('redemptions').add({
          'userId': uid,
          'rewardText': rewardText,
          'stampsUsed': targetStamps,
          'stampsRemaining': remainingStamps,
          'date': FieldValue.serverTimestamp(),
        });
        await _db.collection('huecas').doc(huecaId).update({
          'metrics.rewardsRedeemed': FieldValue.increment(1),
        });
      } catch (_) {}

      return remainingStamps;
    }
  }
}
