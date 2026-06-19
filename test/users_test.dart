import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/users_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
  });

  group('User management (admin panel §4.7)', () {
    test('seeds accounts and counts active users', () {
      final users = container.read(usersProvider);
      expect(users, isNotEmpty);
      expect(users.any((u) => u.role == UserRole.admin), true);
      expect(
        container.read(activeUserCountProvider),
        users.where((u) => u.active).length,
      );
    });

    test('admin creates a user (no self-signup path)', () async {
      final before = container.read(usersProvider).length;
      final u = await container.read(usersProvider.notifier).createUser(
            fullName: 'New Engineer',
            email: 'new.eng@yorksac.ae',
            role: UserRole.engineer,
          );
      expect(container.read(usersProvider).length, before + 1);
      expect(u.active, true);
      expect(u.role, UserRole.engineer);
    });

    test('deactivating a user flips active + lowers the active count', () async {
      final u = container.read(usersProvider).firstWhere(
        (x) => x.role == UserRole.engineer,
      );
      final activeBefore = container.read(activeUserCountProvider);
      await container.read(usersProvider.notifier).setActive(u.id, false);
      expect(
        container.read(usersProvider).firstWhere((x) => x.id == u.id).active,
        false,
      );
      expect(container.read(activeUserCountProvider), activeBefore - 1);
    });

    test('granting / revoking inventory access toggles the flag', () async {
      final u = container.read(usersProvider).firstWhere(
        (x) => x.role == UserRole.engineer,
      );
      await container.read(usersProvider.notifier).setInventoryAccess(
            u.id,
            false,
          );
      expect(
        container
            .read(usersProvider)
            .firstWhere((x) => x.id == u.id)
            .inventoryAccess,
        false,
      );
      await container.read(usersProvider.notifier).setInventoryAccess(u.id, true);
      expect(
        container
            .read(usersProvider)
            .firstWhere((x) => x.id == u.id)
            .inventoryAccess,
        true,
      );
    });
  });
}
