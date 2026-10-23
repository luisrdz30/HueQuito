import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/auth_provider.dart' hide currentUserProvider;
import 'package:hue_quito/providers/data_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hue_quito/repositories/user_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  void _signInWithEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithEmail(
        _emailController.text,
        _passwordController.text,
      );

      ref.invalidate(authStateProvider);
      ref.invalidate(currentUserProvider);

      final userRepo = ref.read(userRepositoryProvider);
      var userModel = await userRepo.getCurrentUser();
      await _handlePostLoginNavigation(userModel);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePostLoginNavigation(UserModel? userModel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'last_login_time',
      DateTime.now().millisecondsSinceEpoch,
    );

    if (!mounted) return;

    if (userModel != null) {
      // Migrar datos acumulados en modo invitado a la cuenta del usuario
      try {
        final userRepo = ref.read(userRepositoryProvider);
        await userRepo.migrateGuestDataToUser(userModel.uid);
        ref.invalidate(currentUserProvider);
      } catch (_) {}

      bool isBusinessOrManager = false;

      try {
        final userEmail = userModel.email.trim().toLowerCase();
        final userUid = userModel.uid;
        final huecasSnap = await FirebaseFirestore.instance.collection('huecas').get();

        for (var doc in huecasSnap.docs) {
          final data = doc.data();
          if (data['ownerId'] == userUid) {
            isBusinessOrManager = true;
            break;
          }
          final branchesList = data['branches'] as List<dynamic>?;
          if (branchesList != null) {
            for (var b in branchesList) {
              if (b is Map && (b['managerEmail']?.toString().trim().toLowerCase() == userEmail)) {
                isBusinessOrManager = true;
                break;
              }
            }
          }
          if (isBusinessOrManager) break;
        }

        if (isBusinessOrManager) {
          if (userModel.role != 'business') {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userModel.uid)
                .update({'role': 'business'});
          }
          await FirebaseFirestore.instance
              .collection('branch_invitations')
              .doc(userEmail)
              .update({'status': 'active'}).catchError((_) {});
        } else if (userModel.role == 'business') {
          // Ya no administra ninguna sucursal ni es dueño: revocar rol
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userModel.uid)
              .update({'role': 'user'});
        }
      } catch (_) {}

      if (isBusinessOrManager) {
        context.go('/business/dashboard');
        return;
      }
    }

    context.go('/home');
  }

  void _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User canceled
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      ref.invalidate(authStateProvider);
      ref.invalidate(currentUserProvider);

      final userRepo = ref.read(userRepositoryProvider);
      var userModel = await userRepo.getCurrentUser();
      await _handlePostLoginNavigation(userModel);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error Google: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _skipLogin() {
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.restaurant, size: 80, color: AppTheme.primary),
              SizedBox(height: 16),
              Text(
                'HueQuito',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              SizedBox(height: 32),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red),
                  ),
                ),

              // Email
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              SizedBox(height: 24),

              _isLoading
                  ? CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _signInWithEmail,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Iniciar Sesión',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

              SizedBox(height: 16),
              OutlinedButton.icon(
                icon: Icon(Icons.g_mobiledata, size: 24),
                label: Text('Ingresar con Google'),
                onPressed: _isLoading ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
              ),

              SizedBox(height: 16),
              TextButton(
                onPressed: _skipLogin,
                child: Text('Continuar como Invitado'),
              ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push('/register'),
                child: Text(
                  '¿Aún no tienes cuenta? Regístrate aquí',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
