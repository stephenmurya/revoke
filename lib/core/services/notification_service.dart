import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app_router.dart';
import 'theme_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.handleBackgroundRemoteMessage(message);
}

class NotificationService {
  static const MethodChannel _amnestyBridge = MethodChannel(
    'com.revoke.app/overlay',
  );
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
  static bool _localNotificationsInitialized = false;

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    if (_initialized) return;
    _initialized = true;

    await _requestPermissions();
    await _initializeLocalNotifications();
    await _subscribeToGlobalTopic();
    _listenForegroundMessages();
    await _listenTapEvents();
  }

  static Future<void> subscribeToGlobalCitizensTopic() async {
    await _subscribeToGlobalTopic();
  }

  static Future<void> handleBackgroundRemoteMessage(
    RemoteMessage message,
  ) async {
    await _handleAmnestyMessage(message);
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
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      // Best-effort only. App remains usable even if notifications are denied.
    }
  }

  static Future<void> _subscribeToGlobalTopic() async {
    try {
      await _messaging.subscribeToTopic('global_citizens');
    } catch (_) {}
  }

  static Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;

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
    _localNotificationsInitialized = true;

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((message) async {
      final handledAmnesty = await _handleAmnestyMessage(message);
      if (handledAmnesty) return;

      final isPlea = _isPleaMessage(message);
      final title =
          message.data['title']?.toString() ??
          message.notification?.title ??
          (isPlea ? 'SQUAD ALERT' : 'Revoke');
      final body =
          message.data['body']?.toString() ??
          message.notification?.body ??
          (isPlea
              ? 'A squad member is begging for time.'
              : 'You have a new notification.');

      if (title.trim().isEmpty && body.trim().isEmpty) {
        return;
      }

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
    final route = _resolveTapRoute(message.data);
    if (route == null || route.isEmpty) return;
    _pushRoute(route);
  }

  static void _handleLocalNotificationTap(String? payload) {
    if (payload == null || payload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final route = _resolveTapRoute(decoded);
      if (route == null || route.isEmpty) return;
      _pushRoute(route);
    } catch (_) {}
  }

  static void _pushRoute(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        AppRouter.router.push(route);
      } catch (_) {
        // Best-effort routing. App-level navigation guards still apply.
      }
    });
  }

  static String? _resolveTapRoute(Map<String, dynamic> data) {
    final type = _normalizeTapType(data['type']?.toString());
    final pleaId = _extractPleaId(data);
    final hasPleaId = pleaId != null && pleaId.isNotEmpty;
    final isTribunal = type == 'plea' || type == 'verdict';

    if (isTribunal && hasPleaId) {
      return '/tribunal/$pleaId';
    }

    if (hasPleaId && type.isEmpty) {
      return '/tribunal/$pleaId';
    }

    if (type.isNotEmpty) {
      return '/notifications';
    }

    return null;
  }

  static String _normalizeTapType(String? rawType) {
    final normalized = rawType?.trim().toLowerCase() ?? '';
    switch (normalized) {
      case 'plea_judgement':
      case 'plea_request':
      case 'plea-created':
        return 'plea';
      case 'verdict_reached':
        return 'verdict';
      case 'strength':
      case 'freedom':
        return 'support';
      case 'system_mandate':
      case 'broadcast':
        return 'system';
      default:
        return normalized;
    }
  }

  static String? _extractPleaId(Map<String, dynamic> data) {
    final direct = data['pleaId']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final metadataField = data['metadata'];
    if (metadataField is String && metadataField.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(metadataField);
        if (decoded is Map) {
          final nested = decoded['pleaId']?.toString().trim();
          if (nested != null && nested.isNotEmpty) return nested;
        }
      } catch (_) {}
    }

    if (metadataField is Map) {
      final nested = metadataField['pleaId']?.toString().trim();
      if (nested != null && nested.isNotEmpty) return nested;
    }

    return null;
  }

  static bool _isPleaMessage(RemoteMessage message) {
    final type = _normalizeTapType(
      message.data['type']?.toString() ??
          message.data['event']?.toString() ??
          message.data['kind']?.toString(),
    );
    if (type == 'plea' || type == 'verdict') return true;
    final pleaId = _extractPleaId(message.data);
    if (pleaId != null && pleaId.isNotEmpty) return true;

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
    final androidDetails = AndroidNotificationDetails(
      'squad_alerts',
      'Squad Alerts',
      channelDescription: 'High-priority alerts for incoming squad pleas.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('lookatthisdude'),
      icon: 'notification_icon',
      color: ThemeService.instance.accentColor.value,
    );
    const iosDetails = DarwinNotificationDetails(presentSound: true);
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    String? payload;
    final payloadData = <String, dynamic>{};
    final normalizedType = _normalizeTapType(data?['type']?.toString());
    if (normalizedType.isNotEmpty) {
      payloadData['type'] = normalizedType;
    }
    final pleaId = data == null ? null : _extractPleaId(data);
    if (pleaId != null && pleaId.isNotEmpty) {
      payloadData['pleaId'] = pleaId;
    }
    if (payloadData.isNotEmpty) {
      payload = jsonEncode(payloadData);
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

  static Future<bool> _handleAmnestyMessage(RemoteMessage message) async {
    final type = message.data['type']?.toString().trim().toUpperCase();
    if (type != 'AMNESTY') return false;

    final rawDuration =
        message.data['durationMinutes']?.toString().trim() ??
        message.data['duration']?.toString().trim() ??
        '60';
    final durationMinutes = int.tryParse(rawDuration) ?? 60;

    await _broadcastAmnestyIntent(durationMinutes);

    await _showAmnestyNotification(durationMinutes);
    return true;
  }

  static Future<void> _broadcastAmnestyIntent(int durationMinutes) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _amnestyBridge.invokeMethod('broadcastAmnestyGranted', {
        'durationMinutes': durationMinutes,
      });
    } catch (_) {
      // Best-effort only. Native FCM receiver is the primary fallback path.
    }
  }

  static Future<void> _showAmnestyNotification(int durationMinutes) async {
    await _initializeLocalNotifications();

    final androidDetails = AndroidNotificationDetails(
      'squad_alerts',
      'Squad Alerts',
      channelDescription: 'High-priority alerts for incoming squad pleas.',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('lookatthisdude'),
      icon: 'notification_icon',
      color: ThemeService.instance.accentColor.value,
    );
    const iosDetails = DarwinNotificationDetails(presentSound: true);
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = 'Amnesty Granted';
    final body =
        'The Architect has granted you Amnesty for $durationMinutes minutes.';

    final notificationId = Random().nextInt(1 << 31);
    await _localNotifications.show(notificationId, title, body, details);
  }
}
