import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/rent_payment.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/permissions_provider.dart';
import '../../../../shared/providers/rentals_provider.dart';
import '../widgets/record_payment_sheet.dart';

/// Detail of one rental unit — tenant/lease info plus the full payment history.
class RentalUnitDetailScreen extends ConsumerWidget {
  const RentalUnitDetailScreen({super.key, required this.unitId});

  final String unitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final unit = ref.watch(rentalUnitsProvider.notifier).byId(unitId);
    final canWrite = ref.watch(canWriteRentalsProvider);

    if (unit == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(AppStrings.noDataYet.primary)),
      );
    }

    final payments = ref.watch(rentPaymentsProvider);
    final history = payments.where((p) => p.unitId == unitId).toList()
      ..sort((a, b) => b.periodMonth.compareTo(a.periodMonth));
    final now = DateTime.now();

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
        title: Text(unit.unitName, style: AppTypography.titleLarge),
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => RecordPaymentSheet.show(context, unit),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.payments_outlined),
              label: Text(AppStrings.recordPayment.primary),
            )
          : null,
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              // ─── Unit summary ───────────────────────────────
              LedgerCard(
                color: AppColors.surfaceContainerLowest,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            unit.type.label,
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        unit.isOccupied
                            ? StatusChip.success(AppStrings.occupied.primary)
                            : StatusChip.info(AppStrings.vacant.primary),
                      ],
                    ),
                    const Gap(AppSpacing.sm),
                    Text(
                      '${currency.format(unit.monthlyRentAED)} / mo',
                      style: AppTypography.displaySmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const Gap(AppSpacing.md),
                    _InfoRow(
                      icon: Icons.place_outlined,
                      text: unit.location,
                    ),
                    if (unit.tenantName != null) ...[
                      const Gap(AppSpacing.sm),
                      _InfoRow(
                        icon: Icons.person_outline_rounded,
                        text: unit.tenantName!,
                      ),
                    ],
                    if (unit.tenantContact != null) ...[
                      const Gap(AppSpacing.sm),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        text: unit.tenantContact!,
                      ),
                    ],
                    if (unit.leaseStart != null && unit.leaseEnd != null) ...[
                      const Gap(AppSpacing.sm),
                      _InfoRow(
                        icon: Icons.event_outlined,
                        text:
                            '${_fmtDate(unit.leaseStart!)} → ${_fmtDate(unit.leaseEnd!)}',
                      ),
                    ],
                    if (unit.notes != null && unit.notes!.isNotEmpty) ...[
                      const Gap(AppSpacing.sm),
                      _InfoRow(
                        icon: Icons.notes_outlined,
                        text: unit.notes!,
                      ),
                    ],
                  ],
                ),
              ),
              const Gap(AppSpacing.xl),

              Text(
                AppStrings.paymentHistory.primary,
                style: AppTypography.titleMedium,
              ),
              const Gap(AppSpacing.md),

              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: Text(
                    AppStrings.noPaymentsYet.primary,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final p in history) ...[
                  _PaymentRow(payment: p, currency: currency, now: now),
                  const Gap(AppSpacing.listItemGap),
                ],
              const Gap(AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
        const Gap(AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.payment,
    required this.currency,
    required this.now,
  });

  final RentPayment payment;
  final dynamic currency;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final status = payment.statusAsOf(now);
    final chip = switch (status) {
      RentStatus.paid => StatusChip.success(RentStatus.paid.label),
      RentStatus.partial => StatusChip.warning(RentStatus.partial.label),
      RentStatus.due => StatusChip.info(RentStatus.due.label),
      RentStatus.overdue => StatusChip.error(RentStatus.overdue.label),
    };
    return LedgerCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.periodMonth, style: AppTypography.titleSmall),
                const Gap(AppSpacing.xxs),
                Text(
                  '${currency.format(payment.amountPaidAED)} / ${currency.format(payment.amountDueAED)}'
                  '${payment.method != null ? ' · ${payment.method}' : ''}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          chip,
        ],
      ),
    );
  }
}
