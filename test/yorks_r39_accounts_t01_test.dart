import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/app_user.dart';
import 'package:material_ledger/shared/models/role_permissions.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_accounts_capability.dart';
import 'package:material_ledger/shared/models/yorks_v1_permission_management.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';

void main() {
  group('R39 Accountant identity foundation', () {
    test(
      'exact server claim and local profile round-trip without promotion',
      () {
        expect(
          YorksV1Role.fromServerClaim('accountant'),
          YorksV1Role.accountant,
        );
        expect(YorksV1Role.fromServerClaim('Accountant'), isNull);
        expect(YorksV1Role.fromServerClaim(' accountant '), isNull);
        expect(
          userRoleFromAppMetadata(const {'role': 'accountant'}),
          UserRole.accountant,
        );

        final original = AppUser(
          id: 'accountant-user',
          fullName: 'Accounts User',
          email: 'accounts@yorks.test',
          role: UserRole.accountant,
          createdAt: DateTime.utc(2026, 8, 25),
          yorksV1RoleCache: YorksV1Role.accountant,
          yorksV1Roles: const [YorksV1Role.accountant],
        );
        final decoded = AppUser.fromJson(original.toJson());

        expect(decoded.role, UserRole.accountant);
        expect(decoded.yorksV1RoleCache, YorksV1Role.accountant);
        expect(decoded.effectiveYorksV1Roles, const [YorksV1Role.accountant]);
      },
    );

    test('Accountant has zero retained technical authority', () {
      const exact = YorksV1Role.accountant;
      expect(exact.isEngineering, isFalse);
      expect(exact.isGlobalProjectEngineer, isFalse);
      expect(exact.canCreateProject, isFalse);
      expect(exact.canCreateMaterialRequest, isFalse);
      expect(exact.canCreateMaterialReturn, isFalse);
      expect(exact.canManageProjectMembers, isFalse);
      expect(exact.canSetProjectState, isFalse);
      expect(exact.canConfigureUsers, isFalse);
      expect(exact.canBrowseInventory, isFalse);
      expect(exact.canManageInventory, isFalse);

      final compatibilityUser = AppUser(
        id: 'accountant-user',
        fullName: 'Accounts User',
        email: 'accounts@yorks.test',
        role: UserRole.accountant,
        createdAt: DateTime.utc(2026, 8, 25),
        canSeeCostOverride: true,
        canViewFinanceOverride: true,
        canAccessRentalsOverride: true,
        canAccessPeopleOverride: true,
        canReceiveGoodsOverride: true,
      );
      final defaults = RolePermissions.fromRoleDefaults();
      for (final capability in RoleCapability.values) {
        expect(
          resolveCapability(
            compatibilityUser,
            UserRole.accountant,
            defaults,
            capability,
          ),
          isFalse,
          reason: capability.name,
        );
      }
    });

    test('protected user-admin options can provision the exact role', () {
      final options = YorksV1UserAdminOptions.fromRpcJson(const {
        'schema_version': YorksV1PermissionSchema.current,
        'target_app_user_id': null,
        'assignable_exact_roles': ['accountant'],
        'can_assign_role': true,
        'can_reset_password': false,
        'can_manage_activation': false,
      });

      expect(options.assignableExactRoles, const [YorksV1Role.accountant]);
      expect(options.allowsRole(YorksV1Role.accountant), isTrue);
      expect(options.allowsRole(YorksV1Role.admin), isFalse);
    });
  });

  group('R39 Accounts capability vocabulary', () {
    const canonical = <String>{
      'view_project_accounts',
      'view_project_commercial_values',
      'suggest_billing_progress',
      'confirm_billing_progress',
      'prepare_client_claim',
      'manage_client_invoices',
      'record_client_certification',
      'record_client_payment',
      'manage_pdc',
      'manage_supplier_bills',
      'approve_supplier_bill_payment',
      'configure_project_commercials',
      'view_supplier_costs',
      'export_accounts_registers',
      'review_commercial_progress',
    };

    test('uses exactly the 15 canonical snake_case keys', () {
      expect(YorksV1AccountsCapability.values, hasLength(15));
      expect(YorksV1AccountsCapability.allCapabilityKeys, canonical);
      expect(canonical.every(YorksV1CapabilityKeys.all.contains), isTrue);
      for (final capability in YorksV1AccountsCapability.values) {
        expect(
          YorksV1AccountsCapability.fromCapabilityKey(capability.capabilityKey),
          capability,
        );
      }
    });

    test('legacy dotted accounts keys never become R39 authority', () {
      for (final legacyKey in const [
        YorksV1CapabilityKeys.accountsView,
        YorksV1CapabilityKeys.accountsEdit,
        YorksV1CapabilityKeys.accountsApprove,
        YorksV1CapabilityKeys.accountsExport,
      ]) {
        expect(YorksV1CapabilityKeys.all, contains(legacyKey));
        expect(YorksV1AccountsCapability.fromCapabilityKey(legacyKey), isNull);
      }
    });

    test('permission catalogue accepts only the 15 canonical bare keys', () {
      for (final key in canonical) {
        final entry = YorksV1PermissionCatalogEntry(
          key: key,
          module: 'accounts',
          action: key,
          label: 'R39 Accounts capability',
          description: 'Protected R39 Accounts authority.',
          riskLevel: YorksV1PermissionRiskLevel.high,
          allowedScopes: const [YorksV1PermissionScopeKind.project],
          requiresProjectAccess: true,
          dependencies: [key],
          runtimeStatus: YorksV1PermissionRuntimeStatus.operational,
          isAssignable: true,
          displayOrder: 1,
        );

        expect(entry.isClientRecognized, isTrue);
        expect(entry.isOperational, isTrue);
        expect(entry.canAssignFromThisClient, isTrue);
      }
      expect(
        () => YorksV1PermissionCatalogEntry(
          key: 'unknown_accounts_capability',
          module: 'accounts',
          action: 'unknown_accounts_capability',
          label: 'Unknown',
          description: 'Unknown bare key.',
          riskLevel: YorksV1PermissionRiskLevel.high,
          allowedScopes: const [YorksV1PermissionScopeKind.project],
          requiresProjectAccess: true,
          dependencies: const [],
          runtimeStatus: YorksV1PermissionRuntimeStatus.operational,
          isAssignable: true,
          displayOrder: 1,
        ),
        throwsFormatException,
      );
      expect(
        () => YorksV1PermissionCatalogEntry(
          key: YorksV1CapabilityKeys.viewProjectAccounts,
          module: 'accounts',
          action: 'view_project_accounts',
          label: 'Unknown dependency',
          description: 'Unknown bare dependency key.',
          riskLevel: YorksV1PermissionRiskLevel.high,
          allowedScopes: const [YorksV1PermissionScopeKind.project],
          requiresProjectAccess: true,
          dependencies: const ['unknown_accounts_capability'],
          runtimeStatus: YorksV1PermissionRuntimeStatus.operational,
          isAssignable: true,
          displayOrder: 1,
        ),
        throwsFormatException,
      );
      expect(
        () => YorksV1PermissionCatalogEntry(
          key: 'view-project-accounts',
          module: 'accounts',
          action: 'view_project_accounts',
          label: 'Invalid',
          description: 'Invalid separator.',
          riskLevel: YorksV1PermissionRiskLevel.high,
          allowedScopes: const [YorksV1PermissionScopeKind.project],
          requiresProjectAccess: true,
          dependencies: const [],
          runtimeStatus: YorksV1PermissionRuntimeStatus.operational,
          isAssignable: true,
          displayOrder: 1,
        ),
        throwsFormatException,
      );
    });
  });
}
