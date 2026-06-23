import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/rent_payment.dart';
import '../../../../shared/models/rental_unit.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/rentals_provider.dart';
import '../../../../shared/providers/session_provider.dart';
import '../../../../shared/sync/sync_indicators.dart';

/// Record a rent payment for a unit (procurement / admin).
class RecordPaymentSheet extends ConsumerStatefulWidget {
  const RecordPaymentSheet({super.key, required this.unit});

  final RentalUnit unit;

  static Future<void> show(BuildContext context, RentalUnit unit) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecordPaymentSheet(unit: unit),
    );
  }

  @override
  ConsumerState<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _monthController;
  late final TextEditingController _dueController;
  final _paidController = TextEditingController();
  final _methodController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final month = currentRentMonthKey();
    _monthController = TextEditingController(text: month);

    // Show the OUTSTANDING balance for this period, not the full monthly rent.
    // If a partial payment already exists, "Due" reflects what's still owed
    // (e.g. after paying half of AED 4,500, this shows AED 2,250).
    RentPayment? existing;
    for (final p in ref.read(rentPaymentsProvider)) {
      if (p.unitId == widget.unit.id &&
          p.periodMonth == month &&
          !p.isVoided) {
        existing = p;
        break;
      }
    }
    final outstanding = existing?.outstandingAED ?? widget.unit.monthlyRentAED;
    _dueController = TextEditingController(text: outstanding.toStringAsFixed(0));
    // Default the "paid" field to clearing the balance in one tap (editable).
    _paidController.text = outstanding.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _monthController.dispose();
    _dueController.dispose();
    _paidController.dispose();
    _methodController.dispose();
    super.dispose();
  }

  /// Reject malformed, out-of-range, far-future or far-past billing months —
  /// they pollute history and the overdue calculation.
  String? _monthError(String? v) {
    final t = (v ?? '').trim();
    final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(t);
    if (m == null) return 'YYYY-MM';
    final month = int.parse(m.group(2)!);
    if (month < 1 || month > 12) return '01–12';
    final now = DateTime.now();
    final entered = int.parse(m.group(1)!) * 12 + month;
    final current = now.year * 12 + now.month;
    if (entered > current + 1) return AppStrings.monthNotFuture.primary;
    if (entered < current - 24) return AppStrings.monthTooOld.primary;
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final period = _monthController.text.trim();
    final due = double.parse(_dueController.text.trim());
    final paid = double.parse(_paidController.text.trim());

    // Guard against fat-finger overpayment — the clamp would otherwise hide it.
    if (paid > due) {
      final over = paid - due;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          title: Text(
            AppStrings.overpaymentTitle.primary,
            style: AppTypography.titleMedium,
          ),
          content: Text(
            '${AppStrings.overpaymentBody.primary} AED ${over.toStringAsFixed(0)}.',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.cancel.primary),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.recordAnyway.primary),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _busy = true);
    await ref
        .read(rentPaymentsProvider.notifier)
        .recordPayment(
          unitId: widget.unit.id,
          periodMonth: period,
          amountDueAED: double.parse(_dueController.text.trim()),
          amountPaidAED: paid,
          method: _methodController.text.trim().isEmpty
              ? null
              : _methodController.text.trim(),
          recordedBy: ref.read(actorNameProvider),
        );
    await ref.logAudit(
      action: 'Rent payment recorded',
      module: AuditModule.rentals,
      refId: widget.unit.id,
      detail:
          'AED ${paid.toStringAsFixed(0)} · ${widget.unit.unitName} · $period',
    );
    if (!mounted) return;
    showSyncSnack(context, ref, savedLabel: AppStrings.paymentRecorded.primary);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Gap(AppSpacing.md),
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Gap(AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${AppStrings.recordPayment.primary} — ${widget.unit.unitName}',
                        style: GoogleFonts.inter(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Gap(AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: LedgerTextField(
                              controller: _monthController,
                              label: AppStrings.billingMonth.primary,
                              hintText: 'YYYY-MM',
                              validator: _monthError,
                            ),
                          ),
                          const Gap(AppSpacing.lg),
                          Expanded(
                            child: LedgerTextField(
                              controller: _dueController,
                              label: AppStrings.amountDue.primary,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: _positive,
                            ),
                          ),
                        ],
                      ),
                      const Gap(AppSpacing.lg),
                      LedgerTextField(
                        controller: _paidController,
                        label: '${AppStrings.amountPaid.primary} (AED)',
                        hintText: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _positive,
                      ),
                      const Gap(AppSpacing.lg),
                      LedgerTextField(
                        controller: _methodController,
                        label: AppStrings.paymentMethod.primary,
                        hintText: AppStrings.optional.primary,
                      ),
                      const Gap(AppSpacing.xxl),
                      PrimaryButton(
                        label: AppStrings.recordPayment.primary,
                        icon: Icons.check_rounded,
                        isLoading: _busy,
                        onPressed: _busy ? null : _save,
                      ),
                      const Gap(AppSpacing.xxl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _positive(String? v) {
    if ((v ?? '').trim().isEmpty) return AppStrings.fieldRequired.primary;
    final val = double.tryParse(v!.trim());
    if (val == null || val <= 0) return AppStrings.enterValidNumber.primary;
    return null;
  }
}
