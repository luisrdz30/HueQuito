import 'package:hue_quito/widgets/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/providers/data_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  void _registerWithEmail() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = 'Por favor, llena todos los campos');
      return;
    }
    
    if (password != confirm) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden');
      return;
    }
    
    if (password.length < 8) {
      setState(() => _errorMessage = 'La contraseña debe tener al menos 8 caracteres');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final uid = userCred.user!.uid;

      final cleanEmail = email.toLowerCase();

      // El perfil siempre se crea como comensal ('user'). Si el correo tiene una
      // invitación de encargado, syncBusinessRole lo asciende de forma permitida por las reglas.
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': cleanEmail,
        'name': name,
        'profilePicUrl': 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random',
        'role': 'user',
        'gamification': {
          'level': 1,
          'points': 0,
          'totalStamps': 0,
          'title': 'Turista Novato',
          'huecaStamps': {},
        },
        'preferences': {},
        'favoriteHuecas': [],
        'subscribedHuecas': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      final userRepo = ref.read(userRepositoryProvider);

      // Migrar sellos y cromos acumulados en modo invitado
      try {
        await userRepo.migrateGuestDataToUser(uid);
      } catch (_) {}

      // Releer el perfil recién creado (evita que se quede mostrando "Usuario")
      ref.invalidate(currentUserProvider);
      bool isBranchManager = false;
      try {
        final userModel = await ref.read(currentUserProvider.future);
        if (userModel != null) {
          isBranchManager = await userRepo.syncBusinessRole(userModel);
          if (isBranchManager) {
            ref.invalidate(currentUserProvider);
            await ref.read(currentUserProvider.future);
          }
        }
      } catch (_) {}

      if (mounted) {
        if (isBranchManager) {
          context.go('/business/dashboard');
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Crear Cuenta'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const HueQuitoLogo.symbol(height: 75),
              const SizedBox(height: 16),
              Text(
                'Únete a HueQuito',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
              ),
              SizedBox(height: 32),
              
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_errorMessage!, style: TextStyle(color: Colors.red)),
                ),

              // Name
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre y Apellido',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(9999)),
                ),
              ),
              SizedBox(height: 16),

              // Email
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(9999)),
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
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(9999)),
                ),
              ),
              SizedBox(height: 16),
              
              // Confirm Password
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirmar Contraseña',
                  prefixIcon: Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(9999)),
                ),
              ),
              SizedBox(height: 32),

              _isLoading
                  ? CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _registerWithEmail,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                        ),
                        child: Text('Registrarse', style: TextStyle(fontSize: 16)),
                      ),
                    ),
              
              SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                child: Text('¿Ya tienes cuenta? Inicia sesión aquí'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
