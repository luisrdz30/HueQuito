import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hue_quito/models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'huequito_promotions';
  static const String channelName = 'Noticias y Promociones Hue-Quito';
  static const String channelDescription =
      'Notificaciones y promociones del panel de tus huecas suscritas';

  bool _initialized = false;
  void Function(String huecaId)? onNotificationTapped;
  final Set<String> _shownNotificationIds = {};

  Future<void> initialize({void Function(String huecaId)? onTapped}) async {
    if (_initialized) return;
    onNotificationTapped = onTapped;

    // Cargar historial persistente en memoria para verificación síncrona inmediata
    try {
      final prefs = await SharedPreferences.getInstance();
      final loaded = prefs.getStringList('shown_notification_ids') ?? [];
      _shownNotificationIds.addAll(loaded);
    } catch (e) {
      debugPrint('Error cargando historial de notificaciones en memoria: $e');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              final data = jsonDecode(payload);
              final huecaId = data['huecaId']?.toString();
              if (huecaId != null && onNotificationTapped != null) {
                onNotificationTapped!(huecaId);
              }
            } catch (e) {
              debugPrint('Error parsing notification payload: $e');
            }
          }
        },
      );

      // Create notification channel for Android
      final androidChannel = const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // Request permissions for Android 13+
      await requestPermissions();
    } catch (e) {
      debugPrint('Plataforma nativa de notificaciones no disponible (modo headless/test): $e');
    }

    _initialized = true;
  }

  Future<bool?> requestPermissions() async {
    return await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  bool hasBeenShown(String notificationId) {
    return _shownNotificationIds.contains(notificationId);
  }

  Future<void> markAsSilentlyProcessed(String notificationId) async {
    if (_shownNotificationIds.contains(notificationId)) return;
    _shownNotificationIds.add(notificationId);

    try {
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.getStringList('shown_notification_ids') ?? [];
      if (!shown.contains(notificationId)) {
        shown.add(notificationId);
        await prefs.setStringList('shown_notification_ids', shown);
      }
    } catch (e) {
      debugPrint('Error guardando notificación procesada silenciosamente: $e');
    }
  }

  Future<void> showPromotionNotification({
    required NotificationModel notification,
  }) async {
    // 1. Verificación síncrona inmediata en memoria para prevenir llamadas concurrentes o duplicados
    if (_shownNotificationIds.contains(notification.id)) {
      return; // Ya mostrada en esta sesión o en historial persistente
    }

    // 2. Registrar inmediatamente en el Set en memoria antes de cualquier await
    _shownNotificationIds.add(notification.id);

    // 3. Persistir en SharedPreferences de manera asíncrona
    try {
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.getStringList('shown_notification_ids') ?? [];
      if (!shown.contains(notification.id)) {
        shown.add(notification.id);
        await prefs.setStringList('shown_notification_ids', shown);
      }
    } catch (e) {
      debugPrint('Error al persistir notificación mostrada: $e');
    }

    // 4. Configurar y disparar notificación local en Android/iOS
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Hue-Quito',
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        notification.message,
        contentTitle: '${notification.categoryEmoji} ${notification.huecaName}: ${notification.title}',
        summaryText: notification.discountTag != null && notification.discountTag!.isNotEmpty
            ? '${notification.categoryDisplay} • ${notification.discountTag}'
            : notification.categoryDisplay,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'huecaId': notification.huecaId,
      'notificationId': notification.id,
    });

    final notifId = notification.id.hashCode & 0x7FFFFFFF;

    try {
      await _localNotifications.show(
        id: notifId,
        title: '${notification.categoryEmoji} ${notification.huecaName}: ${notification.title}',
        body: notification.message,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Plataforma nativa no disponible para mostrar notificación (modo headless/test): $e');
    }
  }

  // Debug helper to reset shown cache
  Future<void> clearShownHistory() async {
    _shownNotificationIds.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('shown_notification_ids');
  }
}
