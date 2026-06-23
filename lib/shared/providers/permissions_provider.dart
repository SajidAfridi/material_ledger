import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/effective_permissions.dart';
import '../models/user_role.dart';
import 'session_provider.dart';

/// Effective-capability providers — the single place UI/guards read access from.
/// Each resolves the signed-in user's per-user override (if Admin set one) and
/// falls back to the role default; before login (no user) it uses the role.
///
/// Migrating consumers from `role.canX` to these providers is what makes the
/// Admin's per-user permission toggles actually take effect across the app.

bool _resolve(
  Ref ref,
  bool Function(AppUser user) ofUser,
  bool Function(UserRole role) ofRole,
) {
  final user = ref.watch(currentUserProvider);
  if (user != null) return ofUser(user);
  return ofRole(ref.watch(currentRoleProvider));
}

final canSeeCostProvider = Provider<bool>(
  (ref) => _resolve(ref, (u) => u.effectiveCanSeeCost, (r) => r.canSeeCost),
);
final canViewFinanceProvider = Provider<bool>(
  (ref) =>
      _resolve(ref, (u) => u.effectiveCanViewFinance, (r) => r.canViewFinance),
);
final canSeeSalaryProvider = Provider<bool>(
  (ref) => _resolve(ref, (u) => u.effectiveCanSeeSalary, (r) => r.canSeeSalary),
);
final canAccessRentalsProvider = Provider<bool>(
  (ref) => _resolve(
    ref,
    (u) => u.effectiveCanAccessRentals,
    (r) => r.canAccessRentals,
  ),
);
final canAccessPeopleProvider = Provider<bool>(
  (ref) =>
      _resolve(ref, (u) => u.effectiveCanAccessPeople, (r) => r.canAccessPeople),
);
final canWriteRentalsProvider = Provider<bool>(
  (ref) =>
      _resolve(ref, (u) => u.effectiveCanWriteRentals, (r) => r.canWriteRentals),
);
final canWritePeopleProvider = Provider<bool>(
  (ref) =>
      _resolve(ref, (u) => u.effectiveCanWritePeople, (r) => r.canWritePeople),
);
final canReceiveGoodsProvider = Provider<bool>(
  (ref) =>
      _resolve(ref, (u) => u.effectiveCanReceiveGoods, (r) => r.canReceiveGoods),
);
