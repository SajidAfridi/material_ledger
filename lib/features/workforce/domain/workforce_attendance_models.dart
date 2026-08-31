import 'workforce_configuration_models.dart';

enum YorksWorkforceAttendanceStatus {
  present('present'),
  absent('absent'),
  annualLeave('annual_leave'),
  sickLeave('sick_leave'),
  officialLeave('official_leave'),
  unpaidLeave('unpaid_leave'),
  notEntered('not_entered');

  const YorksWorkforceAttendanceStatus(this.wireValue);

  final String wireValue;

  static YorksWorkforceAttendanceStatus fromWire(Object? value) =>
      values.firstWhere(
        (candidate) => candidate.wireValue == value,
        orElse: () =>
            throw const FormatException('Unknown Workforce attendance status'),
      );
}

final class YorksWorkforceAttendanceInput {
  const YorksWorkforceAttendanceInput({
    required this.workerId,
    required this.workDate,
    required this.status,
    required this.regularMinutes,
    required this.overtimeMinutes,
    required this.reason,
  });

  final String workerId;
  final String workDate;
  final YorksWorkforceAttendanceStatus status;
  final int regularMinutes;
  final int overtimeMinutes;
  final String reason;

  bool get isValid {
    final total = regularMinutes + overtimeMinutes;
    return _isUuid(workerId.trim()) &&
        _isDate(workDate.trim()) &&
        regularMinutes >= 0 &&
        regularMinutes <= 1440 &&
        overtimeMinutes >= 0 &&
        overtimeMinutes <= 1440 &&
        total <= 1440 &&
        (status == YorksWorkforceAttendanceStatus.present
            ? total > 0
            : total == 0) &&
        reason.trim().isNotEmpty &&
        reason.trim().length <= 2000;
  }

  Map<String, Object?> toRpcJson() => {
    'worker_id': workerId.trim(),
    'work_date': workDate.trim(),
    'attendance_status': status.wireValue,
    'regular_minutes': regularMinutes,
    'overtime_minutes': overtimeMinutes,
    'reason': reason.trim(),
  };
}

final class YorksWorkforceAttendanceAssignmentSnapshot {
  const YorksWorkforceAttendanceAssignmentSnapshot({
    required this.id,
    required this.kind,
    required this.teamId,
    required this.teamName,
    required this.supervisorAuthUserId,
    required this.supervisorName,
    required this.projectId,
    required this.projectRef,
    required this.projectName,
    required this.projectScopeId,
    required this.projectScopeName,
    required this.internalLocationId,
    required this.internalLocationName,
    required this.validFrom,
    required this.validTo,
    required this.recordVersion,
  });

  final String id;
  final String kind;
  final String teamId;
  final String teamName;
  final String? supervisorAuthUserId;
  final String? supervisorName;
  final String? projectId;
  final String? projectRef;
  final String? projectName;
  final String? projectScopeId;
  final String? projectScopeName;
  final String? internalLocationId;
  final String? internalLocationName;
  final String validFrom;
  final String? validTo;
  final int recordVersion;

  factory YorksWorkforceAttendanceAssignmentSnapshot.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final kind = _text(json['assignment_kind']);
    if (kind != 'primary' && kind != 'temporary') {
      throw const FormatException('Invalid retained assignment kind');
    }
    final validFrom = _date(json['valid_from']);
    final validTo = _nullableDate(json['valid_to']);
    if (validTo != null && validTo.compareTo(validFrom) < 0) {
      throw const FormatException('Invalid retained assignment dates');
    }
    final projectId = _nullableText(json['project_id']);
    final projectRef = _nullableText(json['project_ref']);
    final projectName = _nullableText(json['project_name']);
    final projectScopeId = _nullableText(json['project_scope_id']);
    final projectScopeName = _nullableText(json['project_scope_name']);
    final locationId = _nullableText(json['internal_location_id']);
    final locationName = _nullableText(json['internal_location_name']);
    if ((projectId == null) != (projectRef == null) ||
        (projectId == null) != (projectName == null) ||
        (projectScopeId == null) != (projectScopeName == null) ||
        (projectScopeId != null && projectId == null) ||
        (locationId == null) != (locationName == null) ||
        (projectId != null && locationId != null)) {
      throw const FormatException('Incomplete retained assignment scope');
    }
    return YorksWorkforceAttendanceAssignmentSnapshot(
      id: _text(json['assignment_id']),
      kind: kind,
      teamId: _text(json['team_id']),
      teamName: _text(json['team_name']),
      supervisorAuthUserId: _nullableText(json['supervisor_auth_user_id']),
      supervisorName: _nullableText(json['supervisor_name']),
      projectId: projectId,
      projectRef: projectRef,
      projectName: projectName,
      projectScopeId: projectScopeId,
      projectScopeName: projectScopeName,
      internalLocationId: locationId,
      internalLocationName: locationName,
      validFrom: validFrom,
      validTo: validTo,
      recordVersion: _positiveInteger(json['record_version']),
    );
  }
}

final class YorksWorkforceAttendanceAuthoritySnapshot {
  const YorksWorkforceAttendanceAuthoritySnapshot({
    required this.kind,
    required this.responsibilityAssignmentId,
    required this.scopeKind,
    required this.scopeReference,
    required this.recordVersion,
  });

  final String kind;
  final String? responsibilityAssignmentId;
  final String scopeKind;
  final String scopeReference;
  final int? recordVersion;

  factory YorksWorkforceAttendanceAuthoritySnapshot.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final kind = _text(json['authority_kind']);
    final responsibilityId = _nullableText(
      json['responsibility_assignment_id'],
    );
    final recordVersion = _nullablePositiveInteger(json['record_version']);
    final scopeKind = _text(json['scope_kind']);
    const scopes = {
      'organization',
      'worker',
      'team',
      'project',
      'project_scope',
      'internal_location',
    };
    if (!scopes.contains(scopeKind) ||
        (kind == 'admin_organization'
            ? responsibilityId != null ||
                  recordVersion != null ||
                  scopeKind != 'organization'
            : kind != 'responsibility' ||
                  responsibilityId == null ||
                  recordVersion == null)) {
      throw const FormatException('Invalid retained attendance authority');
    }
    return YorksWorkforceAttendanceAuthoritySnapshot(
      kind: kind,
      responsibilityAssignmentId: responsibilityId,
      scopeKind: scopeKind,
      scopeReference: _text(json['scope_reference']),
      recordVersion: recordVersion,
    );
  }
}

final class YorksWorkforceAttendanceScheduleSnapshot {
  const YorksWorkforceAttendanceScheduleSnapshot({
    required this.teamScheduleLinkId,
    required this.teamScheduleRecordVersion,
    required this.calendarId,
    required this.calendarCode,
    required this.calendarName,
    required this.calendarTimezone,
    required this.calendarRecordVersion,
    required this.calendarDateOverrideId,
    required this.calendarDateOverrideVersion,
    required this.calendarOverrideKind,
    required this.calendarExceptionName,
    required this.dayTypeSource,
    required this.isoWeekday,
    required this.dayType,
    required this.scheduledMinutes,
    required this.breakMinutes,
    required this.shiftTemplateId,
    required this.shiftCode,
    required this.shiftName,
    required this.shiftKind,
    required this.shiftStartTime,
    required this.shiftEndTime,
    required this.shiftScheduledMinutes,
    required this.shiftBreakMinutes,
    required this.shiftCrossesMidnight,
    required this.shiftWorkDateBasis,
    required this.shiftRecordVersion,
  });

  final String teamScheduleLinkId;
  final int teamScheduleRecordVersion;
  final String calendarId;
  final String calendarCode;
  final String calendarName;
  final String calendarTimezone;
  final int calendarRecordVersion;
  final String? calendarDateOverrideId;
  final int? calendarDateOverrideVersion;
  final String? calendarOverrideKind;
  final String? calendarExceptionName;
  final String dayTypeSource;
  final int isoWeekday;
  final YorksWorkforceDayType dayType;
  final int scheduledMinutes;
  final int breakMinutes;
  final String? shiftTemplateId;
  final String? shiftCode;
  final String? shiftName;
  final YorksWorkforceShiftKind? shiftKind;
  final String? shiftStartTime;
  final String? shiftEndTime;
  final int? shiftScheduledMinutes;
  final int? shiftBreakMinutes;
  final bool? shiftCrossesMidnight;
  final String? shiftWorkDateBasis;
  final int? shiftRecordVersion;

  factory YorksWorkforceAttendanceScheduleSnapshot.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final source = _text(json['day_type_source']);
    final overrideId = _nullableText(json['calendar_date_override_id']);
    final overrideVersion = _nullablePositiveInteger(
      json['calendar_date_override_version'],
    );
    final overrideKind = _nullableText(json['calendar_override_kind']);
    final exceptionName = _nullableText(json['calendar_exception_name']);
    if ((source == 'weekday' &&
            (overrideId != null ||
                overrideVersion != null ||
                overrideKind != null ||
                exceptionName != null)) ||
        (source == 'date_override' &&
            (overrideId == null ||
                overrideVersion == null ||
                overrideKind == null ||
                exceptionName == null)) ||
        (source != 'weekday' && source != 'date_override')) {
      throw const FormatException('Invalid retained day-type source');
    }

    final isoWeekday = _integer(json['iso_weekday']);
    if (isoWeekday < 1 || isoWeekday > 7) {
      throw const FormatException('Invalid retained ISO weekday');
    }
    final dayType = YorksWorkforceDayType.fromWire(json['day_type']);
    final overrideConsistent = switch (overrideKind) {
      'public_holiday' => dayType == YorksWorkforceDayType.publicHoliday,
      'site_closure' => dayType == YorksWorkforceDayType.siteClosed,
      'ramadan' => dayType == YorksWorkforceDayType.regularWorkingDay,
      'other' =>
        dayType == YorksWorkforceDayType.regularWorkingDay ||
            dayType == YorksWorkforceDayType.weeklyOff ||
            dayType == YorksWorkforceDayType.notScheduled,
      null => source == 'weekday',
      _ => false,
    };
    if (!overrideConsistent) {
      throw const FormatException('Inconsistent retained calendar override');
    }
    final scheduled = _nonNegativeInteger(json['scheduled_minutes']);
    final breakMinutes = _nonNegativeInteger(json['break_minutes']);
    if (scheduled + breakMinutes > 1440 ||
        (dayType == YorksWorkforceDayType.regularWorkingDay
            ? scheduled == 0
            : scheduled != 0 || breakMinutes != 0)) {
      throw const FormatException('Invalid retained schedule minutes');
    }

    final shiftId = _nullableText(json['shift_template_id']);
    final shiftCode = _nullableText(json['shift_code']);
    final shiftName = _nullableText(json['shift_name']);
    final shiftKind = json['shift_kind'] == null
        ? null
        : YorksWorkforceShiftKind.fromWire(json['shift_kind']);
    final shiftStart = _nullableTime(json['shift_start_time']);
    final shiftEnd = _nullableTime(json['shift_end_time']);
    final shiftScheduled = _nullablePositiveInteger(
      json['shift_scheduled_minutes'],
    );
    final shiftBreak = _nullableNonNegativeInteger(json['shift_break_minutes']);
    final shiftCrosses = _nullableBoolean(json['shift_crosses_midnight']);
    final shiftBasis = _nullableText(json['shift_work_date_basis']);
    final shiftVersion = _nullablePositiveInteger(json['shift_record_version']);
    final hasShift = shiftId != null;
    if (hasShift != (shiftCode != null) ||
        hasShift != (shiftName != null) ||
        hasShift != (shiftKind != null) ||
        hasShift != (shiftScheduled != null) ||
        hasShift != (shiftBreak != null) ||
        hasShift != (shiftCrosses != null) ||
        hasShift != (shiftBasis != null) ||
        hasShift != (shiftVersion != null) ||
        (hasShift && shiftBasis != 'shift_start_date') ||
        ((shiftStart == null) != (shiftEnd == null)) ||
        (!hasShift && (shiftStart != null || shiftEnd != null)) ||
        (hasShift && shiftStart == null && shiftCrosses!) ||
        (hasShift && shiftScheduled! + shiftBreak! > 1440) ||
        (shiftStart != null &&
            shiftCrosses != (shiftEnd!.compareTo(shiftStart) < 0))) {
      throw const FormatException('Invalid retained shift snapshot');
    }

    return YorksWorkforceAttendanceScheduleSnapshot(
      teamScheduleLinkId: _text(json['team_schedule_link_id']),
      teamScheduleRecordVersion: _positiveInteger(
        json['team_schedule_record_version'],
      ),
      calendarId: _text(json['calendar_id']),
      calendarCode: _text(json['calendar_code']),
      calendarName: _text(json['calendar_name']),
      calendarTimezone: _text(json['calendar_timezone']),
      calendarRecordVersion: _positiveInteger(json['calendar_record_version']),
      calendarDateOverrideId: overrideId,
      calendarDateOverrideVersion: overrideVersion,
      calendarOverrideKind: overrideKind,
      calendarExceptionName: exceptionName,
      dayTypeSource: source,
      isoWeekday: isoWeekday,
      dayType: dayType,
      scheduledMinutes: scheduled,
      breakMinutes: breakMinutes,
      shiftTemplateId: shiftId,
      shiftCode: shiftCode,
      shiftName: shiftName,
      shiftKind: shiftKind,
      shiftStartTime: shiftStart,
      shiftEndTime: shiftEnd,
      shiftScheduledMinutes: shiftScheduled,
      shiftBreakMinutes: shiftBreak,
      shiftCrossesMidnight: shiftCrosses,
      shiftWorkDateBasis: shiftBasis,
      shiftRecordVersion: shiftVersion,
    );
  }
}

final class YorksWorkforceAttendanceDay {
  const YorksWorkforceAttendanceDay({
    required this.id,
    required this.workerId,
    required this.workerNumber,
    required this.workerName,
    required this.workerJoiningDate,
    required this.workerLeavingDate,
    required this.workDate,
    required this.status,
    required this.regularMinutes,
    required this.overtimeMinutes,
    required this.overtimeReason,
    required this.reason,
    required this.recordVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.assignment,
    required this.initialAuthority,
    required this.schedule,
  });

  final String id;
  final String workerId;
  final String workerNumber;
  final String workerName;
  final String workerJoiningDate;
  final String? workerLeavingDate;
  final String workDate;
  final YorksWorkforceAttendanceStatus status;
  final int regularMinutes;
  final int overtimeMinutes;
  final String? overtimeReason;
  final String reason;
  final int recordVersion;
  final String createdAt;
  final String updatedAt;
  final YorksWorkforceAttendanceAssignmentSnapshot assignment;
  final YorksWorkforceAttendanceAuthoritySnapshot initialAuthority;
  final YorksWorkforceAttendanceScheduleSnapshot schedule;

  factory YorksWorkforceAttendanceDay.fromRpcJson(Map<String, dynamic> json) {
    if (json['worker_status_at_creation'] != 'active') {
      throw const FormatException('Invalid worker status snapshot');
    }
    final status = YorksWorkforceAttendanceStatus.fromWire(
      json['attendance_status'],
    );
    final regular = _nonNegativeInteger(json['regular_minutes']);
    final overtime = _nonNegativeInteger(json['overtime_minutes']);
    final total = regular + overtime;
    if (regular > 1440 ||
        overtime > 1440 ||
        total > 1440 ||
        (status == YorksWorkforceAttendanceStatus.present
            ? total == 0
            : total != 0)) {
      throw const FormatException('Invalid attendance status/minutes');
    }
    final joining = _date(json['worker_joining_date']);
    final leaving = _nullableDate(json['worker_leaving_date']);
    final workDate = _date(json['work_date']);
    if (workDate.compareTo(joining) < 0 ||
        (leaving != null && workDate.compareTo(leaving) > 0)) {
      throw const FormatException('Attendance outside retained employment');
    }
    final overtimeReason = _nullableText(json['overtime_reason']);
    if ((overtimeReason?.length ?? 0) > 2000) {
      throw const FormatException('Invalid overtime evidence');
    }
    return YorksWorkforceAttendanceDay(
      id: _text(json['attendance_day_id']),
      workerId: _text(json['worker_id']),
      workerNumber: _text(json['worker_number']),
      workerName: _text(json['worker_name']),
      workerJoiningDate: joining,
      workerLeavingDate: leaving,
      workDate: workDate,
      status: status,
      regularMinutes: regular,
      overtimeMinutes: overtime,
      overtimeReason: overtimeReason,
      reason: _text(json['reason']),
      recordVersion: _positiveInteger(json['record_version']),
      createdAt: _timestamp(json['created_at']),
      updatedAt: _timestamp(json['updated_at']),
      assignment: YorksWorkforceAttendanceAssignmentSnapshot.fromRpcJson(
        _map(json['assignment']),
      ),
      initialAuthority: YorksWorkforceAttendanceAuthoritySnapshot.fromRpcJson(
        _map(json['initial_authority']),
      ),
      schedule: YorksWorkforceAttendanceScheduleSnapshot.fromRpcJson(
        _map(json['schedule']),
      ),
    );
  }
}

final class YorksWorkforceAttendanceProjection {
  YorksWorkforceAttendanceProjection({
    required this.schemaVersion,
    required this.authorizationMode,
    required this.actorAuthUserId,
    required this.workDate,
    required this.serverTime,
    required Iterable<YorksWorkforceAttendanceDay> days,
  }) : days = List.unmodifiable(days) {
    if (schemaVersion != 1 || authorizationMode != 'enforced_t03') {
      throw const FormatException('Unsupported attendance projection');
    }
  }

  final int schemaVersion;
  final String authorizationMode;
  final String actorAuthUserId;
  final String workDate;
  final String serverTime;
  final List<YorksWorkforceAttendanceDay> days;

  factory YorksWorkforceAttendanceProjection.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksWorkforceAttendanceProjection(
    schemaVersion: _positiveInteger(json['schema_version']),
    authorizationMode: _text(json['authorization_mode']),
    actorAuthUserId: _text(json['actor_auth_user_id']),
    workDate: _date(json['work_date']),
    serverTime: _timestamp(json['server_time']),
    days: _list(
      json['days'],
    ).map((value) => YorksWorkforceAttendanceDay.fromRpcJson(_map(value))),
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

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  throw const FormatException('Expected integer');
}

int _nonNegativeInteger(Object? value) {
  final integer = _integer(value);
  if (integer < 0) throw const FormatException('Expected non-negative integer');
  return integer;
}

int _positiveInteger(Object? value) {
  final integer = _integer(value);
  if (integer <= 0) throw const FormatException('Expected positive integer');
  return integer;
}

int? _nullablePositiveInteger(Object? value) =>
    value == null ? null : _positiveInteger(value);

int? _nullableNonNegativeInteger(Object? value) =>
    value == null ? null : _nonNegativeInteger(value);

bool? _nullableBoolean(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  throw const FormatException('Expected boolean');
}

String _date(Object? value) {
  final text = _text(value);
  if (!_isDate(text)) throw const FormatException('Expected date');
  return text;
}

String? _nullableDate(Object? value) => value == null ? null : _date(value);

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
  if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d+)?$').hasMatch(text)) {
    throw const FormatException('Expected time');
  }
  return text;
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

bool _isUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
).hasMatch(value);
