import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';

const _kUsersKey = 'app_users_v1';
const _uuid = Uuid();

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
  }) async {
    final user = AppUser(
      id: 'usr-${_uuid.v4().substring(0, 8)}',
      fullName: fullName,
      email: email,
      role: role,
      createdAt: DateTime.now(),
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

  static List<AppUser> _seed() {
    final now = DateTime.now();
    return [
      AppUser(
        id: 'usr-admin',
        fullName: 'Owner (Admin)',
        email: 'owner@yorksac.ae',
        role: UserRole.admin,
        createdAt: DateTime(now.year - 2, 1, 1),
      ),
      AppUser(
        id: 'usr-proc',
        fullName: 'Bilal Hassan',
        email: 'bilal.procurement@yorksac.ae',
        role: UserRole.procurement,
        createdAt: DateTime(now.year - 2, 7, 10),
      ),
      AppUser(
        id: 'usr-eng-1',
        fullName: 'Ahmed Khan',
        email: 'ahmed.khan@yorksac.ae',
        role: UserRole.engineer,
        createdAt: DateTime(now.year - 3, 2, 1),
      ),
      AppUser(
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
