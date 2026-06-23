import 'app_user.dart';

/// The capabilities an Admin can grant/revoke per user (each maps to an
/// override field on [AppUser]). Drives both the provider setters and the
/// admin permissions UI.
enum PermissionKey { cost, finance, salary, rentals, people, goods }

/// Resolves a user's **effective** capabilities = per-user override (if the
/// Admin set one) else the role default. This is the single place the rest of
/// the app should consult once a user is signed in; `UserRole`'s getters remain
/// the baseline. Structural traits (isAdmin, usesAdminPanel, canAccessMaterials)
/// stay role-derived — they define which shell loads, not a grantable boundary.
extension EffectivePermissions on AppUser {
  bool get effectiveCanSeeCost => canSeeCostOverride ?? role.canSeeCost;
  bool get effectiveCanViewFinance =>
      canViewFinanceOverride ?? role.canViewFinance;
  bool get effectiveCanSeeSalary => canSeeSalaryOverride ?? role.canSeeSalary;
  bool get effectiveCanAccessRentals =>
      canAccessRentalsOverride ?? role.canAccessRentals;
  bool get effectiveCanAccessPeople =>
      canAccessPeopleOverride ?? role.canAccessPeople;
  bool get effectiveCanReceiveGoods =>
      canReceiveGoodsOverride ?? role.canReceiveGoods;

  // Writes require both the (possibly overridden) access AND the role's write
  // right — revoking access revokes writing too.
  bool get effectiveCanWriteRentals =>
      effectiveCanAccessRentals && role.canWriteRentals;
  bool get effectiveCanWritePeople =>
      effectiveCanAccessPeople && role.canWritePeople;

  /// The Admin-set override for [key], or `null` if it follows the role default.
  bool? overrideFor(PermissionKey key) => switch (key) {
    PermissionKey.cost => canSeeCostOverride,
    PermissionKey.finance => canViewFinanceOverride,
    PermissionKey.salary => canSeeSalaryOverride,
    PermissionKey.rentals => canAccessRentalsOverride,
    PermissionKey.people => canAccessPeopleOverride,
    PermissionKey.goods => canReceiveGoodsOverride,
  };

  /// The role's baseline value for [key] (ignoring any override).
  bool roleDefaultFor(PermissionKey key) => switch (key) {
    PermissionKey.cost => role.canSeeCost,
    PermissionKey.finance => role.canViewFinance,
    PermissionKey.salary => role.canSeeSalary,
    PermissionKey.rentals => role.canAccessRentals,
    PermissionKey.people => role.canAccessPeople,
    PermissionKey.goods => role.canReceiveGoods,
  };

  /// The effective value for [key] = override else role default.
  bool effectiveFor(PermissionKey key) =>
      overrideFor(key) ?? roleDefaultFor(key);
}
