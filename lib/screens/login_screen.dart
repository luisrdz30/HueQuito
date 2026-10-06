import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/auth_provider.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isBusinessOwner = false;
  String? _errorMessage;

  void _signInWithEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final user = await authRepo.signInWithEmail(_emailController.text, _passwordController.text);
      
      final userRepo = ref.read(userRepositoryProvider);
      var userModel = await userRepo.getCurrentUser();

      if (_isBusinessOwner && userModel != null && userModel.role != 'business') {
        await FirebaseFirestore.instance.collection('users').doc(userModel.uid).update({'role': 'business'});
        userModel = await userRepo.getCurrentUser();
      }

      if (mounted) {
        if (userModel != null && userModel.role == 'business') {
          context.go('/business/dashboard');
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al iniciar sesión: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      final userRepo = ref.read(userRepositoryProvider);
      var userModel = await userRepo.getCurrentUser();

      if (_isBusinessOwner && userModel != null && userModel.role != 'business') {
        await FirebaseFirestore.instance.collection('users').doc(userModel.uid).update({'role': 'business'});
        userModel = await userRepo.getCurrentUser();
      }

      if (mounted) {
        if (userModel != null && userModel.role == 'business') {
          context.go('/business/dashboard');
        } else {
          context.go('/home');
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error Google: ${e.toString()}')));
        setState(() => _isLoading = false);
      }
    }
  }
  
  
void _signInAnonymously() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authRepo = ref.read(authRepositoryProvider);
    final user = await authRepo.signInAnonymously();
    
    setState(() {
      _isLoading = false;
    });


    final userRepo = ref.read(userRepositoryProvider);
    var userModel = await userRepo.getCurrentUser();

    if (_isBusinessOwner && userModel != null && userModel.role != 'business') {
      await FirebaseFirestore.instance.collection('users').doc(userModel.uid).update({'role': 'business'});
      userModel = await userRepo.getCurrentUser();
    }

    if (mounted) {
      if (userModel != null && userModel.role == 'business') {
        context.go('/business/dashboard');
      } else {
        context.go('/home');
      }
    }

    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 40),
              Center(
                child: Hero(
                  tag: 'app_logo',
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.restaurant, size: 80, color: AppTheme.primary),
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                '¡Bienvenido a Hue-Quito!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Descubre los mejores sabores de la capital',
                style: TextStyle(fontSize: 16, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 48),

              if (_errorMessage != null)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade900)),
                ),

              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text('¿Olvidaste tu contraseña?', style: TextStyle(color: AppTheme.secondary)),
                ),
              ),
              SizedBox(height: 8),
              CheckboxListTile(
                title: Text('Ingresar como dueño de Hueca'),
                value: _isBusinessOwner,
                onChanged: (val) {
                  setState(() {
                    _isBusinessOwner = val ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppTheme.primary,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _signInWithEmail,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isLoading 
                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Theme.of(context).cardColor, strokeWidth: 2))
                    : Text('Iniciar Sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('O', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium)))),
                  Expanded(child: Divider()),
                ],
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  elevation: 1,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: Icon(Icons.g_mobiledata, size: 32, color: Colors.red),
                label: Text('Continuar con Google'),
              ),
              SizedBox(height: 12),
              TextButton(
                onPressed: _isLoading ? null : _signInAnonymously,
                child: Text('Explorar como Invitado (Sin guardar progreso)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
