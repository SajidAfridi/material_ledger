import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/feedback/feedback_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/role_permissions.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/role_permissions_provider.dart';
import '../../../../shared/providers/users_provider.dart';

/// Editable "who can see & do what" matrix. The Admin grants/revokes each
/// role-level capability and it takes effect immediately (the `canX` providers
/// + route guards read [rolePermissionsProvider] live). Per-user exceptions in
/// User management still override these defaults. Admin-only (route-guarded).
class AccessRolesScreen extends ConsumerWidget {
  const AccessRolesScreen({super.key});

  static bool _materials(UserRole r) => r.canAccessMaterials;
  static bool _adminMore(UserRole r) => r.isAdmin;

  // Each row pairs a short label with a plain-language description so a
  // non-technical admin can tell read from write without guessing.
  static final _rows = <_MatrixRow>[
    const _MatrixRow(
      'View commercials',
      desc: 'View unit costs, totals & stock value',
      cap: RoleCapability.viewCommercials,
    ),
    const _MatrixRow(
      'See salaries',
      desc: 'View pay & HR documents',
      cap: RoleCapability.salary,
    ),
    _MatrixRow(
      'Materials',
      desc: 'Always on for office roles',
      structural: _materials,
    ),
    const _MatrixRow(
      'Rentals',
      desc: 'Open the Rentals module',
      cap: RoleCapability.rentals,
    ),
    const _MatrixRow(
      'Write rentals',
      desc: 'Add units & record payments',
      cap: RoleCapability.writeRentals,
    ),
    const _MatrixRow(
      'People / HR',
      desc: 'Open the People module',
      cap: RoleCapability.people,
    ),
    const _MatrixRow(
      'Write people',
      desc: 'Add & edit employee records',
      cap: RoleCapability.writePeople,
    ),
    const _MatrixRow(
      'Goods receipt',
      desc: 'Receive stock into the store',
      cap: RoleCapability.goods,
    ),
    const _MatrixRow(
      'Approve leave',
      desc: 'Approve or reject leave',
      cap: RoleCapability.approveLeave,
    ),
    const _MatrixRow(
      'Finance / costs',
      desc: 'Open project cost reports',
      cap: RoleCapability.finance,
    ),
    _MatrixRow(
      'Admin (More)',
      desc: 'Superuser — always on',
      structural: _adminMore,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final perms = ref.watch(rolePermissionsProvider);
    final users = ref.watch(usersProvider);
    const roles = UserRole.values;

    int roleCount(UserRole r) => users.where((u) => u.role == r).length;

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
          english: AppStrings.accessRoles.primary,
          secondary: AppStrings.accessRoles.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Reset to defaults',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () => _resetAll(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              Text(
                'Tap a cell to grant or revoke. Changes apply immediately to '
                'everyone in that role.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const Gap(AppSpacing.lg),
              LedgerCard(
                color: AppColors.surfaceContainerLowest,
                child: Column(
                  children: [
                    // Header row of role names + how many users each affects.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Expanded(flex: 5, child: SizedBox()),
                        for (final r in roles)
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                Text(
                                  r.label,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.labelSmall.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  '${roleCount(r)} '
                                  '${roleCount(r) == 1 ? 'user' : 'users'}',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.labelSmall.copyWith(
                                    fontSize: 10,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const Gap(AppSpacing.md),
                    const Divider(height: 1),
                    const Gap(AppSpacing.md),
                    for (final row in _rows) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.label,
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  row.desc,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final r in roles)
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: _cell(
                                  context,
                                  ref,
                                  perms,
                                  r,
                                  row,
                                  roleCount(r),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Gap(AppSpacing.md),
                    ],
                  ],
                ),
              ),
              const Gap(AppSpacing.lg),
              Text(
                'Admin is a fixed superuser and Materials is always on for '
                'office roles. Per-user exceptions in User management override '
                'these role defaults. Revoking a capability re-stamps every '
                "affected user's access immediately.",
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    WidgetRef ref,
    RolePermissions perms,
    UserRole role,
    _MatrixRow row,
    int affectedUsers,
  ) {
    final bool value;
    final bool locked;
    if (row.isStructural) {
      value = row.structural!(role);
      locked = true; // Materials / Admin(More) are role-bound, not grantable.
    } else {
      value = perms.has(role, row.cap!);
      locked = role.isAdmin; // Admin = superuser, can't be reduced (lock-out).
    }

    if (locked) {
      return Icon(
        value ? Icons.check_circle_rounded : Icons.remove_rounded,
        size: 18,
        color: value
            ? AppColors.success.withValues(alpha: 0.45)
            : AppColors.outlineVariant,
      );
    }

    return InkWell(
      onTap: () => _toggle(context, ref, role, row, value, affectedUsers),
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Icon(
          value
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 20,
          color: value ? AppColors.success : AppColors.outlineVariant,
        ),
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    UserRole role,
    _MatrixRow row,
    bool current,
    int affectedUsers,
  ) async {
    final cap = row.cap!;
    final granting = !current;
    final messenger = ScaffoldMessenger.of(context);

    // Revoking role-wide access can lock real people out mid-shift — confirm it
    // and say exactly how many users it hits (blast radius).
    if (!granting && affectedUsers > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          title: Text('Revoke access?', style: AppTypography.titleMedium),
          content: Text(
            "Remove '${row.label}' from ${role.label}. This affects "
            '$affectedUsers ${affectedUsers == 1 ? 'user' : 'users'} '
            'immediately.',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.cancel.primary),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Revoke',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
      if (ok != true) return;
      AppFeedback.warning();
    } else {
      AppFeedback.confirm();
    }

    final failures = await ref
        .read(rolePermissionsProvider.notifier)
        .setCapability(role, cap, granting);
    await ref.logAudit(
      action: 'Role permission changed',
      module: AuditModule.platform,
      refId: role.name,
      detail:
          '${role.label} · ${cap.name} → ${granting ? 'granted' : 'revoked'}',
    );
    if (!context.mounted) return;
    if (failures > 0) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Saved — but $failures '
            "${failures == 1 ? "user's" : "users'"} access will sync on their "
            'next sign-in.',
          ),
        ),
      );
    }
  }

  Future<void> _resetAll(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        title: Text('Reset to defaults?', style: AppTypography.titleMedium),
        content: Text(
          'Restores every role to its built-in permissions.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel.primary),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final failures = await ref
        .read(rolePermissionsProvider.notifier)
        .resetAll();
    await ref.logAudit(
      action: 'Role permissions reset to defaults',
      module: AuditModule.platform,
      refId: 'all',
      detail: 'All roles restored to built-in defaults',
    );
    if (!context.mounted) return;
    AppFeedback.confirm();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: failures > 0 ? AppColors.error : null,
        content: Text(
          failures > 0
              ? 'Reset — but $failures user claim(s) will sync on next sign-in.'
              : 'Roles reset to defaults.',
        ),
      ),
    );
  }
}

class _MatrixRow {
  const _MatrixRow(this.label, {required this.desc, this.cap, this.structural});

  final String label;
  final String desc;
  final RoleCapability? cap;
  final bool Function(UserRole)? structural;

  bool get isStructural => structural != null;
}
