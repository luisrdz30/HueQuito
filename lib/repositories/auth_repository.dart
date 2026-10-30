import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      // Ignorar si no está conectado con Google
    }
    await _auth.signOut();
  }

  /// true si la cuenta entra con correo y contraseña (y no solo con Google)
  bool get usesPasswordLogin =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ?? false;

  /// Firebase exige un inicio de sesión reciente para borrar la cuenta.
  /// Cuentas de correo usan [password]; las de Google vuelven a elegir su cuenta de Google.
  Future<void> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (usesPasswordLogin) {
      final credential = EmailAuthProvider.credential(email: user.email ?? '', password: password ?? '');
      await user.reauthenticateWithCredential(credential);
      return;
    }

    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(code: 'reauth-cancelled', message: 'Reautenticación cancelada');
    }
    final googleAuth = await googleUser.authentication;
    await user.reauthenticateWithCredential(GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    ));
  }

  /// Elimina la cuenta en este orden:
  /// 1. Reautentica (así el borrado de Auth ya no falla por "requires-recent-login").
  /// 2. Borra los datos de Firestore mientras la sesión aún tiene permiso (las reglas lo exigen).
  /// 3. Borra la cuenta de Auth.
  Future<void> deleteAccount({
    String? password,
    required Future<void> Function(User user) deleteUserData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await reauthenticate(password: password);
    await deleteUserData(user);
    await user.delete();
    await signOut();
  }
}
