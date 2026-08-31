enum YorksWorkforceWorkerStatus {
  active('active'),
  inactive('inactive'),
  leftCompany('left_company'),
  suspended('suspended');

  const YorksWorkforceWorkerStatus(this.wireValue);
  final String wireValue;

  static YorksWorkforceWorkerStatus fromWire(Object? value) =>
      values.firstWhere(
        (status) => status.wireValue == value,
        orElse: () => throw const FormatException('Invalid worker status'),
      );
}

enum YorksWorkforceWorkerType {
  yorksEmployee('yorks_employee'),
  temporaryWorker('temporary_worker'),
  subcontractorWorker('subcontractor_worker'),
  agencyWorker('agency_worker');

  const YorksWorkforceWorkerType(this.wireValue);
  final String wireValue;

  static YorksWorkforceWorkerType fromWire(Object? value) => values.firstWhere(
    (type) => type.wireValue == value,
    orElse: () => throw const FormatException('Invalid worker type'),
  );
}

class YorksWorkforceTrade {
  const YorksWorkforceTrade({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.isActive,
    required this.recordVersion,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final bool isActive;
  final int recordVersion;

  factory YorksWorkforceTrade.fromRpcJson(Map<String, dynamic> json) =>
      YorksWorkforceTrade(
        id: _text(json['trade_id']),
        code: _text(json['trade_code']),
        name: _text(json['trade_name']),
        description: _nullableText(json['description']),
        isActive: _boolean(json['is_active']),
        recordVersion: _positiveInteger(json['record_version']),
      );
}

class YorksWorkforceTeam {
  const YorksWorkforceTeam({
    required this.id,
    required this.code,
    required this.name,
    required this.department,
    required this.defaultSupervisorAuthUserId,
    required this.defaultProjectId,
    required this.defaultProjectScopeId,
    required this.defaultInternalLocationId,
    required this.validFrom,
    required this.validTo,
    required this.isActive,
    required this.recordVersion,
  });

  final String id;
  final String code;
  final String name;
  final String? department;
  final String? defaultSupervisorAuthUserId;
  final String? defaultProjectId;
  final String? defaultProjectScopeId;
  final String? defaultInternalLocationId;
  final String validFrom;
  final String? validTo;
  final bool isActive;
  final int recordVersion;

  factory YorksWorkforceTeam.fromRpcJson(Map<String, dynamic> json) =>
      YorksWorkforceTeam(
        id: _text(json['team_id']),
        code: _text(json['team_code']),
        name: _text(json['team_name']),
        department: _nullableText(json['department']),
        defaultSupervisorAuthUserId: _nullableText(
          json['default_supervisor_auth_user_id'],
        ),
        defaultProjectId: _nullableText(json['default_project_id']),
        defaultProjectScopeId: _nullableText(json['default_project_scope_id']),
        defaultInternalLocationId: _nullableText(
          json['default_internal_location_id'],
        ),
        validFrom: _date(json['valid_from']),
        validTo: _nullableDate(json['valid_to']),
        isActive: _boolean(json['is_active']),
        recordVersion: _positiveInteger(json['record_version']),
      );
}

class YorksWorkforceInternalLocation {
  const YorksWorkforceInternalLocation({
    required this.id,
    required this.code,
    required this.name,
    required this.department,
    required this.isActive,
    required this.recordVersion,
  });

  final String id;
  final String code;
  final String name;
  final String? department;
  final bool isActive;
  final int recordVersion;

  factory YorksWorkforceInternalLocation.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksWorkforceInternalLocation(
    id: _text(json['internal_location_id']),
    code: _text(json['location_code']),
    name: _text(json['location_name']),
    department: _nullableText(json['department']),
    isActive: _boolean(json['is_active']),
    recordVersion: _positiveInteger(json['record_version']),
  );
}

class YorksWorkforceEffectiveAssignment {
  const YorksWorkforceEffectiveAssignment({
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
  final String? teamId;
  final String? teamName;
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

  factory YorksWorkforceEffectiveAssignment.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final kind = _text(json['assignment_kind']);
    if (kind != 'primary' && kind != 'temporary') {
      throw const FormatException('Invalid assignment kind');
    }
    return YorksWorkforceEffectiveAssignment(
      id: _text(json['assignment_id']),
      kind: kind,
      teamId: _nullableText(json['team_id']),
      teamName: _nullableText(json['team_name']),
      supervisorAuthUserId: _nullableText(json['supervisor_auth_user_id']),
      supervisorName: _nullableText(json['supervisor_name']),
      projectId: _nullableText(json['project_id']),
      projectRef: _nullableText(json['project_ref']),
      projectName: _nullableText(json['project_name']),
      projectScopeId: _nullableText(json['project_scope_id']),
      projectScopeName: _nullableText(json['project_scope_name']),
      internalLocationId: _nullableText(json['internal_location_id']),
      internalLocationName: _nullableText(json['internal_location_name']),
      validFrom: _date(json['valid_from']),
      validTo: _nullableDate(json['valid_to']),
      recordVersion: _positiveInteger(json['record_version']),
    );
  }
}

class YorksWorkforceWorker {
  const YorksWorkforceWorker({
    required this.id,
    required this.number,
    required this.fullName,
    required this.preferredDisplayName,
    required this.designation,
    required this.tradeId,
    required this.tradeName,
    required this.department,
    required this.employerCompany,
    required this.workerType,
    required this.mobileNumber,
    required this.joiningDate,
    required this.leavingDate,
    required this.status,
    required this.linkedAuthUserId,
    required this.notes,
    required this.recordVersion,
    required this.effectiveAssignment,
  });

  final String id;
  final String number;
  final String fullName;
  final String? preferredDisplayName;
  final String designation;
  final String? tradeId;
  final String? tradeName;
  final String? department;
  final String employerCompany;
  final YorksWorkforceWorkerType workerType;
  final String? mobileNumber;
  final String joiningDate;
  final String? leavingDate;
  final YorksWorkforceWorkerStatus status;
  final String? linkedAuthUserId;
  final String? notes;
  final int recordVersion;
  final YorksWorkforceEffectiveAssignment? effectiveAssignment;

  factory YorksWorkforceWorker.fromRpcJson(Map<String, dynamic> json) {
    final assignment = _map(json['effective_assignment']);
    return YorksWorkforceWorker(
      id: _text(json['worker_id']),
      number: _text(json['worker_number']),
      fullName: _text(json['full_name']),
      preferredDisplayName: _nullableText(json['preferred_display_name']),
      designation: _text(json['designation']),
      tradeId: _nullableText(json['trade_id']),
      tradeName: _nullableText(json['trade_name']),
      department: _nullableText(json['department']),
      employerCompany: _text(json['employer_company']),
      workerType: YorksWorkforceWorkerType.fromWire(json['worker_type']),
      mobileNumber: _nullableText(json['mobile_number']),
      joiningDate: _date(json['joining_date']),
      leavingDate: _nullableDate(json['leaving_date']),
      status: YorksWorkforceWorkerStatus.fromWire(json['current_status']),
      linkedAuthUserId: _nullableText(json['linked_auth_user_id']),
      notes: _nullableText(json['notes']),
      recordVersion: _positiveInteger(json['record_version']),
      effectiveAssignment: assignment.isEmpty
          ? null
          : YorksWorkforceEffectiveAssignment.fromRpcJson(assignment),
    );
  }
}

class YorksWorkforceFoundationProjection {
  YorksWorkforceFoundationProjection({
    required this.schemaVersion,
    required this.authorizationMode,
    required this.actorAuthUserId,
    required this.onDate,
    required this.serverTime,
    required Iterable<YorksWorkforceTrade> trades,
    required Iterable<YorksWorkforceTeam> teams,
    required Iterable<YorksWorkforceInternalLocation> internalLocations,
    required Iterable<YorksWorkforceWorker> workers,
    required this.workerCount,
  }) : trades = List.unmodifiable(trades),
       teams = List.unmodifiable(teams),
       internalLocations = List.unmodifiable(internalLocations),
       workers = List.unmodifiable(workers) {
    if (schemaVersion != 1 ||
        !const {
          'admin_legacy_t01',
          'enforced_administration',
        }.contains(authorizationMode)) {
      throw const FormatException('Unsupported Workforce foundation schema');
    }
    if (workerCount < workers.length) {
      throw const FormatException('Invalid Workforce worker count');
    }
  }

  final int schemaVersion;
  final String authorizationMode;
  final String actorAuthUserId;
  final String onDate;
  final String serverTime;
  final List<YorksWorkforceTrade> trades;
  final List<YorksWorkforceTeam> teams;
  final List<YorksWorkforceInternalLocation> internalLocations;
  final List<YorksWorkforceWorker> workers;
  final int workerCount;

  factory YorksWorkforceFoundationProjection.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksWorkforceFoundationProjection(
    schemaVersion: _positiveInteger(json['schema_version']),
    authorizationMode: _text(json['authorization_mode']),
    actorAuthUserId: _text(json['actor_auth_user_id']),
    onDate: _date(json['on_date']),
    serverTime: _timestamp(json['server_time']),
    trades: _list(
      json['trades'],
    ).map((value) => YorksWorkforceTrade.fromRpcJson(_map(value))),
    teams: _list(
      json['teams'],
    ).map((value) => YorksWorkforceTeam.fromRpcJson(_map(value))),
    internalLocations: _list(
      json['internal_locations'],
    ).map((value) => YorksWorkforceInternalLocation.fromRpcJson(_map(value))),
    workers: _list(
      json['workers'],
    ).map((value) => YorksWorkforceWorker.fromRpcJson(_map(value))),
    workerCount: _nonNegativeInteger(json['worker_count']),
  );
}

class YorksWorkforceCommandResult {
  const YorksWorkforceCommandResult({
    required this.schemaVersion,
    required this.entityId,
    required this.recordVersion,
  });

  final int schemaVersion;
  final String entityId;
  final int recordVersion;

  factory YorksWorkforceCommandResult.fromRpcJson(Map<String, dynamic> json) {
    final schemaVersion = _positiveInteger(json['schema_version']);
    if (schemaVersion != 1) {
      throw const FormatException('Unsupported Workforce command schema');
    }
    return YorksWorkforceCommandResult(
      schemaVersion: schemaVersion,
      entityId: _text(
        json['entity_id'] ??
            json['trade_id'] ??
            json['internal_location_id'] ??
            json['worker_id'] ??
            json['team_id'] ??
            json['assignment_id'] ??
            json['responsibility_assignment_id'] ??
            json['calendar_id'] ??
            json['calendar_date_id'] ??
            json['shift_template_id'] ??
            json['team_schedule_link_id'] ??
            json['attendance_day_id'],
      ),
      recordVersion: _positiveInteger(json['record_version']),
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

int _nonNegativeInteger(Object? value) {
  if (value is int && value >= 0) return value;
  if (value is num && value == value.roundToDouble() && value >= 0) {
    return value.toInt();
  }
  throw const FormatException('Expected non-negative integer');
}

int _positiveInteger(Object? value) {
  final integer = _nonNegativeInteger(value);
  if (integer == 0) throw const FormatException('Expected positive integer');
  return integer;
}

bool _boolean(Object? value) {
  if (value is bool) return value;
  throw const FormatException('Expected boolean');
}

String _date(Object? value) {
  final text = _text(value);
  final parsed = DateTime.tryParse(text);
  if (parsed == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    throw const FormatException('Expected date');
  }
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
