enum YorksWorkforceDayType {
  regularWorkingDay('regular_working_day'),
  weeklyOff('weekly_off'),
  publicHoliday('public_holiday'),
  siteClosed('site_closed'),
  notScheduled('not_scheduled');

  const YorksWorkforceDayType(this.wireValue);
  final String wireValue;

  static YorksWorkforceDayType fromWire(Object? value) => values.firstWhere(
    (candidate) => candidate.wireValue == value,
    orElse: () => throw const FormatException('Unknown Workforce day type'),
  );
}

enum YorksWorkforceCalendarOverrideKind {
  publicHoliday('public_holiday'),
  siteClosure('site_closure'),
  ramadan('ramadan'),
  other('other');

  const YorksWorkforceCalendarOverrideKind(this.wireValue);
  final String wireValue;

  static YorksWorkforceCalendarOverrideKind fromWire(Object? value) =>
      values.firstWhere(
        (candidate) => candidate.wireValue == value,
        orElse: () => throw const FormatException(
          'Unknown Workforce calendar override kind',
        ),
      );
}

enum YorksWorkforceShiftKind {
  normalSite('normal_site'),
  warehouse('warehouse'),
  workshop('workshop'),
  ramadan('ramadan'),
  night('night'),
  other('other');

  const YorksWorkforceShiftKind(this.wireValue);
  final String wireValue;

  static YorksWorkforceShiftKind fromWire(Object? value) => values.firstWhere(
    (candidate) => candidate.wireValue == value,
    orElse: () => throw const FormatException('Unknown Workforce shift kind'),
  );
}

class YorksWorkforceCalendarWeekday {
  const YorksWorkforceCalendarWeekday({
    required this.isoWeekday,
    required this.dayType,
  });

  final int isoWeekday;
  final YorksWorkforceDayType dayType;

  factory YorksWorkforceCalendarWeekday.fromRpcJson(Map<String, dynamic> json) {
    final isoWeekday = _integer(json['iso_weekday']);
    if (isoWeekday < 1 || isoWeekday > 7) {
      throw const FormatException('Invalid ISO weekday');
    }
    final dayType = YorksWorkforceDayType.fromWire(json['day_type']);
    if (dayType != YorksWorkforceDayType.regularWorkingDay &&
        dayType != YorksWorkforceDayType.weeklyOff) {
      throw const FormatException('Invalid recurring Workforce day type');
    }
    return YorksWorkforceCalendarWeekday(
      isoWeekday: isoWeekday,
      dayType: dayType,
    );
  }
}

class YorksWorkforceCalendarDateOverride {
  const YorksWorkforceCalendarDateOverride({
    required this.id,
    required this.calendarDate,
    required this.overrideKind,
    required this.dayType,
    required this.name,
    required this.scheduledMinutes,
    required this.breakMinutes,
    required this.shiftTemplateId,
    required this.notes,
    required this.isActive,
    required this.recordVersion,
  });

  final String id;
  final String calendarDate;
  final YorksWorkforceCalendarOverrideKind overrideKind;
  final YorksWorkforceDayType dayType;
  final String name;
  final int scheduledMinutes;
  final int breakMinutes;
  final String? shiftTemplateId;
  final String? notes;
  final bool isActive;
  final int recordVersion;

  factory YorksWorkforceCalendarDateOverride.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final dayType = YorksWorkforceDayType.fromWire(json['day_type']);
    final overrideKind = YorksWorkforceCalendarOverrideKind.fromWire(
      json['override_kind'],
    );
    final consistent = switch (overrideKind) {
      YorksWorkforceCalendarOverrideKind.publicHoliday =>
        dayType == YorksWorkforceDayType.publicHoliday,
      YorksWorkforceCalendarOverrideKind.siteClosure =>
        dayType == YorksWorkforceDayType.siteClosed,
      YorksWorkforceCalendarOverrideKind.ramadan =>
        dayType == YorksWorkforceDayType.regularWorkingDay,
      YorksWorkforceCalendarOverrideKind.other =>
        dayType == YorksWorkforceDayType.regularWorkingDay ||
            dayType == YorksWorkforceDayType.weeklyOff ||
            dayType == YorksWorkforceDayType.notScheduled,
    };
    if (!consistent) {
      throw const FormatException('Inconsistent Workforce calendar override');
    }
    final scheduledMinutes = _nonNegativeInteger(json['scheduled_minutes']);
    final breakMinutes = _nonNegativeInteger(json['break_minutes']);
    _validateMinutePair(
      scheduledMinutes,
      breakMinutes,
      working: dayType == YorksWorkforceDayType.regularWorkingDay,
    );
    return YorksWorkforceCalendarDateOverride(
      id: _text(json['calendar_date_id']),
      calendarDate: _date(json['calendar_date']),
      overrideKind: overrideKind,
      dayType: dayType,
      name: _text(json['exception_name']),
      scheduledMinutes: scheduledMinutes,
      breakMinutes: breakMinutes,
      shiftTemplateId: _nullableText(json['shift_template_id']),
      notes: _nullableText(json['notes']),
      isActive: _boolean(json['is_active']),
      recordVersion: _positiveInteger(json['record_version']),
    );
  }
}

class YorksWorkforceCalendarConfiguration {
  const YorksWorkforceCalendarConfiguration({
    required this.id,
    required this.code,
    required this.name,
    required this.timezoneName,
    required this.standardScheduledMinutes,
    required this.breakMinutes,
    required this.validFrom,
    required this.validTo,
    required this.isActive,
    required this.isEffective,
    required this.recordVersion,
    required this.weekdays,
    required this.dateOverrides,
  });

  final String id;
  final String code;
  final String name;
  final String timezoneName;
  final int standardScheduledMinutes;
  final int breakMinutes;
  final String validFrom;
  final String? validTo;
  final bool isActive;
  final bool isEffective;
  final int recordVersion;
  final List<YorksWorkforceCalendarWeekday> weekdays;
  final List<YorksWorkforceCalendarDateOverride> dateOverrides;

  factory YorksWorkforceCalendarConfiguration.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final scheduledMinutes = _positiveInteger(
      json['standard_scheduled_minutes'],
    );
    final breakMinutes = _nonNegativeInteger(json['break_minutes']);
    _validateMinutePair(scheduledMinutes, breakMinutes, working: true);
    final weekdays = _list(json['weekdays'])
        .map((value) => YorksWorkforceCalendarWeekday.fromRpcJson(_map(value)))
        .toList(growable: false);
    if (weekdays.length != 7 ||
        weekdays.map((weekday) => weekday.isoWeekday).toSet().length != 7 ||
        !weekdays.any(
          (weekday) =>
              weekday.dayType == YorksWorkforceDayType.regularWorkingDay,
        )) {
      throw const FormatException('Calendar must contain seven ISO weekdays');
    }
    final validFrom = _date(json['valid_from']);
    final validTo = _nullableDate(json['valid_to']);
    _validateDateRange(validFrom, validTo);
    return YorksWorkforceCalendarConfiguration(
      id: _text(json['calendar_id']),
      code: _text(json['calendar_code']),
      name: _text(json['calendar_name']),
      timezoneName: _text(json['timezone_name']),
      standardScheduledMinutes: scheduledMinutes,
      breakMinutes: breakMinutes,
      validFrom: validFrom,
      validTo: validTo,
      isActive: _boolean(json['is_active']),
      isEffective: _boolean(json['is_effective']),
      recordVersion: _positiveInteger(json['record_version']),
      weekdays: weekdays,
      dateOverrides: _list(json['date_overrides'])
          .map(
            (value) =>
                YorksWorkforceCalendarDateOverride.fromRpcJson(_map(value)),
          )
          .toList(growable: false),
    );
  }
}

class YorksWorkforceShiftTemplate {
  const YorksWorkforceShiftTemplate({
    required this.id,
    required this.code,
    required this.name,
    required this.kind,
    required this.startTime,
    required this.endTime,
    required this.scheduledMinutes,
    required this.breakMinutes,
    required this.crossesMidnight,
    required this.validFrom,
    required this.validTo,
    required this.isActive,
    required this.isEffective,
    required this.recordVersion,
  });

  final String id;
  final String code;
  final String name;
  final YorksWorkforceShiftKind kind;
  final String? startTime;
  final String? endTime;
  final int scheduledMinutes;
  final int breakMinutes;
  final bool crossesMidnight;
  final String validFrom;
  final String? validTo;
  final bool isActive;
  final bool isEffective;
  final int recordVersion;

  factory YorksWorkforceShiftTemplate.fromRpcJson(Map<String, dynamic> json) {
    if (json['work_date_basis'] != 'shift_start_date') {
      throw const FormatException('Unsupported Workforce work-date basis');
    }
    final startTime = _nullableTime(json['start_time']);
    final endTime = _nullableTime(json['end_time']);
    if ((startTime == null) != (endTime == null) ||
        (startTime != null && startTime == endTime)) {
      throw const FormatException('Invalid Workforce shift times');
    }
    final crossesMidnight = _boolean(json['crosses_midnight']);
    if ((startTime == null && crossesMidnight) ||
        (startTime != null &&
            crossesMidnight != (endTime!.compareTo(startTime) < 0))) {
      throw const FormatException('Invalid cross-midnight flag');
    }
    final scheduledMinutes = _positiveInteger(json['scheduled_minutes']);
    final breakMinutes = _nonNegativeInteger(json['break_minutes']);
    _validateMinutePair(scheduledMinutes, breakMinutes, working: true);
    final validFrom = _date(json['valid_from']);
    final validTo = _nullableDate(json['valid_to']);
    _validateDateRange(validFrom, validTo);
    return YorksWorkforceShiftTemplate(
      id: _text(json['shift_template_id']),
      code: _text(json['shift_code']),
      name: _text(json['shift_name']),
      kind: YorksWorkforceShiftKind.fromWire(json['shift_kind']),
      startTime: startTime,
      endTime: endTime,
      scheduledMinutes: scheduledMinutes,
      breakMinutes: breakMinutes,
      crossesMidnight: crossesMidnight,
      validFrom: validFrom,
      validTo: validTo,
      isActive: _boolean(json['is_active']),
      isEffective: _boolean(json['is_effective']),
      recordVersion: _positiveInteger(json['record_version']),
    );
  }
}

class YorksWorkforceTeamScheduleLink {
  const YorksWorkforceTeamScheduleLink({
    required this.id,
    required this.teamId,
    required this.teamCode,
    required this.teamName,
    required this.calendarId,
    required this.calendarCode,
    required this.calendarName,
    required this.timezoneName,
    required this.shiftTemplateId,
    required this.shiftCode,
    required this.shiftName,
    required this.validFrom,
    required this.validTo,
    required this.reason,
    required this.isEffective,
    required this.recordVersion,
  });

  final String id;
  final String teamId;
  final String teamCode;
  final String teamName;
  final String calendarId;
  final String calendarCode;
  final String calendarName;
  final String timezoneName;
  final String? shiftTemplateId;
  final String? shiftCode;
  final String? shiftName;
  final String validFrom;
  final String? validTo;
  final String reason;
  final bool isEffective;
  final int recordVersion;

  factory YorksWorkforceTeamScheduleLink.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final validFrom = _date(json['valid_from']);
    final validTo = _nullableDate(json['valid_to']);
    _validateDateRange(validFrom, validTo);
    final shiftId = _nullableText(json['shift_template_id']);
    final shiftCode = _nullableText(json['shift_code']);
    final shiftName = _nullableText(json['shift_name']);
    if ((shiftId == null) != (shiftCode == null) ||
        (shiftId == null) != (shiftName == null)) {
      throw const FormatException('Incomplete Workforce shift reference');
    }
    return YorksWorkforceTeamScheduleLink(
      id: _text(json['team_schedule_link_id']),
      teamId: _text(json['team_id']),
      teamCode: _text(json['team_code']),
      teamName: _text(json['team_name']),
      calendarId: _text(json['calendar_id']),
      calendarCode: _text(json['calendar_code']),
      calendarName: _text(json['calendar_name']),
      timezoneName: _text(json['timezone_name']),
      shiftTemplateId: shiftId,
      shiftCode: shiftCode,
      shiftName: shiftName,
      validFrom: validFrom,
      validTo: validTo,
      reason: _text(json['reason']),
      isEffective: _boolean(json['is_effective']),
      recordVersion: _positiveInteger(json['record_version']),
    );
  }
}

class YorksWorkforceConfigurationProjection {
  const YorksWorkforceConfigurationProjection({
    required this.schemaVersion,
    required this.authorizationMode,
    required this.actorAuthUserId,
    required this.onDate,
    required this.serverTime,
    required this.calendars,
    required this.shiftTemplates,
    required this.teamScheduleLinks,
  });

  final int schemaVersion;
  final String authorizationMode;
  final String actorAuthUserId;
  final String onDate;
  final String serverTime;
  final List<YorksWorkforceCalendarConfiguration> calendars;
  final List<YorksWorkforceShiftTemplate> shiftTemplates;
  final List<YorksWorkforceTeamScheduleLink> teamScheduleLinks;

  factory YorksWorkforceConfigurationProjection.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final schemaVersion = _positiveInteger(json['schema_version']);
    final authorizationMode = _text(json['authorization_mode']);
    if (schemaVersion != 1 ||
        !const {
          'admin_legacy_t02',
          'enforced_administration',
        }.contains(authorizationMode)) {
      throw const FormatException(
        'Unsupported Workforce configuration projection',
      );
    }
    return YorksWorkforceConfigurationProjection(
      schemaVersion: schemaVersion,
      authorizationMode: authorizationMode,
      actorAuthUserId: _text(json['actor_auth_user_id']),
      onDate: _date(json['on_date']),
      serverTime: _timestamp(json['server_time']),
      calendars: _list(json['calendars'])
          .map(
            (value) =>
                YorksWorkforceCalendarConfiguration.fromRpcJson(_map(value)),
          )
          .toList(growable: false),
      shiftTemplates: _list(json['shift_templates'])
          .map((value) => YorksWorkforceShiftTemplate.fromRpcJson(_map(value)))
          .toList(growable: false),
      teamScheduleLinks: _list(json['team_schedule_links'])
          .map(
            (value) => YorksWorkforceTeamScheduleLink.fromRpcJson(_map(value)),
          )
          .toList(growable: false),
    );
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
  if (integer < 1) throw const FormatException('Expected positive integer');
  return integer;
}

bool _boolean(Object? value) {
  if (value is bool) return value;
  throw const FormatException('Expected boolean');
}

String _date(Object? value) {
  final text = _text(value);
  final parsed = DateTime.tryParse(text);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) || parsed == null) {
    throw const FormatException('Expected date');
  }
  final normalized = [
    parsed.year.toString().padLeft(4, '0'),
    parsed.month.toString().padLeft(2, '0'),
    parsed.day.toString().padLeft(2, '0'),
  ].join('-');
  if (normalized != text) throw const FormatException('Expected date');
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
  if (!RegExp(r'^\d{2}:\d{2}(:\d{2}(\.\d+)?)?$').hasMatch(text)) {
    throw const FormatException('Expected time');
  }
  return text;
}

void _validateDateRange(String validFrom, String? validTo) {
  if (validTo != null && validTo.compareTo(validFrom) < 0) {
    throw const FormatException('Invalid effective date range');
  }
}

void _validateMinutePair(
  int scheduledMinutes,
  int breakMinutes, {
  required bool working,
}) {
  if (scheduledMinutes > 1440 ||
      breakMinutes > 1440 ||
      scheduledMinutes + breakMinutes > 1440 ||
      (working && scheduledMinutes == 0) ||
      (!working && (scheduledMinutes != 0 || breakMinutes != 0))) {
    throw const FormatException('Invalid Workforce minute values');
  }
}
