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

  AppUser copyWith({
    String? fullName,
    String? email,
    UserRole? role,
    bool? active,
    bool? inventoryAccess,
  }) => AppUser(
    id: id,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    role: role ?? this.role,
    active: active ?? this.active,
    inventoryAccess: inventoryAccess ?? this.inventoryAccess,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'role': role.name,
    'active': active,
    'inventoryAccess': inventoryAccess,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    fullName: json['fullName'] as String,
    email: json['email'] as String,
    role: UserRole.fromName(json['role'] as String? ?? 'engineer'),
    active: json['active'] as bool? ?? true,
    inventoryAccess: json['inventoryAccess'] as bool? ?? true,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  static String encodeList(List<AppUser> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<AppUser> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }
}
