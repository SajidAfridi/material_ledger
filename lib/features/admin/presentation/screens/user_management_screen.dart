import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/feedback/feedback_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/effective_permissions.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/models/yorks_v1_commercial_capability.dart';
import '../../../../shared/models/yorks_v1_domain_error.dart';
import '../../../../shared/models/yorks_v1_project_strings.dart';
import '../../../../shared/models/yorks_v1_role.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/hr_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/users_provider.dart';
import '../../../../shared/providers/yorks_v1_commercial_capability_provider.dart';

/// Strips the `Exception: ` prefix so remote-provisioning errors read cleanly in
/// a snackbar.
String _friendlyErr(Object e) {
  final s = e.toString();
  const p = 'Exception: ';
  return s.startsWith(p) ? s.substring(p.length) : s;
}

/// Display-only role text for the retained roster. V1 authorization never uses
/// this cache; server commands and route guards read the current exact claim.
String _roleLabel(AppUser user, {required bool yorksV1Provisioning}) {
  if (!yorksV1Provisioning) return user.role.label;
  final role = user.yorksV1RoleCache;
  return role == null
      ? AppStrings.yorksV1RoleMappingRequired.primary
      : _yorksV1RoleText(role).primary;
}

TranslatableString _yorksV1RoleText(YorksV1Role role) => switch (role) {
  YorksV1Role.projectEngineer => AppStrings.projectEngineerRole,
  YorksV1Role.siteEngineer => AppStrings.siteEngineerRole,
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

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final all = ref.watch(usersProvider);
    final yorksV1Provisioning = ref.watch(
      yorksV1UserProvisioningEnabledProvider,
    );
    final users = all
        .where(
          (user) => _matches(user, yorksV1Provisioning: yorksV1Provisioning),
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: BilingualText(
          english: AppStrings.userManagement.primary,
          secondary: AppStrings.userManagement.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _AddUserSheet.show(context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(AppStrings.addUser.primary),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.md,
                  AppSpacing.screenHorizontal,
                  AppSpacing.sm,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  style: AppTypography.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceContainerHighest,
                    hintText: 'Search name, email, role',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: users.isEmpty
                    ? Center(
                        child: Text(
                          all.isEmpty ? 'No users yet' : 'No matching users',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          AppSpacing.sm,
                          AppSpacing.screenHorizontal,
                          AppSpacing.huge,
                        ),
                        itemCount: users.length,
                        separatorBuilder: (_, _) =>
                            const Gap(AppSpacing.listItemGap),
                        itemBuilder: (context, i) => _UserCard(
                          user: users[i],
                          yorksV1Provisioning: yorksV1Provisioning,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.yorksV1Provisioning});
  final AppUser user;
  final bool yorksV1Provisioning;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      onTap: () => _ManageUserSheet.show(context, user),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: user.active
                ? AppColors.primaryContainer.withValues(alpha: 0.15)
                : AppColors.surfaceContainerHigh,
            child: Text(
              user.initials,
              style: AppTypography.labelLarge.copyWith(
                color: user.active
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: AppTypography.titleSmall),
                const Gap(AppSpacing.xxs),
                Text(
                  user.email,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusChip.info(
                _roleLabel(user, yorksV1Provisioning: yorksV1Provisioning),
              ),
              const Gap(AppSpacing.xs),
              user.active
                  ? StatusChip.success(AppStrings.userActive.primary)
                  : StatusChip.error(AppStrings.userInactive.primary),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Add user ────────────────────────────────────────────────────
class _AddUserSheet extends ConsumerStatefulWidget {
  const _AddUserSheet();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddUserSheet(),
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
    setState(() => _busy = true);
    try {
      final yorksV1Provisioning = ref.read(
        yorksV1UserProvisioningEnabledProvider,
      );
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
    final yorksV1Provisioning = ref.watch(
      yorksV1UserProvisioningEnabledProvider,
    );
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
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
                        child: Text(
                          AppStrings.addUser.primary,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const Gap(AppSpacing.lg),
                  LedgerTextField(
                    controller: _nameController,
                    label: AppStrings.fullName.primary,
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? AppStrings.fieldRequired.primary
                        : null,
                  ),
                  const Gap(AppSpacing.lg),
                  LedgerTextField(
                    controller: _emailController,
                    label: AppStrings.emailAddress.primary,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return AppStrings.fieldRequired.primary;
                      if (!t.contains('@')) {
                        return AppStrings.emailAddress.primary;
                      }
                      return null;
                    },
                  ),
                  const Gap(AppSpacing.lg),
                  Text(
                    AppStrings.roleLabel.primary,
                    style: AppTypography.titleSmall,
                  ),
                  const Gap(AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      if (yorksV1Provisioning)
                        for (final role in YorksV1Role.values)
                          _RoleChip(
                            label: _yorksV1RoleText(role).primary,
                            selected: _yorksV1Role == role,
                            onTap: () => setState(() => _yorksV1Role = role),
                          )
                      else
                        for (final role in UserRole.values)
                          _RoleChip(
                            label: role.label,
                            selected: _legacyRole == role,
                            onTap: () => setState(() => _legacyRole = role),
                          ),
                    ],
                  ),
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
                    onPressed: _busy ? null : _save,
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
  const _ManageUserSheet({required this.userId});
  final String userId;

  static Future<void> show(BuildContext context, AppUser user) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManageUserSheet(userId: user.id),
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
    final yorksV1Provisioning = ref.watch(
      yorksV1UserProvisioningEnabledProvider,
    );

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
        if (!allowed) return warn("Can't deactivate the only active admin.");
        _completeCommand(command);
        await ref.logAudit(
          action: willActivate ? 'User reactivated' : 'User deactivated',
          module: AuditModule.platform,
          refId: user.id,
          detail: user.fullName,
        );
        success(willActivate ? 'Account reactivated' : 'Account deactivated');
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

    Future<void> deleteUser() async {
      if (_busy) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          title: const Text('Delete user?'),
          content: Text(
            'Permanently remove ${user.fullName}. This cannot be undone.',
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
                AppStrings.delete.primary,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await run(() async {
        final navigator = Navigator.of(context); // capture before await
        final bool deleted;
        const active = false;
        final command = 'set-active:${user.id}:$active';
        try {
          deleted = await ref
              .read(usersProvider.notifier)
              .deleteUser(user.id, idempotencyKey: _idempotencyKeyFor(command));
        } catch (e) {
          return warn(_friendlyErr(e));
        }
        if (!deleted) {
          return warn(
            "Can't delete the only active admin — assign another admin first.",
          );
        }
        _completeCommand(command);
        await ref.logAudit(
          action: 'User deleted',
          module: AuditModule.platform,
          refId: user.id,
          detail: user.fullName,
        );
        if (!mounted) return;
        navigator.pop();
        success('${user.fullName} deleted');
      });
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Gap(AppSpacing.xxs),
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
                onChanged: _busy ? null : (_) => toggleActive(),
                title: Text(
                  AppStrings.accountActive.primary,
                  style: AppTypography.bodyLarge,
                ),
                subtitle: Text(
                  AppStrings.accountActiveHint.primary,
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
              const Gap(AppSpacing.lg),
              Text('Role', style: AppTypography.titleSmall),
              const Gap(AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (yorksV1Provisioning)
                    for (final role in YorksV1Role.values)
                      _RoleChip(
                        label: _yorksV1RoleText(role).primary,
                        selected: role == user.yorksV1RoleCache,
                        onTap: _busy ? null : () => setYorksV1Role(role),
                      )
                  else
                    for (final role in UserRole.values)
                      _RoleChip(
                        label: role.label,
                        selected: role == user.role,
                        onTap: _busy ? null : () => setLegacyRole(role),
                      ),
                ],
              ),

              // V1 commercial authority is deliberately not backed by the
              // retained local permission overrides below. The child fetches a
              // live, Admin-only server projection and the Edge/DB command
              // remains authoritative even if this display cache is stale.
              if (yorksV1Provisioning && user.yorksV1RoleCache != null) ...[
                const Gap(AppSpacing.lg),
                _YorksV1CommercialAccessSection(
                  appUserId: user.id,
                  targetRole: user.yorksV1RoleCache!,
                  busy: _busy,
                  runBusyCommand: run,
                  onFailure: warn,
                  onSuccess: success,
                ),
              ],

              // ─── HR employee link (drives leave + balance) ───
              const Gap(AppSpacing.lg),
              Text('HR employee', style: AppTypography.titleSmall),
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

              const Gap(AppSpacing.lg),
              SecondaryButton(
                label: AppStrings.resetPassword.primary,
                icon: Icons.lock_reset_rounded,
                onPressed: _busy ? null : resetPassword,
              ),
              const Gap(AppSpacing.sm),
              TextButton.icon(
                onPressed: _busy ? null : deleteUser,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                label: Text(
                  'Delete user',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
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
    required this.busy,
    required this.runBusyCommand,
    required this.onFailure,
    required this.onSuccess,
  });

  final String appUserId;
  final YorksV1Role targetRole;
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
              enabled: !busy && _mayChange(capability),
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
