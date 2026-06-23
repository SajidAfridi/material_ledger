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

/// Editable "who can see & do what" matrix. The Admin grants/revokes each
/// role-level capability and it takes effect immediately (the `canX` providers
/// + route guards read [rolePermissionsProvider] live). Per-user exceptions in
/// User management still override these defaults. Admin-only (route-guarded).
class AccessRolesScreen extends ConsumerWidget {
  const AccessRolesScreen({super.key});

  static bool _materials(UserRole r) => r.canAccessMaterials;
  static bool _adminMore(UserRole r) => r.isAdmin;

  static final _rows = <_MatrixRow>[
    const _MatrixRow('See cost prices', cap: RoleCapability.cost),
    const _MatrixRow('See salaries', cap: RoleCapability.salary),
    _MatrixRow('Materials', structural: _materials),
    const _MatrixRow('Rentals', cap: RoleCapability.rentals),
    const _MatrixRow('Write rentals', cap: RoleCapability.writeRentals),
    const _MatrixRow('People / HR', cap: RoleCapability.people),
    const _MatrixRow('Write people', cap: RoleCapability.writePeople),
    const _MatrixRow('Goods receipt', cap: RoleCapability.goods),
    const _MatrixRow('Finance / costs', cap: RoleCapability.finance),
    _MatrixRow('Admin (More)', structural: _adminMore),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final perms = ref.watch(rolePermissionsProvider);
    const roles = UserRole.values;

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
                'Tap a cell to grant or revoke. Changes apply immediately.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const Gap(AppSpacing.lg),
              LedgerCard(
                color: AppColors.surfaceContainerLowest,
                child: Column(
                  children: [
                    // Header row of role names.
                    Row(
                      children: [
                        const Expanded(flex: 4, child: SizedBox()),
                        for (final r in roles)
                          Expanded(
                            flex: 2,
                            child: Text(
                              r.label,
                              textAlign: TextAlign.center,
                              style: AppTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Gap(AppSpacing.md),
                    for (final row in _rows) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(row.label, style: AppTypography.bodySmall),
                          ),
                          for (final r in roles)
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: _cell(context, ref, perms, r, row),
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
                'Admin is a fixed superuser and Materials is always on. Per-user '
                'exceptions in User management override these role defaults. Note: '
                'engineer office modules (rentals, people, finance, goods) save '
                'here but have no engineer screen yet. In production, roles come '
                'from sign-in credentials (Auth custom claims).',
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
      onTap: () => _toggle(context, ref, role, row.cap!, value),
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

  void _toggle(
    BuildContext context,
    WidgetRef ref,
    UserRole role,
    RoleCapability cap,
    bool current,
  ) {
    AppFeedback.confirm();
    ref.read(rolePermissionsProvider.notifier).setCapability(role, cap, !current);
    ref.logAudit(
      action: 'Role permission changed',
      module: AuditModule.platform,
      refId: role.name,
      detail: '${role.label} · ${cap.name} → ${!current ? 'granted' : 'revoked'}',
    );
  }

  Future<void> _resetAll(BuildContext context, WidgetRef ref) async {
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
    await ref.read(rolePermissionsProvider.notifier).resetAll();
    await ref.logAudit(
      action: 'Role permissions reset to defaults',
      module: AuditModule.platform,
      refId: 'all',
      detail: 'All roles restored to built-in defaults',
    );
  }
}

class _MatrixRow {
  const _MatrixRow(this.label, {this.cap, this.structural});

  final String label;
  final RoleCapability? cap;
  final bool Function(UserRole)? structural;

  bool get isStructural => structural != null;
}
