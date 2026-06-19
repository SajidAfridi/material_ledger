import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/material_request.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_request_provider.dart';
import '../../../../shared/sync/sync_indicators.dart';

/// Phase 2 — Engineer confirms exactly what physically arrived on site,
/// recording received quantity per line and flagging shortfall (FR-088/089).
class ConfirmReceiptScreen extends ConsumerStatefulWidget {
  const ConfirmReceiptScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<ConfirmReceiptScreen> createState() =>
      _ConfirmReceiptScreenState();
}

class _ConfirmReceiptScreenState extends ConsumerState<ConfirmReceiptScreen> {
  List<double>? _received;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final requests = ref.watch(materialRequestsProvider);
    MaterialRequest? request;
    for (final r in requests) {
      if (r.id == widget.requestId) {
        request = r;
        break;
      }
    }

    if (request == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(child: Text(AppStrings.noDataYet.primary)),
      );
    }

    final items = request.lineItems;
    _received ??= [for (final i in items) i.qtyReceived ?? i.quantity];
    final received = _received!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: BilingualText(
          english: AppStrings.confirmReceipt.primary,
          secondary: AppStrings.confirmReceipt.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      body: ResponsiveCenter(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.lg,
                    AppSpacing.screenHorizontal,
                    AppSpacing.xxl,
                  ),
                  children: [
                    Text(
                      request.projectName,
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    Text(
                      AppStrings.confirmReceiptSubtitle.primary,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const Gap(AppSpacing.xl),
                    for (var i = 0; i < items.length; i++) ...[
                      _ReceiptItemCard(
                        item: items[i],
                        received: received[i],
                        lang: lang,
                        onInc: () =>
                            setState(() => received[i] = received[i] + 1),
                        onDec: () => setState(
                          () => received[i] = (received[i] - 1).clamp(
                            0,
                            items[i].quantity,
                          ),
                        ),
                        onAllArrived: () =>
                            setState(() => received[i] = items[i].quantity),
                      ),
                      const Gap(AppSpacing.listItemGap),
                    ],
                  ],
                ),
              ),
              Container(
                color: AppColors.surfaceContainerLowest,
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.md,
                  AppSpacing.screenHorizontal,
                  AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
                ),
                child: PrimaryButton(
                  label: AppStrings.confirmReceipt.primary,
                  icon: Icons.check_rounded,
                  isLoading: _busy,
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          await ref
                              .read(materialRequestsProvider.notifier)
                              .confirmReceipt(widget.requestId, received);
                          await ref.logAudit(
                            action: 'Site receipt confirmed',
                            module: AuditModule.materials,
                            refId: widget.requestId,
                            detail: '${received.length} line(s) received',
                          );
                          if (!context.mounted) return;
                          showSyncSnack(
                            context,
                            ref,
                            savedLabel: AppStrings.receiptConfirmed.primary,
                          );
                          context.pop();
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptItemCard extends StatelessWidget {
  const _ReceiptItemCard({
    required this.item,
    required this.received,
    required this.lang,
    required this.onInc,
    required this.onDec,
    required this.onAllArrived,
  });

  final RequestLineItem item;
  final double received;
  final dynamic lang;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onAllArrived;

  String _fmt(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final short = received < item.quantity;
    final full = received >= item.quantity;

    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.materialName,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.materialNameSecondary.isNotEmpty) ...[
                      const Gap(2),
                      Text(
                        item.materialNameSecondary,
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        textDirection: lang.isRtl
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                      ),
                    ],
                    const Gap(AppSpacing.xs),
                    Text(
                      '${AppStrings.dispatchedLabel.primary} ${_fmt(item.quantity)} ${item.unitSymbol}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                full ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                color: full ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
          const Gap(AppSpacing.md),
          Row(
            children: [
              Text(
                '${AppStrings.receivedLabel.primary}: ',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              _Stepper(
                value: received,
                unit: item.unitSymbol,
                onInc: onInc,
                onDec: onDec,
              ),
            ],
          ),
          if (short) ...[
            const Gap(AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.shortfallFlagged.primary,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onAllArrived,
                  child: Text(AppStrings.receivedLabel.primary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.unit,
    required this.onInc,
    required this.onDec,
  });

  final double value;
  final String unit;
  final VoidCallback onInc;
  final VoidCallback onDec;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Btn(icon: Icons.remove_rounded, onTap: onDec),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} $unit',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _Btn(icon: Icons.add_rounded, onTap: onInc),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
      ),
    );
  }
}
