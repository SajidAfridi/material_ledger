const yorksWorkforceMonthlyMaxPageSize = 500;

enum YorksWorkforceMonthlyPeriodStatus {
  draft('draft'),
  readyForReview('ready_for_review'),
  submitted('submitted'),
  underReview('under_review'),
  returnedForCorrection('returned_for_correction'),
  awaitingFinalApproval('awaiting_final_approval'),
  locked('locked'),
  reopened('reopened');

  const YorksWorkforceMonthlyPeriodStatus(this.wireValue);
  final String wireValue;

  static YorksWorkforceMonthlyPeriodStatus fromWire(Object? value) =>
      values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => throw const FormatException(
          'Invalid Workforce monthly period status',
        ),
      );
}

enum YorksWorkforceMonthlyIssueSeverity {
  blocking('blocking'),
  warning('warning');

  const YorksWorkforceMonthlyIssueSeverity(this.wireValue);
  final String wireValue;

  static YorksWorkforceMonthlyIssueSeverity fromWire(Object? value) =>
      values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => throw const FormatException(
          'Invalid Workforce monthly issue severity',
        ),
      );
}

enum YorksWorkforceMonthlyWorkerStatus {
  complete('complete'),
  hasWarnings('has_warnings'),
  hasErrors('has_errors');

  const YorksWorkforceMonthlyWorkerStatus(this.wireValue);
  final String wireValue;

  static YorksWorkforceMonthlyWorkerStatus fromWire(Object? value) =>
      values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => throw const FormatException(
          'Invalid Workforce monthly worker status',
        ),
      );
}

enum YorksWorkforceMonthlyDailyStatus {
  future('future'),
  notStarted('not_started'),
  complete('complete'),
  hasWarnings('has_warnings'),
  hasErrors('has_errors');

  const YorksWorkforceMonthlyDailyStatus(this.wireValue);
  final String wireValue;

  static YorksWorkforceMonthlyDailyStatus fromWire(Object? value) =>
      values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => throw const FormatException(
          'Invalid Workforce monthly daily status',
        ),
      );
}

final class YorksWorkforceMonthlyFilters {
  const YorksWorkforceMonthlyFilters({
    required this.teamId,
    required this.periodMonth,
    this.query = '',
    this.issueSeverity,
    this.issueCode,
    this.workerLimit = 50,
    this.workerOffset = 0,
  });

  final String teamId;
  final String periodMonth;
  final String query;
  final YorksWorkforceMonthlyIssueSeverity? issueSeverity;
  final String? issueCode;
  final int workerLimit;
  final int workerOffset;

  bool get isValid =>
      _isUuid(teamId.trim()) &&
      _isFirstOfMonth(periodMonth.trim()) &&
      query.trim().length <= 200 &&
      (_nullableTrimmed(issueCode)?.length ?? 0) <= 80 &&
      workerLimit >= 1 &&
      workerLimit <= yorksWorkforceMonthlyMaxPageSize &&
      workerOffset >= 0;

  YorksWorkforceMonthlyFilters copyWith({
    String? teamId,
    String? periodMonth,
    String? query,
    YorksWorkforceMonthlyIssueSeverity? issueSeverity,
    bool clearIssueSeverity = false,
    String? issueCode,
    bool clearIssueCode = false,
    int? workerLimit,
    int? workerOffset,
  }) => YorksWorkforceMonthlyFilters(
    teamId: teamId ?? this.teamId,
    periodMonth: periodMonth ?? this.periodMonth,
    query: query ?? this.query,
    issueSeverity: clearIssueSeverity
        ? null
        : issueSeverity ?? this.issueSeverity,
    issueCode: clearIssueCode ? null : issueCode ?? this.issueCode,
    workerLimit: workerLimit ?? this.workerLimit,
    workerOffset: workerOffset ?? this.workerOffset,
  );

  Map<String, Object?> toRpcParameters() => {
    'p_team_id': teamId.trim(),
    'p_period_month': periodMonth.trim(),
    'p_query': _nullableTrimmed(query),
    'p_issue_severity': issueSeverity?.wireValue,
    'p_issue_code': _nullableTrimmed(issueCode),
    'p_worker_limit': workerLimit,
    'p_worker_offset': workerOffset,
  };

  factory YorksWorkforceMonthlyFilters.fromRpcJson(Map<String, dynamic> json) {
    _requireExactKeys(json, _monthlyFilterKeys, 'monthly filters');
    final filters = YorksWorkforceMonthlyFilters(
      teamId: _uuid(json['team_id']),
      periodMonth: _firstOfMonth(json['period_month']),
      query: _nullableText(json['query']) ?? '',
      issueSeverity: json['issue_severity'] == null
          ? null
          : YorksWorkforceMonthlyIssueSeverity.fromWire(json['issue_severity']),
      issueCode: _nullableText(json['issue_code']),
      workerLimit: _positiveInteger(json['worker_limit']),
      workerOffset: _nonNegativeInteger(json['worker_offset']),
    );
    if (!filters.isValid) {
      throw const FormatException('Invalid monthly filter projection');
    }
    return filters;
  }
}

final class YorksWorkforceMonthlyTeamFilters {
  const YorksWorkforceMonthlyTeamFilters({
    required this.periodMonth,
    this.query = '',
    this.limit = 50,
    this.offset = 0,
  });

  final String periodMonth;
  final String query;
  final int limit;
  final int offset;

  bool get isValid =>
      _isFirstOfMonth(periodMonth.trim()) &&
      query.trim().length <= 200 &&
      limit >= 1 &&
      limit <= yorksWorkforceMonthlyMaxPageSize &&
      offset >= 0;

  YorksWorkforceMonthlyTeamFilters copyWith({
    String? periodMonth,
    String? query,
    int? limit,
    int? offset,
  }) => YorksWorkforceMonthlyTeamFilters(
    periodMonth: periodMonth ?? this.periodMonth,
    query: query ?? this.query,
    limit: limit ?? this.limit,
    offset: offset ?? this.offset,
  );

  Map<String, Object?> toRpcParameters() => {
    'p_period_month': periodMonth.trim(),
    'p_query': _nullableTrimmed(query),
    'p_limit': limit,
    'p_offset': offset,
  };

  factory YorksWorkforceMonthlyTeamFilters.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _teamFilterKeys, 'monthly team filters');
    final filters = YorksWorkforceMonthlyTeamFilters(
      periodMonth: _firstOfMonth(json['period_month']),
      query: _nullableText(json['query']) ?? '',
      limit: _positiveInteger(json['limit']),
      offset: _nonNegativeInteger(json['offset']),
    );
    if (!filters.isValid) {
      throw const FormatException('Invalid monthly team filters');
    }
    return filters;
  }
}

final class YorksWorkforceMonthlyTeam {
  const YorksWorkforceMonthlyTeam({
    required this.id,
    required this.code,
    required this.name,
    required this.department,
    required this.periodExists,
    required this.periodId,
    required this.storedStatus,
    required this.recordVersion,
    required this.currentValidationNumber,
  });

  final String id;
  final String code;
  final String name;
  final String? department;
  final bool periodExists;
  final String? periodId;
  final YorksWorkforceMonthlyPeriodStatus? storedStatus;
  final int? recordVersion;
  final int? currentValidationNumber;

  factory YorksWorkforceMonthlyTeam.fromRpcJson(Map<String, dynamic> json) {
    _requireExactKeys(json, _teamKeys, 'monthly team');
    final periodExists = _boolean(json['period_exists']);
    final periodId = json['period_id'] == null
        ? null
        : _uuid(json['period_id']);
    final status = json['stored_status'] == null
        ? null
        : YorksWorkforceMonthlyPeriodStatus.fromWire(json['stored_status']);
    final version = json['record_version'] == null
        ? null
        : _positiveInteger(json['record_version']);
    final validationNumber = json['current_validation_number'] == null
        ? null
        : _positiveInteger(json['current_validation_number']);
    if (periodExists != (periodId != null) ||
        periodExists != (status != null) ||
        periodExists != (version != null) ||
        periodExists != (validationNumber != null)) {
      throw const FormatException('Invalid monthly team period tuple');
    }
    return YorksWorkforceMonthlyTeam(
      id: _uuid(json['team_id']),
      code: _text(json['team_code']),
      name: _text(json['team_name']),
      department: _nullableText(json['department']),
      periodExists: periodExists,
      periodId: periodId,
      storedStatus: status,
      recordVersion: version,
      currentValidationNumber: validationNumber,
    );
  }
}

final class YorksWorkforceMonthlyTeamProjection {
  YorksWorkforceMonthlyTeamProjection({
    required this.schemaVersion,
    required this.authorizationMode,
    required this.actorAuthUserId,
    required this.serverTime,
    required this.filters,
    required this.totalCount,
    required Iterable<YorksWorkforceMonthlyTeam> teams,
  }) : teams = List.unmodifiable(teams) {
    if (schemaVersion != 1 ||
        authorizationMode != 'enforced_t06' ||
        totalCount < this.teams.length) {
      throw const FormatException('Invalid monthly team projection context');
    }
    _requireUnique(this.teams.map((item) => item.id), 'monthly team');
  }

  final int schemaVersion;
  final String authorizationMode;
  final String actorAuthUserId;
  final String serverTime;
  final YorksWorkforceMonthlyTeamFilters filters;
  final int totalCount;
  final List<YorksWorkforceMonthlyTeam> teams;

  factory YorksWorkforceMonthlyTeamProjection.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _teamProjectionKeys, 'monthly team projection');
    return YorksWorkforceMonthlyTeamProjection(
      schemaVersion: _positiveInteger(json['schema_version']),
      authorizationMode: _text(json['authorization_mode']),
      actorAuthUserId: _uuid(json['actor_auth_user_id']),
      serverTime: _timestamp(json['server_time']),
      filters: YorksWorkforceMonthlyTeamFilters.fromRpcJson(
        _map(json['filters']),
      ),
      totalCount: _nonNegativeInteger(json['total_count']),
      teams: _list(
        json['teams'],
      ).map((value) => YorksWorkforceMonthlyTeam.fromRpcJson(_map(value))),
    );
  }
}

final class YorksWorkforceMonthlyCapabilities {
  const YorksWorkforceMonthlyCapabilities({
    required this.canView,
    required this.canValidate,
  });

  final bool canView;
  final bool canValidate;

  factory YorksWorkforceMonthlyCapabilities.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _monthlyCapabilityKeys, 'monthly capabilities');
    final canView = _boolean(json['can_view']);
    if (!canView) {
      throw const FormatException('Monthly projection denied its own read');
    }
    return YorksWorkforceMonthlyCapabilities(
      canView: canView,
      canValidate: _boolean(json['can_validate']),
    );
  }
}

final class YorksWorkforceMonthlyPeriod {
  const YorksWorkforceMonthlyPeriod({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.periodMonth,
    required this.storedStatus,
    required this.effectiveStatus,
    required this.isStale,
    required this.recordVersion,
    required this.currentValidationRunId,
    required this.currentValidationNumber,
    required this.sourceFingerprint,
    required this.currentSourceFingerprint,
    required this.validatedAt,
    required this.validatedByAuthUserId,
  });

  final String id;
  final String teamId;
  final String teamName;
  final String periodMonth;
  final YorksWorkforceMonthlyPeriodStatus storedStatus;
  final YorksWorkforceMonthlyPeriodStatus effectiveStatus;
  final bool isStale;
  final int recordVersion;
  final String currentValidationRunId;
  final int currentValidationNumber;
  final String sourceFingerprint;
  final String currentSourceFingerprint;
  final String validatedAt;
  final String validatedByAuthUserId;

  factory YorksWorkforceMonthlyPeriod.fromRpcJson(Map<String, dynamic> json) {
    _requireExactKeys(json, _periodKeys, 'monthly period');
    final stored = YorksWorkforceMonthlyPeriodStatus.fromWire(
      json['stored_status'],
    );
    final effective = YorksWorkforceMonthlyPeriodStatus.fromWire(
      json['effective_status'],
    );
    final stale = _boolean(json['is_stale']);
    if (stale && effective != YorksWorkforceMonthlyPeriodStatus.draft) {
      throw const FormatException('Stale monthly period must be draft');
    }
    return YorksWorkforceMonthlyPeriod(
      id: _uuid(json['period_id']),
      teamId: _uuid(json['team_id']),
      teamName: _text(json['team_name']),
      periodMonth: _firstOfMonth(json['period_month']),
      storedStatus: stored,
      effectiveStatus: effective,
      isStale: stale,
      recordVersion: _positiveInteger(json['record_version']),
      currentValidationRunId: _uuid(json['current_validation_run_id']),
      currentValidationNumber: _positiveInteger(
        json['current_validation_number'],
      ),
      sourceFingerprint: _fingerprint(json['source_fingerprint']),
      currentSourceFingerprint: _fingerprint(
        json['current_source_fingerprint'],
      ),
      validatedAt: _timestamp(json['validated_at']),
      validatedByAuthUserId: _uuid(json['validated_by_auth_user_id']),
    );
  }
}

final class YorksWorkforceMonthlySummary {
  const YorksWorkforceMonthlySummary({
    required this.workerCount,
    required this.dateCount,
    required this.scheduledDayCount,
    required this.futureDayCount,
    required this.presentDayCount,
    required this.absentDayCount,
    required this.leaveDayCount,
    required this.weeklyOffDayCount,
    required this.publicHolidayDayCount,
    required this.siteClosureDayCount,
    required this.missingDayCount,
    required this.regularMinutes,
    required this.overtimeMinutes,
    required this.allocationMinutes,
    required this.blockingIssueCount,
    required this.warningIssueCount,
    required this.projectCount,
    required this.locationCount,
  });

  final int workerCount;
  final int dateCount;
  final int scheduledDayCount;
  final int futureDayCount;
  final int presentDayCount;
  final int absentDayCount;
  final int leaveDayCount;
  final int weeklyOffDayCount;
  final int publicHolidayDayCount;
  final int siteClosureDayCount;
  final int missingDayCount;
  final int regularMinutes;
  final int overtimeMinutes;
  final int allocationMinutes;
  final int blockingIssueCount;
  final int warningIssueCount;
  final int projectCount;
  final int locationCount;

  factory YorksWorkforceMonthlySummary.fromRpcJson(Map<String, dynamic> json) {
    _requireExactKeys(json, _summaryKeys, 'monthly summary');
    return YorksWorkforceMonthlySummary(
      workerCount: _nonNegativeInteger(json['worker_count']),
      dateCount: _nonNegativeInteger(json['date_count']),
      scheduledDayCount: _nonNegativeInteger(json['scheduled_day_count']),
      futureDayCount: _nonNegativeInteger(json['future_day_count']),
      presentDayCount: _nonNegativeInteger(json['present_day_count']),
      absentDayCount: _nonNegativeInteger(json['absent_day_count']),
      leaveDayCount: _nonNegativeInteger(json['leave_day_count']),
      weeklyOffDayCount: _nonNegativeInteger(json['weekly_off_day_count']),
      publicHolidayDayCount: _nonNegativeInteger(
        json['public_holiday_day_count'],
      ),
      siteClosureDayCount: _nonNegativeInteger(json['site_closure_day_count']),
      missingDayCount: _nonNegativeInteger(json['missing_day_count']),
      regularMinutes: _nonNegativeInteger(json['regular_minutes']),
      overtimeMinutes: _nonNegativeInteger(json['overtime_minutes']),
      allocationMinutes: _nonNegativeInteger(json['allocation_minutes']),
      blockingIssueCount: _nonNegativeInteger(json['blocking_issue_count']),
      warningIssueCount: _nonNegativeInteger(json['warning_issue_count']),
      projectCount: _nonNegativeInteger(json['project_count']),
      locationCount: _nonNegativeInteger(json['location_count']),
    );
  }
}

final class YorksWorkforceMonthlyIssueCount {
  const YorksWorkforceMonthlyIssueCount({
    required this.severity,
    required this.issueCode,
    required this.count,
  });

  final YorksWorkforceMonthlyIssueSeverity severity;
  final String issueCode;
  final int count;

  factory YorksWorkforceMonthlyIssueCount.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _issueCountKeys, 'monthly issue count');
    return YorksWorkforceMonthlyIssueCount(
      severity: YorksWorkforceMonthlyIssueSeverity.fromWire(json['severity']),
      issueCode: _text(json['issue_code']),
      count: _positiveInteger(json['count']),
    );
  }
}

final class YorksWorkforceMonthlyWorkerSummary {
  YorksWorkforceMonthlyWorkerSummary({
    required this.workerId,
    required this.workerNumber,
    required this.workerName,
    required this.tradeName,
    required this.employerName,
    required this.firstApplicableDate,
    required this.lastApplicableDate,
    required Iterable<YorksWorkforceMonthlySupervisor> supervisors,
    required Iterable<YorksWorkforceMonthlyProject> projects,
    required Iterable<YorksWorkforceMonthlyLocation> locations,
    required this.scheduledDayCount,
    required this.presentDayCount,
    required this.absentDayCount,
    required this.leaveDayCount,
    required this.weeklyOffDayCount,
    required this.publicHolidayDayCount,
    required this.regularMinutes,
    required this.overtimeMinutes,
    required this.missingDayCount,
    required this.blockingIssueCount,
    required this.warningIssueCount,
    required this.status,
  }) : supervisors = List.unmodifiable(supervisors),
       projects = List.unmodifiable(projects),
       locations = List.unmodifiable(locations);

  final String workerId;
  final String workerNumber;
  final String workerName;
  final String? tradeName;
  final String employerName;
  final String firstApplicableDate;
  final String lastApplicableDate;
  final List<YorksWorkforceMonthlySupervisor> supervisors;
  final List<YorksWorkforceMonthlyProject> projects;
  final List<YorksWorkforceMonthlyLocation> locations;
  final int scheduledDayCount;
  final int presentDayCount;
  final int absentDayCount;
  final int leaveDayCount;
  final int weeklyOffDayCount;
  final int publicHolidayDayCount;
  final int regularMinutes;
  final int overtimeMinutes;
  final int missingDayCount;
  final int blockingIssueCount;
  final int warningIssueCount;
  final YorksWorkforceMonthlyWorkerStatus status;

  factory YorksWorkforceMonthlyWorkerSummary.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _workerSummaryKeys, 'monthly worker summary');
    final first = _date(json['first_applicable_date']);
    final last = _date(json['last_applicable_date']);
    if (last.compareTo(first) < 0) {
      throw const FormatException('Invalid worker applicable date range');
    }
    return YorksWorkforceMonthlyWorkerSummary(
      workerId: _uuid(json['worker_id']),
      workerNumber: _text(json['worker_number']),
      workerName: _text(json['worker_name']),
      tradeName: _nullableText(json['trade_name']),
      employerName: _text(json['employer_name']),
      firstApplicableDate: first,
      lastApplicableDate: last,
      supervisors: _list(json['supervisors']).map(
        (value) => YorksWorkforceMonthlySupervisor.fromRpcJson(_map(value)),
      ),
      projects: _list(
        json['projects'],
      ).map((value) => YorksWorkforceMonthlyProject.fromRpcJson(_map(value))),
      locations: _list(
        json['locations'],
      ).map((value) => YorksWorkforceMonthlyLocation.fromRpcJson(_map(value))),
      scheduledDayCount: _nonNegativeInteger(json['scheduled_day_count']),
      presentDayCount: _nonNegativeInteger(json['present_day_count']),
      absentDayCount: _nonNegativeInteger(json['absent_day_count']),
      leaveDayCount: _nonNegativeInteger(json['leave_day_count']),
      weeklyOffDayCount: _nonNegativeInteger(json['weekly_off_day_count']),
      publicHolidayDayCount: _nonNegativeInteger(
        json['public_holiday_day_count'],
      ),
      regularMinutes: _nonNegativeInteger(json['regular_minutes']),
      overtimeMinutes: _nonNegativeInteger(json['overtime_minutes']),
      missingDayCount: _nonNegativeInteger(json['missing_day_count']),
      blockingIssueCount: _nonNegativeInteger(json['blocking_issue_count']),
      warningIssueCount: _nonNegativeInteger(json['warning_issue_count']),
      status: YorksWorkforceMonthlyWorkerStatus.fromWire(json['status']),
    );
  }
}

final class YorksWorkforceMonthlySupervisor {
  const YorksWorkforceMonthlySupervisor({
    required this.authUserId,
    required this.name,
  });

  final String authUserId;
  final String? name;

  factory YorksWorkforceMonthlySupervisor.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _supervisorKeys, 'monthly supervisor');
    return YorksWorkforceMonthlySupervisor(
      authUserId: _uuid(json['supervisor_auth_user_id']),
      name: _nullableText(json['supervisor_name']),
    );
  }
}

final class YorksWorkforceMonthlyProject {
  const YorksWorkforceMonthlyProject({
    required this.id,
    required this.reference,
    required this.name,
    required this.scopeId,
    required this.scopeName,
  });

  final String id;
  final String? reference;
  final String? name;
  final String? scopeId;
  final String? scopeName;

  factory YorksWorkforceMonthlyProject.fromRpcJson(Map<String, dynamic> json) {
    _requireExactKeys(json, _projectKeys, 'monthly project');
    final scopeId = json['project_scope_id'] == null
        ? null
        : _uuid(json['project_scope_id']);
    final scopeName = _nullableText(json['project_scope_name']);
    if ((scopeId == null) != (scopeName == null)) {
      throw const FormatException('Invalid monthly project scope tuple');
    }
    return YorksWorkforceMonthlyProject(
      id: _uuid(json['project_id']),
      reference: _nullableText(json['project_ref']),
      name: _nullableText(json['project_name']),
      scopeId: scopeId,
      scopeName: scopeName,
    );
  }
}

final class YorksWorkforceMonthlyLocation {
  const YorksWorkforceMonthlyLocation({required this.id, required this.name});

  final String id;
  final String? name;

  factory YorksWorkforceMonthlyLocation.fromRpcJson(Map<String, dynamic> json) {
    _requireExactKeys(json, _locationKeys, 'monthly location');
    return YorksWorkforceMonthlyLocation(
      id: _uuid(json['internal_location_id']),
      name: _nullableText(json['internal_location_name']),
    );
  }
}

final class YorksWorkforceMonthlyProjection {
  YorksWorkforceMonthlyProjection({
    required this.schemaVersion,
    required this.authorizationMode,
    required this.actorAuthUserId,
    required this.serverTime,
    required this.filters,
    required this.capabilities,
    required this.period,
    required this.summary,
    required Iterable<YorksWorkforceMonthlyIssueCount> issueCounts,
    required this.totalCount,
    required Iterable<YorksWorkforceMonthlyWorkerSummary> workers,
  }) : issueCounts = List.unmodifiable(issueCounts),
       workers = List.unmodifiable(workers) {
    if (schemaVersion != 1 || authorizationMode != 'enforced_t06') {
      throw const FormatException('Unsupported Workforce monthly schema');
    }
    if ((period == null) != (summary == null) ||
        (period == null &&
            (this.issueCounts.isNotEmpty ||
                totalCount != 0 ||
                this.workers.isNotEmpty)) ||
        totalCount < this.workers.length ||
        (period != null &&
            (period!.teamId != filters.teamId ||
                period!.periodMonth != filters.periodMonth)) ||
        (summary != null &&
            (totalCount > summary!.workerCount ||
                (filters.query.isEmpty &&
                    filters.issueSeverity == null &&
                    filters.issueCode == null &&
                    summary!.workerCount != totalCount)))) {
      throw const FormatException('Invalid monthly projection context');
    }
    _requireUnique(this.workers.map((item) => item.workerId), 'monthly worker');
    _requireUnique(
      this.issueCounts.map((item) => '${item.severity.name}:${item.issueCode}'),
      'monthly issue count',
    );
    if (summary != null) {
      final blocking = this.issueCounts
          .where(
            (item) =>
                item.severity == YorksWorkforceMonthlyIssueSeverity.blocking,
          )
          .fold<int>(0, (sum, item) => sum + item.count);
      final warnings = this.issueCounts
          .where(
            (item) =>
                item.severity == YorksWorkforceMonthlyIssueSeverity.warning,
          )
          .fold<int>(0, (sum, item) => sum + item.count);
      if (blocking != summary!.blockingIssueCount ||
          warnings != summary!.warningIssueCount ||
          (period!.effectiveStatus ==
                  YorksWorkforceMonthlyPeriodStatus.readyForReview &&
              blocking != 0)) {
        throw const FormatException('Monthly issue totals do not reconcile');
      }
    }
  }

  final int schemaVersion;
  final String authorizationMode;
  final String actorAuthUserId;
  final String serverTime;
  final YorksWorkforceMonthlyFilters filters;
  final YorksWorkforceMonthlyCapabilities capabilities;
  final YorksWorkforceMonthlyPeriod? period;
  final YorksWorkforceMonthlySummary? summary;
  final List<YorksWorkforceMonthlyIssueCount> issueCounts;
  final int totalCount;
  final List<YorksWorkforceMonthlyWorkerSummary> workers;

  bool get isAbsent => period == null;

  factory YorksWorkforceMonthlyProjection.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _projectionKeys, 'monthly projection');
    return YorksWorkforceMonthlyProjection(
      schemaVersion: _positiveInteger(json['schema_version']),
      authorizationMode: _text(json['authorization_mode']),
      actorAuthUserId: _uuid(json['actor_auth_user_id']),
      serverTime: _timestamp(json['server_time']),
      filters: YorksWorkforceMonthlyFilters.fromRpcJson(_map(json['filters'])),
      capabilities: YorksWorkforceMonthlyCapabilities.fromRpcJson(
        _map(json['capabilities']),
      ),
      period: json['period'] == null
          ? null
          : YorksWorkforceMonthlyPeriod.fromRpcJson(_map(json['period'])),
      summary: json['summary'] == null
          ? null
          : YorksWorkforceMonthlySummary.fromRpcJson(_map(json['summary'])),
      issueCounts: _list(json['issue_counts']).map(
        (value) => YorksWorkforceMonthlyIssueCount.fromRpcJson(_map(value)),
      ),
      totalCount: _nonNegativeInteger(json['total_count']),
      workers: _list(json['workers']).map(
        (value) => YorksWorkforceMonthlyWorkerSummary.fromRpcJson(_map(value)),
      ),
    );
  }
}

final class YorksWorkforceMonthlyIssueFilters {
  const YorksWorkforceMonthlyIssueFilters({
    required this.periodId,
    required this.validationRunId,
    this.severity,
    this.issueCode,
    this.workerId,
    this.limit = 100,
    this.offset = 0,
  });

  final String periodId;
  final String validationRunId;
  final YorksWorkforceMonthlyIssueSeverity? severity;
  final String? issueCode;
  final String? workerId;
  final int limit;
  final int offset;

  bool get isValid =>
      _isUuid(periodId.trim()) &&
      _isUuid(validationRunId.trim()) &&
      (_nullableTrimmed(issueCode)?.length ?? 0) <= 80 &&
      (_nullableTrimmed(workerId) == null ||
          _isUuid(_nullableTrimmed(workerId)!)) &&
      limit >= 1 &&
      limit <= yorksWorkforceMonthlyMaxPageSize &&
      offset >= 0;

  YorksWorkforceMonthlyIssueFilters copyWith({
    YorksWorkforceMonthlyIssueSeverity? severity,
    bool clearSeverity = false,
    String? issueCode,
    bool clearIssueCode = false,
    String? workerId,
    bool clearWorker = false,
    int? limit,
    int? offset,
  }) => YorksWorkforceMonthlyIssueFilters(
    periodId: periodId,
    validationRunId: validationRunId,
    severity: clearSeverity ? null : severity ?? this.severity,
    issueCode: clearIssueCode ? null : issueCode ?? this.issueCode,
    workerId: clearWorker ? null : workerId ?? this.workerId,
    limit: limit ?? this.limit,
    offset: offset ?? this.offset,
  );

  Map<String, Object?> toRpcParameters() => {
    'p_period_id': periodId.trim(),
    'p_validation_run_id': validationRunId.trim(),
    'p_severity': severity?.wireValue,
    'p_issue_code': _nullableTrimmed(issueCode),
    'p_worker_id': _nullableTrimmed(workerId),
    'p_limit': limit,
    'p_offset': offset,
  };

  factory YorksWorkforceMonthlyIssueFilters.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _issueFilterKeys, 'monthly issue filters');
    final filters = YorksWorkforceMonthlyIssueFilters(
      periodId: _uuid(json['period_id']),
      validationRunId: _uuid(json['validation_run_id']),
      severity: json['severity'] == null
          ? null
          : YorksWorkforceMonthlyIssueSeverity.fromWire(json['severity']),
      issueCode: _nullableText(json['issue_code']),
      workerId: json['worker_id'] == null ? null : _uuid(json['worker_id']),
      limit: _positiveInteger(json['limit']),
      offset: _nonNegativeInteger(json['offset']),
    );
    if (!filters.isValid) {
      throw const FormatException('Invalid monthly issue filter projection');
    }
    return filters;
  }
}

final class YorksWorkforceMonthlyIssue {
  YorksWorkforceMonthlyIssue({
    required this.id,
    required this.severity,
    required this.issueCode,
    required this.workerId,
    required this.workerNumber,
    required this.workerName,
    required this.workDate,
    required this.messageKey,
    required Map<String, dynamic> context,
  }) : context = Map.unmodifiable(context);

  final String id;
  final YorksWorkforceMonthlyIssueSeverity severity;
  final String issueCode;
  final String? workerId;
  final String? workerNumber;
  final String? workerName;
  final String? workDate;
  final String messageKey;
  final Map<String, dynamic> context;

  factory YorksWorkforceMonthlyIssue.fromRpcJson(Map<String, dynamic> json) {
    _requireExactKeys(json, _issueKeys, 'monthly issue');
    final workerId = json['worker_id'] == null
        ? null
        : _uuid(json['worker_id']);
    final workerNumber = _nullableText(json['worker_number']);
    final workerName = _nullableText(json['worker_name']);
    if ((workerId == null) != (workerNumber == null) ||
        (workerId == null) != (workerName == null)) {
      throw const FormatException('Invalid monthly issue worker tuple');
    }
    return YorksWorkforceMonthlyIssue(
      id: _uuid(json['issue_id']),
      severity: YorksWorkforceMonthlyIssueSeverity.fromWire(json['severity']),
      issueCode: _text(json['issue_code']),
      workerId: workerId,
      workerNumber: workerNumber,
      workerName: workerName,
      workDate: json['work_date'] == null ? null : _date(json['work_date']),
      messageKey: _text(json['message_key']),
      context: _map(json['context']),
    );
  }
}

final class YorksWorkforceMonthlyIssueProjection {
  YorksWorkforceMonthlyIssueProjection({
    required this.schemaVersion,
    required this.authorizationMode,
    required this.actorAuthUserId,
    required this.serverTime,
    required this.filters,
    required this.totalCount,
    required Iterable<YorksWorkforceMonthlyIssue> issues,
  }) : issues = List.unmodifiable(issues) {
    if (schemaVersion != 1 ||
        authorizationMode != 'enforced_t06' ||
        totalCount < this.issues.length) {
      throw const FormatException('Invalid monthly issue projection context');
    }
    _requireUnique(this.issues.map((item) => item.id), 'monthly issue');
  }

  final int schemaVersion;
  final String authorizationMode;
  final String actorAuthUserId;
  final String serverTime;
  final YorksWorkforceMonthlyIssueFilters filters;
  final int totalCount;
  final List<YorksWorkforceMonthlyIssue> issues;

  factory YorksWorkforceMonthlyIssueProjection.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _issueProjectionKeys, 'monthly issue projection');
    return YorksWorkforceMonthlyIssueProjection(
      schemaVersion: _positiveInteger(json['schema_version']),
      authorizationMode: _text(json['authorization_mode']),
      actorAuthUserId: _uuid(json['actor_auth_user_id']),
      serverTime: _timestamp(json['server_time']),
      filters: YorksWorkforceMonthlyIssueFilters.fromRpcJson(
        _map(json['filters']),
      ),
      totalCount: _nonNegativeInteger(json['total_count']),
      issues: _list(
        json['issues'],
      ).map((value) => YorksWorkforceMonthlyIssue.fromRpcJson(_map(value))),
    );
  }
}

final class YorksWorkforceMonthlyDay {
  YorksWorkforceMonthlyDay({
    required this.workDate,
    required this.isFuture,
    required this.isRequired,
    required this.dayType,
    required this.dailyStatus,
    required Map<String, dynamic> assignment,
    required Map<String, dynamic>? schedule,
    required Map<String, dynamic>? attendance,
    required Map<String, dynamic>? allocation,
    required this.scheduledMinutes,
    required this.regularMinutes,
    required this.overtimeMinutes,
    required this.allocationMinutes,
    required this.blockingIssueCount,
    required this.warningIssueCount,
    required Iterable<YorksWorkforceMonthlyDayIssue> issues,
  }) : assignment = Map.unmodifiable(assignment),
       schedule = schedule == null ? null : Map.unmodifiable(schedule),
       attendance = attendance == null ? null : Map.unmodifiable(attendance),
       allocation = allocation == null ? null : Map.unmodifiable(allocation),
       issues = List.unmodifiable(issues) {
    final blocking = this.issues
        .where(
          (item) =>
              item.severity == YorksWorkforceMonthlyIssueSeverity.blocking,
        )
        .length;
    final warnings = this.issues
        .where(
          (item) => item.severity == YorksWorkforceMonthlyIssueSeverity.warning,
        )
        .length;
    if (blocking != blockingIssueCount || warnings != warningIssueCount) {
      throw const FormatException('Monthly day issues do not reconcile');
    }
    if (regularMinutes + overtimeMinutes > 1440 ||
        (isFuture
            ? dailyStatus != YorksWorkforceMonthlyDailyStatus.future ||
                  isRequired
            : dailyStatus == YorksWorkforceMonthlyDailyStatus.future)) {
      throw const FormatException('Invalid monthly day state');
    }
    _requireUnique(this.issues.map((item) => item.id), 'monthly day issue');
  }

  final String workDate;
  final bool isFuture;
  final bool isRequired;
  final String? dayType;
  final YorksWorkforceMonthlyDailyStatus dailyStatus;
  final Map<String, dynamic> assignment;
  final Map<String, dynamic>? schedule;
  final Map<String, dynamic>? attendance;
  final Map<String, dynamic>? allocation;
  final int scheduledMinutes;
  final int regularMinutes;
  final int overtimeMinutes;
  final int allocationMinutes;
  final int blockingIssueCount;
  final int warningIssueCount;
  final List<YorksWorkforceMonthlyDayIssue> issues;

  factory YorksWorkforceMonthlyDay.fromRpcJson(Map<String, dynamic> json) {
    _requireExactKeys(json, _dayKeys, 'monthly day');
    return YorksWorkforceMonthlyDay(
      workDate: _date(json['work_date']),
      isFuture: _boolean(json['is_future']),
      isRequired: _boolean(json['is_required']),
      dayType: _nullableText(json['day_type']),
      dailyStatus: YorksWorkforceMonthlyDailyStatus.fromWire(
        json['daily_status'],
      ),
      assignment: _strictMap(
        json['assignment'],
        _assignmentSnapshotKeys,
        'monthly assignment snapshot',
      ),
      schedule: json['schedule'] == null
          ? null
          : _scheduleSnapshot(json['schedule']),
      attendance: json['attendance'] == null
          ? null
          : _strictMap(
              json['attendance'],
              _attendanceSnapshotKeys,
              'monthly attendance snapshot',
            ),
      allocation: json['allocation'] == null
          ? null
          : _allocationSnapshot(json['allocation']),
      scheduledMinutes: _boundedMinutes(json['scheduled_minutes']),
      regularMinutes: _boundedMinutes(json['regular_minutes']),
      overtimeMinutes: _boundedMinutes(json['overtime_minutes']),
      allocationMinutes: _boundedMinutes(json['allocation_minutes']),
      blockingIssueCount: _nonNegativeInteger(json['blocking_issue_count']),
      warningIssueCount: _nonNegativeInteger(json['warning_issue_count']),
      issues: _list(
        json['issues'],
      ).map((value) => YorksWorkforceMonthlyDayIssue.fromRpcJson(_map(value))),
    );
  }
}

final class YorksWorkforceMonthlyDayIssue {
  YorksWorkforceMonthlyDayIssue({
    required this.id,
    required this.severity,
    required this.issueCode,
    required this.messageKey,
    required Map<String, dynamic> context,
  }) : context = Map.unmodifiable(context);

  final String id;
  final YorksWorkforceMonthlyIssueSeverity severity;
  final String issueCode;
  final String messageKey;
  final Map<String, dynamic> context;

  factory YorksWorkforceMonthlyDayIssue.fromRpcJson(Map<String, dynamic> json) {
    _requireExactKeys(json, _dayIssueKeys, 'monthly day issue');
    return YorksWorkforceMonthlyDayIssue(
      id: _uuid(json['issue_id']),
      severity: YorksWorkforceMonthlyIssueSeverity.fromWire(json['severity']),
      issueCode: _text(json['issue_code']),
      messageKey: _text(json['message_key']),
      context: _map(json['context']),
    );
  }
}

final class YorksWorkforceMonthlyWorkerDetail {
  YorksWorkforceMonthlyWorkerDetail({
    required this.schemaVersion,
    required this.authorizationMode,
    required this.actorAuthUserId,
    required this.serverTime,
    required this.period,
    required this.validationRun,
    required this.worker,
    required Iterable<YorksWorkforceMonthlyDay> days,
  }) : days = List.unmodifiable(days) {
    if (schemaVersion != 1 ||
        authorizationMode != 'enforced_t06' ||
        validationRun.isCurrent !=
            (validationRun.id == period.currentValidationRunId) ||
        days.length > 31 ||
        days.any(
          (day) => !day.workDate.startsWith(period.periodMonth.substring(0, 7)),
        )) {
      throw const FormatException('Invalid monthly detail context');
    }
    _requireUnique(days.map((item) => item.workDate), 'monthly worker date');
  }

  final int schemaVersion;
  final String authorizationMode;
  final String actorAuthUserId;
  final String serverTime;
  final YorksWorkforceMonthlyPeriod period;
  final YorksWorkforceMonthlyValidationRun validationRun;
  final YorksWorkforceMonthlyWorkerSummary worker;
  final List<YorksWorkforceMonthlyDay> days;

  factory YorksWorkforceMonthlyWorkerDetail.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _detailProjectionKeys, 'monthly worker detail');
    return YorksWorkforceMonthlyWorkerDetail(
      schemaVersion: _positiveInteger(json['schema_version']),
      authorizationMode: _text(json['authorization_mode']),
      actorAuthUserId: _uuid(json['actor_auth_user_id']),
      serverTime: _timestamp(json['server_time']),
      period: YorksWorkforceMonthlyPeriod.fromRpcJson(_map(json['period'])),
      validationRun: YorksWorkforceMonthlyValidationRun.fromRpcJson(
        _map(json['validation_run']),
      ),
      worker: YorksWorkforceMonthlyWorkerSummary.fromRpcJson(
        _map(json['worker']),
      ),
      days: _list(
        json['days'],
      ).map((value) => YorksWorkforceMonthlyDay.fromRpcJson(_map(value))),
    );
  }
}

final class YorksWorkforceMonthlyValidationRun {
  const YorksWorkforceMonthlyValidationRun({
    required this.id,
    required this.number,
    required this.status,
    required this.sourceFingerprint,
    required this.isCurrent,
    required this.validatedAt,
    required this.validatedByAuthUserId,
  });

  final String id;
  final int number;
  final YorksWorkforceMonthlyPeriodStatus status;
  final String sourceFingerprint;
  final bool isCurrent;
  final String validatedAt;
  final String validatedByAuthUserId;

  factory YorksWorkforceMonthlyValidationRun.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _validationRunKeys, 'monthly validation run');
    return YorksWorkforceMonthlyValidationRun(
      id: _uuid(json['validation_run_id']),
      number: _positiveInteger(json['validation_number']),
      status: YorksWorkforceMonthlyPeriodStatus.fromWire(
        json['validation_status'],
      ),
      sourceFingerprint: _fingerprint(json['source_fingerprint']),
      isCurrent: _boolean(json['is_current_run']),
      validatedAt: _timestamp(json['validated_at']),
      validatedByAuthUserId: _uuid(json['validated_by_auth_user_id']),
    );
  }
}

final class YorksWorkforceMonthlyValidationResult {
  const YorksWorkforceMonthlyValidationResult({required this.projection});

  final YorksWorkforceMonthlyProjection projection;

  factory YorksWorkforceMonthlyValidationResult.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final projection = YorksWorkforceMonthlyProjection.fromRpcJson(json);
    if (projection.period == null || projection.summary == null) {
      throw const FormatException('Validation result has no monthly period');
    }
    return YorksWorkforceMonthlyValidationResult(projection: projection);
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) throw const FormatException('Expected object');
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic> _strictMap(Object? value, Set<String> keys, String label) {
  final decoded = _map(value);
  _requireExactKeys(decoded, keys, label);
  return decoded;
}

Map<String, dynamic> _scheduleSnapshot(Object? value) {
  final decoded = _map(value);
  if (_hasExactKeys(decoded, _scheduleSnapshotKeys)) return decoded;
  if (_hasExactKeys(decoded, {..._scheduleSnapshotKeys, 'source'}) &&
      decoded['source'] == 'attendance_snapshot') {
    return decoded;
  }
  throw const FormatException('Invalid monthly schedule snapshot keys');
}

Map<String, dynamic> _allocationSnapshot(Object? value) {
  final decoded = _map(value);
  final restricted = _boolean(decoded['targets_restricted']);
  _requireExactKeys(
    decoded,
    restricted ? _restrictedAllocationKeys : _visibleAllocationKeys,
    'monthly allocation snapshot',
  );
  if (restricted) {
    const hiddenKeys = {
      'allocation_set_id',
      'allocation_set_version',
      'allocation_state',
      'allocation_revision_id',
      'allocation_revision_number',
      'attendance_record_version_basis',
      'targets',
    };
    if (hiddenKeys.any((key) => decoded[key] != null)) {
      throw const FormatException('Restricted allocation leaked a target');
    }
  } else if (decoded['targets'] is! List) {
    throw const FormatException('Visible allocation has no targets');
  }
  return decoded;
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

bool _boolean(Object? value) {
  if (value is! bool) throw const FormatException('Expected boolean');
  return value;
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  throw const FormatException('Expected integer');
}

int _nonNegativeInteger(Object? value) {
  final parsed = _integer(value);
  if (parsed < 0) throw const FormatException('Expected non-negative integer');
  return parsed;
}

int _positiveInteger(Object? value) {
  final parsed = _integer(value);
  if (parsed < 1) throw const FormatException('Expected positive integer');
  return parsed;
}

int _boundedMinutes(Object? value) {
  final parsed = _nonNegativeInteger(value);
  if (parsed > 1440) throw const FormatException('Invalid minute total');
  return parsed;
}

String _fingerprint(Object? value) {
  final text = _text(value);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(text)) {
    throw const FormatException('Expected source fingerprint');
  }
  return text;
}

String _date(Object? value) {
  final text = _text(value);
  if (!_isDate(text)) throw const FormatException('Expected date');
  return text;
}

String _firstOfMonth(Object? value) {
  final text = _date(value);
  if (!_isFirstOfMonth(text)) {
    throw const FormatException('Expected first day of month');
  }
  return text;
}

String _timestamp(Object? value) {
  final text = _text(value);
  if (!RegExp(r'(?:[zZ]|[+-](?:0\d|1[0-4]):[0-5]\d)$').hasMatch(text) ||
      DateTime.tryParse(text) == null) {
    throw const FormatException('Expected timestamp');
  }
  return text;
}

String? _nullableTrimmed(String? value) {
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

bool _isFirstOfMonth(String value) => _isDate(value) && value.endsWith('-01');

bool _isUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
).hasMatch(value);

void _requireUnique(Iterable<String> values, String label) {
  final list = values.toList(growable: false);
  if (list.toSet().length != list.length) {
    throw FormatException('Duplicate $label');
  }
}

void _requireExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
  String label,
) {
  final actual = json.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw FormatException('Invalid $label keys');
  }
}

bool _hasExactKeys(Map<String, dynamic> json, Set<String> expected) {
  final actual = json.keys.toSet();
  return actual.length == expected.length && actual.containsAll(expected);
}

const _monthlyFilterKeys = {
  'team_id',
  'period_month',
  'query',
  'issue_severity',
  'issue_code',
  'worker_limit',
  'worker_offset',
};
const _teamFilterKeys = {'period_month', 'query', 'limit', 'offset'};
const _teamKeys = {
  'team_id',
  'team_code',
  'team_name',
  'department',
  'period_exists',
  'period_id',
  'stored_status',
  'record_version',
  'current_validation_number',
};
const _teamProjectionKeys = {
  'schema_version',
  'authorization_mode',
  'actor_auth_user_id',
  'server_time',
  'filters',
  'total_count',
  'teams',
};
const _monthlyCapabilityKeys = {'can_view', 'can_validate'};
const _periodKeys = {
  'period_id',
  'team_id',
  'team_name',
  'period_month',
  'stored_status',
  'effective_status',
  'is_stale',
  'record_version',
  'current_validation_run_id',
  'current_validation_number',
  'source_fingerprint',
  'current_source_fingerprint',
  'validated_at',
  'validated_by_auth_user_id',
};
const _summaryKeys = {
  'worker_count',
  'date_count',
  'scheduled_day_count',
  'future_day_count',
  'present_day_count',
  'absent_day_count',
  'leave_day_count',
  'weekly_off_day_count',
  'public_holiday_day_count',
  'site_closure_day_count',
  'missing_day_count',
  'regular_minutes',
  'overtime_minutes',
  'allocation_minutes',
  'blocking_issue_count',
  'warning_issue_count',
  'project_count',
  'location_count',
};
const _issueCountKeys = {'severity', 'issue_code', 'count'};
const _workerSummaryKeys = {
  'worker_id',
  'worker_number',
  'worker_name',
  'trade_name',
  'employer_name',
  'first_applicable_date',
  'last_applicable_date',
  'supervisors',
  'projects',
  'locations',
  'scheduled_day_count',
  'present_day_count',
  'absent_day_count',
  'leave_day_count',
  'weekly_off_day_count',
  'public_holiday_day_count',
  'regular_minutes',
  'overtime_minutes',
  'missing_day_count',
  'blocking_issue_count',
  'warning_issue_count',
  'status',
};
const _supervisorKeys = {'supervisor_auth_user_id', 'supervisor_name'};
const _projectKeys = {
  'project_id',
  'project_ref',
  'project_name',
  'project_scope_id',
  'project_scope_name',
};
const _locationKeys = {'internal_location_id', 'internal_location_name'};
const _projectionKeys = {
  'schema_version',
  'authorization_mode',
  'actor_auth_user_id',
  'server_time',
  'filters',
  'capabilities',
  'period',
  'summary',
  'issue_counts',
  'total_count',
  'workers',
};
const _issueFilterKeys = {
  'period_id',
  'validation_run_id',
  'severity',
  'issue_code',
  'worker_id',
  'limit',
  'offset',
};
const _issueKeys = {
  'issue_id',
  'severity',
  'issue_code',
  'worker_id',
  'worker_number',
  'worker_name',
  'work_date',
  'message_key',
  'context',
};
const _issueProjectionKeys = {
  'schema_version',
  'authorization_mode',
  'actor_auth_user_id',
  'server_time',
  'filters',
  'total_count',
  'issues',
};
const _dayIssueKeys = {
  'issue_id',
  'severity',
  'issue_code',
  'message_key',
  'context',
};
const _dayKeys = {
  'work_date',
  'is_future',
  'is_required',
  'day_type',
  'daily_status',
  'assignment',
  'schedule',
  'attendance',
  'allocation',
  'scheduled_minutes',
  'regular_minutes',
  'overtime_minutes',
  'allocation_minutes',
  'blocking_issue_count',
  'warning_issue_count',
  'issues',
};
const _assignmentSnapshotKeys = {
  'assignment_id',
  'assignment_kind',
  'team_id',
  'team_name',
  'supervisor_auth_user_id',
  'supervisor_name',
  'project_id',
  'project_ref',
  'project_name',
  'project_scope_id',
  'project_scope_name',
  'internal_location_id',
  'internal_location_name',
  'valid_from',
  'valid_to',
  'record_version',
  'source',
};
const _scheduleSnapshotKeys = {
  'team_schedule_link_id',
  'team_schedule_record_version',
  'calendar_id',
  'calendar_code',
  'calendar_name',
  'calendar_timezone',
  'calendar_record_version',
  'calendar_date_override_id',
  'calendar_date_override_version',
  'calendar_override_kind',
  'calendar_exception_name',
  'day_type_source',
  'iso_weekday',
  'day_type',
  'scheduled_minutes',
  'break_minutes',
  'shift_template_id',
  'shift_code',
  'shift_name',
  'shift_kind',
  'shift_start_time',
  'shift_end_time',
  'shift_scheduled_minutes',
  'shift_break_minutes',
  'shift_crosses_midnight',
  'shift_work_date_basis',
  'shift_record_version',
};
const _attendanceSnapshotKeys = {
  'attendance_day_id',
  'record_version',
  'attendance_status',
  'regular_minutes',
  'overtime_minutes',
  'overtime_reason',
  'reason',
  'created_by_auth_user_id',
  'created_at',
  'updated_by_auth_user_id',
  'updated_at',
};
const _restrictedAllocationKeys = {
  'allocation_set_id',
  'allocation_set_version',
  'allocation_state',
  'allocation_revision_id',
  'allocation_revision_number',
  'attendance_record_version_basis',
  'total_regular_minutes',
  'total_overtime_minutes',
  'line_count',
  'targets_restricted',
  'targets',
};
const _visibleAllocationKeys = {
  'allocation_set_id',
  'allocation_set_version',
  'allocation_state',
  'allocation_revision_id',
  'allocation_revision_number',
  'attendance_record_version_basis',
  'total_regular_minutes',
  'total_overtime_minutes',
  'line_count',
  'has_interval_overlap',
  'has_missing_activity',
  'has_off_assignment_target',
  'has_invalid_target',
  'targets_restricted',
  'targets',
};
const _detailProjectionKeys = {
  'schema_version',
  'authorization_mode',
  'actor_auth_user_id',
  'server_time',
  'period',
  'validation_run',
  'worker',
  'days',
};
const _validationRunKeys = {
  'validation_run_id',
  'validation_number',
  'validation_status',
  'source_fingerprint',
  'is_current_run',
  'validated_at',
  'validated_by_auth_user_id',
};
