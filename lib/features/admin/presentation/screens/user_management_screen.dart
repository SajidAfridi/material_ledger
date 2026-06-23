import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/effective_permissions.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/users_provider.dart';

/// The per-user capabilities an Admin can grant/revoke, with display labels.
const _managedPermissions = <(PermissionKey, String)>[
  (PermissionKey.cost, 'See unit cost'),
  (PermissionKey.finance, 'Financial reports'),
  (PermissionKey.salary, 'Salary & HR documents'),
  (PermissionKey.rentals, 'Rentals module'),
  (PermissionKey.people, 'People / HR module'),
  (PermissionKey.goods, 'Receive goods (stock-in)'),
];

/// Admin user management & access control (SRS §4.7). Create / edit /
/// deactivate accounts, assign roles, reset passwords, grant or revoke
/// per-engineer inventory access. No self-signup — Admin creates every account.
class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final users = ref.watch(usersProvider);

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
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.md,
              AppSpacing.screenHorizontal,
              AppSpacing.huge,
            ),
            itemCount: users.length,
            separatorBuilder: (_, _) => const Gap(AppSpacing.listItemGap),
            itemBuilder: (context, i) => _UserCard(user: users[i]),
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
    final user = await ref
        .read(usersProvider.notifier)
        .createUser(
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          role: _role,
          password: _passwordController.text,
        );
    // Stored as a salted local hash now (the user must change it on first
    // sign-in); becomes a Firebase Auth credential when Firebase lands.
    await ref.logAudit(
      action: 'User created',
      module: AuditModule.platform,
      refId: user.id,
      detail: '${user.fullName} · ${user.role.label}',
    );
    if (!mounted) return;
    Navigator.pop(context);
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
                      if (!t.contains('@')) return AppStrings.emailAddress.primary;
                      return null;
                    },
                  ),
                  const Gap(AppSpacing.lg),
                  Text(AppStrings.roleLabel.primary, style: AppTypography.titleSmall),
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
class _ManageUserSheet extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref
        .watch(usersProvider)
        .where((u) => u.id == userId)
        .firstOrNull;
    if (user == null) return const SizedBox.shrink();

    Future<void> toggleActive() async {
      await ref.read(usersProvider.notifier).setActive(user.id, !user.active);
      await ref.logAudit(
        action: user.active ? 'User deactivated' : 'User reactivated',
        module: AuditModule.platform,
        refId: user.id,
        detail: user.fullName,
      );
    }

    Future<void> toggleAccess() async {
      await ref
          .read(usersProvider.notifier)
          .setInventoryAccess(user.id, !user.inventoryAccess);
      await ref.logAudit(
        action: user.inventoryAccess
            ? 'Inventory access revoked'
            : 'Inventory access granted',
        module: AuditModule.platform,
        refId: user.id,
        detail: user.fullName,
      );
    }

    Future<void> resetPassword() async {
      // Set a temporary password the admin can share; the user must change it on
      // first sign-in. (With Firebase this becomes an Auth reset link.)
      final temp = 'Temp${1000 + Random().nextInt(9000)}';
      await ref
          .read(usersProvider.notifier)
          .setPassword(user.id, temp, temporary: true);
      await ref.logAudit(
        action: 'Password reset',
        module: AuditModule.platform,
        refId: user.id,
        detail: user.fullName,
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          title: const Text('Temporary password'),
          content: Text(
            'Share this with ${user.fullName}. They must change it on first '
            'sign-in:\n\n$temp',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.done.primary),
            ),
          ],
        ),
      );
    }

    Future<void> setRole(UserRole role) async {
      if (role == user.role) return;
      await ref.read(usersProvider.notifier).setRole(user.id, role);
      await ref.logAudit(
        action: 'User role changed',
        module: AuditModule.platform,
        refId: user.id,
        detail: '${user.fullName} → ${role.label}',
      );
    }

    Future<void> setOverride(PermissionKey key, bool value) async {
      // Toggling back to the role default clears the override entirely.
      final next = value == user.roleDefaultFor(key) ? null : value;
      await ref.read(usersProvider.notifier).setPermissionOverride(
            user.id,
            key,
            next,
          );
      await ref.logAudit(
        action: 'Permission updated',
        module: AuditModule.platform,
        refId: user.id,
        detail: '${user.fullName} · $key = ${next ?? 'role default'}',
      );
    }

    Future<void> deleteUser() async {
      final ok = await showDialog<bool>(
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
      if (ok != true) return;
      await ref.read(usersProvider.notifier).deleteUser(user.id);
      await ref.logAudit(
        action: 'User deleted',
        module: AuditModule.platform,
        refId: user.id,
        detail: user.fullName,
      );
      if (!context.mounted) return;
      Navigator.pop(context);
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
              const Gap(AppSpacing.lg),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: user.active,
                onChanged: (_) => toggleActive(),
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
                  onChanged: (_) => toggleAccess(),
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
                      onTap: () => setRole(r),
                    ),
                ],
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
                    onChanged: (v) => setOverride(key, v),
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
                onPressed: resetPassword,
              ),
              const Gap(AppSpacing.sm),
              TextButton.icon(
                onPressed: deleteUser,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
    );
  }
}
