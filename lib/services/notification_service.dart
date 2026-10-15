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

  Future<void> initialize({void Function(String huecaId)? onTapped}) async {
    if (_initialized) return;
    onNotificationTapped = onTapped;

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

    _initialized = true;
  }

  Future<bool?> requestPermissions() async {
    return await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showPromotionNotification({
    required NotificationModel notification,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getStringList('shown_notification_ids') ?? [];
    if (shown.contains(notification.id)) {
      return; // Already notified on this device
    }

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

    await _localNotifications.show(
      id: notifId,
      title: '${notification.categoryEmoji} ${notification.huecaName}: ${notification.title}',
      body: notification.message,
      notificationDetails: details,
      payload: payload,
    );

    // Mark as shown so user only gets it once in their notification drawer
    shown.add(notification.id);
    await prefs.setStringList('shown_notification_ids', shown);
  }

  // Debug helper to reset shown cache
  Future<void> clearShownHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('shown_notification_ids');
  }
}
