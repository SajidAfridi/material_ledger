import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_logistics.dart';
import '../../../../shared/models/yorks_v1_logistics_strings.dart';
import '../../../../shared/models/yorks_v1_quantity.dart';
import '../../../../shared/models/yorks_v1_shell_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_logistics_provider.dart';
import '../../../../shared/providers/yorks_v1_logistics_repository_provider.dart';
import '../../../../shared/providers/yorks_v1_material_request_provider.dart';

/// Role-aware request logistics. Server-derived action flags distinguish the
/// Procurement dispatch form from Project/Site Engineer receipt review.
class YorksV1LogisticsScreen extends ConsumerWidget {
  const YorksV1LogisticsScreen({
    super.key,
    required this.requestId,
    this.focusReceiptReview = false,
    this.focusedDispatchId,
  });

  final String requestId;

  /// Opens the supplied dispatched delivery in the R35 receipt-review dialog.
  /// This lets the Material Request remain the primary workflow surface while
  /// still using the protected logistics command for the receipt commit.
  final bool focusReceiptReview;
  final String? focusedDispatchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final workspace = ref.watch(yorksV1LogisticsWorkspaceProvider(requestId));
    final compactRoute =
        MediaQuery.sizeOf(context).width < AppSpacing.yorksV1DesktopBreakpoint;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: compactRoute
          ? AppBar(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              title: _ActiveText(
                copy: YorksV1LogisticsStrings.dispatchAndReceipt,
                language: language,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: YorksV1LogisticsStrings.refresh.primary,
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => _refresh(ref),
                ),
              ],
            )
          : null,
      body: workspace.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _LogisticsError(onRetry: () => _refresh(ref)),
        data: (value) => _FocusedLogisticsBody(
          workspace: value,
          language: language,
          onChanged: () => _refresh(ref),
          showPageHeader: !compactRoute,
          focusReceiptReview: focusReceiptReview,
          focusedDispatchId: focusedDispatchId,
        ),
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(yorksV1LogisticsWorkspaceProvider(requestId));
    ref.invalidate(yorksV1MaterialRequestDetailProvider(requestId));
  }
}

class _FocusedLogisticsBody extends StatefulWidget {
  const _FocusedLogisticsBody({
    required this.workspace,
    required this.language,
    required this.onChanged,
    required this.showPageHeader,
    required this.focusReceiptReview,
    required this.focusedDispatchId,
  });

  final YorksV1LogisticsWorkspace workspace;
  final AppLanguage language;
  final VoidCallback onChanged;
  final bool showPageHeader;
  final bool focusReceiptReview;
  final String? focusedDispatchId;

  @override
  State<_FocusedLogisticsBody> createState() => _FocusedLogisticsBodyState();
}

class _FocusedLogisticsBodyState extends State<_FocusedLogisticsBody> {
  bool _focusHandled = false;

  @override
  void initState() {
    super.initState();
    _scheduleFocusedReceiptReview();
  }

  @override
  void didUpdateWidget(covariant _FocusedLogisticsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusReceiptReview != widget.focusReceiptReview ||
        oldWidget.focusedDispatchId != widget.focusedDispatchId) {
      _focusHandled = false;
    }
    _scheduleFocusedReceiptReview();
  }

  void _scheduleFocusedReceiptReview() {
    if (!widget.focusReceiptReview || _focusHandled) return;
    _focusHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      YorksV1MaterialDispatch? target;
      for (final dispatch in widget.workspace.dispatches) {
        if (widget.focusedDispatchId == dispatch.id) {
          target = dispatch;
          break;
        }
      }
      if (target == null || !target.canConfirmReceipt) {
        for (final dispatch in widget.workspace.dispatches) {
          if (dispatch.canConfirmReceipt) {
            target = dispatch;
            break;
          }
        }
      }
      if (target == null || !target.canConfirmReceipt) return;
      final confirmed = await showYorksV1ReceiptReviewDialog(
        context,
        workspace: widget.workspace,
        dispatch: target,
        onChanged: widget.onChanged,
      );
      if (confirmed == true && mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  Widget build(BuildContext context) => _LogisticsBody(
    workspace: widget.workspace,
    language: widget.language,
    onChanged: widget.onChanged,
    showPageHeader: widget.showPageHeader,
  );
}

class _LogisticsBody extends StatelessWidget {
  const _LogisticsBody({
    required this.workspace,
    required this.language,
    required this.onChanged,
    required this.showPageHeader,
  });

  final YorksV1LogisticsWorkspace workspace;
  final AppLanguage language;
  final VoidCallback onChanged;
  final bool showPageHeader;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.pageMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showPageHeader) ...[
                YorksR35PageHeader(
                  eyebrow: YorksV1ShellStrings.operationalWorkspace.primary,
                  title: YorksV1LogisticsStrings.dispatchAndReceipt.primary,
                  description: YorksV1LogisticsStrings.dispatchHistory.primary,
                  actions: [
                    SizedBox(
                      height: AppSpacing.controlHeight,
                      child: OutlinedButton.icon(
                        onPressed: onChanged,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(YorksV1LogisticsStrings.refresh.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              _WorkspaceHeader(workspace: workspace),
              const SizedBox(height: AppSpacing.lg),
              if (workspace.canDispatch) ...[
                NexusSectionCard(
                  title: YorksV1LogisticsStrings.dispatchNow.primary,
                  child: _DispatchEditor(
                    workspace: workspace,
                    onChanged: onChanged,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              NexusSectionCard(
                title: YorksV1LogisticsStrings.dispatchHistory.primary,
                child: workspace.dispatches.isEmpty
                    ? _ActiveText(
                        copy: YorksV1LogisticsStrings.noDispatch,
                        language: language,
                        center: true,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.muted,
                        ),
                      )
                    : Column(
                        children: [
                          for (final dispatch in workspace.dispatches)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: _DispatchCard(
                                dispatch: dispatch,
                                workspace: workspace,
                                onChanged: onChanged,
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.workspace});
  final YorksV1LogisticsWorkspace workspace;

  @override
  Widget build(BuildContext context) => NexusSectionCard(
    child: Wrap(
      spacing: AppSpacing.xxl,
      runSpacing: AppSpacing.md,
      children: [
        _Fact(
          label: YorksV1LogisticsStrings.dispatchAndReceipt.primary,
          value: workspace.requestNumber ?? '',
        ),
        _Fact(
          label: YorksV1LogisticsStrings.project.primary,
          value: workspace.projectName,
        ),
        _Fact(
          label: YorksV1LogisticsStrings.scope.primary,
          value: workspace.scopeName,
        ),
      ],
    ),
  );
}

class _DispatchEditor extends ConsumerStatefulWidget {
  const _DispatchEditor({required this.workspace, required this.onChanged});

  final YorksV1LogisticsWorkspace workspace;
  final VoidCallback onChanged;

  @override
  ConsumerState<_DispatchEditor> createState() => _DispatchEditorState();
}

class _DispatchEditorState extends ConsumerState<_DispatchEditor> {
  final _deliveryReference = TextEditingController();
  final _driver = TextEditingController();
  final _vehicle = TextEditingController();
  final Map<String, TextEditingController> _quantities = {};
  late final String _commandIdempotencyKey;
  DateTime _dispatchDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _commandIdempotencyKey = const Uuid().v4();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _DispatchEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.requestRecordVersion !=
        widget.workspace.requestRecordVersion) {
      _syncControllers();
    }
  }

  @override
  void dispose() {
    _deliveryReference.dispose();
    _driver.dispose();
    _vehicle.dispose();
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncControllers() {
    final ids = widget.workspace.dispatchCandidates
        .map((candidate) => candidate.requestLineId)
        .toSet();
    for (final entry in Map<String, TextEditingController>.from(
      _quantities,
    ).entries) {
      if (!ids.contains(entry.key)) {
        entry.value.dispose();
        _quantities.remove(entry.key);
      }
    }
    for (final candidate in widget.workspace.dispatchCandidates) {
      if (_quantities.containsKey(candidate.requestLineId)) continue;
      // An approved request already has an outstanding quantity.  Seed the
      // editor with the dispatchable amount so Procurement can dispatch the
      // approved line immediately, while still allowing a partial dispatch.
      // For warehouse lines, never suggest more than what is currently
      // available at the warehouse; the server remains the final authority.
      var suggested = _number(candidate.stillNeededQuantity);
      final available = _number(candidate.warehouseAvailableQuantity ?? '');
      if (candidate.source == YorksV1LogisticsSource.warehouse) {
        suggested = available > 0 && suggested > 0
            ? (suggested < available ? suggested : available)
            : 0;
      }
      _quantities[candidate.requestLineId] = TextEditingController(
        text: suggested > 0 ? _quantityText(suggested) : '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.workspace.dispatchCandidates
        .where((candidate) => _number(candidate.stillNeededQuantity) > 0)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            SizedBox(
              width: 240,
              child: _TextInput(
                controller: _deliveryReference,
                label: YorksV1LogisticsStrings.deliveryReference.primary,
              ),
            ),
            SizedBox(
              width: 220,
              child: SecondaryButton(
                label: _dateLabel(_dispatchDate),
                isExpanded: false,
                icon: Icons.calendar_today_outlined,
                onPressed: _saving ? null : _pickDate,
              ),
            ),
            SizedBox(
              width: 240,
              child: _TextInput(
                controller: _driver,
                label: YorksV1LogisticsStrings.driver.primary,
              ),
            ),
            SizedBox(
              width: 240,
              child: _TextInput(
                controller: _vehicle,
                label: YorksV1LogisticsStrings.vehicle.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (candidates.isEmpty)
          Text(
            YorksV1LogisticsStrings.noDispatch.primary,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
          )
        else
          _DispatchCandidateList(
            candidates: candidates,
            controllers: _quantities,
          ),
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: Alignment.centerRight,
          child: PrimaryButton(
            label: YorksV1LogisticsStrings.dispatchNow.primary,
            icon: Icons.local_shipping_outlined,
            isExpanded: false,
            isLoading: _saving,
            onPressed: candidates.isEmpty || _saving ? null : _dispatch,
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dispatchDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) setState(() => _dispatchDate = selected);
  }

  Future<void> _dispatch() async {
    if (_deliveryReference.text.trim().isEmpty) {
      _showError(YorksV1LogisticsStrings.deliveryReferenceRequired.primary);
      return;
    }
    final lines = <YorksV1DispatchLineInput>[];
    for (final candidate in widget.workspace.dispatchCandidates) {
      final quantity = _quantities[candidate.requestLineId]?.text.trim() ?? '';
      if (_number(quantity) > 0) {
        if (_number(quantity) > _number(candidate.stillNeededQuantity)) {
          _showError(YorksV1LogisticsStrings.invalidDispatch.primary);
          return;
        }
        lines.add(
          YorksV1DispatchLineInput(
            requestLineId: candidate.requestLineId,
            dispatchQuantity: quantity,
          ),
        );
      }
    }
    if (lines.isEmpty) {
      _showError(YorksV1LogisticsStrings.invalidDispatch.primary);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(yorksV1LogisticsRepositoryProvider)
          .dispatch(
            YorksV1DispatchInput(
              requestId: widget.workspace.requestId,
              expectedRequestVersion: widget.workspace.requestRecordVersion,
              dispatchDate: _dispatchDate,
              deliveryReference: _deliveryReference.text,
              driverName: _driver.text,
              vehicleReference: _vehicle.text,
              lines: lines,
              idempotencyKey: _commandIdempotencyKey,
            ),
          );
      if (!mounted) return;
      widget.onChanged();
      for (final controller in _quantities.values) {
        controller.clear();
      }
    } catch (_) {
      if (mounted) _showError(YorksV1LogisticsStrings.savingFailed.primary);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _DispatchCandidateList extends StatelessWidget {
  const _DispatchCandidateList({
    required this.candidates,
    required this.controllers,
  });

  final List<YorksV1DispatchCandidate> candidates;
  final Map<String, TextEditingController> controllers;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= AppSpacing.yorksV1DesktopBreakpoint) {
        return Column(
          children: [
            const _DispatchCandidateHeader(),
            const Divider(height: 1),
            for (final candidate in candidates)
              _DispatchCandidateDesktopRow(
                candidate: candidate,
                controller: controllers[candidate.requestLineId]!,
              ),
          ],
        );
      }
      return Column(
        children: [
          for (final candidate in candidates)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _DispatchCandidateMobileCard(
                candidate: candidate,
                controller: controllers[candidate.requestLineId]!,
              ),
            ),
        ],
      );
    },
  );
}

class _DispatchCandidateHeader extends StatelessWidget {
  const _DispatchCandidateHeader();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Row(
      children: [
        Expanded(
          flex: 4,
          child: _ColumnLabel(YorksV1LogisticsStrings.itemDescription),
        ),
        Expanded(child: _ColumnLabel(YorksV1LogisticsStrings.approved)),
        Expanded(child: _ColumnLabel(YorksV1LogisticsStrings.goodReceived)),
        Expanded(child: _ColumnLabel(YorksV1LogisticsStrings.inTransit)),
        Expanded(child: _ColumnLabel(YorksV1LogisticsStrings.stillNeeded)),
        Expanded(
          flex: 2,
          child: _ColumnLabel(YorksV1LogisticsStrings.dispatchQuantity),
        ),
      ],
    ),
  );
}

class _DispatchCandidateDesktopRow extends StatelessWidget {
  const _DispatchCandidateDesktopRow({
    required this.candidate,
    required this.controller,
  });

  final YorksV1DispatchCandidate candidate;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Row(
      children: [
        Expanded(flex: 4, child: _CandidateName(candidate: candidate)),
        Expanded(
          child: _Quantity(
            value: _displayQuantity(candidate.approvedQuantity),
            unit: candidate.unit,
          ),
        ),
        Expanded(
          child: _Quantity(
            value: _displayQuantity(candidate.goodReceivedQuantity),
            unit: candidate.unit,
          ),
        ),
        Expanded(
          child: _Quantity(
            value: _displayQuantity(candidate.inTransitQuantity),
            unit: candidate.unit,
          ),
        ),
        Expanded(
          child: _Quantity(
            value: _displayQuantity(candidate.stillNeededQuantity),
            unit: candidate.unit,
          ),
        ),
        Expanded(
          flex: 2,
          child: _QuantityInput(
            controller: controller,
            label: YorksV1LogisticsStrings.dispatchQuantity.primary,
          ),
        ),
      ],
    ),
  );
}

class _DispatchCandidateMobileCard extends StatelessWidget {
  const _DispatchCandidateMobileCard({
    required this.candidate,
    required this.controller,
  });

  final YorksV1DispatchCandidate candidate;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CandidateName(candidate: candidate),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.md,
          children: [
            _Fact(
              label: YorksV1LogisticsStrings.approved.primary,
              value: _displayQuantity(candidate.approvedQuantity),
            ),
            _Fact(
              label: YorksV1LogisticsStrings.goodReceived.primary,
              value: _displayQuantity(candidate.goodReceivedQuantity),
            ),
            _Fact(
              label: YorksV1LogisticsStrings.inTransit.primary,
              value: _displayQuantity(candidate.inTransitQuantity),
            ),
            _Fact(
              label: YorksV1LogisticsStrings.stillNeeded.primary,
              value: _displayQuantity(candidate.stillNeededQuantity),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _QuantityInput(
          controller: controller,
          label: YorksV1LogisticsStrings.dispatchQuantity.primary,
        ),
      ],
    ),
  );
}

class _DispatchCard extends StatelessWidget {
  const _DispatchCard({
    required this.dispatch,
    required this.workspace,
    required this.onChanged,
  });

  final YorksV1MaterialDispatch dispatch;
  final YorksV1LogisticsWorkspace workspace;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(dispatch.number, style: AppTypography.titleSmall),
            _StateChip(state: dispatch.state),
            Text(
              _dateLabel(dispatch.dispatchDate),
              style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
            ),
          ],
        ),
        if (dispatch.driverName != null ||
            dispatch.vehicleReference != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              dispatch.driverName,
              dispatch.vehicleReference,
            ].whereType<String>().join(' · '),
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        for (final line in dispatch.lines) _DispatchLineRow(line: line),
        if (dispatch.receiptReview != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            dispatch.receiptReview!.reviewedByDisplayName,
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
        ],
        if (dispatch.canConfirmReceipt) ...[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: SecondaryButton(
              label: YorksV1LogisticsStrings.receiptReview.primary,
              isExpanded: false,
              icon: Icons.fact_check_outlined,
              onPressed: () => _openReceiptReview(context),
            ),
          ),
        ],
      ],
    ),
  );

  Future<void> _openReceiptReview(BuildContext context) async {
    await showYorksV1ReceiptReviewDialog(
      context,
      workspace: workspace,
      dispatch: dispatch,
      onChanged: onChanged,
    );
  }
}

/// Opens the same protected receipt-review command from either the focused
/// logistics route or the Material Request record. Keeping one dialog avoids
/// route changes and guarantees both entry points validate identical inputs.
Future<bool?> showYorksV1ReceiptReviewDialog(
  BuildContext context, {
  required YorksV1LogisticsWorkspace workspace,
  required YorksV1MaterialDispatch dispatch,
  required VoidCallback onChanged,
}) => showDialog<bool>(
  context: context,
  animationStyle: AnimationStyle.noAnimation,
  barrierDismissible: false,
  builder: (_) => _ReceiptReviewSheet(
    workspace: workspace,
    dispatch: dispatch,
    onChanged: onChanged,
  ),
);

class _ReceiptReviewSheet extends ConsumerStatefulWidget {
  const _ReceiptReviewSheet({
    required this.workspace,
    required this.dispatch,
    required this.onChanged,
  });

  final YorksV1LogisticsWorkspace workspace;
  final YorksV1MaterialDispatch dispatch;
  final VoidCallback onChanged;

  @override
  ConsumerState<_ReceiptReviewSheet> createState() =>
      _ReceiptReviewSheetState();
}

class _ReceiptReviewSheetState extends ConsumerState<_ReceiptReviewSheet> {
  final Map<String, YorksV1ReceiptOutcome> _outcomes = {};
  final Map<String, TextEditingController> _goodQuantities = {};
  final Map<String, TextEditingController> _notes = {};
  bool _allReviewed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final line in widget.dispatch.lines) {
      _outcomes[line.id] = YorksV1ReceiptOutcome.received;
      _goodQuantities[line.id] = TextEditingController(
        text: _displayQuantity(line.dispatchedQuantity),
      );
      _notes[line.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _goodQuantities.values) {
      controller.dispose();
    }
    for (final controller in _notes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final isCompact = screen.width < AppSpacing.yorksV1DesktopBreakpoint;
    return Dialog(
      insetPadding: EdgeInsets.all(isCompact ? AppSpacing.sm : AppSpacing.xxl),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1320,
          maxHeight: screen.height * .92,
          minWidth: isCompact ? 0 : 760,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReceiptReviewHeader(
              dispatchNumber: widget.dispatch.number,
              onClose: _saving ? null : () => Navigator.of(context).pop(),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ReceiptDispatchBanner(dispatch: widget.dispatch),
                    const SizedBox(height: AppSpacing.lg),
                    for (
                      var index = 0;
                      index < widget.dispatch.lines.length;
                      index++
                    )
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _ReceiptLineEditor(
                          lineNumber: index + 1,
                          line: widget.dispatch.lines[index],
                          outcome: _outcomes[widget.dispatch.lines[index].id]!,
                          goodQuantity:
                              _goodQuantities[widget.dispatch.lines[index].id]!,
                          note: _notes[widget.dispatch.lines[index].id]!,
                          isDisabled: _saving,
                          onOutcomeChanged: (outcome) => setState(() {
                            final line = widget.dispatch.lines[index];
                            _outcomes[line.id] = outcome;
                            if (outcome == YorksV1ReceiptOutcome.received) {
                              _goodQuantities[line.id]!.text = _displayQuantity(
                                line.dispatchedQuantity,
                              );
                            } else if (_goodQuantities[line.id]!.text ==
                                _displayQuantity(line.dispatchedQuantity)) {
                              _goodQuantities[line.id]!.text = '0';
                            }
                          }),
                        ),
                      ),
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
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: [
                    SizedBox(
                      width: isCompact
                          ? screen.width -
                                (AppSpacing.sm * 2) -
                                (AppSpacing.lg * 2)
                          : 360,
                      child: CheckboxListTile(
                        value: _allReviewed,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  setState(() => _allReviewed = value ?? false),
                        title: Text(
                          YorksV1LogisticsStrings.allLinesReviewed.primary,
                        ),
                      ),
                    ),
                    SecondaryButton(
                      label: MaterialLocalizations.of(
                        context,
                      ).cancelButtonLabel,
                      isExpanded: false,
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                    PrimaryButton(
                      label: YorksV1LogisticsStrings.saveReceiptReview.primary,
                      icon: Icons.verified_outlined,
                      isExpanded: false,
                      isLoading: _saving,
                      onPressed: _allReviewed && !_saving ? _confirm : null,
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

  Future<void> _confirm() async {
    final lines = <YorksV1ReceiptLineInput>[];
    for (final line in widget.dispatch.lines) {
      final outcome = _outcomes[line.id]!;
      final good = _goodQuantities[line.id]!.text.trim();
      final note = _notes[line.id]!.text.trim();
      final dispatched = _number(line.dispatchedQuantity);
      if (_number(good) < 0 ||
          (outcome == YorksV1ReceiptOutcome.received &&
              _number(good) != dispatched) ||
          (outcome != YorksV1ReceiptOutcome.received &&
              (_number(good) >= dispatched || note.isEmpty))) {
        _showFailure(YorksV1LogisticsStrings.invalidReceipt.primary);
        return;
      }
      lines.add(
        YorksV1ReceiptLineInput(
          dispatchLineId: line.id,
          outcome: outcome,
          goodQuantity: good,
          note: note,
        ),
      );
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(yorksV1LogisticsRepositoryProvider)
          .confirmReceipt(
            YorksV1ReceiptConfirmationInput(
              requestId: widget.workspace.requestId,
              dispatchId: widget.dispatch.id,
              expectedRequestVersion: widget.workspace.requestRecordVersion,
              expectedDispatchVersion: widget.dispatch.recordVersion,
              lines: lines,
              idempotencyKey: const Uuid().v4(),
            ),
          );
      if (!mounted) return;
      widget.onChanged();
      Navigator.of(context).pop(true);
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

class _ReceiptLineEditor extends StatelessWidget {
  const _ReceiptLineEditor({
    required this.lineNumber,
    required this.line,
    required this.outcome,
    required this.goodQuantity,
    required this.note,
    required this.isDisabled,
    required this.onOutcomeChanged,
  });

  final int lineNumber;
  final YorksV1DispatchLine line;
  final YorksV1ReceiptOutcome outcome;
  final TextEditingController goodQuantity;
  final TextEditingController note;
  final bool isDisabled;
  final ValueChanged<YorksV1ReceiptOutcome> onOutcomeChanged;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1180;
        final identity = _ReceiptLineIdentity(
          lineNumber: lineNumber,
          line: line,
        );
        final decisions = _ReceiptOutcomeChoices(
          selected: outcome,
          disabled: isDisabled,
          onChanged: onOutcomeChanged,
        );
        final inputs = _ReceiptLineInputs(
          outcome: outcome,
          goodQuantity: goodQuantity,
          note: note,
          disabled: isDisabled,
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 5, child: identity),
              const SizedBox(width: AppSpacing.md),
              SizedBox(width: 360, child: decisions),
              const SizedBox(width: AppSpacing.md),
              SizedBox(width: 360, child: inputs),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            identity,
            const SizedBox(height: AppSpacing.md),
            decisions,
            const SizedBox(height: AppSpacing.md),
            inputs,
          ],
        );
      },
    ),
  );
}

class _ReceiptReviewHeader extends StatelessWidget {
  const _ReceiptReviewHeader({
    required this.dispatchNumber,
    required this.onClose,
  });

  final String dispatchNumber;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Padding(
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
                YorksV1LogisticsStrings.reviewDeliveredMaterials.primary,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '$dispatchNumber · ${YorksV1LogisticsStrings.reviewDeliveryLineByLine.primary}',
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

class _ReceiptDispatchBanner extends StatelessWidget {
  const _ReceiptDispatchBanner({required this.dispatch});

  final YorksV1MaterialDispatch dispatch;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.blueContainer,
      border: Border.all(color: AppColors.primary.withValues(alpha: .24)),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: AppSpacing.xxs),
          child: Icon(Icons.local_shipping_outlined, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dispatch.deliveryReference ?? dispatch.number,
                style: AppTypography.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${_dateLabel(dispatch.dispatchDate)} · ${dispatch.dispatchedByDisplayName}',
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReceiptLineIdentity extends StatelessWidget {
  const _ReceiptLineIdentity({required this.lineNumber, required this.line});

  final int lineNumber;
  final YorksV1DispatchLine line;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$lineNumber. ${line.description}', style: AppTypography.titleSmall),
      const SizedBox(height: AppSpacing.xxs),
      Text(
        '${_displayQuantity(line.dispatchedQuantity)} ${line.unit} ${YorksV1LogisticsStrings.dispatched.primary}',
        style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
      ),
    ],
  );
}

class _ReceiptOutcomeChoices extends StatelessWidget {
  const _ReceiptOutcomeChoices({
    required this.selected,
    required this.disabled,
    required this.onChanged,
  });

  final YorksV1ReceiptOutcome selected;
  final bool disabled;
  final ValueChanged<YorksV1ReceiptOutcome> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      for (final option in YorksV1ReceiptOutcome.values)
        _ReceiptOutcomeButton(
          outcome: option,
          selected: selected == option,
          onPressed: disabled ? null : () => onChanged(option),
        ),
    ],
  );
}

class _ReceiptOutcomeButton extends StatelessWidget {
  const _ReceiptOutcomeButton({
    required this.outcome,
    required this.selected,
    required this.onPressed,
  });

  final YorksV1ReceiptOutcome outcome;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(
      outcome == YorksV1ReceiptOutcome.received
          ? Icons.check_rounded
          : outcome == YorksV1ReceiptOutcome.missing
          ? Icons.remove_circle_outline_rounded
          : Icons.warning_amber_rounded,
      size: 18,
    ),
    label: Text(yorksV1ReceiptOutcomeCopy(outcome).primary),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, AppSpacing.minTapTarget),
      foregroundColor: selected ? AppColors.primary : AppColors.onSurface,
      backgroundColor: selected ? AppColors.blueContainer : null,
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.line,
        width: selected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
    ),
  );
}

class _ReceiptLineInputs extends StatelessWidget {
  const _ReceiptLineInputs({
    required this.outcome,
    required this.goodQuantity,
    required this.note,
    required this.disabled,
  });

  final YorksV1ReceiptOutcome outcome;
  final TextEditingController goodQuantity;
  final TextEditingController note;
  final bool disabled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final fields = [
        SizedBox(
          width: constraints.maxWidth >= 330 ? 150 : double.infinity,
          child: _QuantityInput(
            controller: goodQuantity,
            label: YorksV1LogisticsStrings.goodQuantity.primary,
            enabled: !disabled && outcome != YorksV1ReceiptOutcome.received,
          ),
        ),
        SizedBox(
          width: constraints.maxWidth >= 330 ? 196 : double.infinity,
          child: _TextInput(
            controller: note,
            label: YorksV1LogisticsStrings.exceptionNote.primary,
            enabled: !disabled,
          ),
        ),
      ];
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: fields,
      );
    },
  );
}

class _DispatchLineRow extends StatelessWidget {
  const _DispatchLineRow({required this.line});
  final YorksV1DispatchLine line;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Row(
      children: [
        Expanded(
          child: Text(line.description, style: AppTypography.bodyMedium),
        ),
        Text('${_displayQuantity(line.dispatchedQuantity)} ${line.unit}'),
        if (line.receiptOutcome != null) ...[
          const SizedBox(width: AppSpacing.md),
          Text(
            yorksV1ReceiptOutcomeCopy(line.receiptOutcome!).primary,
            style: AppTypography.labelMedium.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    ),
  );
}

class _CandidateName extends StatelessWidget {
  const _CandidateName({required this.candidate});
  final YorksV1DispatchCandidate candidate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(candidate.description, style: AppTypography.bodyMedium),
      const SizedBox(height: AppSpacing.xxs),
      Text(
        [
          candidate.brandOrigin,
          yorksV1LogisticsSourceCopy(candidate.source).primary,
          candidate.externalSupplier,
        ].whereType<String>().join(' · '),
        style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
      ),
    ],
  );
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});
  final YorksV1DispatchState state;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: state == YorksV1DispatchState.received
          ? AppColors.successContainer
          : AppColors.blueContainer,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
    ),
    child: Text(
      yorksV1DispatchStateCopy(state).primary,
      style: AppTypography.labelSmall,
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
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

class _ColumnLabel extends StatelessWidget {
  const _ColumnLabel(this.copy);
  final TranslatableString copy;

  @override
  Widget build(BuildContext context) => Text(
    copy.primary,
    style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
  );
}

class _Quantity extends StatelessWidget {
  const _Quantity({required this.value, required this.unit});
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => Text('$value $unit');
}

class _QuantityInput extends StatelessWidget {
  const _QuantityInput({
    required this.controller,
    required this.label,
    this.enabled = true,
  });
  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    this.enabled = true,
  });
  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );
}

class _LogisticsError extends StatelessWidget {
  const _LogisticsError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SecondaryButton(
      label: YorksV1LogisticsStrings.savingFailed.primary,
      icon: Icons.refresh_rounded,
      onPressed: onRetry,
    ),
  );
}

class _ActiveText extends StatelessWidget {
  const _ActiveText({
    required this.copy,
    required this.language,
    required this.style,
    this.center = false,
  });

  final TranslatableString copy;
  final AppLanguage language;
  final TextStyle style;
  final bool center;

  @override
  Widget build(BuildContext context) => Text(
    copy.active(language),
    textAlign: center ? TextAlign.center : TextAlign.start,
    textDirection: language.isRtl ? TextDirection.rtl : TextDirection.ltr,
    style: style,
  );
}

double _number(String text) => double.tryParse(text) ?? 0;

String _quantityText(double value) => value == value.truncateToDouble()
    ? value.toInt().toString()
    : value.toString();

String _displayQuantity(String raw) => yorksV1DisplayQuantity(raw);

String _dateLabel(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
