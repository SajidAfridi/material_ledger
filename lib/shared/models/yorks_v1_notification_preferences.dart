/// Server-owned personal notification controls.
///
/// The notification centre itself is intentionally not optional: it is the
/// durable, authorized history of workflow facts. These preferences control
/// only delivery and foreground presentation.
class YorksV1NotificationPreferences {
  const YorksV1NotificationPreferences({
    required this.revision,
    required this.pushEnabled,
    required this.workflowPushEnabled,
    required this.teamChatPushEnabled,
    required this.foregroundAlertsEnabled,
    required this.soundEnabled,
    this.updatedAt,
  });

  const YorksV1NotificationPreferences.defaults()
    : revision = 0,
      pushEnabled = true,
      workflowPushEnabled = true,
      teamChatPushEnabled = true,
      foregroundAlertsEnabled = true,
      soundEnabled = true,
      updatedAt = null;

  final int revision;
  final bool pushEnabled;
  final bool workflowPushEnabled;
  final bool teamChatPushEnabled;
  final bool foregroundAlertsEnabled;
  final bool soundEnabled;
  final DateTime? updatedAt;

  bool allowsPushFor({required bool teamChat}) =>
      pushEnabled && (teamChat ? teamChatPushEnabled : workflowPushEnabled);

  YorksV1NotificationPreferences copyWith({
    int? revision,
    bool? pushEnabled,
    bool? workflowPushEnabled,
    bool? teamChatPushEnabled,
    bool? foregroundAlertsEnabled,
    bool? soundEnabled,
    DateTime? updatedAt,
  }) => YorksV1NotificationPreferences(
    revision: revision ?? this.revision,
    pushEnabled: pushEnabled ?? this.pushEnabled,
    workflowPushEnabled: workflowPushEnabled ?? this.workflowPushEnabled,
    teamChatPushEnabled: teamChatPushEnabled ?? this.teamChatPushEnabled,
    foregroundAlertsEnabled:
        foregroundAlertsEnabled ?? this.foregroundAlertsEnabled,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, bool> toPatch() => {
    'push_enabled': pushEnabled,
    'workflow_push_enabled': workflowPushEnabled,
    'team_chat_push_enabled': teamChatPushEnabled,
    'foreground_alerts_enabled': foregroundAlertsEnabled,
    'sound_enabled': soundEnabled,
  };

  factory YorksV1NotificationPreferences.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    const exactKeys = {
      'schema_version',
      'revision',
      'push_enabled',
      'workflow_push_enabled',
      'team_chat_push_enabled',
      'foreground_alerts_enabled',
      'sound_enabled',
      'updated_at',
    };
    if (json.keys.any((key) => !exactKeys.contains(key)) ||
        json['schema_version'] != 1 ||
        json['revision'] is! int ||
        (json['revision'] as int) < 0 ||
        json['push_enabled'] is! bool ||
        json['workflow_push_enabled'] is! bool ||
        json['team_chat_push_enabled'] is! bool ||
        json['foreground_alerts_enabled'] is! bool ||
        json['sound_enabled'] is! bool ||
        (json['updated_at'] != null && json['updated_at'] is! String)) {
      throw const FormatException(
        'Invalid Yorks notification preference projection',
      );
    }
    final updatedAt = json['updated_at'] == null
        ? null
        : DateTime.tryParse(json['updated_at'] as String)?.toLocal();
    if (json['updated_at'] != null && updatedAt == null) {
      throw const FormatException('Invalid notification preference timestamp');
    }
    return YorksV1NotificationPreferences(
      revision: json['revision'] as int,
      pushEnabled: json['push_enabled'] as bool,
      workflowPushEnabled: json['workflow_push_enabled'] as bool,
      teamChatPushEnabled: json['team_chat_push_enabled'] as bool,
      foregroundAlertsEnabled: json['foreground_alerts_enabled'] as bool,
      soundEnabled: json['sound_enabled'] as bool,
      updatedAt: updatedAt,
    );
  }
}
