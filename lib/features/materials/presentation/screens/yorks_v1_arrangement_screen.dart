import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_arrangement.dart';
import '../../../../shared/models/yorks_v1_arrangement_strings.dart';
import '../../../../shared/models/yorks_v1_quantity.dart';
import '../../../../shared/models/yorks_v1_shell_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_arrangement_provider.dart';
import '../../../../shared/providers/yorks_v1_arrangement_repository_provider.dart';
import '../../../../shared/providers/yorks_v1_material_request_provider.dart';

/// One responsive view for Procurement arrangement and Project Engineer review.
/// Server-derived action flags decide whether the current viewer can edit or
/// decide; this screen never infers authority from a local role label.
class YorksV1ArrangementScreen extends ConsumerWidget {
  const YorksV1ArrangementScreen({
    super.key,
    required this.requestId,
    this.embedded = false,
    this.onClose,
    this.onCompleted,
  });

  final String requestId;

  /// The record detail uses a bounded desktop dialog.  Its close control lives
  /// in the dialog header rather than being stacked over the workspace, which
  /// prevents it from drifting over the arrangement title at narrow heights.
  final bool embedded;
  final VoidCallback? onClose;

  /// The record-detail modal and the compact arrangement route both leave the
  /// editor after a successful, server-confirmed hand-off to the Project
  /// Engineer.  This keeps the UI in sync with the workflow state rather than
  /// leaving a stale working form on screen.
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final workspace = ref.watch(yorksV1ArrangementWorkspaceProvider(requestId));
    final mobile = YorksMobileUi.isActive(context) && !embedded;
    final compactRoute =
        !embedded &&
        !mobile &&
        MediaQuery.sizeOf(context).width < AppSpacing.yorksV1DesktopBreakpoint;
    final body = workspace.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _ArrangementError(
        language: language,
        onRetry: () =>
            ref.invalidate(yorksV1ArrangementWorkspaceProvider(requestId)),
      ),
      data: (value) => mobile
          ? _MobileArrangementWorkspaceBody(
              workspace: value,
              language: language,
              onCompleted: onCompleted,
            )
          : _ArrangementWorkspaceBody(
              workspace: value,
              language: language,
              showPageHeader: !compactRoute && !embedded,
              directEditor: embedded || compactRoute,
              onCompleted: onCompleted,
              onClose: onClose,
            ),
    );
    if (mobile) {
      return Scaffold(
        backgroundColor: AppColors.mobileSurface,
        body: Column(
          children: [
            YorksMobileAppBar(
              title:
                  workspace.valueOrNull?.requestNumber ??
                  YorksV1ArrangementStrings.arrangement.active(language),
              leading: YorksMobileIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              trailing: YorksMobileIconButton(
                icon: Icons.menu_rounded,
                tooltip: YorksV1ArrangementStrings.arrangement.active(language),
                onPressed: () => ref.invalidate(
                  yorksV1ArrangementWorkspaceProvider(requestId),
                ),
              ),
            ),
            Expanded(child: body),
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
              title: _ActiveText(
                copy: YorksV1ArrangementStrings.arrangeMaterialRequest,
                language: language,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: YorksV1ArrangementStrings.arrangement.primary,
                  onPressed: () => ref.invalidate(
                    yorksV1ArrangementWorkspaceProvider(requestId),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            )
          : null,
      body: embedded
          ? Column(
              children: [
                _EmbeddedArrangementHeader(
                  language: language,
                  requestNumber:
                      workspace.valueOrNull?.requestNumber ?? requestId,
                  onClose: onClose,
                ),
                Expanded(child: body),
              ],
            )
          : body,
    );
  }
}

class _EmbeddedArrangementHeader extends StatelessWidget {
  const _EmbeddedArrangementHeader({
    required this.language,
    required this.requestNumber,
    this.onClose,
  });

  final AppLanguage language;
  final String requestNumber;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActiveText(
                copy: YorksV1ArrangementStrings.arrangeMaterialRequest,
                language: language,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '$requestNumber · ${YorksV1ArrangementStrings.arrangeMaterialRequestDescription.active(language)}',
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        if (onClose != null)
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
      ],
    ),
  );
}

class _MobileArrangementWorkspaceBody extends ConsumerWidget {
  const _MobileArrangementWorkspaceBody({
    required this.workspace,
    required this.language,
    this.onCompleted,
  });

  final YorksV1ArrangementWorkspace workspace;
  final AppLanguage language;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final working = workspace.workingArrangement;
    if (working != null && workspace.canSave) {
      final inventory = ref.watch(yorksV1ArrangementInventoryProvider);
      return inventory.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _ArrangementError(
          language: language,
          onRetry: () => ref.invalidate(yorksV1ArrangementInventoryProvider),
        ),
        data: (items) => _ArrangementEditor(
          workspace: workspace,
          arrangement: working,
          inventoryItems: items,
          language: language,
          mobileFlow: true,
          onCompleted: onCompleted,
        ),
      );
    }
    final current = workspace.currentArrangement;
    if (current != null && workspace.canDecide) {
      return _MobileArrangementDecisionView(
        workspace: workspace,
        arrangement: current,
        language: language,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (workspace.canBegin && working == null)
            _BeginArrangementAction(workspace: workspace, language: language),
          if (current != null) ...[
            YorksMobilePageTitle(
              eyebrow: YorksV1ArrangementStrings.arrangementReview.active(
                language,
              ),
              title: YorksV1ArrangementStrings.arrangement.active(language),
              description: YorksV1ArrangementStrings.reviewSummary.active(
                language,
              ),
            ),
            const SizedBox(height: 16),
            _ArrangementReadOnly(arrangement: current, language: language),
          ],
          if (workspace.arrangements.isEmpty && !workspace.canBegin)
            YorksMobileCard(
              child: _ActiveText(
                copy: YorksV1ArrangementStrings.noArrangement,
                language: language,
                center: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _ArrangementWorkspaceBody extends ConsumerWidget {
  const _ArrangementWorkspaceBody({
    required this.workspace,
    required this.language,
    required this.showPageHeader,
    required this.directEditor,
    this.onCompleted,
    this.onClose,
  });

  final YorksV1ArrangementWorkspace workspace;
  final AppLanguage language;
  final bool showPageHeader;
  final bool directEditor;
  final VoidCallback? onCompleted;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final working = workspace.workingArrangement;
    final inventory = workspace.canSave
        ? ref.watch(yorksV1ArrangementInventoryProvider)
        : const AsyncData<List<YorksV1InventoryItem>>([]);
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
                if (showPageHeader) ...[
                  YorksR35PageHeader(
                    eyebrow: YorksV1ShellStrings.operationalWorkspace.primary,
                    title: YorksV1ArrangementStrings.arrangement.primary,
                    description:
                        YorksV1ArrangementStrings.reviewSummary.primary,
                    actions: [
                      SizedBox(
                        height: AppSpacing.controlHeight,
                        child: OutlinedButton.icon(
                          onPressed: () => ref.invalidate(
                            yorksV1ArrangementWorkspaceProvider(
                              workspace.requestId,
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(
                            YorksV1ArrangementStrings.arrangement.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                if (!directEditor) ...[
                  _WorkspaceHeader(workspace: workspace),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (workspace.canBegin && working == null)
                  _BeginArrangementAction(
                    workspace: workspace,
                    language: language,
                  ),
                if (working != null) ...[
                  _ArrangementEditorSurface(
                    directEditor: directEditor,
                    child: inventory.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: LinearProgressIndicator(),
                      ),
                      error: (_, _) => _ArrangementError(
                        language: language,
                        onRetry: () =>
                            ref.invalidate(yorksV1ArrangementInventoryProvider),
                      ),
                      data: (items) => _ArrangementEditor(
                        workspace: workspace,
                        arrangement: working,
                        inventoryItems: items,
                        language: language,
                        onCompleted: onCompleted,
                        onClose: onClose,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (workspace.currentArrangement != null) ...[
                  NexusSectionCard(
                    title: YorksV1ArrangementStrings.reviewSummary.primary,
                    child: _ArrangementReadOnly(
                      arrangement: workspace.currentArrangement!,
                      language: language,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (workspace.canDecide)
                    _DecisionActions(
                      workspace: workspace,
                      arrangement: workspace.currentArrangement!,
                      language: language,
                    ),
                ],
                if (workspace.arrangements.isEmpty && !workspace.canBegin)
                  NexusSectionCard(
                    child: _ActiveText(
                      copy: YorksV1ArrangementStrings.noArrangement,
                      language: language,
                      center: true,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                if (workspace.arrangements.length > 1) ...[
                  const SizedBox(height: AppSpacing.lg),
                  NexusSectionCard(
                    title: YorksV1ArrangementStrings.arrangementHistory.primary,
                    child: Column(
                      children: [
                        for (final arrangement in workspace.arrangements.skip(
                          1,
                        ))
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: _ArrangementHistoryRow(
                              arrangement: arrangement,
                              language: language,
                            ),
                          ),
                      ],
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
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.workspace});

  final YorksV1ArrangementWorkspace workspace;

  @override
  Widget build(BuildContext context) => NexusSectionCard(
    child: Wrap(
      spacing: AppSpacing.xxl,
      runSpacing: AppSpacing.md,
      children: [
        _Meta(
          label: YorksV1ArrangementStrings.version.primary,
          value: workspace.currentArrangement == null
              ? workspace.requestRecordVersion.toString()
              : workspace.currentArrangement!.version.toString(),
        ),
        _Meta(
          label: YorksV1ArrangementStrings.arrangement.primary,
          value: workspace.requestNumber ?? '',
        ),
        if (workspace.currentArrangement != null)
          _Meta(
            label: YorksV1ArrangementStrings.decision.primary,
            value: yorksV1ArrangementStatusCopy(
              workspace.currentArrangement!.status,
            ).primary,
          ),
      ],
    ),
  );
}

class _ArrangementEditorSurface extends StatelessWidget {
  const _ArrangementEditorSurface({
    required this.directEditor,
    required this.child,
  });

  final bool directEditor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!directEditor) {
      return NexusSectionCard(
        title: YorksV1ArrangementStrings.arrangement.primary,
        child: child,
      );
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: child,
    );
  }
}

class _BeginArrangementAction extends ConsumerStatefulWidget {
  const _BeginArrangementAction({
    required this.workspace,
    required this.language,
  });

  final YorksV1ArrangementWorkspace workspace;
  final AppLanguage language;

  @override
  ConsumerState<_BeginArrangementAction> createState() =>
      _BeginArrangementActionState();
}

class _BeginArrangementActionState
    extends ConsumerState<_BeginArrangementAction> {
  bool _busy = false;
  late String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = const Uuid().v4();
  }

  @override
  Widget build(BuildContext context) => NexusSectionCard(
    child: PrimaryButton(
      label: YorksV1ArrangementStrings.startArrangement.primary,
      icon: Icons.playlist_add_check_rounded,
      isLoading: _busy,
      onPressed: _busy ? null : _begin,
    ),
  );

  Future<void> _begin() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(yorksV1ArrangementRepositoryProvider)
          .begin(
            YorksV1BeginArrangementInput(
              requestId: widget.workspace.requestId,
              expectedRequestVersion: widget.workspace.requestRecordVersion,
              idempotencyKey: _idempotencyKey,
            ),
          );
      ref.invalidate(
        yorksV1ArrangementWorkspaceProvider(widget.workspace.requestId),
      );
      ref.invalidate(
        yorksV1MaterialRequestDetailProvider(widget.workspace.requestId),
      );
      ref.invalidate(yorksV1MaterialRequestListProvider);
      _idempotencyKey = const Uuid().v4();
    } catch (_) {
      if (mounted) _showFailure(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ArrangementEditor extends ConsumerStatefulWidget {
  const _ArrangementEditor({
    required this.workspace,
    required this.arrangement,
    required this.inventoryItems,
    required this.language,
    this.mobileFlow = false,
    this.onCompleted,
    this.onClose,
  });

  final YorksV1ArrangementWorkspace workspace;
  final YorksV1ProcurementArrangement arrangement;
  final List<YorksV1InventoryItem> inventoryItems;
  final AppLanguage language;
  final bool mobileFlow;
  final VoidCallback? onCompleted;
  final VoidCallback? onClose;

  @override
  ConsumerState<_ArrangementEditor> createState() => _ArrangementEditorState();
}

class _ArrangementEditorState extends ConsumerState<_ArrangementEditor> {
  late Map<String, _EditableArrangementLine> _lines;
  final Map<String, TextEditingController> _arrangedQuantities = {};
  final Map<String, TextEditingController> _unitCosts = {};
  final Map<String, TextEditingController> _suppliers = {};
  final Map<String, TextEditingController> _reasons = {};
  late final TextEditingController _procurementNote;
  late String _saveIdempotencyKey;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _lines = {
      for (final line in widget.arrangement.lines)
        line.id: _EditableArrangementLine.fromLine(line, widget.inventoryItems),
    };
    _initializeLineControllers();
    _procurementNote = TextEditingController(
      text: widget.arrangement.procurementNote ?? '',
    );
    _saveIdempotencyKey = const Uuid().v4();
  }

  @override
  void didUpdateWidget(covariant _ArrangementEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.arrangement.id != widget.arrangement.id) {
      _lines = {
        for (final line in widget.arrangement.lines)
          line.id: _EditableArrangementLine.fromLine(
            line,
            widget.inventoryItems,
          ),
      };
      _disposeLineControllers();
      _initializeLineControllers();
      _procurementNote.text = widget.arrangement.procurementNote ?? '';
      _saveIdempotencyKey = const Uuid().v4();
    }
  }

  @override
  void dispose() {
    _disposeLineControllers();
    _procurementNote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mobileFlow) {
      return _MobileArrangementFlow(
        workspace: widget.workspace,
        arrangement: widget.arrangement,
        inventoryItems: widget.inventoryItems,
        language: widget.language,
        lines: _lines,
        arrangedQuantities: _arrangedQuantities,
        unitCosts: _unitCosts,
        suppliers: _suppliers,
        reasons: _reasons,
        procurementNote: _procurementNote,
        busy: _busy,
        onChanged: _replace,
        onSave: _save,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ArrangementQuantityGuidance(),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 980
              ? _DesktopArrangementEditor(
                  lines: widget.arrangement.lines,
                  drafts: _lines,
                  arrangedQuantities: _arrangedQuantities,
                  unitCosts: _unitCosts,
                  suppliers: _suppliers,
                  reasons: _reasons,
                  inventoryItems: widget.inventoryItems,
                  enabled: !_busy,
                  onChanged: _replace,
                )
              : Column(
                  children: [
                    for (final line in widget.arrangement.lines) ...[
                      _MobileArrangementEditor(
                        line: line,
                        draft: _lines[line.id]!,
                        arrangedQuantity: _arrangedQuantities[line.id]!,
                        unitCost: _unitCosts[line.id]!,
                        supplier: _suppliers[line.id]!,
                        reason: _reasons[line.id]!,
                        inventoryItems: widget.inventoryItems,
                        enabled: !_busy,
                        onChanged: _replace,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          YorksV1ArrangementStrings.procurementNote.primary,
          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: _procurementNote,
          enabled: !_busy,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: YorksV1ArrangementStrings.procurementNoteHint.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Divider(height: AppSpacing.lg),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (widget.onClose != null)
                SecondaryButton(
                  label: AppStrings.cancel.primary,
                  isExpanded: false,
                  onPressed: _busy ? null : widget.onClose,
                ),
              PrimaryButton(
                label: YorksV1ArrangementStrings.saveForApproval.primary,
                icon: Icons.send_rounded,
                isExpanded: false,
                isLoading: _busy,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _replace(_EditableArrangementLine value) {
    final previous = _lines[value.arrangementLineId];
    if (value.decision == YorksV1ArrangementDecision.unavailable &&
        previous?.decision != YorksV1ArrangementDecision.unavailable) {
      _arrangedQuantities[value.arrangementLineId]?.text = '0';
    }
    setState(() => _lines = {..._lines, value.arrangementLineId: value});
  }

  Future<void> _save() async {
    final inputs = [
      for (final line in _lines.values)
        line
            .copyWith(
              arrangedQuantity:
                  _arrangedQuantities[line.arrangementLineId]!.text,
              externalSupplier: _suppliers[line.arrangementLineId]!.text,
              reason: _reasons[line.arrangementLineId]!.text,
              unitCost: _unitCosts[line.arrangementLineId]!.text,
            )
            .toInput(),
    ];
    final validationMessage = _validationMessage(inputs);
    if (validationMessage != null) {
      _showMessage(context, validationMessage);
      return;
    }
    var saved = false;
    setState(() => _busy = true);
    try {
      await ref
          .read(yorksV1ArrangementRepositoryProvider)
          .save(
            YorksV1SaveArrangementInput(
              requestId: widget.workspace.requestId,
              arrangementId: widget.arrangement.id,
              expectedRequestVersion: widget.workspace.requestRecordVersion,
              expectedArrangementVersion: widget.arrangement.recordVersion,
              lines: inputs,
              procurementNote: _procurementNote.text,
              idempotencyKey: _saveIdempotencyKey,
            ),
          );
      ref.invalidate(
        yorksV1ArrangementWorkspaceProvider(widget.workspace.requestId),
      );
      ref.invalidate(
        yorksV1MaterialRequestDetailProvider(widget.workspace.requestId),
      );
      ref.invalidate(yorksV1MaterialRequestListProvider);
      _saveIdempotencyKey = const Uuid().v4();
      saved = true;
    } catch (_) {
      if (mounted) _showFailure(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (saved && mounted) widget.onCompleted?.call();
  }

  void _initializeLineControllers() {
    for (final line in _lines.values) {
      _arrangedQuantities[line.arrangementLineId] = TextEditingController(
        text: yorksV1DisplayQuantity(line.arrangedQuantity),
      );
      _unitCosts[line.arrangementLineId] = TextEditingController(
        text: line.unitCost ?? '',
      );
      _suppliers[line.arrangementLineId] = TextEditingController(
        text: line.externalSupplier ?? '',
      );
      _reasons[line.arrangementLineId] = TextEditingController(
        text: line.reason ?? '',
      );
    }
  }

  void _disposeLineControllers() {
    for (final controller in _arrangedQuantities.values) {
      controller.dispose();
    }
    for (final controller in _unitCosts.values) {
      controller.dispose();
    }
    for (final controller in _suppliers.values) {
      controller.dispose();
    }
    for (final controller in _reasons.values) {
      controller.dispose();
    }
    _arrangedQuantities.clear();
    _unitCosts.clear();
    _suppliers.clear();
    _reasons.clear();
  }

  String? _validationMessage(List<YorksV1ArrangementLineInput> lines) {
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final arrangedLine = widget.arrangement.lines.firstWhere(
        (value) => value.id == line.arrangementLineId,
      );
      final label =
          '${YorksV1ArrangementStrings.rowNumber.primary} ${arrangedLine.displayOrder}';
      final quantity = num.tryParse(line.arrangedQuantity.trim());
      if (quantity == null || quantity < 0) {
        return YorksV1ArrangementStrings.invalidQuantityFor(
          label,
        ).active(widget.language);
      }
      if (line.decision == YorksV1ArrangementDecision.unavailable) {
        if (quantity != 0 ||
            line.reason == null ||
            line.reason!.trim().isEmpty) {
          return YorksV1ArrangementStrings.unavailableReasonFor(
            label,
          ).active(widget.language);
        }
        continue;
      }
      final requestedQuantity = num.tryParse(arrangedLine.requestedQuantity);
      if (requestedQuantity == null) {
        return YorksV1ArrangementStrings.invalidQuantityFor(
          label,
        ).active(widget.language);
      }
      if (line.decision == YorksV1ArrangementDecision.full &&
          quantity != requestedQuantity) {
        return YorksV1ArrangementStrings.fullQuantityFor(
          label,
        ).active(widget.language);
      }
      if (line.decision == YorksV1ArrangementDecision.partial &&
          (quantity <= 0 || quantity >= requestedQuantity)) {
        return YorksV1ArrangementStrings.partialQuantityFor(
          label,
        ).active(widget.language);
      }
      final unitCost = line.unitCost?.trim() ?? '';
      if (unitCost.isNotEmpty &&
          (num.tryParse(unitCost) == null || num.parse(unitCost) < 0)) {
        return YorksV1ArrangementStrings.invalidUnitCostFor(
          label,
        ).active(widget.language);
      }
      if (line.source == YorksV1ArrangementSource.warehouse &&
          (line.inventoryItemId == null ||
              line.inventoryItemId!.trim().isEmpty)) {
        return widget.inventoryItems.isEmpty
            ? YorksV1ArrangementStrings.emptyWarehouseFor(
                label,
              ).active(widget.language)
            : YorksV1ArrangementStrings.warehouseItemRequiredFor(
                label,
              ).active(widget.language);
      }
      if (line.source == YorksV1ArrangementSource.externalSupplier &&
          (line.externalSupplier == null ||
              line.externalSupplier!.trim().isEmpty)) {
        return YorksV1ArrangementStrings.supplierRequiredFor(
          label,
        ).active(widget.language);
      }
      if ((line.decision == YorksV1ArrangementDecision.partial ||
              line.decision == YorksV1ArrangementDecision.unavailable) &&
          (line.reason == null || line.reason!.trim().isEmpty)) {
        return YorksV1ArrangementStrings.partialReasonFor(
          label,
        ).active(widget.language);
      }
    }
    return null;
  }
}

enum _MobileArrangementStage { lines, line, review }

class _MobileArrangementFlow extends StatefulWidget {
  const _MobileArrangementFlow({
    required this.workspace,
    required this.arrangement,
    required this.inventoryItems,
    required this.language,
    required this.lines,
    required this.arrangedQuantities,
    required this.unitCosts,
    required this.suppliers,
    required this.reasons,
    required this.procurementNote,
    required this.busy,
    required this.onChanged,
    required this.onSave,
  });

  final YorksV1ArrangementWorkspace workspace;
  final YorksV1ProcurementArrangement arrangement;
  final List<YorksV1InventoryItem> inventoryItems;
  final AppLanguage language;
  final Map<String, _EditableArrangementLine> lines;
  final Map<String, TextEditingController> arrangedQuantities;
  final Map<String, TextEditingController> unitCosts;
  final Map<String, TextEditingController> suppliers;
  final Map<String, TextEditingController> reasons;
  final TextEditingController procurementNote;
  final bool busy;
  final ValueChanged<_EditableArrangementLine> onChanged;
  final Future<void> Function() onSave;

  @override
  State<_MobileArrangementFlow> createState() => _MobileArrangementFlowState();
}

class _MobileArrangementFlowState extends State<_MobileArrangementFlow> {
  _MobileArrangementStage _stage = _MobileArrangementStage.lines;
  int _lineIndex = 0;

  @override
  Widget build(BuildContext context) => switch (_stage) {
    _MobileArrangementStage.lines => _buildLines(),
    _MobileArrangementStage.line => _buildLine(),
    _MobileArrangementStage.review => _buildReview(),
  };

  Widget _buildLines() {
    final counts = _counts;
    return Column(
      key: const ValueKey('mobile-arrangement-list'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                YorksMobilePageTitle(
                  eyebrow:
                      '${widget.workspace.requestNumber ?? widget.workspace.requestId} · ${widget.workspace.requestState}',
                  title: YorksV1ArrangementStrings.arrangeRequestedItems.active(
                    widget.language,
                  ),
                  description: YorksV1ArrangementStrings.decideEveryLine.active(
                    widget.language,
                  ),
                ),
                const SizedBox(height: 14),
                _MobileArrangementCounts(counts: counts),
                const SizedBox(height: 10),
                for (
                  var index = 0;
                  index < widget.arrangement.lines.length;
                  index++
                ) ...[
                  _MobileArrangementLineCard(
                    line: widget.arrangement.lines[index],
                    draft: widget.lines[widget.arrangement.lines[index].id]!,
                    onTap: () => setState(() {
                      _lineIndex = index;
                      _stage = _MobileArrangementStage.line;
                    }),
                  ),
                  const SizedBox(height: 9),
                ],
              ],
            ),
          ),
        ),
        YorksMobileStickyActions(
          summary: YorksV1ArrangementStrings.linesDecided(
            widget.lines.length,
            widget.arrangement.lines.length,
          ).active(widget.language),
          children: [
            PrimaryButton(
              key: const ValueKey('mobile-arrangement-review-action'),
              label: YorksV1ArrangementStrings.saveForApproval.active(
                widget.language,
              ),
              onPressed: widget.busy
                  ? null
                  : () =>
                        setState(() => _stage = _MobileArrangementStage.review),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLine() {
    final line = widget.arrangement.lines[_lineIndex];
    final draft = widget.lines[line.id]!;
    final inventoryItem = widget.inventoryItems
        .where((item) => item.id == draft.inventoryItemId)
        .firstOrNull;
    return Column(
      key: const ValueKey('mobile-arrangement-line'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                YorksMobilePageTitle(
                  eyebrow: YorksV1ArrangementStrings.itemPosition(
                    _lineIndex + 1,
                    widget.arrangement.lines.length,
                  ).active(widget.language),
                  title: line.description,
                  description: [
                    line.brandOrigin,
                    '${YorksV1ArrangementStrings.requested.active(widget.language)} ${yorksV1DisplayQuantity(line.requestedQuantity)} ${line.unit}',
                  ].whereType<String>().join(' · '),
                ),
                const SizedBox(height: 16),
                _MobileFieldLabel(
                  label: YorksV1ArrangementStrings.decision.active(
                    widget.language,
                  ),
                ),
                YorksMobileSegmentedControl<YorksV1ArrangementDecision>(
                  options: [
                    for (final decision in YorksV1ArrangementDecision.values)
                      YorksMobileSegmentOption(
                        value: decision,
                        label: yorksV1ArrangementDecisionCopy(
                          decision,
                        ).active(widget.language),
                      ),
                  ],
                  selected: draft.decision,
                  enabled: !widget.busy,
                  onSelected: (decision) {
                    widget.onChanged(
                      draft.copyWith(
                        decision: decision,
                        arrangedQuantity:
                            decision == YorksV1ArrangementDecision.unavailable
                            ? '0'
                            : draft.arrangedQuantity,
                        inventoryItemId:
                            decision == YorksV1ArrangementDecision.unavailable
                            ? null
                            : _keep,
                        externalSupplier:
                            decision == YorksV1ArrangementDecision.unavailable
                            ? null
                            : _keep,
                      ),
                    );
                    setState(() {});
                  },
                ),
                const SizedBox(height: 14),
                _SourcePicker(
                  value: draft,
                  enabled: !widget.busy,
                  onChanged: (value) {
                    widget.onChanged(value);
                    setState(() {});
                  },
                ),
                if (draft.decision !=
                    YorksV1ArrangementDecision.unavailable) ...[
                  const SizedBox(height: 14),
                  _InventoryOrSupplierField(
                    value: draft,
                    supplier: widget.suppliers[line.id]!,
                    inventoryItems: widget.inventoryItems,
                    enabled: !widget.busy,
                    onChanged: (value) {
                      widget.onChanged(value);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _QuantityField(
                          value: draft,
                          controller: widget.arrangedQuantities[line.id]!,
                          enabled: !widget.busy,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MobileReadOnlyField(
                          label: YorksV1ArrangementStrings.available.active(
                            widget.language,
                          ),
                          value: inventoryItem == null
                              ? '—'
                              : '${yorksV1DisplayQuantity(inventoryItem.availableQuantity)} ${inventoryItem.unit}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _UnitCostField(
                    value: draft,
                    controller: widget.unitCosts[line.id]!,
                    enabled: !widget.busy,
                  ),
                ],
                const SizedBox(height: 14),
                _ReasonField(
                  value: draft,
                  controller: widget.reasons[line.id]!,
                  enabled: !widget.busy,
                ),
                if (draft.decision == YorksV1ArrangementDecision.partial ||
                    draft.decision == YorksV1ArrangementDecision.unavailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      YorksV1ArrangementStrings.invalidLines.active(
                        widget.language,
                      ),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                YorksMobileCallout(
                  icon: Icons.lock_outline_rounded,
                  title: YorksV1ArrangementStrings.quantityRule.active(
                    widget.language,
                  ),
                  message:
                      '${YorksV1ArrangementStrings.arranged.active(widget.language)}: ${yorksV1DisplayQuantity(widget.arrangedQuantities[line.id]!.text)} / ${yorksV1DisplayQuantity(line.requestedQuantity)} ${line.unit}',
                ),
              ],
            ),
          ),
        ),
        YorksMobileStickyActions(
          children: [
            SecondaryButton(
              label: YorksV1ArrangementStrings.previous.active(widget.language),
              onPressed: widget.busy ? null : _previous,
            ),
            PrimaryButton(
              label: YorksV1ArrangementStrings.saveAndNext.active(
                widget.language,
              ),
              onPressed: widget.busy ? null : _next,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReview() {
    final counts = _counts;
    final exceptions = widget.arrangement.lines
        .where((line) {
          final decision = widget.lines[line.id]!.decision;
          return decision != YorksV1ArrangementDecision.full;
        })
        .toList(growable: false);
    return Column(
      key: const ValueKey('mobile-arrangement-review'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                YorksMobilePageTitle(
                  eyebrow: YorksV1ArrangementStrings.arrangementReview.active(
                    widget.language,
                  ),
                  title: YorksV1ArrangementStrings.readyForProjectEngineer
                      .active(widget.language),
                  description: YorksV1ArrangementStrings
                      .approvalReleasesArranged
                      .active(widget.language),
                ),
                const SizedBox(height: 14),
                _MobileArrangementCounts(counts: counts),
                if (exceptions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  YorksMobileCallout(
                    icon: Icons.warning_amber_rounded,
                    warning: true,
                    title: YorksV1ArrangementStrings.exceptionsRequireAttention(
                      exceptions.length,
                    ).active(widget.language),
                    message: YorksV1ArrangementStrings.exceptionSummary(
                      counts.partial,
                      counts.unavailable,
                    ).active(widget.language),
                  ),
                  const SizedBox(height: 10),
                  YorksMobileCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var index = 0; index < exceptions.length; index++)
                          _MobileArrangementReviewLine(
                            line: exceptions[index],
                            draft: widget.lines[exceptions[index].id]!,
                            reason: widget.reasons[exceptions[index].id]!.text,
                            arrangedQuantity: widget
                                .arrangedQuantities[exceptions[index].id]!
                                .text,
                            onTap: () {
                              _lineIndex = widget.arrangement.lines.indexWhere(
                                (line) => line.id == exceptions[index].id,
                              );
                              setState(
                                () => _stage = _MobileArrangementStage.line,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _MobileFieldLabel(
                  label: YorksV1ArrangementStrings.procurementNote.active(
                    widget.language,
                  ),
                ),
                TextField(
                  controller: widget.procurementNote,
                  enabled: !widget.busy,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: YorksV1ArrangementStrings.procurementNoteHint
                        .active(widget.language),
                  ),
                ),
              ],
            ),
          ),
        ),
        YorksMobileStickyActions(
          children: [
            SecondaryButton(
              label: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: widget.busy
                  ? null
                  : () =>
                        setState(() => _stage = _MobileArrangementStage.lines),
            ),
            PrimaryButton(
              label: YorksV1ArrangementStrings.saveForApproval.active(
                widget.language,
              ),
              isLoading: widget.busy,
              onPressed: widget.busy ? null : widget.onSave,
            ),
          ],
        ),
      ],
    );
  }

  ({int full, int partial, int unavailable}) get _counts {
    var full = 0;
    var partial = 0;
    var unavailable = 0;
    for (final line in widget.lines.values) {
      switch (line.decision) {
        case YorksV1ArrangementDecision.full:
          full++;
        case YorksV1ArrangementDecision.partial:
          partial++;
        case YorksV1ArrangementDecision.unavailable:
          unavailable++;
      }
    }
    return (full: full, partial: partial, unavailable: unavailable);
  }

  void _previous() {
    if (_lineIndex == 0) {
      setState(() => _stage = _MobileArrangementStage.lines);
      return;
    }
    setState(() => _lineIndex--);
  }

  void _next() {
    if (_lineIndex + 1 >= widget.arrangement.lines.length) {
      setState(() => _stage = _MobileArrangementStage.review);
      return;
    }
    setState(() => _lineIndex++);
  }
}

class _MobileArrangementCounts extends StatelessWidget {
  const _MobileArrangementCounts({required this.counts});

  final ({int full, int partial, int unavailable}) counts;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _MobileArrangementCount(
        value: counts.full,
        label: yorksV1ArrangementDecisionCopy(
          YorksV1ArrangementDecision.full,
        ).primary,
        color: AppColors.success,
        background: AppColors.successContainer,
      ),
      const SizedBox(width: 8),
      _MobileArrangementCount(
        value: counts.partial,
        label: yorksV1ArrangementDecisionCopy(
          YorksV1ArrangementDecision.partial,
        ).primary,
        color: AppColors.warning,
        background: AppColors.warningContainer,
      ),
      const SizedBox(width: 8),
      _MobileArrangementCount(
        value: counts.unavailable,
        label: yorksV1ArrangementDecisionCopy(
          YorksV1ArrangementDecision.unavailable,
        ).primary,
        color: AppColors.error,
        background: AppColors.errorContainer,
      ),
    ],
  );
}

class _MobileArrangementCount extends StatelessWidget {
  const _MobileArrangementCount({
    required this.value,
    required this.label,
    required this.color,
    required this.background,
  });

  final int value;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 78,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: 32,
              child: Center(
                child: Text(
                  '$value',
                  style: AppTypography.titleSmall.copyWith(color: color),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _MobileArrangementLineCard extends StatelessWidget {
  const _MobileArrangementLineCard({
    required this.line,
    required this.draft,
    required this.onTap,
  });

  final YorksV1ArrangementLine line;
  final _EditableArrangementLine draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => YorksMobileCard(
    onTap: onTap,
    child: Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '${line.displayOrder}',
            style: AppTypography.labelLarge.copyWith(color: AppColors.muted),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.description, style: AppTypography.titleSmall),
              if (line.brandOrigin != null) ...[
                const SizedBox(height: 2),
                Text(
                  line.brandOrigin!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
              const SizedBox(height: 5),
              Text(
                '${YorksV1ArrangementStrings.requested.primary} ${yorksV1DisplayQuantity(line.requestedQuantity)} ${line.unit}',
                style: AppTypography.labelMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _ArrangementDecisionChip(decision: draft.decision),
      ],
    ),
  );
}

class _MobileArrangementReviewLine extends StatelessWidget {
  const _MobileArrangementReviewLine({
    required this.line,
    required this.draft,
    required this.reason,
    required this.arrangedQuantity,
    required this.onTap,
  });

  final YorksV1ArrangementLine line;
  final _EditableArrangementLine draft;
  final String reason;
  final String arrangedQuantity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 72,
    onTap: onTap,
    leading: Icon(
      draft.decision == YorksV1ArrangementDecision.unavailable
          ? Icons.warning_amber_rounded
          : Icons.inventory_2_outlined,
      color: draft.decision == YorksV1ArrangementDecision.unavailable
          ? AppColors.warning
          : AppColors.blue,
    ),
    title: Text(
      line.description,
      style: AppTypography.titleSmall.copyWith(
        decoration: draft.decision == YorksV1ArrangementDecision.unavailable
            ? TextDecoration.lineThrough
            : null,
      ),
    ),
    subtitle: Text(
      [
        '${yorksV1DisplayQuantity(arrangedQuantity)} ${line.unit}',
        yorksV1ArrangementSourceCopy(draft.source).primary,
        if (reason.trim().isNotEmpty) reason.trim(),
      ].join(' · '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: _ArrangementDecisionChip(decision: draft.decision),
  );
}

class _ArrangementDecisionChip extends StatelessWidget {
  const _ArrangementDecisionChip({required this.decision});

  final YorksV1ArrangementDecision decision;

  @override
  Widget build(BuildContext context) {
    final color = switch (decision) {
      YorksV1ArrangementDecision.full => AppColors.success,
      YorksV1ArrangementDecision.partial => AppColors.warning,
      YorksV1ArrangementDecision.unavailable => AppColors.error,
    };
    final background = switch (decision) {
      YorksV1ArrangementDecision.full => AppColors.successContainer,
      YorksV1ArrangementDecision.partial => AppColors.warningContainer,
      YorksV1ArrangementDecision.unavailable => AppColors.errorContainer,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        yorksV1ArrangementDecisionCopy(decision).primary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _MobileFieldLabel extends StatelessWidget {
  const _MobileFieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label, style: AppTypography.labelLarge),
  );
}

class _MobileReadOnlyField extends StatelessWidget {
  const _MobileReadOnlyField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _MobileFieldLabel(label: label),
      Container(
        height: 56,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(value, style: AppTypography.bodyMedium),
      ),
    ],
  );
}

class _MobileArrangementDecisionView extends ConsumerStatefulWidget {
  const _MobileArrangementDecisionView({
    required this.workspace,
    required this.arrangement,
    required this.language,
  });

  final YorksV1ArrangementWorkspace workspace;
  final YorksV1ProcurementArrangement arrangement;
  final AppLanguage language;

  @override
  ConsumerState<_MobileArrangementDecisionView> createState() =>
      _MobileArrangementDecisionViewState();
}

class _MobileArrangementDecisionViewState
    extends ConsumerState<_MobileArrangementDecisionView> {
  bool _busy = false;
  bool _showLines = false;
  bool _exceptionsOnly = false;
  late String _approveIdempotencyKey;
  late String _returnIdempotencyKey;

  @override
  void initState() {
    super.initState();
    _approveIdempotencyKey = const Uuid().v4();
    _returnIdempotencyKey = const Uuid().v4();
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.arrangement.lines
        .where((line) => line.decision == YorksV1ArrangementDecision.full)
        .length;
    final partial = widget.arrangement.lines
        .where((line) => line.decision == YorksV1ArrangementDecision.partial)
        .length;
    final unavailable = widget.arrangement.lines
        .where(
          (line) => line.decision == YorksV1ArrangementDecision.unavailable,
        )
        .length;
    final visibleLines = _exceptionsOnly
        ? widget.arrangement.lines
              .where((line) => line.decision != YorksV1ArrangementDecision.full)
              .toList(growable: false)
        : widget.arrangement.lines;
    return PopScope(
      canPop: !_busy,
      child: Column(
        key: const ValueKey('mobile-arrangement-approval'),
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  YorksMobilePageTitle(
                    eyebrow: YorksV1ArrangementStrings.projectEngineerReview
                        .active(widget.language),
                    title: YorksV1ArrangementStrings.arrangement.active(
                      widget.language,
                    ),
                    description: YorksV1ArrangementStrings.reviewExceptionsFirst
                        .active(widget.language),
                  ),
                  const SizedBox(height: 14),
                  _MobileArrangementCounts(
                    counts: (
                      full: full,
                      partial: partial,
                      unavailable: unavailable,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _MobileDecisionOption(
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppColors.warning,
                    title: YorksV1ArrangementStrings.exceptionsRequireAttention(
                      partial + unavailable,
                    ).active(widget.language),
                    subtitle: YorksV1ArrangementStrings.exceptionSummary(
                      partial,
                      unavailable,
                    ).active(widget.language),
                    onTap: () => setState(() {
                      _showLines = true;
                      _exceptionsOnly = true;
                    }),
                  ),
                  const SizedBox(height: 9),
                  _MobileDecisionOption(
                    icon: Icons.description_outlined,
                    iconColor: AppColors.blue,
                    title:
                        '${YorksV1ArrangementStrings.allMaterialLines.active(widget.language)} · ${widget.arrangement.lines.length}',
                    subtitle: YorksV1ArrangementStrings.materialLineFacts
                        .active(widget.language),
                    onTap: () => setState(() {
                      _showLines = true;
                      _exceptionsOnly = false;
                    }),
                  ),
                  if (_showLines) ...[
                    const SizedBox(height: 10),
                    YorksMobileCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final line in visibleLines)
                            _ReadOnlyLineCard(line: line),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  YorksMobileCallout(
                    icon: Icons.info_outline_rounded,
                    title: YorksV1ArrangementStrings.approvalMeaning.active(
                      widget.language,
                    ),
                    message: YorksV1ArrangementStrings.approvalMeaningMessage
                        .active(widget.language),
                  ),
                ],
              ),
            ),
          ),
          YorksMobileStickyActions(
            children: [
              SecondaryButton(
                label: YorksV1ArrangementStrings.returnAction.active(
                  widget.language,
                ),
                onPressed: _busy ? null : _return,
              ),
              PrimaryButton(
                label: YorksV1ArrangementStrings.approveAction.active(
                  widget.language,
                ),
                isLoading: _busy,
                onPressed: _busy
                    ? null
                    : () => _decide(
                        YorksV1ArrangementReviewDecision.approved,
                        null,
                        _approveIdempotencyKey,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _return() async {
    final reason = await showDialog<String>(
      context: context,
      animationStyle: AnimationStyle.noAnimation,
      barrierDismissible: false,
      builder: (context) =>
          _MobileReturnArrangementDialog(language: widget.language),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    await _decide(
      YorksV1ArrangementReviewDecision.returned,
      reason,
      _returnIdempotencyKey,
    );
  }

  Future<void> _decide(
    YorksV1ArrangementReviewDecision decision,
    String? reason,
    String idempotencyKey,
  ) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(yorksV1ArrangementRepositoryProvider)
          .decide(
            YorksV1DecideArrangementInput(
              requestId: widget.workspace.requestId,
              arrangementId: widget.arrangement.id,
              expectedRequestVersion: widget.workspace.requestRecordVersion,
              expectedArrangementVersion: widget.arrangement.recordVersion,
              decision: decision,
              reason: reason,
              idempotencyKey: idempotencyKey,
            ),
          );
      ref.invalidate(
        yorksV1ArrangementWorkspaceProvider(widget.workspace.requestId),
      );
      ref.invalidate(
        yorksV1MaterialRequestDetailProvider(widget.workspace.requestId),
      );
      ref.invalidate(yorksV1MaterialRequestListProvider);
      if (decision == YorksV1ArrangementReviewDecision.approved) {
        _approveIdempotencyKey = const Uuid().v4();
      } else {
        _returnIdempotencyKey = const Uuid().v4();
      }
    } catch (_) {
      if (mounted) _showFailure(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _MobileDecisionOption extends StatelessWidget {
  const _MobileDecisionOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => YorksMobileCard(
    onTap: onTap,
    child: Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(11),
          ),
          child: SizedBox.square(
            dimension: 42,
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.titleSmall),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ],
    ),
  );
}

class _MobileReturnArrangementDialog extends StatefulWidget {
  const _MobileReturnArrangementDialog({required this.language});

  final AppLanguage language;

  @override
  State<_MobileReturnArrangementDialog> createState() =>
      _MobileReturnArrangementDialogState();
}

class _MobileReturnArrangementDialogState
    extends State<_MobileReturnArrangementDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: Scaffold(
      backgroundColor: AppColors.mobileSurface,
      body: Column(
        children: [
          YorksMobileAppBar(
            title: YorksV1ArrangementStrings.returnArrangement.active(
              widget.language,
            ),
            leading: YorksMobileIconButton(
              icon: Icons.chevron_left_rounded,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  YorksMobilePageTitle(
                    eyebrow: YorksV1ArrangementStrings.returnArrangement.active(
                      widget.language,
                    ),
                    title: YorksV1ArrangementStrings.whatNeedsToChange.active(
                      widget.language,
                    ),
                    description: YorksV1ArrangementStrings.returnReasonRecorded
                        .active(widget.language),
                  ),
                  const SizedBox(height: 18),
                  _MobileFieldLabel(
                    label: YorksV1ArrangementStrings.returnReason.active(
                      widget.language,
                    ),
                  ),
                  TextField(
                    key: const ValueKey('mobile-return-arrangement-reason'),
                    controller: _reason,
                    autofocus: true,
                    minLines: 4,
                    maxLines: 7,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    YorksV1ArrangementStrings.returnReasonHint.active(
                      widget.language,
                    ),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  YorksMobileCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          YorksV1ArrangementStrings.whatHappensNext.active(
                            widget.language,
                          ),
                          style: AppTypography.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          YorksV1ArrangementStrings.returnedArrangementHistory
                              .active(widget.language),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.muted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          YorksMobileStickyActions(
            children: [
              SecondaryButton(
                label: AppStrings.cancel.active(widget.language),
                onPressed: () => Navigator.of(context).pop(),
              ),
              PrimaryButton(
                label: YorksV1ArrangementStrings.returnAction.active(
                  widget.language,
                ),
                onPressed: () {
                  final value = _reason.text.trim();
                  if (value.isEmpty) return;
                  Navigator.of(context).pop(value);
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _DesktopArrangementEditor extends StatelessWidget {
  const _DesktopArrangementEditor({
    required this.lines,
    required this.drafts,
    required this.arrangedQuantities,
    required this.unitCosts,
    required this.suppliers,
    required this.reasons,
    required this.inventoryItems,
    required this.enabled,
    required this.onChanged,
  });

  final List<YorksV1ArrangementLine> lines;
  final Map<String, _EditableArrangementLine> drafts;
  final Map<String, TextEditingController> arrangedQuantities;
  final Map<String, TextEditingController> unitCosts;
  final Map<String, TextEditingController> suppliers;
  final Map<String, TextEditingController> reasons;
  final List<YorksV1InventoryItem> inventoryItems;
  final bool enabled;
  final ValueChanged<_EditableArrangementLine> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final tableWidth = constraints.maxWidth < 1060
          ? 1060.0
          : constraints.maxWidth;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Column(
              children: [
                _ArrangementTableHeader(),
                for (final line in lines)
                  _ArrangementTableRow(
                    line: line,
                    draft: drafts[line.id]!,
                    arrangedQuantity: arrangedQuantities[line.id]!,
                    unitCost: unitCosts[line.id]!,
                    supplier: suppliers[line.id]!,
                    reason: reasons[line.id]!,
                    inventoryItems: inventoryItems,
                    enabled: enabled,
                    onChanged: onChanged,
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ArrangementQuantityGuidance extends StatelessWidget {
  const _ArrangementQuantityGuidance();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.blueContainer.withValues(alpha: .42),
      border: Border.all(color: AppColors.blueContainerStrong),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.verified_user_outlined,
          color: AppColors.blue,
          size: 21,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            YorksV1ArrangementStrings.quantityRule.primary,
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    ),
  );
}

class _ArrangementTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.surfaceContainerLow,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.sm,
    ),
    child: const Row(
      children: [
        _ArrangementTableHeading(
          YorksV1ArrangementStrings.requestedItem,
          flex: 30,
        ),
        _ArrangementTableHeading(YorksV1ArrangementStrings.decision, flex: 17),
        _ArrangementTableHeading(
          YorksV1ArrangementStrings.supplierSource,
          flex: 21,
        ),
        _ArrangementTableHeading(YorksV1ArrangementStrings.requested, flex: 10),
        _ArrangementTableHeading(YorksV1ArrangementStrings.arranged, flex: 10),
        _ArrangementTableHeading(YorksV1ArrangementStrings.unitCost, flex: 12),
      ],
    ),
  );
}

class _ArrangementTableHeading extends StatelessWidget {
  const _ArrangementTableHeading(this.copy, {required this.flex});

  final TranslatableString copy;
  final int flex;

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(
      copy.primary.toUpperCase(),
      style: AppTypography.labelSmall.copyWith(
        color: AppColors.muted,
        fontWeight: FontWeight.w800,
        letterSpacing: .8,
      ),
    ),
  );
}

class _ArrangementTableRow extends StatelessWidget {
  const _ArrangementTableRow({
    required this.line,
    required this.draft,
    required this.arrangedQuantity,
    required this.unitCost,
    required this.supplier,
    required this.reason,
    required this.inventoryItems,
    required this.enabled,
    required this.onChanged,
  });

  final YorksV1ArrangementLine line;
  final _EditableArrangementLine draft;
  final TextEditingController arrangedQuantity;
  final TextEditingController unitCost;
  final TextEditingController supplier;
  final TextEditingController reason;
  final List<YorksV1InventoryItem> inventoryItems;
  final bool enabled;
  final ValueChanged<_EditableArrangementLine> onChanged;

  @override
  Widget build(BuildContext context) {
    final reasonRequired =
        draft.decision == YorksV1ArrangementDecision.partial ||
        draft.decision == YorksV1ArrangementDecision.unavailable;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 30, child: _ArrangementRequestedItem(line: line)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 17,
                child: _DecisionPicker(
                  value: draft,
                  enabled: enabled,
                  compact: true,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 21,
                child: _ArrangementSourceEditor(
                  value: draft,
                  supplier: supplier,
                  inventoryItems: inventoryItems,
                  enabled: enabled,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 10,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '${yorksV1DisplayQuantity(line.requestedQuantity)} ${line.unit}',
                    style: AppTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 10,
                child: _QuantityField(
                  value: draft,
                  controller: arrangedQuantity,
                  enabled: enabled,
                  compact: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 12,
                child: _UnitCostField(
                  value: draft,
                  controller: unitCost,
                  enabled: enabled,
                  compact: true,
                ),
              ),
            ],
          ),
          if (reasonRequired) ...[
            const SizedBox(height: AppSpacing.sm),
            _ReasonField(value: draft, controller: reason, enabled: enabled),
          ],
        ],
      ),
    );
  }
}

class _ArrangementRequestedItem extends StatelessWidget {
  const _ArrangementRequestedItem({required this.line});

  final YorksV1ArrangementLine line;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line.description,
          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        if (line.brandOrigin?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            line.brandOrigin!,
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    ),
  );
}

class _ArrangementSourceEditor extends StatelessWidget {
  const _ArrangementSourceEditor({
    required this.value,
    required this.supplier,
    required this.inventoryItems,
    required this.enabled,
    required this.onChanged,
  });

  final _EditableArrangementLine value;
  final TextEditingController supplier;
  final List<YorksV1InventoryItem> inventoryItems;
  final bool enabled;
  final ValueChanged<_EditableArrangementLine> onChanged;

  @override
  Widget build(BuildContext context) {
    if (value.decision == YorksV1ArrangementDecision.unavailable) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(
          YorksV1ArrangementStrings.noSourceRequired.primary,
          style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SourcePicker(
          value: value,
          enabled: enabled,
          compact: true,
          onChanged: onChanged,
        ),
        const SizedBox(height: AppSpacing.xs),
        _InventoryOrSupplierField(
          value: value,
          supplier: supplier,
          inventoryItems: inventoryItems,
          enabled: enabled,
          compact: true,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _MobileArrangementEditor extends StatelessWidget {
  const _MobileArrangementEditor({
    required this.line,
    required this.draft,
    required this.arrangedQuantity,
    required this.unitCost,
    required this.supplier,
    required this.reason,
    required this.inventoryItems,
    required this.enabled,
    required this.onChanged,
  });

  final YorksV1ArrangementLine line;
  final _EditableArrangementLine draft;
  final TextEditingController arrangedQuantity;
  final TextEditingController unitCost;
  final TextEditingController supplier;
  final TextEditingController reason;
  final List<YorksV1InventoryItem> inventoryItems;
  final bool enabled;
  final ValueChanged<_EditableArrangementLine> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${line.displayOrder}. ${line.description}',
          style: AppTypography.titleSmall,
        ),
        Text(
          '${YorksV1ArrangementStrings.requested.primary}: ${yorksV1DisplayQuantity(line.requestedQuantity)} ${line.unit}',
          style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.md),
        _DecisionPicker(value: draft, enabled: enabled, onChanged: onChanged),
        const SizedBox(height: AppSpacing.md),
        _SourcePicker(value: draft, enabled: enabled, onChanged: onChanged),
        const SizedBox(height: AppSpacing.md),
        _QuantityField(
          value: draft,
          controller: arrangedQuantity,
          enabled: enabled,
        ),
        const SizedBox(height: AppSpacing.md),
        _UnitCostField(value: draft, controller: unitCost, enabled: enabled),
        const SizedBox(height: AppSpacing.md),
        _InventoryOrSupplierField(
          value: draft,
          supplier: supplier,
          inventoryItems: inventoryItems,
          enabled: enabled,
          onChanged: onChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        _ReasonField(value: draft, controller: reason, enabled: enabled),
      ],
    ),
  );
}

class _DecisionPicker extends StatelessWidget {
  const _DecisionPicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.compact = false,
  });

  final _EditableArrangementLine value;
  final bool enabled;
  final ValueChanged<_EditableArrangementLine> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<YorksV1ArrangementDecision>(
        initialValue: value.decision,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: compact
              ? null
              : YorksV1ArrangementStrings.decision.primary,
          contentPadding: compact
              ? const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                )
              : null,
        ),
        items: [
          for (final decision in YorksV1ArrangementDecision.values)
            DropdownMenuItem(
              value: decision,
              child: Text(yorksV1ArrangementDecisionCopy(decision).primary),
            ),
        ],
        onChanged: !enabled
            ? null
            : (decision) {
                if (decision == null) return;
                onChanged(
                  value.copyWith(
                    decision: decision,
                    arrangedQuantity:
                        decision == YorksV1ArrangementDecision.unavailable
                        ? '0'
                        : value.arrangedQuantity,
                    inventoryItemId:
                        decision == YorksV1ArrangementDecision.unavailable
                        ? null
                        : _keep,
                    externalSupplier:
                        decision == YorksV1ArrangementDecision.unavailable
                        ? null
                        : _keep,
                  ),
                );
              },
      );
}

class _SourcePicker extends StatelessWidget {
  const _SourcePicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.compact = false,
  });

  final _EditableArrangementLine value;
  final bool enabled;
  final ValueChanged<_EditableArrangementLine> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (value.decision == YorksV1ArrangementDecision.unavailable) {
      return SizedBox(
        width: 150,
        child: Text(
          YorksV1ArrangementStrings.noSourceRequired.primary,
          style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
        ),
      );
    }
    return DropdownButtonFormField<YorksV1ArrangementSource>(
      initialValue: value.source,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: compact ? null : YorksV1ArrangementStrings.source.primary,
        contentPadding: compact
            ? const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              )
            : null,
      ),
      items: [
        for (final source in YorksV1ArrangementSource.values)
          DropdownMenuItem(
            value: source,
            child: Text(yorksV1ArrangementSourceCopy(source).primary),
          ),
      ],
      onChanged: !enabled
          ? null
          : (source) {
              if (source == null) return;
              onChanged(
                value.copyWith(
                  source: source,
                  inventoryItemId: source == YorksV1ArrangementSource.warehouse
                      ? value.inventoryItemId
                      : null,
                  externalSupplier:
                      source == YorksV1ArrangementSource.externalSupplier
                      ? value.externalSupplier
                      : null,
                ),
              );
            },
    );
  }
}

class _QuantityField extends StatelessWidget {
  const _QuantityField({
    required this.value,
    required this.controller,
    required this.enabled,
    this.compact = false,
  });

  final _EditableArrangementLine value;
  final TextEditingController controller;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 112,
    child: TextFormField(
      key: ValueKey(
        'arranged-${value.arrangementLineId}-${value.decision.wireValue}',
      ),
      controller: controller,
      enabled:
          enabled && value.decision != YorksV1ArrangementDecision.unavailable,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: compact ? null : YorksV1ArrangementStrings.arranged.primary,
        contentPadding: compact
            ? const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              )
            : null,
      ),
    ),
  );
}

class _UnitCostField extends StatelessWidget {
  const _UnitCostField({
    required this.value,
    required this.controller,
    required this.enabled,
    this.compact = false,
  });

  final _EditableArrangementLine value;
  final TextEditingController controller;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 116,
    child: TextFormField(
      key: ValueKey(
        'unit-cost-${value.arrangementLineId}-${value.decision.wireValue}',
      ),
      controller: controller,
      enabled:
          enabled && value.decision != YorksV1ArrangementDecision.unavailable,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: compact ? null : YorksV1ArrangementStrings.unitCost.primary,
        contentPadding: compact
            ? const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              )
            : null,
      ),
    ),
  );
}

class _InventoryOrSupplierField extends StatelessWidget {
  const _InventoryOrSupplierField({
    required this.value,
    required this.supplier,
    required this.inventoryItems,
    required this.enabled,
    required this.onChanged,
    this.compact = false,
  });

  final _EditableArrangementLine value;
  final TextEditingController supplier;
  final List<YorksV1InventoryItem> inventoryItems;
  final bool enabled;
  final ValueChanged<_EditableArrangementLine> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (value.decision == YorksV1ArrangementDecision.unavailable) {
      return Text(
        YorksV1ArrangementStrings.noSourceRequired.primary,
        style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
      );
    }
    if (value.source == YorksV1ArrangementSource.externalSupplier) {
      return SizedBox(
        width: 180,
        child: TextFormField(
          key: ValueKey(
            'supplier-${value.arrangementLineId}-${value.source.wireValue}-${value.decision.wireValue}',
          ),
          controller: supplier,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: compact
                ? null
                : YorksV1ArrangementStrings.supplierName.primary,
            contentPadding: compact
                ? const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  )
                : null,
          ),
        ),
      );
    }
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        initialValue:
            inventoryItems.any((item) => item.id == value.inventoryItemId)
            ? value.inventoryItemId
            : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: compact
              ? null
              : YorksV1ArrangementStrings.warehouseItem.primary,
          contentPadding: compact
              ? const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                )
              : null,
        ),
        items: [
          for (final item in inventoryItems)
            DropdownMenuItem(
              value: item.id,
              child: Text(
                '${item.description} · ${item.availableQuantity} ${item.unit}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: !enabled
            ? null
            : (itemId) => onChanged(value.copyWith(inventoryItemId: itemId)),
      ),
    );
  }
}

class _ReasonField extends StatelessWidget {
  const _ReasonField({
    required this.value,
    required this.controller,
    required this.enabled,
  });

  final _EditableArrangementLine value;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: TextFormField(
      key: ValueKey(
        'reason-${value.arrangementLineId}-${value.decision.wireValue}',
      ),
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: YorksV1ArrangementStrings.reason.primary,
      ),
    ),
  );
}

class _ArrangementReadOnly extends StatelessWidget {
  const _ArrangementReadOnly({
    required this.arrangement,
    required this.language,
  });

  final YorksV1ProcurementArrangement arrangement;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: AppSpacing.xxl,
        runSpacing: AppSpacing.md,
        children: [
          _Meta(
            label: YorksV1ArrangementStrings.version.primary,
            value: arrangement.version.toString(),
          ),
          _Meta(
            label: YorksV1ArrangementStrings.startedBy.primary,
            value: arrangement.startedByDisplayName,
          ),
          _Meta(
            label: YorksV1ArrangementStrings.decision.primary,
            value: yorksV1ArrangementStatusCopy(arrangement.status).primary,
          ),
        ],
      ),
      if (arrangement.reviewReason != null) ...[
        const SizedBox(height: AppSpacing.md),
        Text(arrangement.reviewReason!, style: AppTypography.bodyMedium),
      ],
      const SizedBox(height: AppSpacing.lg),
      LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 760
            ? _ReadOnlyDesktopTable(lines: arrangement.lines)
            : Column(
                children: [
                  for (final line in arrangement.lines) ...[
                    _ReadOnlyLineCard(line: line),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
      ),
    ],
  );
}

class _ReadOnlyDesktopTable extends StatelessWidget {
  const _ReadOnlyDesktopTable({required this.lines});
  final List<YorksV1ArrangementLine> lines;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: [
        DataColumn(label: Text(YorksV1ArrangementStrings.rowNumber.primary)),
        DataColumn(label: Text(YorksV1ArrangementStrings.requested.primary)),
        DataColumn(label: Text(YorksV1ArrangementStrings.decision.primary)),
        DataColumn(label: Text(YorksV1ArrangementStrings.source.primary)),
        DataColumn(label: Text(YorksV1ArrangementStrings.arranged.primary)),
        DataColumn(label: Text(YorksV1ArrangementStrings.unitCost.primary)),
        DataColumn(label: Text(YorksV1ArrangementStrings.availability.primary)),
        DataColumn(label: Text(YorksV1ArrangementStrings.reason.primary)),
      ],
      rows: [
        for (final line in lines)
          DataRow(
            color: WidgetStatePropertyAll(_lineBackground(line)),
            cells: [
              DataCell(Text(line.displayOrder.toString())),
              DataCell(
                Text(
                  '${line.description}\n${yorksV1DisplayQuantity(line.requestedQuantity)} ${line.unit}',
                ),
              ),
              DataCell(
                Text(
                  line.decision == null
                      ? ''
                      : yorksV1ArrangementDecisionCopy(line.decision!).primary,
                ),
              ),
              DataCell(Text(yorksV1ArrangementSourceCopy(line.source).primary)),
              DataCell(
                Text(yorksV1DisplayQuantity(line.arrangedQuantity ?? '')),
              ),
              DataCell(Text(line.unitCost ?? '')),
              DataCell(
                Text(
                  line.source == YorksV1ArrangementSource.warehouse
                      ? (line.warehouseAvailableAtSave ?? '')
                      : (line.externalSupplier ?? ''),
                ),
              ),
              DataCell(Text(line.reason ?? '')),
            ],
          ),
      ],
    ),
  );
}

class _ReadOnlyLineCard extends StatelessWidget {
  const _ReadOnlyLineCard({required this.line});
  final YorksV1ArrangementLine line;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: _lineBackground(line),
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${line.displayOrder}. ${line.description}',
          style: AppTypography.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${YorksV1ArrangementStrings.requested.primary}: ${yorksV1DisplayQuantity(line.requestedQuantity)} ${line.unit}',
        ),
        Text(
          '${YorksV1ArrangementStrings.arranged.primary}: ${yorksV1DisplayQuantity(line.arrangedQuantity ?? '')}',
        ),
        if (line.unitCost != null)
          Text(
            '${YorksV1ArrangementStrings.unitCost.primary}: ${line.unitCost}',
          ),
        Text(
          '${YorksV1ArrangementStrings.source.primary}: ${yorksV1ArrangementSourceCopy(line.source).primary}',
        ),
        if (line.reason != null)
          Text('${YorksV1ArrangementStrings.reason.primary}: ${line.reason}'),
      ],
    ),
  );
}

Color _lineBackground(YorksV1ArrangementLine line) => switch (line.decision) {
  YorksV1ArrangementDecision.partial => AppColors.warningContainer,
  YorksV1ArrangementDecision.unavailable => AppColors.errorContainer,
  _ => Colors.transparent,
};

class _DecisionActions extends ConsumerStatefulWidget {
  const _DecisionActions({
    required this.workspace,
    required this.arrangement,
    required this.language,
  });

  final YorksV1ArrangementWorkspace workspace;
  final YorksV1ProcurementArrangement arrangement;
  final AppLanguage language;

  @override
  ConsumerState<_DecisionActions> createState() => _DecisionActionsState();
}

class _DecisionActionsState extends ConsumerState<_DecisionActions> {
  bool _busy = false;
  late String _approveIdempotencyKey;
  late String _returnIdempotencyKey;

  @override
  void initState() {
    super.initState();
    _approveIdempotencyKey = const Uuid().v4();
    _returnIdempotencyKey = const Uuid().v4();
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.md,
    runSpacing: AppSpacing.md,
    children: [
      PrimaryButton(
        label: YorksV1ArrangementStrings.approveArrangement.primary,
        icon: Icons.verified_rounded,
        isExpanded: false,
        isLoading: _busy,
        onPressed: _busy
            ? null
            : () => _decide(YorksV1ArrangementReviewDecision.approved),
      ),
      SecondaryButton(
        label: YorksV1ArrangementStrings.returnToProcurement.primary,
        icon: Icons.reply_rounded,
        isExpanded: false,
        onPressed: _busy
            ? null
            : () => _decide(YorksV1ArrangementReviewDecision.returned),
      ),
    ],
  );

  Future<void> _decide(YorksV1ArrangementReviewDecision decision) async {
    String? reason;
    if (decision == YorksV1ArrangementReviewDecision.returned) {
      reason = await _returnReason(context);
      if (reason == null || reason.trim().isEmpty) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(yorksV1ArrangementRepositoryProvider)
          .decide(
            YorksV1DecideArrangementInput(
              requestId: widget.workspace.requestId,
              arrangementId: widget.arrangement.id,
              expectedRequestVersion: widget.workspace.requestRecordVersion,
              expectedArrangementVersion: widget.arrangement.recordVersion,
              decision: decision,
              reason: reason,
              idempotencyKey:
                  decision == YorksV1ArrangementReviewDecision.approved
                  ? _approveIdempotencyKey
                  : _returnIdempotencyKey,
            ),
          );
      ref.invalidate(
        yorksV1ArrangementWorkspaceProvider(widget.workspace.requestId),
      );
      ref.invalidate(
        yorksV1MaterialRequestDetailProvider(widget.workspace.requestId),
      );
      ref.invalidate(yorksV1MaterialRequestListProvider);
      if (decision == YorksV1ArrangementReviewDecision.approved) {
        _approveIdempotencyKey = const Uuid().v4();
      } else {
        _returnIdempotencyKey = const Uuid().v4();
      }
    } catch (_) {
      if (mounted) _showFailure(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ArrangementHistoryRow extends StatelessWidget {
  const _ArrangementHistoryRow({
    required this.arrangement,
    required this.language,
  });
  final YorksV1ProcurementArrangement arrangement;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.history_rounded),
    title: Text(
      '${YorksV1ArrangementStrings.version.primary} ${arrangement.version}',
    ),
    subtitle: Text(arrangement.startedByDisplayName),
    trailing: Text(yorksV1ArrangementStatusCopy(arrangement.status).primary),
  );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelLarge.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(value, style: AppTypography.bodyMedium),
      ],
    ),
  );
}

class _ArrangementError extends StatelessWidget {
  const _ArrangementError({required this.language, required this.onRetry});
  final AppLanguage language;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: NexusSectionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 40,
          ),
          const SizedBox(height: AppSpacing.md),
          _ActiveText(
            copy: YorksV1ArrangementStrings.savingFailed,
            language: language,
            center: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          SecondaryButton(
            label: YorksV1ArrangementStrings.arrangement.primary,
            icon: Icons.refresh_rounded,
            isExpanded: false,
            onPressed: onRetry,
          ),
        ],
      ),
    ),
  );
}

class _EditableArrangementLine {
  const _EditableArrangementLine({
    required this.arrangementLineId,
    required this.source,
    required this.decision,
    required this.arrangedQuantity,
    this.externalSupplier,
    this.inventoryItemId,
    this.reason,
    this.unitCost,
  });

  final String arrangementLineId;
  final YorksV1ArrangementSource source;
  final YorksV1ArrangementDecision decision;
  final String arrangedQuantity;
  final String? externalSupplier;
  final String? inventoryItemId;
  final String? reason;
  final String? unitCost;

  factory _EditableArrangementLine.fromLine(
    YorksV1ArrangementLine line,
    List<YorksV1InventoryItem> inventory,
  ) {
    final matchingItem = inventory.where(
      (item) => item.unit == line.unit && item.description == line.description,
    );
    return _EditableArrangementLine(
      arrangementLineId: line.id,
      // A fresh deployment may not have warehouse opening stock yet. Choosing
      // Warehouse in that state makes a valid arrangement impossible because
      // every non-unavailable line must reserve a real item. Default to the
      // explicit external-supplier route instead; Procurement still has to
      // enter the supplier and the server validates every line.
      source: line.inventoryItemId == null && inventory.isEmpty
          ? YorksV1ArrangementSource.externalSupplier
          : line.source,
      decision: line.decision ?? YorksV1ArrangementDecision.full,
      arrangedQuantity: yorksV1DisplayQuantity(
        line.arrangedQuantity ?? line.requestedQuantity,
      ),
      externalSupplier: line.externalSupplier,
      inventoryItemId:
          line.inventoryItemId ??
          (matchingItem.isEmpty ? null : matchingItem.first.id),
      reason: line.reason,
      unitCost: line.unitCost,
    );
  }

  _EditableArrangementLine copyWith({
    YorksV1ArrangementSource? source,
    YorksV1ArrangementDecision? decision,
    String? arrangedQuantity,
    Object? externalSupplier = _keep,
    Object? inventoryItemId = _keep,
    Object? reason = _keep,
    Object? unitCost = _keep,
  }) => _EditableArrangementLine(
    arrangementLineId: arrangementLineId,
    source: source ?? this.source,
    decision: decision ?? this.decision,
    arrangedQuantity: arrangedQuantity ?? this.arrangedQuantity,
    externalSupplier: identical(externalSupplier, _keep)
        ? this.externalSupplier
        : externalSupplier as String?,
    inventoryItemId: identical(inventoryItemId, _keep)
        ? this.inventoryItemId
        : inventoryItemId as String?,
    reason: identical(reason, _keep) ? this.reason : reason as String?,
    unitCost: identical(unitCost, _keep) ? this.unitCost : unitCost as String?,
  );

  YorksV1ArrangementLineInput toInput() => YorksV1ArrangementLineInput(
    arrangementLineId: arrangementLineId,
    source: source,
    decision: decision,
    arrangedQuantity: arrangedQuantity,
    externalSupplier: externalSupplier,
    inventoryItemId: inventoryItemId,
    reason: reason,
    unitCost: unitCost,
  );
}

const _keep = Object();

Future<String?> _returnReason(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(YorksV1ArrangementStrings.returnToProcurement.primary),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: YorksV1ArrangementStrings.returnReason.primary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.cancel.primary),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(YorksV1ArrangementStrings.returnToProcurement.primary),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

void _showFailure(BuildContext context) =>
    _showMessage(context, YorksV1ArrangementStrings.savingFailed.primary);

void _showMessage(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

class _ActiveText extends StatelessWidget {
  const _ActiveText({
    required this.copy,
    required this.language,
    this.style,
    this.center = false,
    this.maxLines,
    this.overflow,
  });

  final TranslatableString copy;
  final AppLanguage language;
  final TextStyle? style;
  final bool center;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => Text(
    copy.active(language),
    textAlign: center ? TextAlign.center : null,
    textDirection: language.isRtl ? TextDirection.rtl : TextDirection.ltr,
    style: style,
    maxLines: maxLines,
    overflow: overflow,
  );
}
