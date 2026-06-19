import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/inventory_transaction.dart';
import '../../../../shared/providers/hr_provider.dart';
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_plan_provider.dart';
import '../../../../shared/providers/material_request_provider.dart';
import '../../../../shared/providers/notification_provider.dart';
import '../../../../shared/providers/project_provider.dart';
import '../../../../shared/providers/rentals_provider.dart';
import '../../../../shared/providers/session_provider.dart';
import '../../../../shared/providers/users_provider.dart';
import '../../../../shared/widgets/profile_menu_button.dart';

/// Home dashboard for office roles (procurement / admin). The single overview —
/// it replaces the old Dashboard tab AND the Admin-Panel "Overview". KPI cards
/// deep-link into the relevant tab/screen.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final currency = ref.watch(currencyProvider);
    final role = ref.watch(currentRoleProvider);
    final canSeeCost = role.canSeeCost;

    final totalValue = ref.watch(totalStockValueProvider);
    final matCount = ref.watch(materialCountProvider);
    // Procurement's actual work queue (plans to review + requests to dispatch).
    final procurementQueue =
        ref.watch(dispatchQueueCountProvider) +
        ref.watch(planReviewQueueCountProvider);
    final recentTxns = ref.watch(recentTransactionsProvider);
    final unreadNotifs = ref.watch(unreadNotificationCountProvider);
    final rentals = ref.watch(rentalsSummaryProvider);
    final hr = ref.watch(hrSummaryProvider);
    final activeUsers = ref.watch(activeUserCountProvider);
    final activeProjects = ref.watch(activeProjectCountProvider);

    // Deep-linking KPI cards (filtered by capability).
    final kpis = <_Kpi>[
      // Procurement's primary job, surfaced front-and-centre and deep-linked
      // straight to the workspace (plans to review + requests to dispatch).
      _Kpi(
        label: AppStrings.awaitingAction.primary,
        value: '$procurementQueue',
        icon: Icons.assignment_turned_in_outlined,
        color: AppColors.warning,
        onTap: () => context.push(RoutePaths.procurement),
      ),
      if (role.canAccessRentals)
        _Kpi(
          label: AppStrings.overdueTotal.primary,
          value: currency.format(rentals.overdueTotal),
          icon: Icons.warning_amber_rounded,
          color: AppColors.error,
          onTap: () => context.go(RoutePaths.rentals),
        ),
      if (role.canAccessPeople)
        _Kpi(
          label: 'On leave / absent',
          value: '${hr.onLeaveToday + hr.absentToday}',
          icon: Icons.event_busy_outlined,
          color: AppColors.tertiary,
          onTap: () => context.go(RoutePaths.people),
        ),
      _Kpi(
        label: AppStrings.materials.primary,
        value: '$matCount',
        icon: Icons.category_outlined,
        color: AppColors.primary,
        onTap: () => context.push(RoutePaths.inventory),
      ),
      if (role.isAdmin)
        _Kpi(
          label: AppStrings.activeUsers.primary,
          value: '$activeUsers',
          icon: Icons.group_outlined,
          color: AppColors.primary,
          onTap: () => context.push(RoutePaths.users),
        ),
      if (role.isAdmin)
        _Kpi(
          label: AppStrings.activeProjects.primary,
          value: '$activeProjects',
          icon: Icons.folder_open_outlined,
          color: AppColors.tertiary,
          onTap: () => context.push(RoutePaths.adminProjects),
        ),
    ];

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // ─── Header ──────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.screenVertical,
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: BilingualText(
                      english: AppStrings.home.primary,
                      secondary: AppStrings.dashboard.secondary(lang),
                      englishStyle: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.28,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  _NotificationButton(unread: unreadNotifs),
                  const Gap(AppSpacing.xs),
                  const ProfileMenuButton(),
                ],
              ),
            ),
          ),

          // ─── Hero: total stock value (→ Inventory) ───────
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(
              child: LedgerCard(
                color: AppColors.surfaceContainerLowest,
                onTap: () => context.push(RoutePaths.inventory),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BilingualText(
                      english: AppStrings.totalStockValue.primary,
                      secondary: AppStrings.totalStockValue.secondary(lang),
                      englishStyle: AppTypography.titleSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const Gap(AppSpacing.md),
                    Text(
                      canSeeCost ? currency.format(totalValue) : '— — —',
                      style: AppTypography.displayLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    if (matCount == 0)
                      StatusChip.info(AppStrings.noDataYet.primary)
                    else
                      StatusChip.success(
                        '$matCount ${AppStrings.materials.primary}',
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SliverGap(AppSpacing.lg),

          // ─── KPI grid (deep-links) ───────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(
              child: GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width >= 600 ? 3 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.5,
                children: [for (final k in kpis) _KpiCard(kpi: k)],
              ),
            ),
          ),

          // ─── Recent Activity ────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Gap(AppSpacing.lg),
                  BilingualText(
                    english: AppStrings.recentActivity.primary,
                    secondary: AppStrings.recentActivity.secondary(lang),
                    englishStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Gap(AppSpacing.lg),
                ],
              ),
            ),
          ),

          if (recentTxns.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverToBoxAdapter(
                child: LedgerCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.huge,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: AppColors.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const Gap(AppSpacing.lg),
                          BilingualText(
                            english: AppStrings.noRecentActivity.primary,
                            secondary: AppStrings.noRecentActivity.secondary(
                              lang,
                            ),
                            englishStyle: AppTypography.bodyMedium.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                            crossAxisAlignment: CrossAxisAlignment.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverList.separated(
                itemCount: recentTxns.length,
                separatorBuilder: (_, _) => const Gap(AppSpacing.listItemGap),
                itemBuilder: (context, index) =>
                    _RecentActivityCard(txn: recentTxns[index]),
              ),
            ),

          const SliverGap(AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ─── Notification bell ───────────────────────────────────────────
class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => context.push(RoutePaths.notifications),
          icon: const Icon(Icons.notifications_outlined),
          style: IconButton.styleFrom(foregroundColor: AppColors.primary),
        ),
        if (unread > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── KPI card (deep-link) ────────────────────────────────────────
class _Kpi {
  const _Kpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});

  final _Kpi kpi;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      color: AppColors.surfaceContainerLowest,
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: kpi.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(kpi.icon, size: 20, color: kpi.color),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  kpi.value,
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: kpi.color,
                  ),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              Text(
                kpi.label,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Recent Activity Card ────────────────────────────────────────
class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.txn});

  final InventoryTransaction txn;

  @override
  Widget build(BuildContext context) {
    final isIncoming = txn.type == TransactionType.incoming;
    final dateFormat = DateFormat('MMM d, h:mm a');

    return LedgerCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isIncoming
                  ? AppColors.successContainer.withValues(alpha: 0.25)
                  : AppColors.errorContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              isIncoming
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 18,
              color: isIncoming ? AppColors.success : AppColors.error,
            ),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn.materialName, style: AppTypography.titleSmall),
                const Gap(AppSpacing.xxs),
                Text(
                  dateFormat.format(txn.timestamp),
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            txn.formattedQuantity,
            style: AppTypography.titleSmall.copyWith(
              color: isIncoming ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
