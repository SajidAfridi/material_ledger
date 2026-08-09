import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/yorks_v1_document.dart';
import '../../../../shared/models/yorks_v1_document_strings.dart';
import '../../../../shared/models/yorks_v1_logistics.dart';
import '../../../../shared/models/yorks_v1_logistics_strings.dart';
import '../../../../shared/models/yorks_v1_quantity.dart';
import '../../../../shared/models/yorks_v1_shell_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_boq_workbook_provider.dart';
import '../../../../shared/providers/yorks_v1_documents_repository_provider.dart';
import '../../../../shared/providers/yorks_v1_feature_flags_provider.dart';
import '../../../../shared/providers/yorks_v1_logistics_provider.dart';
import '../../../../shared/providers/yorks_v1_logistics_repository_provider.dart';
import '../../../../shared/providers/yorks_v1_material_request_provider.dart';
import '../../../../shared/services/yorks_v1_logistics_document_service.dart';

/// Batch 8's request-level Delivery Order and Material Return workspace.
/// Server-provided capabilities control every committed action; the client only
/// collects operational inputs and renders immutable snapshots.
class YorksV1ReturnsDocumentsScreen extends ConsumerWidget {
  const YorksV1ReturnsDocumentsScreen({
    super.key,
    required this.requestId,
    this.focusDeliveryOrder = false,
    this.focusedDispatchId,
  });

  final String requestId;

  /// Opens the Delivery Order action directly after a committed dispatch so
  /// the request stays on the controlled document workflow.
  final bool focusDeliveryOrder;
  final String? focusedDispatchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final workspace = ref.watch(
      yorksV1ReturnsDocumentsWorkspaceProvider(requestId),
    );
    final mobile = YorksMobileUi.isActive(context);
    final compactRoute =
        !mobile &&
        MediaQuery.sizeOf(context).width < AppSpacing.yorksV1DesktopBreakpoint;
    final content = workspace.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: SecondaryButton(
          label: YorksV1LogisticsStrings.savingFailed.primary,
          icon: Icons.refresh_rounded,
          onPressed: () => _refresh(ref),
        ),
      ),
      data: (value) => _ReturnsDocumentsBody(
        workspace: value,
        onChanged: () => _refresh(ref),
        showPageHeader: !compactRoute && !mobile,
        focusDeliveryOrder: focusDeliveryOrder,
        focusedDispatchId: focusedDispatchId,
      ),
    );
    if (mobile) {
      return Scaffold(
        backgroundColor: AppColors.mobileSurface,
        body: Column(
          children: [
            YorksMobileAppBar(
              title:
                  (focusDeliveryOrder
                          ? YorksV1LogisticsStrings.deliveryOrder
                          : YorksV1LogisticsStrings.materialReturns)
                      .active(language),
              leading: YorksMobileIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              trailing: YorksMobileIconButton(
                icon: Icons.refresh_rounded,
                tooltip: YorksV1LogisticsStrings.refresh.active(language),
                onPressed: () => _refresh(ref),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: compactRoute
          ? AppBar(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              title: _ReturnsBilingualTitle(
                language: language,
                deliveryOrderOnly: focusDeliveryOrder,
              ),
              actions: [
                IconButton(
                  tooltip:
                      YorksV1LogisticsStrings.deliveryOrdersAndReturns.primary,
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => _refresh(ref),
                ),
              ],
            )
          : null,
      body: content,
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(yorksV1ReturnsDocumentsWorkspaceProvider(requestId));
    ref.invalidate(yorksV1LogisticsWorkspaceProvider(requestId));
    ref.invalidate(yorksV1MaterialRequestDetailProvider(requestId));
  }
}

class _ReturnsBilingualTitle extends StatelessWidget {
  const _ReturnsBilingualTitle({
    required this.language,
    required this.deliveryOrderOnly,
  });
  final AppLanguage language;
  final bool deliveryOrderOnly;

  @override
  Widget build(BuildContext context) => Text(
    (deliveryOrderOnly
            ? YorksV1LogisticsStrings.deliveryOrder
            : YorksV1LogisticsStrings.deliveryOrdersAndReturns)
        .active(language),
    textDirection: language.isRtl ? TextDirection.rtl : TextDirection.ltr,
    style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
  );
}

class _ReturnsDocumentsBody extends ConsumerStatefulWidget {
  const _ReturnsDocumentsBody({
    required this.workspace,
    required this.onChanged,
    required this.showPageHeader,
    required this.focusDeliveryOrder,
    required this.focusedDispatchId,
  });

  final YorksV1ReturnsDocumentsWorkspace workspace;
  final VoidCallback onChanged;
  final bool showPageHeader;
  final bool focusDeliveryOrder;
  final String? focusedDispatchId;

  @override
  ConsumerState<_ReturnsDocumentsBody> createState() =>
      _ReturnsDocumentsBodyState();
}

class _ReturnsDocumentsBodyState extends ConsumerState<_ReturnsDocumentsBody> {
  final _note = TextEditingController();
  final _search = TextEditingController();
  final Map<String, TextEditingController> _quantities = {};
  final _documents = const YorksV1LogisticsDocumentService();
  late String _saveDraftIdempotencyKey;
  late String _submitDraftIdempotencyKey;
  bool _saving = false;
  bool _deliveryOrderFocusHandled = false;
  bool _mobileReview = false;

  YorksV1MaterialReturn? get _editableDraft {
    for (final materialReturn in widget.workspace.materialReturns) {
      if (materialReturn.canEditDraft) return materialReturn;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _saveDraftIdempotencyKey = const Uuid().v4();
    _submitDraftIdempotencyKey = const Uuid().v4();
    _syncDraft();
    _scheduleFocusedDeliveryOrder();
  }

  @override
  void didUpdateWidget(covariant _ReturnsDocumentsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace != widget.workspace) {
      final oldDraft = _editableDraftFrom(oldWidget.workspace);
      final newDraft = _editableDraft;
      _syncDraft();
      if (oldDraft?.id != newDraft?.id ||
          oldDraft?.recordVersion != newDraft?.recordVersion) {
        _saveDraftIdempotencyKey = const Uuid().v4();
        _submitDraftIdempotencyKey = const Uuid().v4();
      }
    }
    if (oldWidget.focusDeliveryOrder != widget.focusDeliveryOrder ||
        oldWidget.focusedDispatchId != widget.focusedDispatchId) {
      _deliveryOrderFocusHandled = false;
    }
    _scheduleFocusedDeliveryOrder();
  }

  @override
  void dispose() {
    _note.dispose();
    _search.dispose();
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncDraft() {
    final draft = _editableDraft;
    _note.text = draft?.note ?? '';
    final draftQuantities = {
      for (final line in draft?.lines ?? const <YorksV1MaterialReturnLine>[])
        line.receiptReviewLineId: line.returnQuantity,
    };
    final candidateIds = widget.workspace.returnCandidates
        .map((candidate) => candidate.receiptReviewLineId)
        .toSet();
    for (final entry in Map<String, TextEditingController>.from(
      _quantities,
    ).entries) {
      if (!candidateIds.contains(entry.key)) {
        entry.value.dispose();
        _quantities.remove(entry.key);
      }
    }
    for (final candidate in widget.workspace.returnCandidates) {
      final controller = _quantities.putIfAbsent(
        candidate.receiptReviewLineId,
        TextEditingController.new,
      );
      controller.text = draftQuantities[candidate.receiptReviewLineId] ?? '';
    }
  }

  YorksV1MaterialReturn? _editableDraftFrom(
    YorksV1ReturnsDocumentsWorkspace workspace,
  ) {
    for (final materialReturn in workspace.materialReturns) {
      if (materialReturn.canEditDraft) return materialReturn;
    }
    return null;
  }

  void _removeReturnLine(String receiptReviewLineId) {
    _quantities[receiptReviewLineId]?.clear();
    setState(() {});
  }

  void _scheduleFocusedDeliveryOrder() {
    if (!widget.focusDeliveryOrder || _deliveryOrderFocusHandled) return;
    _deliveryOrderFocusHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      YorksV1DeliveryOrderDispatch? target;
      for (final dispatch in widget.workspace.deliveryOrderDispatches) {
        if (widget.focusedDispatchId == dispatch.dispatchId) {
          target = dispatch;
          break;
        }
      }
      if (target == null ||
          (!target.canGenerate && target.deliveryOrder == null)) {
        for (final dispatch in widget.workspace.deliveryOrderDispatches) {
          if (dispatch.canGenerate || dispatch.deliveryOrder != null) {
            target = dispatch;
            break;
          }
        }
      }
      if (target == null ||
          (!target.canGenerate && target.deliveryOrder == null)) {
        return;
      }
      final changed = await showYorksV1DeliveryOrderGenerationDialog(
        context,
        workspace: widget.workspace,
        dispatch: target,
        documents: _documents,
      );
      if (changed == true && mounted) widget.onChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (YorksMobileUi.isActive(context)) {
      if (widget.focusDeliveryOrder) {
        return _MobileDeliveryOrderWorkspace(
          workspace: widget.workspace,
          documents: _documents,
          onChanged: widget.onChanged,
        );
      }
      return PopScope(canPop: !_saving, child: _buildMobileReturnFlow(context));
    }
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.pageMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showPageHeader) ...[
                  YorksR35PageHeader(
                    eyebrow: YorksV1ShellStrings.operationalWorkspace.primary,
                    title:
                        (widget.focusDeliveryOrder
                                ? YorksV1LogisticsStrings.deliveryOrder
                                : YorksV1LogisticsStrings
                                      .deliveryOrdersAndReturns)
                            .primary,
                    description:
                        (widget.focusDeliveryOrder
                                ? YorksV1LogisticsStrings
                                      .deliveryOrderAfterReceipt
                                : YorksV1LogisticsStrings.materialReturns)
                            .primary,
                    actions: [
                      SizedBox(
                        height: AppSpacing.controlHeight,
                        child: OutlinedButton.icon(
                          onPressed: widget.onChanged,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(YorksV1LogisticsStrings.refresh.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                NexusSectionCard(
                  child: _WorkspaceFacts(
                    workspace: widget.workspace,
                    deliveryOrderOnly: widget.focusDeliveryOrder,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                NexusSectionCard(
                  title: YorksV1LogisticsStrings.deliveryOrders.primary,
                  child: _DeliveryOrderList(
                    workspace: widget.workspace,
                    documents: _documents,
                    onChanged: widget.onChanged,
                  ),
                ),
                if (!widget.focusDeliveryOrder) ...[
                  const SizedBox(height: AppSpacing.lg),
                  if (widget.workspace.canSubmitMaterialReturn) ...[
                    NexusSectionCard(
                      title: YorksV1LogisticsStrings.materialReturns.primary,
                      child: _buildReturnEditor(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  NexusSectionCard(
                    title: YorksV1LogisticsStrings.materialReturns.primary,
                    child: _ReturnHistory(
                      workspace: widget.workspace,
                      documents: _documents,
                      onChanged: widget.onChanged,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileReturnFlow(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final candidates = widget.workspace.returnCandidates
        .where((candidate) => _number(candidate.eligibleReturnQuantity) > 0)
        .where(
          (candidate) =>
              query.isEmpty ||
              candidate.description.toLowerCase().contains(query) ||
              (candidate.brandOrigin ?? '').toLowerCase().contains(query) ||
              candidate.dispatchNumber.toLowerCase().contains(query),
        )
        .toList(growable: false);
    final selected = widget.workspace.returnCandidates
        .where(
          (candidate) =>
              _number(_quantities[candidate.receiptReviewLineId]?.text ?? '') >
              0,
        )
        .toList(growable: false);
    return Column(
      key: ValueKey(
        _mobileReview ? 'mobile-return-review' : 'mobile-return-select',
      ),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
            children: [
              YorksMobilePageTitle(
                eyebrow: widget.workspace.requestNumber ?? '',
                title:
                    (_mobileReview
                            ? YorksV1LogisticsStrings.reviewReturn
                            : YorksV1LogisticsStrings.newMaterialReturn)
                        .primary,
                description:
                    (_mobileReview
                            ? YorksV1LogisticsStrings.reviewReturnedMaterial
                            : YorksV1LogisticsStrings.selectDeliveredMaterial)
                        .primary,
              ),
              const SizedBox(height: 14),
              YorksMobileCard(
                child: Row(
                  children: [
                    Expanded(
                      child: _MobileReturnFact(
                        label: YorksV1LogisticsStrings.project.primary,
                        value: widget.workspace.projectName,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MobileReturnFact(
                        label: YorksV1LogisticsStrings.scope.primary,
                        value: widget.workspace.scopeName,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              YorksMobileCallout(
                icon: Icons.verified_user_outlined,
                title: YorksV1LogisticsStrings.eligibleGoodReceivedOnly.primary,
                message: YorksV1LogisticsStrings
                    .procurementConfirmsBeforeStock
                    .primary,
              ),
              const SizedBox(height: 14),
              if (!_mobileReview) ...[
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    labelText:
                        YorksV1LogisticsStrings.searchDeliveredItems.primary,
                    hintText: YorksV1LogisticsStrings.searchItemHint.primary,
                  ),
                ),
                const SizedBox(height: 12),
                if (candidates.isEmpty)
                  YorksMobileCard(
                    child: Text(
                      YorksV1LogisticsStrings.noEligibleReturns.primary,
                    ),
                  )
                else
                  for (final candidate in candidates) ...[
                    _MobileReturnSelectionCard(
                      candidate: candidate,
                      quantity:
                          _quantities[candidate.receiptReviewLineId]!.text,
                      onTap: () => _editMobileQuantity(candidate),
                    ),
                    const SizedBox(height: 10),
                  ],
              ] else ...[
                YorksMobileSectionHeader(
                  title: YorksV1LogisticsStrings.returnDraft.primary,
                  subtitle:
                      YorksV1LogisticsStrings.reviewReturnedMaterial.primary,
                ),
                const SizedBox(height: 10),
                for (final candidate in selected) ...[
                  _MobileReturnReviewCard(
                    candidate: candidate,
                    quantity: _quantities[candidate.receiptReviewLineId]!.text,
                    onEdit: () => _editMobileQuantity(candidate),
                    onRemove: () =>
                        _removeReturnLine(candidate.receiptReviewLineId),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: _note,
                  minLines: 3,
                  maxLines: 5,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: YorksV1LogisticsStrings.notes.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
        YorksMobileStickyActions(
          summary: selected.isEmpty
              ? null
              : YorksV1LogisticsStrings.selectedItems(selected.length).primary,
          children: _mobileReview
              ? [
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _mobileReview = false),
                    child: Text(
                      MaterialLocalizations.of(context).backButtonTooltip,
                    ),
                  ),
                  if (_editableDraft?.canSubmit == true)
                    FilledButton.icon(
                      onPressed: _saving ? null : _submitDraft,
                      icon: const Icon(Icons.send_outlined, size: 18),
                      label: Text(YorksV1LogisticsStrings.submitReturn.primary),
                    )
                  else
                    FilledButton.icon(
                      onPressed: selected.isEmpty || _saving
                          ? null
                          : _saveDraft,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                        YorksV1LogisticsStrings.saveReturnDraft.primary,
                      ),
                    ),
                ]
              : [
                  FilledButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () => setState(() => _mobileReview = true),
                    child: Text(
                      YorksV1LogisticsStrings.nextItems(
                        selected.length,
                      ).primary,
                    ),
                  ),
                ],
        ),
      ],
    );
  }

  Future<void> _editMobileQuantity(YorksV1ReturnCandidate candidate) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _MobileReturnQuantityPicker(
        candidate: candidate,
        initial: _quantities[candidate.receiptReviewLineId]!.text,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _quantities[candidate.receiptReviewLineId]!.text = result;
    });
  }

  Widget _buildReturnEditor(BuildContext context) {
    final candidates = widget.workspace.returnCandidates
        .where((candidate) => _number(candidate.eligibleReturnQuantity) > 0)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (candidates.isEmpty)
          Text(
            YorksV1LogisticsStrings.noEligibleReturns.primary,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
          )
        else
          _ResponsiveReturnCandidates(
            candidates: candidates,
            controllers: _quantities,
            onRemove: _removeReturnLine,
          ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _note,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: YorksV1LogisticsStrings.returnNote.primary,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            SizedBox(
              width: 230,
              child: PrimaryButton(
                label: YorksV1LogisticsStrings.saveReturnDraft.primary,
                icon: Icons.save_outlined,
                isLoading: _saving,
                onPressed: candidates.isEmpty || _saving ? null : _saveDraft,
              ),
            ),
            if (_editableDraft?.canSubmit == true)
              SizedBox(
                width: 210,
                child: SecondaryButton(
                  label: YorksV1LogisticsStrings.submitReturn.primary,
                  icon: Icons.send_outlined,
                  onPressed: _saving ? null : _submitDraft,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveDraft() async {
    final lines = <YorksV1MaterialReturnDraftLineInput>[];
    for (final candidate in widget.workspace.returnCandidates) {
      final quantity =
          _quantities[candidate.receiptReviewLineId]?.text.trim() ?? '';
      if (quantity.isEmpty) continue;
      final parsed = _number(quantity);
      if (parsed <= 0 || parsed > _number(candidate.eligibleReturnQuantity)) {
        _showFailure(YorksV1LogisticsStrings.invalidReturn.primary);
        return;
      }
      lines.add(
        YorksV1MaterialReturnDraftLineInput(
          receiptReviewLineId: candidate.receiptReviewLineId,
          returnQuantity: quantity,
        ),
      );
    }
    if (lines.isEmpty) {
      _showFailure(YorksV1LogisticsStrings.invalidReturn.primary);
      return;
    }
    setState(() => _saving = true);
    try {
      final draft = _editableDraft;
      await ref
          .read(yorksV1LogisticsRepositoryProvider)
          .saveMaterialReturnDraft(
            YorksV1MaterialReturnDraftInput(
              returnId: draft?.id,
              requestId: widget.workspace.requestId,
              expectedVersion: draft?.recordVersion ?? 0,
              note: _note.text,
              lines: lines,
              idempotencyKey: _saveDraftIdempotencyKey,
            ),
          );
      if (!mounted) return;
      _saveDraftIdempotencyKey = const Uuid().v4();
      widget.onChanged();
    } catch (_) {
      if (mounted) _showFailure(YorksV1LogisticsStrings.savingFailed.primary);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitDraft() async {
    final draft = _editableDraft;
    if (draft == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(yorksV1LogisticsRepositoryProvider)
          .submitMaterialReturn(
            YorksV1MaterialReturnSubmissionInput(
              returnId: draft.id,
              expectedVersion: draft.recordVersion,
              idempotencyKey: _submitDraftIdempotencyKey,
            ),
          );
      if (!mounted) return;
      _submitDraftIdempotencyKey = const Uuid().v4();
      widget.onChanged();
    } catch (_) {
      if (mounted) _showFailure(YorksV1LogisticsStrings.savingFailed.primary);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showFailure(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _MobileDeliveryOrderWorkspace extends StatelessWidget {
  const _MobileDeliveryOrderWorkspace({
    required this.workspace,
    required this.documents,
    required this.onChanged,
  });

  final YorksV1ReturnsDocumentsWorkspace workspace;
  final YorksV1LogisticsDocumentService documents;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
    children: [
      YorksMobilePageTitle(
        eyebrow: workspace.requestNumber ?? '',
        title: YorksV1LogisticsStrings.deliveryOrders.primary,
        description: YorksV1LogisticsStrings.deliveryOrderAfterReceipt.primary,
      ),
      const SizedBox(height: 14),
      YorksMobileCallout(
        icon: Icons.lock_outline_rounded,
        title: YorksV1LogisticsStrings.deliveryOrder.primary,
        message: YorksV1LogisticsStrings.deliveryOrderAfterReceipt.primary,
      ),
      const SizedBox(height: 14),
      if (workspace.deliveryOrderDispatches.isEmpty)
        YorksMobileCard(
          child: Text(YorksV1LogisticsStrings.noDeliveryOrders.primary),
        )
      else
        for (final dispatch in workspace.deliveryOrderDispatches) ...[
          _DeliveryOrderCard(
            workspace: workspace,
            dispatch: dispatch,
            documents: documents,
            onChanged: onChanged,
          ),
          const SizedBox(height: 10),
        ],
    ],
  );
}

class _MobileReturnFact extends StatelessWidget {
  const _MobileReturnFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.muted,
          fontSize: 9,
          letterSpacing: .8,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelLarge,
      ),
    ],
  );
}

class _MobileReturnSelectionCard extends StatelessWidget {
  const _MobileReturnSelectionCard({
    required this.candidate,
    required this.quantity,
    required this.onTap,
  });

  final YorksV1ReturnCandidate candidate;
  final String quantity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = _number(quantity) > 0;
    return YorksMobileCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.successContainer
                  : AppColors.blueContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              selected ? Icons.check_rounded : Icons.inventory_2_outlined,
              color: selected ? AppColors.success : AppColors.blue,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(child: _CandidateDescription(candidate)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                selected
                    ? '${yorksV1DisplayQuantity(quantity)} ${candidate.unit}'
                    : '${yorksV1DisplayQuantity(candidate.eligibleReturnQuantity)} ${candidate.unit}',
                style: AppTypography.labelLarge,
              ),
              Text(
                selected
                    ? YorksV1LogisticsStrings.returnQuantity.primary
                    : YorksV1LogisticsStrings.eligibleToReturn.primary,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileReturnReviewCard extends StatelessWidget {
  const _MobileReturnReviewCard({
    required this.candidate,
    required this.quantity,
    required this.onEdit,
    required this.onRemove,
  });

  final YorksV1ReturnCandidate candidate;
  final String quantity;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => YorksMobileCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CandidateDescription(candidate),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MobileReturnFact(
                label: YorksV1LogisticsStrings.returnQuantity.primary,
                value: '${yorksV1DisplayQuantity(quantity)} ${candidate.unit}',
              ),
            ),
            IconButton(
              tooltip: YorksV1LogisticsStrings.returnQuantity.primary,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MobileReturnQuantityPicker extends StatefulWidget {
  const _MobileReturnQuantityPicker({
    required this.candidate,
    required this.initial,
  });

  final YorksV1ReturnCandidate candidate;
  final String initial;

  @override
  State<_MobileReturnQuantityPicker> createState() =>
      _MobileReturnQuantityPickerState();
}

class _MobileReturnQuantityPickerState
    extends State<_MobileReturnQuantityPicker> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CandidateDescription(widget.candidate),
          const SizedBox(height: 10),
          Text(
            '${YorksV1LogisticsStrings.eligibleToReturn.primary}: ${yorksV1DisplayQuantity(widget.candidate.eligibleReturnQuantity)} ${widget.candidate.unit}',
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          _QuantityField(controller: _controller),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _save,
            child: Text(YorksV1LogisticsStrings.saveReview.primary),
          ),
        ],
      ),
    ),
  );

  void _save() {
    final quantity = _number(_controller.text);
    if (quantity < 0 ||
        quantity > _number(widget.candidate.eligibleReturnQuantity)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(YorksV1LogisticsStrings.invalidReturn.primary)),
      );
      return;
    }
    Navigator.of(context).pop(quantity == 0 ? '' : _controller.text.trim());
  }
}

class _WorkspaceFacts extends StatelessWidget {
  const _WorkspaceFacts({
    required this.workspace,
    this.deliveryOrderOnly = false,
  });
  final YorksV1ReturnsDocumentsWorkspace workspace;
  final bool deliveryOrderOnly;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.xxl,
    runSpacing: AppSpacing.md,
    children: [
      _Fact(
        (deliveryOrderOnly
                ? YorksV1LogisticsStrings.deliveryOrder
                : YorksV1LogisticsStrings.deliveryOrdersAndReturns)
            .primary,
        workspace.requestNumber ?? '',
      ),
      _Fact(YorksV1LogisticsStrings.project.primary, workspace.projectName),
      _Fact(YorksV1LogisticsStrings.scope.primary, workspace.scopeName),
    ],
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: AppSpacing.xxs),
      Text(value, style: AppTypography.bodyMedium),
    ],
  );
}

class _DeliveryOrderList extends ConsumerWidget {
  const _DeliveryOrderList({
    required this.workspace,
    required this.documents,
    required this.onChanged,
  });

  final YorksV1ReturnsDocumentsWorkspace workspace;
  final YorksV1LogisticsDocumentService documents;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (workspace.deliveryOrderDispatches.isEmpty) {
      return Text(
        YorksV1LogisticsStrings.noDeliveryOrders.primary,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
      );
    }
    return Column(
      children: [
        for (final dispatch in workspace.deliveryOrderDispatches)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _DeliveryOrderCard(
              workspace: workspace,
              dispatch: dispatch,
              documents: documents,
              onChanged: onChanged,
            ),
          ),
      ],
    );
  }
}

class _DeliveryOrderCard extends ConsumerStatefulWidget {
  const _DeliveryOrderCard({
    required this.workspace,
    required this.dispatch,
    required this.documents,
    required this.onChanged,
  });

  final YorksV1ReturnsDocumentsWorkspace workspace;
  final YorksV1DeliveryOrderDispatch dispatch;
  final YorksV1LogisticsDocumentService documents;
  final VoidCallback onChanged;

  @override
  ConsumerState<_DeliveryOrderCard> createState() => _DeliveryOrderCardState();
}

class _DeliveryOrderCardState extends ConsumerState<_DeliveryOrderCard> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.dispatch.deliveryOrder;
    final current = order?.currentRevision;
    final documentsEnabled = ref.watch(yorksV1FeatureFlagsProvider).documents;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                widget.dispatch.dispatchNumber,
                style: AppTypography.titleSmall,
              ),
              if (order != null)
                Text(order.reference, style: AppTypography.bodyMedium),
              if (current != null)
                Text(
                  '${YorksV1LogisticsStrings.revision.primary} ${current.revisionNumber}',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
          if (current != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${current.generatedByDisplayName} · ${_date(current.generatedAt)}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.md),
            _FourColumnTable(lines: current.lines),
          ],
          if (widget.dispatch.canGenerate || order != null) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                if (widget.dispatch.canGenerate)
                  SizedBox(
                    width: 230,
                    child: SecondaryButton(
                      label: order == null
                          ? YorksV1LogisticsStrings
                                .generateDeliveryOrder
                                .primary
                          : YorksV1LogisticsStrings
                                .regenerateDeliveryOrder
                                .primary,
                      icon: Icons.description_outlined,
                      onPressed: _working ? null : _generate,
                    ),
                  ),
                if (order != null && current != null) ...[
                  SizedBox(
                    width: 120,
                    child: SecondaryButton(
                      label: YorksV1LogisticsStrings.exportExcel.primary,
                      icon: Icons.table_view_outlined,
                      onPressed: _working
                          ? null
                          : () => _export(order, current),
                    ),
                  ),
                  SizedBox(
                    width: 145,
                    child: SecondaryButton(
                      label: YorksV1LogisticsStrings.printDocument.primary,
                      icon: Icons.print_outlined,
                      onPressed: _working ? null : () => _print(order, current),
                    ),
                  ),
                  SizedBox(
                    width: 165,
                    child: SecondaryButton(
                      label: YorksV1LogisticsStrings.downloadPdf.primary,
                      icon: Icons.download_outlined,
                      onPressed: _working
                          ? null
                          : () => _downloadPdf(order, current),
                    ),
                  ),
                  if (documentsEnabled)
                    SizedBox(
                      width: 160,
                      child: SecondaryButton(
                        label: YorksV1DocumentStrings.documents.primary,
                        icon: Icons.folder_open_outlined,
                        onPressed: _working
                            ? null
                            : () => context.push(
                                RoutePaths.yorksV1ProjectDocumentsPath(
                                  widget.workspace.projectId,
                                  entityType: 'delivery_order',
                                  entityId: order.id,
                                ),
                              ),
                      ),
                    ),
                  if (documentsEnabled)
                    SizedBox(
                      width: 230,
                      child: SecondaryButton(
                        label: YorksV1DocumentStrings
                            .storeControlledVersion
                            .primary,
                        icon: Icons.verified_outlined,
                        onPressed: _working
                            ? null
                            : () => _storePdfSnapshot(order, current),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generate() async {
    final changed = await showYorksV1DeliveryOrderGenerationDialog(
      context,
      workspace: widget.workspace,
      dispatch: widget.dispatch,
      documents: widget.documents,
    );
    if (changed == true && mounted) widget.onChanged();
  }

  Future<void> _export(
    YorksV1DeliveryOrder order,
    YorksV1DeliveryOrderRevision revision,
  ) async {
    final bytes = widget.documents.buildDeliveryOrderExcel(
      workspace: widget.workspace,
      dispatch: widget.dispatch,
      revision: revision,
    );
    await ref
        .read(yorksV1BoqWorkbookFileServiceProvider)
        .saveWorkbook(
          bytes: bytes,
          suggestedName: widget.documents.suggestedDeliveryOrderExcelName(
            order,
            revision,
          ),
        );
  }

  Future<void> _print(
    YorksV1DeliveryOrder order,
    YorksV1DeliveryOrderRevision revision,
  ) => widget.documents.printDeliveryOrder(
    workspace: widget.workspace,
    dispatch: widget.dispatch,
    revision: revision,
  );

  Future<void> _downloadPdf(
    YorksV1DeliveryOrder order,
    YorksV1DeliveryOrderRevision revision,
  ) => widget.documents.shareDeliveryOrderPdf(
    workspace: widget.workspace,
    dispatch: widget.dispatch,
    revision: revision,
  );

  Future<void> _storePdfSnapshot(
    YorksV1DeliveryOrder order,
    YorksV1DeliveryOrderRevision revision,
  ) async {
    setState(() => _working = true);
    try {
      final bytes = await widget.documents.buildDeliveryOrderPdf(
        workspace: widget.workspace,
        dispatch: widget.dispatch,
        revision: revision,
        format: PdfPageFormat.a4,
      );
      await ref
          .read(yorksV1DocumentsRepositoryProvider)
          .upload(
            YorksV1DocumentUploadInput(
              projectId: widget.workspace.projectId,
              entityType: YorksV1DocumentEntityType.deliveryOrder,
              entityId: order.id,
              classification: YorksV1DocumentClassification.operational,
              fileName: widget.documents
                  .suggestedDeliveryOrderExcelName(order, revision)
                  .replaceFirst(RegExp(r'\.xlsx$'), '.pdf'),
              mimeType: 'application/pdf',
              bytes: bytes,
              origin: YorksV1DocumentOrigin.generated,
              sourceEntityType: YorksV1DocumentEntityType.deliveryOrder,
              sourceEntityId: order.id,
              sourceRevision: revision.revisionNumber.toString(),
              idempotencyKey: const Uuid().v5(
                Namespace.url.value,
                'yorks-delivery-order-pdf:${order.id}:${revision.revisionNumber}',
              ),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(YorksV1DocumentStrings.uploadSucceeded.primary),
          ),
        );
      }
    } catch (_) {
      if (mounted) _failure(context);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}

/// Opens Delivery Order generation on the current Material Request surface.
/// The trusted RPC still owns eligibility and the immutable snapshot.
Future<bool?> showYorksV1DeliveryOrderGenerationDialog(
  BuildContext context, {
  required YorksV1ReturnsDocumentsWorkspace workspace,
  required YorksV1DeliveryOrderDispatch dispatch,
  required YorksV1LogisticsDocumentService documents,
}) => showDialog<bool>(
  context: context,
  animationStyle: AnimationStyle.noAnimation,
  barrierDismissible: false,
  builder: (_) => _DeliveryOrderGenerationDialog(
    workspace: workspace,
    dispatch: dispatch,
    documents: documents,
  ),
);

enum _DeliveryOrderOutput { print, download }

class _DeliveryOrderGenerationDialog extends ConsumerStatefulWidget {
  const _DeliveryOrderGenerationDialog({
    required this.workspace,
    required this.dispatch,
    required this.documents,
  });

  final YorksV1ReturnsDocumentsWorkspace workspace;
  final YorksV1DeliveryOrderDispatch dispatch;
  final YorksV1LogisticsDocumentService documents;

  @override
  ConsumerState<_DeliveryOrderGenerationDialog> createState() =>
      _DeliveryOrderGenerationDialogState();
}

class _DeliveryOrderGenerationDialogState
    extends ConsumerState<_DeliveryOrderGenerationDialog> {
  late final TextEditingController _reference;
  late final String _idempotencyKey;
  bool _working = false;
  bool _creatingRevision = false;

  @override
  void initState() {
    super.initState();
    _reference = TextEditingController(
      text: widget.dispatch.deliveryOrder?.reference ?? '',
    );
    _idempotencyKey = const Uuid().v4();
  }

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (YorksMobileUi.isActive(context)) return _buildMobile(context);
    final order = widget.dispatch.deliveryOrder;
    final revision = order?.currentRevision;
    final showingPreview = revision != null && !_creatingRevision;
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: EdgeInsets.all(
        screen.width < AppSpacing.yorksV1DesktopBreakpoint
            ? AppSpacing.md
            : AppSpacing.xxl,
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: screen.height * .88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (showingPreview
                                  ? YorksV1LogisticsStrings.deliveryOrder
                                  : YorksV1LogisticsStrings
                                        .generateDeliveryOrder)
                              .primary,
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          widget.dispatch.dispatchNumber,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: _working
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: showingPreview
                      ? [
                          _ControlledDeliveryOrderPreview(
                            key: const ValueKey(
                              'yorks-v1-controlled-delivery-order-preview',
                            ),
                            workspace: widget.workspace,
                            dispatch: widget.dispatch,
                            revision: revision,
                            documents: widget.documents,
                            height: screen.height * .64,
                          ),
                        ]
                      : [
                          TextField(
                            controller: _reference,
                            enabled: !_working,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: YorksV1LogisticsStrings
                                  .deliveryOrderReference
                                  .primary,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _DeliveryOrderSnapshotCallout(),
                        ],
                ),
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: [
                    SecondaryButton(
                      label: MaterialLocalizations.of(
                        context,
                      ).cancelButtonLabel,
                      isExpanded: false,
                      onPressed: _working
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                    if (showingPreview)
                      SecondaryButton(
                        label: YorksV1LogisticsStrings.printDocument.primary,
                        icon: Icons.print_outlined,
                        isExpanded: false,
                        onPressed: _working
                            ? null
                            : () => _printCurrent(order!, revision),
                      )
                    else
                      SecondaryButton(
                        label: YorksV1LogisticsStrings.printDocument.primary,
                        icon: Icons.print_outlined,
                        isExpanded: false,
                        onPressed: _working
                            ? null
                            : () =>
                                  _generateAndOpen(_DeliveryOrderOutput.print),
                      ),
                    PrimaryButton(
                      label: YorksV1LogisticsStrings.downloadPdf.primary,
                      icon: Icons.download_outlined,
                      isExpanded: false,
                      isLoading: _working,
                      onPressed: _working
                          ? null
                          : showingPreview
                          ? () => _shareCurrent(order!, revision)
                          : () =>
                                _generateAndOpen(_DeliveryOrderOutput.download),
                    ),
                    if (showingPreview && widget.dispatch.canGenerate)
                      SecondaryButton(
                        label: YorksV1LogisticsStrings
                            .regenerateDeliveryOrder
                            .primary,
                        icon: Icons.restart_alt_rounded,
                        isExpanded: false,
                        onPressed: _working
                            ? null
                            : () => setState(() => _creatingRevision = true),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    final order = widget.dispatch.deliveryOrder;
    final revision = order?.currentRevision;
    final showingPreview = revision != null && !_creatingRevision;
    final documentsEnabled = ref.watch(yorksV1FeatureFlagsProvider).documents;
    return PopScope(
      canPop: !_working,
      child: Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: AppColors.mobileSurface,
          body: Column(
            children: [
              YorksMobileAppBar(
                title:
                    (showingPreview
                            ? YorksV1LogisticsStrings.deliveryOrder
                            : YorksV1LogisticsStrings.generateDeliveryOrder)
                        .primary,
                leading: YorksMobileIconButton(
                  icon: Icons.close_rounded,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: _working
                      ? () {}
                      : () => Navigator.of(context).pop(),
                ),
                trailing: !showingPreview
                    ? null
                    : YorksMobileIconButton(
                        icon: Icons.share_outlined,
                        tooltip: YorksV1LogisticsStrings.share.primary,
                        onPressed: _working
                            ? () {}
                            : () => _shareCurrent(order!, revision),
                      ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 22),
                  children: [
                    YorksMobilePageTitle(
                      eyebrow: widget.dispatch.dispatchNumber,
                      title:
                          order?.reference ??
                          YorksV1LogisticsStrings.generateDeliveryOrder.primary,
                      description: YorksV1LogisticsStrings
                          .deliveryOrderAfterReceipt
                          .primary,
                    ),
                    const SizedBox(height: 14),
                    if (!showingPreview) ...[
                      YorksMobileCard(
                        child: TextField(
                          controller: _reference,
                          enabled: !_working,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: YorksV1LogisticsStrings
                                .deliveryOrderReference
                                .primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      _ControlledDeliveryOrderPreview(
                        key: const ValueKey('mobile-delivery-order-preview'),
                        workspace: widget.workspace,
                        dispatch: widget.dispatch,
                        revision: revision,
                        documents: widget.documents,
                        height: 520,
                      ),
                      const SizedBox(height: 12),
                      _DeliveryOrderSnapshotCallout(),
                      if (documentsEnabled || widget.dispatch.canGenerate) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 4,
                          children: [
                            if (documentsEnabled)
                              TextButton.icon(
                                onPressed: _working
                                    ? null
                                    : () => _storeCurrent(order!, revision),
                                icon: const Icon(
                                  Icons.verified_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  YorksV1LogisticsStrings.storeVersion.primary,
                                ),
                              ),
                            if (widget.dispatch.canGenerate)
                              TextButton.icon(
                                onPressed: _working
                                    ? null
                                    : () => setState(
                                        () => _creatingRevision = true,
                                      ),
                                icon: const Icon(
                                  Icons.restart_alt_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  YorksV1LogisticsStrings
                                      .regenerateDeliveryOrder
                                      .primary,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              YorksMobileStickyActions(
                children: !showingPreview
                    ? [
                        OutlinedButton.icon(
                          onPressed: _working
                              ? null
                              : () => _generateAndOpen(
                                  _DeliveryOrderOutput.print,
                                ),
                          icon: const Icon(Icons.print_outlined, size: 18),
                          label: Text(
                            YorksV1LogisticsStrings.printDocument.primary,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _working
                              ? null
                              : () => _generateAndOpen(
                                  _DeliveryOrderOutput.download,
                                ),
                          icon: _working
                              ? const SizedBox.square(
                                  dimension: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download_outlined, size: 18),
                          label: Text(
                            YorksV1LogisticsStrings.downloadPdf.primary,
                          ),
                        ),
                      ]
                    : [
                        OutlinedButton.icon(
                          onPressed: _working
                              ? null
                              : () => _printCurrent(order!, revision),
                          icon: const Icon(Icons.print_outlined, size: 18),
                          label: Text(
                            YorksV1LogisticsStrings.printDocument.primary,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _working
                              ? null
                              : () => _shareCurrent(order!, revision),
                          icon: _working
                              ? const SizedBox.square(
                                  dimension: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download_outlined, size: 18),
                          label: Text(
                            YorksV1LogisticsStrings.downloadPdf.primary,
                          ),
                        ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _printCurrent(
    YorksV1DeliveryOrder order,
    YorksV1DeliveryOrderRevision revision,
  ) => widget.documents.printDeliveryOrder(
    workspace: widget.workspace,
    dispatch: widget.dispatch,
    revision: revision,
  );

  Future<void> _shareCurrent(
    YorksV1DeliveryOrder order,
    YorksV1DeliveryOrderRevision revision,
  ) => widget.documents.shareDeliveryOrderPdf(
    workspace: widget.workspace,
    dispatch: widget.dispatch,
    revision: revision,
  );

  Future<void> _storeCurrent(
    YorksV1DeliveryOrder order,
    YorksV1DeliveryOrderRevision revision,
  ) async {
    setState(() => _working = true);
    try {
      final bytes = await widget.documents.buildDeliveryOrderPdf(
        workspace: widget.workspace,
        dispatch: widget.dispatch,
        revision: revision,
        format: PdfPageFormat.a4,
      );
      await ref
          .read(yorksV1DocumentsRepositoryProvider)
          .upload(
            YorksV1DocumentUploadInput(
              projectId: widget.workspace.projectId,
              entityType: YorksV1DocumentEntityType.deliveryOrder,
              entityId: order.id,
              classification: YorksV1DocumentClassification.operational,
              fileName: widget.documents
                  .suggestedDeliveryOrderExcelName(order, revision)
                  .replaceFirst(RegExp(r'\.xlsx$'), '.pdf'),
              mimeType: 'application/pdf',
              bytes: bytes,
              origin: YorksV1DocumentOrigin.generated,
              sourceEntityType: YorksV1DocumentEntityType.deliveryOrder,
              sourceEntityId: order.id,
              sourceRevision: revision.revisionNumber.toString(),
              idempotencyKey: const Uuid().v5(
                Namespace.url.value,
                'yorks-delivery-order-pdf:${order.id}:${revision.revisionNumber}',
              ),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(YorksV1DocumentStrings.uploadSucceeded.primary),
          ),
        );
      }
    } catch (_) {
      if (mounted) _showFailure(YorksV1LogisticsStrings.savingFailed.primary);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _generateAndOpen(_DeliveryOrderOutput output) async {
    if (_reference.text.trim().isEmpty) {
      _showFailure(
        YorksV1LogisticsStrings.deliveryOrderReferenceRequired.primary,
      );
      return;
    }
    setState(() => _working = true);
    try {
      final updated = await ref
          .read(yorksV1LogisticsRepositoryProvider)
          .generateDeliveryOrder(
            YorksV1DeliveryOrderGenerationInput(
              requestId: widget.workspace.requestId,
              dispatchId: widget.dispatch.dispatchId,
              expectedRequestVersion: widget.workspace.requestRecordVersion,
              expectedDispatchVersion: widget.dispatch.dispatchRecordVersion,
              deliveryOrderReference: _reference.text,
              idempotencyKey: _idempotencyKey,
            ),
          );
      YorksV1DeliveryOrderDispatch? dispatch;
      for (final candidate in updated.deliveryOrderDispatches) {
        if (candidate.dispatchId == widget.dispatch.dispatchId) {
          dispatch = candidate;
          break;
        }
      }
      final revision = dispatch?.deliveryOrder?.currentRevision;
      if (dispatch == null || revision == null) {
        throw StateError('Missing Delivery Order snapshot after generation.');
      }
      if (output == _DeliveryOrderOutput.print) {
        await widget.documents.printDeliveryOrder(
          workspace: updated,
          dispatch: dispatch,
          revision: revision,
        );
      } else {
        await widget.documents.shareDeliveryOrderPdf(
          workspace: updated,
          dispatch: dispatch,
          revision: revision,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        _showFailure(YorksV1LogisticsStrings.savingFailed.primary);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showFailure(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _DeliveryOrderSnapshotCallout extends StatelessWidget {
  @override
  Widget build(BuildContext context) => YorksMobileCallout(
    icon: Icons.lock_outline_rounded,
    title: YorksV1LogisticsStrings.deliveryOrder.primary,
    message: YorksV1LogisticsStrings.deliveryOrderAfterReceipt.primary,
  );
}

/// Uses the exact A4 bytes sent to print/share, so web and mobile never keep a
/// separate hand-built Delivery Order preview in sync with the PDF template.
class _ControlledDeliveryOrderPreview extends StatelessWidget {
  const _ControlledDeliveryOrderPreview({
    super.key,
    required this.workspace,
    required this.dispatch,
    required this.revision,
    required this.documents,
    required this.height,
  });

  final YorksV1ReturnsDocumentsWorkspace workspace;
  final YorksV1DeliveryOrderDispatch dispatch;
  final YorksV1DeliveryOrderRevision revision;
  final YorksV1LogisticsDocumentService documents;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    clipBehavior: Clip.antiAlias,
    child: PdfPreview(
      build: (_) => documents.buildDeliveryOrderPdf(
        workspace: workspace,
        dispatch: dispatch,
        revision: revision,
        format: PdfPageFormat.a4,
      ),
      allowPrinting: false,
      allowSharing: false,
      canChangeOrientation: false,
      canChangePageFormat: false,
      initialPageFormat: PdfPageFormat.a4,
      useActions: false,
      // The native PDF rasterizer completes asynchronously. A determinate
      // indicator keeps the loading state accessible without leaving an
      // indeterminate test ticker running when no native rasterizer exists.
      loadingWidget: const Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(value: .38, strokeWidth: 2.5),
        ),
      ),
    ),
  );
}

class _FourColumnTable extends StatelessWidget {
  const _FourColumnTable({required this.lines});
  final List<YorksV1DeliveryOrderLine> lines;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < AppSpacing.yorksV1DesktopBreakpoint) {
        return Column(
          children: [
            for (final line in lines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(line.description),
                subtitle: Text(
                  '${yorksV1DisplayQuantity(line.quantity)} ${line.unit}',
                ),
                leading: Text(line.serialNumber.toString()),
              ),
          ],
        );
      }
      return Table(
        border: TableBorder.all(color: AppColors.line),
        columnWidths: const {
          0: IntrinsicColumnWidth(),
          1: FlexColumnWidth(),
          2: IntrinsicColumnWidth(),
          3: IntrinsicColumnWidth(),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: AppColors.blueContainer),
            children: [
              _TableCell(
                YorksV1LogisticsStrings.serialNumber.primary,
                bold: true,
              ),
              _TableCell(
                YorksV1LogisticsStrings.itemDescription.primary,
                bold: true,
              ),
              _TableCell(
                YorksV1LogisticsStrings.deliveryQuantity.primary,
                bold: true,
              ),
              _TableCell(YorksV1LogisticsStrings.unit.primary, bold: true),
            ],
          ),
          for (final line in lines)
            TableRow(
              children: [
                _TableCell(line.serialNumber.toString()),
                _TableCell(line.description),
                _TableCell(yorksV1DisplayQuantity(line.quantity)),
                _TableCell(line.unit),
              ],
            ),
        ],
      );
    },
  );
}

class _TableCell extends StatelessWidget {
  const _TableCell(this.value, {this.bold = false});
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.sm),
    child: Text(
      value,
      style: bold ? AppTypography.labelMedium : AppTypography.bodySmall,
    ),
  );
}

class _ResponsiveReturnCandidates extends StatelessWidget {
  const _ResponsiveReturnCandidates({
    required this.candidates,
    required this.controllers,
    required this.onRemove,
  });

  final List<YorksV1ReturnCandidate> candidates;
  final Map<String, TextEditingController> controllers;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= AppSpacing.yorksV1DesktopBreakpoint) {
        return Column(
          children: [
            const Divider(height: 1),
            for (final candidate in candidates)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: _CandidateDescription(candidate)),
                    Expanded(
                      child: _Fact(
                        YorksV1LogisticsStrings.eligibleToReturn.primary,
                        '${candidate.eligibleReturnQuantity} ${candidate.unit}',
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _QuantityField(
                        controller: controllers[candidate.receiptReviewLineId]!,
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                      onPressed: () => onRemove(candidate.receiptReviewLineId),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
          ],
        );
      }
      return Column(
        children: [
          for (final candidate in candidates)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _MobileReturnCandidate(
                candidate: candidate,
                controller: controllers[candidate.receiptReviewLineId]!,
                onRemove: () => onRemove(candidate.receiptReviewLineId),
              ),
            ),
        ],
      );
    },
  );
}

class _CandidateDescription extends StatelessWidget {
  const _CandidateDescription(this.candidate);
  final YorksV1ReturnCandidate candidate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(candidate.description, style: AppTypography.bodyMedium),
      Text(
        [
          candidate.brandOrigin,
          candidate.dispatchNumber,
        ].whereType<String>().join(' · '),
        style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
      ),
    ],
  );
}

class _QuantityField extends StatelessWidget {
  const _QuantityField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: YorksV1LogisticsStrings.returnQuantity.primary,
      border: const OutlineInputBorder(),
    ),
  );
}

class _MobileReturnCandidate extends StatelessWidget {
  const _MobileReturnCandidate({
    required this.candidate,
    required this.controller,
    required this.onRemove,
  });

  final YorksV1ReturnCandidate candidate;
  final TextEditingController controller;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (_) => _MobileReturnQuantityEditor(
          candidate: candidate,
          controller: controller,
          onRemove: onRemove,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          children: [
            Expanded(child: _CandidateDescription(candidate)),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${candidate.eligibleReturnQuantity} ${candidate.unit}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium,
                  ),
                  Text(
                    YorksV1LogisticsStrings.eligibleToReturn.primary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MobileReturnQuantityEditor extends StatelessWidget {
  const _MobileReturnQuantityEditor({
    required this.candidate,
    required this.controller,
    required this.onRemove,
  });

  final YorksV1ReturnCandidate candidate;
  final TextEditingController controller;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CandidateDescription(candidate),
          const SizedBox(height: AppSpacing.md),
          _Fact(
            YorksV1LogisticsStrings.eligibleToReturn.primary,
            '${candidate.eligibleReturnQuantity} ${candidate.unit}',
          ),
          const SizedBox(height: AppSpacing.md),
          _QuantityField(controller: controller),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: YorksV1LogisticsStrings.saveReturnDraft.primary,
            icon: Icons.check_outlined,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: MaterialLocalizations.of(context).deleteButtonTooltip,
            icon: Icons.delete_outline_rounded,
            onPressed: () {
              onRemove();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    ),
  );
}

class _ReturnHistory extends ConsumerWidget {
  const _ReturnHistory({
    required this.workspace,
    required this.documents,
    required this.onChanged,
  });

  final YorksV1ReturnsDocumentsWorkspace workspace;
  final YorksV1LogisticsDocumentService documents;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (workspace.materialReturns.isEmpty) {
      return Text(
        YorksV1LogisticsStrings.noMaterialReturns.primary,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
      );
    }
    return Column(
      children: [
        for (final materialReturn in workspace.materialReturns)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _MaterialReturnCard(
              workspace: workspace,
              materialReturn: materialReturn,
              documents: documents,
              onChanged: onChanged,
            ),
          ),
      ],
    );
  }
}

class _MaterialReturnCard extends ConsumerStatefulWidget {
  const _MaterialReturnCard({
    required this.workspace,
    required this.materialReturn,
    required this.documents,
    required this.onChanged,
  });

  final YorksV1ReturnsDocumentsWorkspace workspace;
  final YorksV1MaterialReturn materialReturn;
  final YorksV1LogisticsDocumentService documents;
  final VoidCallback onChanged;

  @override
  ConsumerState<_MaterialReturnCard> createState() =>
      _MaterialReturnCardState();
}

class _MaterialReturnCardState extends ConsumerState<_MaterialReturnCard> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final materialReturn = widget.materialReturn;
    final documentsEnabled = ref.watch(yorksV1FeatureFlagsProvider).documents;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                materialReturn.number ??
                    YorksV1LogisticsStrings.materialReturns.primary,
                style: AppTypography.titleSmall,
              ),
              _ReturnStateChip(state: materialReturn.state),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${materialReturn.draftedByDisplayName} · ${_date(materialReturn.draftedAt)}',
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
          if (materialReturn.rejectionReason != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _Fact(
              YorksV1LogisticsStrings.rejectionReason.primary,
              materialReturn.rejectionReason!,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          for (final line in materialReturn.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(child: Text(line.description)),
                  Text('${line.returnQuantity} ${line.unit}'),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              SizedBox(
                width: 120,
                child: SecondaryButton(
                  label: YorksV1LogisticsStrings.exportExcel.primary,
                  icon: Icons.table_view_outlined,
                  onPressed: _working ? null : _export,
                ),
              ),
              SizedBox(
                width: 145,
                child: SecondaryButton(
                  label: YorksV1LogisticsStrings.printDocument.primary,
                  icon: Icons.print_outlined,
                  onPressed: _working ? null : _print,
                ),
              ),
              if (documentsEnabled)
                SizedBox(
                  width: 160,
                  child: SecondaryButton(
                    label: YorksV1DocumentStrings.documents.primary,
                    icon: Icons.folder_open_outlined,
                    onPressed: _working
                        ? null
                        : () => context.push(
                            RoutePaths.yorksV1ProjectDocumentsPath(
                              widget.workspace.projectId,
                              entityType: 'material_return',
                              entityId: materialReturn.id,
                            ),
                          ),
                  ),
                ),
              if (documentsEnabled)
                SizedBox(
                  width: 230,
                  child: SecondaryButton(
                    label:
                        YorksV1DocumentStrings.storeControlledVersion.primary,
                    icon: Icons.verified_outlined,
                    onPressed: _working ? null : _storePdfSnapshot,
                  ),
                ),
              if (materialReturn.canConfirm)
                SizedBox(
                  width: 230,
                  child: PrimaryButton(
                    label: YorksV1LogisticsStrings.confirmReturn.primary,
                    icon: Icons.warehouse_outlined,
                    isLoading: _working,
                    onPressed: _working ? null : _confirm,
                  ),
                ),
              if (materialReturn.canReject)
                SizedBox(
                  width: 170,
                  child: SecondaryButton(
                    label: YorksV1LogisticsStrings.rejectReturn.primary,
                    icon: Icons.close_outlined,
                    onPressed: _working ? null : _reject,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    final bytes = widget.documents.buildMaterialReturnExcel(
      workspace: widget.workspace,
      materialReturn: widget.materialReturn,
    );
    await ref
        .read(yorksV1BoqWorkbookFileServiceProvider)
        .saveWorkbook(
          bytes: bytes,
          suggestedName: widget.documents.suggestedMaterialReturnExcelName(
            widget.materialReturn,
          ),
        );
  }

  Future<void> _print() => widget.documents.printMaterialReturn(
    workspace: widget.workspace,
    materialReturn: widget.materialReturn,
  );

  Future<void> _storePdfSnapshot() async {
    setState(() => _working = true);
    try {
      final materialReturn = widget.materialReturn;
      final bytes = await widget.documents.buildMaterialReturnPdf(
        workspace: widget.workspace,
        materialReturn: materialReturn,
        format: PdfPageFormat.a4,
      );
      await ref
          .read(yorksV1DocumentsRepositoryProvider)
          .upload(
            YorksV1DocumentUploadInput(
              projectId: widget.workspace.projectId,
              entityType: YorksV1DocumentEntityType.materialReturn,
              entityId: materialReturn.id,
              classification: YorksV1DocumentClassification.operational,
              fileName: widget.documents
                  .suggestedMaterialReturnExcelName(materialReturn)
                  .replaceFirst(RegExp(r'\.xlsx$'), '.pdf'),
              mimeType: 'application/pdf',
              bytes: bytes,
              origin: YorksV1DocumentOrigin.generated,
              sourceEntityType: YorksV1DocumentEntityType.materialReturn,
              sourceEntityId: materialReturn.id,
              sourceRevision: materialReturn.recordVersion.toString(),
              idempotencyKey: const Uuid().v5(
                Namespace.url.value,
                'yorks-material-return-pdf:${materialReturn.id}:${materialReturn.recordVersion}',
              ),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(YorksV1DocumentStrings.uploadSucceeded.primary),
          ),
        );
      }
    } catch (_) {
      if (mounted) _failure(context);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _confirm() async {
    final mappings =
        await showModalBottomSheet<List<YorksV1MaterialReturnLineMappingInput>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface,
          builder: (_) => _ReturnConfirmationSheet(
            workspace: widget.workspace,
            materialReturn: widget.materialReturn,
          ),
        );
    if (mappings == null) return;
    setState(() => _working = true);
    try {
      await ref
          .read(yorksV1LogisticsRepositoryProvider)
          .confirmMaterialReturn(
            YorksV1MaterialReturnConfirmationInput(
              returnId: widget.materialReturn.id,
              expectedVersion: widget.materialReturn.recordVersion,
              lineMappings: mappings,
              idempotencyKey: const Uuid().v4(),
            ),
          );
      if (!mounted) return;
      widget.onChanged();
    } catch (_) {
      if (mounted) _failure(context);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _reject() async {
    final reason = await _reasonDialog(context);
    if (reason == null || reason.trim().isEmpty) return;
    setState(() => _working = true);
    try {
      await ref
          .read(yorksV1LogisticsRepositoryProvider)
          .rejectMaterialReturn(
            YorksV1MaterialReturnRejectionInput(
              returnId: widget.materialReturn.id,
              expectedVersion: widget.materialReturn.recordVersion,
              reason: reason,
              idempotencyKey: const Uuid().v4(),
            ),
          );
      if (!mounted) return;
      widget.onChanged();
    } catch (_) {
      if (mounted) _failure(context);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}

class _ReturnConfirmationSheet extends StatefulWidget {
  const _ReturnConfirmationSheet({
    required this.workspace,
    required this.materialReturn,
  });

  final YorksV1ReturnsDocumentsWorkspace workspace;
  final YorksV1MaterialReturn materialReturn;

  @override
  State<_ReturnConfirmationSheet> createState() =>
      _ReturnConfirmationSheetState();
}

class _ReturnConfirmationSheetState extends State<_ReturnConfirmationSheet> {
  static const _newItem = '__new_item__';
  final Map<String, String> _choices = {};

  @override
  Widget build(BuildContext context) {
    final externalLines = widget.materialReturn.lines
        .where((line) => line.source == YorksV1LogisticsSource.externalSupplier)
        .toList(growable: false);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                YorksV1LogisticsStrings.confirmReturn.primary,
                style: AppTypography.titleLarge,
              ),
              if (externalLines.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                for (final line in externalLines) ...[
                  Text(line.description, style: AppTypography.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  DropdownButtonFormField<String>(
                    initialValue: _choices[line.id] ?? _newItem,
                    decoration: InputDecoration(
                      labelText:
                          YorksV1LogisticsStrings.mapInventoryItem.primary,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: _newItem,
                        child: Text(
                          YorksV1LogisticsStrings.newInventoryItem.primary,
                        ),
                      ),
                      for (final item
                          in widget.workspace.returnInventoryItems.where(
                            (item) =>
                                item.unit.toLowerCase() ==
                                line.unit.toLowerCase(),
                          ))
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            [
                              item.description,
                              item.brandOrigin,
                              item.unit,
                            ].whereType<String>().join(' · '),
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _choices[line.id] = value ?? _newItem;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
              PrimaryButton(
                label: YorksV1LogisticsStrings.confirmReturn.primary,
                icon: Icons.verified_outlined,
                onPressed: () => Navigator.of(context).pop([
                  for (final line in externalLines)
                    YorksV1MaterialReturnLineMappingInput(
                      returnLineId: line.id,
                      inventoryItemId: _choices[line.id] == _newItem
                          ? null
                          : _choices[line.id],
                      newInventoryItem:
                          _choices[line.id] == null ||
                              _choices[line.id] == _newItem
                          ? YorksV1NewReturnInventoryItemInput(
                              description: line.description,
                              brandOrigin: line.brandOrigin,
                              unit: line.unit,
                            )
                          : null,
                    ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReturnStateChip extends StatelessWidget {
  const _ReturnStateChip({required this.state});
  final YorksV1MaterialReturnState state;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: state == YorksV1MaterialReturnState.confirmed
          ? AppColors.successContainer
          : state == YorksV1MaterialReturnState.rejected
          ? AppColors.errorContainer
          : AppColors.blueContainer,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
    ),
    child: Text(
      yorksV1MaterialReturnStateCopy(state).primary,
      style: AppTypography.labelSmall,
    ),
  );
}

Future<String?> _reasonDialog(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(YorksV1LogisticsStrings.rejectionReason.primary),
      content: TextField(
        controller: controller,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: YorksV1LogisticsStrings.rejectionReason.primary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(YorksV1LogisticsStrings.rejectReturn.primary),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

void _failure(BuildContext context) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(YorksV1LogisticsStrings.savingFailed.primary)),
    );

double _number(String value) => double.tryParse(value) ?? 0;

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
