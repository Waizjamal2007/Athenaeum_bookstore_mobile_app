import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Notification payloads are shown by the OS in background/terminated state.
  // Do not show another local notification here: that creates duplicates.
}

class NotificationService {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final local = FlutterLocalNotificationsPlugin();
  static const topic = 'athenaeum_readers'; // Public catalog/news only.
  static const channel = AndroidNotificationChannel(
    'athenaeum_updates',
    'Athenaeum updates',
    description: 'Books, announcements and order updates',
    importance: Importance.high,
  );
  static bool _initialized = false;
  static String? _uid, _token;
  static Map<String, dynamic>? _pending;
  static final ValueNotifier<String?> status = ValueNotifier(null);
  static Future<void> _queue = Future.value();
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (_initialized || !supported) return;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_book'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          try {
            open(
              Map<String, dynamic>.from(jsonDecode(response.payload!) as Map),
            );
          } catch (_) {
            open({});
          }
        }
      },
    );
    await local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
    FirebaseMessaging.onMessage.listen((message) async {
      if (defaultTargetPlatform != TargetPlatform.android ||
          message.notification == null)
        return;
      final notification = message.notification!;
      await local.show(
        message.messageId.hashCode & 0x7fffffff,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_book',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) => open(m.data));
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _queue = _queue
          .then((_) async {
            if (_uid == null) return;
            final old = _token;
            if (old != null && old != token) {
              await FirebaseService.db.ref('deviceTokens/$_uid/$old').remove();
            }
            _token = token;
            await _saveToken();
          })
          .catchError((Object e) {
            status.value = 'Unable to refresh notification token.';
          });
    });
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _pending = initial.data;
    final launch = await local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        launch?.notificationResponse?.payload != null) {
      try {
        _pending = Map<String, dynamic>.from(
          jsonDecode(launch!.notificationResponse!.payload!) as Map,
        );
      } catch (_) {
        _pending = {};
      }
    }
    _initialized = true;
  }

  static Future<void> attachUser(User user) {
    _queue = _queue.then((_) async {
      if (!supported) {
        status.value = 'Push notifications are configured for Android and iOS.';
        return;
      }
      try {
        await init();
        if (_uid == user.uid && _token != null) {
          flushPending();
          return;
        }
        await _detach();
        final permission = await FirebaseMessaging.instance.requestPermission();
        if (permission.authorizationStatus == AuthorizationStatus.denied) {
          status.value =
              'Notifications are disabled. Enable them in phone settings.';
          return;
        }
        // On Apple devices the APNs token must exist before FCM registration.
        if (defaultTargetPlatform == TargetPlatform.iOS &&
            await FirebaseMessaging.instance.getAPNSToken() == null) {
          status.value = 'Notification registration is pending. Tap Enable notifications again shortly.';
          return;
        }
        _token = await FirebaseMessaging.instance.getToken();
        _uid = user.uid;
        await _saveToken();
        await FirebaseMessaging.instance.subscribeToTopic(topic);
        status.value = 'Notifications enabled';
        flushPending();
      } catch (e) {
        status.value = 'Notification setup failed. Check Firebase and phone permissions, then retry.';
        debugPrint('Notification setup: $e');
      }
    });
    return _queue;
  }

  static Future<void> _saveToken() async {
    if (_uid != null && _token != null) {
      await FirebaseService.db.ref('deviceTokens/$_uid/$_token').set({
        'updatedAt': ServerValue.timestamp,
        'platform': defaultTargetPlatform.name,
      });
    }
  }

  static Future<void> _detach() async {
    final uid = _uid, token = _token;
    _uid = null;
    _token = null;
    if (!supported || !_initialized) return;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    } catch (_) {
      /* Public topic, never carries personal order details. */
    }
    if (uid != null && token != null) {
      try {
        await FirebaseService.db.ref('deviceTokens/$uid/$token').remove();
      } catch (_) {
        /* Deleted/disabled accounts can no longer remove tokens. */
      }
    }
  }

  static Future<void> detachUser() {
    _queue = _queue.then((_) => _detach());
    return _queue;
  }

  static void open(Map<String, dynamic> data) {
    _pending = data;
    flushPending();
  }

  static void flushPending() {
    final user = FirebaseAuth.instance.currentUser;
    if (_pending == null || user == null || !user.emailVerified) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pending == null || navigatorKey.currentState == null) return;
      final data = _pending!;
      _pending = null;
      // Never expose another user's order via a stale notification tap.
      final uid = data['userId'];
      if (uid != null && uid != FirebaseAuth.instance.currentUser?.uid) return;
      navigatorKey.currentState!.pushNamed('/notifications');
    });
  }
}
