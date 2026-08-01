/// The two protected commercial boundaries defined by the Yorks V1 contract.
///
/// These values describe authorization only. They deliberately carry no cost,
/// supplier or material-commercial data, so the administration UI can manage a
/// boundary without placing a protected commercial projection in local state.
enum YorksV1CommercialCapability {
  viewCommercials('view_commercials'),
  manageCommercials('manage_commercials');

  const YorksV1CommercialCapability(this.databaseValue);

  final String databaseValue;

  static YorksV1CommercialCapability? fromDatabaseValue(Object? value) {
    if (value is! String) return null;
    for (final capability in YorksV1CommercialCapability.values) {
      if (capability.databaseValue == value) return capability;
    }
    return null;
  }
}

/// The server-issued effective result for one protected capability.
///
/// [overrideGranted] is nullable: `null` means that the role default supplies
/// the effective value. A value is never inferred from the retained local
/// role/capability cache.
class YorksV1CommercialCapabilityAccess {
  const YorksV1CommercialCapabilityAccess({
    required this.roleDefault,
    required this.effective,
    required this.overrideGranted,
  });

  final bool roleDefault;
  final bool effective;
  final bool? overrideGranted;

  bool get usesRoleDefault => overrideGranted == null;

  factory YorksV1CommercialCapabilityAccess.fromApiJson(
    Map<String, dynamic> json,
  ) {
    final roleDefault = json['role_default'];
    final effective = json['effective'];
    final overrideGranted = json['override'];
    if (roleDefault is! bool ||
        effective is! bool ||
        (overrideGranted != null && overrideGranted is! bool)) {
      throw const FormatException('Invalid commercial-capability response');
    }
    return YorksV1CommercialCapabilityAccess(
      roleDefault: roleDefault,
      effective: effective,
      overrideGranted: overrideGranted as bool?,
    );
  }
}

/// A complete, typed and deliberately non-commercial capability projection for
/// one V1 identity. The Edge Function is responsible for identifying that
/// identity from the server-side app-user mapping.
class YorksV1CommercialCapabilities {
  const YorksV1CommercialCapabilities(this._accessByCapability);

  final Map<YorksV1CommercialCapability, YorksV1CommercialCapabilityAccess>
  _accessByCapability;

  YorksV1CommercialCapabilityAccess operator [](
    YorksV1CommercialCapability capability,
  ) {
    final access = _accessByCapability[capability];
    if (access == null) {
      throw StateError('Missing protected commercial capability projection');
    }
    return access;
  }

  Map<YorksV1CommercialCapability, YorksV1CommercialCapabilityAccess>
  get accessByCapability => Map.unmodifiable(_accessByCapability);

  factory YorksV1CommercialCapabilities.fromApiJson(Map<String, dynamic> json) {
    final rawCapabilities = json['capabilities'];
    if (rawCapabilities is! Map) {
      throw const FormatException('Missing commercial-capability projection');
    }

    final access =
        <YorksV1CommercialCapability, YorksV1CommercialCapabilityAccess>{};
    for (final capability in YorksV1CommercialCapability.values) {
      final raw = rawCapabilities[capability.databaseValue];
      if (raw is! Map) {
        throw const FormatException(
          'Incomplete commercial-capability response',
        );
      }
      access[capability] = YorksV1CommercialCapabilityAccess.fromApiJson(
        Map<String, dynamic>.from(raw),
      );
    }
    return YorksV1CommercialCapabilities(Map.unmodifiable(access));
  }
}
