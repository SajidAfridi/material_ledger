import 'dart:convert';

import 'user_role.dart';

/// A system user account (auth + access control). Created only by the Admin —
/// there is no self-signup (SRS §3 / §4.1). Passwords are never stored here;
/// with Firebase they live as hashed Auth credentials. The model carries just
/// the access-control facts the Admin Panel manages.
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
    this.canSeeCostOverride,
    this.canViewFinanceOverride,
    this.canSeeSalaryOverride,
    this.canAccessRentalsOverride,
    this.canAccessPeopleOverride,
    this.canReceiveGoodsOverride,
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;

  /// A deactivated user is denied access on their next request (FR-095).
  final bool active;

  /// Per-engineer inventory read access, grantable/revocable by Admin (FR-104).
  /// Only meaningful for engineers; office roles always read inventory.
  final bool inventoryAccess;

  final DateTime createdAt;

  /// Local auth stand-in only — salted SHA-256 (see PasswordHasher). Firebase
  /// Auth replaces this and these fields drop from any Firestore mapping.
  final String passwordHash;
  final String passwordSalt;

  /// Set on admin-created/reset accounts so the user must set their own password
  /// on first sign-in.
  final bool mustChangePassword;

  /// Per-user capability overrides set by Admin. `null` = use the role default
  /// (see effective_permissions.dart). These let Admin grant/revoke financial,
  /// salary, and module access per person without changing their role.
  final bool? canSeeCostOverride;
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
    Object? canSeeCostOverride = _keep,
    Object? canViewFinanceOverride = _keep,
    Object? canSeeSalaryOverride = _keep,
    Object? canAccessRentalsOverride = _keep,
    Object? canAccessPeopleOverride = _keep,
    Object? canReceiveGoodsOverride = _keep,
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
    'canSeeCostOverride': canSeeCostOverride,
    'canViewFinanceOverride': canViewFinanceOverride,
    'canSeeSalaryOverride': canSeeSalaryOverride,
    'canAccessRentalsOverride': canAccessRentalsOverride,
    'canAccessPeopleOverride': canAccessPeopleOverride,
    'canReceiveGoodsOverride': canReceiveGoodsOverride,
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
    canSeeCostOverride: json['canSeeCostOverride'] as bool?,
    canViewFinanceOverride: json['canViewFinanceOverride'] as bool?,
    canSeeSalaryOverride: json['canSeeSalaryOverride'] as bool?,
    canAccessRentalsOverride: json['canAccessRentalsOverride'] as bool?,
    canAccessPeopleOverride: json['canAccessPeopleOverride'] as bool?,
    canReceiveGoodsOverride: json['canReceiveGoodsOverride'] as bool?,
  );

  static String encodeList(List<AppUser> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<AppUser> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }
}
