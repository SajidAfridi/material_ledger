import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/effective_permissions.dart';
import '../models/user_role.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';
import '../services/password_hasher.dart';

const _kUsersKey = 'app_users_v2';
const _uuid = Uuid();

/// Default password for the seeded demo accounts (internal first-run only).
/// Real accounts are created by Admin with their own password.
const kSeedPassword = 'yorks1234';

/// All system user accounts. Admin-managed only (no self-signup). This is the
/// seam that becomes Firebase Auth user administration (create via Admin SDK,
/// deactivate, reset password, custom-claim role).
final usersProvider = StateNotifierProvider<UsersNotifier, List<AppUser>>((ref) {
  return UsersNotifier(
    ref.watch(storageProvider).collection<AppUser>(
      _kUsersKey,
      toJson: (u) => u.toJson(),
      fromJson: AppUser.fromJson,
    ),
  );
});

class UsersNotifier extends StateNotifier<List<AppUser>> {
  UsersNotifier(this._store) : super([]) {
    state = _store.isSeeded ? _store.readAll() : _seed();
    if (!_store.isSeeded) _store.writeAll(state);
  }

  final CollectionStore<AppUser> _store;

  Future<AppUser> createUser({
    required String fullName,
    required String email,
    required UserRole role,
    required String password,
  }) async {
    final pw = PasswordHasher.create(password);
    final user = AppUser(
      id: 'usr-${_uuid.v4().substring(0, 8)}',
      fullName: fullName,
      email: email,
      role: role,
      createdAt: DateTime.now(),
      passwordHash: pw.hash,
      passwordSalt: pw.salt,
      // The admin set a temporary password; the user changes it on first login.
      mustChangePassword: true,
    );
    state = [user, ...state];
    await _store.writeAll(state);
    return user;
  }

  Future<void> update(AppUser updated) async {
    state = [
      for (final u in state)
        if (u.id == updated.id) updated else u,
    ];
    await _store.writeAll(state);
  }

  /// Set a new password. [temporary] true (admin reset) forces a change on next
  /// sign-in; false (user changed their own) clears the flag.
  Future<void> setPassword(
    String id,
    String newPassword, {
    bool temporary = false,
  }) async {
    final pw = PasswordHasher.create(newPassword);
    state = [
      for (final u in state)
        if (u.id == id)
          u.copyWith(
            passwordHash: pw.hash,
            passwordSalt: pw.salt,
            mustChangePassword: temporary,
          )
        else
          u,
    ];
    await _store.writeAll(state);
  }

  Future<void> setActive(String id, bool active) async {
    state = [
      for (final u in state)
        if (u.id == id) u.copyWith(active: active) else u,
    ];
    await _store.writeAll(state);
  }

  Future<void> setInventoryAccess(String id, bool access) async {
    state = [
      for (final u in state)
        if (u.id == id) u.copyWith(inventoryAccess: access) else u,
    ];
    await _store.writeAll(state);
  }

  /// Set (or clear, with `null`) a per-user capability override. Clearing
  /// returns that capability to the role default.
  Future<void> setPermissionOverride(
    String id,
    PermissionKey key,
    bool? value,
  ) async {
    state = [
      for (final u in state)
        if (u.id == id) _applyOverride(u, key, value) else u,
    ];
    await _store.writeAll(state);
  }

  AppUser _applyOverride(AppUser u, PermissionKey key, bool? value) =>
      switch (key) {
        PermissionKey.cost => u.copyWith(canSeeCostOverride: value),
        PermissionKey.finance => u.copyWith(canViewFinanceOverride: value),
        PermissionKey.salary => u.copyWith(canSeeSalaryOverride: value),
        PermissionKey.rentals => u.copyWith(canAccessRentalsOverride: value),
        PermissionKey.people => u.copyWith(canAccessPeopleOverride: value),
        PermissionKey.goods => u.copyWith(canReceiveGoodsOverride: value),
      };

  /// Change a user's role (changes which side they load on next sign-in).
  Future<void> setRole(String id, UserRole role) async {
    state = [
      for (final u in state)
        if (u.id == id) u.copyWith(role: role) else u,
    ];
    await _store.writeAll(state);
  }

  Future<void> deleteUser(String id) async {
    state = state.where((u) => u.id != id).toList();
    await _store.writeAll(state);
  }

  static List<AppUser> _seed() {
    final now = DateTime.now();
    AppUser seed({
      required String id,
      required String fullName,
      required String email,
      required UserRole role,
      required DateTime createdAt,
    }) {
      final pw = PasswordHasher.create(kSeedPassword);
      return AppUser(
        id: id,
        fullName: fullName,
        email: email,
        role: role,
        createdAt: createdAt,
        passwordHash: pw.hash,
        passwordSalt: pw.salt,
      );
    }

    return [
      seed(
        id: 'usr-admin',
        fullName: 'Owner (Admin)',
        email: 'owner@yorksac.ae',
        role: UserRole.admin,
        createdAt: DateTime(now.year - 2, 1, 1),
      ),
      seed(
        id: 'usr-proc',
        fullName: 'Bilal Hassan',
        email: 'bilal.procurement@yorksac.ae',
        role: UserRole.procurement,
        createdAt: DateTime(now.year - 2, 7, 10),
      ),
      seed(
        id: 'usr-eng-1',
        fullName: 'Ahmed Khan',
        email: 'ahmed.khan@yorksac.ae',
        role: UserRole.engineer,
        createdAt: DateTime(now.year - 3, 2, 1),
      ),
      seed(
        id: 'usr-eng-2',
        fullName: 'Imran Khalid',
        email: 'imran.khalid@yorksac.ae',
        role: UserRole.engineer,
        createdAt: DateTime(now.year - 1, 5, 20),
      ),
    ];
  }
}

/// Active-account count (admin dashboard figure).
final activeUserCountProvider = Provider<int>((ref) {
  return ref.watch(usersProvider).where((u) => u.active).length;
});
