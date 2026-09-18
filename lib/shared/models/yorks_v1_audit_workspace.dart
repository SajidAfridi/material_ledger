enum YorksV1AuditModule {
  projects('projects'),
  materialRequests('material_requests'),
  logistics('logistics'),
  inventory('inventory'),
  rentals('rentals'),
  users('users'),
  documents('documents'),
  accounts('accounts'),
  workforce('workforce'),
  configuration('configuration'),
  system('system');

  const YorksV1AuditModule(this.wireValue);
  final String wireValue;

  static YorksV1AuditModule fromWire(Object? value) => values.firstWhere(
    (module) => module.wireValue == value,
    orElse: () => YorksV1AuditModule.system,
  );
}

enum YorksV1AuditSeverity {
  unclassified,
  normal,
  warning,
  critical;

  static YorksV1AuditSeverity fromWire(Object? value) => values.firstWhere(
    (severity) => severity.name == value,
    orElse: () => YorksV1AuditSeverity.unclassified,
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
    this.actorId,
    this.projectId,
    this.eventType,
    this.severity,
    this.entityId,
    this.entityType,
    this.scope,
    this.asOf,
    this.cursorAt,
    this.cursorId,
  });

  final String search;
  final YorksV1AuditModule? module;
  final YorksV1AuditQuickFilter? quickFilter;
  final DateTime? from;
  final DateTime? to;
  final int page;
  final int pageSize;
  final String? actorId,
      projectId,
      eventType,
      severity,
      entityId,
      entityType,
      scope;
  final DateTime? asOf;
  final DateTime? cursorAt;
  final String? cursorId;

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
    String? actorId,
    projectId,
    eventType,
    severity,
    entityId,
    entityType,
    scope,
    DateTime? asOf,
    bool clearAdvanced = false,
    bool clearSnapshot = false,
    DateTime? cursorAt,
    String? cursorId,
    bool clearCursor = false,
  }) => YorksV1AuditFilter(
    search: search ?? this.search,
    module: clearModule ? null : module ?? this.module,
    quickFilter: clearQuickFilter ? null : quickFilter ?? this.quickFilter,
    from: clearDates ? null : from ?? this.from,
    to: clearDates ? null : to ?? this.to,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
    actorId: clearAdvanced ? null : actorId ?? this.actorId,
    projectId: clearAdvanced ? null : projectId ?? this.projectId,
    eventType: clearAdvanced ? null : eventType ?? this.eventType,
    severity: clearAdvanced ? null : severity ?? this.severity,
    entityId: clearAdvanced ? null : entityId ?? this.entityId,
    entityType: clearAdvanced ? null : entityType ?? this.entityType,
    scope: clearAdvanced ? null : scope ?? this.scope,
    asOf: clearSnapshot ? null : asOf ?? this.asOf,
    cursorAt: clearCursor ? null : cursorAt ?? this.cursorAt,
    cursorId: clearCursor ? null : cursorId ?? this.cursorId,
  );

  Map<String, Object?> toRpcParameters() => {
    'p_search': search.trim().isEmpty ? null : search.trim(),
    'p_module': module?.wireValue,
    'p_quick_filter': quickFilter?.wireValue,
    'p_from': from?.toUtc().toIso8601String(),
    'p_to': to?.toUtc().toIso8601String(),
    'p_limit': pageSize,
    'p_offset': offset,
    'p_actor': actorId,
    'p_project': projectId,
    'p_event_type': eventType,
    'p_severity': severity,
    'p_entity_id': entityId,
    'p_entity_type': entityType,
    'p_scope': scope,
    'p_as_of': asOf?.toUtc().toIso8601String(),
    'p_cursor_at': cursorAt?.toUtc().toIso8601String(),
    'p_cursor_id': cursorId,
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
    this.beforeFacts = const {},
    this.scope = 'organization',
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
  final Map<String, String> beforeFacts;
  final String scope;

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
        beforeFacts: {
          for (final entry in _object(json['before_facts']).entries)
            if (entry.value != null) entry.key: entry.value.toString(),
        },
        scope: _nullableText(json['scope']) ?? 'organization',
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
    this.filterOptions = const {},
    this.asOf,
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
  final Map<String, List<Map<String, String>>> filterOptions;
  final DateTime? asOf;

  int get pageCount => filteredCount == 0 ? 1 : (filteredCount / limit).ceil();

  factory YorksV1AuditWorkspace.fromRpcJson(Map<String, dynamic> json) {
    final limit = json['limit'];
    final count = json['filtered_count'];
    final offset = json['offset'];
    if (limit is! int ||
        limit < 1 ||
        limit > 5001 ||
        count is! int ||
        count < 0 ||
        offset is! int ||
        offset < 0 ||
        json['events'] is! List ||
        json['summary'] is! Map ||
        DateTime.tryParse(json['generated_at']?.toString() ?? '') == null) {
      throw const FormatException('Invalid audit workspace');
    }
    final events = json['events'] as List;
    if (events.length > limit ||
        events.length > count ||
        events.any(
          (e) =>
              e is! Map ||
              e['id'] is! String ||
              e['entity_id'] is! String ||
              DateTime.tryParse(e['occurred_at']?.toString() ?? '') == null,
        )) {
      throw const FormatException('Invalid audit events');
    }
    final quick = _object(json['quick_filters']);
    return YorksV1AuditWorkspace(
      generatedAt: _dateTime(json['generated_at']),
      asOf: json['as_of'] == null ? null : _dateTime(json['as_of']),
      filterOptions: {
        for (final entry in _object(json['filter_options']).entries)
          entry.key: _list(entry.value)
              .map((v) => _object(v).map((k, v) => MapEntry(k, v.toString())))
              .toList(),
      },
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
