/// Exact, server-controlled Yorks V1 role claims.
///
/// This type deliberately does not convert from the legacy [UserRole] model.
/// A legacy `engineer` is not evidence of either V1 engineering role; V1
/// authority begins only after the server supplies one of these exact claims.
enum YorksV1Role {
  projectEngineer('project_engineer'),
  siteEngineer('site_engineer'),
  seniorMechanicalEngineer('senior_mechanical_engineer'),
  projectManager('project_manager'),
  procurement('procurement'),
  admin('admin');

  const YorksV1Role(this.claimValue);

  /// The exact value accepted from `auth.jwt() -> app_metadata.role`.
  final String claimValue;

  /// Parses only an exact server claim. In particular, this does not lowercase,
  /// normalize, or reinterpret legacy labels such as `engineer`.
  static YorksV1Role? fromServerClaim(Object? value) {
    if (value is! String) return null;
    for (final role in YorksV1Role.values) {
      if (role.claimValue == value) return role;
    }
    return null;
  }

  bool get canCreateProject => isEngineering || this == admin;

  /// V1 Material Request draft creation follows the same base-role boundary.
  /// The server additionally checks active project membership and project state
  /// for every save and submit command.
  bool get canCreateMaterialRequest => isEngineering || this == admin;

  /// A base Site Engineer can hold a dated, project-specific Project Engineer
  /// membership. The client has no authoritative membership projection at this
  /// command boundary, so it must not reject that person before the trusted
  /// RPC checks their active project role. Procurement remains denied early.
  ///
  /// This is not a grant: `v1_can_manage_project` re-checks the exact role and
  /// active Project Engineer membership (or Admin override) under its lock.
  bool get canManageProjectMembers => isEngineering || this == admin;

  /// See [canManageProjectMembers]. Project-state authority likewise belongs
  /// to the server-side intersection of base role and dated membership.
  bool get canSetProjectState => isEngineering || this == admin;

  /// Senior Mechanical Engineer and Project Manager are organization-wide
  /// Project Engineer roles. The trusted database maps both exact claims to
  /// Project Engineer workflow authority and grants project access without a
  /// dated per-project membership row.
  bool get isGlobalProjectEngineer =>
      this == seniorMechanicalEngineer || this == projectManager;

  bool get isEngineering =>
      this == projectEngineer ||
      this == siteEngineer ||
      isGlobalProjectEngineer;
}
