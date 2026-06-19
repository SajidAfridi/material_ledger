import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/feedback/feedback_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_notification.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/material_item.dart';
import '../../../../shared/models/material_request.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/goods_receipt_provider.dart';
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_request_provider.dart';
import '../../../../shared/providers/notification_provider.dart';
import '../../../../shared/providers/session_provider.dart';
import '../../../../shared/sync/sync_indicators.dart';

/// Procurement dispatches a Phase-2 request — full or partial per line, or puts
/// it on hold. Only items that are actually in stock can be dispatched (stock is
/// decremented + the reservation freed); custom / not-yet-stocked items must be
/// received into inventory first, right from this screen.
class ProcurementDispatchScreen extends ConsumerStatefulWidget {
  const ProcurementDispatchScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<ProcurementDispatchScreen> createState() =>
      _ProcurementDispatchScreenState();
}

class _ProcurementDispatchScreenState
    extends ConsumerState<ProcurementDispatchScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(RequestLineItem line, double max) {
    return _controllers.putIfAbsent(
      line.materialId,
      () => TextEditingController(text: _fmt(max)),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

  /// On-hand stock dispatchable for a line (capped at what's still outstanding).
  double _dispatchableMax(MaterialItem? item, RequestLineItem line) {
    if (item == null) return 0;
    return line.qtyOutstanding.clamp(0, item.quantity).toDouble();
  }

  Future<void> _dispatch(MaterialRequest req, List<MaterialItem?> items) async {
    final qtys = <double>[];
    for (var i = 0; i < req.lineItems.length; i++) {
      final line = req.lineItems[i];
      final item = items[i];
      if (item == null) {
        qtys.add(0); // not stocked → can't dispatch
        continue;
      }
      final max = _dispatchableMax(item, line);
      final entered = double.tryParse(_controllerFor(line, max).text.trim()) ?? 0;
      qtys.add(entered.clamp(0, max).toDouble());
    }
    final count = qtys.where((q) => q > 0).length;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.enterDispatchQty.primary)),
      );
      return;
    }

    final ok = await _confirm(
      title: AppStrings.confirmDispatchTitle.primary,
      message:
          '${AppStrings.dispatch.primary} $count ${AppStrings.lineItems.primary.toLowerCase()} · ${req.projectName}',
      confirmLabel: AppStrings.dispatch.primary,
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    AppFeedback.confirm();
    await ref.read(materialRequestsProvider.notifier).dispatch(req.id, qtys);
    await ref.read(notificationsProvider.notifier).add(
          type: NotificationType.request,
          title: 'Request dispatched to site',
          titleSecondary: 'درخواست سائٹ پر روانہ کر دی گئی',
          body: '${req.projectName} · $count line(s).',
          refId: req.id,
          route: RoutePaths.requestDetailPath(req.id),
          audience: UserRole.engineer.name,
        );
    await ref.logAudit(
      action: 'Request dispatched',
      module: AuditModule.materials,
      refId: req.id,
      detail: '${req.projectName} · $count line(s)',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    showSyncSnack(context, ref, savedLabel: AppStrings.requestDispatched.primary);
    context.pop();
  }

  /// Receive a custom / not-yet-stocked line into inventory: create the material,
  /// stock it via a goods receipt, then re-link the request line to it so it
  /// becomes dispatchable.
  Future<void> _receiveIntoInventory(
    MaterialRequest req,
    RequestLineItem line,
  ) async {
    final qtyController = TextEditingController(text: _fmt(line.qtyOutstanding));
    final costController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        title: Text(
          AppStrings.receiveIntoInventory.primary,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line.materialName, style: AppTypography.titleSmall),
            const Gap(AppSpacing.lg),
            LedgerTextField(
              controller: qtyController,
              label: '${AppStrings.quantityToStock.primary} (${line.unitSymbol})',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const Gap(AppSpacing.md),
            LedgerTextField(
              controller: costController,
              label: '${AppStrings.unitCost.primary} (AED)',
              hintText: AppStrings.optional.primary,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            child: Text(AppStrings.receiveIntoInventory.primary),
          ),
        ],
      ),
    );
    final qty = double.tryParse(qtyController.text.trim()) ?? 0;
    final cost = double.tryParse(costController.text.trim()) ?? 0;
    qtyController.dispose();
    costController.dispose();
    if (result != true || qty <= 0 || !mounted) return;

    // 1) Create the material, 2) stock it via a goods receipt, 3) re-link.
    final newId = await ref.read(materialsProvider.notifier).addMaterial(
          name: line.materialName,
          urduName: line.materialNameSecondary,
          category: MaterialCategory.other,
          unit: MaterialUnit.fromSymbol(line.unitSymbol),
          quantity: 0,
          unitPrice: cost,
        );
    await ref.read(goodsReceiptsProvider.notifier).recordReceipt(
          materialId: newId,
          materialName: line.materialName,
          quantity: qty,
          unitSymbol: line.unitSymbol,
          unitCostAED: cost,
          supplier: AppStrings.customItem.primary,
          receivedBy: ref.read(actorNameProvider),
        );
    await ref.read(materialRequestsProvider.notifier).relinkLine(
          req.id,
          line.materialId,
          newMaterialId: newId,
          newName: line.materialName,
        );
    await ref.logAudit(
      action: 'Custom item received into inventory',
      module: AuditModule.materials,
      refId: req.id,
      detail: '${line.materialName} ×${_fmt(qty)} ${line.unitSymbol}',
    );
    if (!mounted) return;
    AppFeedback.confirm();
    showSyncSnack(context, ref, savedLabel: AppStrings.grnRecorded.primary);
  }

  Future<void> _onHold(MaterialRequest req) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        title: Text(AppStrings.putOnHold.primary, style: AppTypography.titleMedium),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: AppStrings.holdNote.primary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.cancel.primary),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(AppStrings.putOnHold.primary),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;
    await ref.read(materialRequestsProvider.notifier).putOnHold(req.id, note);
    await ref.logAudit(
      action: 'Request put on hold',
      module: AuditModule.materials,
      refId: req.id,
      detail: '${req.projectName}${note.isEmpty ? '' : ' · $note'}',
    );
    if (!mounted) return;
    context.pop();
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        content: Text(message, style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel.primary),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final req = ref
        .watch(materialRequestsProvider)
        .where((r) => r.id == widget.requestId)
        .firstOrNull;
    final materials = ref.watch(materialsProvider);

    if (req == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(AppStrings.noDataYet.primary)),
      );
    }

    MaterialItem? itemFor(String id) {
      for (final m in materials) {
        if (m.id == id) return m;
      }
      return null;
    }

    final items = [for (final l in req.lineItems) itemFor(l.materialId)];
    var readyCount = 0;
    var needStockCount = 0;
    for (var i = 0; i < req.lineItems.length; i++) {
      final line = req.lineItems[i];
      if (line.qtyOutstanding <= 0) continue;
      if (items[i] == null) {
        needStockCount++;
      } else if (_dispatchableMax(items[i], line) > 0) {
        readyCount++;
      }
    }
    final anyDispatchable = readyCount > 0;

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
          english: AppStrings.dispatchRequest.primary,
          secondary: AppStrings.dispatchRequest.secondary(lang),
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
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  children: [
                    // ─── Summary card ───────────────────────────
                    _SummaryCard(
                      req: req,
                      readyCount: readyCount,
                      needStockCount: needStockCount,
                    ),
                    const Gap(AppSpacing.xl),
                    for (var i = 0; i < req.lineItems.length; i++) ...[
                      _DispatchLine(
                        line: req.lineItems[i],
                        item: items[i],
                        controller: items[i] == null
                            ? null
                            : _controllerFor(
                                req.lineItems[i],
                                _dispatchableMax(items[i], req.lineItems[i]),
                              ),
                        onReceive: () =>
                            _receiveIntoInventory(req, req.lineItems[i]),
                      ),
                      const Gap(AppSpacing.listItemGap),
                    ],
                    const Gap(AppSpacing.xxl),
                  ],
                ),
              ),
              // ─── Action bar ─────────────────────────────────
              Container(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.md,
                  AppSpacing.screenHorizontal,
                  AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
                ),
                color: AppColors.surfaceContainerLowest,
                child: Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: AppStrings.putOnHold.primary,
                        icon: Icons.pause_circle_outline_rounded,
                        onPressed: _busy ? null : () => _onHold(req),
                      ),
                    ),
                    const Gap(AppSpacing.md),
                    Expanded(
                      child: PrimaryButton(
                        label: AppStrings.dispatch.primary,
                        icon: Icons.local_shipping_outlined,
                        isLoading: _busy,
                        onPressed: (_busy || !anyDispatchable)
                            ? null
                            : () => _dispatch(req, items),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Summary card ─────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.req,
    required this.readyCount,
    required this.needStockCount,
  });

  final MaterialRequest req;
  final int readyCount;
  final int needStockCount;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      color: AppColors.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(req.projectName, style: AppTypography.titleMedium),
              ),
              if (req.priority == RequestPriority.urgent)
                StatusChip.error(AppStrings.urgent.primary),
            ],
          ),
          const Gap(AppSpacing.sm),
          Text(
            req.id.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const Gap(AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusChip.success(
                '$readyCount ${AppStrings.readyToDispatch.primary}',
              ),
              if (needStockCount > 0)
                StatusChip.warning(
                  '$needStockCount ${AppStrings.needsStocking.primary}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Dispatch line ────────────────────────────────────────────────
class _DispatchLine extends StatelessWidget {
  const _DispatchLine({
    required this.line,
    required this.item,
    required this.controller,
    required this.onReceive,
  });

  final RequestLineItem line;
  final MaterialItem? item;
  final TextEditingController? controller;
  final VoidCallback onReceive;

  String _fmt(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final stocked = item != null;
    final onHand = item?.quantity ?? 0;
    final outstanding = line.qtyOutstanding;

    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(line.materialName, style: AppTypography.titleSmall),
              ),
              const Gap(AppSpacing.sm),
              if (!stocked)
                StatusChip.error(AppStrings.notInInventory.primary)
              else if (onHand <= 0)
                StatusChip.error(AppStrings.outOfStock.primary)
              else if (onHand < outstanding)
                StatusChip.warning(AppStrings.lowStock.primary)
              else
                StatusChip.success(AppStrings.inStock.primary),
            ],
          ),
          const Gap(AppSpacing.xxs),
          Text(
            '${AppStrings.requested.primary}: ${_fmt(line.quantity)} ${line.unitSymbol}'
            '${(line.qtyDispatched ?? 0) > 0 ? ' · ${AppStrings.dispatched.primary}: ${_fmt(line.qtyDispatched!)}' : ''}',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          if (line.spec.isNotEmpty) ...[
            const Gap(AppSpacing.xxs),
            Text(
              line.spec,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
          const Gap(AppSpacing.md),
          if (!stocked)
            // Custom / un-stocked: must be received into inventory first.
            SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                label: AppStrings.receiveIntoInventory.primary,
                icon: Icons.move_to_inbox_outlined,
                onPressed: onReceive,
              ),
            )
          else
            Row(
              children: [
                Text(
                  '${AppStrings.dispatch.primary}:',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const Gap(AppSpacing.sm),
                SizedBox(
                  width: 88,
                  child: TextField(
                    controller: controller,
                    enabled: onHand > 0,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surfaceContainerHigh,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                        horizontal: AppSpacing.sm,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const Gap(AppSpacing.sm),
                Text(line.unitSymbol, style: AppTypography.bodyMedium),
                const Spacer(),
                Text(
                  '${AppStrings.available.primary}: ${_fmt(onHand)}',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
