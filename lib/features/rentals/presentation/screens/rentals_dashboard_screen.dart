import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/rent_payment.dart';
import '../../../../shared/models/rental_unit.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/permissions_provider.dart';
import '../../../../shared/providers/rentals_provider.dart';
import '../../../../shared/widgets/notification_bell.dart';
import '../widgets/add_unit_sheet.dart';

/// Rentals module home: portfolio summary + a list of units with their current
/// rent status. Read & write (add unit, record payment) for procurement/admin.
class RentalsDashboardScreen extends ConsumerStatefulWidget {
  const RentalsDashboardScreen({super.key});

  @override
  ConsumerState<RentalsDashboardScreen> createState() =>
      _RentalsDashboardScreenState();
}

class _RentalsDashboardScreenState
    extends ConsumerState<RentalsDashboardScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(RentalUnit u) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return u.unitName.toLowerCase().contains(q) ||
        (u.tenantName ?? '').toLowerCase().contains(q) ||
        u.location.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final currency = ref.watch(currencyProvider);
    final units = ref.watch(rentalUnitsProvider);
    final summary = ref.watch(rentalsSummaryProvider);
    final canWrite = ref.watch(canWriteRentalsProvider);
    final visibleUnits = units.where(_matches).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // tab root — nothing to go back to
        title: BilingualText(
          english: AppStrings.rentalShops.primary,
          secondary: AppStrings.rentalShops.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: const [NotificationBell()],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => AddUnitSheet.show(context),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: Text(AppStrings.addUnit.primary),
            )
          : null,
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              // ─── Summary ────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: AppStrings.rentRoll.primary,
                      value: currency.format(summary.monthlyRentRoll),
                      color: AppColors.primary,
                    ),
                  ),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: _SummaryCard(
                      label: AppStrings.cashReceived.primary,
                      value: currency.format(summary.collectedThisMonth),
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const Gap(AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: AppStrings.overdueTotal.primary,
                      value: currency.format(summary.overdueTotal),
                      color: AppColors.error,
                    ),
                  ),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: _SummaryCard(
                      label:
                          '${AppStrings.occupied.primary} / ${AppStrings.rentalUnits.primary}',
                      value: '${summary.occupied} / ${summary.totalUnits}',
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              Builder(
                builder: (context) {
                  final deposits = ref.watch(totalSecurityDepositsHeldProvider);
                  if (deposits <= 0) return const SizedBox.shrink();
                  return Column(
                    children: [
                      const Gap(AppSpacing.md),
                      _SummaryCard(
                        label: 'Security deposits held',
                        value: currency.format(deposits),
                        color: AppColors.onSurfaceVariant,
                      ),
                    ],
                  );
                },
              ),
              const Gap(AppSpacing.xl),

              Text(
                AppStrings.rentalUnits.primary,
                style: AppTypography.titleMedium,
              ),
              const Gap(AppSpacing.md),

              if (units.isEmpty)
                LedgerCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Column(
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 32,
                          color: AppColors.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const Gap(AppSpacing.sm),
                        Text(
                          AppStrings.noUnitsYet.primary,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  style: AppTypography.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceContainerHighest,
                    hintText: 'Search unit, tenant, location',
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
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const Gap(AppSpacing.md),
                if (visibleUnits.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: Center(
                      child: Text(
                        'No matching units',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  for (final unit in visibleUnits) ...[
                    _UnitCard(unit: unit, currency: currency),
                    const Gap(AppSpacing.listItemGap),
                  ],
              ],
              const Gap(AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Summary card ────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      color: AppColors.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Gap(AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.titleLarge.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Unit card ───────────────────────────────────────────────────
class _UnitCard extends ConsumerWidget {
  const _UnitCard({required this.unit, required this.currency});

  final RentalUnit unit;
  final dynamic currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(unitRentStatusProvider(unit.id));
    return LedgerCard(
      onTap: () => context.push(RoutePaths.rentalUnitPath(unit.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  unit.type == RentalType.workshop
                      ? Icons.handyman_outlined
                      : Icons.storefront_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(unit.unitName, style: AppTypography.titleSmall),
                    const Gap(AppSpacing.xxs),
                    Text(
                      unit.isOccupied
                          ? (unit.tenantName ?? AppStrings.occupied.primary)
                          : AppStrings.vacant.primary,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _rentStatusChip(unit, status),
            ],
          ),
          const Gap(AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                unit.location,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${currency.format(unit.monthlyRentAED)} / mo',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _rentStatusChip(RentalUnit unit, RentStatus status) {
  if (!unit.isOccupied) return StatusChip.info(AppStrings.vacant.primary);
  return switch (status) {
    RentStatus.paid => StatusChip.success(RentStatus.paid.label),
    RentStatus.partial => StatusChip.warning(RentStatus.partial.label),
    RentStatus.due => StatusChip.info(RentStatus.due.label),
    RentStatus.overdue => StatusChip.error(RentStatus.overdue.label),
  };
}
