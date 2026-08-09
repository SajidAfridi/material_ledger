import 'dart:convert';

/// Notification category (drives icon + colour). Kept deliberately small —
/// these map to the lifecycle events the SRS §4.6 calls for: plan updates,
/// request/dispatch updates, low-stock alerts, and general system info.
enum NotificationType {
  plan('plan'),
  request('request'),
  stock('stock'),
  project('project'),
  info('info');

  const NotificationType(this.key);
  final String key;

  static NotificationType fromKey(String key) => NotificationType.values
      .firstWhere((t) => t.key == key, orElse: () => NotificationType.info);
}

/// Where the record is authoritative. Yorks V1 workflow alerts live in the
/// normalized server table and must be acknowledged through its trusted RPC;
/// legacy alerts retain their existing local/sync behavior.
enum NotificationOrigin {
  legacy('legacy'),
  yorksV1('yorks_v1');

  const NotificationOrigin(this.key);
  final String key;

  static NotificationOrigin fromKey(String? key) =>
      key == yorksV1.key ? yorksV1 : legacy;
}

/// A single in-app notification (notification centre — read/unread status).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.titleSecondary,
    required this.timestamp,
    this.body = '',
    this.isRead = false,
    this.refId = '',
    this.route = '',
    this.audience = '',
    this.userId = '',
    this.origin = NotificationOrigin.legacy,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String titleSecondary;
  final String body;
  final DateTime timestamp;
  final bool isRead;

  /// The entity this notification points at (request id / project id). Empty
  /// for general alerts. Paired with [route] to deep-link on tap.
  final String refId;

  /// Resolved navigation target (e.g. `/admin/dispatch/req-123`). Empty means
  /// the notification is informational and tapping it only marks it read.
  final String route;

  /// Intended recipient role (`UserRole.name`, e.g. 'procurement' or
  /// 'engineer'). Empty = broadcast to everyone; admin always sees all
  /// (read-all, FR-068). Backward/Firebase compatible: a missing value decodes
  /// to '' (broadcast), so old persisted notifications keep showing.
  final String audience;

  /// Targets a single user (`AppUser.id`). When set, only that user sees it
  /// (e.g. "your leave was approved") — admin still sees all. Empty = fall back
  /// to [audience] role targeting. Decodes to '' for old/Firebase data.
  final String userId;

  final NotificationOrigin origin;

  bool get isServerAuthoritative => origin == NotificationOrigin.yorksV1;

  /// Human-readable relative time string.
  String get relativeTime {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    title: title,
    titleSecondary: titleSecondary,
    timestamp: timestamp,
    body: body,
    isRead: isRead ?? this.isRead,
    refId: refId,
    route: route,
    audience: audience,
    userId: userId,
    origin: origin,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.key,
    'title': title,
    'titleSecondary': titleSecondary,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
    'refId': refId,
    'route': route,
    'audience': audience,
    'userId': userId,
    'origin': origin.key,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: NotificationType.fromKey(json['type'] as String? ?? 'info'),
        title: json['title'] as String,
        titleSecondary: json['titleSecondary'] as String? ?? '',
        body: json['body'] as String? ?? '',
        timestamp: DateTime.parse(json['timestamp'] as String),
        isRead: json['isRead'] as bool? ?? false,
        refId: json['refId'] as String? ?? '',
        route: json['route'] as String? ?? '',
        audience: json['audience'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        origin: NotificationOrigin.fromKey(json['origin'] as String?),
      );

  static String encodeList(List<AppNotification> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<AppNotification> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
