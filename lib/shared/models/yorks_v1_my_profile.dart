import 'yorks_v1_role.dart';

/// P01 account evidence, independent of legacy UserRole and employee caches.
/// No business-command authorization is inferred from this read projection.
class YorksV1MyProfile {
  YorksV1MyProfile._({
    required this.generatedAt,
    required this.nextTransitionAt,
    required this.permissionRevision,
    required this.authUserId,
    required this.appUserId,
    required this.displayName,
    required this.email,
    required this.exactRole,
    required this.workerId,
    required this.projects,
    required this.projectTotal,
    required this.projectOffset,
    required this.hasMoreProjects,
    required this.capabilities,
    required this.actions,
  });

  final DateTime generatedAt;
  final DateTime? nextTransitionAt;
  final int permissionRevision;
  final String authUserId;
  final String? appUserId;
  final String displayName;
  final String? email;
  final YorksV1Role exactRole;
  final String? workerId;
  final List<YorksV1MyProfileProject> projects;
  final int projectTotal;
  final int projectOffset;
  final bool hasMoreProjects;
  final List<YorksV1MyProfileCapability> capabilities;
  final List<YorksV1MyProfileAction> actions;

  // P04/P05 populate these independently; absence is never interpreted as zero.
  bool get hasOperationalSummary => false;
  bool get hasLegacyEmployeeProjection => false;
  bool get workerLinkGrantsSelfService => false;

  factory YorksV1MyProfile.fromRpcJson(Object? value) {
    final json = _map(value, {
      'schema_version',
      'generated_at',
      'next_transition_at',
      'permission_revision',
      'account',
      'work_identity',
      'projects',
      'capabilities',
      'actions',
      'operational_summary_state',
      'workforce_scope_state',
    });
    _require(json['schema_version'] == 1);
    _require(json['operational_summary_state'] == 'not_projected');
    _require(json['workforce_scope_state'] == 'requires_work_date_context');
    final account = _map(json['account'], {
      'auth_user_id',
      'app_user_id',
      'display_name',
      'email',
      'exact_role',
      'status',
      'workspace_key',
    });
    final role = YorksV1Role.fromServerClaim(account['exact_role']);
    _require(role != null && account['workspace_key'] == account['exact_role']);
    _require(account['status'] == 'active');
    final identity = _map(json['work_identity'], {
      'legacy_employee',
      'workforce_worker',
    });
    _require(
      _map(identity['legacy_employee'], {'state'})['state'] == 'not_projected',
    );
    final worker = _map(identity['workforce_worker'], {
      'state',
      'worker_id',
      'grants_self_service',
    });
    final workerId = worker['worker_id'] == null
        ? null
        : _uuid(worker['worker_id']);
    _require(worker['state'] == (workerId == null ? 'unlinked' : 'linked'));
    _require(worker['grants_self_service'] == false);
    final page = _map(json['projects'], {
      'total',
      'offset',
      'has_more',
      'items',
    });
    final projects = _list(
      page['items'],
    ).map(YorksV1MyProfileProject.fromJson).toList();
    final total = _integer(page['total']);
    final offset = _integer(page['offset']);
    final more = _boolean(page['has_more']);
    _require(projects.length <= 50 && projects.length <= total);
    _require(
      offset <= total ? offset + projects.length <= total : projects.isEmpty,
    );
    _require(more == (offset + projects.length < total));
    final projectIds = projects.map((p) => p.id).toSet();
    _require(projectIds.length == projects.length);
    final capabilities = _list(
      json['capabilities'],
    ).map(YorksV1MyProfileCapability.fromJson).toList();
    _require(
      capabilities.map((c) => c.key).toSet().length == capabilities.length,
    );
    for (final capability in capabilities) {
      _require(capability.projects.keys.every(projectIds.contains));
    }
    final actions = _list(
      json['actions'],
    ).map(YorksV1MyProfileAction.fromJson).toList();
    _require(actions.map((a) => a.id).toSet().length == actions.length);
    for (final action in actions) {
      _require(
        capabilities.any(
          (c) =>
              c.key == action.capabilityKey &&
              (c.organization?.effective == true ||
                  c.projects.values.any((p) => p.effective)),
        ),
      );
    }
    final generated = _date(json['generated_at']);
    final next = json['next_transition_at'] == null
        ? null
        : _date(json['next_transition_at']);
    _require(next == null || next.isAfter(generated));
    return YorksV1MyProfile._(
      generatedAt: generated,
      nextTransitionAt: next,
      permissionRevision: _integer(json['permission_revision']),
      authUserId: _uuid(account['auth_user_id']),
      appUserId: _nullableText(account['app_user_id']),
      displayName: _text(account['display_name'], allowEmpty: true),
      email: _nullableText(account['email']),
      exactRole: role!,
      workerId: workerId,
      projects: List.unmodifiable(projects),
      projectTotal: total,
      projectOffset: offset,
      hasMoreProjects: more,
      capabilities: List.unmodifiable(capabilities),
      actions: List.unmodifiable(actions),
    );
  }
}

class YorksV1MyProfileProject {
  YorksV1MyProfileProject._(
    this.id,
    this.reference,
    this.name,
    this.technicalAccess,
    this.accountsAccess,
    this.memberships,
  );
  final String id;
  final String reference;
  final String name;
  final bool technicalAccess;
  final bool accountsAccess;
  final List<YorksV1MyProfileMembership> memberships;
  factory YorksV1MyProfileProject.fromJson(Object? value) {
    final json = _map(value, {
      'project_id',
      'project_ref',
      'project_name',
      'technical_access',
      'accounts_access',
      'memberships',
    });
    final technical = _boolean(json['technical_access']);
    final accounts = _boolean(json['accounts_access']);
    final memberships = _list(
      json['memberships'],
    ).map(YorksV1MyProfileMembership.fromJson).toList();
    _require(technical || accounts);
    _require(technical || memberships.isEmpty);
    return YorksV1MyProfileProject._(
      _uuid(json['project_id']),
      _text(json['project_ref']),
      _text(json['project_name']),
      technical,
      accounts,
      List.unmodifiable(memberships),
    );
  }
}

class YorksV1MyProfileMembership {
  YorksV1MyProfileMembership._(this.projectRole, this.from, this.until);
  final String projectRole;
  final DateTime from;
  final DateTime? until;
  factory YorksV1MyProfileMembership.fromJson(Object? value) {
    final json = _map(value, {
      'project_role',
      'effective_from',
      'effective_until',
    });
    final role = _text(json['project_role']);
    _require({'project_engineer', 'site_engineer'}.contains(role));
    final from = _date(json['effective_from']);
    final until = json['effective_until'] == null
        ? null
        : _date(json['effective_until']);
    _require(until == null || until.isAfter(from));
    return YorksV1MyProfileMembership._(role, from, until);
  }
}

class YorksV1MyProfileDecision {
  YorksV1MyProfileDecision._(this.effective, this.source);
  final bool effective;
  final String source;
  factory YorksV1MyProfileDecision.fromJson(Object? value) {
    final json = _map(value, {'effective', 'source'});
    return YorksV1MyProfileDecision._(
      _boolean(json['effective']),
      _text(json['source']),
    );
  }
}

class YorksV1MyProfileCapability {
  YorksV1MyProfileCapability._(
    this.key,
    this.mode,
    this.organization,
    this.projects,
  );
  final String key;
  final String mode;
  final YorksV1MyProfileDecision? organization;
  final Map<String, YorksV1MyProfileDecision> projects;
  factory YorksV1MyProfileCapability.fromJson(Object? value) {
    final json = _map(value, {
      'capability_key',
      'authorization_mode',
      'requires_record_check',
      'organization',
      'projects',
    });
    final mode = _text(json['authorization_mode']);
    _require(
      {'enforced', 'shadow'}.contains(mode) &&
          json['requires_record_check'] == true,
    );
    final projects = <String, YorksV1MyProfileDecision>{};
    for (final value in _list(json['projects'])) {
      final row = _map(value, {'project_id', 'effective', 'source'});
      final id = _uuid(row['project_id']);
      _require(!projects.containsKey(id));
      projects[id] = YorksV1MyProfileDecision.fromJson({
        'effective': row['effective'],
        'source': row['source'],
      });
    }
    return YorksV1MyProfileCapability._(
      _text(json['capability_key']),
      mode,
      json['organization'] == null
          ? null
          : YorksV1MyProfileDecision.fromJson(json['organization']),
      Map.unmodifiable(projects),
    );
  }
}

class YorksV1MyProfileAction {
  YorksV1MyProfileAction._(this.id, this.capabilityKey, this.requiredFeature);
  final String id;
  final String capabilityKey;
  final String requiredFeature;
  static const contracts = {
    'open_projects': ('projects.view', 'projects'),
    'open_material_requests': ('material_requests.view', 'requests'),
    'open_accounts': ('view_project_accounts', 'accounts'),
    'open_inventory': ('inventory.view', 'inventory_suppliers'),
    'open_returns': ('returns.view', 'returns_documents'),
    'open_chat': ('chat.view', 'team_chat'),
    'open_rentals': ('rentals.view', 'foundation'),
    'open_users': ('users.view', 'foundation'),
    'open_configuration': ('configuration.view', 'foundation'),
    'open_audit': ('audit.view', 'foundation'),
    'open_analytics': ('analytics.view', 'analytics'),
  };
  factory YorksV1MyProfileAction.fromJson(Object? value) {
    final json = _map(value, {
      'action_id',
      'capability_key',
      'required_feature',
      'kind',
    });
    final id = _text(json['action_id']);
    final contract = contracts[id];
    _require(contract != null && json['kind'] == 'navigation');
    _require(
      json['capability_key'] == contract!.$1 &&
          json['required_feature'] == contract.$2,
    );
    return YorksV1MyProfileAction._(id, contract.$1, contract.$2);
  }
}

void _require(bool condition) {
  if (!condition) throw const FormatException('Invalid My Yorks profile');
}

Map<String, dynamic> _map(Object? value, Set<String> keys) {
  if (value is! Map) throw const FormatException('Invalid My Yorks object');
  _require(value.keys.length == keys.length && value.keys.every(keys.contains));
  return Map<String, dynamic>.from(value);
}

List<dynamic> _list(Object? value) {
  if (value is! List) throw const FormatException('Invalid My Yorks list');
  return value;
}

String _text(Object? value, {bool allowEmpty = false}) {
  if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
    throw const FormatException('Invalid My Yorks text');
  }
  return value;
}

String? _nullableText(Object? value) => value == null ? null : _text(value);
String _uuid(Object? value) {
  final text = _text(value);
  _require(
    RegExp(
      r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
    ).hasMatch(text),
  );
  return text;
}

int _integer(Object? value) {
  if (value is! int || value < 0) {
    throw const FormatException('Invalid My Yorks integer');
  }
  return value;
}

bool _boolean(Object? value) {
  if (value is! bool) throw const FormatException('Invalid My Yorks boolean');
  return value;
}

DateTime _date(Object? value) {
  final result = DateTime.tryParse(_text(value));
  _require(result != null && result.isUtc);
  return result!;
}
