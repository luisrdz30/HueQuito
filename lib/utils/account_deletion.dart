import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/providers/auth_provider.dart' show authRepositoryProvider;
import 'package:hue_quito/providers/data_provider.dart' show userRepositoryProvider;
import 'package:shared_preferences/shared_preferences.dart';

/// Elimina la cuenta del usuario actual (ya confirmada por él).
/// Las cuentas de correo piden la contraseña; las de Google vuelven a elegir su cuenta.
/// Devuelve null si se eliminó, '' si el usuario canceló, o el mensaje de error a mostrar.
Future<String?> deleteCurrentAccount(BuildContext context, WidgetRef ref, {required bool isEn}) async {
  final authRepo = ref.read(authRepositoryProvider);

  String? password;
  if (authRepo.usesPasswordLogin) {
    password = await _askPassword(context, isEn);
    if (password == null || password.isEmpty) return '';
  }

  try {
    await authRepo.deleteAccount(
      password: password,
      deleteUserData: (user) => ref.read(userRepositoryProvider).deleteUser(user.uid, email: user.email),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    return null;
  } on FirebaseAuthException catch (e) {
    switch (e.code) {
      case 'reauth-cancelled':
        return '';
      case 'wrong-password':
      case 'invalid-credential':
        return isEn ? 'Incorrect password. Your account was not deleted.' : 'Contraseña incorrecta. Tu cuenta no fue eliminada.';
      case 'too-many-requests':
        return isEn ? 'Too many attempts. Try again later.' : 'Demasiados intentos. Inténtalo más tarde.';
      case 'network-request-failed':
        return isEn ? 'No internet connection.' : 'Sin conexión a internet.';
      default:
        return isEn ? 'Could not delete the account. Please try again.' : 'No se pudo eliminar la cuenta. Inténtalo de nuevo.';
    }
  } catch (_) {
    return isEn ? 'Could not delete the account. Please try again.' : 'No se pudo eliminar la cuenta. Inténtalo de nuevo.';
  }
}

Future<String?> _askPassword(BuildContext context, bool isEn) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isEn ? 'Confirm your password' : 'Confirma tu contraseña'),
      content: TextField(
        controller: controller,
        obscureText: true,
        autofocus: true,
        decoration: InputDecoration(labelText: isEn ? 'Password' : 'Contraseña'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(isEn ? 'Cancel' : 'Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(isEn ? 'Delete' : 'Eliminar'),
        ),
      ],
    ),
  );
}
