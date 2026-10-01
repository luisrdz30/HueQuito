import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      // Ignorar si no está conectado con Google
    }
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _db.collection('users').doc(user.uid).delete();
      } catch (e) {
        // Ignorar si no existe el documento
      }
      await user.delete();
      await signOut();
    }
  }

  // Create or Update user doc in Firestore after login
  Future<void> syncUserToFirestore(User user) async {
    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'name': user.displayName ?? 'Invitado',
        'profilePicUrl': user.photoURL ?? '',
        'role': 'comensal',
        'createdAt': FieldValue.serverTimestamp(),
        'gamification': {
          'totalStamps': 0,
          'level': 1,
          'title': 'Explorador Novato'
        },
        'preferences': {
          'favoriteDishes': [],
          'dietaryRestrictions': []
        }
      });
    }
  }
}
