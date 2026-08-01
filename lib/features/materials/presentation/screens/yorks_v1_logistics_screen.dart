import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_logistics.dart';
import '../../../../shared/models/yorks_v1_logistics_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_logistics_provider.dart';
import '../../../../shared/providers/yorks_v1_logistics_repository_provider.dart';
import '../../../../shared/providers/yorks_v1_material_request_provider.dart';

/// Role-aware request logistics. Server-derived action flags distinguish the
/// Procurement dispatch form from Project/Site Engineer receipt review.
class YorksV1LogisticsScreen extends ConsumerWidget {
  const YorksV1LogisticsScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final workspace = ref.watch(yorksV1LogisticsWorkspaceProvider(requestId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: _BilingualText(
          copy: YorksV1LogisticsStrings.dispatchAndReceipt,
          language: language,
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: YorksV1LogisticsStrings.dispatchAndReceipt.primary,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _refresh(ref),
          ),
        ],
      ),
      body: workspace.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _LogisticsError(onRetry: () => _refresh(ref)),
        data: (value) => _LogisticsBody(
          workspace: value,
          language: language,
          onChanged: () => _refresh(ref),
        ),
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(yorksV1LogisticsWorkspaceProvider(requestId));
    ref.invalidate(yorksV1MaterialRequestDetailProvider(requestId));
  }
}

class _LogisticsBody extends StatelessWidget {
  const _LogisticsBody({
    required this.workspace,
    required this.language,
    required this.onChanged,
  });

  final YorksV1LogisticsWorkspace workspace;
  final AppLanguage language;
  final VoidCallback onChanged;

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
                    ? _BilingualText(
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
  final _driver = TextEditingController();
  final _vehicle = TextEditingController();
  final Map<String, TextEditingController> _quantities = {};
  DateTime _dispatchDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
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
      _quantities.putIfAbsent(
        candidate.requestLineId,
        TextEditingController.new,
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
              driverName: _driver.text,
              vehicleReference: _vehicle.text,
              lines: lines,
              idempotencyKey: const Uuid().v4(),
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
            value: candidate.approvedQuantity,
            unit: candidate.unit,
          ),
        ),
        Expanded(
          child: _Quantity(
            value: candidate.goodReceivedQuantity,
            unit: candidate.unit,
          ),
        ),
        Expanded(
          child: _Quantity(
            value: candidate.inTransitQuantity,
            unit: candidate.unit,
          ),
        ),
        Expanded(
          child: _Quantity(
            value: candidate.stillNeededQuantity,
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
              value: candidate.approvedQuantity,
            ),
            _Fact(
              label: YorksV1LogisticsStrings.goodReceived.primary,
              value: candidate.goodReceivedQuantity,
            ),
            _Fact(
              label: YorksV1LogisticsStrings.inTransit.primary,
              value: candidate.inTransitQuantity,
            ),
            _Fact(
              label: YorksV1LogisticsStrings.stillNeeded.primary,
              value: candidate.stillNeededQuantity,
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _ReceiptReviewSheet(
        workspace: workspace,
        dispatch: dispatch,
        onChanged: onChanged,
      ),
    );
  }
}

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
        text: line.dispatchedQuantity,
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
  Widget build(BuildContext context) => SafeArea(
    child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      maxChildSize: .96,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
          top: AppSpacing.lg,
        ),
        child: ListView(
          controller: scrollController,
          children: [
            Text(
              YorksV1LogisticsStrings.receiptReview.primary,
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(widget.dispatch.number, style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            for (final line in widget.dispatch.lines)
              _ReceiptLineEditor(
                line: line,
                outcome: _outcomes[line.id]!,
                goodQuantity: _goodQuantities[line.id]!,
                note: _notes[line.id]!,
                onOutcomeChanged: (outcome) => setState(() {
                  _outcomes[line.id] = outcome;
                  if (outcome == YorksV1ReceiptOutcome.received) {
                    _goodQuantities[line.id]!.text = line.dispatchedQuantity;
                    _notes[line.id]!.clear();
                  } else if (_goodQuantities[line.id]!.text ==
                      line.dispatchedQuantity) {
                    _goodQuantities[line.id]!.text = '0';
                  }
                }),
              ),
            CheckboxListTile(
              value: _allReviewed,
              contentPadding: EdgeInsets.zero,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _allReviewed = value ?? false),
              title: Text(YorksV1LogisticsStrings.allLinesReviewed.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: YorksV1LogisticsStrings.confirmReceipt.primary,
              icon: Icons.verified_outlined,
              isLoading: _saving,
              onPressed: _allReviewed && !_saving ? _confirm : null,
            ),
          ],
        ),
      ),
    ),
  );

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
      Navigator.of(context).pop();
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
    required this.line,
    required this.outcome,
    required this.goodQuantity,
    required this.note,
    required this.onOutcomeChanged,
  });

  final YorksV1DispatchLine line;
  final YorksV1ReceiptOutcome outcome;
  final TextEditingController goodQuantity;
  final TextEditingController note;
  final ValueChanged<YorksV1ReceiptOutcome> onOutcomeChanged;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(line.description, style: AppTypography.titleSmall),
        Text(
          '${line.dispatchedQuantity} ${line.unit}',
          style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<YorksV1ReceiptOutcome>(
          initialValue: outcome,
          decoration: InputDecoration(
            labelText: YorksV1LogisticsStrings.outcome.primary,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final option in YorksV1ReceiptOutcome.values)
              DropdownMenuItem(
                value: option,
                child: Text(yorksV1ReceiptOutcomeCopy(option).primary),
              ),
          ],
          onChanged: (value) {
            if (value != null) onOutcomeChanged(value);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _QuantityInput(
          controller: goodQuantity,
          label: YorksV1LogisticsStrings.goodQuantity.primary,
        ),
        if (outcome != YorksV1ReceiptOutcome.received) ...[
          const SizedBox(height: AppSpacing.md),
          _TextInput(
            controller: note,
            label: YorksV1LogisticsStrings.note.primary,
          ),
        ],
      ],
    ),
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
        Text('${line.dispatchedQuantity} ${line.unit}'),
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
  const _QuantityInput({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );
}

class _TextInput extends StatelessWidget {
  const _TextInput({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
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

class _BilingualText extends StatelessWidget {
  const _BilingualText({
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      Text(
        copy.primary,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: style,
      ),
      const SizedBox(height: AppSpacing.xxs),
      Text(
        copy.secondary(language),
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
      ),
    ],
  );
}

double _number(String text) => double.tryParse(text) ?? 0;

String _dateLabel(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
