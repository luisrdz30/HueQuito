import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hue_quito/services/push_service.dart';
import 'package:hue_quito/theme/theme.dart';

/// Pasos para recibir notificaciones según el dispositivo y lo que respondió el sistema.
/// Devuelve (título, pasos); en web con iPhone hay que agregar la página a la pantalla de inicio.
(String, List<String>) pushHelpContent(PushRegistrationResult result, {required bool isEs}) {
  final isIos = defaultTargetPlatform == TargetPlatform.iOS;

  if (result == PushRegistrationResult.denied) {
    if (!kIsWeb) {
      return (
        isEs ? 'Las notificaciones están desactivadas' : 'Notifications are turned off',
        isEs
            ? ['Abre los Ajustes de tu celular.', 'Entra a Aplicaciones → Hue-Quito → Notificaciones.', 'Actívalas y vuelve a tocar la campana 🔔 de la hueca.']
            : ['Open your phone Settings.', 'Go to Apps → Hue-Quito → Notifications.', 'Turn them on and tap the hueca bell 🔔 again.'],
      );
    }
    return (
      isEs ? 'Tu navegador bloqueó las notificaciones' : 'Your browser blocked notifications',
      isEs
          ? ['Toca el candado o el ícono de ajustes junto a la dirección de la página.', 'En Notificaciones, elige Permitir.', 'Recarga la página y vuelve a tocar la campana 🔔 de la hueca.']
          : ['Tap the lock or settings icon next to the page address.', 'Under Notifications, choose Allow.', 'Reload the page and tap the hueca bell 🔔 again.'],
    );
  }

  if (kIsWeb && isIos) {
    return (
      isEs ? 'En iPhone, agrega HueQuito a tu inicio' : 'On iPhone, add HueQuito to your home screen',
      isEs
          ? ['Abre esta página en Safari.', 'Toca Compartir y elige "Agregar a inicio".', 'Abre HueQuito desde el nuevo ícono.', 'Vuelve a tocar la campana 🔔 de la hueca y acepta el permiso.']
          : ['Open this page in Safari.', 'Tap Share and choose "Add to Home Screen".', 'Open HueQuito from the new icon.', 'Tap the hueca bell 🔔 again and allow notifications.'],
    );
  }

  return (
    isEs ? 'Este navegador no puede recibir notificaciones' : 'This browser can\'t receive notifications',
    isEs
        ? ['Abre HueQuito en Chrome, Edge o Firefox, o instala la aplicación de Android.', 'Vuelve a tocar la campana 🔔 de la hueca y acepta el permiso.']
        : ['Open HueQuito in Chrome, Edge or Firefox, or install the Android app.', 'Tap the hueca bell 🔔 again and allow notifications.'],
  );
}

/// Explica cómo activar las notificaciones cuando el dispositivo no las pudo registrar.
/// Con [allowUnfollow] ofrece dejar de seguir la hueca y devuelve true si lo eligió.
Future<bool> showPushHelpDialog(
  BuildContext context,
  PushRegistrationResult result, {
  required bool isEs,
  bool allowUnfollow = false,
}) async {
  final (title, steps) = pushHelpContent(result, isEs: isEs);
  final unfollow = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(Icons.notifications_off_outlined, color: AppTheme.primary, size: 32),
      title: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${i + 1}. ${steps[i]}', style: const TextStyle(fontSize: 14, height: 1.3)),
            ),
        ],
      ),
      actions: [
        if (allowUnfollow)
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isEs ? 'Dejar de seguir' : 'Unfollow', style: const TextStyle(color: Colors.grey)),
          ),
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEs ? 'Entendido' : 'Got it')),
      ],
    ),
  );
  return unfollow ?? false;
}
