import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/app_user.dart';
import 'package:material_ledger/shared/models/role_permissions.dart';
import 'package:material_ledger/shared/models/user_role.dart';

AppUser _user(UserRole role, {bool? costOverride, bool? rentalsOverride}) =>
    AppUser(
      id: 'u1',
      fullName: 'Test User',
      email: 't@x.com',
      role: role,
      createdAt: DateTime(2024, 1, 1),
      canSeeCostOverride: costOverride,
      canAccessRentalsOverride: rentalsOverride,
    );

void main() {
  group('RolePermissions seeding', () {
    test('fromRoleDefaults matches the built-in UserRole baseline', () {
      final perms = RolePermissions.fromRoleDefaults();
      for (final role in editableRoles) {
        for (final cap in RoleCapability.values) {
          expect(
            perms.has(role, cap),
            cap.defaultFor(role),
            reason: '${role.name}.${cap.name} should equal the seed default',
          );
        }
      }
    });

    test('Admin is always-true (locked superuser) for every capability', () {
      final perms = RolePermissions.fromRoleDefaults();
      for (final cap in RoleCapability.values) {
        expect(perms.has(UserRole.admin, cap), isTrue);
      }
    });
  });

  group('setCapability', () {
    test('grant then revoke is reflected by has()', () {
      var perms = RolePermissions.fromRoleDefaults();
      // Engineer has no rentals by default.
      expect(perms.has(UserRole.engineer, RoleCapability.rentals), isFalse);

      perms = perms.setCapability(UserRole.engineer, RoleCapability.rentals, true);
      expect(perms.has(UserRole.engineer, RoleCapability.rentals), isTrue);

      perms =
          perms.setCapability(UserRole.engineer, RoleCapability.rentals, false);
      expect(perms.has(UserRole.engineer, RoleCapability.rentals), isFalse);
    });

    test('editing one role does not change another', () {
      final perms = RolePermissions.fromRoleDefaults()
          .setCapability(UserRole.engineer, RoleCapability.cost, true);
      expect(perms.has(UserRole.engineer, RoleCapability.cost), isTrue);
      expect(
        perms.has(UserRole.procurement, RoleCapability.cost),
        RoleCapability.cost.defaultFor(UserRole.procurement),
      );
    });

    test('editing Admin is a no-op (returns identical instance)', () {
      final perms = RolePermissions.fromRoleDefaults();
      final next =
          perms.setCapability(UserRole.admin, RoleCapability.cost, false);
      expect(identical(perms, next), isTrue);
      expect(next.has(UserRole.admin, RoleCapability.cost), isTrue);
    });
  });

  group('resetRole', () {
    test('restores a role to its built-in defaults', () {
      var perms = RolePermissions.fromRoleDefaults()
          .setCapability(UserRole.procurement, RoleCapability.rentals, false)
          .setCapability(UserRole.procurement, RoleCapability.cost, false);

      perms = perms.resetRole(UserRole.procurement);
      for (final cap in RoleCapability.values) {
        expect(
          perms.has(UserRole.procurement, cap),
          cap.defaultFor(UserRole.procurement),
        );
      }
    });
  });

  group('JSON round-trip & back-compat', () {
    test('toJson/fromJson preserves edited grants', () {
      final perms = RolePermissions.fromRoleDefaults()
          .setCapability(UserRole.engineer, RoleCapability.rentals, true)
          .setCapability(UserRole.procurement, RoleCapability.cost, false);

      final restored = RolePermissions.fromJson(perms.toJson());
      expect(restored.has(UserRole.engineer, RoleCapability.rentals), isTrue);
      expect(restored.has(UserRole.procurement, RoleCapability.cost), isFalse);
    });

    test('missing role in JSON seeds from defaults', () {
      // Simulate older persisted data with only one role present.
      final partial = {
        UserRole.engineer.name: <String>[RoleCapability.rentals.name],
      };
      final perms = RolePermissions.fromJson(partial);
      // Procurement absent → falls back to seed defaults.
      for (final cap in RoleCapability.values) {
        expect(
          perms.has(UserRole.procurement, cap),
          cap.defaultFor(UserRole.procurement),
        );
      }
      // Engineer present → only the listed cap is granted.
      expect(perms.has(UserRole.engineer, RoleCapability.rentals), isTrue);
      expect(perms.has(UserRole.engineer, RoleCapability.cost), isFalse);
    });

    test('unknown capability names in JSON are ignored', () {
      final json = {
        UserRole.engineer.name: ['rentals', 'bogusCapability'],
        UserRole.procurement.name: <String>[],
      };
      final perms = RolePermissions.fromJson(json);
      expect(perms.has(UserRole.engineer, RoleCapability.rentals), isTrue);
      // Procurement explicitly empty → nothing granted.
      expect(perms.has(UserRole.procurement, RoleCapability.cost), isFalse);
    });
  });

  group('resolveCapability layering', () {
    test('per-user override beats the (edited) role default', () {
      // Edit procurement cost OFF at the role level...
      final perms = RolePermissions.fromRoleDefaults()
          .setCapability(UserRole.procurement, RoleCapability.cost, false);
      expect(perms.has(UserRole.procurement, RoleCapability.cost), isFalse);

      // ...but a per-user override of TRUE still wins.
      final user = _user(UserRole.procurement, costOverride: true);
      expect(
        resolveCapability(user, UserRole.procurement, perms, RoleCapability.cost),
        isTrue,
      );
    });

    test('override of false hides a granted role default', () {
      final perms = RolePermissions.fromRoleDefaults();
      // Engineer rentals granted at role level for this case.
      final granted =
          perms.setCapability(UserRole.engineer, RoleCapability.rentals, true);
      expect(granted.has(UserRole.engineer, RoleCapability.rentals), isTrue);

      final user = _user(UserRole.engineer, rentalsOverride: false);
      expect(
        resolveCapability(
            user, UserRole.engineer, granted, RoleCapability.rentals),
        isFalse,
      );
    });

    test('no override → falls through to the role default', () {
      final perms = RolePermissions.fromRoleDefaults();
      final user = _user(UserRole.procurement);
      expect(
        resolveCapability(user, UserRole.procurement, perms, RoleCapability.cost),
        perms.has(UserRole.procurement, RoleCapability.cost),
      );
    });

    test('writes have no override key — resolve straight from role default', () {
      final perms = RolePermissions.fromRoleDefaults()
          .setCapability(UserRole.procurement, RoleCapability.writeRentals, false);
      // Even with an unrelated user override set, writeRentals follows the role.
      final user = _user(UserRole.procurement, costOverride: true);
      expect(
        resolveCapability(
            user, UserRole.procurement, perms, RoleCapability.writeRentals),
        isFalse,
      );
    });
  });
}
