import 'yorks_v1_role.dart';

/// P04/P05 self-only companion to the strict P01 My Yorks profile model.
///
/// P01 remains the source of account identity, capability decisions and
/// navigation identifiers. This response is deliberately smaller: it carries
/// only aggregate, server-confirmed workspace facts and a self-linked
/// Workforce identity. It is never employee, attendance, assignment or
/// commercial authority.
class YorksV1MyProfileWorkspace {
  YorksV1MyProfileWorkspace._({
    required this.generatedAt,
    required this.nextTransitionAt,
    required this.permissionRevision,
    required this.authUserId,
    required this.exactRole,
    required this.today,
    required this.accessScope,
    required this.workIdentity,
  });

  final DateTime generatedAt;
  final DateTime? nextTransitionAt;
  final int permissionRevision;
  final String authUserId;
  final YorksV1Role exactRole;
  final YorksV1MyProfileToday today;
  final YorksV1MyProfileAccessScope accessScope;
  final YorksV1MyProfileWorkIdentity workIdentity;

  factory YorksV1MyProfileWorkspace.fromRpcJson(Object? value) {
    final json = _workspaceMap(value, {
      'schema_version',
      'generated_at',
      'next_transition_at',
      'permission_revision',
      'account',
      'today',
      'access_scope',
      'work_identity',
    });
    _workspaceRequire(json['schema_version'] == 1);
    final account = _workspaceMap(json['account'], {
      'auth_user_id',
      'exact_role',
    });
    final role = YorksV1Role.fromServerClaim(account['exact_role']);
    _workspaceRequire(role != null);
    final generatedAt = _workspaceDate(json['generated_at']);
    final nextTransitionAt = json['next_transition_at'] == null
        ? null
        : _workspaceDate(json['next_transition_at']);
    _workspaceRequire(
      nextTransitionAt == null || nextTransitionAt.isAfter(generatedAt),
    );
    return YorksV1MyProfileWorkspace._(
      generatedAt: generatedAt,
      nextTransitionAt: nextTransitionAt,
      permissionRevision: _workspaceInteger(json['permission_revision']),
      authUserId: _workspaceUuid(account['auth_user_id']),
      exactRole: role!,
      today: YorksV1MyProfileToday.fromJson(json['today']),
      accessScope: YorksV1MyProfileAccessScope.fromJson(json['access_scope']),
      workIdentity: YorksV1MyProfileWorkIdentity.fromJson(
        json['work_identity'],
      ),
    );
  }
}

class YorksV1MyProfileToday {
  YorksV1MyProfileToday._(this.metrics);

  final List<YorksV1MyProfileTodayMetric> metrics;

  factory YorksV1MyProfileToday.fromJson(Object? value) {
    final json = _workspaceMap(value, {'state', 'metrics'});
    _workspaceRequire(json['state'] == 'available');
    final metrics = _workspaceList(
      json['metrics'],
    ).map(YorksV1MyProfileTodayMetric.fromJson).toList();
    _workspaceRequire(
      metrics.map((metric) => metric.key).toSet().length == metrics.length,
    );
    return YorksV1MyProfileToday._(List.unmodifiable(metrics));
  }
}

class YorksV1MyProfileTodayMetric {
  YorksV1MyProfileTodayMetric._(this.key, this.value);

  static const supportedKeys = <String>{
    'technical_projects',
    'material_requests_needing_action',
    'material_requests_open',
    'accounts_projects',
  };

  final String key;
  final int value;

  factory YorksV1MyProfileTodayMetric.fromJson(Object? value) {
    final json = _workspaceMap(value, {'metric_key', 'value'});
    final key = _workspaceText(json['metric_key']);
    _workspaceRequire(supportedKeys.contains(key));
    return YorksV1MyProfileTodayMetric._(key, _workspaceInteger(json['value']));
  }
}

class YorksV1MyProfileAccessScope {
  YorksV1MyProfileAccessScope._({
    required this.technicalProjectCount,
    required this.accountsProjectCount,
    required this.activeDirectMembershipCount,
    required this.effectiveSourceKinds,
    required this.accountsPortfolioAvailable,
  });

  final int technicalProjectCount;
  final int accountsProjectCount;
  final int activeDirectMembershipCount;
  final List<String> effectiveSourceKinds;

  /// Server-confirmed gate for the organization-wide Accounts portfolio.
  /// Project-specific Accounts visibility is intentionally not treated as a
  /// portfolio route grant.
  final bool accountsPortfolioAvailable;

  factory YorksV1MyProfileAccessScope.fromJson(Object? value) {
    final json = _workspaceMap(value, {
      'technical_project_count',
      'accounts_project_count',
      'active_direct_membership_count',
      'effective_source_kinds',
      'accounts_portfolio_available',
    });
    final sources = _workspaceList(
      json['effective_source_kinds'],
    ).map(_workspaceSource).toList();
    _workspaceRequire(sources.toSet().length == sources.length);
    return YorksV1MyProfileAccessScope._(
      technicalProjectCount: _workspaceInteger(json['technical_project_count']),
      accountsProjectCount: _workspaceInteger(json['accounts_project_count']),
      activeDirectMembershipCount: _workspaceInteger(
        json['active_direct_membership_count'],
      ),
      effectiveSourceKinds: List.unmodifiable(sources),
      accountsPortfolioAvailable: _workspaceBoolean(
        json['accounts_portfolio_available'],
      ),
    );
  }
}

class YorksV1MyProfileWorkIdentity {
  YorksV1MyProfileWorkIdentity._(this.worker);

  final YorksV1MyProfileWorkerIdentity worker;

  factory YorksV1MyProfileWorkIdentity.fromJson(Object? value) {
    final json = _workspaceMap(value, {'legacy_employee', 'workforce_worker'});
    _workspaceRequire(
      _workspaceMap(json['legacy_employee'], {'state'})['state'] ==
          'not_projected',
    );
    return YorksV1MyProfileWorkIdentity._(
      YorksV1MyProfileWorkerIdentity.fromJson(json['workforce_worker']),
    );
  }
}

class YorksV1MyProfileWorkerIdentity {
  YorksV1MyProfileWorkerIdentity._({
    required this.state,
    required this.workerId,
    required this.workerNumber,
    required this.displayName,
    required this.designation,
    required this.department,
    required this.workerType,
    required this.currentStatus,
  });

  final String state;
  final String? workerId;
  final String? workerNumber;
  final String? displayName;
  final String? designation;
  final String? department;
  final String? workerType;
  final String? currentStatus;

  bool get isLinked => state == 'linked';

  factory YorksV1MyProfileWorkerIdentity.fromJson(Object? value) {
    final json = _workspaceMap(value, {
      'state',
      'worker_id',
      'worker_number',
      'display_name',
      'designation',
      'department',
      'worker_type',
      'current_status',
      'grants_self_service',
    });
    final state = _workspaceText(json['state']);
    _workspaceRequire({'linked', 'unlinked'}.contains(state));
    _workspaceRequire(json['grants_self_service'] == false);
    final workerId = _workspaceNullableUuid(json['worker_id']);
    final workerNumber = _workspaceNullableText(json['worker_number']);
    final displayName = _workspaceNullableText(json['display_name']);
    final designation = _workspaceNullableText(json['designation']);
    final department = _workspaceNullableText(json['department']);
    final workerType = _workspaceNullableText(json['worker_type']);
    final currentStatus = _workspaceNullableText(json['current_status']);
    if (state == 'linked') {
      _workspaceRequire(
        workerId != null &&
            workerNumber != null &&
            displayName != null &&
            designation != null &&
            workerType != null &&
            currentStatus != null,
      );
      _workspaceRequire(
        {
          'yorks_employee',
          'temporary_worker',
          'subcontractor_worker',
          'agency_worker',
        }.contains(workerType),
      );
      _workspaceRequire(
        {
          'active',
          'inactive',
          'left_company',
          'suspended',
        }.contains(currentStatus),
      );
    } else {
      _workspaceRequire(
        workerId == null &&
            workerNumber == null &&
            displayName == null &&
            designation == null &&
            department == null &&
            workerType == null &&
            currentStatus == null,
      );
    }
    return YorksV1MyProfileWorkerIdentity._(
      state: state,
      workerId: workerId,
      workerNumber: workerNumber,
      displayName: displayName,
      designation: designation,
      department: department,
      workerType: workerType,
      currentStatus: currentStatus,
    );
  }
}

void _workspaceRequire(bool condition) {
  if (!condition) {
    throw const FormatException('Invalid My Yorks workspace profile');
  }
}

Map<String, dynamic> _workspaceMap(Object? value, Set<String> keys) {
  if (value is! Map) {
    throw const FormatException('Invalid My Yorks workspace object');
  }
  _workspaceRequire(
    value.keys.length == keys.length && value.keys.every(keys.contains),
  );
  return Map<String, dynamic>.from(value);
}

List<dynamic> _workspaceList(Object? value) {
  if (value is! List) {
    throw const FormatException('Invalid My Yorks workspace list');
  }
  return value;
}

String _workspaceText(Object? value, {bool allowEmpty = false}) {
  if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
    throw const FormatException('Invalid My Yorks workspace text');
  }
  return value;
}

String? _workspaceNullableText(Object? value) =>
    value == null ? null : _workspaceText(value);

String _workspaceSource(Object? value) {
  final source = _workspaceText(value);
  _workspaceRequire(RegExp(r'^[a-z][a-z0-9_]{0,79}$').hasMatch(source));
  return source;
}

String _workspaceUuid(Object? value) {
  final text = _workspaceText(value);
  _workspaceRequire(
    RegExp(
      r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
    ).hasMatch(text),
  );
  return text;
}

String? _workspaceNullableUuid(Object? value) =>
    value == null ? null : _workspaceUuid(value);

int _workspaceInteger(Object? value) {
  if (value is! int || value < 0) {
    throw const FormatException('Invalid My Yorks workspace integer');
  }
  return value;
}

bool _workspaceBoolean(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid My Yorks workspace boolean');
  }
  return value;
}

DateTime _workspaceDate(Object? value) {
  final result = DateTime.tryParse(_workspaceText(value));
  _workspaceRequire(result != null && result.isUtc);
  return result!;
}
