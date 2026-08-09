import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart' show appRouterProvider;
import '../../firebase_options.dart';
import '../models/app_notification.dart';
import '../providers/language_provider.dart' show supabaseClientProvider;
import 'observability_service.dart';

/// Optional project-specific Web Push key. Firebase supports its default VAPID
/// key when this is absent; a release can still inject the project key for push
/// services that require a non-default key without placing credentials in
/// source control.
const _webPushVapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

const _androidChannel = AndroidNotificationChannel(
  'yorks_push',
  'Yorks notifications',
  description: 'Workflow alerts and controlled-record updates.',
  importance: Importance.high,
);

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
/// stays the backend/auth/db); [NoopPushService] remains the deterministic
/// test/unsupported-platform implementation.
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
/// own isolate). It must remain short and cannot update Riverpod or UI state.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _debugMessage('background', message);
  } catch (error, stackTrace) {
    _debugFailure('background initialization', error, stackTrace);
  }
}

/// Registers the required top-level handler before the app starts building.
/// Keeping it outside a widget prevents release tree-shaking from dropping the
/// callback and means a background delivery can be handled after the first
/// normal launch.
void registerFirebaseBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);
}

void _debugMessage(String phase, RemoteMessage message) {
  // FCM registration tokens and payloads are device/user data. Keep the
  // requested diagnostic output strictly to development consoles; production
  // observability receives only failures through the scrubbed reporter below.
  if (!kDebugMode) return;
  debugPrint(
    '[fcm][$phase] id=${message.messageId ?? '-'} '
    'notification=${message.notification} data=${message.data}',
  );
}

void _debugToken(String token) {
  if (kDebugMode) debugPrint('[fcm] device token: $token');
}

void _debugFailure(String phase, Object error, StackTrace stackTrace) {
  if (kDebugMode) {
    debugPrint('[fcm][$phase] $error\n$stackTrace');
  }
}

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
  Future<void>? _initializing;

  @override
  Stream<PushMessage> get onMessage => _controller.stream;

  @override
  Future<String?> register() async {
    await initialize();
    if (!_ready) return null;
    try {
      final token = await _getToken();
      if (token != null) _debugToken(token);
      // [initialize] can run before authentication exists (so permission is
      // requested on app launch). Repeat this owner-bound registration after a
      // later sign-in instead of leaving a token unassociated with that user.
      await _registerToken(token);
      return token;
    } catch (e, st) {
      _observe(e, st);
      return null;
    }
  }

  /// Full setup: Firebase, permission, background handler, local-notification
  /// display for foreground pushes, tap → deep-link, and device-token
  /// registration (+ refresh). Call once at app start; later calls no-op.
  Future<void> initialize() {
    if (_ready) return Future<void>.value();
    final inFlight = _initializing;
    if (inFlight != null) return inFlight;
    final attempt = _initialize();
    _initializing = attempt;
    return attempt.whenComplete(() {
      if (identical(_initializing, attempt)) _initializing = null;
    });
  }

  Future<void> _initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, st) {
      // Unsupported desktop targets and missing native configuration must not
      // block Yorks. Android, iOS and web use the generated options above.
      _debugFailure('initialization', e, st);
      return;
    }
    _ready = true;

    try {
      await _localPlugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (resp) => _openRoute(resp.payload),
      );
      final android = _localPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(_androidChannel);
    } catch (e, st) {
      _observe(e, st);
    }

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (kDebugMode) {
        debugPrint('[fcm] permission: ${settings.authorizationStatus.name}');
      }
    } catch (e, st) {
      _observe(e, st);
    }

    // Foreground: FCM does NOT auto-display anything, so show it ourselves
    // (a transient banner — the real record already synced into the
    // notifications table) and publish it on [onMessage] for any observer.
    FirebaseMessaging.onMessage.listen((m) {
      _debugMessage('foreground', m);
      _showForeground(m);
      _controller.add(_toPushMessage(m));
    });
    // Backgrounded (app alive, tapped from the tray) → deep-link.
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      _debugMessage('opened', m);
      _openRoute(m.data['route'] as String?);
    });
    // Terminated (the tap launched the app fresh) → check once at startup.
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _debugMessage('initial', initial);
        _openRoute(initial.data['route'] as String?);
      }
    } catch (e, st) {
      _observe(e, st);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _debugToken(token);
      _registerToken(token);
    });
  }

  Future<String?> _getToken() {
    if (!kIsWeb) return FirebaseMessaging.instance.getToken();
    if (_webPushVapidKey.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[fcm] FIREBASE_WEB_VAPID_KEY is not configured; using Firebase default.',
        );
      }
      return FirebaseMessaging.instance.getToken(
        serviceWorkerScriptPath: 'firebase-messaging-sw.js',
      );
    }
    return FirebaseMessaging.instance.getToken(
      vapidKey: _webPushVapidKey,
      // This service worker imports Flutter's generated cache worker, so FCM
      // does not replace the PWA/offline worker at the root scope.
      serviceWorkerScriptPath: 'firebase-messaging-sw.js',
    );
  }

  PushMessage _toPushMessage(RemoteMessage m) =>
      PushMessage.fromData(m.data.map((k, v) => MapEntry(k, '$v')));

  Future<void> _showForeground(RemoteMessage m) async {
    final n = m.notification;
    if (n == null) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'yorks_push',
        'Yorks notifications',
        channelDescription: 'Workflow alerts and controlled-record updates.',
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
  Future<void> _registerToken([String? currentToken]) async {
    final client = _ref.read(supabaseClientProvider);
    final authUserId = client?.auth.currentUser?.id;
    if (client == null || authUserId == null || authUserId.isEmpty) return;
    try {
      final token = currentToken ?? await _getToken();
      if (token == null) return;
      await client.rpc(
        'v1_register_push_device',
        params: {
          'p_token': token,
          'p_platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        },
      );
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
      final token = await _getToken();
      if (token == null) return;
      await client.rpc('v1_unregister_push_device', params: {'p_token': token});
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

final pushServiceProvider = Provider<PushService>((ref) => FcmPushService(ref));
