import 'workforce_attendance_models.dart';
import 'workforce_timesheet_models.dart';

const yorksWorkforceRosterMaxPageSize = 500;
const yorksWorkforceRosterCopyPageSize = 100;
const yorksWorkforceRosterMaxCommandRows = 500;

enum YorksWorkforceRosterAllocationAction {
  preserve('preserve'),
  replace('replace'),
  withdraw('withdraw');

  const YorksWorkforceRosterAllocationAction(this.wireValue);
  final String wireValue;
}

final class YorksWorkforceRosterFilters {
  const YorksWorkforceRosterFilters({
    this.teamId,
    this.projectId,
    this.projectScopeId,
    this.internalLocationId,
    this.query = '',
    this.limit = 100,
    this.offset = 0,
  });

  final String? teamId;
  final String? projectId;
  final String? projectScopeId;
  final String? internalLocationId;
  final String query;
  final int limit;
  final int offset;

  bool get isValid =>
      _nullableUuidIsValid(teamId) &&
      _nullableUuidIsValid(projectId) &&
      _nullableUuidIsValid(projectScopeId) &&
      _nullableUuidIsValid(internalLocationId) &&
      (projectScopeId == null || projectId != null) &&
      query.trim().length <= 160 &&
      limit >= 1 &&
      limit <= yorksWorkforceRosterMaxPageSize &&
      offset >= 0;

  YorksWorkforceRosterFilters copyWith({
    String? teamId,
    bool clearTeam = false,
    String? projectId,
    bool clearProject = false,
    String? projectScopeId,
    bool clearProjectScope = false,
    String? internalLocationId,
    bool clearInternalLocation = false,
    String? query,
    int? limit,
    int? offset,
  }) => YorksWorkforceRosterFilters(
    teamId: clearTeam ? null : teamId ?? this.teamId,
    projectId: clearProject ? null : projectId ?? this.projectId,
    projectScopeId: clearProjectScope
        ? null
        : projectScopeId ?? this.projectScopeId,
    internalLocationId: clearInternalLocation
        ? null
        : internalLocationId ?? this.internalLocationId,
    query: query ?? this.query,
    limit: limit ?? this.limit,
    offset: offset ?? this.offset,
  );

  Map<String, Object?> toRpcParameters(String workDate) => {
    'p_work_date': workDate.trim(),
    'p_team_id': _nullableTrimmed(teamId),
    'p_project_id': _nullableTrimmed(projectId),
    'p_project_scope_id': _nullableTrimmed(projectScopeId),
    'p_internal_location_id': _nullableTrimmed(internalLocationId),
    'p_query': _nullableTrimmed(query),
    'p_limit': limit,
    'p_offset': offset,
  };
}

final class YorksWorkforceRosterCapabilities {
  const YorksWorkforceRosterCapabilities({
    required this.canView,
    required this.canMaintainAttendance,
    required this.canMaintainTimesheet,
  });

  final bool canView;
  final bool canMaintainAttendance;
  final bool canMaintainTimesheet;

  factory YorksWorkforceRosterCapabilities.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _capabilityKeys, 'roster capabilities');
    final canView = _boolean(json['can_view']);
    if (!canView) {
      throw const FormatException('Roster projection cannot deny its own read');
    }
    return YorksWorkforceRosterCapabilities(
      canView: canView,
      canMaintainAttendance: _boolean(json['can_maintain_attendance']),
      canMaintainTimesheet: _boolean(json['can_maintain_timesheet']),
    );
  }
}

final class YorksWorkforceRosterTeamSelector {
  const YorksWorkforceRosterTeamSelector({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory YorksWorkforceRosterTeamSelector.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _teamSelectorKeys, 'team selector');
    return YorksWorkforceRosterTeamSelector(
      id: _uuid(json['team_id']),
      name: _text(json['team_name']),
    );
  }
}

final class YorksWorkforceRosterProjectSelector {
  const YorksWorkforceRosterProjectSelector({
    required this.id,
    required this.reference,
    required this.name,
  });

  final String id;
  final String reference;
  final String name;

  factory YorksWorkforceRosterProjectSelector.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _projectSelectorKeys, 'project selector');
    return YorksWorkforceRosterProjectSelector(
      id: _uuid(json['project_id']),
      reference: _text(json['project_ref']),
      name: _text(json['project_name']),
    );
  }
}

final class YorksWorkforceRosterScopeSelector {
  const YorksWorkforceRosterScopeSelector({
    required this.projectId,
    required this.id,
    required this.name,
  });

  final String projectId;
  final String id;
  final String name;

  factory YorksWorkforceRosterScopeSelector.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _scopeSelectorKeys, 'project scope selector');
    return YorksWorkforceRosterScopeSelector(
      projectId: _uuid(json['project_id']),
      id: _uuid(json['project_scope_id']),
      name: _text(json['project_scope_name']),
    );
  }
}

final class YorksWorkforceRosterLocationSelector {
  const YorksWorkforceRosterLocationSelector({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory YorksWorkforceRosterLocationSelector.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _locationSelectorKeys, 'location selector');
    return YorksWorkforceRosterLocationSelector(
      id: _uuid(json['internal_location_id']),
      name: _text(json['internal_location_name']),
    );
  }
}

final class YorksWorkforceRosterSelectors {
  YorksWorkforceRosterSelectors({
    required Iterable<YorksWorkforceRosterTeamSelector> teams,
    required Iterable<YorksWorkforceRosterProjectSelector> projects,
    required Iterable<YorksWorkforceRosterScopeSelector> projectScopes,
    required Iterable<YorksWorkforceRosterLocationSelector> internalLocations,
  }) : teams = List.unmodifiable(teams),
       projects = List.unmodifiable(projects),
       projectScopes = List.unmodifiable(projectScopes),
       internalLocations = List.unmodifiable(internalLocations) {
    _requireUnique(this.teams.map((item) => item.id), 'team selector');
    _requireUnique(this.projects.map((item) => item.id), 'project selector');
    _requireUnique(
      this.projectScopes.map((item) => item.id),
      'project scope selector',
    );
    _requireUnique(
      this.internalLocations.map((item) => item.id),
      'location selector',
    );
    final projectIds = this.projects.map((item) => item.id).toSet();
    if (this.projectScopes.any(
      (scope) => !projectIds.contains(scope.projectId),
    )) {
      throw const FormatException('Scope selector has no project');
    }
  }

  final List<YorksWorkforceRosterTeamSelector> teams;
  final List<YorksWorkforceRosterProjectSelector> projects;
  final List<YorksWorkforceRosterScopeSelector> projectScopes;
  final List<YorksWorkforceRosterLocationSelector> internalLocations;

  factory YorksWorkforceRosterSelectors.fromRpcJson(Map<String, dynamic> json) {
    _requireExactKeys(json, _selectorKeys, 'roster selectors');
    return YorksWorkforceRosterSelectors(
      teams: _list(json['teams']).map(
        (value) => YorksWorkforceRosterTeamSelector.fromRpcJson(_map(value)),
      ),
      projects: _list(json['projects']).map(
        (value) => YorksWorkforceRosterProjectSelector.fromRpcJson(_map(value)),
      ),
      projectScopes: _list(json['project_scopes']).map(
        (value) => YorksWorkforceRosterScopeSelector.fromRpcJson(_map(value)),
      ),
      internalLocations: _list(json['internal_locations']).map(
        (value) =>
            YorksWorkforceRosterLocationSelector.fromRpcJson(_map(value)),
      ),
    );
  }
}

final class YorksWorkforceRosterAllocationScopeTarget {
  const YorksWorkforceRosterAllocationScopeTarget({
    required this.projectId,
    required this.id,
    required this.kind,
    required this.code,
    required this.name,
  });

  final String projectId;
  final String id;
  final String kind;
  final String code;
  final String name;

  factory YorksWorkforceRosterAllocationScopeTarget.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(
      json,
      _allocationScopeTargetKeys,
      'allocation project scope target',
    );
    final kind = _text(json['project_scope_kind']);
    if (kind != 'common' && kind != 'building') {
      throw const FormatException('Invalid allocation project scope kind');
    }
    return YorksWorkforceRosterAllocationScopeTarget(
      projectId: _uuid(json['project_id']),
      id: _uuid(json['project_scope_id']),
      kind: kind,
      code: _text(json['project_scope_code']),
      name: _text(json['project_scope_name']),
    );
  }
}

final class YorksWorkforceRosterAllocationLocationTarget {
  const YorksWorkforceRosterAllocationLocationTarget({
    required this.id,
    required this.code,
    required this.name,
    required this.departmentCostCentre,
  });

  final String id;
  final String code;
  final String name;
  final String? departmentCostCentre;

  factory YorksWorkforceRosterAllocationLocationTarget.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(
      json,
      _allocationLocationTargetKeys,
      'allocation internal location target',
    );
    return YorksWorkforceRosterAllocationLocationTarget(
      id: _uuid(json['internal_location_id']),
      code: _text(json['location_code']),
      name: _text(json['location_name']),
      departmentCostCentre: _nullableText(json['department_cost_centre']),
    );
  }
}

final class YorksWorkforceRosterAllocationTargets {
  YorksWorkforceRosterAllocationTargets({
    required Iterable<YorksWorkforceRosterProjectSelector> projects,
    required Iterable<YorksWorkforceRosterAllocationScopeTarget> projectScopes,
    required Iterable<YorksWorkforceRosterAllocationLocationTarget>
    internalLocations,
  }) : projects = List.unmodifiable(projects),
       projectScopes = List.unmodifiable(projectScopes),
       internalLocations = List.unmodifiable(internalLocations) {
    _requireUnique(this.projects.map((item) => item.id), 'allocation project');
    _requireUnique(
      this.projectScopes.map((item) => item.id),
      'allocation project scope',
    );
    _requireUnique(
      this.internalLocations.map((item) => item.id),
      'allocation internal location',
    );
    final projectIds = this.projects.map((item) => item.id).toSet();
    if (this.projectScopes.any(
      (scope) => !projectIds.contains(scope.projectId),
    )) {
      throw const FormatException('Allocation scope target has no project');
    }
  }

  final List<YorksWorkforceRosterProjectSelector> projects;
  final List<YorksWorkforceRosterAllocationScopeTarget> projectScopes;
  final List<YorksWorkforceRosterAllocationLocationTarget> internalLocations;

  factory YorksWorkforceRosterAllocationTargets.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _allocationTargetKeys, 'allocation targets');
    return YorksWorkforceRosterAllocationTargets(
      projects: _list(json['projects']).map(
        (value) => YorksWorkforceRosterProjectSelector.fromRpcJson(_map(value)),
      ),
      projectScopes: _list(json['project_scopes']).map(
        (value) =>
            YorksWorkforceRosterAllocationScopeTarget.fromRpcJson(_map(value)),
      ),
      internalLocations: _list(json['internal_locations']).map(
        (value) => YorksWorkforceRosterAllocationLocationTarget.fromRpcJson(
          _map(value),
        ),
      ),
    );
  }
}

final class YorksWorkforceRosterScheduleSuggestion {
  const YorksWorkforceRosterScheduleSuggestion({
    required this.schedule,
    required this.suggestedStatus,
    required this.suggestedRegularMinutes,
    required this.suggestedOvertimeMinutes,
    required this.requiresConfirmation,
  });

  final YorksWorkforceAttendanceScheduleSnapshot schedule;
  final YorksWorkforceAttendanceStatus suggestedStatus;
  final int suggestedRegularMinutes;
  final int suggestedOvertimeMinutes;
  final bool requiresConfirmation;

  factory YorksWorkforceRosterScheduleSuggestion.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _scheduleSuggestionKeys, 'schedule suggestion');
    if (_text(json['source']) != 'schedule_only') {
      throw const FormatException('Invalid roster suggestion provenance');
    }
    final status = YorksWorkforceAttendanceStatus.fromWire(
      json['suggested_attendance_status'],
    );
    if (status != YorksWorkforceAttendanceStatus.present &&
        status != YorksWorkforceAttendanceStatus.notEntered) {
      throw const FormatException('Invalid suggested attendance status');
    }
    final regular = _nonNegativeInteger(json['suggested_regular_minutes']);
    final overtime = _nonNegativeInteger(json['suggested_overtime_minutes']);
    final schedule = YorksWorkforceAttendanceScheduleSnapshot.fromRpcJson(json);
    if (overtime != 0 ||
        (status == YorksWorkforceAttendanceStatus.present
            ? regular <= 0 || regular != schedule.scheduledMinutes
            : regular != 0)) {
      throw const FormatException('Invalid suggested attendance minutes');
    }
    final confirmation = _boolean(json['requires_confirmation']);
    if (!confirmation) {
      throw const FormatException('Schedule suggestion must be confirmed');
    }
    return YorksWorkforceRosterScheduleSuggestion(
      schedule: schedule,
      suggestedStatus: status,
      suggestedRegularMinutes: regular,
      suggestedOvertimeMinutes: overtime,
      requiresConfirmation: confirmation,
    );
  }
}

final class YorksWorkforceDailyRosterRow {
  const YorksWorkforceDailyRosterRow({
    required this.workerId,
    required this.workerNumber,
    required this.workerName,
    required this.designation,
    required this.tradeId,
    required this.tradeName,
    required this.department,
    required this.employerCompany,
    required this.workerType,
    required this.assignment,
    required this.scheduleSuggestion,
    required this.attendance,
    required this.allocationSet,
    required this.hasActiveAllocationLock,
    required this.allocationDetailsRestricted,
    required this.canMaintainAttendance,
    required this.canMaintainTimesheet,
  });

  final String workerId;
  final String workerNumber;
  final String workerName;
  final String? designation;
  final String? tradeId;
  final String? tradeName;
  final String? department;
  final String employerCompany;
  final String workerType;
  final YorksWorkforceAttendanceAssignmentSnapshot assignment;
  final YorksWorkforceRosterScheduleSuggestion scheduleSuggestion;
  final YorksWorkforceAttendanceDay? attendance;
  final YorksWorkforceTimesheetDay? allocationSet;
  final bool hasActiveAllocationLock;
  final bool allocationDetailsRestricted;
  final bool canMaintainAttendance;
  final bool canMaintainTimesheet;

  bool get isAttendanceEditable =>
      canMaintainAttendance && !hasActiveAllocationLock;

  factory YorksWorkforceDailyRosterRow.fromRpcJson(
    Map<String, dynamic> json,
    String projectionDate,
  ) {
    _requireExactKeys(json, _rosterRowKeys, 'roster row');
    final workerId = _uuid(json['worker_id']);
    final attendance = json['attendance'] == null
        ? null
        : YorksWorkforceAttendanceDay.fromRpcJson(_map(json['attendance']));
    final allocationSet = json['allocation_set'] == null
        ? null
        : YorksWorkforceTimesheetDay.fromRpcJson(_map(json['allocation_set']));
    if ((attendance != null &&
            (attendance.workerId != workerId ||
                attendance.workDate != projectionDate)) ||
        (allocationSet != null &&
            (allocationSet.workerId != workerId ||
                allocationSet.workDate != projectionDate)) ||
        (allocationSet != null &&
            attendance?.id != allocationSet.attendanceDayId)) {
      throw const FormatException('Roster row context mismatch');
    }
    final activeLock = _boolean(json['has_active_allocation_lock']);
    final restricted = _boolean(json['allocation_details_restricted']);
    final canMaintainTimesheet = _boolean(json['can_maintain_timesheet']);
    final visibleActiveAllocation = allocationSet?.state == 'active';
    if ((restricted
            ? allocationSet != null || !activeLock
            : activeLock != visibleActiveAllocation) ||
        (restricted && canMaintainTimesheet)) {
      throw const FormatException('Invalid allocation visibility state');
    }
    const workerTypes = {
      'yorks_employee',
      'temporary_worker',
      'subcontractor_worker',
      'agency_worker',
    };
    final workerType = _text(json['worker_type']);
    if (!workerTypes.contains(workerType)) {
      throw const FormatException('Invalid roster worker type');
    }
    return YorksWorkforceDailyRosterRow(
      workerId: workerId,
      workerNumber: _text(json['worker_number']),
      workerName: _text(json['worker_name']),
      designation: _nullableText(json['designation']),
      tradeId: _nullableUuid(json['trade_id']),
      tradeName: _nullableText(json['trade_name']),
      department: _nullableText(json['department']),
      employerCompany: _text(json['employer_company']),
      workerType: workerType,
      assignment: YorksWorkforceAttendanceAssignmentSnapshot.fromRpcJson(
        _map(json['assignment']),
      ),
      scheduleSuggestion: YorksWorkforceRosterScheduleSuggestion.fromRpcJson(
        _map(json['schedule_suggestion']),
      ),
      attendance: attendance,
      allocationSet: allocationSet,
      hasActiveAllocationLock: activeLock,
      allocationDetailsRestricted: restricted,
      canMaintainAttendance: _boolean(json['can_maintain_attendance']),
      canMaintainTimesheet: canMaintainTimesheet,
    );
  }
}

final class YorksWorkforceDailyRosterProjection {
  YorksWorkforceDailyRosterProjection({
    required this.schemaVersion,
    required this.authorizationMode,
    required this.actorAuthUserId,
    required this.workDate,
    required this.isFuture,
    required this.serverTime,
    required this.filters,
    required this.capabilities,
    required this.selectors,
    required this.allocationTargets,
    required this.totalCount,
    required Iterable<YorksWorkforceDailyRosterRow> rows,
  }) : rows = List.unmodifiable(rows) {
    if (schemaVersion != 1 || authorizationMode != 'enforced_t05') {
      throw const FormatException('Unsupported Workforce roster schema');
    }
    if (totalCount < this.rows.length) {
      throw const FormatException('Invalid roster total count');
    }
    _requireUnique(this.rows.map((row) => row.workerId), 'roster worker');
    for (final row in this.rows) {
      final assignment = row.assignment;
      if (!selectors.teams.any((item) => item.id == assignment.teamId) ||
          (assignment.projectId != null &&
              !selectors.projects.any(
                (item) => item.id == assignment.projectId,
              )) ||
          (assignment.projectScopeId != null &&
              !selectors.projectScopes.any(
                (item) =>
                    item.id == assignment.projectScopeId &&
                    item.projectId == assignment.projectId,
              )) ||
          (assignment.internalLocationId != null &&
              !selectors.internalLocations.any(
                (item) => item.id == assignment.internalLocationId,
              ))) {
        throw const FormatException('Roster row has no read selector');
      }
    }
    if (isFuture &&
        (capabilities.canMaintainAttendance ||
            capabilities.canMaintainTimesheet ||
            this.rows.any(
              (row) => row.canMaintainAttendance || row.canMaintainTimesheet,
            ))) {
      throw const FormatException('Future roster cannot be mutable');
    }
  }

  final int schemaVersion;
  final String authorizationMode;
  final String actorAuthUserId;
  final String workDate;
  final bool isFuture;
  final String serverTime;
  final YorksWorkforceRosterFilters filters;
  final YorksWorkforceRosterCapabilities capabilities;
  final YorksWorkforceRosterSelectors selectors;
  final YorksWorkforceRosterAllocationTargets allocationTargets;
  final int totalCount;
  final List<YorksWorkforceDailyRosterRow> rows;

  factory YorksWorkforceDailyRosterProjection.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _rosterProjectionKeys, 'roster projection');
    final date = _date(json['work_date']);
    final filters = _map(json['filters']);
    _requireExactKeys(filters, _filterKeys, 'roster filters');
    final decodedFilters = YorksWorkforceRosterFilters(
      teamId: _nullableUuid(filters['team_id']),
      projectId: _nullableUuid(filters['project_id']),
      projectScopeId: _nullableUuid(filters['project_scope_id']),
      internalLocationId: _nullableUuid(filters['internal_location_id']),
      query: _nullableText(filters['query']) ?? '',
      limit: _positiveInteger(filters['limit']),
      offset: _nonNegativeInteger(filters['offset']),
    );
    if (!decodedFilters.isValid) {
      throw const FormatException('Invalid roster filter projection');
    }
    return YorksWorkforceDailyRosterProjection(
      schemaVersion: _positiveInteger(json['schema_version']),
      authorizationMode: _text(json['authorization_mode']),
      actorAuthUserId: _uuid(json['actor_auth_user_id']),
      workDate: date,
      isFuture: _boolean(json['is_future']),
      serverTime: _timestamp(json['server_time']),
      filters: decodedFilters,
      capabilities: YorksWorkforceRosterCapabilities.fromRpcJson(
        _map(json['capabilities']),
      ),
      selectors: YorksWorkforceRosterSelectors.fromRpcJson(
        _map(json['selectors']),
      ),
      allocationTargets: YorksWorkforceRosterAllocationTargets.fromRpcJson(
        _map(json['allocation_targets']),
      ),
      totalCount: _nonNegativeInteger(json['total_count']),
      rows: _list(json['rows']).map(
        (value) => YorksWorkforceDailyRosterRow.fromRpcJson(_map(value), date),
      ),
    );
  }
}

final class YorksWorkforceDailyRosterSaveRow {
  YorksWorkforceDailyRosterSaveRow({
    required this.workerId,
    required this.expectedAttendanceVersion,
    required this.status,
    required this.regularMinutes,
    required this.overtimeMinutes,
    required this.overtimeReason,
    required this.reason,
    required this.allocationAction,
    required this.expectedAllocationVersion,
    Iterable<YorksWorkforceAllocationInput>? allocations,
  }) : allocations = allocations == null
           ? null
           : List.unmodifiable(allocations);

  final String workerId;
  final int? expectedAttendanceVersion;
  final YorksWorkforceAttendanceStatus status;
  final int regularMinutes;
  final int overtimeMinutes;
  final String? overtimeReason;
  final String reason;
  final YorksWorkforceRosterAllocationAction allocationAction;
  final int? expectedAllocationVersion;
  final List<YorksWorkforceAllocationInput>? allocations;

  bool get isValid {
    final total = regularMinutes + overtimeMinutes;
    final allocationRows =
        allocations ?? const <YorksWorkforceAllocationInput>[];
    final base =
        _isUuid(workerId.trim()) &&
        (expectedAttendanceVersion == null || expectedAttendanceVersion! > 0) &&
        regularMinutes >= 0 &&
        overtimeMinutes >= 0 &&
        total <= 1440 &&
        (status == YorksWorkforceAttendanceStatus.present
            ? total > 0
            : total == 0) &&
        reason.trim().isNotEmpty &&
        reason.trim().length <= 2000 &&
        (_nullableTrimmed(overtimeReason)?.length ?? 0) <= 2000;
    if (!base) return false;
    return switch (allocationAction) {
      YorksWorkforceRosterAllocationAction.preserve => allocationRows.isEmpty,
      YorksWorkforceRosterAllocationAction.withdraw =>
        expectedAllocationVersion != null &&
            expectedAllocationVersion! > 0 &&
            allocationRows.isEmpty,
      YorksWorkforceRosterAllocationAction.replace =>
        allocationRows.isNotEmpty &&
            allocationRows.every((row) => row.isValid) &&
            allocationRows.fold<int>(
                  0,
                  (sum, row) => sum + row.regularMinutes,
                ) ==
                regularMinutes &&
            allocationRows.fold<int>(
                  0,
                  (sum, row) => sum + row.overtimeMinutes,
                ) ==
                overtimeMinutes,
    };
  }

  Map<String, Object?> toRpcJson() => {
    'worker_id': workerId.trim(),
    'expected_attendance_version': expectedAttendanceVersion,
    'attendance_status': status.wireValue,
    'regular_minutes': regularMinutes,
    'overtime_minutes': overtimeMinutes,
    'overtime_reason': _nullableTrimmed(overtimeReason),
    'reason': reason.trim(),
    'allocation_action': allocationAction.wireValue,
    'expected_allocation_version': expectedAllocationVersion,
    'allocations': allocations?.map((row) => row.toRpcJson()).toList(),
  };
}

final class YorksWorkforceDailyRosterSaveResultRow {
  const YorksWorkforceDailyRosterSaveResultRow({
    required this.workerId,
    required this.attendanceDayId,
    required this.attendanceRecordVersion,
    required this.attendance,
    required this.allocationSet,
    required this.allocationSetId,
    required this.allocationSetRecordVersion,
    required this.allocationState,
  });

  final String workerId;
  final String attendanceDayId;
  final int attendanceRecordVersion;
  final YorksWorkforceAttendanceDay attendance;
  final YorksWorkforceTimesheetDay? allocationSet;
  final String? allocationSetId;
  final int? allocationSetRecordVersion;
  final String? allocationState;

  factory YorksWorkforceDailyRosterSaveResultRow.fromRpcJson(
    Map<String, dynamic> json,
    String workDate,
  ) {
    _requireExactKeys(json, _rosterSaveRowKeys, 'roster save row');
    final workerId = _uuid(json['worker_id']);
    final attendanceId = _uuid(json['attendance_day_id']);
    final attendance = YorksWorkforceAttendanceDay.fromRpcJson(
      _map(json['attendance']),
    );
    final allocationSet = json['allocation_set'] == null
        ? null
        : YorksWorkforceTimesheetDay.fromRpcJson(_map(json['allocation_set']));
    final allocationId = _nullableUuid(json['allocation_set_id']);
    final allocationVersion = _nullablePositiveInteger(
      json['allocation_set_record_version'],
    );
    final allocationState = _nullableText(json['allocation_state']);
    final attendanceRecordVersion = _positiveInteger(
      json['attendance_record_version'],
    );
    if (attendance.workerId != workerId ||
        attendance.id != attendanceId ||
        attendance.workDate != workDate ||
        attendance.recordVersion != attendanceRecordVersion ||
        (allocationState != null &&
            allocationState != 'active' &&
            allocationState != 'withdrawn') ||
        ((allocationSet == null) != (allocationId == null)) ||
        ((allocationSet == null) != (allocationVersion == null)) ||
        ((allocationSet == null) != (allocationState == null)) ||
        (allocationSet != null &&
            (allocationSet.id != allocationId ||
                allocationSet.attendanceDayId != attendanceId ||
                allocationSet.workDate != workDate ||
                allocationSet.recordVersion != allocationVersion))) {
      throw const FormatException('Invalid roster save row');
    }
    return YorksWorkforceDailyRosterSaveResultRow(
      workerId: workerId,
      attendanceDayId: attendanceId,
      attendanceRecordVersion: attendanceRecordVersion,
      attendance: attendance,
      allocationSet: allocationSet,
      allocationSetId: allocationId,
      allocationSetRecordVersion: allocationVersion,
      allocationState: allocationState,
    );
  }
}

final class YorksWorkforceDailyRosterSaveResult {
  YorksWorkforceDailyRosterSaveResult({
    required this.schemaVersion,
    required this.authorizationMode,
    required this.workDate,
    required this.savedAt,
    required this.rowCount,
    required Iterable<YorksWorkforceDailyRosterSaveResultRow> rows,
  }) : rows = List.unmodifiable(rows) {
    if (schemaVersion != 1 ||
        authorizationMode != 'enforced_t05' ||
        rowCount != this.rows.length) {
      throw const FormatException('Unsupported roster save response');
    }
    _requireUnique(this.rows.map((row) => row.workerId), 'saved roster worker');
    _requireUnique(
      this.rows.map((row) => row.attendanceDayId),
      'saved attendance day',
    );
  }

  final int schemaVersion;
  final String authorizationMode;
  final String workDate;
  final String savedAt;
  final int rowCount;
  final List<YorksWorkforceDailyRosterSaveResultRow> rows;

  factory YorksWorkforceDailyRosterSaveResult.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, _rosterSaveResultKeys, 'roster save response');
    final workDate = _date(json['work_date']);
    return YorksWorkforceDailyRosterSaveResult(
      schemaVersion: _positiveInteger(json['schema_version']),
      authorizationMode: _text(json['authorization_mode']),
      workDate: workDate,
      savedAt: _timestamp(json['saved_at']),
      rowCount: _nonNegativeInteger(json['row_count']),
      rows: _list(json['rows']).map(
        (value) => YorksWorkforceDailyRosterSaveResultRow.fromRpcJson(
          _map(value),
          workDate,
        ),
      ),
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

String _uuid(Object? value) {
  final text = _text(value);
  if (!_isUuid(text)) throw const FormatException('Expected UUID');
  return text;
}

String? _nullableUuid(Object? value) => value == null ? null : _uuid(value);

bool _boolean(Object? value) {
  if (value is! bool) throw const FormatException('Expected boolean');
  return value;
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  throw const FormatException('Expected integer');
}

int _nonNegativeInteger(Object? rawValue) {
  final parsed = _integer(rawValue);
  if (parsed < 0) throw const FormatException('Expected non-negative integer');
  return parsed;
}

int _positiveInteger(Object? rawValue) {
  final parsed = _integer(rawValue);
  if (parsed < 1) throw const FormatException('Expected positive integer');
  return parsed;
}

int? _nullablePositiveInteger(Object? value) =>
    value == null ? null : _positiveInteger(value);

String _date(Object? value) {
  final text = _text(value);
  if (!_isDate(text)) throw const FormatException('Expected date');
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
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}

bool _nullableUuidIsValid(String? value) {
  final text = _nullableTrimmed(value);
  return text == null || _isUuid(text);
}

bool _isDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final parsed = DateTime.tryParse(value);
  return parsed != null &&
      '${parsed.year.toString().padLeft(4, '0')}-'
              '${parsed.month.toString().padLeft(2, '0')}-'
              '${parsed.day.toString().padLeft(2, '0')}' ==
          value;
}

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

const _capabilityKeys = {
  'can_view',
  'can_maintain_attendance',
  'can_maintain_timesheet',
};
const _teamSelectorKeys = {'team_id', 'team_name'};
const _projectSelectorKeys = {'project_id', 'project_ref', 'project_name'};
const _scopeSelectorKeys = {
  'project_id',
  'project_scope_id',
  'project_scope_name',
};
const _locationSelectorKeys = {
  'internal_location_id',
  'internal_location_name',
};
const _selectorKeys = {
  'teams',
  'projects',
  'project_scopes',
  'internal_locations',
};
const _allocationTargetKeys = {
  'projects',
  'project_scopes',
  'internal_locations',
};
const _allocationScopeTargetKeys = {
  'project_id',
  'project_scope_id',
  'project_scope_kind',
  'project_scope_code',
  'project_scope_name',
};
const _allocationLocationTargetKeys = {
  'internal_location_id',
  'location_code',
  'location_name',
  'department_cost_centre',
};
const _filterKeys = {
  'team_id',
  'project_id',
  'project_scope_id',
  'internal_location_id',
  'query',
  'limit',
  'offset',
};
const _rosterProjectionKeys = {
  'schema_version',
  'authorization_mode',
  'actor_auth_user_id',
  'work_date',
  'is_future',
  'server_time',
  'filters',
  'capabilities',
  'selectors',
  'allocation_targets',
  'total_count',
  'rows',
};
const _rosterRowKeys = {
  'worker_id',
  'worker_number',
  'worker_name',
  'designation',
  'trade_id',
  'trade_name',
  'department',
  'employer_company',
  'worker_type',
  'assignment',
  'schedule_suggestion',
  'attendance',
  'allocation_set',
  'has_active_allocation_lock',
  'allocation_details_restricted',
  'can_maintain_attendance',
  'can_maintain_timesheet',
};
const _scheduleSuggestionKeys = {
  'source',
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
  'suggested_attendance_status',
  'suggested_regular_minutes',
  'suggested_overtime_minutes',
  'requires_confirmation',
};
const _rosterSaveResultKeys = {
  'schema_version',
  'authorization_mode',
  'work_date',
  'saved_at',
  'row_count',
  'rows',
};
const _rosterSaveRowKeys = {
  'worker_id',
  'attendance_day_id',
  'attendance_record_version',
  'attendance',
  'allocation_set',
  'allocation_set_id',
  'allocation_set_record_version',
  'allocation_state',
};
