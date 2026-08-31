enum YorksWorkforceAllocationTargetKind {
  projectWork('project_work'),
  internalWork('internal_work');

  const YorksWorkforceAllocationTargetKind(this.wireValue);
  final String wireValue;

  static YorksWorkforceAllocationTargetKind fromWire(Object? value) =>
      values.firstWhere(
        (candidate) => candidate.wireValue == value,
        orElse: () => throw const FormatException(
          'Unknown Workforce allocation target kind',
        ),
      );
}

final class YorksWorkforceAllocationInput {
  const YorksWorkforceAllocationInput({
    required this.targetKind,
    this.projectId,
    this.projectScopeId,
    this.internalLocationId,
    this.activityTask,
    this.notes,
    required this.regularMinutes,
    required this.overtimeMinutes,
    this.startTime,
    this.endTime,
  });

  final YorksWorkforceAllocationTargetKind targetKind;
  final String? projectId;
  final String? projectScopeId;
  final String? internalLocationId;
  final String? activityTask;
  final String? notes;
  final int regularMinutes;
  final int overtimeMinutes;
  final String? startTime;
  final String? endTime;

  bool get isValid {
    final project = _nullableTrim(projectId);
    final scope = _nullableTrim(projectScopeId);
    final internal = _nullableTrim(internalLocationId);
    final start = _nullableTrim(startTime);
    final end = _nullableTrim(endTime);
    final total = regularMinutes + overtimeMinutes;
    final validTarget = switch (targetKind) {
      YorksWorkforceAllocationTargetKind.projectWork =>
        project != null &&
            scope != null &&
            internal == null &&
            _isUuid(project) &&
            _isUuid(scope),
      YorksWorkforceAllocationTargetKind.internalWork =>
        project == null &&
            scope == null &&
            internal != null &&
            _isUuid(internal),
    };
    final validRange =
        (start == null && end == null) ||
        (start != null &&
            end != null &&
            _isTime(start) &&
            _isTime(end) &&
            start != end);
    return validTarget &&
        regularMinutes >= 0 &&
        regularMinutes <= 1440 &&
        overtimeMinutes >= 0 &&
        overtimeMinutes <= 1440 &&
        total > 0 &&
        total <= 1440 &&
        (_nullableTrim(activityTask)?.length ?? 0) <= 500 &&
        (_nullableTrim(notes)?.length ?? 0) <= 2000 &&
        validRange;
  }

  Map<String, Object?> toRpcJson() {
    final json = <String, Object?>{
      'target_kind': targetKind.wireValue,
      'regular_minutes': regularMinutes,
      'overtime_minutes': overtimeMinutes,
    };
    final project = _nullableTrim(projectId);
    final scope = _nullableTrim(projectScopeId);
    final internal = _nullableTrim(internalLocationId);
    final activity = _nullableTrim(activityTask);
    final normalizedNotes = _nullableTrim(notes);
    final start = _nullableTrim(startTime);
    final end = _nullableTrim(endTime);
    if (project != null) json['project_id'] = project;
    if (scope != null) json['project_scope_id'] = scope;
    if (internal != null) json['internal_location_id'] = internal;
    if (activity != null) json['activity_task'] = activity;
    if (normalizedNotes != null) json['notes'] = normalizedNotes;
    if (start != null) json['start_time'] = start;
    if (end != null) json['end_time'] = end;
    return json;
  }
}

final class YorksWorkforceTimesheetAllocationInput {
  YorksWorkforceTimesheetAllocationInput({
    required this.attendanceDayId,
    required this.attendanceRecordVersion,
    required Iterable<YorksWorkforceAllocationInput> allocations,
    required this.reason,
  }) : allocations = List.unmodifiable(allocations);

  final String attendanceDayId;
  final int attendanceRecordVersion;
  final List<YorksWorkforceAllocationInput> allocations;
  final String reason;

  bool get isValid =>
      _isUuid(attendanceDayId.trim()) &&
      attendanceRecordVersion > 0 &&
      allocations.isNotEmpty &&
      allocations.every((allocation) => allocation.isValid) &&
      allocations.fold<int>(0, (sum, row) => sum + row.regularMinutes) <=
          1440 &&
      allocations.fold<int>(0, (sum, row) => sum + row.overtimeMinutes) <=
          1440 &&
      allocations.fold<int>(
            0,
            (sum, row) => sum + row.regularMinutes + row.overtimeMinutes,
          ) <=
          1440 &&
      reason.trim().isNotEmpty &&
      reason.trim().length <= 2000;

  Map<String, Object?> toRpcJson() => {
    'attendance_day_id': attendanceDayId.trim(),
    'attendance_record_version': attendanceRecordVersion,
    'allocations': allocations.map((row) => row.toRpcJson()).toList(),
    'reason': reason.trim(),
  };
}

final class YorksWorkforceAllocationTargetSnapshot {
  const YorksWorkforceAllocationTargetSnapshot({
    required this.kind,
    required this.projectId,
    required this.projectRef,
    required this.projectName,
    required this.projectRecordVersion,
    required this.projectScopeId,
    required this.projectScopeKind,
    required this.projectScopeCode,
    required this.projectScopeName,
    required this.projectScopeRecordVersion,
    required this.internalLocationId,
    required this.internalLocationCode,
    required this.internalLocationName,
    required this.departmentCostCentre,
    required this.internalLocationRecordVersion,
  });

  final YorksWorkforceAllocationTargetKind kind;
  final String? projectId;
  final String? projectRef;
  final String? projectName;
  final int? projectRecordVersion;
  final String? projectScopeId;
  final String? projectScopeKind;
  final String? projectScopeCode;
  final String? projectScopeName;
  final int? projectScopeRecordVersion;
  final String? internalLocationId;
  final String? internalLocationCode;
  final String? internalLocationName;
  final String? departmentCostCentre;
  final int? internalLocationRecordVersion;

  factory YorksWorkforceAllocationTargetSnapshot.fromRpcJson(
    YorksWorkforceAllocationTargetKind kind,
    Object? projectValue,
    Object? internalValue,
  ) {
    final project = projectValue == null ? null : _map(projectValue);
    final internal = internalValue == null ? null : _map(internalValue);
    if (kind == YorksWorkforceAllocationTargetKind.projectWork) {
      if (project == null || internal != null) {
        throw const FormatException('Invalid project allocation snapshot');
      }
      final scopeKind = _text(project['project_scope_kind']);
      if (scopeKind != 'common' && scopeKind != 'building') {
        throw const FormatException('Invalid project scope kind');
      }
      return YorksWorkforceAllocationTargetSnapshot(
        kind: kind,
        projectId: _uuid(project['project_id']),
        projectRef: _text(project['project_ref']),
        projectName: _text(project['project_name']),
        projectRecordVersion: _positiveInt(project['project_record_version']),
        projectScopeId: _uuid(project['project_scope_id']),
        projectScopeKind: scopeKind,
        projectScopeCode: _text(project['project_scope_code']),
        projectScopeName: _text(project['project_scope_name']),
        projectScopeRecordVersion: _positiveInt(
          project['project_scope_record_version'],
        ),
        internalLocationId: null,
        internalLocationCode: null,
        internalLocationName: null,
        departmentCostCentre: null,
        internalLocationRecordVersion: null,
      );
    }
    if (project != null || internal == null) {
      throw const FormatException('Invalid internal allocation snapshot');
    }
    return YorksWorkforceAllocationTargetSnapshot(
      kind: kind,
      projectId: null,
      projectRef: null,
      projectName: null,
      projectRecordVersion: null,
      projectScopeId: null,
      projectScopeKind: null,
      projectScopeCode: null,
      projectScopeName: null,
      projectScopeRecordVersion: null,
      internalLocationId: _uuid(internal['internal_location_id']),
      internalLocationCode: _text(internal['location_code']),
      internalLocationName: _text(internal['location_name']),
      departmentCostCentre: _nullableText(internal['department_cost_centre']),
      internalLocationRecordVersion: _positiveInt(internal['record_version']),
    );
  }
}

final class YorksWorkforceTimesheetAllocation {
  const YorksWorkforceTimesheetAllocation({
    required this.id,
    required this.lineNumber,
    required this.target,
    required this.activityTask,
    required this.notes,
    required this.regularMinutes,
    required this.overtimeMinutes,
    required this.startTime,
    required this.endTime,
    required this.crossesMidnight,
  });

  final String id;
  final int lineNumber;
  final YorksWorkforceAllocationTargetSnapshot target;
  final String? activityTask;
  final String? notes;
  final int regularMinutes;
  final int overtimeMinutes;
  final String? startTime;
  final String? endTime;
  final bool? crossesMidnight;

  factory YorksWorkforceTimesheetAllocation.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final kind = YorksWorkforceAllocationTargetKind.fromWire(
      json['target_kind'],
    );
    final regular = _nonNegativeInt(json['regular_minutes']);
    final overtime = _nonNegativeInt(json['overtime_minutes']);
    final start = _nullableTime(json['start_time']);
    final end = _nullableTime(json['end_time']);
    final crosses = _nullableBool(json['crosses_midnight']);
    if (regular + overtime <= 0 ||
        regular + overtime > 1440 ||
        (start == null) != (end == null) ||
        (start == null) != (crosses == null) ||
        (start != null && start == end)) {
      throw const FormatException('Invalid allocation minutes/time range');
    }
    return YorksWorkforceTimesheetAllocation(
      id: _uuid(json['allocation_id']),
      lineNumber: _positiveInt(json['line_number']),
      target: YorksWorkforceAllocationTargetSnapshot.fromRpcJson(
        kind,
        json['project'],
        json['internal_location'],
      ),
      activityTask: _nullableText(json['activity_task']),
      notes: _nullableText(json['notes']),
      regularMinutes: regular,
      overtimeMinutes: overtime,
      startTime: start,
      endTime: end,
      crossesMidnight: crosses,
    );
  }
}

final class YorksWorkforceTimesheetDay {
  YorksWorkforceTimesheetDay({
    required this.id,
    required this.attendanceDayId,
    required this.workerId,
    required this.workDate,
    required this.state,
    required this.recordVersion,
    required this.revisionId,
    required this.revisionNumber,
    required this.attendanceRecordVersionBasis,
    required this.totalRegularMinutes,
    required this.totalOvertimeMinutes,
    required this.reason,
    required this.attendanceStatus,
    required this.attendanceRegularMinutes,
    required this.attendanceOvertimeMinutes,
    required this.attendanceRecordVersion,
    required this.calendarTimezone,
    required Iterable<YorksWorkforceTimesheetAllocation> allocations,
    required this.createdAt,
    required this.updatedAt,
  }) : allocations = List.unmodifiable(allocations) {
    if (state != 'active' && state != 'withdrawn') {
      throw const FormatException('Invalid allocation set state');
    }
    final regular = this.allocations.fold<int>(
      0,
      (sum, allocation) => sum + allocation.regularMinutes,
    );
    final overtime = this.allocations.fold<int>(
      0,
      (sum, allocation) => sum + allocation.overtimeMinutes,
    );
    if (state == 'active'
        ? attendanceStatus != 'present' ||
              this.allocations.isEmpty ||
              totalRegularMinutes != regular ||
              totalOvertimeMinutes != overtime ||
              regular != attendanceRegularMinutes ||
              overtime != attendanceOvertimeMinutes
        : this.allocations.isNotEmpty ||
              totalRegularMinutes != 0 ||
              totalOvertimeMinutes != 0) {
      throw const FormatException('Inconsistent allocation set projection');
    }
  }

  final String id;
  final String attendanceDayId;
  final String workerId;
  final String workDate;
  final String state;
  final int recordVersion;
  final String revisionId;
  final int revisionNumber;
  final int attendanceRecordVersionBasis;
  final int totalRegularMinutes;
  final int totalOvertimeMinutes;
  final String reason;
  final String attendanceStatus;
  final int attendanceRegularMinutes;
  final int attendanceOvertimeMinutes;
  final int attendanceRecordVersion;
  final String calendarTimezone;
  final List<YorksWorkforceTimesheetAllocation> allocations;
  final String createdAt;
  final String updatedAt;

  factory YorksWorkforceTimesheetDay.fromRpcJson(Map<String, dynamic> json) {
    final revision = _map(json['current_revision']);
    final attendance = _map(json['attendance']);
    return YorksWorkforceTimesheetDay(
      id: _uuid(json['allocation_set_id']),
      attendanceDayId: _uuid(json['attendance_day_id']),
      workerId: _uuid(json['worker_id']),
      workDate: _date(json['work_date']),
      state: _text(json['state']),
      recordVersion: _positiveInt(json['record_version']),
      revisionId: _uuid(revision['revision_id']),
      revisionNumber: _positiveInt(revision['revision_number']),
      attendanceRecordVersionBasis: _positiveInt(
        revision['attendance_record_version_basis'],
      ),
      totalRegularMinutes: _nonNegativeInt(revision['total_regular_minutes']),
      totalOvertimeMinutes: _nonNegativeInt(revision['total_overtime_minutes']),
      reason: _text(revision['reason']),
      attendanceStatus: _text(attendance['status']),
      attendanceRegularMinutes: _nonNegativeInt(attendance['regular_minutes']),
      attendanceOvertimeMinutes: _nonNegativeInt(
        attendance['overtime_minutes'],
      ),
      attendanceRecordVersion: _positiveInt(attendance['record_version']),
      calendarTimezone: _text(attendance['calendar_timezone']),
      allocations: _list(json['allocations']).map(
        (value) => YorksWorkforceTimesheetAllocation.fromRpcJson(_map(value)),
      ),
      createdAt: _timestamp(json['created_at']),
      updatedAt: _timestamp(json['updated_at']),
    );
  }
}

final class YorksWorkforceTimesheetProjection {
  YorksWorkforceTimesheetProjection({
    required this.schemaVersion,
    required this.authorizationMode,
    required this.actorAuthUserId,
    required this.workDate,
    required this.serverTime,
    required Iterable<YorksWorkforceTimesheetDay> days,
  }) : days = List.unmodifiable(days) {
    if (schemaVersion != 1 || authorizationMode != 'enforced_t04') {
      throw const FormatException('Unsupported timesheet projection');
    }
  }

  final int schemaVersion;
  final String authorizationMode;
  final String actorAuthUserId;
  final String workDate;
  final String serverTime;
  final List<YorksWorkforceTimesheetDay> days;

  factory YorksWorkforceTimesheetProjection.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksWorkforceTimesheetProjection(
    schemaVersion: _positiveInt(json['schema_version']),
    authorizationMode: _text(json['authorization_mode']),
    actorAuthUserId: _uuid(json['actor_auth_user_id']),
    workDate: _date(json['work_date']),
    serverTime: _timestamp(json['server_time']),
    days: _list(
      json['timesheet_days'],
    ).map((value) => YorksWorkforceTimesheetDay.fromRpcJson(_map(value))),
  );
}

final class YorksWorkforceTimesheetCommandResult {
  YorksWorkforceTimesheetCommandResult({
    required this.schemaVersion,
    required this.authorizationMode,
    required this.day,
  }) {
    if (schemaVersion != 1 || authorizationMode != 'enforced_t04') {
      throw const FormatException('Unsupported timesheet command result');
    }
  }

  final int schemaVersion;
  final String authorizationMode;
  final YorksWorkforceTimesheetDay day;

  factory YorksWorkforceTimesheetCommandResult.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksWorkforceTimesheetCommandResult(
    schemaVersion: _positiveInt(json['schema_version']),
    authorizationMode: _text(json['authorization_mode']),
    day: YorksWorkforceTimesheetDay.fromRpcJson(_map(json['timesheet_day'])),
  );
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) throw const FormatException('Expected object');
  return Map<String, dynamic>.from(value);
}

List<Object?> _list(Object? value) {
  if (value is! List) throw const FormatException('Expected list');
  return List<Object?>.from(value);
}

String _text(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Expected text');
  }
  return value.trim();
}

String? _nullableText(Object? value) => value == null ? null : _text(value);

String _uuid(Object? value) {
  final text = _text(value);
  if (!_isUuid(text)) throw const FormatException('Expected UUID');
  return text;
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  throw const FormatException('Expected integer');
}

int _positiveInt(Object? value) {
  final valueAsInt = _integer(value);
  if (valueAsInt <= 0) throw const FormatException('Expected positive integer');
  return valueAsInt;
}

int _nonNegativeInt(Object? value) {
  final valueAsInt = _integer(value);
  if (valueAsInt < 0 || valueAsInt > 1440) {
    throw const FormatException('Expected bounded non-negative integer');
  }
  return valueAsInt;
}

bool? _nullableBool(Object? value) {
  if (value == null) return null;
  if (value is! bool) throw const FormatException('Expected boolean');
  return value;
}

String _date(Object? value) {
  final text = _text(value);
  if (!_isDate(text)) throw const FormatException('Expected date');
  return text;
}

String _timestamp(Object? value) {
  final text = _text(value);
  if (DateTime.tryParse(text) == null) {
    throw const FormatException('Expected timestamp');
  }
  return text;
}

String? _nullableTime(Object? value) {
  if (value == null) return null;
  final text = _text(value);
  if (!_isTime(text)) throw const FormatException('Expected local time');
  return text;
}

String? _nullableTrim(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

bool _isDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return false;
  return '${parsed.year.toString().padLeft(4, '0')}-'
          '${parsed.month.toString().padLeft(2, '0')}-'
          '${parsed.day.toString().padLeft(2, '0')}' ==
      value;
}

bool _isTime(String value) =>
    RegExp(r'^([01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d+)?)?$').hasMatch(value);

bool _isUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
).hasMatch(value);
