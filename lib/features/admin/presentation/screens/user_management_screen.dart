import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/feedback/feedback_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/effective_permissions.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/hr_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/users_provider.dart';

/// Strips the `Exception: ` prefix so remote-provisioning errors read cleanly in
/// a snackbar.
String _friendlyErr(Object e) {
  final s = e.toString();
  const p = 'Exception: ';
  return s.startsWith(p) ? s.substring(p.length) : s;
}

/// The per-user capabilities an Admin can grant/revoke, with display labels.
const _managedPermissions = <(PermissionKey, String)>[
  (PermissionKey.viewCommercials, 'View commercials'),
  (PermissionKey.finance, 'Financial reports'),
  (PermissionKey.salary, 'Salary & HR documents'),
  (PermissionKey.rentals, 'Rentals module'),
  (PermissionKey.people, 'People / HR module'),
  (PermissionKey.goods, 'Receive goods (stock-in)'),
];

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

  bool _matches(AppUser u) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return u.fullName.toLowerCase().contains(q) ||
        u.email.toLowerCase().contains(q) ||
        u.role.label.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final all = ref.watch(usersProvider);
    final users = all.where(_matches).toList();

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
                        itemBuilder: (context, i) => _UserCard(user: users[i]),
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
  const _UserCard({required this.user});
  final AppUser user;

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
              StatusChip.info(user.role.label),
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
  UserRole _role = UserRole.engineer;
  bool _busy = false;

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
      // When Supabase is configured this provisions the account in the identity
      // provider (via the admin-users function) before storing it locally; a
      // failure (e.g. duplicate email) throws and nothing is written.
      final user = await ref
          .read(usersProvider.notifier)
          .createUser(
            fullName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            role: _role,
            password: _passwordController.text,
          );
      await ref.logAudit(
        action: 'User created',
        module: AuditModule.platform,
        refId: user.id,
        detail: '${user.fullName} · ${user.role.label}',
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
                      for (final r in UserRole.values)
                        _RoleChip(
                          label: r.label,
                          selected: _role == r,
                          onTap: () => setState(() => _role = r),
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

  @override
  Widget build(BuildContext context) {
    final user = ref
        .watch(usersProvider)
        .where((u) => u.id == widget.userId)
        .firstOrNull;
    if (user == null) return const SizedBox.shrink();

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
      try {
        final allowed = await ref
            .read(usersProvider.notifier)
            .setActive(user.id, willActivate);
        if (!allowed) return warn("Can't deactivate the only active admin.");
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
      final temp = 'Temp${1000 + Random().nextInt(9000)}';
      try {
        await ref
            .read(usersProvider.notifier)
            .setPassword(user.id, temp, temporary: true);
      } catch (e) {
        return warn(_friendlyErr(e));
      }
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

    Future<void> setRole(UserRole role) => run(() async {
      if (role == user.role) return;
      try {
        final allowed = await ref
            .read(usersProvider.notifier)
            .setRole(user.id, role);
        if (!allowed) return warn("Can't change the only active admin's role.");
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

    Future<void> setOverride(PermissionKey key, bool value) => run(() async {
      // Toggling back to the role default clears the override entirely.
      final next = value == user.roleDefaultFor(key) ? null : value;
      try {
        await ref
            .read(usersProvider.notifier)
            .setPermissionOverride(user.id, key, next);
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
        try {
          deleted = await ref.read(usersProvider.notifier).deleteUser(user.id);
        } catch (e) {
          return warn(_friendlyErr(e));
        }
        if (!deleted) {
          return warn(
            "Can't delete the only active admin — assign another admin first.",
          );
        }
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
                '${user.email} · ${user.role.label}',
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
              if (user.role == UserRole.engineer)
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
                  for (final r in UserRole.values)
                    _RoleChip(
                      label: r.label,
                      selected: r == user.role,
                      onTap: _busy ? null : () => setRole(r),
                    ),
                ],
              ),

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
              if (user.role != UserRole.admin) ...[
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
          duration: const Duration(milliseconds: 160),
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
