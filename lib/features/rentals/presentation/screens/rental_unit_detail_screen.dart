import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/rent_payment.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/permissions_provider.dart';
import '../../../../shared/providers/rentals_provider.dart';
import '../widgets/add_unit_sheet.dart';
import '../widgets/record_payment_sheet.dart';

/// Detail of one rental unit — tenant/lease info, this-month status, and the
/// full payment history (with void/correction).
class RentalUnitDetailScreen extends ConsumerWidget {
  const RentalUnitDetailScreen({super.key, required this.unitId});

  final String unitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    // Reactive: rebuild when the unit is edited elsewhere.
    final unit = ref
        .watch(rentalUnitsProvider)
        .where((u) => u.id == unitId)
        .firstOrNull;
    final canWrite = ref.watch(canWriteRentalsProvider);

    if (unit == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.store_mall_directory_outlined,
                size: 48,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const Gap(AppSpacing.md),
              Text(
                AppStrings.noDataYet.primary,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const Gap(AppSpacing.lg),
              SecondaryButton(
                label: AppStrings.goBack.primary,
                icon: Icons.arrow_back_rounded,
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(RoutePaths.rentals),
              ),
            ],
          ),
        ),
      );
    }

    final payments = ref.watch(rentPaymentsProvider);
    final history = payments.where((p) => p.unitId == unitId).toList()
      ..sort((a, b) => b.periodMonth.compareTo(a.periodMonth));
    final now = DateTime.now();
    final thisMonth = currentRentMonthKey();
    final thisMonthPayment = history
        .where((p) => p.periodMonth == thisMonth && !p.isVoided)
        .firstOrNull;

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
        actions: [
          if (canWrite)
            IconButton(
              tooltip: AppStrings.editUnit.primary,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => AddUnitSheet.show(context, unit: unit),
            ),
        ],
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
                        if (unit.leaseExpired) ...[
                          StatusChip.warning(AppStrings.leaseExpired.primary),
                          const Gap(AppSpacing.xs),
                        ],
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
                    _InfoRow(icon: Icons.place_outlined, text: unit.location),
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
                      _InfoRow(icon: Icons.notes_outlined, text: unit.notes!),
                    ],
                  ],
                ),
              ),

              // ─── This month ─────────────────────────────────
              if (unit.isOccupied) ...[
                const Gap(AppSpacing.md),
                _ThisMonthCard(
                  payment: thisMonthPayment,
                  monthlyRent: unit.monthlyRentAED,
                  currency: currency,
                  now: now,
                ),
              ],
              const Gap(AppSpacing.xl),

              Text(
                AppStrings.paymentHistory.primary,
                style: AppTypography.titleMedium,
              ),
              const Gap(AppSpacing.md),

              if (history.isEmpty)
                LedgerCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Center(
                      child: Text(
                        AppStrings.noPaymentsYet.primary,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                )
              else
                for (final p in history) ...[
                  _PaymentRow(
                    payment: p,
                    currency: currency,
                    now: now,
                    onVoid: (canWrite && !p.isVoided)
                        ? () => _void(context, ref, p, unit.unitName)
                        : null,
                  ),
                  const Gap(AppSpacing.listItemGap),
                ],
              const Gap(AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _void(
    BuildContext context,
    WidgetRef ref,
    RentPayment payment,
    String unitName,
  ) async {
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        title: Text(
          AppStrings.voidPaymentAction.primary,
          style: AppTypography.titleMedium,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${payment.periodMonth} · $unitName',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const Gap(AppSpacing.md),
            TextField(
              controller: reasonController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: AppStrings.voidReasonLabel.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel.primary),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppStrings.voidPaymentAction.primary,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (ok != true) return;
    await ref
        .read(rentPaymentsProvider.notifier)
        .voidPayment(payment.id, reason: reason);
    await ref.logAudit(
      action: 'Rent payment voided',
      module: AuditModule.rentals,
      refId: payment.unitId,
      detail:
          '$unitName · ${payment.periodMonth}${reason.isEmpty ? '' : ' · $reason'}',
    );
  }

  String _fmtDate(DateTime d) => DateFormat('d MMM yyyy').format(d);
}

// ─── This-month status card ──────────────────────────────────────
class _ThisMonthCard extends StatelessWidget {
  const _ThisMonthCard({
    required this.payment,
    required this.monthlyRent,
    required this.currency,
    required this.now,
  });

  final RentPayment? payment;
  final double monthlyRent;
  final dynamic currency;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final status = payment?.statusAsOf(now) ?? RentStatus.due;
    final chip = switch (status) {
      RentStatus.paid => StatusChip.success(RentStatus.paid.label),
      RentStatus.partial => StatusChip.warning(RentStatus.partial.label),
      RentStatus.due => StatusChip.info(RentStatus.due.label),
      RentStatus.overdue => StatusChip.error(RentStatus.overdue.label),
    };
    final outstanding = payment?.outstandingAED ?? monthlyRent;
    return LedgerCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.thisMonth.primary,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  outstanding > 0
                      ? '${currency.format(outstanding)} ${RentStatus.due.label.toLowerCase()}'
                      : RentStatus.paid.label,
                  style: AppTypography.titleSmall,
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
    this.onVoid,
  });

  final RentPayment payment;
  final dynamic currency;
  final DateTime now;
  final VoidCallback? onVoid;

  @override
  Widget build(BuildContext context) {
    final voided = payment.isVoided;
    final status = payment.statusAsOf(now);
    final chip = voided
        ? StatusChip.error(AppStrings.voided.primary)
        : switch (status) {
            RentStatus.paid => StatusChip.success(RentStatus.paid.label),
            RentStatus.partial => StatusChip.warning(RentStatus.partial.label),
            RentStatus.due => StatusChip.info(RentStatus.due.label),
            RentStatus.overdue => StatusChip.error(RentStatus.overdue.label),
          };
    final strike = voided ? TextDecoration.lineThrough : null;
    return LedgerCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.periodMonth,
                  style: AppTypography.titleSmall.copyWith(decoration: strike),
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  '${currency.format(payment.amountPaidAED)} / ${currency.format(payment.amountDueAED)}'
                  '${payment.method != null ? ' · ${payment.method}' : ''}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                    decoration: strike,
                  ),
                ),
                if (voided && payment.voidReason.isNotEmpty) ...[
                  const Gap(AppSpacing.xxs),
                  Text(
                    payment.voidReason,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Gap(AppSpacing.sm),
          chip,
          if (onVoid != null)
            IconButton(
              tooltip: AppStrings.voidPaymentAction.primary,
              icon: const Icon(Icons.more_vert_rounded, size: 18),
              onPressed: () async {
                final action = await showMenu<String>(
                  context: context,
                  position: _menuPosition(context),
                  items: [
                    PopupMenuItem(
                      value: 'void',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.block_rounded,
                            size: 18,
                            color: AppColors.error,
                          ),
                          const Gap(AppSpacing.sm),
                          Text(AppStrings.voidPaymentAction.primary),
                        ],
                      ),
                    ),
                  ],
                );
                if (action == 'void') onVoid!();
              },
            ),
        ],
      ),
    );
  }

  RelativeRect _menuPosition(BuildContext context) {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = context.findRenderObject() as RenderBox;
    final topRight = box.localToGlobal(
      box.size.topRight(Offset.zero),
      ancestor: overlay,
    );
    return RelativeRect.fromLTRB(
      topRight.dx,
      topRight.dy,
      overlay.size.width - topRight.dx,
      0,
    );
  }
}
