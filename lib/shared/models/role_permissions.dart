import 'dart:convert';

import 'app_user.dart';
import 'effective_permissions.dart';
import 'user_role.dart';

/// A non-structural capability whose role-level default an Admin can edit on the
/// Access & Roles screen. Superset of the per-user [PermissionKey] (adds the two
/// writes shown as their own matrix rows). Structural traits (materials access,
/// admin identity / which shell loads) are intentionally NOT here — they define
/// the app a role gets, not a grantable boundary.
enum RoleCapability {
  cost,
  salary,
  finance,
  rentals,
  writeRentals,
  people,
  writePeople,
  goods;

  /// The matching per-user override key, or null for caps with no per-user
  /// override (the two writes derive from access + this role-level right).
  PermissionKey? get overrideKey => switch (this) {
    RoleCapability.cost => PermissionKey.cost,
    RoleCapability.salary => PermissionKey.salary,
    RoleCapability.finance => PermissionKey.finance,
    RoleCapability.rentals => PermissionKey.rentals,
    RoleCapability.people => PermissionKey.people,
    RoleCapability.goods => PermissionKey.goods,
    RoleCapability.writeRentals || RoleCapability.writePeople => null,
  };

  /// Built-in baseline for [role] (the `UserRole` getters) — the seed value.
  bool defaultFor(UserRole role) => switch (this) {
    RoleCapability.cost => role.canSeeCost,
    RoleCapability.salary => role.canSeeSalary,
    RoleCapability.finance => role.canViewFinance,
    RoleCapability.rentals => role.canAccessRentals,
    RoleCapability.writeRentals => role.canWriteRentals,
    RoleCapability.people => role.canAccessPeople,
    RoleCapability.writePeople => role.canWritePeople,
    RoleCapability.goods => role.canReceiveGoods,
  };
}

/// Roles whose defaults are editable. Admin is a locked superuser (always all),
/// so it is neither stored nor editable.
const editableRoles = [UserRole.engineer, UserRole.procurement];

Set<RoleCapability> _seedFor(UserRole role) => {
  for (final c in RoleCapability.values)
    if (c.defaultFor(role)) c,
};

/// Admin-editable role-level capability defaults. Seeded from the `UserRole`
/// baseline so behaviour is identical until an Admin edits. Admin is always all.
class RolePermissions {
  const RolePermissions(this._granted);

  /// role.name → granted caps (editable roles only).
  final Map<String, Set<RoleCapability>> _granted;

  factory RolePermissions.fromRoleDefaults() =>
      RolePermissions({for (final r in editableRoles) r.name: _seedFor(r)});

  /// Whether [role] currently has [cap]. Admin → always true (locked superuser).
  bool has(UserRole role, RoleCapability cap) {
    if (role.isAdmin) return true;
    return _granted[role.name]?.contains(cap) ?? cap.defaultFor(role);
  }

  bool isEditable(UserRole role) => editableRoles.contains(role);

  RolePermissions setCapability(UserRole role, RoleCapability cap, bool value) {
    if (!isEditable(role)) return this; // admin / unknown — ignore
    final next = {
      for (final e in _granted.entries) e.key: {...e.value},
    };
    final set = next.putIfAbsent(role.name, () => _seedFor(role));
    value ? set.add(cap) : set.remove(cap);
    return RolePermissions(next);
  }

  RolePermissions resetRole(UserRole role) {
    if (!isEditable(role)) return this;
    final next = {
      for (final e in _granted.entries) e.key: {...e.value},
    };
    next[role.name] = _seedFor(role);
    return RolePermissions(next);
  }

  Map<String, dynamic> toJson() => {
    for (final e in _granted.entries)
      e.key: e.value.map((c) => c.name).toList(),
  };

  factory RolePermissions.fromJson(Map<String, dynamic> json) =>
      RolePermissions({
        for (final r in editableRoles)
          r.name: switch (json[r.name]) {
            // Back-compat: a missing role seeds from defaults.
            null => _seedFor(r),
            final List<dynamic> raw => {
              for (final c in RoleCapability.values)
                if (raw.contains(c.name)) c,
            },
            _ => _seedFor(r),
          },
      });

  static String encode(RolePermissions p) => jsonEncode(p.toJson());
  static RolePermissions decode(String s) =>
      RolePermissions.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

/// The single resolver the app uses everywhere: per-user override (if the Admin
/// set one for this cap) else the (editable) role default.
bool resolveCapability(
  AppUser? user,
  UserRole role,
  RolePermissions perms,
  RoleCapability cap,
) {
  final key = cap.overrideKey;
  if (user != null && key != null) {
    final override = user.overrideFor(key);
    if (override != null) return override;
  }
  return perms.has(role, cap);
}
