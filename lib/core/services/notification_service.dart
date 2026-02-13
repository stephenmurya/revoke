import 'dart:convert';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../theme/app_theme.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _squadAlertsChannel =
      AndroidNotificationChannel(
        'squad_alerts',
        'Squad Alerts',
        description: 'High-priority alerts for incoming squad pleas.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('lookatthisdude'),
      );

  static bool _initialized = false;
  static void Function(String pleaId)? _onPleaJudgementTap;
  static String? _pendingPleaId;

  static void registerPleaJudgementTapHandler(
    void Function(String pleaId) handler,
  ) {
    _onPleaJudgementTap = handler;
    final pending = _pendingPleaId;
    if (pending != null && pending.isNotEmpty) {
      _pendingPleaId = null;
      handler(pending);
    }
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _requestPermissions();
    await _initializeLocalNotifications();
    _listenForegroundMessages();
    await _listenTapEvents();
  }

  static Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: true,
      sound: true,
    );
    print(
      'FCM_DEBUG: Notification permission status = ${settings.authorizationStatus.name}',
    );
  }

  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('notification_icon');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleLocalNotificationTap(response.payload);
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_squadAlertsChannel);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((message) async {
      if (!_isPleaMessage(message)) {
        print(
          'FCM_DEBUG: Foreground message ignored (non-plea). id=${message.messageId}',
        );
        return;
      }

      final title =
          message.data['title']?.toString() ??
          message.notification?.title ??
          'SQUAD ALERT';
      final body =
          message.data['body']?.toString() ??
          message.notification?.body ??
          'A squad member is begging for time.';

      print(
        'FCM_DEBUG: Foreground plea detected. id=${message.messageId} data=${message.data}',
      );

      await _showForegroundNotification(
        title: title,
        body: body,
        data: message.data,
      );
    });
  }

  static Future<void> _listenTapEvents() async {
    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteNotificationTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteNotificationTap(initialMessage);
    }
  }

  static void _handleRemoteNotificationTap(RemoteMessage message) {
    final type = message.data['type']?.toString().trim().toLowerCase();
    final pleaId = message.data['pleaId']?.toString().trim();
    if (type == 'plea_judgement' && pleaId != null && pleaId.isNotEmpty) {
      _dispatchPleaTap(pleaId);
    }
  }

  static void _handleLocalNotificationTap(String? payload) {
    if (payload == null || payload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final type = decoded['type']?.toString().trim().toLowerCase();
      final pleaId = decoded['pleaId']?.toString().trim();
      if (type == 'plea_judgement' && pleaId != null && pleaId.isNotEmpty) {
        _dispatchPleaTap(pleaId);
      }
    } catch (_) {}
  }

  static void _dispatchPleaTap(String pleaId) {
    if (_onPleaJudgementTap != null) {
      _onPleaJudgementTap!(pleaId);
      return;
    }
    _pendingPleaId = pleaId;
  }

  static bool _isPleaMessage(RemoteMessage message) {
    final type =
        message.data['type']?.toString().toLowerCase() ??
        message.data['event']?.toString().toLowerCase() ??
        message.data['kind']?.toString().toLowerCase() ??
        '';
    if (type.contains('plea')) return true;
    if (message.data.containsKey('pleaId')) return true;

    final notificationText =
        '${message.notification?.title ?? ''} ${message.notification?.body ?? ''}'
            .toLowerCase();
    if (notificationText.contains('plea') ||
        notificationText.contains('beg') ||
        notificationText.contains('begging')) {
      return true;
    }

    return false;
  }

  static Future<void> _showForegroundNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'squad_alerts',
      'Squad Alerts',
      channelDescription: 'High-priority alerts for incoming squad pleas.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('lookatthisdude'),
      icon: 'notification_icon',
      color: AppSemanticColors.accent,
    );
    const iosDetails = DarwinNotificationDetails(presentSound: true);
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    String? payload;
    final type = data?['type']?.toString().trim().toLowerCase();
    final pleaId = data?['pleaId']?.toString().trim();
    if (type == 'plea_judgement' && pleaId != null && pleaId.isNotEmpty) {
      payload = jsonEncode({'type': 'plea_judgement', 'pleaId': pleaId});
    }

    final notificationId = Random().nextInt(1 << 31);
    await _localNotifications.show(
      notificationId,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
