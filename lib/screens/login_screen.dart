import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/auth_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  void _signInWithEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authRepo = ref.read(authRepositoryProvider);
    final user = await authRepo.signInWithEmail(_emailController.text, _passwordController.text);
    
    setState(() {
      _isLoading = false;
    });

    if (user != null) {
      if (mounted) context.go('/home');
    } else {
      setState(() {
        _errorMessage = 'Correo o contraseña incorrectos.';
      });
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
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error Google: ${e.toString()}')));
        setState(() => _isLoading = false);
      }
    }
  }
  
  
  String _verificationId = '';
  
  void _verifyOTP(String smsCode) async {
    setState(() => _isLoading = true);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: smsCode,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cdigo invlido: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showOTPDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String smsCode = '';
        return AlertDialog(
          title: const Text('Ingresa el cdigo SMS'),
          content: TextField(
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: const InputDecoration(hintText: '000000'),
            onChanged: (v) => smsCode = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (smsCode.length == 6) {
                  Navigator.pop(context);
                  _verifyOTP(smsCode);
                }
              },
              child: const Text('Verificar'),
            )
          ],
        );
      },
    );
  }

  void _signInWithPhone() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        String fullPhone = '';
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ingresar con telfono', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              IntlPhoneField(
                decoration: InputDecoration(
                  labelText: 'Nmero de telfono',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                initialCountryCode: 'EC',
                onChanged: (phone) {
                  fullPhone = phone.completeNumber;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    Navigator.pop(context);
                    if (!mounted || fullPhone.isEmpty) return;
                    setState(() => _isLoading = true);
                    try {
                      await FirebaseAuth.instance.verifyPhoneNumber(
                        phoneNumber: fullPhone,
                        verificationCompleted: (PhoneAuthCredential credential) async {
                          await FirebaseAuth.instance.signInWithCredential(credential);
                          if (mounted) context.go('/home');
                        },
                        verificationFailed: (FirebaseAuthException e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fallo: ${e.message}')));
                          if (mounted) setState(() => _isLoading = false);
                        },
                        codeSent: (String vid, int? token) {
                          _verificationId = vid;
                          if (mounted) setState(() => _isLoading = false);
                          _showOTPDialog();
                        },
                        codeAutoRetrievalTimeout: (String vid) {
                          _verificationId = vid;
                        },
                      );
                    } catch(e) {
                       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fallo: $e')));
                       if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  child: const Text('Enviar SMS'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
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

    if (user != null) {
      if (mounted) context.go('/home');
    } else {
      setState(() {
        _errorMessage = 'Error al ingresar como invitado.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Hero(
                  tag: 'app_logo',
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.restaurant, size: 80, color: AppTheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '¡Bienvenido a Hue-Quito!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Descubre los mejores sabores de la capital',
                style: TextStyle(fontSize: 16, color: AppTheme.textMedium),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade900)),
                ),

              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(color: AppTheme.secondary)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _signInWithEmail,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Iniciar Sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('O', style: TextStyle(color: AppTheme.textMedium))),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  foregroundColor: AppTheme.textDark,
                  elevation: 1,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.red),
                label: const Text('Continuar con Google'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  foregroundColor: AppTheme.textDark,
                  elevation: 1,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _isLoading ? null : _signInWithPhone,
                icon: const Icon(Icons.phone, size: 24, color: Colors.green),
                label: const Text('Continuar con Teléfono'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isLoading ? null : _signInAnonymously,
                child: const Text('Explorar como Invitado (Sin guardar progreso)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
