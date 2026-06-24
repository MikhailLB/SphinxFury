import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'net_client.dart';
import 'vault_store.dart';

// ─── SignalDispatcher ───────────────────────────────────────
// Firebase Messaging glue + local-notification surface.
//
// Channel id intentionally project-unique (`sphinx_signal_channel`)
// so it won't collide with anything else in user's app drawer.
//
// Push URL routing rules (carry over from TZ):
//
//   • Cold start (app killed) → save url into VaultStore,
//     consumed by IntroView on next boot.
//   • Warm start (background) → invoke [onWarmUrl] callback.
//   • Foreground             → local notification, tap routes
//                              via [onWarmUrl].
//
// We also explicitly persist `notification_os_denied` when the
// system dialog reports "denied", so the in-app prompt no longer
// reappears after the 3-day cool-down.
// ────────────────────────────────────────────────────────────

const String _channelId = 'sphinx_signal_channel';
const String _channelName = 'Sphinx Signal';
const String _logTag = '«signal»';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage _) async {
  // Background isolate: nothing to do here — OS surfaces the
  // notification, taps are routed at process resume.
}

class SignalDispatcher {
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final VaultStore _vault;
  FirebaseMessaging? _fcm;
  String? _token;
  bool _started = false;

  /// Invoked on warm taps with the embedded url (if any).
  void Function(String url)? onWarmUrl;

  /// Invoked whenever FCM rotates the token.
  void Function(String token)? onTokenRotated;

  SignalDispatcher(this._vault);

  String? get token => _token;

  Future<void> ignite() async {
    if (_started) return;
    try {
      await Firebase.initializeApp();
      final fcm = FirebaseMessaging.instance;
      _fcm = fcm;

      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

      await _wireLocalNotifications();

      _token = await fcm.getToken();

      fcm.onTokenRefresh.listen((t) {
        _token = t;
        onTokenRotated?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_onForegroundPush);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final cold = await fcm.getInitialMessage();
      if (cold != null) _onColdTap(cold);

      _started = true;
    } catch (e) {
      if (kDebugMode) debugPrint('$_logTag ignite failed: $e');
    }
  }

  Future<void> _wireLocalNotifications() async {
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload == null) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final url = data['url'];
          if (url is String && url.isNotEmpty) onWarmUrl?.call(url);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final plugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await plugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Important Sphinx Fury updates',
          importance: Importance.high,
        ),
      );
    }
  }

  /// Ask the OS for notification permission.
  /// Returns true when granted (or implicit on Android < 13).
  Future<bool> requestConsent() async {
    if (_fcm == null) return false;
    final settings = await _fcm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final status = settings.authorizationStatus;
    final granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;

    await _vault.markConsent(granted);

    if (status == AuthorizationStatus.denied) {
      // Android won't show the system dialog again — silence the in-app
      // promo too.
      await _vault.markConsentOsBlocked();
    }
    return granted;
  }

  // ── Message handlers ─────────────────────────────────

  void _onForegroundPush(RemoteMessage msg) async {
    final notif = msg.notification;
    if (notif == null || !Platform.isAndroid) return;

    final bigPicUrl = notif.android?.imageUrl;
    AndroidNotificationDetails? details;

    if (bigPicUrl != null && bigPicUrl.isNotEmpty) {
      final bytes = await _fetchImage(bigPicUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
    );

    final payload = msg.data.isNotEmpty ? jsonEncode(msg.data) : null;

    await _local.show(
      notif.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(android: details),
      payload: payload,
    );
  }

  void _onColdTap(RemoteMessage msg) {
    final url = msg.data['url'];
    if (url is String && url.isNotEmpty) {
      _vault.stashPushUrl(url);
    }
  }

  void _onWarmTap(RemoteMessage msg) {
    final url = msg.data['url'];
    if (url is String && url.isNotEmpty) {
      onWarmUrl?.call(url);
    }
  }

  Future<Uint8List?> _fetchImage(String url) async {
    try {
      final res = await netClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }
}
