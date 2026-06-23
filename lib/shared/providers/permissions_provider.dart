import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/role_permissions.dart';
import 'role_permissions_provider.dart';
import 'session_provider.dart';

/// Effective-capability providers — the single place UI/guards read access from.
/// Resolution layers (highest wins): per-user override → editable role default
/// (Access & Roles matrix) → built-in `UserRole` baseline. Watching
/// [rolePermissionsProvider] is what makes an Admin's matrix edits take effect
/// across the app instantly.
bool _cap(Ref ref, RoleCapability cap) {
  final user = ref.watch(currentUserProvider);
  final role = ref.watch(currentRoleProvider);
  final perms = ref.watch(rolePermissionsProvider);
  return resolveCapability(user, role, perms, cap);
}

final canSeeCostProvider = Provider<bool>((ref) => _cap(ref, RoleCapability.cost));
final canViewFinanceProvider =
    Provider<bool>((ref) => _cap(ref, RoleCapability.finance));
final canSeeSalaryProvider =
    Provider<bool>((ref) => _cap(ref, RoleCapability.salary));
final canAccessRentalsProvider =
    Provider<bool>((ref) => _cap(ref, RoleCapability.rentals));
final canAccessPeopleProvider =
    Provider<bool>((ref) => _cap(ref, RoleCapability.people));
final canReceiveGoodsProvider =
    Provider<bool>((ref) => _cap(ref, RoleCapability.goods));

// Writes require both the (possibly overridden) access AND the role-level write
// right — revoking access revokes writing too.
final canWriteRentalsProvider = Provider<bool>(
  (ref) =>
      _cap(ref, RoleCapability.rentals) && _cap(ref, RoleCapability.writeRentals),
);
final canWritePeopleProvider = Provider<bool>(
  (ref) =>
      _cap(ref, RoleCapability.people) && _cap(ref, RoleCapability.writePeople),
);
