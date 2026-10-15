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
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
        });
        doc = await docRef.get();
      }
      
      if (doc.exists) {
        UserModel userModel = UserModel.fromFirestore(doc);
        // Also fetch sector albums
        final albums = await _db.collection('users').doc(user.uid).collection('sector_albums').get();
        userModel.sectorAlbums.addAll(albums.docs.map((d) => d.data()).toList());
        return userModel;
      }
    } catch (e) {
      print('Error fetching user: $e');
    }
    return null;
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
        await _db.collection('huecas').doc(huecaId).set({
          'metrics': {
            'favoriteCount': countSnap.docs.length,
          }
        }, SetOptions(merge: true));
      } catch (e) {
        try {
          await _db.collection('huecas').doc(huecaId).set({
            'metrics': {
              'favoriteCount': FieldValue.increment(wasFavorite ? -1 : 1),
            }
          }, SetOptions(merge: true));
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

  /// ADMIN: Crear cuenta de usuario con rol 'business' desde el panel de admin
  /// No requiere contraseña manual: genera una clave temporal segura y envía automáticamente
  /// un correo electrónico al usuario para que defina su propia contraseña.
  Future<UserModel> createBusinessAccount({
    required String name,
    required String email,
    String? password,
    String? assignedHuecaId,
    String? assignedBranchId,
  }) async {
    final tempAppName = 'AdminUserCreator_${DateTime.now().millisecondsSinceEpoch}';
    FirebaseApp? tempApp;
    UserCredential cred;

    // Si no se proporcionó contraseña, generar una clave temporal segura
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
        email: email.trim(),
        password: initialPassword,
      );

      await cred.user?.updateDisplayName(name.trim());
    } finally {
      if (tempApp != null) {
        await tempApp.delete();
      }
    }

    final newUid = cred.user!.uid;

    final userData = <String, dynamic>{
      'uid': newUid,
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
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
          email: email.trim(),
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
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      print('Aviso: No se pudo enviar el correo de definición de contraseña: $e');
    }

    final docSnap = await _db.collection('users').doc(newUid).get();
    return UserModel.fromFirestore(docSnap);
  }
}
