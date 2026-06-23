import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/models/app_user.dart';
import 'package:material_ledger/shared/models/effective_permissions.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/users_provider.dart';

AppUser _user(UserRole role) => AppUser(
      id: 'u1',
      fullName: 'X',
      email: 'x@y.z',
      role: role,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  group('Effective permissions (override ?? role default)', () {
    test('with no override, effective = role default', () {
      final eng = _user(UserRole.engineer);
      expect(eng.effectiveCanSeeCost, false); // engineer default
      expect(eng.overrideFor(PermissionKey.cost), isNull);

      final proc = _user(UserRole.procurement);
      expect(proc.effectiveCanSeeCost, true); // procurement default
      expect(proc.effectiveCanViewFinance, false); // finance is admin-only
    });

    test('an override wins over the role default', () {
      final eng = _user(UserRole.engineer).copyWith(canViewFinanceOverride: true);
      expect(eng.effectiveCanViewFinance, true);
      expect(eng.overrideFor(PermissionKey.finance), true);

      final proc =
          _user(UserRole.procurement).copyWith(canSeeCostOverride: false);
      expect(proc.effectiveCanSeeCost, false); // revoked despite role default
    });

    test('revoking access also revokes the matching write capability', () {
      final proc = _user(UserRole.procurement)
          .copyWith(canAccessRentalsOverride: false);
      expect(proc.effectiveCanAccessRentals, false);
      expect(proc.effectiveCanWriteRentals, false);
    });
  });

  group('Admin permission management', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
    });

    UsersNotifier users() => container.read(usersProvider.notifier);
    AppUser byId(String id) =>
        container.read(usersProvider).firstWhere((u) => u.id == id);

    test('setPermissionOverride sets and clears an override', () async {
      final eng = container
          .read(usersProvider)
          .firstWhere((u) => u.role == UserRole.engineer);

      await users().setPermissionOverride(eng.id, PermissionKey.finance, true);
      expect(byId(eng.id).effectiveCanViewFinance, true);

      // Clearing (null) returns to the role default (engineer: false).
      await users().setPermissionOverride(eng.id, PermissionKey.finance, null);
      expect(byId(eng.id).overrideFor(PermissionKey.finance), isNull);
      expect(byId(eng.id).effectiveCanViewFinance, false);
    });

    test('setRole changes the user role', () async {
      final eng = container
          .read(usersProvider)
          .firstWhere((u) => u.role == UserRole.engineer);
      await users().setRole(eng.id, UserRole.procurement);
      expect(byId(eng.id).role, UserRole.procurement);
    });

    test('deleteUser removes the account', () async {
      final eng = container
          .read(usersProvider)
          .firstWhere((u) => u.role == UserRole.engineer);
      final before = container.read(usersProvider).length;
      await users().deleteUser(eng.id);
      expect(container.read(usersProvider).length, before - 1);
      expect(container.read(usersProvider).any((u) => u.id == eng.id), false);
    });
  });
}
