import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Notificaciones push con Firebase Cloud Messaging.
///
/// Registra el token del dispositivo (celular o navegador) en `users/{uid}.fcmTokens`.
/// La Cloud Function `publicarAviso` usa esos tokens para enviar los avisos de las
/// huecas a sus suscriptores, aunque la app o la pestaña estén cerradas.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// Clave pública "Web Push" del proyecto (Firebase Console → Cloud Messaging).
  static const String webVapidKey = String.fromEnvironment(
    'FCM_VAPID_KEY',
    defaultValue: 'BNLV9HiWMhnIa4sSQnlEZETzHXFQnXiioIHKsECtpVuJNJNtdsw0sggorLDGc8KaGAjUdAzCQRC56Z6tey35xaE',
  );

  String? _uid;
  String? _token;
  StreamSubscription<String>? _refreshSub;

  /// Registra el dispositivo. Con [askPermission] muestra el permiso del sistema
  /// (en web solo debe llamarse tras un toque del usuario); sin él, solo se registra
  /// si el permiso ya estaba concedido.
  Future<void> register(String uid, {bool askPermission = false}) async {
    try {
      if (kIsWeb && webVapidKey.isEmpty) return;
      final messaging = FirebaseMessaging.instance;

      final settings = askPermission
          ? await messaging.requestPermission()
          : await messaging.getNotificationSettings();
      final allowed = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) return;

      final token = await messaging.getToken(vapidKey: kIsWeb ? webVapidKey : null);
      if (token == null) return;
      await _save(uid, token);

      _refreshSub ??= messaging.onTokenRefresh.listen((t) {
        if (_uid != null) _save(_uid!, t);
      });
    } catch (e) {
      debugPrint('[PUSH] No se pudo registrar el dispositivo: $e');
    }
  }

  /// Al cerrar sesión el dispositivo deja de recibir avisos de esa cuenta.
  Future<void> unregister() async {
    final uid = _uid, token = _token;
    _uid = null;
    _token = null;
    if (uid == null || token == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    } catch (e) {
      debugPrint('[PUSH] No se pudo quitar el token: $e');
    }
  }

  Future<void> _save(String uid, String token) async {
    if (_uid == uid && _token == token) return;
    _uid = uid;
    _token = token;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }
}
