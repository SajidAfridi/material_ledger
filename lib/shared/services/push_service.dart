import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';

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

/// Server push behind one interface. No-op today; on Firebase day swap for an
/// FCM implementation that registers a token, listens for messages, and forwards
/// each [PushMessage] into `notificationsProvider.add(...)` + handles taps via
/// the stored `route` (the deep-link plumbing already exists). The rest of the
/// app is unchanged.
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

final pushServiceProvider = Provider<PushService>(
  (ref) => const NoopPushService(),
);
