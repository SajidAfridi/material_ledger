import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/user_role.dart';

void main() {
  group('UserRole capability matrix (3 roles: engineer/procurement/admin)', () {
    test('only three roles exist — accountant merged into admin', () {
      expect(UserRole.values, [
        UserRole.engineer,
        UserRole.procurement,
        UserRole.admin,
      ]);
    });

    test('cost visibility — Admin/Procurement only (FR-092)', () {
      expect(UserRole.admin.canSeeCost, true);
      expect(UserRole.procurement.canSeeCost, true);
      expect(UserRole.engineer.canSeeCost, false);
    });

    test('salary visibility — Admin only (FR-128)', () {
      expect(UserRole.admin.canSeeSalary, true);
      expect(UserRole.procurement.canSeeSalary, false);
      expect(UserRole.engineer.canSeeSalary, false);
    });

    test('rentals access + write — Procurement/Admin', () {
      expect(UserRole.procurement.canAccessRentals, true);
      expect(UserRole.admin.canAccessRentals, true);
      expect(UserRole.engineer.canAccessRentals, false);

      expect(UserRole.procurement.canWriteRentals, true);
      expect(UserRole.admin.canWriteRentals, true);
      expect(UserRole.engineer.canWriteRentals, false);
    });

    test('people/HR access + write — Procurement/Admin (HR moved to procurement)',
        () {
      expect(UserRole.procurement.canAccessPeople, true);
      expect(UserRole.admin.canAccessPeople, true);
      expect(UserRole.engineer.canAccessPeople, false);

      expect(UserRole.procurement.canWritePeople, true);
      expect(UserRole.admin.canWritePeople, true);
      expect(UserRole.engineer.canWritePeople, false);
    });

    test('goods receipt — Procurement/Admin; finance — Admin only', () {
      expect(UserRole.procurement.canReceiveGoods, true);
      expect(UserRole.admin.canReceiveGoods, true);
      expect(UserRole.engineer.canReceiveGoods, false);

      expect(UserRole.admin.canViewFinance, true);
      expect(UserRole.procurement.canViewFinance, false);
      expect(UserRole.engineer.canViewFinance, false);
    });

    test('engineer is the only mobile (non-admin-panel) role', () {
      expect(UserRole.engineer.usesAdminPanel, false);
      expect(UserRole.procurement.usesAdminPanel, true);
      expect(UserRole.admin.usesAdminPanel, true);
    });

    test('all roles can access Materials', () {
      for (final r in UserRole.values) {
        expect(r.canAccessMaterials, true);
      }
    });

    test('fromName round-trips; legacy "accountant" falls back to engineer', () {
      for (final r in UserRole.values) {
        expect(UserRole.fromName(r.name), r);
      }
      expect(UserRole.fromName('accountant'), UserRole.engineer);
      expect(UserRole.fromName('nonsense'), UserRole.engineer);
    });
  });
}
