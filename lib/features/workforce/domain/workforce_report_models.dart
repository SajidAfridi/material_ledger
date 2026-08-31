enum YorksWorkforceReportKind {
  dailyAttendanceRegister('daily_attendance_register'),
  workerMonthlyTimesheet('worker_monthly_timesheet'),
  supervisorTeamMonthly('supervisor_team_monthly'),
  projectWorkforce('project_workforce'),
  companyWorkforceSummary('company_workforce_summary'),
  exceptionMissingAttendance('exception_missing_attendance'),
  exceptionHighOvertime('exception_high_overtime'),
  exceptionReturnedTimesheets('exception_returned_timesheets'),
  exceptionUnsubmittedPeriods('exception_unsubmitted_periods'),
  exceptionWorkersWithoutAssignment('exception_workers_without_assignment'),
  exceptionOverlappingAllocations('exception_overlapping_allocations'),
  exceptionReopenedPeriods('exception_reopened_periods');

  const YorksWorkforceReportKind(this.wire);
  final String wire;

  static YorksWorkforceReportKind fromWire(Object? value) => values.firstWhere(
    (kind) => kind.wire == value,
    orElse: () => throw const FormatException('Unknown Workforce report kind'),
  );

  bool get requiresApprovedSnapshot => switch (this) {
    workerMonthlyTimesheet ||
    supervisorTeamMonthly ||
    projectWorkforce ||
    companyWorkforceSummary => true,
    _ => false,
  };
}

enum YorksWorkforceReportColumnType {
  text,
  date,
  integer,
  decimal;

  static YorksWorkforceReportColumnType fromWire(Object? value) =>
      values.firstWhere(
        (type) => type.name == value,
        orElse: () => throw const FormatException('Unknown report column type'),
      );
}

enum YorksWorkforceReportSourceKind {
  approvedSnapshot('approved_snapshot'),
  currentDaily('current_daily'),
  currentException('current_exception');

  const YorksWorkforceReportSourceKind(this.wire);
  final String wire;

  static YorksWorkforceReportSourceKind fromWire(Object? value) =>
      values.firstWhere(
        (kind) => kind.wire == value,
        orElse: () => throw const FormatException('Unknown report source kind'),
      );
}

enum YorksWorkforceReportFormat {
  xlsx,
  pdf;

  static YorksWorkforceReportFormat fromWire(Object? value) =>
      values.firstWhere(
        (format) => format.name == value,
        orElse: () => throw const FormatException('Unknown report format'),
      );
}

enum YorksWorkforceReportAction {
  preview,
  download,
  share,
  print;

  static YorksWorkforceReportAction fromWire(Object? value) =>
      values.firstWhere(
        (action) => action.name == value,
        orElse: () => throw const FormatException('Unknown report action'),
      );
}

final class YorksWorkforceReportIssueRequest {
  const YorksWorkforceReportIssueRequest({
    required this.artifactId,
    required this.format,
    required this.action,
  });

  final String artifactId;
  final YorksWorkforceReportFormat format;
  final YorksWorkforceReportAction action;

  Map<String, Object?> toRpcJson() {
    if (!_isUuid(artifactId) ||
        format == YorksWorkforceReportFormat.xlsx &&
            action != YorksWorkforceReportAction.download) {
      throw const FormatException('Invalid report issuance request');
    }
    return <String, Object?>{
      'artifact_id': artifactId,
      'format': format.name,
      'action': action.name,
    };
  }
}

final class YorksWorkforceReportIssueReceipt {
  const YorksWorkforceReportIssueReceipt({
    required this.artifactId,
    required this.format,
    required this.action,
    required this.sourceHash,
    required this.reportPayloadHash,
    required this.issuedAt,
    required this.issuedBy,
    required this.issuedByRole,
    required this.capabilityKey,
    required this.scopeKind,
    required this.scopeReference,
    required this.sourceAuthorityHash,
  });

  final String artifactId;
  final YorksWorkforceReportFormat format;
  final YorksWorkforceReportAction action;
  final String sourceHash;
  final String reportPayloadHash;
  final DateTime issuedAt;
  final String issuedBy;
  final String issuedByRole;
  final String capabilityKey;
  final String scopeKind;
  final String scopeReference;
  final String sourceAuthorityHash;

  factory YorksWorkforceReportIssueReceipt.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _exact(json, const {
      'schema_version',
      'authorization_mode',
      'artifact_id',
      'format',
      'action',
      'source_hash',
      'report_payload_hash',
      'issued_at',
      'issued_by',
      'issued_by_role',
      'capability_key',
      'scope_kind',
      'scope_reference',
      'source_authority_hash',
    }, 'report issuance receipt');
    if (json['schema_version'] != 1 ||
        json['authorization_mode'] != 'enforced_t09' ||
        json['capability_key'] != 'workforce.reports.export') {
      throw const FormatException('Unsupported report issuance receipt');
    }
    final format = YorksWorkforceReportFormat.fromWire(json['format']);
    final action = YorksWorkforceReportAction.fromWire(json['action']);
    if (format == YorksWorkforceReportFormat.xlsx &&
        action != YorksWorkforceReportAction.download) {
      throw const FormatException('Contradictory report issuance receipt');
    }
    return YorksWorkforceReportIssueReceipt(
      artifactId: _uuid(json['artifact_id']),
      format: format,
      action: action,
      sourceHash: _hash(json['source_hash']),
      reportPayloadHash: _hash(json['report_payload_hash']),
      issuedAt: _timestamp(json['issued_at']),
      issuedBy: _uuid(json['issued_by']),
      issuedByRole: _text(json['issued_by_role']),
      capabilityKey: _text(json['capability_key']),
      scopeKind: _oneOf(json['scope_kind'], const {
        'worker',
        'team',
        'project',
        'organization',
      }),
      scopeReference: _text(json['scope_reference']),
      sourceAuthorityHash: _hash(json['source_authority_hash']),
    );
  }
}

final class YorksWorkforceReportRequest {
  YorksWorkforceReportRequest({
    required this.kind,
    Iterable<String> snapshotIds = const [],
    this.periodMonth,
    this.workDate,
    this.teamId,
    this.projectId,
    this.workerId,
  }) : snapshotIds = List.unmodifiable(snapshotIds);

  final YorksWorkforceReportKind kind;
  final List<String> snapshotIds;
  final String? periodMonth;
  final String? workDate;
  final String? teamId;
  final String? projectId;
  final String? workerId;

  Map<String, Object?> toRpcJson() {
    if (kind.requiresApprovedSnapshot && snapshotIds.isEmpty) {
      throw const FormatException('An approved snapshot is required');
    }
    if (!kind.requiresApprovedSnapshot && snapshotIds.isNotEmpty) {
      throw const FormatException('Current reports cannot receive snapshots');
    }
    if (kind == YorksWorkforceReportKind.dailyAttendanceRegister &&
        (!_isDate(workDate) ||
            !_isUuid(teamId) ||
            periodMonth != null ||
            projectId != null ||
            workerId != null)) {
      throw const FormatException('Daily report scope is invalid');
    }
    if (kind.requiresApprovedSnapshot &&
        snapshotIds.any((id) => !_isUuid(id))) {
      throw const FormatException('Approved snapshot identity is invalid');
    }
    if (periodMonth != null && !_isMonth(periodMonth)) {
      throw const FormatException('Report month is invalid');
    }
    if (teamId != null && !_isUuid(teamId) ||
        projectId != null && !_isUuid(projectId) ||
        workerId != null && !_isUuid(workerId)) {
      throw const FormatException('Report scope identity is invalid');
    }
    if (kind == YorksWorkforceReportKind.workerMonthlyTimesheet &&
        (workerId == null || teamId != null || projectId != null)) {
      throw const FormatException('Worker report requires a worker');
    }
    if (kind == YorksWorkforceReportKind.supervisorTeamMonthly &&
        (teamId == null || workerId != null || projectId != null)) {
      throw const FormatException('Team report requires a team');
    }
    if (kind == YorksWorkforceReportKind.projectWorkforce &&
        (projectId == null || teamId != null || workerId != null)) {
      throw const FormatException('Project report requires a project');
    }
    if (kind == YorksWorkforceReportKind.companyWorkforceSummary &&
        (teamId != null || projectId != null || workerId != null)) {
      throw const FormatException('Company report scope is invalid');
    }
    if (!kind.requiresApprovedSnapshot &&
        kind != YorksWorkforceReportKind.dailyAttendanceRegister &&
        (!_isMonth(periodMonth) ||
            workDate != null ||
            teamId != null ||
            projectId != null ||
            workerId != null)) {
      throw const FormatException('Exception report scope is invalid');
    }
    return <String, Object?>{
      'report_kind': kind.wire,
      if (snapshotIds.isNotEmpty) 'snapshot_ids': snapshotIds,
      if (periodMonth != null) 'period_month': periodMonth,
      if (workDate != null) 'work_date': workDate,
      if (teamId != null) 'team_id': teamId,
      if (projectId != null) 'project_id': projectId,
      if (workerId != null) 'worker_id': workerId,
    };
  }
}

final class YorksWorkforceReportColumn {
  const YorksWorkforceReportColumn({
    required this.key,
    required this.label,
    required this.type,
  });

  final String key;
  final String label;
  final YorksWorkforceReportColumnType type;

  factory YorksWorkforceReportColumn.fromRpcJson(Map<String, dynamic> json) {
    _exact(json, const {'key', 'label', 'type'}, 'report column');
    final key = _text(json['key']);
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(key) || key.endsWith('_id')) {
      throw const FormatException('Unsafe report column key');
    }
    return YorksWorkforceReportColumn(
      key: key,
      label: _text(json['label']),
      type: YorksWorkforceReportColumnType.fromWire(json['type']),
    );
  }
}

final class YorksWorkforceReportTotals {
  const YorksWorkforceReportTotals({
    required this.rowCount,
    required this.regularMinutes,
    required this.overtimeMinutes,
    required this.manDays,
  });

  final int rowCount;
  final num regularMinutes;
  final num overtimeMinutes;
  final num manDays;

  factory YorksWorkforceReportTotals.fromRpcJson(Map<String, dynamic> json) {
    _exact(json, const {
      'row_count',
      'regular_minutes',
      'overtime_minutes',
      'man_days',
    }, 'report totals');
    return YorksWorkforceReportTotals(
      rowCount: _nonNegativeInt(json['row_count']),
      regularMinutes: _nonNegativeNumber(json['regular_minutes']),
      overtimeMinutes: _nonNegativeNumber(json['overtime_minutes']),
      manDays: _nonNegativeNumber(json['man_days']),
    );
  }
}

final class YorksWorkforceReportArtifact {
  YorksWorkforceReportArtifact({
    required this.artifactId,
    required this.kind,
    required this.sourceKind,
    required this.sourceStatus,
    required this.sourceVersion,
    required this.sourceHash,
    required this.periodMonth,
    required this.workDate,
    required this.scopeKind,
    required this.scopeReference,
    required this.generatedAt,
    required this.generatedBy,
    required this.generatedByRole,
    required this.companyLegalName,
    required this.companySecondaryName,
    required Iterable<Map<String, dynamic>> sources,
    required Iterable<YorksWorkforceReportColumn> columns,
    required Iterable<Map<String, Object?>> rows,
    required this.totals,
  }) : sources = List.unmodifiable(sources),
       columns = List.unmodifiable(columns),
       rows = List.unmodifiable(rows);

  final String artifactId;
  final YorksWorkforceReportKind kind;
  final YorksWorkforceReportSourceKind sourceKind;
  final String sourceStatus;
  final String sourceVersion;
  final String sourceHash;
  final String? periodMonth;
  final String? workDate;
  final String scopeKind;
  final String scopeReference;
  final DateTime generatedAt;
  final String generatedBy;
  final String generatedByRole;
  final String companyLegalName;
  final String companySecondaryName;
  final List<Map<String, dynamic>> sources;
  final List<YorksWorkforceReportColumn> columns;
  final List<Map<String, Object?>> rows;
  final YorksWorkforceReportTotals totals;

  bool get isApproved =>
      sourceKind == YorksWorkforceReportSourceKind.approvedSnapshot &&
      sourceStatus == 'approved_locked';

  factory YorksWorkforceReportArtifact.fromRpcJson(Map<String, dynamic> json) {
    _exact(json, const {
      'schema_version',
      'authorization_mode',
      'artifact_id',
      'report_kind',
      'source_kind',
      'source_status',
      'source_version',
      'source_hash',
      'period_month',
      'work_date',
      'scope_kind',
      'scope_reference',
      'generated_at',
      'generated_by',
      'generated_by_role',
      'company_legal_name',
      'company_secondary_name',
      'sources',
      'columns',
      'rows',
      'totals',
    }, 'report artifact');
    if (json['schema_version'] != 1 ||
        json['authorization_mode'] != 'enforced_t09') {
      throw const FormatException('Unsupported report schema');
    }
    final sourceKind = YorksWorkforceReportSourceKind.fromWire(
      json['source_kind'],
    );
    final sourceStatus = _text(json['source_status']);
    if (sourceKind == YorksWorkforceReportSourceKind.approvedSnapshot
        ? sourceStatus != 'approved_locked'
        : sourceStatus != 'current_not_approved') {
      throw const FormatException('Contradictory report source status');
    }
    final kind = YorksWorkforceReportKind.fromWire(json['report_kind']);
    final columns = _list(json['columns'])
        .map((value) => YorksWorkforceReportColumn.fromRpcJson(_map(value)))
        .toList(growable: false);
    if (columns.isEmpty ||
        columns.map((column) => column.key).toSet().length != columns.length) {
      throw const FormatException('Invalid report columns');
    }
    final expectedColumns = _expectedReportColumns(kind);
    if (columns.length != expectedColumns.length) {
      throw const FormatException('Unexpected report column contract');
    }
    for (var index = 0; index < expectedColumns.length; index += 1) {
      if (columns[index].key != expectedColumns[index].$1 ||
          columns[index].type != expectedColumns[index].$2) {
        throw const FormatException('Unexpected report column contract');
      }
    }
    final columnKeys = columns.map((column) => column.key).toSet();
    final rows = _list(json['rows'])
        .map((value) {
          final row = _map(value).cast<String, Object?>();
          if (row.keys.toSet().difference(columnKeys).isNotEmpty ||
              columnKeys.difference(row.keys.toSet()).isNotEmpty) {
            throw const FormatException('Report row does not match columns');
          }
          for (final column in columns) {
            _validateCell(column.type, row[column.key]);
          }
          return Map<String, Object?>.unmodifiable(row);
        })
        .toList(growable: false);
    final totals = YorksWorkforceReportTotals.fromRpcJson(_map(json['totals']));
    if (totals.rowCount != rows.length) {
      throw const FormatException('Report row count mismatch');
    }
    final generatedAt = DateTime.tryParse(_text(json['generated_at']));
    if (generatedAt == null) {
      throw const FormatException('Invalid generated time');
    }
    final periodMonth = _nullableDate(json['period_month']);
    final workDate = _nullableDate(json['work_date']);
    final sources = _validateSources(sourceKind, json['sources']);
    switch (sourceKind) {
      case YorksWorkforceReportSourceKind.approvedSnapshot:
        if (periodMonth == null || workDate != null) {
          throw const FormatException('Invalid approved report dates');
        }
      case YorksWorkforceReportSourceKind.currentDaily:
        if (periodMonth != null || workDate == null) {
          throw const FormatException('Invalid daily report dates');
        }
      case YorksWorkforceReportSourceKind.currentException:
        if (periodMonth == null || workDate != null) {
          throw const FormatException('Invalid exception report dates');
        }
    }
    return YorksWorkforceReportArtifact(
      artifactId: _uuid(json['artifact_id']),
      kind: kind,
      sourceKind: sourceKind,
      sourceStatus: sourceStatus,
      sourceVersion: _text(json['source_version']),
      sourceHash: _hash(json['source_hash']),
      periodMonth: periodMonth,
      workDate: workDate,
      scopeKind: _oneOf(json['scope_kind'], const {
        'worker',
        'team',
        'project',
        'organization',
      }),
      scopeReference: _text(json['scope_reference']),
      generatedAt: generatedAt,
      generatedBy: _text(json['generated_by']),
      generatedByRole: _text(json['generated_by_role']),
      companyLegalName: _text(json['company_legal_name']),
      companySecondaryName: _text(json['company_secondary_name']),
      sources: sources,
      columns: columns,
      rows: rows,
      totals: totals,
    );
  }
}

List<(String, YorksWorkforceReportColumnType)> _expectedReportColumns(
  YorksWorkforceReportKind kind,
) => switch (kind) {
  YorksWorkforceReportKind.dailyAttendanceRegister => const [
    ('worker_number', YorksWorkforceReportColumnType.text),
    ('worker_name', YorksWorkforceReportColumnType.text),
    ('trade', YorksWorkforceReportColumnType.text),
    ('attendance_status', YorksWorkforceReportColumnType.text),
    ('regular_hours', YorksWorkforceReportColumnType.decimal),
    ('overtime_hours', YorksWorkforceReportColumnType.decimal),
    ('project', YorksWorkforceReportColumnType.text),
    ('building', YorksWorkforceReportColumnType.text),
    ('internal_location', YorksWorkforceReportColumnType.text),
    ('supervisor', YorksWorkforceReportColumnType.text),
    ('notes', YorksWorkforceReportColumnType.text),
  ],
  YorksWorkforceReportKind.workerMonthlyTimesheet => const [
    ('worker_number', YorksWorkforceReportColumnType.text),
    ('worker_name', YorksWorkforceReportColumnType.text),
    ('work_date', YorksWorkforceReportColumnType.date),
    ('attendance_status', YorksWorkforceReportColumnType.text),
    ('regular_hours', YorksWorkforceReportColumnType.decimal),
    ('overtime_hours', YorksWorkforceReportColumnType.decimal),
    ('projects', YorksWorkforceReportColumnType.text),
    ('buildings', YorksWorkforceReportColumnType.text),
    ('internal_locations', YorksWorkforceReportColumnType.text),
    ('activities', YorksWorkforceReportColumnType.text),
    ('supervisor', YorksWorkforceReportColumnType.text),
    ('reviewer', YorksWorkforceReportColumnType.text),
    ('approver', YorksWorkforceReportColumnType.text),
    ('approval_dates', YorksWorkforceReportColumnType.text),
  ],
  YorksWorkforceReportKind.supervisorTeamMonthly => const [
    ('team', YorksWorkforceReportColumnType.text),
    ('period_month', YorksWorkforceReportColumnType.date),
    ('workers_managed', YorksWorkforceReportColumnType.integer),
    ('attendance_summary', YorksWorkforceReportColumnType.text),
    ('regular_hours', YorksWorkforceReportColumnType.decimal),
    ('overtime_hours', YorksWorkforceReportColumnType.decimal),
    ('absences', YorksWorkforceReportColumnType.integer),
    ('projects', YorksWorkforceReportColumnType.text),
    ('exceptions', YorksWorkforceReportColumnType.text),
    ('review_approval_status', YorksWorkforceReportColumnType.text),
  ],
  YorksWorkforceReportKind.projectWorkforce => const [
    ('project', YorksWorkforceReportColumnType.text),
    ('buildings', YorksWorkforceReportColumnType.text),
    ('worker_count', YorksWorkforceReportColumnType.integer),
    ('trade_distribution', YorksWorkforceReportColumnType.text),
    ('man_hours', YorksWorkforceReportColumnType.decimal),
    ('man_days', YorksWorkforceReportColumnType.decimal),
    ('regular_hours', YorksWorkforceReportColumnType.decimal),
    ('overtime_hours', YorksWorkforceReportColumnType.decimal),
    ('absences', YorksWorkforceReportColumnType.integer),
    ('supervisors', YorksWorkforceReportColumnType.text),
    ('outstanding_periods', YorksWorkforceReportColumnType.integer),
  ],
  YorksWorkforceReportKind.companyWorkforceSummary => const [
    ('period_month', YorksWorkforceReportColumnType.date),
    ('total_active_workforce', YorksWorkforceReportColumnType.integer),
    ('attendance_completion', YorksWorkforceReportColumnType.decimal),
    ('approved_regular_hours', YorksWorkforceReportColumnType.decimal),
    ('approved_overtime_hours', YorksWorkforceReportColumnType.decimal),
    ('absence_position', YorksWorkforceReportColumnType.integer),
    ('project_allocation', YorksWorkforceReportColumnType.text),
    ('pending_submissions', YorksWorkforceReportColumnType.integer),
    ('pending_approvals', YorksWorkforceReportColumnType.integer),
    ('reopened_periods', YorksWorkforceReportColumnType.integer),
  ],
  _ => const [
    ('period', YorksWorkforceReportColumnType.text),
    ('team', YorksWorkforceReportColumnType.text),
    ('worker_number', YorksWorkforceReportColumnType.text),
    ('worker_name', YorksWorkforceReportColumnType.text),
    ('exception', YorksWorkforceReportColumnType.text),
    ('status', YorksWorkforceReportColumnType.text),
  ],
};

final class YorksWorkforceReportHistory {
  YorksWorkforceReportHistory({
    required this.limit,
    required this.offset,
    required this.totalCount,
    required Iterable<YorksWorkforceReportArtifact> items,
  }) : items = List.unmodifiable(items);

  final int limit;
  final int offset;
  final int totalCount;
  final List<YorksWorkforceReportArtifact> items;

  factory YorksWorkforceReportHistory.fromRpcJson(Map<String, dynamic> json) {
    _exact(json, const {
      'schema_version',
      'authorization_mode',
      'limit',
      'offset',
      'total_count',
      'items',
    }, 'report history');
    if (json['schema_version'] != 1 ||
        json['authorization_mode'] != 'enforced_t09') {
      throw const FormatException('Unsupported report history schema');
    }
    final limit = _positiveInt(json['limit']);
    final offset = _nonNegativeInt(json['offset']);
    final total = _nonNegativeInt(json['total_count']);
    final items = _list(json['items'])
        .map((value) => YorksWorkforceReportArtifact.fromRpcJson(_map(value)))
        .toList(growable: false);
    if (items.length > limit ||
        offset + items.length > total && items.isNotEmpty) {
      throw const FormatException('Invalid report history bounds');
    }
    return YorksWorkforceReportHistory(
      limit: limit,
      offset: offset,
      totalCount: total,
      items: items,
    );
  }
}

List<Map<String, dynamic>> _validateSources(
  YorksWorkforceReportSourceKind kind,
  Object? value,
) {
  final sources = _list(value).map(_map).toList(growable: false);
  if (sources.isEmpty) throw const FormatException('Missing report sources');
  for (final source in sources) {
    switch (kind) {
      case YorksWorkforceReportSourceKind.approvedSnapshot:
        _exact(source, const {
          'snapshot_id',
          'period_id',
          'approval_revision_number',
          'snapshot_hash',
          'approved_at',
          'approved_by',
          'approved_role',
          'review_chain',
        }, 'approved report source');
        _uuid(source['snapshot_id']);
        _uuid(source['period_id']);
        _positiveInt(source['approval_revision_number']);
        _hash(source['snapshot_hash']);
        _timestamp(source['approved_at']);
        _text(source['approved_by']);
        _text(source['approved_role']);
        for (final transition in _list(source['review_chain']).map(_map)) {
          _exact(transition, const {
            'action',
            'actor',
            'role',
            'at',
          }, 'approved review transition');
          _text(transition['action']);
          _text(transition['actor']);
          _text(transition['role']);
          _timestamp(transition['at']);
        }
      case YorksWorkforceReportSourceKind.currentDaily:
        _exact(source, const {
          'work_date',
          'team_id',
          'server_time',
          'status',
        }, 'daily report source');
        if (source['work_date'] is! String ||
            !_isDate(source['work_date'] as String)) {
          throw const FormatException('Invalid daily source date');
        }
        _uuid(source['team_id']);
        _timestamp(source['server_time']);
        if (source['status'] != 'current_not_approved') {
          throw const FormatException('Invalid daily source status');
        }
      case YorksWorkforceReportSourceKind.currentException:
        _exact(source, const {
          'period_month',
          'generated_at',
          'status',
        }, 'exception report source');
        if (source['period_month'] is! String ||
            !_isMonth(source['period_month'] as String)) {
          throw const FormatException('Invalid exception source month');
        }
        _timestamp(source['generated_at']);
        if (source['status'] != 'current_not_approved') {
          throw const FormatException('Invalid exception source status');
        }
    }
  }
  return List.unmodifiable(
    sources.map((source) => Map<String, dynamic>.unmodifiable(source)),
  );
}

void _validateCell(YorksWorkforceReportColumnType type, Object? value) {
  if (value == null) return;
  switch (type) {
    case YorksWorkforceReportColumnType.text:
      if (value is! String) throw const FormatException('Expected text cell');
    case YorksWorkforceReportColumnType.date:
      if (value is! String || !_isDate(value)) {
        throw const FormatException('Expected date cell');
      }
    case YorksWorkforceReportColumnType.integer:
      if (value is! num || value < 0 || value != value.roundToDouble()) {
        throw const FormatException('Expected integer cell');
      }
    case YorksWorkforceReportColumnType.decimal:
      if (value is! num || !value.isFinite || value < 0) {
        throw const FormatException('Expected decimal cell');
      }
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) throw const FormatException('Expected object');
  return Map<String, dynamic>.from(value);
}

List<Object?> _list(Object? value) {
  if (value is! List) throw const FormatException('Expected list');
  return List<Object?>.from(value);
}

void _exact(Map<String, dynamic> value, Set<String> keys, String label) {
  if (value.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(value.keys.toSet()).isNotEmpty) {
    throw FormatException('Unexpected $label shape');
  }
}

String _text(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Expected text');
  }
  return value;
}

String _uuid(Object? value) {
  final text = _text(value);
  if (!_isUuid(text)) throw const FormatException('Expected UUID');
  return text;
}

String _hash(Object? value) {
  final text = _text(value);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(text)) {
    throw const FormatException('Expected SHA-256');
  }
  return text;
}

DateTime _timestamp(Object? value) {
  final timestamp = DateTime.tryParse(_text(value));
  if (timestamp == null) throw const FormatException('Expected timestamp');
  return timestamp;
}

String _oneOf(Object? value, Set<String> allowed) {
  final text = _text(value);
  if (!allowed.contains(text)) throw const FormatException('Unexpected value');
  return text;
}

String? _nullableDate(Object? value) {
  if (value == null) return null;
  if (value is! String || !_isDate(value)) {
    throw const FormatException('Expected nullable date');
  }
  return value;
}

int _positiveInt(Object? value) {
  final result = _nonNegativeInt(value);
  if (result == 0) throw const FormatException('Expected positive integer');
  return result;
}

int _nonNegativeInt(Object? value) {
  if (value is! num || value < 0 || value != value.roundToDouble()) {
    throw const FormatException('Expected non-negative integer');
  }
  return value.toInt();
}

num _nonNegativeNumber(Object? value) {
  if (value is! num || !value.isFinite || value < 0) {
    throw const FormatException('Expected non-negative number');
  }
  return value;
}

bool _isUuid(String? value) =>
    value != null &&
    RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);

bool _isDate(String? value) =>
    value != null &&
    RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
    DateTime.tryParse(value) != null;

bool _isMonth(String? value) => _isDate(value) && value!.endsWith('-01');
