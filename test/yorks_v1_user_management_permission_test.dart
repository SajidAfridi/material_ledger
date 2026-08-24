import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/admin/presentation/screens/user_management_screen.dart';
import 'package:material_ledger/shared/models/yorks_v1_permission_management.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/yorks_v1_permission_provider.dart';

void main() {
  test('enforced directory viewer has inspection without mutations', () {
    final access = YorksV1UserManagementAccess.resolve(
      connectedV1: true,
      role: YorksV1Role.projectManager,
      permissionState: _state({
        YorksV1CapabilityKeys.usersView: true,
        YorksV1CapabilityKeys.permissionsView: true,
      }),
    );

    expect(access.canView, isTrue);
    expect(access.canViewPermissions, isTrue);
    expect(access.canCreate, isFalse);
    expect(access.canEditProfile, isFalse);
    expect(access.canAssignRoles, isFalse);
    expect(access.canResetPassword, isFalse);
    expect(access.canManageActivation, isFalse);
    expect(access.canManageUser, isFalse);
    expect(access.canViewAudit, isFalse);
    // The retained commercial RPC still requires an exact Admin/SME actor.
    expect(access.canViewCommercialAccess, isFalse);
  });

  test(
    'activation permission is independent from every other user command',
    () {
      final access = YorksV1UserManagementAccess.resolve(
        connectedV1: true,
        role: YorksV1Role.projectManager,
        permissionState: _state({
          YorksV1CapabilityKeys.usersView: true,
          YorksV1CapabilityKeys.usersActivationManage: true,
        }),
      );

      expect(access.canView, isTrue);
      expect(access.canManageActivation, isTrue);
      expect(access.canManageUser, isTrue);
      expect(access.canCreate, isFalse);
      expect(access.canEditProfile, isFalse);
      expect(access.canAssignRoles, isFalse);
      expect(access.canResetPassword, isFalse);
      expect(access.canViewPermissions, isFalse);
      expect(access.canViewAudit, isFalse);
    },
  );

  test('stale snapshot keeps directory readable and disables every write', () {
    final access = YorksV1UserManagementAccess.resolve(
      connectedV1: true,
      role: YorksV1Role.projectManager,
      permissionState: _state({
        YorksV1CapabilityKeys.usersView: true,
        YorksV1CapabilityKeys.usersCreate: true,
        YorksV1CapabilityKeys.usersActivationManage: true,
      }, stale: true),
    );

    expect(access.canView, isTrue);
    expect(access.canCreate, isFalse);
    expect(access.canManageActivation, isFalse);
  });

  test('connected current account is protected from self deactivation', () {
    expect(
      yorksV1IsProtectedSelfTarget(
        connectedV1: true,
        currentAppUserId: 'actor-app-user',
        targetAppUserId: 'actor-app-user',
      ),
      isTrue,
    );
    expect(
      yorksV1IsProtectedSelfTarget(
        connectedV1: true,
        currentAppUserId: 'actor-app-user',
        targetAppUserId: 'other-app-user',
      ),
      isFalse,
    );
    expect(
      yorksV1IsProtectedSelfTarget(
        connectedV1: false,
        currentAppUserId: 'actor-app-user',
        targetAppUserId: 'actor-app-user',
      ),
      isFalse,
    );
  });
}

YorksV1CurrentPermissionSnapshotState _state(
  Map<String, bool> effective, {
  bool stale = false,
}) => YorksV1CurrentPermissionSnapshotState(
  snapshot: _snapshot(effective),
  isStale: stale,
  isRevisionSignalHealthy: !stale,
);

YorksV1CurrentPermissionSnapshot _snapshot(Map<String, bool> effective) {
  const keys = [
    YorksV1CapabilityKeys.usersView,
    YorksV1CapabilityKeys.usersCreate,
    YorksV1CapabilityKeys.usersProfileEdit,
    YorksV1CapabilityKeys.usersRolesAssign,
    YorksV1CapabilityKeys.usersPasswordReset,
    YorksV1CapabilityKeys.usersActivationManage,
    YorksV1CapabilityKeys.permissionsView,
    YorksV1CapabilityKeys.permissionsManage,
    YorksV1CapabilityKeys.auditView,
  ];
  YorksV1PermissionCapabilityAccess capability(String key) {
    final allowed = effective[key] ?? false;
    final split = key.split('.');
    final catalog = YorksV1PermissionCatalogEntry(
      key: key,
      module: split.first,
      action: split.last,
      label: key,
      description: 'Focused permission test capability.',
      riskLevel: YorksV1PermissionRiskLevel.high,
      allowedScopes: const [YorksV1PermissionScopeKind.organization],
      requiresProjectAccess: false,
      dependencies: const [],
      runtimeStatus: YorksV1PermissionRuntimeStatus.operational,
      isAssignable: true,
      displayOrder: keys.indexOf(key),
    );
    return YorksV1PermissionCapabilityAccess(
      catalog: catalog,
      authorizationMode: YorksV1PermissionCapabilityAuthorizationMode.enforced,
      roleDefault: YorksV1PermissionRoleDefault(
        capabilityKey: key,
        role: YorksV1Role.projectManager,
        isGranted: allowed,
      ),
      organizationSummaryVisible: true,
      authoritativeEffective: allowed,
      authoritativeSource: YorksV1PermissionEffectiveSource.roleDefault,
      candidateEffective: allowed,
      candidateSource: YorksV1PermissionEffectiveSource.roleDefault,
      hasParity: true,
      actorCanDelegate: true,
      actorDelegableScopes: catalog.allowedScopes,
      projectOverrides: const [],
    );
  }

  return YorksV1CurrentPermissionSnapshot(
    schemaVersion: 1,
    authorizationMode: YorksV1PermissionAuthorizationMode.enforced,
    generatedAt: DateTime.utc(2026, 8, 24),
    user: YorksV1PermissionUser(
      appUserId: 'actor-app-user',
      displayName: 'Directory Viewer',
      exactRole: YorksV1Role.projectManager,
      isActive: true,
    ),
    revision: 4,
    capabilities: [for (final key in keys) capability(key)],
    projectAccess: const [],
  );
}
