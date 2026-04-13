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
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/notification_provider.dart';

/// Dashboard — The main overview screen.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final currency = ref.watch(currencyProvider);
    final totalValue = ref.watch(totalStockValueProvider);
    final matCount = ref.watch(materialCountProvider);
    final txnCount = ref.watch(transactionCountProvider);
    final recentTxns = ref.watch(recentTransactionsProvider);
    final unreadNotifs = ref.watch(unreadNotificationCountProvider);

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: BilingualText(
                      english: AppStrings.dashboard.primary,
                      secondary: AppStrings.dashboard.secondary(lang),
                      englishStyle: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.28,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () => context.push(RoutePaths.notifications),
                        icon: const Icon(Icons.notifications_outlined),
                        style: IconButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                      if (unreadNotifs > 0)
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
                  ),
                ],
              ),
            ),
          ),

          // ─── Hero Metric Card ────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(
              child: LedgerCard(
                color: AppColors.surfaceContainerLowest,
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
                      currency.format(totalValue),
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

          // ─── Quick Stats ─────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: _QuickStatCard(
                      title: AppStrings.materials.primary,
                      secondaryTitle: AppStrings.materials.secondary(lang),
                      value: '$matCount',
                      icon: Icons.category_outlined,
                    ),
                  ),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: _QuickStatCard(
                      title: AppStrings.transactions.primary,
                      secondaryTitle: AppStrings.transactions.secondary(lang),
                      value: '$txnCount',
                      icon: Icons.swap_horiz_rounded,
                    ),
                  ),
                ],
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
                itemBuilder: (context, index) {
                  final txn = recentTxns[index];
                  return _RecentActivityCard(txn: txn);
                },
              ),
            ),

          const SliverGap(AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ─── Quick Stat Card ─────────────────────────────────────────────
class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.title,
    required this.secondaryTitle,
    required this.value,
    required this.icon,
  });

  final String title;
  final String secondaryTitle;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const Gap(AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.md),
          Text(
            value,
            style: AppTypography.headlineLarge.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          const Gap(AppSpacing.xxs),
          Text(secondaryTitle, style: AppTypography.bodySmall),
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
