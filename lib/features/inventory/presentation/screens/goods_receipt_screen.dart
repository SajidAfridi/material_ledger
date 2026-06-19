import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/material_item.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/goods_receipt_provider.dart';
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/session_provider.dart';
import '../../../../shared/sync/sync_indicators.dart';
import '../../../engineer/presentation/widgets/inventory_picker_sheet.dart';

/// Procurement records goods physically arriving into the store (a GRN).
/// Receiving increments on-hand stock and rolls the unit cost into a weighted
/// average (FR-090). Procurement / Admin only.
class GoodsReceiptScreen extends ConsumerStatefulWidget {
  const GoodsReceiptScreen({super.key});

  @override
  ConsumerState<GoodsReceiptScreen> createState() => _GoodsReceiptScreenState();
}

class _GoodsReceiptScreenState extends ConsumerState<GoodsReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _costController = TextEditingController();
  final _supplierController = TextEditingController();
  final _noteController = TextEditingController();
  MaterialItem? _selected;
  bool _busy = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    _supplierController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickMaterial() async {
    final materials = ref.read(materialsProvider);
    final picked = await InventoryPickerSheet.show(context, materials);
    if (picked != null) setState(() => _selected = picked);
  }

  Future<void> _submit() async {
    if (_selected == null) {
      _toast(AppStrings.grnSelectMaterial.primary);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    final qty = double.parse(_qtyController.text.trim());
    final cost = double.parse(_costController.text.trim());
    final supplier = _supplierController.text.trim();

    final grn = await ref
        .read(goodsReceiptsProvider.notifier)
        .recordReceipt(
          materialId: _selected!.id,
          materialName: _selected!.name,
          quantity: qty,
          unitSymbol: _selected!.unit.symbol,
          unitCostAED: cost,
          supplier: supplier,
          receivedBy: ref.read(actorNameProvider),
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
    await ref.logAudit(
      action: 'Goods received into store',
      module: AuditModule.materials,
      refId: grn.id,
      detail:
          '${_selected!.name} ×${_fmt(qty)} @ ${cost.toStringAsFixed(2)} · $supplier',
    );

    if (!mounted) return;
    showSyncSnack(context, ref, savedLabel: AppStrings.grnRecorded.primary);
    context.pop();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmt(double v) =>
      v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final currency = ref.watch(currencyProvider);
    final sel = _selected;

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
          english: AppStrings.receiveGoods.primary,
          secondary: AppStrings.receiveGoods.secondary(lang),
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
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              children: [
                // ─── Material selector ──────────────────────────
                LedgerCard(
                  onTap: _pickMaterial,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                        child: Icon(
                          sel == null
                              ? Icons.add_box_outlined
                              : CategoryIcons.icon(sel.category),
                          color: AppColors.primary,
                        ),
                      ),
                      const Gap(AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sel?.name ?? AppStrings.grnSelectMaterial.primary,
                              style: AppTypography.titleSmall,
                            ),
                            const Gap(AppSpacing.xxs),
                            Text(
                              sel == null
                                  ? AppStrings.grnTapToChoose.primary
                                  : '${AppStrings.onHand.primary}: ${sel.formattedQuantity}',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
                const Gap(AppSpacing.lg),

                // ─── Quantity + Unit cost ───────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LedgerTextField(
                        controller: _qtyController,
                        label: AppStrings.quantity.primary,
                        hintText: '0',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _positiveNumber,
                      ),
                    ),
                    const Gap(AppSpacing.lg),
                    Expanded(
                      child: LedgerTextField(
                        controller: _costController,
                        label: '${AppStrings.unitPrice.primary} (AED)',
                        hintText: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _positiveNumber,
                      ),
                    ),
                  ],
                ),
                const Gap(AppSpacing.lg),

                // ─── Supplier ───────────────────────────────────
                LedgerTextField(
                  controller: _supplierController,
                  label: AppStrings.supplier.primary,
                  urduHint: AppStrings.supplier.secondary(lang),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? AppStrings.fieldRequired.primary
                      : null,
                ),
                const Gap(AppSpacing.lg),

                // ─── Note ───────────────────────────────────────
                LedgerTextField(
                  controller: _noteController,
                  label: AppStrings.notes.primary,
                  hintText: AppStrings.optional.primary,
                ),

                // ─── Cost preview ───────────────────────────────
                if (sel != null) ...[
                  const Gap(AppSpacing.lg),
                  _CostPreview(
                    qtyController: _qtyController,
                    costController: _costController,
                    currency: currency,
                  ),
                ],
                const Gap(AppSpacing.xxl),

                PrimaryButton(
                  label: AppStrings.grnRecord.primary,
                  icon: Icons.check_rounded,
                  isLoading: _busy,
                  onPressed: _busy ? null : _submit,
                ),
                const Gap(AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _positiveNumber(String? v) {
    if ((v ?? '').trim().isEmpty) return AppStrings.fieldRequired.primary;
    final val = double.tryParse(v!.trim());
    if (val == null || val <= 0) return AppStrings.enterValidNumber.primary;
    return null;
  }
}

// ─── Live line-value preview ─────────────────────────────────────
class _CostPreview extends StatelessWidget {
  const _CostPreview({
    required this.qtyController,
    required this.costController,
    required this.currency,
  });

  final TextEditingController qtyController;
  final TextEditingController costController;
  final dynamic currency;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([qtyController, costController]),
      builder: (context, _) {
        final qty = double.tryParse(qtyController.text.trim()) ?? 0;
        final cost = double.tryParse(costController.text.trim()) ?? 0;
        final value = qty * cost;
        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.totalValue.primary,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Text(
                currency.format(value),
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
