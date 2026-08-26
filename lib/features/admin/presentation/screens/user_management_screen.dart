import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/feedback/feedback_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/effective_permissions.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/models/yorks_v1_commercial_capability.dart';
import '../../../../shared/models/yorks_v1_domain_error.dart';
import '../../../../shared/models/yorks_v1_permission_management.dart';
import '../../../../shared/models/yorks_v1_project_strings.dart';
import '../../../../shared/models/yorks_v1_permission_strings.dart';
import '../../../../shared/models/yorks_v1_role.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/hr_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/session_provider.dart';
import '../../../../shared/providers/users_provider.dart';
import '../../../../shared/providers/yorks_v1_commercial_capability_provider.dart';
import '../../../../shared/providers/yorks_v1_identity_provider.dart';
import '../../../../shared/providers/yorks_v1_permission_provider.dart';

/// Strips the `Exception: ` prefix so remote-provisioning errors read cleanly in
/// a snackbar.
String _friendlyErr(Object e) {
  final s = e.toString();
  const p = 'Exception: ';
  return s.startsWith(p) ? s.substring(p.length) : s;
}

String _permissionCopy(AppLanguage language, String key, {String? name}) =>
    YorksV1PermissionStrings.text(
      language,
      key,
    ).replaceAll('{name}', name ?? '');

List<YorksV1Role> _displayYorksV1Roles(AppUser user) =>
    user.yorksV1RoleCache == null
    ? const <YorksV1Role>[]
    : <YorksV1Role>[user.yorksV1RoleCache!];

/// Display-only role text for the retained roster. V1 authorization never uses
/// this cache; server commands and route guards read the current exact claim.
String _roleLabel(AppUser user, {required bool yorksV1Provisioning}) {
  if (!yorksV1Provisioning) return user.role.label;
  final roles = _displayYorksV1Roles(user);
  return roles.isEmpty
      ? AppStrings.yorksV1RoleMappingRequired.primary
      : roles.map((role) => _yorksV1RoleText(role).primary).join(' · ');
}

String _roleFamilyLabel(
  AppUser user, {
  required bool yorksV1Provisioning,
  required AppLanguage language,
}) {
  if (!yorksV1Provisioning) return user.role.label;
  final roles = _displayYorksV1Roles(user);
  if (roles.any((role) => role.isEngineering)) {
    return _permissionCopy(language, 'role_family.engineering');
  }
  if (roles.contains(YorksV1Role.procurement)) {
    return _permissionCopy(language, 'role_family.procurement');
  }
  if (roles.contains(YorksV1Role.admin)) {
    return _permissionCopy(language, 'role_family.admin');
  }
  return _permissionCopy(language, 'unassigned');
}

String _roleTitleLabel(
  AppUser user, {
  required bool yorksV1Provisioning,
  required AppLanguage language,
}) {
  if (!yorksV1Provisioning) return user.role.label;
  final roles = _displayYorksV1Roles(user);
  if (roles.isEmpty) return _permissionCopy(language, 'unassigned');
  return roles
      .map((role) => _yorksV1RoleText(role).active(language))
      .join(' · ');
}

TranslatableString _yorksV1RoleText(YorksV1Role role) => switch (role) {
  YorksV1Role.projectEngineer => AppStrings.projectEngineerRole,
  YorksV1Role.siteEngineer => AppStrings.siteEngineerRole,
  YorksV1Role.seniorMechanicalEngineer =>
    AppStrings.seniorMechanicalEngineerRole,
  YorksV1Role.projectManager => AppStrings.projectManagerRole,
  YorksV1Role.workshopInCharge => AppStrings.workshopInChargeRole,
  YorksV1Role.documentController => AppStrings.documentControllerRole,
  YorksV1Role.accountant => AppStrings.accountantRole,
  YorksV1Role.procurement => AppStrings.procurementRole,
  YorksV1Role.admin => AppStrings.adminRole,
};

/// The per-user capabilities an Admin can grant/revoke, with display labels.
const _managedPermissions = <(PermissionKey, String)>[
  (PermissionKey.viewCommercials, 'View commercials'),
  (PermissionKey.finance, 'Financial reports'),
  (PermissionKey.salary, 'Salary & HR documents'),
  (PermissionKey.rentals, 'Rentals module'),
  (PermissionKey.people, 'People / HR module'),
  (PermissionKey.goods, 'Receive goods (stock-in)'),
];

typedef _UserManagementBusyCommand =
    Future<void> Function(Future<void> Function() command);

@visibleForTesting
bool yorksV1IsProtectedSelfTarget({
  required bool connectedV1,
  required String? currentAppUserId,
  required String targetAppUserId,
}) =>
    connectedV1 &&
    currentAppUserId != null &&
    currentAppUserId.trim().isNotEmpty &&
    currentAppUserId == targetAppUserId;

@visibleForTesting
class YorksV1UserManagementAccess {
  const YorksV1UserManagementAccess({
    required this.canView,
    required this.canCreate,
    required this.canEditProfile,
    required this.canAssignRoles,
    required this.canResetPassword,
    required this.canManageActivation,
    required this.canViewPermissions,
    required this.canManagePermissions,
    required this.canViewAudit,
    required this.isConfigurationActor,
    required this.connectedV1,
  });

  factory YorksV1UserManagementAccess.resolve({
    required bool connectedV1,
    required YorksV1Role? role,
    required YorksV1CurrentPermissionSnapshotState permissionState,
  }) {
    if (!connectedV1) {
      return const YorksV1UserManagementAccess(
        canView: true,
        canCreate: true,
        canEditProfile: true,
        canAssignRoles: true,
        canResetPassword: true,
        canManageActivation: true,
        canViewPermissions: false,
        canManagePermissions: false,
        canViewAudit: true,
        isConfigurationActor: false,
        connectedV1: false,
      );
    }
    final legacy = role?.canConfigureUsers ?? false;
    bool read(String key) => permissionState.hybridAllows(
      key,
      legacyAllowed: legacy,
      organizationSummary: true,
    );
    bool write(String key) => permissionState.hybridAllows(
      key,
      legacyAllowed: legacy,
      requireWrite: true,
      organizationSummary: true,
    );
    return YorksV1UserManagementAccess(
      canView: read(YorksV1CapabilityKeys.usersView),
      canCreate: write(YorksV1CapabilityKeys.usersCreate),
      canEditProfile: write(YorksV1CapabilityKeys.usersProfileEdit),
      canAssignRoles: write(YorksV1CapabilityKeys.usersRolesAssign),
      canResetPassword: write(YorksV1CapabilityKeys.usersPasswordReset),
      canManageActivation: write(YorksV1CapabilityKeys.usersActivationManage),
      canViewPermissions: read(YorksV1CapabilityKeys.permissionsView),
      canManagePermissions: write(YorksV1CapabilityKeys.permissionsManage),
      canViewAudit: read(YorksV1CapabilityKeys.auditView),
      // The retained commercial-capability RPC has not been delegated yet.
      // It still requires the established Admin/SME configuration actor in
      // addition to the scoped permission decision.
      isConfigurationActor: role?.canConfigureUsers ?? false,
      connectedV1: true,
    );
  }

  final bool canView;
  final bool canCreate;
  final bool canEditProfile;
  final bool canAssignRoles;
  final bool canResetPassword;
  final bool canManageActivation;
  final bool canViewPermissions;
  final bool canManagePermissions;
  final bool canViewAudit;
  final bool isConfigurationActor;
  final bool connectedV1;

  bool get canManageUser =>
      canEditProfile ||
      canAssignRoles ||
      canResetPassword ||
      canManageActivation;

  bool get canViewCommercialAccess =>
      isConfigurationActor && canViewPermissions;

  bool get canManageCommercialAccess =>
      isConfigurationActor && canManagePermissions;
}

/// Admin user management & access control (SRS §4.7). Create / edit /
/// deactivate accounts, assign roles, reset passwords, grant or revoke
/// per-engineer inventory access. No self-signup — Admin creates every account.
class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _AdminManagementTab _tab = _AdminManagementTab.users;
  int? _lastDirectoryRefreshRevision;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(AppUser u, {required bool yorksV1Provisioning}) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return u.fullName.toLowerCase().contains(q) ||
        u.email.toLowerCase().contains(q) ||
        _roleLabel(
          u,
          yorksV1Provisioning: yorksV1Provisioning,
        ).toLowerCase().contains(q);
  }

  Future<void> _removeUserAccess(AppUser user) async {
    final connectedV1 =
        ref.read(yorksV1UserProvisioningEnabledProvider) &&
        ref.read(supabaseClientProvider) != null;
    final language = ref.read(languageProvider);
    if (yorksV1IsProtectedSelfTarget(
      connectedV1: connectedV1,
      currentAppUserId:
          ref
              .read(yorksV1CurrentPermissionSnapshotProvider)
              .snapshot
              ?.user
              .appUserId ??
          ref.read(currentUserProvider)?.id,
      targetAppUserId: user.id,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _permissionCopy(language, 'self_account_protected_body'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (connectedV1) {
      try {
        final options = await ref.read(
          yorksV1UserAdminOptionsProvider(user.id).future,
        );
        if (!options.canManageActivation) {
          throw StateError(
            _permissionCopy(language, 'admin_options_unavailable'),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_friendlyErr(error)),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Text(
          _permissionCopy(
            language,
            connectedV1
                ? 'deactivate_account_title'
                : 'delete_local_user_title',
          ),
        ),
        content: Text(
          _permissionCopy(
            language,
            connectedV1 ? 'deactivate_account_body' : 'delete_local_user_body',
            name: user.fullName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppStrings.cancel.primary),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _permissionCopy(
                language,
                connectedV1 ? 'deactivate_account' : 'delete_local_user',
              ),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final changed = connectedV1
          ? await ref
                .read(usersProvider.notifier)
                .setActive(user.id, false, idempotencyKey: const Uuid().v4())
          : await ref
                .read(usersProvider.notifier)
                .deleteUser(user.id, idempotencyKey: const Uuid().v4());
      if (!changed) {
        throw StateError(
          _permissionCopy(language, 'last_admin_deactivation_error'),
        );
      }
      await ref.logAudit(
        action: connectedV1 ? 'User deactivated' : 'Local user deleted',
        module: AuditModule.platform,
        refId: user.id,
        detail: connectedV1
            ? '${user.fullName} · account access removed; history retained'
            : '${user.fullName} · local development roster only',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _permissionCopy(
                language,
                connectedV1
                    ? 'deactivate_account_success'
                    : 'delete_local_user_success',
                name: user.fullName,
              ),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyErr(error)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = YorksMobileUi.isActive(context);
    final yorksV1Provisioning = ref.watch(
      yorksV1UserProvisioningEnabledProvider,
    );
    final connectedV1 =
        yorksV1Provisioning && ref.watch(supabaseClientProvider) != null;
    final permissionState = ref.watch(yorksV1CurrentPermissionSnapshotProvider);
    final access = YorksV1UserManagementAccess.resolve(
      connectedV1: connectedV1,
      role: ref.watch(yorksV1CurrentRoleProvider),
      permissionState: permissionState,
    );
    if (!access.canView) {
      return _UserDirectoryAccessGate(
        loading: permissionState.isInitialLoading,
        onRetry: () => ref
            .read(yorksV1CurrentPermissionSnapshotProvider.notifier)
            .refresh(),
      );
    }

    final revision = permissionState.snapshot?.revision;
    if (connectedV1 &&
        revision != null &&
        _lastDirectoryRefreshRevision != revision) {
      _lastDirectoryRefreshRevision = revision;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          await ref
              .read(usersProvider.notifier)
              .refreshFromServer(permissionConfirmed: access.canView);
        } catch (_) {
          // Keep the last confirmed directory. The explicit Refresh action
          // remains available for a transient protected-directory failure.
        }
      });
    }
    final all = ref.watch(usersProvider);
    final users = all
        .where(
          (user) => _matches(user, yorksV1Provisioning: yorksV1Provisioning),
        )
        .toList();

    final activeUsers = all.where((user) => user.active).length;
    final engineers = all
        .where(
          (user) =>
              _displayYorksV1Roles(user).any((role) => role.isEngineering),
        )
        .length;
    final deactivated = all.length - activeUsers;

    return Scaffold(
      backgroundColor: AppColors.surface,
      // A nested FAB sits over the workspace navigation on phones. The phone
      // header owns the same create action so it remains visible without
      // obscuring a directory row.
      floatingActionButton:
          !phone && MediaQuery.sizeOf(context).width < 820 && access.canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _AddUserSheet.show(context),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add user'),
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 820;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                compact ? AppSpacing.lg : AppSpacing.xxxl,
                compact ? AppSpacing.lg : AppSpacing.xxxl,
                compact ? AppSpacing.lg : AppSpacing.xxxl,
                AppSpacing.huge,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AdminPageHeader(
                      compact: compact,
                      phone: phone,
                      onCreate: access.canCreate
                          ? () => _AddUserSheet.show(context)
                          : null,
                      onRefresh: () async {
                        try {
                          await ref
                              .read(usersProvider.notifier)
                              .refreshFromServer(
                                permissionConfirmed: access.canView,
                              );
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_friendlyErr(error))),
                            );
                          }
                        }
                      },
                    ),
                    const Gap(AppSpacing.xl),
                    _AdminTabBar(
                      selected:
                          _tab == _AdminManagementTab.accessHistory &&
                              !access.canViewAudit
                          ? _AdminManagementTab.users
                          : _tab,
                      showAccessHistory: access.canViewAudit,
                      onChanged: (tab) => setState(() => _tab = tab),
                    ),
                    const Gap(AppSpacing.lg),
                    switch (_tab == _AdminManagementTab.accessHistory &&
                            !access.canViewAudit
                        ? _AdminManagementTab.users
                        : _tab) {
                      _AdminManagementTab.users => _UsersTab(
                        allUsers: all,
                        users: users,
                        activeUsers: activeUsers,
                        engineers: engineers,
                        deactivated: deactivated,
                        queryController: _searchController,
                        query: _query,
                        yorksV1Provisioning: yorksV1Provisioning,
                        access: access,
                        onQueryChanged: (query) =>
                            setState(() => _query = query),
                        onCreate: access.canCreate
                            ? () => _AddUserSheet.show(context)
                            : null,
                        onDelete: _removeUserAccess,
                      ),
                      _AdminManagementTab.projectAccess =>
                        const _ProjectAccessTab(),
                      _AdminManagementTab.accessHistory => _AccessHistoryTab(
                        entries: ref.watch(auditLogProvider),
                      ),
                    },
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _AdminManagementTab { users, projectAccess, accessHistory }

class _UserDirectoryAccessGate extends ConsumerWidget {
  const _UserDirectoryAccessGate({
    required this.loading,
    required this.onRetry,
  });

  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    const CircularProgressIndicator()
                  else
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 48,
                      color: AppColors.muted,
                    ),
                  const Gap(AppSpacing.lg),
                  Text(
                    YorksV1PermissionStrings.text(
                      language,
                      loading
                          ? 'directory_loading_title'
                          : 'directory_unavailable_title',
                    ),
                    key: const ValueKey('user-directory-access-state'),
                    textAlign: TextAlign.center,
                    style: AppTypography.titleMedium,
                  ),
                  if (!loading) ...[
                    const Gap(AppSpacing.sm),
                    Text(
                      YorksV1PermissionStrings.text(
                        language,
                        'directory_unavailable_body',
                      ),
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const Gap(AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        YorksV1PermissionStrings.text(language, 'retry'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminPageHeader extends StatelessWidget {
  const _AdminPageHeader({
    required this.compact,
    required this.phone,
    required this.onCreate,
    required this.onRefresh,
  });

  final bool compact;
  final bool phone;
  final VoidCallback? onCreate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADMINISTRATION',
          style: AppTypography.eyebrow.copyWith(
            color: AppColors.blue,
            letterSpacing: 1.5,
          ),
        ),
        const Gap(AppSpacing.xs),
        Text(
          'User Access',
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
        const Gap(AppSpacing.xs),
        Text(
          'Complete control of users, roles, project assignments and recoverable access removal.',
          style: AppTypography.bodyLarge.copyWith(color: AppColors.muted),
        ),
      ],
    );
    if (phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              YorksMobileIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh users',
                onPressed: onRefresh,
              ),
            ],
          ),
          const Gap(AppSpacing.md),
          if (onCreate != null)
            SizedBox(
              height: AppSpacing.minTapTarget,
              child: FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add user'),
              ),
            ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        Expanded(child: heading),
        const Gap(AppSpacing.lg),
        if (!compact && onCreate != null)
          _AdminPrimaryButton(
            label: 'Create User',
            icon: Icons.add_rounded,
            onPressed: onCreate!,
          )
        else
          IconButton(
            tooltip: 'Refresh users',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
    );
  }
}

class _AdminTabBar extends StatelessWidget {
  const _AdminTabBar({
    required this.selected,
    required this.showAccessHistory,
    required this.onChanged,
  });

  final _AdminManagementTab selected;
  final bool showAccessHistory;
  final ValueChanged<_AdminManagementTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _tab('Users', _AdminManagementTab.users),
      _tab('Project Access', _AdminManagementTab.projectAccess),
      if (showAccessHistory)
        _tab('Access History', _AdminManagementTab.accessHistory),
    ];
    final control = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: YorksMobileUi.isActive(context)
            ? Row(mainAxisSize: MainAxisSize.min, children: tabs)
            : Wrap(spacing: 4, children: tabs),
      ),
    );
    if (!YorksMobileUi.isActive(context)) {
      return Align(alignment: Alignment.centerLeft, child: control);
    }
    return SizedBox(
      height: AppSpacing.minTapTarget + 12,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: control,
      ),
    );
  }

  Widget _tab(String label, _AdminManagementTab value) => TextButton(
    onPressed: () => onChanged(value),
    style: TextButton.styleFrom(
      backgroundColor: selected == value
          ? AppColors.surfaceContainerLowest
          : Colors.transparent,
      foregroundColor: selected == value ? AppColors.blue : AppColors.muted,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
    ),
    child: Text(label, style: AppTypography.labelLarge),
  );
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({
    required this.allUsers,
    required this.users,
    required this.activeUsers,
    required this.engineers,
    required this.deactivated,
    required this.queryController,
    required this.query,
    required this.yorksV1Provisioning,
    required this.access,
    required this.onQueryChanged,
    required this.onCreate,
    required this.onDelete,
  });

  final List<AppUser> allUsers;
  final List<AppUser> users;
  final int activeUsers;
  final int engineers;
  final int deactivated;
  final TextEditingController queryController;
  final String query;
  final bool yorksV1Provisioning;
  final YorksV1UserManagementAccess access;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback? onCreate;
  final ValueChanged<AppUser> onDelete;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 820;
    final phone = YorksMobileUi.isActive(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!phone) ...[
          _AdminMetricGrid(
            metrics: [
              (
                'ACTIVE USERS',
                '$activeUsers',
                'Across Engineer, Procurement and Admin',
              ),
              ('ENGINEERS', '$engineers', 'Project delivery and site coverage'),
              (
                'ASSIGNED PROJECTS',
                '0',
                'Primary and supporting access controlled',
              ),
              (
                'DEACTIVATED',
                '$deactivated',
                'Recoverable accounts with history retained',
              ),
            ],
          ),
          const Gap(AppSpacing.lg),
        ],
        _AdminSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User Directory',
                          style: AppTypography.headlineSmall,
                        ),
                        const Gap(AppSpacing.xs),
                        Text(
                          'Create, manage, deactivate and restore company accounts without losing history.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!compact && onCreate != null)
                    _AdminPrimaryButton(
                      label: 'Create User',
                      icon: Icons.add_rounded,
                      onPressed: onCreate!,
                    ),
                ],
              ),
              const Gap(AppSpacing.lg),
              TextField(
                controller: queryController,
                onChanged: onQueryChanged,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search name, email, role',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            queryController.clear();
                            onQueryChanged('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const Gap(AppSpacing.md),
              if (compact)
                _CompactUserList(
                  users: users,
                  yorksV1Provisioning: yorksV1Provisioning,
                  access: access,
                  allUsersEmpty: allUsers.isEmpty,
                  onDelete: onDelete,
                )
              else
                _DesktopUserTable(
                  users: users,
                  yorksV1Provisioning: yorksV1Provisioning,
                  access: access,
                  allUsersEmpty: allUsers.isEmpty,
                  onDelete: onDelete,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminMetricGrid extends StatelessWidget {
  const _AdminMetricGrid({required this.metrics});
  final List<(String, String, String)> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1100
          ? 4
          : constraints.maxWidth >= 620
          ? 2
          : 1;
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        mainAxisExtent: columns == 1 ? 110 : 136,
        children: [
          for (final metric in metrics)
            _AdminSurfaceCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    metric.$1,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.muted,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Gap(AppSpacing.xs),
                  Text(metric.$2, style: AppTypography.headlineMedium),
                  const Gap(AppSpacing.xxs),
                  Text(
                    metric.$3,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _DesktopUserTable extends StatelessWidget {
  const _DesktopUserTable({
    required this.users,
    required this.yorksV1Provisioning,
    required this.access,
    required this.allUsersEmpty,
    required this.onDelete,
  });

  final List<AppUser> users;
  final bool yorksV1Provisioning;
  final YorksV1UserManagementAccess access;
  final bool allUsersEmpty;
  final ValueChanged<AppUser> onDelete;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return _EmptyDirectory(allUsersEmpty: allUsersEmpty);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: AppColors.surfaceContainerLow,
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('USER')),
                Expanded(flex: 2, child: Text('ROLE / TITLE')),
                Expanded(flex: 2, child: Text('PROJECT ACCESS')),
                Expanded(flex: 2, child: Text('COMMERCIAL')),
                Expanded(flex: 2, child: Text('LAST ACTIVE')),
                Expanded(flex: 2, child: Text('STATUS')),
                SizedBox(width: 430, child: Text('')),
              ],
            ),
          ),
          for (final user in users)
            _UserTableRow(
              user: user,
              yorksV1Provisioning: yorksV1Provisioning,
              access: access,
              onDelete: onDelete,
            ),
        ],
      ),
    );
  }
}

class _UserTableRow extends ConsumerWidget {
  const _UserTableRow({
    required this.user,
    required this.yorksV1Provisioning,
    required this.access,
    required this.onDelete,
  });

  final AppUser user;
  final bool yorksV1Provisioning;
  final YorksV1UserManagementAccess access;
  final ValueChanged<AppUser> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final isCurrentUser = yorksV1IsProtectedSelfTarget(
      connectedV1: access.connectedV1,
      currentAppUserId:
          ref
              .watch(yorksV1CurrentPermissionSnapshotProvider)
              .snapshot
              ?.user
              .appUserId ??
          ref.watch(currentUserProvider)?.id,
      targetAppUserId: user.id,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: _UserIdentity(user: user)),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _roleFamilyLabel(
                    user,
                    yorksV1Provisioning: yorksV1Provisioning,
                    language: language,
                  ),
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _roleTitleLabel(
                    user,
                    yorksV1Provisioning: yorksV1Provisioning,
                    language: language,
                  ),
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(flex: 2, child: Text('0 projects')),
          const Expanded(flex: 2, child: _PermittedChip()),
          const Expanded(flex: 2, child: Text('—')),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: user.active
                  ? StatusChip.success(AppStrings.userActive.primary)
                  : StatusChip.error(AppStrings.userInactive.primary),
            ),
          ),
          SizedBox(
            width: 430,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (yorksV1Provisioning && access.canViewPermissions) ...[
                  OutlinedButton.icon(
                    key: Key('manage-access-${user.id}'),
                    onPressed: () =>
                        context.go(RoutePaths.yorksV1UserAccessPath(user.id)),
                    icon: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 17,
                    ),
                    label: Text(
                      YorksV1PermissionStrings.text(language, 'manage_access'),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (access.canManageUser) ...[
                  OutlinedButton.icon(
                    key: Key('manage-user-${user.id}'),
                    onPressed: () =>
                        _ManageUserSheet.show(context, user, access),
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: Text(
                      YorksV1PermissionStrings.text(language, 'manage_user'),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (!access.connectedV1 &&
                    user.active &&
                    access.canManageActivation &&
                    !isCurrentUser)
                  TextButton(
                    key: Key('deactivate-user-${user.id}'),
                    onPressed: () => onDelete(user),
                    child: Text(
                      YorksV1PermissionStrings.text(
                        language,
                        access.connectedV1
                            ? 'deactivate_account_short'
                            : 'delete_local_user',
                      ),
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactUserList extends StatelessWidget {
  const _CompactUserList({
    required this.users,
    required this.yorksV1Provisioning,
    required this.access,
    required this.allUsersEmpty,
    required this.onDelete,
  });
  final List<AppUser> users;
  final bool yorksV1Provisioning;
  final YorksV1UserManagementAccess access;
  final bool allUsersEmpty;
  final ValueChanged<AppUser> onDelete;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return _EmptyDirectory(allUsersEmpty: allUsersEmpty);
    return Column(
      children: [
        for (final user in users) ...[
          _MobileUserCard(
            user: user,
            yorksV1Provisioning: yorksV1Provisioning,
            access: access,
            onDelete: onDelete,
          ),
          const Gap(AppSpacing.sm),
        ],
      ],
    );
  }
}

class _MobileUserCard extends ConsumerWidget {
  const _MobileUserCard({
    required this.user,
    required this.yorksV1Provisioning,
    required this.access,
    required this.onDelete,
  });
  final AppUser user;
  final bool yorksV1Provisioning;
  final YorksV1UserManagementAccess access;
  final ValueChanged<AppUser> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final isCurrentUser = yorksV1IsProtectedSelfTarget(
      connectedV1: access.connectedV1,
      currentAppUserId:
          ref
              .watch(yorksV1CurrentPermissionSnapshotProvider)
              .snapshot
              ?.user
              .appUserId ??
          ref.watch(currentUserProvider)?.id,
      targetAppUserId: user.id,
    );
    final role = _roleLabel(user, yorksV1Provisioning: yorksV1Provisioning);
    return Semantics(
      button: true,
      label: '${user.fullName}, $role',
      child: YorksMobileCard(
        onTap: access.canManageUser
            ? () => _ManageUserSheet.show(context, user, access)
            : null,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _UserAvatar(user: user),
                const Gap(AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Gap(AppSpacing.xxs),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
            const Gap(AppSpacing.md),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _MobileUserStatusPill(label: role, info: true),
                _MobileUserStatusPill(
                  label: user.active
                      ? AppStrings.userActive.primary
                      : AppStrings.userInactive.primary,
                  active: user.active,
                ),
              ],
            ),
            if (yorksV1Provisioning && access.canViewPermissions) ...[
              const Gap(AppSpacing.md),
              const Divider(height: 1),
              const Gap(AppSpacing.sm),
              OutlinedButton.icon(
                key: Key('manage-access-${user.id}'),
                onPressed: () =>
                    context.go(RoutePaths.yorksV1UserAccessPath(user.id)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSpacing.minTapTarget),
                ),
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: Text(
                  YorksV1PermissionStrings.text(language, 'manage_access'),
                ),
              ),
            ],
            if (!access.connectedV1 &&
                user.active &&
                access.canManageActivation &&
                !isCurrentUser) ...[
              const Gap(AppSpacing.sm),
              TextButton.icon(
                key: Key('deactivate-user-${user.id}'),
                onPressed: () => onDelete(user),
                icon: const Icon(
                  Icons.person_off_outlined,
                  color: AppColors.error,
                ),
                label: Text(
                  YorksV1PermissionStrings.text(
                    language,
                    access.connectedV1
                        ? 'deactivate_account'
                        : 'delete_local_user',
                  ),
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MobileUserStatusPill extends StatelessWidget {
  const _MobileUserStatusPill({
    required this.label,
    this.info = false,
    this.active = false,
  });

  final String label;
  final bool info;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = info
        ? NexusStatusPalette.forTone(NexusStatusTone.info)
        : NexusStatusPalette.forTone(
            active ? NexusStatusTone.success : NexusStatusTone.danger,
          );
    return Container(
      constraints: const BoxConstraints(maxWidth: 248, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelMedium.copyWith(
          color: palette.foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _UserIdentity extends StatelessWidget {
  const _UserIdentity({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _UserAvatar(user: user),
      const Gap(AppSpacing.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.fullName, style: AppTypography.labelLarge),
            const Gap(AppSpacing.xxs),
            Text(
              user.email,
              style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ],
  );
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 23,
    backgroundColor: AppColors.blueContainer.withValues(alpha: .6),
    child: Text(
      user.initials,
      style: AppTypography.labelLarge.copyWith(
        color: AppColors.blue,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _PermittedChip extends StatelessWidget {
  const _PermittedChip();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: .10),
        border: Border.all(color: AppColors.success.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        'Permitted',
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _EmptyDirectory extends StatelessWidget {
  const _EmptyDirectory({required this.allUsersEmpty});
  final bool allUsersEmpty;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    child: Center(
      child: Text(
        allUsersEmpty ? 'No users yet' : 'No matching users',
        style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
      ),
    ),
  );
}

class _ProjectAccessTab extends StatelessWidget {
  const _ProjectAccessTab();

  @override
  Widget build(BuildContext context) => _AdminSurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Primary & Supporting Engineer Access',
          style: AppTypography.headlineSmall,
        ),
        const Gap(AppSpacing.xs),
        Text(
          'Management controls who can maintain each project.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
        ),
        const Gap(AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.blueContainer.withValues(alpha: .35),
            border: Border.all(color: AppColors.blueContainerStrong),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppColors.blue),
              const Gap(AppSpacing.md),
              Expanded(
                child: Text(
                  'Project access and request coverage are intentionally different. Assigned Engineers may edit a project; active Engineers may raise a Material Request when covering a site.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Gap(AppSpacing.xl),
        Text(
          'No project assignments yet',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
        ),
        const Gap(AppSpacing.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => context.go(RoutePaths.yorksV1Projects),
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('Open Projects'),
          ),
        ),
      ],
    ),
  );
}

class _AccessHistoryTab extends StatelessWidget {
  const _AccessHistoryTab({required this.entries});
  final List<AuditEntry> entries;

  @override
  Widget build(BuildContext context) {
    final relevant = entries
        .where(
          (entry) =>
              entry.module == AuditModule.platform ||
              entry.action.toLowerCase().contains('access'),
        )
        .take(20)
        .toList();
    return _AdminSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Access History', style: AppTypography.headlineSmall),
          const Gap(AppSpacing.xs),
          Text(
            'Creation, deletion, restoration and project access changes remain traceable.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
          ),
          const Gap(AppSpacing.lg),
          if (relevant.isEmpty)
            Text(
              'No access changes recorded yet.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
            )
          else
            for (final entry in relevant) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.blueContainer,
                  foregroundColor: AppColors.blue,
                  child: const Icon(Icons.people_outline),
                ),
                title: Text(entry.action),
                subtitle: Text(
                  '${entry.detail ?? ''} · ${entry.actorName}\n${entry.timestamp}',
                ),
              ),
              const Divider(height: 1),
            ],
        ],
      ),
    );
  }
}

class _AdminSurfaceCard extends StatelessWidget {
  const _AdminSurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A18324B),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class _AdminPrimaryButton extends StatelessWidget {
  const _AdminPrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
    ),
  );
}

@visibleForTesting
class YorksV1RoleAssignmentEditor extends StatelessWidget {
  const YorksV1RoleAssignmentEditor({
    required this.language,
    required this.primary,
    required this.availableRoles,
    required this.onPrimaryChanged,
    this.statusText,
  });

  final AppLanguage language;
  final YorksV1Role? primary;
  final List<YorksV1Role> availableRoles;
  final ValueChanged<YorksV1Role>? onPrimaryChanged;
  final String? statusText;

  @override
  Widget build(BuildContext context) {
    final selected = availableRoles.contains(primary) ? primary : null;
    final onChanged = availableRoles.isEmpty || onPrimaryChanged == null
        ? null
        : (YorksV1Role? role) {
            if (role != null) onPrimaryChanged!(role);
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          YorksV1PermissionStrings.text(language, 'role'),
          style: AppTypography.titleSmall,
        ),
        const Gap(AppSpacing.sm),
        DropdownButtonFormField<YorksV1Role>(
          key: const ValueKey('server-assignable-role-field'),
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(helperText: statusText),
          hint: Text(AppStrings.yorksV1RoleMappingRequired.active(language)),
          items: [
            for (final role in availableRoles)
              DropdownMenuItem(
                value: role,
                child: Text(_yorksV1RoleText(role).active(language)),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ─── Add user ────────────────────────────────────────────────────
class _AddUserSheet extends ConsumerStatefulWidget {
  const _AddUserSheet();

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.scrim.withValues(alpha: .38),
      builder: (dialogContext) {
        final viewport = MediaQuery.sizeOf(dialogContext);
        final phone = YorksMobileUi.isActive(dialogContext);
        return Dialog(
          alignment: phone ? Alignment.bottomCenter : Alignment.center,
          backgroundColor: AppColors.surfaceContainerLowest,
          insetPadding: phone
              ? const EdgeInsets.fromLTRB(8, 48, 8, 0)
              : const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          shape: RoundedRectangleBorder(
            borderRadius: phone
                ? const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.radiusXl),
                  )
                : BorderRadius.circular(AppSpacing.radiusXl),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 704,
              maxHeight: viewport.height * .92,
            ),
            child: const _AddUserSheet(),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<_AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends ConsumerState<_AddUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _legacyRole = UserRole.engineer;
  YorksV1Role _yorksV1Role = YorksV1Role.siteEngineer;
  bool _busy = false;
  String? _createCommandFingerprint;
  String? _createIdempotencyKey;
  String? _createAppUserId;

  ({String idempotencyKey, String appUserId}) _createCommandFor(
    String fingerprint,
  ) {
    if (_createCommandFingerprint != fingerprint) {
      _createCommandFingerprint = fingerprint;
      _createIdempotencyKey = const Uuid().v4();
      _createAppUserId = 'usr-${const Uuid().v4().substring(0, 8)}';
    }
    return (
      idempotencyKey: _createIdempotencyKey!,
      appUserId: _createAppUserId!,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final yorksV1Provisioning = ref.read(
      yorksV1UserProvisioningEnabledProvider,
    );
    final connectedV1 =
        yorksV1Provisioning && ref.read(supabaseClientProvider) != null;
    if (connectedV1) {
      final options = ref
          .read(yorksV1UserAdminOptionsProvider(null))
          .asData
          ?.value;
      if (options == null || !options.allowsRole(_yorksV1Role)) {
        final language = ref.read(languageProvider);
        AppFeedback.warning();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _permissionCopy(language, 'admin_options_unavailable'),
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }
    setState(() => _busy = true);
    try {
      final fullName = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final command = _createCommandFor(
        [
          yorksV1Provisioning,
          fullName,
          email,
          password,
          yorksV1Provisioning ? _yorksV1Role.name : _legacyRole.name,
        ].join('\u0000'),
      );
      // When Supabase is configured this provisions the account in the identity
      // provider (via the admin-users function) before storing it locally; a
      // failure (e.g. duplicate email) throws and nothing is written.
      final users = ref.read(usersProvider.notifier);
      final user = yorksV1Provisioning
          ? await users.createYorksV1User(
              fullName: fullName,
              email: email,
              role: _yorksV1Role,
              password: password,
              idempotencyKey: command.idempotencyKey,
              appUserId: command.appUserId,
            )
          : await users.createUser(
              fullName: fullName,
              email: email,
              role: _legacyRole,
              password: password,
              idempotencyKey: command.idempotencyKey,
              appUserId: command.appUserId,
            );
      await ref.logAudit(
        action: 'User created',
        module: AuditModule.platform,
        refId: user.id,
        detail:
            '${user.fullName} · ${_roleLabel(user, yorksV1Provisioning: yorksV1Provisioning)}',
      );
      if (!mounted) return;
      // The app-level messenger outlives this sheet, so the success toast still
      // shows after we pop.
      final messenger = ScaffoldMessenger.of(context);
      AppFeedback.confirm();
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text('${user.fullName} added')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyErr(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final language = ref.watch(languageProvider);
    final yorksV1Provisioning = ref.watch(
      yorksV1UserProvisioningEnabledProvider,
    );
    final connectedV1 =
        yorksV1Provisioning && ref.watch(supabaseClientProvider) != null;
    final adminOptionsState = connectedV1
        ? ref.watch(yorksV1UserAdminOptionsProvider(null))
        : null;
    final adminOptions = adminOptionsState?.asData?.value;
    final assignableRoles = connectedV1
        ? adminOptions?.assignableExactRoles ?? const <YorksV1Role>[]
        : YorksV1Role.values;
    final roleOptionsStatus = !connectedV1
        ? null
        : adminOptionsState!.isLoading
        ? _permissionCopy(language, 'admin_options_loading')
        : adminOptions == null
        ? _permissionCopy(language, 'admin_options_unavailable')
        : assignableRoles.isEmpty
        ? _permissionCopy(language, 'no_assignable_roles')
        : _permissionCopy(language, 'role_options_help');
    final canCreateWithRole =
        !yorksV1Provisioning ||
        !connectedV1 ||
        (adminOptions?.allowsRole(_yorksV1Role) ?? false);
    final access = YorksV1UserManagementAccess.resolve(
      connectedV1: connectedV1,
      role: ref.watch(yorksV1CurrentRoleProvider),
      permissionState: ref.watch(yorksV1CurrentPermissionSnapshotProvider),
    );
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create User',
                              style: AppTypography.headlineSmall.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Gap(AppSpacing.xxs),
                            Text(
                              'Accounts are controlled by Admin. Historical activity remains attributed to the original user.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.xxl),
                  const Gap(AppSpacing.lg),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 560;
                      final fields = [
                        LedgerTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? AppStrings.fieldRequired.primary
                              : null,
                        ),
                        LedgerTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) {
                              return AppStrings.fieldRequired.primary;
                            }
                            if (!t.contains('@')) {
                              return AppStrings.emailAddress.primary;
                            }
                            return null;
                          },
                        ),
                      ];
                      return stacked
                          ? Column(
                              children: [
                                fields[0],
                                const Gap(AppSpacing.lg),
                                fields[1],
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: fields[0]),
                                const Gap(AppSpacing.lg),
                                Expanded(child: fields[1]),
                              ],
                            );
                    },
                  ),
                  const Gap(AppSpacing.lg),
                  if (yorksV1Provisioning)
                    YorksV1RoleAssignmentEditor(
                      language: language,
                      primary: _yorksV1Role,
                      availableRoles: assignableRoles,
                      statusText: roleOptionsStatus,
                      onPrimaryChanged:
                          connectedV1 && adminOptions?.canAssignRole != true
                          ? null
                          : (role) => setState(() {
                              _yorksV1Role = role;
                            }),
                    )
                  else ...[
                    Text('Role', style: AppTypography.titleSmall),
                    const Gap(AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final role in UserRole.values)
                          _RoleChip(
                            label: role.label,
                            selected: _legacyRole == role,
                            onTap: () => setState(() => _legacyRole = role),
                          ),
                      ],
                    ),
                  ],
                  const Gap(AppSpacing.lg),
                  LedgerTextField(
                    controller: _passwordController,
                    label: AppStrings.initialPassword.primary,
                    obscureText: true,
                    validator: (v) => (v ?? '').trim().length < 6
                        ? AppStrings.passwordTooShort.primary
                        : null,
                  ),
                  const Gap(AppSpacing.xxl),
                  PrimaryButton(
                    label: AppStrings.createUser.primary,
                    icon: Icons.check_rounded,
                    isLoading: _busy,
                    isExpanded: true,
                    onPressed: _busy || !access.canCreate || !canCreateWithRole
                        ? null
                        : _save,
                  ),
                  const Gap(AppSpacing.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Manage user ─────────────────────────────────────────────────
class _ManageUserSheet extends ConsumerStatefulWidget {
  const _ManageUserSheet({required this.userId, required this.access});
  final String userId;
  final YorksV1UserManagementAccess access;

  static Future<void> show(
    BuildContext context,
    AppUser user,
    YorksV1UserManagementAccess access,
  ) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.scrim.withValues(alpha: .38),
      builder: (dialogContext) {
        final viewport = MediaQuery.sizeOf(dialogContext);
        final compact = viewport.width < AppSpacing.compactBreakpoint;
        return Dialog(
          alignment: compact ? Alignment.bottomCenter : Alignment.center,
          backgroundColor: AppColors.surfaceContainerLowest,
          insetPadding: compact
              ? const EdgeInsets.fromLTRB(8, 48, 8, 0)
              : const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          shape: RoundedRectangleBorder(
            borderRadius: compact
                ? const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.radiusXl),
                  )
                : BorderRadius.circular(AppSpacing.radiusXl),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: viewport.height * .92,
            ),
            child: _ManageUserSheet(userId: user.id, access: access),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<_ManageUserSheet> createState() => _ManageUserSheetState();
}

class _ManageUserSheetState extends ConsumerState<_ManageUserSheet> {
  /// True while a remote (Edge-Function-backed) action is in flight. Disables
  /// the sheet's controls and shows a progress line so the admin gets clear
  /// system-status feedback and can't fire a second action mid-flight.
  bool _busy = false;
  final Map<String, String> _idempotencyKeys = {};
  String? _pendingResetPassword;

  String _idempotencyKeyFor(String command) =>
      _idempotencyKeys.putIfAbsent(command, () => const Uuid().v4());

  void _completeCommand(String command) {
    _idempotencyKeys.remove(command);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref
        .watch(usersProvider)
        .where((u) => u.id == widget.userId)
        .firstOrNull;
    if (user == null) return const SizedBox.shrink();
    final language = ref.watch(languageProvider);
    final yorksV1Provisioning = ref.watch(
      yorksV1UserProvisioningEnabledProvider,
    );
    final connectedV1 =
        yorksV1Provisioning && ref.watch(supabaseClientProvider) != null;
    final isCurrentUser = yorksV1IsProtectedSelfTarget(
      connectedV1: connectedV1,
      currentAppUserId:
          ref
              .watch(yorksV1CurrentPermissionSnapshotProvider)
              .snapshot
              ?.user
              .appUserId ??
          ref.watch(currentUserProvider)?.id,
      targetAppUserId: user.id,
    );
    final access = YorksV1UserManagementAccess.resolve(
      connectedV1: connectedV1,
      role: ref.watch(yorksV1CurrentRoleProvider),
      permissionState: ref.watch(yorksV1CurrentPermissionSnapshotProvider),
    );
    final adminOptionsState = connectedV1
        ? ref.watch(yorksV1UserAdminOptionsProvider(user.id))
        : null;
    final adminOptions = adminOptionsState?.asData?.value;
    final assignableRoles = connectedV1
        ? adminOptions?.assignableExactRoles ?? const <YorksV1Role>[]
        : YorksV1Role.values;
    final roleOptionsStatus = !connectedV1
        ? null
        : adminOptionsState!.isLoading
        ? _permissionCopy(language, 'admin_options_loading')
        : adminOptions == null
        ? _permissionCopy(language, 'admin_options_unavailable')
        : assignableRoles.isEmpty
        ? _permissionCopy(language, 'no_assignable_roles')
        : _permissionCopy(language, 'role_options_help');
    final canManageActivationForTarget =
        access.canManageActivation &&
        !isCurrentUser &&
        (!connectedV1 || adminOptions?.canManageActivation == true);
    final canAssignRolesForTarget =
        access.canAssignRoles &&
        !isCurrentUser &&
        (!connectedV1 || adminOptions?.canAssignRole == true);
    final canResetPasswordForTarget =
        access.canResetPassword &&
        !isCurrentUser &&
        (!connectedV1 || adminOptions?.canResetPassword == true);
    // The app-level messenger outlives this sheet, so success toasts shown after
    // Navigator.pop still appear.
    final messenger = ScaffoldMessenger.of(context);

    void warn(String msg) {
      AppFeedback.warning();
      messenger.showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
    }

    void success(String msg) {
      AppFeedback.confirm();
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }

    /// Runs [body] under the busy guard: disables controls + shows the progress
    /// line while the remote call is in flight, and blocks concurrent actions.
    Future<void> run(Future<void> Function() body) async {
      if (_busy) return;
      setState(() => _busy = true);
      try {
        await body();
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    Future<void> toggleActive() => run(() async {
      if (!canManageActivationForTarget) {
        return warn(
          _permissionCopy(
            language,
            isCurrentUser
                ? 'self_account_protected_body'
                : 'admin_options_unavailable',
          ),
        );
      }
      final willActivate = !user.active;
      final command = 'set-active:${user.id}:$willActivate';
      try {
        final allowed = await ref
            .read(usersProvider.notifier)
            .setActive(
              user.id,
              willActivate,
              idempotencyKey: _idempotencyKeyFor(command),
            );
        if (!allowed) {
          return warn(
            _permissionCopy(language, 'last_admin_deactivation_error'),
          );
        }
        _completeCommand(command);
        if (connectedV1) {
          ref.invalidate(yorksV1UserAdminOptionsProvider(user.id));
        }
        await ref.logAudit(
          action: willActivate ? 'User reactivated' : 'User deactivated',
          module: AuditModule.platform,
          refId: user.id,
          detail: user.fullName,
        );
        success(
          _permissionCopy(
            language,
            willActivate ? 'account_reactivated' : 'account_deactivated',
          ),
        );
      } catch (e) {
        warn(_friendlyErr(e));
      }
    });

    Future<void> toggleAccess() => run(() async {
      final grant = !user.inventoryAccess;
      try {
        await ref
            .read(usersProvider.notifier)
            .setInventoryAccess(user.id, grant);
        await ref.logAudit(
          action: grant
              ? 'Inventory access granted'
              : 'Inventory access revoked',
          module: AuditModule.platform,
          refId: user.id,
          detail: user.fullName,
        );
        success(
          grant ? 'Inventory access granted' : 'Inventory access revoked',
        );
      } catch (e) {
        warn(_friendlyErr(e));
      }
    });

    Future<void> resetPassword() => run(() async {
      if (!canResetPasswordForTarget) {
        return warn(
          _permissionCopy(
            language,
            isCurrentUser
                ? 'self_account_protected_body'
                : 'admin_options_unavailable',
          ),
        );
      }
      // Capture the navigator up-front (before any await) — the sheet's own
      // context is about to be popped, so we drive the result dialog off the
      // (stable) navigator's context instead.
      final navigator = Navigator.of(context);
      // Set a temporary password the admin can share; the user must change it on
      // first sign-in. When Supabase is configured this resets the real Auth
      // credential via the admin-users function.
      final temp = _pendingResetPassword ??=
          'Temp${1000 + Random().nextInt(9000)}';
      final command = 'set-password:${user.id}:$temp';
      try {
        await ref
            .read(usersProvider.notifier)
            .setPassword(
              user.id,
              temp,
              temporary: true,
              idempotencyKey: _idempotencyKeyFor(command),
            );
      } catch (e) {
        return warn(_friendlyErr(e));
      }
      _pendingResetPassword = null;
      _completeCommand(command);
      await ref.logAudit(
        action: 'Password reset',
        module: AuditModule.platform,
        refId: user.id,
        detail: user.fullName,
      );
      if (!mounted) return;
      navigator.pop();
      showDialog<void>(
        context: navigator.context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          title: const Text('Temporary password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share this with ${user.fullName}. They must change it on first '
                'sign-in:',
                style: AppTypography.bodyMedium,
              ),
              const Gap(AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        temp,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: temp));
                        AppFeedback.confirm();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Password copied')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.done.primary),
            ),
          ],
        ),
      );
    });

    Future<void> setLegacyRole(UserRole role) => run(() async {
      if (role == user.role) return;
      final command = 'set-role:${user.id}:${role.name}';
      try {
        final allowed = await ref
            .read(usersProvider.notifier)
            .setRole(
              user.id,
              role,
              idempotencyKey: _idempotencyKeyFor(command),
            );
        if (!allowed) return warn("Can't change the only active admin's role.");
        _completeCommand(command);
        await ref.logAudit(
          action: 'User role changed',
          module: AuditModule.platform,
          refId: user.id,
          detail: '${user.fullName} → ${role.label}',
        );
        success('Role changed to ${role.label}');
      } catch (e) {
        warn(_friendlyErr(e));
      }
    });

    Future<void> setYorksV1Role(YorksV1Role role) => run(() async {
      if (role == user.yorksV1RoleCache) return;
      if (!canAssignRolesForTarget ||
          (connectedV1 && adminOptions?.allowsRole(role) != true)) {
        return warn(_permissionCopy(language, 'admin_options_unavailable'));
      }
      final command = 'set-v1-role:${user.id}:${role.claimValue}';
      try {
        final allowed = await ref
            .read(usersProvider.notifier)
            .setYorksV1Role(
              user.id,
              role,
              idempotencyKey: _idempotencyKeyFor(command),
            );
        if (!allowed) return warn("Can't change the only active admin's role.");
        _completeCommand(command);
        if (connectedV1) {
          ref.invalidate(yorksV1UserAdminOptionsProvider(user.id));
        }
        final label = _yorksV1RoleText(role).primary;
        await ref.logAudit(
          action: 'User role changed',
          module: AuditModule.platform,
          refId: user.id,
          detail: '${user.fullName} → $label',
        );
        success('Role changed to $label');
      } catch (e) {
        warn(_friendlyErr(e));
      }
    });

    Future<void> setOverride(PermissionKey key, bool value) => run(() async {
      // Toggling back to the role default clears the override entirely.
      final next = value == user.roleDefaultFor(key) ? null : value;
      final command = 'set-override:${user.id}:${key.name}:$next';
      try {
        await ref
            .read(usersProvider.notifier)
            .setPermissionOverride(
              user.id,
              key,
              next,
              idempotencyKey: _idempotencyKeyFor(command),
            );
        _completeCommand(command);
        await ref.logAudit(
          action: 'Permission updated',
          module: AuditModule.platform,
          refId: user.id,
          detail: '${user.fullName} · $key = ${next ?? 'role default'}',
        );
        success('Permission updated');
      } catch (e) {
        warn(_friendlyErr(e));
      }
    });

    Future<void> setEmployee(String? employeeId) => run(() async {
      final allowed = await ref
          .read(usersProvider.notifier)
          .setEmployeeLink(user.id, employeeId);
      if (!allowed) {
        return warn('That employee is already linked to another user.');
      }
      await ref.logAudit(
        action: employeeId == null
            ? 'Employee link cleared'
            : 'Linked to employee',
        module: AuditModule.platform,
        refId: user.id,
        detail: '${user.fullName} → ${employeeId ?? 'none'}',
      );
      success(
        employeeId == null ? 'Employee link cleared' : 'Linked to employee',
      );
    });

    Future<void> pickEmployee() async {
      if (_busy) return;
      final employees = ref.read(employeesProvider);
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: [
                ListTile(
                  leading: const Icon(Icons.link_off_rounded),
                  title: const Text('Not linked'),
                  trailing: user.employeeId == null
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setEmployee(null);
                  },
                ),
                for (final e in employees)
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(e.fullName),
                    subtitle: Text('${e.jobRole} · ${e.id}'),
                    trailing: user.employeeId == e.id
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.primary,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      setEmployee(e.id);
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    }

    Future<void> removeUserAccess() async {
      if (_busy) return;
      if (!canManageActivationForTarget) {
        warn(
          _permissionCopy(
            language,
            isCurrentUser
                ? 'self_account_protected_body'
                : 'admin_options_unavailable',
          ),
        );
        return;
      }
      final connectedV1 = access.connectedV1;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          title: Text(
            _permissionCopy(
              language,
              connectedV1
                  ? 'deactivate_account_title'
                  : 'delete_local_user_title',
            ),
          ),
          content: Text(
            _permissionCopy(
              language,
              connectedV1
                  ? 'deactivate_account_body'
                  : 'delete_local_user_body',
              name: user.fullName,
            ),
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.cancel.primary),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                _permissionCopy(
                  language,
                  connectedV1 ? 'deactivate_account' : 'delete_local_user',
                ),
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await run(() async {
        final navigator = Navigator.of(context); // capture before await
        final bool changed;
        const active = false;
        final command = 'set-active:${user.id}:$active';
        try {
          changed = connectedV1
              ? await ref
                    .read(usersProvider.notifier)
                    .setActive(
                      user.id,
                      false,
                      idempotencyKey: _idempotencyKeyFor(command),
                    )
              : await ref
                    .read(usersProvider.notifier)
                    .deleteUser(
                      user.id,
                      idempotencyKey: _idempotencyKeyFor(command),
                    );
        } catch (e) {
          return warn(_friendlyErr(e));
        }
        if (!changed) {
          return warn(
            _permissionCopy(language, 'last_admin_deactivation_error'),
          );
        }
        _completeCommand(command);
        await ref.logAudit(
          action: connectedV1 ? 'User deactivated' : 'Local user deleted',
          module: AuditModule.platform,
          refId: user.id,
          detail: connectedV1
              ? '${user.fullName} · account access removed; history retained'
              : '${user.fullName} · local development roster only',
        );
        if (!mounted) return;
        navigator.pop();
        success(
          _permissionCopy(
            language,
            connectedV1
                ? 'deactivate_account_success'
                : 'delete_local_user_success',
            name: user.fullName,
          ),
        );
      });
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit User',
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Gap(AppSpacing.xxs),
                        Text(
                          'Accounts are controlled by Admin. Historical activity remains attributed to the original user.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xxl),
              Text(
                user.fullName,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${user.email} · ${_roleLabel(user, yorksV1Provisioning: yorksV1Provisioning)}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              // Busy line — clear "working…" signal during a remote call.
              SizedBox(
                height: AppSpacing.lg,
                child: _busy
                    ? const Align(
                        alignment: Alignment.bottomCenter,
                        child: LinearProgressIndicator(minHeight: 2),
                      )
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: user.active,
                onChanged: _busy || !canManageActivationForTarget
                    ? null
                    : (_) => toggleActive(),
                title: Text(
                  AppStrings.accountActive.primary,
                  style: AppTypography.bodyLarge,
                ),
                subtitle: Text(
                  isCurrentUser
                      ? _permissionCopy(language, 'self_account_protected_body')
                      : AppStrings.accountActiveHint.active(language),
                  style: AppTypography.bodySmall,
                ),
                activeThumbColor: AppColors.primary,
              ),
              if (!yorksV1Provisioning && user.role == UserRole.engineer)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: user.inventoryAccess,
                  onChanged: _busy ? null : (_) => toggleAccess(),
                  title: Text(
                    AppStrings.inventoryAccess.primary,
                    style: AppTypography.bodyLarge,
                  ),
                  subtitle: Text(
                    AppStrings.inventoryAccessHint.primary,
                    style: AppTypography.bodySmall,
                  ),
                  activeThumbColor: AppColors.primary,
                ),

              // ─── Role ────────────────────────────────────────
              if (canAssignRolesForTarget) const Gap(AppSpacing.lg),
              if (canAssignRolesForTarget && yorksV1Provisioning)
                YorksV1RoleAssignmentEditor(
                  language: language,
                  primary: user.yorksV1RoleCache,
                  availableRoles: assignableRoles,
                  statusText: roleOptionsStatus,
                  onPrimaryChanged: _busy ? (_) {} : setYorksV1Role,
                )
              else if (canAssignRolesForTarget)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Role', style: AppTypography.titleSmall),
                    const Gap(AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final role in UserRole.values)
                          _RoleChip(
                            label: role.label,
                            selected: role == user.role,
                            onTap: _busy ? null : () => setLegacyRole(role),
                          ),
                      ],
                    ),
                  ],
                ),

              // V1 commercial authority is deliberately not backed by the
              // retained local permission overrides below. The child fetches a
              // live, Admin-only server projection and the Edge/DB command
              // remains authoritative even if this display cache is stale.
              if (access.canViewCommercialAccess &&
                  yorksV1Provisioning &&
                  user.yorksV1RoleCache != null) ...[
                const Gap(AppSpacing.lg),
                _YorksV1CommercialAccessSection(
                  appUserId: user.id,
                  targetRole: user.yorksV1RoleCache!,
                  canManage: access.canManageCommercialAccess,
                  busy: _busy,
                  runBusyCommand: run,
                  onFailure: warn,
                  onSuccess: success,
                ),
              ],

              // ─── HR employee link (drives leave + balance) ───
              if (access.canEditProfile) const Gap(AppSpacing.lg),
              if (access.canEditProfile)
                Text('HR employee', style: AppTypography.titleSmall),
              if (access.canEditProfile)
                Builder(
                  builder: (_) {
                    final linked = ref
                        .watch(employeesProvider)
                        .where((e) => e.id == user.employeeId)
                        .firstOrNull;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      enabled: !_busy,
                      leading: Icon(
                        linked == null
                            ? Icons.link_off_rounded
                            : Icons.badge_outlined,
                        color: AppColors.onSurfaceVariant,
                      ),
                      title: Text(
                        linked?.fullName ?? 'Not linked',
                        style: AppTypography.bodyLarge,
                      ),
                      subtitle: Text(
                        linked == null
                            ? 'Link so this person can request leave (HR + balance)'
                            : '${linked.jobRole} · ${linked.id}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: _busy ? null : pickEmployee,
                        child: Text(linked == null ? 'Link' : 'Change'),
                      ),
                      onTap: _busy ? null : pickEmployee,
                    );
                  },
                ),

              // ─── Permissions (per-user overrides) ────────────
              if (!yorksV1Provisioning && user.role != UserRole.admin) ...[
                const Gap(AppSpacing.lg),
                Text('Permissions', style: AppTypography.titleSmall),
                Text(
                  'Override what this person can access. Matches the role '
                  'default until you change it.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                for (final (key, label) in _managedPermissions)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: user.effectiveFor(key),
                    onChanged: _busy ? null : (v) => setOverride(key, v),
                    title: Text(label, style: AppTypography.bodyLarge),
                    subtitle: Text(
                      user.overrideFor(key) == null
                          ? 'Role default'
                          : 'Custom for this user',
                      style: AppTypography.bodySmall.copyWith(
                        color: user.overrideFor(key) == null
                            ? AppColors.onSurfaceVariant
                            : AppColors.primary,
                      ),
                    ),
                    activeThumbColor: AppColors.primary,
                  ),
              ],

              if (canResetPasswordForTarget) ...[
                const Gap(AppSpacing.lg),
                SecondaryButton(
                  label: AppStrings.resetPassword.primary,
                  icon: Icons.lock_reset_rounded,
                  onPressed: _busy ? null : resetPassword,
                ),
              ],
              if (canManageActivationForTarget && user.active) ...[
                const Gap(AppSpacing.sm),
                TextButton.icon(
                  key: const ValueKey('manage-sheet-deactivate-account'),
                  onPressed: _busy ? null : removeUserAccess,
                  icon: const Icon(
                    Icons.person_off_outlined,
                    color: AppColors.error,
                  ),
                  label: Text(
                    _permissionCopy(
                      language,
                      access.connectedV1
                          ? 'deactivate_account'
                          : 'delete_local_user',
                    ),
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
              const Gap(AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

/// Connected, Admin-only V1 commercial capability controls.
///
/// This section renders only a small authorization projection. It never loads
/// a commercial material, cost, quotation or other protected business value.
class _YorksV1CommercialAccessSection extends ConsumerWidget {
  const _YorksV1CommercialAccessSection({
    required this.appUserId,
    required this.targetRole,
    required this.canManage,
    required this.busy,
    required this.runBusyCommand,
    required this.onFailure,
    required this.onSuccess,
  });

  final String appUserId;
  final YorksV1Role targetRole;
  final bool canManage;
  final bool busy;
  final _UserManagementBusyCommand runBusyCommand;
  final ValueChanged<String> onFailure;
  final ValueChanged<String> onSuccess;

  /// Product Decisions permit a reasoned Admin override for an Engineer's
  /// protected commercial *view*. `manage_commercials` remains unavailable to
  /// both engineering roles and is also enforced by the server command.
  bool _mayChange(YorksV1CommercialCapability capability) =>
      switch (capability) {
        YorksV1CommercialCapability.viewCommercials => true,
        YorksV1CommercialCapability.manageCommercials =>
          targetRole == YorksV1Role.procurement ||
              targetRole == YorksV1Role.admin,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final access = ref.watch(yorksV1CommercialCapabilitiesProvider(appUserId));

    return access.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BilingualText(
            english: YorksV1ProjectStrings.commercialAccess.primary,
            secondary: YorksV1ProjectStrings.commercialAccess.secondary(
              language,
            ),
            englishStyle: AppTypography.titleSmall,
          ),
          const Gap(AppSpacing.xs),
          BilingualText(
            english: YorksV1ProjectStrings.commercialAccessUnavailable.primary,
            secondary: YorksV1ProjectStrings.commercialAccessUnavailable
                .secondary(language),
            englishStyle: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const Gap(AppSpacing.xs),
          TextButton.icon(
            onPressed: busy
                ? null
                : () => ref.invalidate(
                    yorksV1CommercialCapabilitiesProvider(appUserId),
                  ),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(YorksV1ProjectStrings.retry.primary),
          ),
        ],
      ),
      data: (capabilities) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BilingualText(
            english: YorksV1ProjectStrings.commercialAccess.primary,
            secondary: YorksV1ProjectStrings.commercialAccess.secondary(
              language,
            ),
            englishStyle: AppTypography.titleSmall,
          ),
          const Gap(AppSpacing.xs),
          BilingualText(
            english: YorksV1ProjectStrings.commercialAccessDescription.primary,
            secondary: YorksV1ProjectStrings.commercialAccessDescription
                .secondary(language),
            englishStyle: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const Gap(AppSpacing.sm),
          for (final capability in YorksV1CommercialCapability.values)
            _CommercialCapabilitySwitch(
              capability: capability,
              access: capabilities[capability],
              enabled: !busy && canManage && _mayChange(capability),
              onChanged: (granted) => _changeCapability(
                context,
                ref,
                capability: capability,
                granted: granted,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _changeCapability(
    BuildContext context,
    WidgetRef ref, {
    required YorksV1CommercialCapability capability,
    required bool granted,
  }) async {
    if (!canManage) return;
    final reason = await _askCommercialCapabilityReason(context);
    if (reason == null) return;

    await runBusyCommand(() async {
      try {
        await ref
            .read(yorksV1CommercialCapabilityRepositoryProvider)
            .setForAppUser(
              appUserId: appUserId,
              capability: capability,
              granted: granted,
              reason: reason,
              idempotencyKey: const Uuid().v4(),
            );
        ref.invalidate(yorksV1CommercialCapabilitiesProvider(appUserId));
        onSuccess(YorksV1ProjectStrings.accessUpdated.primary);
      } on YorksV1DomainException catch (error) {
        onFailure(YorksV1ProjectStrings.errorFor(error.code).primary);
      } catch (_) {
        onFailure(YorksV1ProjectStrings.commercialAccessUnavailable.primary);
      }
    });
  }

  Future<String?> _askCommercialCapabilityReason(BuildContext context) async {
    final controller = TextEditingController();
    String? validationError;
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: AppColors.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            ),
            title: Text(
              YorksV1ProjectStrings.commercialAccessChangeReason.primary,
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText:
                    YorksV1ProjectStrings.commercialAccessReasonHint.primary,
                errorText: validationError,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(YorksV1ProjectStrings.cancel.primary),
              ),
              FilledButton(
                onPressed: () {
                  final reason = controller.text.trim();
                  if (reason.isEmpty) {
                    setDialogState(
                      () => validationError = YorksV1ProjectStrings
                          .commercialAccessChangeReason
                          .primary,
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, reason);
                },
                child: Text(YorksV1ProjectStrings.saveAccessChange.primary),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }
}

class _CommercialCapabilitySwitch extends ConsumerWidget {
  const _CommercialCapabilitySwitch({
    required this.capability,
    required this.access,
    required this.enabled,
    required this.onChanged,
  });

  final YorksV1CommercialCapability capability;
  final YorksV1CommercialCapabilityAccess access;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final label = switch (capability) {
      YorksV1CommercialCapability.viewCommercials =>
        YorksV1ProjectStrings.viewCommercials,
      YorksV1CommercialCapability.manageCommercials =>
        YorksV1ProjectStrings.manageCommercials,
    };
    final source = access.usesRoleDefault
        ? YorksV1ProjectStrings.roleDefault
        : YorksV1ProjectStrings.customForUser;

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: access.effective,
      onChanged: enabled ? onChanged : null,
      title: BilingualText(
        english: label.primary,
        secondary: label.secondary(language),
        englishStyle: AppTypography.bodyLarge,
      ),
      subtitle: BilingualText(
        english: source.primary,
        secondary: source.secondary(language),
        englishStyle: AppTypography.bodySmall.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
      activeThumbColor: AppColors.primary,
    );
  }
}

// ─── Role chip ───────────────────────────────────────────────────
class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;

  /// Null → disabled (e.g. while a remote action is in flight).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null && !selected ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: AnimatedContainer(
          duration: Duration.zero,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : AppColors.primaryContainer.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
