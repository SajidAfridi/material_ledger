import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/effective_permissions.dart';
import '../models/role_permissions.dart';
import '../models/user_role.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';
import '../services/password_hasher.dart';
import 'language_provider.dart';
import 'role_permissions_provider.dart';

// Bumped to v3 to re-seed the simplified one-account-per-role set (owner /
// alasad / imrankhan, password test@123) over any previously-seeded users.
const _kUsersKey = 'app_users_v3';
const _uuid = Uuid();

/// Default password for the seeded demo accounts (internal first-run only).
/// Real accounts are created by Admin with their own password.
const kSeedPassword = 'test@123';

/// All system user accounts. Admin-managed only (no self-signup).
///
/// When Supabase is configured, every account operation that must reach the
/// identity provider (create, change role/claims, reset password, deactivate,
/// delete) is executed by the `admin-users` Edge Function using the service_role
/// key — the client never holds that key. The local list is the admin-facing
/// roster/cache; the JWT is the source of truth for identity, role and caps.
final usersProvider = StateNotifierProvider<UsersNotifier, List<AppUser>>((ref) {
  return UsersNotifier(
    ref,
    ref.watch(storageProvider).collection<AppUser>(
      _kUsersKey,
      toJson: (u) => u.toJson(),
      fromJson: AppUser.fromJson,
    ),
  );
});

class UsersNotifier extends StateNotifier<List<AppUser>> {
  UsersNotifier(this._ref, this._store) : super([]) {
    state = _store.isSeeded ? _store.readAll() : _seed();
    if (!_store.isSeeded) _store.writeAll(state);
  }

  final Ref _ref;
  final CollectionStore<AppUser> _store;

  SupabaseClient? get _client => _ref.read(supabaseClientProvider);

  /// The capabilities to stamp into a user's JWT claim, so server-side RLS
  /// matches the app exactly: per-user overrides on top of the LIVE Access &
  /// Roles matrix (not just the built-in role baseline).
  List<String> _claimCaps(AppUser user) {
    final perms = _ref.read(rolePermissionsProvider);
    return [
      for (final cap in RoleCapability.values)
        if (resolveCapability(user, user.role, perms, cap)) cap.name,
    ];
  }

  /// Re-stamp JWT caps for every (non-admin) user of [role] after the role
  /// matrix changed, so server-side RLS immediately tracks the admin's edit
  /// rather than diverging from the shown access. A no-op (returns 0) when
  /// Supabase isn't configured (tests / offline).
  ///
  /// Returns the number of users whose re-stamp FAILED. One user's failure
  /// doesn't block the rest, but the count is surfaced to the admin rather than
  /// swallowed — a partial failure means those users' server-side access lags
  /// the matrix until they next sign in (which re-issues a fresh claim).
  Future<int> restampRoleClaims(UserRole role) async {
    if (_client == null || role == UserRole.admin) return 0;
    var failures = 0;
    for (final u in state) {
      if (u.role != role) continue;
      try {
        await _adminFn({
          'action': 'updateClaims',
          'appUserId': u.id,
          'role': u.role.name,
          'caps': _claimCaps(u),
        });
      } catch (_) {
        failures++;
      }
    }
    return failures;
  }

  /// Calls the privileged `admin-users` function. A no-op (returns null) when no
  /// Supabase backend is configured — widget tests and pure-offline dev keep the
  /// legacy local-only behaviour. Throws on a remote failure so the caller can
  /// surface it and NOT apply the local change (keeps the two in step).
  Future<Map<String, dynamic>?> _adminFn(Map<String, dynamic> body) async {
    final client = _client;
    if (client == null) return null;
    try {
      final res = await client.functions.invoke('admin-users', body: body);
      final data = res.data;
      if (data is Map && (data['ok'] == true || data['authUserId'] != null)) {
        return Map<String, dynamic>.from(data);
      }
      throw Exception(
        'User service error: ${data is Map ? data['error'] : data}',
      );
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = (d is Map && d['error'] != null)
          ? d['error']
          : (e.reasonPhrase ?? 'request failed');
      throw Exception('User service error: $msg');
    }
  }

  Future<AppUser> createUser({
    required String fullName,
    required String email,
    required UserRole role,
    required String password,
  }) async {
    final id = 'usr-${_uuid.v4().substring(0, 8)}';
    final draft = AppUser(
      id: id,
      fullName: fullName,
      email: email,
      role: role,
      createdAt: DateTime.now(),
    );
    // Provision in the identity provider first; a failure (e.g. duplicate email)
    // throws before anything is written locally.
    await _adminFn({
      'action': 'create',
      'email': email,
      'password': password,
      'fullName': fullName,
      'role': role.name,
      'appUserId': id,
      'caps': _claimCaps(draft),
    });
    final pw = PasswordHasher.create(password);
    final user = draft.copyWith(
      passwordHash: pw.hash,
      passwordSalt: pw.salt,
      // The admin set a temporary password; the user changes it on first login.
      mustChangePassword: true,
    );
    state = [user, ...state];
    await _store.writeAll(state);
    return user;
  }

  /// Materialise a user from their JWT claims when they aren't already in this
  /// device's roster (they were provisioned on another device). Existing records
  /// are kept untouched so their overrides / employee link survive.
  Future<void> upsertFromClaims({
    required String id,
    required String email,
    required UserRole role,
    required String fullName,
    bool mustChangePassword = false,
  }) async {
    final existing = _byId(id);
    if (existing != null) {
      // The user is already in this device's roster. Reconcile ONLY the
      // authoritative must-change flag from the claim (leave local overrides /
      // employee link untouched) so a change made on another device is honoured.
      if (existing.mustChangePassword != mustChangePassword) {
        state = [
          for (final u in state)
            if (u.id == id)
              u.copyWith(mustChangePassword: mustChangePassword)
            else
              u,
        ];
        await _store.writeAll(state);
      }
      return;
    }
    final user = AppUser(
      id: id,
      fullName: fullName.trim().isEmpty ? email : fullName,
      email: email,
      role: role,
      mustChangePassword: mustChangePassword,
      createdAt: DateTime.now(),
    );
    state = [user, ...state];
    await _store.writeAll(state);
  }

  Future<void> update(AppUser updated) async {
    state = [
      for (final u in state)
        if (u.id == updated.id) updated else u,
    ];
    await _store.writeAll(state);
  }

  AppUser? _byId(String id) {
    for (final u in state) {
      if (u.id == id) return u;
    }
    return null;
  }

  /// True if [id] is the ONLY currently-active admin — used to block the last
  /// admin from being demoted or deactivated, which would lock everyone out of
  /// the admin panel with no in-app recovery.
  bool _isLastActiveAdmin(String id) {
    final admins = state.where((u) => u.role == UserRole.admin && u.active);
    return admins.length == 1 && admins.first.id == id;
  }

  /// Update ONLY the local roster's password hash + must-change flag, WITHOUT
  /// calling the privileged admin Edge Function. Used by self-service password
  /// change ([AuthController.changeOwnPassword]), where the identity provider is
  /// updated separately via the caller's own GoTrue self-update — so a non-admin
  /// never has to (and can't) hit the admin-only function. Keeps local + cloud
  /// in step for the credential fallback / offline sign-in.
  Future<void> applyLocalPassword(
    String id,
    String newPassword, {
    required bool mustChange,
  }) async {
    final pw = PasswordHasher.create(newPassword);
    state = [
      for (final u in state)
        if (u.id == id)
          u.copyWith(
            passwordHash: pw.hash,
            passwordSalt: pw.salt,
            mustChangePassword: mustChange,
          )
        else
          u,
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
    await _adminFn({
      'action': 'setPassword',
      'appUserId': id,
      'password': newPassword,
    });
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

  /// Activate/deactivate an account. Refuses to deactivate the last active admin
  /// (would lock everyone out). Returns false if blocked. A deactivated user is
  /// banned in the identity provider, so they can no longer sign in on ANY device.
  Future<bool> setActive(String id, bool active) async {
    if (!active && _isLastActiveAdmin(id)) return false;
    await _adminFn({'action': 'setActive', 'appUserId': id, 'active': active});
    state = [
      for (final u in state)
        if (u.id == id) u.copyWith(active: active) else u,
    ];
    await _store.writeAll(state);
    return true;
  }

  /// Inventory access is an engineer-only flag (office roles get materials via
  /// their own tabs) — ignore it for any other role. Local-only (not an identity
  /// concern), so no remote call.
  Future<void> setInventoryAccess(String id, bool access) async {
    if (_byId(id)?.role != UserRole.engineer) return;
    state = [
      for (final u in state)
        if (u.id == id) u.copyWith(inventoryAccess: access) else u,
    ];
    await _store.writeAll(state);
  }

  /// Set (or clear, with `null`) a per-user capability override. Clearing
  /// returns that capability to the role default. Server-relevant caps
  /// (rentals/people/goods/…) are re-stamped into the user's JWT claim so RLS
  /// tracks the change.
  Future<void> setPermissionOverride(
    String id,
    PermissionKey key,
    bool? value,
  ) async {
    // Admin always hard-grants everything, so an override would be dead state.
    final current = _byId(id);
    if (current == null || current.role == UserRole.admin) return;
    final updated = _applyOverride(current, key, value);
    await _adminFn({
      'action': 'updateClaims',
      'appUserId': id,
      'role': updated.role.name,
      'caps': _claimCaps(updated),
    });
    state = [
      for (final u in state)
        if (u.id == id) updated else u,
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

  /// Change a user's role (changes which side they load on next sign-in, and
  /// re-stamps their JWT role/caps claims). Refuses to demote the last active
  /// admin. Returns false if blocked.
  Future<bool> setRole(String id, UserRole role) async {
    if (role != UserRole.admin && _isLastActiveAdmin(id)) return false;
    final current = _byId(id);
    if (current == null) return false;
    final updated = current.copyWith(role: role);
    await _adminFn({
      'action': 'updateClaims',
      'appUserId': id,
      'role': role.name,
      'caps': _claimCaps(updated),
    });
    state = [
      for (final u in state)
        if (u.id == id) updated else u,
    ];
    await _store.writeAll(state);
    return true;
  }

  /// Permanently delete an account. Refuses to delete the last active admin —
  /// that would leave the system with no way back into the admin panel (there is
  /// no self-signup). Returns false if blocked, mirroring [setActive]/[setRole].
  Future<bool> deleteUser(String id) async {
    if (_isLastActiveAdmin(id)) return false;
    await _adminFn({'action': 'delete', 'appUserId': id});
    state = state.where((u) => u.id != id).toList();
    await _store.writeAll(state);
    return true;
  }

  /// Link (or unlink, with `null`) this login to an HR roster [Employee] — so
  /// the person's leave requests, balance, and HR profile become one record.
  /// Local-only (an HR mapping, not an identity-provider concern). An employee
  /// maps to exactly one login, so a duplicate link is rejected. Returns false
  /// if blocked.
  Future<bool> setEmployeeLink(String id, String? employeeId) async {
    if (employeeId != null &&
        state.any((u) => u.id != id && u.employeeId == employeeId)) {
      return false;
    }
    state = [
      for (final u in state)
        if (u.id == id) u.copyWith(employeeId: employeeId) else u,
    ];
    await _store.writeAll(state);
    return true;
  }

  static List<AppUser> _seed() {
    final now = DateTime.now();
    AppUser seed({
      required String id,
      required String fullName,
      required String email,
      required UserRole role,
      required DateTime createdAt,
      String? employeeId,
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
        employeeId: employeeId,
      );
    }

    // Exactly one account per role, so the dev role-switcher signs into a
    // distinct person each time (not one identity wearing three hats).
    return [
      seed(
        id: 'usr-admin',
        fullName: 'Owner',
        email: 'owner@gmail.com',
        role: UserRole.admin,
        createdAt: DateTime(now.year - 2, 1, 1),
      ),
      seed(
        id: 'usr-proc',
        fullName: 'Al Asad',
        email: 'alasad@gmail.com',
        role: UserRole.procurement,
        createdAt: DateTime(now.year - 2, 7, 10),
        employeeId: 'emp-002', // linked to the HR roster
      ),
      seed(
        id: 'usr-eng',
        fullName: 'Imran Khan',
        email: 'imrankhan@gmail.com',
        role: UserRole.engineer,
        createdAt: DateTime(now.year - 3, 2, 1),
        employeeId: 'emp-001', // linked to the HR roster
      ),
    ];
  }
}

/// Active-account count (admin dashboard figure).
final activeUserCountProvider = Provider<int>((ref) {
  return ref.watch(usersProvider).where((u) => u.active).length;
});
