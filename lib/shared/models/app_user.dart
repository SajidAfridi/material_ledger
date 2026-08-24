import 'dart:convert';

import 'user_role.dart';
import 'yorks_v1_role.dart';

/// A system user account (auth + access control). Created only by the Admin —
/// there is no self-signup (SRS §3 / §4.1). Supabase owns connected-environment
/// credentials. The hash fields below exist only for explicit local
/// development.
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.active = true,
    this.inventoryAccess = true,
    required this.createdAt,
    this.passwordHash = '',
    this.passwordSalt = '',
    this.mustChangePassword = false,
    this.employeeId,
    this.canSeeCostOverride,
    this.canViewFinanceOverride,
    this.canSeeSalaryOverride,
    this.canAccessRentalsOverride,
    this.canAccessPeopleOverride,
    this.canReceiveGoodsOverride,
    this.yorksV1RoleCache,
    this.yorksV1Roles = const [],
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;

  /// A non-authoritative local display projection of an exact Yorks V1 role
  /// claim. It is populated only after a successful provisioning command or
  /// from the signed-in user's server-issued JWT. V1 authorization must always
  /// read the current Auth claim through [YorksV1Role.fromServerClaim], never
  /// this persisted roster cache.
  ///
  /// `null` is deliberate: a legacy `engineer` account has not been mapped to
  /// either V1 engineering role and must remain unmapped until an Admin makes
  /// that explicit server-side change.
  final YorksV1Role? yorksV1RoleCache;

  /// Backward-compatible serialized role list. Connected Yorks V1 identity
  /// paths normalize this to the one exact server-controlled role in
  /// [yorksV1RoleCache]; historical local records may still decode older lists
  /// without gaining authorization from them.
  final List<YorksV1Role> yorksV1Roles;

  List<YorksV1Role> get effectiveYorksV1Roles => yorksV1Roles.isNotEmpty
      ? List.unmodifiable(yorksV1Roles)
      : yorksV1RoleCache == null
      ? const []
      : [yorksV1RoleCache!];

  /// A deactivated user is denied access on their next request (FR-095).
  final bool active;

  /// Per-engineer inventory read access, grantable/revocable by Admin (FR-104).
  /// Only meaningful for engineers; office roles always read inventory.
  final bool inventoryAccess;

  final DateTime createdAt;

  /// Local auth stand-in only — salted SHA-256 (see PasswordHasher). Supabase
  /// Auth replaces this and connected mode clears these fields.
  final String passwordHash;
  final String passwordSalt;

  /// Set on admin-created/reset accounts so the user must set their own password
  /// on first sign-in.
  final bool mustChangePassword;

  /// Links this login to an HR roster [Employee] (by id), so the person's leave
  /// requests, balance, and HR profile are one unified record. `null` = not yet
  /// linked (the user can't self-request leave until an Admin links them).
  final String? employeeId;

  /// Per-user capability overrides set by Admin. `null` = use the role default
  /// (see effective_permissions.dart). These let Admin grant/revoke financial,
  /// salary, and module access per person without changing their role.
  final bool? canSeeCostOverride;

  /// Canonical V7 name. The stored legacy field remains readable during the
  /// transition so existing user records do not lose their override.
  bool? get canViewCommercialsOverride => canSeeCostOverride;
  final bool? canViewFinanceOverride;
  final bool? canSeeSalaryOverride;
  final bool? canAccessRentalsOverride;
  final bool? canAccessPeopleOverride;
  final bool? canReceiveGoodsOverride;

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Sentinel so nullable override flags can be explicitly set OR cleared
  /// (to `null` = "use role default") via [copyWith].
  static const Object _keep = Object();

  AppUser copyWith({
    String? fullName,
    String? email,
    UserRole? role,
    bool? active,
    bool? inventoryAccess,
    String? passwordHash,
    String? passwordSalt,
    bool? mustChangePassword,
    Object? employeeId = _keep,
    Object? canSeeCostOverride = _keep,
    Object? canViewFinanceOverride = _keep,
    Object? canSeeSalaryOverride = _keep,
    Object? canAccessRentalsOverride = _keep,
    Object? canAccessPeopleOverride = _keep,
    Object? canReceiveGoodsOverride = _keep,
    Object? yorksV1RoleCache = _keep,
    Object? yorksV1Roles = _keep,
  }) => AppUser(
    id: id,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    role: role ?? this.role,
    active: active ?? this.active,
    inventoryAccess: inventoryAccess ?? this.inventoryAccess,
    createdAt: createdAt,
    passwordHash: passwordHash ?? this.passwordHash,
    passwordSalt: passwordSalt ?? this.passwordSalt,
    mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    employeeId: employeeId == _keep ? this.employeeId : employeeId as String?,
    canSeeCostOverride: canSeeCostOverride == _keep
        ? this.canSeeCostOverride
        : canSeeCostOverride as bool?,
    canViewFinanceOverride: canViewFinanceOverride == _keep
        ? this.canViewFinanceOverride
        : canViewFinanceOverride as bool?,
    canSeeSalaryOverride: canSeeSalaryOverride == _keep
        ? this.canSeeSalaryOverride
        : canSeeSalaryOverride as bool?,
    canAccessRentalsOverride: canAccessRentalsOverride == _keep
        ? this.canAccessRentalsOverride
        : canAccessRentalsOverride as bool?,
    canAccessPeopleOverride: canAccessPeopleOverride == _keep
        ? this.canAccessPeopleOverride
        : canAccessPeopleOverride as bool?,
    canReceiveGoodsOverride: canReceiveGoodsOverride == _keep
        ? this.canReceiveGoodsOverride
        : canReceiveGoodsOverride as bool?,
    yorksV1RoleCache: yorksV1RoleCache == _keep
        ? this.yorksV1RoleCache
        : yorksV1RoleCache as YorksV1Role?,
    yorksV1Roles: yorksV1Roles == _keep
        ? this.yorksV1Roles
        : List<YorksV1Role>.unmodifiable(
            (yorksV1Roles as Iterable<YorksV1Role>?) ?? const [],
          ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'role': role.name,
    'active': active,
    'inventoryAccess': inventoryAccess,
    'createdAt': createdAt.toIso8601String(),
    'passwordHash': passwordHash,
    'passwordSalt': passwordSalt,
    'mustChangePassword': mustChangePassword,
    'employeeId': employeeId,
    'canSeeCostOverride': canSeeCostOverride,
    'canViewFinanceOverride': canViewFinanceOverride,
    'canSeeSalaryOverride': canSeeSalaryOverride,
    'canAccessRentalsOverride': canAccessRentalsOverride,
    'canAccessPeopleOverride': canAccessPeopleOverride,
    'canReceiveGoodsOverride': canReceiveGoodsOverride,
    'yorksV1RoleCache': yorksV1RoleCache?.claimValue,
    'yorksV1Roles': [for (final role in yorksV1Roles) role.claimValue],
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    fullName: json['fullName'] as String,
    email: json['email'] as String,
    role: UserRole.fromName(json['role'] as String? ?? 'engineer'),
    active: json['active'] as bool? ?? true,
    inventoryAccess: json['inventoryAccess'] as bool? ?? true,
    createdAt: DateTime.parse(json['createdAt'] as String),
    passwordHash: json['passwordHash'] as String? ?? '',
    passwordSalt: json['passwordSalt'] as String? ?? '',
    mustChangePassword: json['mustChangePassword'] as bool? ?? false,
    employeeId: json['employeeId'] as String?,
    canSeeCostOverride: json['canSeeCostOverride'] as bool?,
    canViewFinanceOverride: json['canViewFinanceOverride'] as bool?,
    canSeeSalaryOverride: json['canSeeSalaryOverride'] as bool?,
    canAccessRentalsOverride: json['canAccessRentalsOverride'] as bool?,
    canAccessPeopleOverride: json['canAccessPeopleOverride'] as bool?,
    canReceiveGoodsOverride: json['canReceiveGoodsOverride'] as bool?,
    yorksV1RoleCache: YorksV1Role.fromServerClaim(json['yorksV1RoleCache']),
    yorksV1Roles: ((json['yorksV1Roles'] as List?) ?? const [])
        .map(YorksV1Role.fromServerClaim)
        .whereType<YorksV1Role>()
        .toList(growable: false),
  );

  static String encodeList(List<AppUser> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<AppUser> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
