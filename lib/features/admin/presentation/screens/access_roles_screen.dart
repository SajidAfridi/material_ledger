import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/language_provider.dart';

/// Read-only "who can see & do what" matrix, derived directly from the
/// [UserRole] capability getters (the single source of truth also used by the
/// router guards and Firestore rules). No new logic — a transparent view of the
/// existing access model. Admin-only (gated in the router).
class AccessRolesScreen extends ConsumerWidget {
  const AccessRolesScreen({super.key});

  static const _capabilities = <({String label, bool Function(UserRole) of})>[
    (label: 'See cost prices', of: _canSeeCost),
    (label: 'See salaries', of: _canSeeSalary),
    (label: 'Materials', of: _canAccessMaterials),
    (label: 'Rentals', of: _canAccessRentals),
    (label: 'Write rentals', of: _canWriteRentals),
    (label: 'People / HR', of: _canAccessPeople),
    (label: 'Write people', of: _canWritePeople),
    (label: 'Goods receipt', of: _canReceiveGoods),
    (label: 'Finance / costs', of: _canViewFinance),
    (label: 'Admin (More)', of: _isAdmin),
  ];

  // Tear-offs (const list can't hold instance getters directly).
  static bool _canSeeCost(UserRole r) => r.canSeeCost;
  static bool _canSeeSalary(UserRole r) => r.canSeeSalary;
  static bool _canAccessMaterials(UserRole r) => r.canAccessMaterials;
  static bool _canAccessRentals(UserRole r) => r.canAccessRentals;
  static bool _canWriteRentals(UserRole r) => r.canWriteRentals;
  static bool _canAccessPeople(UserRole r) => r.canAccessPeople;
  static bool _canWritePeople(UserRole r) => r.canWritePeople;
  static bool _canReceiveGoods(UserRole r) => r.canReceiveGoods;
  static bool _canViewFinance(UserRole r) => r.canViewFinance;
  static bool _isAdmin(UserRole r) => r.isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
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
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              Text(
                AppStrings.accessRolesHint.primary,
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
                    for (final cap in _capabilities) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              cap.label,
                              style: AppTypography.bodySmall,
                            ),
                          ),
                          for (final r in roles)
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Icon(
                                  cap.of(r)
                                      ? Icons.check_circle_rounded
                                      : Icons.remove_rounded,
                                  size: 18,
                                  color: cap.of(r)
                                      ? AppColors.success
                                      : AppColors.outlineVariant,
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
                'Roles are assigned in User management. In production they come '
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
}
