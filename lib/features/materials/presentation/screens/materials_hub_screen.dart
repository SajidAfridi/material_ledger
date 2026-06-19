import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_plan_provider.dart';
import '../../../../shared/providers/material_request_provider.dart';
import '../../../../shared/providers/session_provider.dart';

/// Materials tab hub (IA restructure). A landing page that routes to the
/// existing materials screens — Inventory, Procurement, Requests, Goods receipt,
/// Returns, Transactions, Project costs — filtered by [UserRole]. It owns no
/// business logic; every card opens a screen that already exists.
class MaterialsHubScreen extends ConsumerWidget {
  const MaterialsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final role = ref.watch(currentRoleProvider);
    final currency = ref.watch(currencyProvider);
    final stockValue = ref.watch(totalStockValueProvider);
    final matCount = ref.watch(materialCountProvider);
    final openRequests = ref.watch(openRequestCountProvider);
    // Plans to review + requests to dispatch — badged on the Procurement card.
    final int procurementQueue =
        ref.watch(dispatchQueueCountProvider) +
        ref.watch(planReviewQueueCountProvider);

    final cards = <Widget>[
      // Office stock control.
      if (role.usesAdminPanel)
        _NavCard(
          icon: Icons.inventory_2_outlined,
          title: AppStrings.inventory.primary,
          subtitle: AppStrings.inventoryHint.primary,
          onTap: () => context.push(RoutePaths.inventory),
        ),
      // Engineer materials catalogue.
      if (!role.usesAdminPanel)
        _NavCard(
          icon: Icons.search_rounded,
          title: AppStrings.browse.primary,
          subtitle: AppStrings.browse.secondary(lang),
          onTap: () => context.push(RoutePaths.engineerBrowse),
        ),
      if (role.usesAdminPanel)
        _NavCard(
          icon: Icons.assignment_turned_in_outlined,
          title: AppStrings.procurement.primary,
          subtitle: AppStrings.procurementHint.primary,
          badge: procurementQueue,
          onTap: () => context.push(RoutePaths.procurement),
        ),
      _NavCard(
        icon: Icons.assignment_outlined,
        title: AppStrings.requests.primary,
        subtitle: AppStrings.requests.secondary(lang),
        onTap: () => context.push(
          role.isAdmin ? RoutePaths.adminRequests : RoutePaths.requests,
        ),
      ),
      // New request — engineers raise these from site.
      if (!role.usesAdminPanel)
        _NavCard(
          icon: Icons.add_circle_outline_rounded,
          title: AppStrings.newRequest.primary,
          subtitle: AppStrings.newRequest.secondary(lang),
          onTap: () => context.push(RoutePaths.engineerNewRequest),
        ),
      // Goods receipt (stock in) — procurement / admin.
      if (role.canReceiveGoods)
        _NavCard(
          icon: Icons.move_to_inbox_outlined,
          title: AppStrings.goodsReceipt.primary,
          subtitle: AppStrings.goodsReceipt.secondary(lang),
          onTap: () => context.push(RoutePaths.goodsReceipt),
        ),
      _NavCard(
        icon: Icons.assignment_return_outlined,
        title: AppStrings.returnsAndReceipts.primary,
        subtitle: AppStrings.returnsAndReceiptsHint.primary,
        onTap: () => context.push(RoutePaths.returnStore),
      ),
      if (role.usesAdminPanel)
        _NavCard(
          icon: Icons.swap_horiz_rounded,
          title: AppStrings.transactions.primary,
          subtitle: AppStrings.transactions.secondary(lang),
          onTap: () => context.push(RoutePaths.transactions),
        ),
      if (role.canViewFinance)
        _NavCard(
          icon: Icons.bar_chart_rounded,
          title: AppStrings.projectCosts.primary,
          subtitle: AppStrings.costReportHint.primary,
          onTap: () => context.push(RoutePaths.finance),
        ),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.screenVertical,
          AppSpacing.screenHorizontal,
          AppSpacing.xxl,
        ),
        children: [
          BilingualText(
            english: AppStrings.materials.primary,
            secondary: AppStrings.materialsSubtitle.primary,
            englishStyle: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.28,
              color: AppColors.onSurface,
            ),
            secondaryStyle: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const Gap(AppSpacing.lg),

          // ─── Quick summary (deep-link KPIs live on Home) ──────────
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: AppStrings.totalStockValue.primary,
                  value: role.canSeeCost ? currency.format(stockValue) : '— — —',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: _MiniStat(
                  label: AppStrings.openRequests.primary,
                  value: '$openRequests',
                  icon: Icons.assignment_outlined,
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: _MiniStat(
                  label: AppStrings.materials.primary,
                  value: '$matCount',
                  icon: Icons.category_outlined,
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.xl),

          for (final card in cards) ...[card, const Gap(AppSpacing.listItemGap)],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      color: AppColors.surfaceContainerLowest,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const Gap(AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              softWrap: false,
            ),
          ),
          const Gap(AppSpacing.xxs),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// When > 0, a count pill (e.g. items awaiting action) renders before the
  /// chevron — used to surface the Procurement work queue at a glance.
  final int badge;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, size: 22, color: AppColors.primary),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleSmall),
                const Gap(AppSpacing.xxs),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (badge > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                '$badge',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Gap(AppSpacing.sm),
          ],
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
