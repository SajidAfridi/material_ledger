import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart' show appRouterProvider;
import '../models/app_notification.dart';
import '../providers/language_provider.dart' show supabaseClientProvider;
import '../providers/session_provider.dart';
import 'observability_service.dart';

/// A push notification delivered from a server (its payload already maps onto
/// the in-app [AppNotification] model — `type`, `refId`, `route`, `audience` —
/// so a tapped push deep-links exactly like an in-app alert).
class PushMessage {
  const PushMessage({
    required this.type,
    required this.title,
    this.titleSecondary = '',
    this.body = '',
    this.refId = '',
    this.route = '',
    this.audience = '',
  });

  final NotificationType type;
  final String title;
  final String titleSecondary;
  final String body;
  final String refId;
  final String route;
  final String audience;

  factory PushMessage.fromData(Map<String, String> data) => PushMessage(
    type: NotificationType.fromKey(data['type'] ?? 'info'),
    title: data['title'] ?? '',
    titleSecondary: data['titleSecondary'] ?? '',
    body: data['body'] ?? '',
    refId: data['refId'] ?? '',
    route: data['route'] ?? '',
    audience: data['audience'] ?? '',
  );
}

/// Server push behind one interface. [FcmPushService] is the real
/// implementation (Firebase Cloud Messaging as pure TRANSPORT — Supabase
/// stays the backend/auth/db); [NoopPushService] is the default until a
/// Firebase project is configured.
///
/// IMPORTANT: `notifications` is now a SYNCED table (realtime + hydrate), so
/// the actual [AppNotification] record already reaches every device on its
/// own. A push's job is narrower than the original design here: wake the
/// device and, on tap, deep-link via the payload's `route` — NOT create a
/// second in-app notification record (that would duplicate the synced one).
abstract interface class PushService {
  /// Register for push + return the device token (null when unsupported / no-op).
  Future<String?> register();

  /// Stream of inbound push messages (empty in the no-op).
  Stream<PushMessage> get onMessage;
}

class NoopPushService implements PushService {
  const NoopPushService();

  @override
  Future<String?> register() async => null;

  @override
  Stream<PushMessage> get onMessage => const Stream.empty();
}

/// Required top-level entry point for background FCM messages (invoked in its
/// own isolate). The OS already shows the system banner for a background/
/// terminated push with zero app code — this exists only to satisfy the
/// plugin's API contract (it must be top-level or static).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {}

/// Real push transport (FCM). Every step is defensive: a missing/misconfigured
/// Firebase project (no `google-services.json` / `GoogleService-Info.plist`
/// yet) must never crash or block the app — [initialize] simply leaves push
/// inactive, exactly like Sentry/Supabase when their own config is absent.
class FcmPushService implements PushService {
  FcmPushService(this._ref);
  final Ref _ref;

  final _localPlugin = FlutterLocalNotificationsPlugin();
  final _controller = StreamController<PushMessage>.broadcast();
  bool _ready = false;

  @override
  Stream<PushMessage> get onMessage => _controller.stream;

  @override
  Future<String?> register() async {
    await initialize();
    if (!_ready) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e, st) {
      _observe(e, st);
      return null;
    }
  }

  /// Full setup: Firebase, permission, background handler, local-notification
  /// display for foreground pushes, tap → deep-link, and device-token
  /// registration (+ refresh). Call once at app start; later calls no-op.
  Future<void> initialize() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
    } catch (e, st) {
      _observe(e, st);
      return; // No Firebase config present yet — push stays off.
    }
    _ready = true;

    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

    try {
      await _localPlugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (resp) => _openRoute(resp.payload),
      );
    } catch (e, st) {
      _observe(e, st);
    }

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e, st) {
      _observe(e, st);
    }

    // Foreground: FCM does NOT auto-display anything, so show it ourselves
    // (a transient banner — the real record already synced into the
    // notifications table) and publish it on [onMessage] for any observer.
    FirebaseMessaging.onMessage.listen((m) {
      _showForeground(m);
      _controller.add(_toPushMessage(m));
    });
    // Backgrounded (app alive, tapped from the tray) → deep-link.
    FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => _openRoute(m.data['route'] as String?),
    );
    // Terminated (the tap launched the app fresh) → check once at startup.
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _openRoute(initial.data['route'] as String?);
    } catch (e, st) {
      _observe(e, st);
    }

    await _registerToken();
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => _registerToken());
  }

  PushMessage _toPushMessage(RemoteMessage m) => PushMessage.fromData(
        m.data.map((k, v) => MapEntry(k, '$v')),
      );

  Future<void> _showForeground(RemoteMessage m) async {
    final n = m.notification;
    if (n == null) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'default',
        'Notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _localPlugin.show(
        id: m.hashCode,
        title: n.title,
        body: n.body,
        notificationDetails: details,
        payload: m.data['route'] as String?,
      );
    } catch (e, st) {
      _observe(e, st);
    }
  }

  /// Navigates via the CURRENT router read fresh from Riverpod each time (the
  /// router is recreated on role/session changes — mirrors the existing
  /// pattern in `hardwareActionProvider`, which solves the same "navigate with
  /// no widget context" problem). Never throws — a bad/stale route on tap must
  /// never crash the app.
  void _openRoute(String? route) {
    if (route == null || route.isEmpty) return;
    try {
      _ref.read(appRouterProvider).push(route);
    } catch (e, st) {
      _observe(e, st);
    }
  }

  /// Registers (or refreshes) this device's token against the signed-in user.
  /// Best-effort: push is a convenience, never a requirement to use the app.
  Future<void> _registerToken() async {
    final client = _ref.read(supabaseClientProvider);
    final appUserId = _ref.read(currentUserProvider)?.id;
    if (client == null || appUserId == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await client.from('device_tokens').upsert({
        'id': token,
        'data': {
          'appUserId': appUserId,
          'platform': defaultTargetPlatform.name,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      });
    } catch (e, st) {
      _observe(e, st);
    }
  }

  /// De-registers this device — call on sign-out so a stale token can't keep
  /// receiving pushes meant for the account that just signed out.
  Future<void> unregisterToken() async {
    if (!_ready) return;
    final client = _ref.read(supabaseClientProvider);
    if (client == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await client.from('device_tokens').delete().eq('id', token);
    } catch (e, st) {
      _observe(e, st);
    }
  }

  void _observe(Object e, StackTrace st) {
    try {
      _ref.read(observabilityProvider).recordError(e, st, fatal: false);
    } catch (_) {
      // Observability itself unavailable — nothing further we can do.
    }
  }
}

final pushServiceProvider = Provider<PushService>(
  (ref) => FcmPushService(ref),
);
