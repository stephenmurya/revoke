import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../native_bridge.dart';
import 'theme_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.handleBackgroundRemoteMessage(message);
}

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
  static bool _localNotificationsInitialized = false;
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
    print(
      'FCM_DEBUG: Notification permission status = ${settings.authorizationStatus.name}',
    );
  }

  static Future<void> _subscribeToGlobalTopic() async {
    try {
      await _messaging.subscribeToTopic('global_citizens');
      print('FCM_DEBUG: Subscribed to topic global_citizens');
    } catch (e) {
      print('FCM_DEBUG: Failed to subscribe to global_citizens: $e');
    }
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
        print(
          'FCM_DEBUG: Foreground message ignored (empty title/body). id=${message.messageId}',
        );
        return;
      }

      print(
        'FCM_DEBUG: Foreground message displayed. id=${message.messageId} data=${message.data}',
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

  static Future<bool> _handleAmnestyMessage(RemoteMessage message) async {
    final type = message.data['type']?.toString().trim().toUpperCase();
    if (type != 'AMNESTY') return false;

    final rawDuration = message.data['duration']?.toString().trim() ?? '60';
    final durationMinutes = int.tryParse(rawDuration) ?? 60;

    try {
      await NativeBridge.pauseMonitoring(durationMinutes);
    } catch (e) {
      print('FCM_DEBUG: Failed to pause monitoring for amnesty: $e');
    }

    await _showAmnestyNotification(durationMinutes);
    return true;
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
