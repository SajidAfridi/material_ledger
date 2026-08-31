class YorksWorkforceAdministrationUserOption {
  const YorksWorkforceAdministrationUserOption({
    required this.authUserId,
    required this.appUserId,
    required this.displayName,
    required this.exactRole,
    required this.isActive,
  });

  final String authUserId;
  final String appUserId;
  final String displayName;
  final String exactRole;
  final bool isActive;

  factory YorksWorkforceAdministrationUserOption.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksWorkforceAdministrationUserOption(
    authUserId: _text(json['auth_user_id']),
    appUserId: _text(json['app_user_id']),
    displayName: _text(json['display_name']),
    exactRole: _text(json['exact_role']),
    isActive: _boolean(json['is_active']),
  );
}

class YorksWorkforceAdministrationScopeOption {
  const YorksWorkforceAdministrationScopeOption({
    required this.id,
    required this.code,
    required this.name,
    required this.kind,
    required this.isActive,
  });

  final String id;
  final String code;
  final String name;
  final String kind;
  final bool isActive;

  factory YorksWorkforceAdministrationScopeOption.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final kind = _text(json['scope_kind']);
    if (kind != 'common' && kind != 'building') {
      throw const FormatException('Invalid project scope kind');
    }
    return YorksWorkforceAdministrationScopeOption(
      id: _text(json['project_scope_id']),
      code: _text(json['scope_code']),
      name: _text(json['scope_name']),
      kind: kind,
      isActive: _boolean(json['is_active']),
    );
  }
}

class YorksWorkforceAdministrationProjectOption {
  YorksWorkforceAdministrationProjectOption({
    required this.id,
    required this.reference,
    required this.name,
    required this.state,
    required Iterable<YorksWorkforceAdministrationScopeOption> scopes,
  }) : scopes = List.unmodifiable(scopes);

  final String id;
  final String reference;
  final String name;
  final String state;
  final List<YorksWorkforceAdministrationScopeOption> scopes;

  factory YorksWorkforceAdministrationProjectOption.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final state = _text(json['state']);
    if (!const {'draft', 'active', 'on_hold', 'completed'}.contains(state)) {
      throw const FormatException('Invalid project state');
    }
    return YorksWorkforceAdministrationProjectOption(
      id: _text(json['project_id']),
      reference: _text(json['project_ref']),
      name: _text(json['project_name']),
      state: state,
      scopes: _list(json['scopes']).map(
        (value) =>
            YorksWorkforceAdministrationScopeOption.fromRpcJson(_map(value)),
      ),
    );
  }
}

class YorksWorkforceAdministrationOptions {
  YorksWorkforceAdministrationOptions({
    required this.schemaVersion,
    required this.authorizationMode,
    required this.actorAuthUserId,
    required this.onDate,
    required this.serverTime,
    required Iterable<YorksWorkforceAdministrationUserOption> users,
    required Iterable<YorksWorkforceAdministrationProjectOption> projects,
  }) : users = List.unmodifiable(users),
       projects = List.unmodifiable(projects) {
    if (schemaVersion != 1 || authorizationMode != 'enforced_administration') {
      throw const FormatException(
        'Unsupported Workforce administration options',
      );
    }
  }

  final int schemaVersion;
  final String authorizationMode;
  final String actorAuthUserId;
  final String onDate;
  final String serverTime;
  final List<YorksWorkforceAdministrationUserOption> users;
  final List<YorksWorkforceAdministrationProjectOption> projects;

  factory YorksWorkforceAdministrationOptions.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksWorkforceAdministrationOptions(
    schemaVersion: _positiveInteger(json['schema_version']),
    authorizationMode: _text(json['authorization_mode']),
    actorAuthUserId: _text(json['actor_auth_user_id']),
    onDate: _date(json['on_date']),
    serverTime: _timestamp(json['server_time']),
    users: _list(json['users']).map(
      (value) =>
          YorksWorkforceAdministrationUserOption.fromRpcJson(_map(value)),
    ),
    projects: _list(json['projects']).map(
      (value) =>
          YorksWorkforceAdministrationProjectOption.fromRpcJson(_map(value)),
    ),
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

int _positiveInteger(Object? value) {
  if (value is int && value > 0) return value;
  if (value is num && value == value.roundToDouble() && value > 0) {
    return value.toInt();
  }
  throw const FormatException('Expected positive integer');
}

bool _boolean(Object? value) {
  if (value is bool) return value;
  throw const FormatException('Expected boolean');
}

String _date(Object? value) {
  final text = _text(value);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
      DateTime.tryParse(text) == null) {
    throw const FormatException('Expected date');
  }
  return text;
}

String _timestamp(Object? value) {
  final text = _text(value);
  if (DateTime.tryParse(text) == null) {
    throw const FormatException('Expected timestamp');
  }
  return text;
}
