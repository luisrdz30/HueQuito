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

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.profilePicUrl,
    required this.gamification,
    required this.preferences,
    required this.sectorAlbums,
      this.favoriteHuecas = const [],
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? 'Usuario',
      email: data['email'] ?? '',
      profilePicUrl: data['profilePicUrl'] ?? 'https://via.placeholder.com/150',
      gamification: data['gamification'] ?? {'totalStamps': 0, 'level': 1, 'title': 'Novato'},
      preferences: data['preferences'] ?? {'favoriteDishes': [], 'dietaryRestrictions': []},
      sectorAlbums: [], // Load separately or assume empty for now
      favoriteHuecas: List<String>.from(data['favoriteHuecas'] ?? []),
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
      if (currentFavs.contains(huecaId)) {
        currentFavs.remove(huecaId);
      } else {
        currentFavs.add(huecaId);
      }
      await docRef.update({'favoriteHuecas': currentFavs});
    }
  }

  Future<void> updatePreferences(Map<String, dynamic> newPrefs) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({
      'preferences': newPrefs
    });
  }
}
