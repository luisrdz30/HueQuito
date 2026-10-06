import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hue_quito/theme/theme.dart';

class AuthUtils {
  static bool checkAuthAndPrompt(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Inicio de Sesión Requerido'),
          content: const Text('Para usar esta función y guardar tu progreso necesitas crear una cuenta o iniciar sesión.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/login');
              },
              child: const Text('Registrarse / Entrar'),
            )
          ],
        )
      );
      return false;
    }
    return true;
  }
}
