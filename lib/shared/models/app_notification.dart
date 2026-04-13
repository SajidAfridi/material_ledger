import 'dart:convert';

/// Type of notification — drives icon, color, and action behavior.
enum NotificationType {
  approved('approved'),
  lowStock('low_stock'),
  dispatched('dispatched'),
  message('message'),
  weeklySummary('weekly_summary'),
  rejected('rejected'),
  info('info');

  const NotificationType(this.key);
  final String key;

  static NotificationType fromKey(String key) => NotificationType.values
      .firstWhere((t) => t.key == key, orElse: () => NotificationType.info);
}

/// A single in-app notification.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.titleSecondary,
    required this.body,
    required this.timestamp,
    this.actionLabel,
    this.isRead = false,
    this.isBanner = false,
    this.bannerHeadline,
    this.bannerLabel,
    // ─── Enhanced Fields ─────────────────────
    this.project,
    this.projectSecondary,
    this.initiatorName,
    this.initiatorRole,
    this.initiatorAction,
    this.initiatorActionSecondary,
    this.isUrgent = false,
    this.chipLabel,
  });

  final String id;
  final NotificationType type;

  /// English title.
  final String title;

  /// Secondary-language (Urdu) title.
  final String titleSecondary;

  /// Body description text.
  final String body;

  final DateTime timestamp;

  /// Optional inline CTA label (e.g. "Reply Now").
  final String? actionLabel;

  /// Whether this notification has been read.
  final bool isRead;

  /// Whether this is a full-width banner card (e.g. Weekly Summary).
  final bool isBanner;

  /// Main headline for banner cards.
  final String? bannerHeadline;

  /// Small label above the headline for banner cards.
  final String? bannerLabel;

  // ─── Enhanced Fields ──────────────────────────────────────────

  /// Optional project name (English).
  final String? project;

  /// Optional project name (secondary language).
  final String? projectSecondary;

  /// Name of the person who initiated this notification.
  final String? initiatorName;

  /// Role of the initiator.
  final String? initiatorRole;

  /// English action description (e.g. "initiated this request.").
  final String? initiatorAction;

  /// Secondary-language action description.
  final String? initiatorActionSecondary;

  /// Whether this notification is urgent (for urgent filter).
  final bool isUrgent;

  /// Short type label shown in the chip (e.g. "APPROVAL REQUIRED").
  final String? chipLabel;

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
    body: body,
    timestamp: timestamp,
    actionLabel: actionLabel,
    isRead: isRead ?? this.isRead,
    isBanner: isBanner,
    bannerHeadline: bannerHeadline,
    bannerLabel: bannerLabel,
    project: project,
    projectSecondary: projectSecondary,
    initiatorName: initiatorName,
    initiatorRole: initiatorRole,
    initiatorAction: initiatorAction,
    initiatorActionSecondary: initiatorActionSecondary,
    isUrgent: isUrgent,
    chipLabel: chipLabel,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.key,
    'title': title,
    'titleSecondary': titleSecondary,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
    'actionLabel': actionLabel,
    'isRead': isRead,
    'isBanner': isBanner,
    'bannerHeadline': bannerHeadline,
    'bannerLabel': bannerLabel,
    'project': project,
    'projectSecondary': projectSecondary,
    'initiatorName': initiatorName,
    'initiatorRole': initiatorRole,
    'initiatorAction': initiatorAction,
    'initiatorActionSecondary': initiatorActionSecondary,
    'isUrgent': isUrgent,
    'chipLabel': chipLabel,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: NotificationType.fromKey(json['type'] as String),
        title: json['title'] as String,
        titleSecondary: json['titleSecondary'] as String? ?? '',
        body: json['body'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        actionLabel: json['actionLabel'] as String?,
        isRead: json['isRead'] as bool? ?? false,
        isBanner: json['isBanner'] as bool? ?? false,
        bannerHeadline: json['bannerHeadline'] as String?,
        bannerLabel: json['bannerLabel'] as String?,
        project: json['project'] as String?,
        projectSecondary: json['projectSecondary'] as String?,
        initiatorName: json['initiatorName'] as String?,
        initiatorRole: json['initiatorRole'] as String?,
        initiatorAction: json['initiatorAction'] as String?,
        initiatorActionSecondary: json['initiatorActionSecondary'] as String?,
        isUrgent: json['isUrgent'] as bool? ?? false,
        chipLabel: json['chipLabel'] as String?,
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
