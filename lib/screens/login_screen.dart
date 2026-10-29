import 'package:hue_quito/widgets/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/auth_provider.dart' hide currentUserProvider;
import 'package:hue_quito/providers/data_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _getFriendlyErrorMessage(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('user-not-found')) {
      return 'No existe una cuenta registrada con este correo electrónico.';
    }
    if (msg.contains('wrong-password') || msg.contains('invalid-credential')) {
      return 'El correo o la contraseña son incorrectos.';
    }
    if (msg.contains('invalid-email')) {
      return 'El formato del correo electrónico no es válido.';
    }
    if (msg.contains('user-disabled')) {
      return 'Esta cuenta ha sido deshabilitada. Contacta a soporte.';
    }
    if (msg.contains('too-many-requests')) {
      return 'Demasiados intentos fallidos. Por favor espera un momento o restablece tu contraseña.';
    }
    if (msg.contains('network-request-failed')) {
      return 'Error de conexión. Revisa tu acceso a internet.';
    }
    return e.toString().replaceAll('Exception: ', '').replaceAll(RegExp(r'\[.*?\]'), '').trim();
  }

  void _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor ingresa tu correo electrónico';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor ingresa tu contraseña';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithEmail(
        email,
        password,
      );

      ref.invalidate(authStateProvider);
      ref.invalidate(currentUserProvider);

      final userRepo = ref.read(userRepositoryProvider);
      var userModel = await userRepo.getCurrentUser();
      await _handlePostLoginNavigation(userModel);
    } catch (e) {
      setState(() {
        _errorMessage = _getFriendlyErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    bool isSending = false;
    String? resetError;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_reset, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Recuperar Contraseña',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingresa tu correo registrado y te enviaremos un enlace seguro para crear una nueva contraseña.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : AppTheme.textMedium,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Correo Electrónico',
                      hintText: 'ejemplo@correo.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      errorText: resetError,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(dialogCtx),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          final email = resetEmailController.text.trim();
                          if (email.isEmpty) {
                            setDialogState(() {
                              resetError = 'Por favor escribe tu correo';
                            });
                            return;
                          }
                          if (!email.contains('@') || !email.contains('.')) {
                            setDialogState(() {
                              resetError = 'Ingresa un correo electrónico válido';
                            });
                            return;
                          }

                          setDialogState(() {
                            isSending = true;
                            resetError = null;
                          });

                          try {
                            final authRepo = ref.read(authRepositoryProvider);
                            await authRepo.sendPasswordResetEmail(email);

                            if (mounted) {
                              Navigator.pop(dialogCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.mark_email_read, color: Colors.white, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '¡Listo! Enviamos el enlace de recuperación a $email. Revisa tu bandeja de entrada o spam.',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.green.shade700,
                                  duration: const Duration(seconds: 5),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSending = false;
                              resetError = _getFriendlyErrorMessage(e);
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Enviar Enlace',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
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

      final userRepo = ref.read(userRepositoryProvider);
      final isBusinessOrManager = await userRepo.syncBusinessRole(userModel);

      // Esperar el perfil actualizado antes de navegar, para que el guardia del
      // router vea el rol correcto (evita que un encargado termine en /home)
      ref.invalidate(currentUserProvider);
      try {
        await ref.read(currentUserProvider.future);
      } catch (_) {}
      if (!mounted) return;

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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const HueQuitoLogo.stacked(height: 120),
              const SizedBox(height: 32),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock),
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
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Olvidaste tu contraseña
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _signInWithEmail,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                        child: const Text(
                          'Iniciar Sesión',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.g_mobiledata, size: 24),
                label: const Text('Ingresar con Google'),
                onPressed: _isLoading ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: _skipLogin,
                child: const Text('Continuar como Invitado'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push('/register'),
                child: const Text(
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
