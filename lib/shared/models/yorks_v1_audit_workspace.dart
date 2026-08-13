enum YorksV1AuditModule {
  projects('projects'),
  materialRequests('material_requests'),
  logistics('logistics'),
  inventory('inventory'),
  rentals('rentals'),
  users('users'),
  documents('documents'),
  system('system');

  const YorksV1AuditModule(this.wireValue);
  final String wireValue;

  static YorksV1AuditModule fromWire(Object? value) => values.firstWhere(
    (module) => module.wireValue == value,
    orElse: () => YorksV1AuditModule.system,
  );
}

enum YorksV1AuditSeverity {
  normal,
  warning,
  critical;

  static YorksV1AuditSeverity fromWire(Object? value) => values.firstWhere(
    (severity) => severity.name == value,
    orElse: () => YorksV1AuditSeverity.normal,
  );
}

enum YorksV1AuditQuickFilter {
  critical('critical'),
  exceptions('exceptions'),
  dataChanges('data_changes'),
  approvals('approvals'),
  access('access');

  const YorksV1AuditQuickFilter(this.wireValue);
  final String wireValue;
}

class YorksV1AuditFilter {
  const YorksV1AuditFilter({
    this.search = '',
    this.module,
    this.quickFilter,
    this.from,
    this.to,
    this.page = 0,
    this.pageSize = 12,
  });

  final String search;
  final YorksV1AuditModule? module;
  final YorksV1AuditQuickFilter? quickFilter;
  final DateTime? from;
  final DateTime? to;
  final int page;
  final int pageSize;

  int get offset => page * pageSize;

  YorksV1AuditFilter copyWith({
    String? search,
    YorksV1AuditModule? module,
    bool clearModule = false,
    YorksV1AuditQuickFilter? quickFilter,
    bool clearQuickFilter = false,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    int? page,
    int? pageSize,
  }) => YorksV1AuditFilter(
    search: search ?? this.search,
    module: clearModule ? null : module ?? this.module,
    quickFilter: clearQuickFilter ? null : quickFilter ?? this.quickFilter,
    from: clearDates ? null : from ?? this.from,
    to: clearDates ? null : to ?? this.to,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
  );

  Map<String, Object?> toRpcParameters() => {
    'p_search': search.trim().isEmpty ? null : search.trim(),
    'p_module': module?.wireValue,
    'p_quick_filter': quickFilter?.wireValue,
    'p_from': from?.toUtc().toIso8601String(),
    'p_to': to?.toUtc().toIso8601String(),
    'p_limit': pageSize,
    'p_offset': offset,
  };
}

class YorksV1AuditSummary {
  const YorksV1AuditSummary({
    required this.totalActivities,
    required this.criticalActivities,
    required this.activeUsers,
    required this.entitiesMonitored,
    required this.auditAlerts,
    required this.dataIntegrityPercent,
    required this.currentPeriodActivities,
    required this.previousPeriodActivities,
  });

  final int totalActivities;
  final int criticalActivities;
  final int activeUsers;
  final int entitiesMonitored;
  final int auditAlerts;
  final double dataIntegrityPercent;
  final int currentPeriodActivities;
  final int previousPeriodActivities;

  factory YorksV1AuditSummary.fromJson(Map<String, dynamic> json) =>
      YorksV1AuditSummary(
        totalActivities: _integer(json['total_activities']),
        criticalActivities: _integer(json['critical_activities']),
        activeUsers: _integer(json['active_users']),
        entitiesMonitored: _integer(json['entities_monitored']),
        auditAlerts: _integer(json['audit_alerts']),
        dataIntegrityPercent: _decimal(json['data_integrity_percent']),
        currentPeriodActivities: _integer(json['current_period_activities']),
        previousPeriodActivities: _integer(json['previous_period_activities']),
      );
}

class YorksV1AuditEvent {
  const YorksV1AuditEvent({
    required this.id,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.module,
    required this.severity,
    required this.actorAuthUserId,
    required this.actorDisplayName,
    required this.actorExactRole,
    required this.occurredAt,
    required this.reference,
    required this.facts,
    required this.attributionVerified,
    this.projectId,
    this.projectRef,
    this.projectName,
    this.reason,
  });

  final String id;
  final String eventType;
  final String entityType;
  final String entityId;
  final String? projectId;
  final YorksV1AuditModule module;
  final YorksV1AuditSeverity severity;
  final String actorAuthUserId;
  final String actorDisplayName;
  final String actorExactRole;
  final DateTime occurredAt;
  final String reference;
  final String? projectRef;
  final String? projectName;
  final String? reason;
  final Map<String, String> facts;
  final bool attributionVerified;

  factory YorksV1AuditEvent.fromJson(Map<String, dynamic> json) =>
      YorksV1AuditEvent(
        id: _text(json['id']),
        eventType: _text(json['event_type']),
        entityType: _text(json['entity_type']),
        entityId: _text(json['entity_id']),
        projectId: _nullableText(json['project_id']),
        module: YorksV1AuditModule.fromWire(json['module']),
        severity: YorksV1AuditSeverity.fromWire(json['severity']),
        actorAuthUserId: _text(json['actor_auth_user_id']),
        actorDisplayName: _text(json['actor_display_name']),
        actorExactRole: _text(json['actor_exact_role']),
        occurredAt: _dateTime(json['occurred_at']),
        reference: _text(json['reference']),
        projectRef: _nullableText(json['project_ref']),
        projectName: _nullableText(json['project_name']),
        reason: _nullableText(json['reason']),
        facts: {
          for (final entry in _object(json['facts']).entries)
            if (entry.value != null) entry.key: entry.value.toString(),
        },
        attributionVerified: json['attribution_verified'] == true,
      );
}

class YorksV1AuditActivityGroup {
  const YorksV1AuditActivityGroup({
    required this.key,
    required this.activityCount,
    required this.percent,
  });

  final String key;
  final int activityCount;
  final double percent;

  factory YorksV1AuditActivityGroup.entity(Map<String, dynamic> json) =>
      YorksV1AuditActivityGroup(
        key: _text(json['entity_type']),
        activityCount: _integer(json['activity_count']),
        percent: _decimal(json['percent']),
      );

  factory YorksV1AuditActivityGroup.module(Map<String, dynamic> json) =>
      YorksV1AuditActivityGroup(
        key: _text(json['module']),
        activityCount: _integer(json['activity_count']),
        percent: _decimal(json['percent']),
      );
}

class YorksV1AuditTrendPoint {
  const YorksV1AuditTrendPoint({
    required this.date,
    required this.activityCount,
  });

  final DateTime date;
  final int activityCount;

  factory YorksV1AuditTrendPoint.fromJson(Map<String, dynamic> json) =>
      YorksV1AuditTrendPoint(
        date: _dateTime(json['date']),
        activityCount: _integer(json['activity_count']),
      );
}

class YorksV1AuditAlert {
  const YorksV1AuditAlert({
    required this.id,
    required this.eventType,
    required this.entityType,
    required this.severity,
    required this.reference,
    required this.occurredAt,
    this.reason,
  });

  final String id;
  final String eventType;
  final String entityType;
  final YorksV1AuditSeverity severity;
  final String reference;
  final String? reason;
  final DateTime occurredAt;

  factory YorksV1AuditAlert.fromJson(Map<String, dynamic> json) =>
      YorksV1AuditAlert(
        id: _text(json['id']),
        eventType: _text(json['event_type']),
        entityType: _text(json['entity_type']),
        severity: YorksV1AuditSeverity.fromWire(json['severity']),
        reference: _text(json['reference']),
        reason: _nullableText(json['reason']),
        occurredAt: _dateTime(json['occurred_at']),
      );
}

class YorksV1AuditWorkspace {
  const YorksV1AuditWorkspace({
    required this.generatedAt,
    required this.summary,
    required this.filteredCount,
    required this.limit,
    required this.offset,
    required this.events,
    required this.topEntities,
    required this.moduleActivity,
    required this.trend,
    required this.quickFilterCounts,
    required this.alerts,
  });

  final DateTime generatedAt;
  final YorksV1AuditSummary summary;
  final int filteredCount;
  final int limit;
  final int offset;
  final List<YorksV1AuditEvent> events;
  final List<YorksV1AuditActivityGroup> topEntities;
  final List<YorksV1AuditActivityGroup> moduleActivity;
  final List<YorksV1AuditTrendPoint> trend;
  final Map<YorksV1AuditQuickFilter, int> quickFilterCounts;
  final List<YorksV1AuditAlert> alerts;

  int get pageCount => filteredCount == 0 ? 1 : (filteredCount / limit).ceil();

  factory YorksV1AuditWorkspace.fromRpcJson(Map<String, dynamic> json) {
    final quick = _object(json['quick_filters']);
    return YorksV1AuditWorkspace(
      generatedAt: _dateTime(json['generated_at']),
      summary: YorksV1AuditSummary.fromJson(_object(json['summary'])),
      filteredCount: _integer(json['filtered_count']),
      limit: _integer(json['limit']),
      offset: _integer(json['offset']),
      events: _list(json['events'])
          .map((item) => YorksV1AuditEvent.fromJson(_object(item)))
          .toList(growable: false),
      topEntities: _list(json['top_entities'])
          .map((item) => YorksV1AuditActivityGroup.entity(_object(item)))
          .toList(growable: false),
      moduleActivity: _list(json['module_activity'])
          .map((item) => YorksV1AuditActivityGroup.module(_object(item)))
          .toList(growable: false),
      trend: _list(json['trend'])
          .map((item) => YorksV1AuditTrendPoint.fromJson(_object(item)))
          .toList(growable: false),
      quickFilterCounts: {
        for (final filter in YorksV1AuditQuickFilter.values)
          filter: _integer(quick[filter.wireValue]),
      },
      alerts: _list(json['alerts'])
          .map((item) => YorksV1AuditAlert.fromJson(_object(item)))
          .toList(growable: false),
    );
  }
}

Map<String, dynamic> _object(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

List<dynamic> _list(Object? value) => value is List ? value : const [];

String _text(Object? value) => value?.toString() ?? '';

String? _nullableText(Object? value) {
  final text = value?.toString();
  return text == null || text.trim().isEmpty ? null : text;
}

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

double _decimal(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;

DateTime _dateTime(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
    DateTime.fromMillisecondsSinceEpoch(0);
