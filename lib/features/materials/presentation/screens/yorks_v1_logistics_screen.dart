import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_document.dart';
import '../../../../shared/models/yorks_v1_domain_error.dart';
import '../../../../shared/models/yorks_v1_logistics.dart';
import '../../../../shared/models/yorks_v1_logistics_strings.dart';
import '../../../../shared/models/yorks_v1_material_request_strings.dart';
import '../../../../shared/models/yorks_v1_quantity.dart';
import '../../../../shared/models/yorks_v1_shell_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_document_file_service_provider.dart';
import '../../../../shared/providers/yorks_v1_documents_repository_provider.dart';
import '../../../../shared/providers/yorks_v1_logistics_provider.dart';
import '../../../../shared/providers/yorks_v1_material_request_provider.dart';
import '../../../../shared/providers/yorks_v1_material_workflow_command_provider.dart';

/// Role-aware request logistics. Server-derived action flags distinguish the
/// Procurement dispatch form from Project/Site Engineer receipt review.
class YorksV1LogisticsScreen extends ConsumerWidget {
  const YorksV1LogisticsScreen({
    super.key,
    required this.requestId,
    this.focusReceiptReview = false,
    this.focusedDispatchId,
    this.initialDispatchDate,
  });

  final String requestId;

  /// Opens the supplied dispatched delivery in the R35 receipt-review dialog.
  /// This lets the Material Request remain the primary workflow surface while
  /// still using the protected logistics command for the receipt commit.
  final bool focusReceiptReview;
  final String? focusedDispatchId;

  /// Allows a caller restoring a partially prepared dispatch to retain the
  /// intended date. Normal workflow starts with today's date.
  final DateTime? initialDispatchDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final workspace = ref.watch(yorksV1LogisticsWorkspaceProvider(requestId));
    final mobile = YorksMobileUi.isActive(context);
    final compactRoute =
        !mobile &&
        MediaQuery.sizeOf(context).width < AppSpacing.yorksV1DesktopBreakpoint;
    final content = workspace.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _LogisticsError(onRetry: () => _refresh(ref)),
      data: (value) => _FocusedLogisticsBody(
        workspace: value,
        language: language,
        onChanged: () => _refresh(ref),
        showPageHeader: !compactRoute && !mobile,
        focusReceiptReview: focusReceiptReview,
        focusedDispatchId: focusedDispatchId,
        initialDispatchDate: initialDispatchDate,
      ),
    );
    if (mobile) {
      return Scaffold(
        backgroundColor: AppColors.mobileSurface,
        body: Column(
          children: [
            YorksMobileAppBar(
              title: workspace.valueOrNull?.canDispatch == true
                  ? YorksV1LogisticsStrings.createDispatch.active(language)
                  : YorksV1LogisticsStrings.dispatchAndReceipt.active(language),
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
      body: content,
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(yorksV1LogisticsWorkspaceProvider(requestId));
    // The request detail remains mounted while Procurement opens this route.
    // A committed dispatch is immediately a Delivery Order candidate, so its
    // role-safe documents projection must be refreshed before the user
    // returns to the detail page. Receipt review is a later, independent
    // workflow fact and is not required for this refresh.
    ref.invalidate(yorksV1ReturnsDocumentsWorkspaceProvider(requestId));
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
    required this.initialDispatchDate,
  });

  final YorksV1LogisticsWorkspace workspace;
  final AppLanguage language;
  final VoidCallback onChanged;
  final bool showPageHeader;
  final bool focusReceiptReview;
  final String? focusedDispatchId;
  final DateTime? initialDispatchDate;

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
        YorksAppToast.show(
          context,
          title: YorksV1MaterialRequestStrings.recordChanged.primary,
          tone: YorksAppToastTone.error,
        );
        return;
      }
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
    initialDispatchDate: widget.initialDispatchDate,
  );
}

class _LogisticsBody extends StatelessWidget {
  const _LogisticsBody({
    required this.workspace,
    required this.language,
    required this.onChanged,
    required this.showPageHeader,
    required this.initialDispatchDate,
  });

  final YorksV1LogisticsWorkspace workspace;
  final AppLanguage language;
  final VoidCallback onChanged;
  final bool showPageHeader;
  final DateTime? initialDispatchDate;

  @override
  Widget build(BuildContext context) {
    if (YorksMobileUi.isActive(context)) {
      if (workspace.canDispatch) {
        return _DispatchEditor(
          workspace: workspace,
          onChanged: onChanged,
          mobileFlow: true,
          initialDispatchDate: initialDispatchDate,
        );
      }
      return _MobileDispatchHistory(workspace: workspace, onChanged: onChanged);
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
                if (showPageHeader) ...[
                  YorksR35PageHeader(
                    eyebrow: YorksV1ShellStrings.operationalWorkspace.primary,
                    title: YorksV1LogisticsStrings.dispatchAndReceipt.primary,
                    description:
                        YorksV1LogisticsStrings.dispatchHistory.primary,
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
                      initialDispatchDate: initialDispatchDate,
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
}

class _MobileDispatchHistory extends StatelessWidget {
  const _MobileDispatchHistory({
    required this.workspace,
    required this.onChanged,
  });

  final YorksV1LogisticsWorkspace workspace;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
    children: [
      YorksMobilePageTitle(
        eyebrow: workspace.requestNumber ?? '',
        title: YorksV1LogisticsStrings.dispatchAndReceipt.primary,
        description: YorksV1LogisticsStrings.dispatchHistory.primary,
      ),
      const SizedBox(height: 16),
      if (workspace.dispatches.isEmpty)
        YorksMobileCard(
          child: Text(
            YorksV1LogisticsStrings.noDispatch.primary,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
          ),
        )
      else
        for (final dispatch in workspace.dispatches) ...[
          _DispatchCard(
            dispatch: dispatch,
            workspace: workspace,
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
        ],
    ],
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
  const _DispatchEditor({
    required this.workspace,
    required this.onChanged,
    this.mobileFlow = false,
    this.initialDispatchDate,
  });

  final YorksV1LogisticsWorkspace workspace;
  final VoidCallback onChanged;
  final bool mobileFlow;
  final DateTime? initialDispatchDate;

  @override
  ConsumerState<_DispatchEditor> createState() => _DispatchEditorState();
}

class _DispatchEditorState extends ConsumerState<_DispatchEditor> {
  final _deliveryReference = TextEditingController();
  final _driver = TextEditingController();
  final _vehicle = TextEditingController();
  final Map<String, TextEditingController> _quantities = {};
  late String _commandIdempotencyKey;
  late DateTime _dispatchDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dispatchDate = widget.initialDispatchDate ?? DateTime.now();
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
      var suggested =
          YorksV1DecimalQuantity.tryParse(candidate.stillNeededQuantity) ??
          YorksV1DecimalQuantity.zero;
      final available =
          YorksV1DecimalQuantity.tryParse(
            candidate.warehouseAvailableQuantity ?? '',
          ) ??
          YorksV1DecimalQuantity.zero;
      if (candidate.source == YorksV1LogisticsSource.warehouse) {
        suggested = available.isPositive && suggested.isPositive
            ? suggested.min(available)
            : YorksV1DecimalQuantity.zero;
      }
      _quantities[candidate.requestLineId] = TextEditingController(
        text: suggested.isPositive ? suggested.canonicalText : '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.workspace.dispatchCandidates
        .where(
          (candidate) =>
              YorksV1DecimalQuantity.tryParse(
                candidate.stillNeededQuantity,
              )?.isPositive ==
              true,
        )
        .toList(growable: false);
    if (widget.mobileFlow) {
      return PopScope(
        canPop: !_saving,
        child: _MobileDispatchEditor(
          workspace: widget.workspace,
          deliveryReference: _deliveryReference,
          driver: _driver,
          vehicle: _vehicle,
          quantities: _quantities,
          dispatchDate: _dispatchDate,
          saving: _saving,
          onDate: _pickDate,
          onChanged: () => setState(() {}),
          onDispatch: _dispatch,
        ),
      );
    }
    return PopScope(
      canPop: !_saving,
      child: Column(
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
      ),
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
      if (quantity.isEmpty) continue;
      final parsedQuantity = YorksV1DecimalQuantity.tryParse(quantity);
      if (parsedQuantity == null) {
        _showError(YorksV1LogisticsStrings.invalidDispatch.primary);
        return;
      }
      if (parsedQuantity.isPositive) {
        final stillNeeded = YorksV1DecimalQuantity.tryParse(
          candidate.stillNeededQuantity,
        );
        if (stillNeeded == null || parsedQuantity.compareTo(stillNeeded) > 0) {
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
      final updated = await ref
          .read(yorksV1MaterialWorkflowCommandControllerProvider)
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
      _commandIdempotencyKey = const Uuid().v4();
      widget.onChanged();
      final confirmedDispatch = updated.dispatches.isEmpty
          ? null
          : updated.dispatches.first;
      YorksAppToast.show(
        context,
        title: YorksV1LogisticsStrings.dispatched.primary,
        message: confirmedDispatch == null
            ? YorksV1LogisticsStrings.receiptReview.primary
            : '${confirmedDispatch.number} · '
                  '${confirmedDispatch.dispatchedByDisplayName} · '
                  '${YorksV1LogisticsStrings.receiptReview.primary}',
        tone: YorksAppToastTone.success,
      );
      for (final controller in _quantities.values) {
        controller.clear();
      }
    } on YorksV1DomainException catch (error) {
      if (mounted) {
        _showError(
          YorksV1MaterialRequestStrings.commandFailure(error.code).primary,
        );
      }
    } catch (_) {
      if (mounted) _showError(YorksV1LogisticsStrings.savingFailed.primary);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String text) =>
      YorksAppToast.show(context, title: text, tone: YorksAppToastTone.error);
}

class _MobileDispatchEditor extends StatelessWidget {
  const _MobileDispatchEditor({
    required this.workspace,
    required this.deliveryReference,
    required this.driver,
    required this.vehicle,
    required this.quantities,
    required this.dispatchDate,
    required this.saving,
    required this.onDate,
    required this.onChanged,
    required this.onDispatch,
  });

  final YorksV1LogisticsWorkspace workspace;
  final TextEditingController deliveryReference;
  final TextEditingController driver;
  final TextEditingController vehicle;
  final Map<String, TextEditingController> quantities;
  final DateTime dispatchDate;
  final bool saving;
  final VoidCallback onDate;
  final VoidCallback onChanged;
  final VoidCallback onDispatch;

  @override
  Widget build(BuildContext context) {
    final candidates = workspace.dispatchCandidates
        .where((candidate) => _number(candidate.stillNeededQuantity) > 0)
        .toList(growable: false);
    final total = candidates.fold<double>(
      0,
      (sum, item) => sum + _number(quantities[item.requestLineId]?.text ?? ''),
    );
    return Column(
      key: const ValueKey('mobile-dispatch-create'),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 20),
            children: [
              YorksMobilePageTitle(
                eyebrow: workspace.requestNumber ?? '',
                title: YorksV1LogisticsStrings.createDispatch.primary,
                description:
                    YorksV1LogisticsStrings.dispatchOutstandingOnly.primary,
              ),
              const SizedBox(height: 16),
              YorksMobileCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TextInput(
                      controller: deliveryReference,
                      label: YorksV1LogisticsStrings.deliveryReference.primary,
                      onChanged: (_) => onChanged(),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: saving ? null : onDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText:
                              YorksV1LogisticsStrings.dispatchDate.primary,
                          suffixIcon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 19,
                          ),
                        ),
                        child: Text(_dateLabel(dispatchDate)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _TextInput(
                            controller: driver,
                            label: YorksV1LogisticsStrings.driver.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _TextInput(
                            controller: vehicle,
                            label: YorksV1LogisticsStrings.vehicle.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              YorksMobileSectionHeader(
                title: YorksV1LogisticsStrings.dispatchApprovedItems.primary,
                subtitle: workspace.scopeName,
              ),
              const SizedBox(height: 10),
              if (candidates.isEmpty)
                YorksMobileCard(
                  child: Text(YorksV1LogisticsStrings.noDispatch.primary),
                )
              else
                for (var index = 0; index < candidates.length; index++) ...[
                  _MobileDispatchCandidate(
                    index: index + 1,
                    candidate: candidates[index],
                    controller: quantities[candidates[index].requestLineId]!,
                    enabled: !saving,
                    onChanged: onChanged,
                  ),
                  const SizedBox(height: 10),
                ],
              YorksMobileCallout(
                icon: Icons.shield_outlined,
                title: YorksV1LogisticsStrings.stockProtected.primary,
                message:
                    YorksV1LogisticsStrings.stockRecheckedOnDispatch.primary,
              ),
            ],
          ),
        ),
        YorksMobileStickyActions(
          summary: YorksV1LogisticsStrings.dispatchUnits(
            _quantityText(total),
          ).primary,
          children: [
            FilledButton.icon(
              onPressed: candidates.isEmpty || saving ? null : onDispatch,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.local_shipping_outlined, size: 19),
              label: Text(YorksV1LogisticsStrings.dispatchNow.primary),
            ),
          ],
        ),
      ],
    );
  }
}

class _MobileDispatchCandidate extends StatelessWidget {
  const _MobileDispatchCandidate({
    required this.index,
    required this.candidate,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final int index;
  final YorksV1DispatchCandidate candidate;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => YorksMobileCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.blueContainer,
                shape: BoxShape.circle,
              ),
              child: Text('$index', style: AppTypography.labelLarge),
            ),
            const SizedBox(width: 10),
            Expanded(child: _CandidateName(candidate: candidate)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MobileDispatchFact(
                label: YorksV1LogisticsStrings.approved.primary,
                value:
                    '${_displayQuantity(candidate.approvedQuantity)} ${candidate.unit}',
              ),
            ),
            Expanded(
              child: _MobileDispatchFact(
                label: YorksV1LogisticsStrings.stillNeeded.primary,
                value:
                    '${_displayQuantity(candidate.stillNeededQuantity)} ${candidate.unit}',
              ),
            ),
          ],
        ),
        if (candidate.source == YorksV1LogisticsSource.warehouse) ...[
          const SizedBox(height: 8),
          _MobileDispatchFact(
            label: YorksV1LogisticsStrings.available.primary,
            value:
                '${_displayQuantity(candidate.warehouseAvailableQuantity ?? '0')} ${candidate.unit}',
          ),
        ],
        const SizedBox(height: 12),
        _QuantityInput(
          controller: controller,
          label: YorksV1LogisticsStrings.dispatchQuantity.primary,
          enabled: enabled,
          onChanged: (_) => onChanged(),
        ),
      ],
    ),
  );
}

class _MobileDispatchFact extends StatelessWidget {
  const _MobileDispatchFact({required this.label, required this.value});

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
      const SizedBox(height: 2),
      Text(value, style: AppTypography.labelLarge),
    ],
  );
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

class _DispatchCard extends ConsumerStatefulWidget {
  const _DispatchCard({
    required this.dispatch,
    required this.workspace,
    required this.onChanged,
  });

  final YorksV1MaterialDispatch dispatch;
  final YorksV1LogisticsWorkspace workspace;
  final VoidCallback onChanged;

  @override
  ConsumerState<_DispatchCard> createState() => _DispatchCardState();
}

class _DispatchCardState extends ConsumerState<_DispatchCard> {
  bool _uploadingPhoto = false;
  String _photoIdempotencyKey = const Uuid().v4();

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
            Text(widget.dispatch.number, style: AppTypography.titleSmall),
            _StateChip(state: widget.dispatch.state),
            Text(
              _dateLabel(widget.dispatch.dispatchDate),
              style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
            ),
          ],
        ),
        if (widget.dispatch.driverName != null ||
            widget.dispatch.vehicleReference != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              widget.dispatch.driverName,
              widget.dispatch.vehicleReference,
            ].whereType<String>().join(' · '),
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        for (final line in widget.dispatch.lines) _DispatchLineRow(line: line),
        if (widget.dispatch.receiptReview != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            widget.dispatch.receiptReview!.reviewedByDisplayName,
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: SecondaryButton(
              label: YorksV1LogisticsStrings.addSitePhoto.primary,
              isExpanded: false,
              icon: _uploadingPhoto
                  ? Icons.hourglass_top_rounded
                  : Icons.add_a_photo_outlined,
              onPressed: _uploadingPhoto ? null : _addSitePhoto,
            ),
          ),
        ],
        if (widget.dispatch.canConfirmReceipt) ...[
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
      workspace: widget.workspace,
      dispatch: widget.dispatch,
      onChanged: widget.onChanged,
    );
  }

  Future<void> _addSitePhoto() async {
    final review = widget.dispatch.receiptReview;
    if (review == null || _uploadingPhoto) return;
    setState(() => _uploadingPhoto = true);
    final uploaded = await _selectAndUploadReceiptPhoto(
      context: context,
      ref: ref,
      workspace: widget.workspace,
      receiptReviewId: review.id,
      idempotencyKey: _photoIdempotencyKey,
    );
    if (!mounted) return;
    if (uploaded) {
      _photoIdempotencyKey = const Uuid().v4();
      widget.onChanged();
    }
    setState(() => _uploadingPhoto = false);
  }
}

Future<bool> _selectAndUploadReceiptPhoto({
  required BuildContext context,
  required WidgetRef ref,
  required YorksV1LogisticsWorkspace workspace,
  required String receiptReviewId,
  required String idempotencyKey,
}) async {
  try {
    final selected = await ref
        .read(yorksV1DocumentFileServiceProvider)
        .selectImage();
    if (selected == null) return false;
    await ref
        .read(yorksV1DocumentsRepositoryProvider)
        .upload(
          YorksV1DocumentUploadInput(
            projectId: workspace.projectId,
            entityType: YorksV1DocumentEntityType.receiptReview,
            entityId: receiptReviewId,
            classification: YorksV1DocumentClassification.operational,
            fileName: selected.fileName,
            mimeType: selected.mimeType,
            bytes: selected.bytes,
            idempotencyKey: idempotencyKey,
          ),
        );
    if (context.mounted) {
      YorksAppToast.show(
        context,
        title: YorksV1LogisticsStrings.sitePhotoUploaded.primary,
        tone: YorksAppToastTone.success,
      );
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      YorksAppToast.show(
        context,
        title: YorksV1LogisticsStrings.sitePhotoFailed.primary,
        tone: YorksAppToastTone.error,
      );
    }
    return false;
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
  final Map<String, TextEditingController> _missingQuantities = {};
  final Map<String, TextEditingController> _damagedQuantities = {};
  final Map<String, TextEditingController> _notes = {};
  final Set<String> _reviewed = {};
  late String _receiptIdempotencyKey;
  late String _photoIdempotencyKey;
  bool _allReviewed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _receiptIdempotencyKey = const Uuid().v4();
    _photoIdempotencyKey = const Uuid().v4();
    for (final line in widget.dispatch.lines) {
      _outcomes[line.id] = YorksV1ReceiptOutcome.received;
      _goodQuantities[line.id] = TextEditingController(
        text: _displayQuantity(line.dispatchedQuantity),
      );
      _missingQuantities[line.id] = TextEditingController(text: '0');
      _damagedQuantities[line.id] = TextEditingController(text: '0');
      _notes[line.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _goodQuantities.values) {
      controller.dispose();
    }
    for (final controller in _missingQuantities.values) {
      controller.dispose();
    }
    for (final controller in _damagedQuantities.values) {
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
    if (YorksMobileUi.isActive(context)) {
      return PopScope(
        canPop: !_saving,
        child: Dialog.fullscreen(
          child: _MobileReceiptReview(
            dispatch: widget.dispatch,
            outcomes: _outcomes,
            reviewed: _reviewed,
            saving: _saving,
            onClose: () => Navigator.of(context).pop(),
            onReceiveAll: _receiveAll,
            onOutcome: _selectMobileOutcome,
            onConfirm: _reviewed.length == widget.dispatch.lines.length
                ? _confirm
                : null,
          ),
        ),
      );
    }
    final isCompact = screen.width < AppSpacing.yorksV1DesktopBreakpoint;
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        insetPadding: EdgeInsets.all(
          isCompact ? AppSpacing.sm : AppSpacing.xxl,
        ),
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
                            outcome:
                                _outcomes[widget.dispatch.lines[index].id]!,
                            goodQuantity:
                                _goodQuantities[widget
                                    .dispatch
                                    .lines[index]
                                    .id]!,
                            missingQuantity:
                                _missingQuantities[widget
                                    .dispatch
                                    .lines[index]
                                    .id]!,
                            damagedQuantity:
                                _damagedQuantities[widget
                                    .dispatch
                                    .lines[index]
                                    .id]!,
                            note: _notes[widget.dispatch.lines[index].id]!,
                            isDisabled: _saving,
                            onOutcomeChanged: (outcome) => setState(() {
                              final line = widget.dispatch.lines[index];
                              _reviewed.add(line.id);
                              _outcomes[line.id] = outcome;
                              if (outcome == YorksV1ReceiptOutcome.received) {
                                _goodQuantities[line.id]!.text =
                                    _displayQuantity(line.dispatchedQuantity);
                                _missingQuantities[line.id]!.text = '0';
                                _damagedQuantities[line.id]!.text = '0';
                                _notes[line.id]!.clear();
                              } else if (_goodQuantities[line.id]!.text ==
                                  _displayQuantity(line.dispatchedQuantity)) {
                                _goodQuantities[line.id]!.text = '0';
                                _missingQuantities[line.id]!.text = '0';
                                _damagedQuantities[line.id]!.text = '0';
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
                              : (value) => setState(
                                  () => _allReviewed = value ?? false,
                                ),
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
                        label:
                            YorksV1LogisticsStrings.saveReceiptReview.primary,
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
      ),
    );
  }

  Future<void> _confirm() async {
    if (YorksMobileUi.isActive(context) &&
        _reviewed.length != widget.dispatch.lines.length) {
      _showFailure(YorksV1LogisticsStrings.allLinesReviewed.primary);
      return;
    }
    final lines = <YorksV1ReceiptLineInput>[];
    for (final line in widget.dispatch.lines) {
      final outcome = _outcomes[line.id]!;
      final good = _goodQuantities[line.id]!.text.trim();
      final note = _notes[line.id]!.text.trim();
      final dispatched = YorksV1DecimalQuantity.tryParse(
        line.dispatchedQuantity,
      );
      final goodQuantity = YorksV1DecimalQuantity.tryParse(good);
      final missingQuantity = outcome == YorksV1ReceiptOutcome.missing
          ? dispatched == null || goodQuantity == null
                ? null
                : dispatched - goodQuantity
          : outcome == YorksV1ReceiptOutcome.mixed
          ? YorksV1DecimalQuantity.tryParse(
              _missingQuantities[line.id]!.text.trim(),
            )
          : YorksV1DecimalQuantity.zero;
      final damagedQuantity = outcome == YorksV1ReceiptOutcome.damaged
          ? dispatched == null || goodQuantity == null
                ? null
                : dispatched - goodQuantity
          : outcome == YorksV1ReceiptOutcome.mixed
          ? YorksV1DecimalQuantity.tryParse(
              _damagedQuantities[line.id]!.text.trim(),
            )
          : YorksV1DecimalQuantity.zero;
      if (goodQuantity == null ||
          dispatched == null ||
          missingQuantity == null ||
          damagedQuantity == null ||
          goodQuantity.isNegative ||
          missingQuantity.isNegative ||
          damagedQuantity.isNegative ||
          goodQuantity + missingQuantity + damagedQuantity != dispatched ||
          (outcome == YorksV1ReceiptOutcome.received &&
              (goodQuantity != dispatched || note.isNotEmpty)) ||
          (outcome == YorksV1ReceiptOutcome.missing &&
              (!missingQuantity.isPositive ||
                  !damagedQuantity.isZero ||
                  note.isEmpty)) ||
          (outcome == YorksV1ReceiptOutcome.damaged &&
              (!missingQuantity.isZero ||
                  !damagedQuantity.isPositive ||
                  note.isEmpty)) ||
          (outcome == YorksV1ReceiptOutcome.mixed &&
              (!missingQuantity.isPositive ||
                  !damagedQuantity.isPositive ||
                  note.isEmpty))) {
        _showFailure(YorksV1LogisticsStrings.invalidReceipt.primary);
        return;
      }
      lines.add(
        YorksV1ReceiptLineInput(
          dispatchLineId: line.id,
          outcome: outcome,
          goodQuantity: good,
          missingQuantity: missingQuantity.canonicalText,
          damagedQuantity: damagedQuantity.canonicalText,
          note: note,
        ),
      );
    }
    setState(() => _saving = true);
    try {
      final confirmedWorkspace = await ref
          .read(yorksV1MaterialWorkflowCommandControllerProvider)
          .confirmReceipt(
            YorksV1ReceiptConfirmationInput(
              requestId: widget.workspace.requestId,
              dispatchId: widget.dispatch.id,
              expectedRequestVersion: widget.workspace.requestRecordVersion,
              expectedDispatchVersion: widget.dispatch.recordVersion,
              lines: lines,
              idempotencyKey: _receiptIdempotencyKey,
            ),
          );
      if (!mounted) return;
      _receiptIdempotencyKey = const Uuid().v4();
      widget.onChanged();
      YorksV1ReceiptReview? confirmedReview;
      for (final dispatch in confirmedWorkspace.dispatches) {
        if (dispatch.id == widget.dispatch.id) {
          confirmedReview = dispatch.receiptReview;
          break;
        }
      }
      if (confirmedReview != null) {
        final attachNow = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Text(YorksV1LogisticsStrings.receiptConfirmed.primary),
            content: Text(YorksV1LogisticsStrings.attachPhotoPrompt.primary),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(YorksV1LogisticsStrings.attachLater.primary),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(YorksV1LogisticsStrings.addSitePhoto.primary),
              ),
            ],
          ),
        );
        if (attachNow == true && mounted) {
          final uploaded = await _selectAndUploadReceiptPhoto(
            context: context,
            ref: ref,
            workspace: confirmedWorkspace,
            receiptReviewId: confirmedReview.id,
            idempotencyKey: _photoIdempotencyKey,
          );
          if (uploaded) _photoIdempotencyKey = const Uuid().v4();
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on YorksV1DomainException catch (error) {
      if (mounted) {
        _showFailure(
          YorksV1MaterialRequestStrings.commandFailure(error.code).primary,
        );
      }
    } catch (_) {
      if (mounted) _showFailure(YorksV1LogisticsStrings.savingFailed.primary);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showFailure(String message) => YorksAppToast.show(
    context,
    title: message,
    tone: YorksAppToastTone.error,
  );

  void _receiveAll() {
    if (_saving) return;
    setState(() {
      for (final line in widget.dispatch.lines) {
        _outcomes[line.id] = YorksV1ReceiptOutcome.received;
        _goodQuantities[line.id]!.text = _displayQuantity(
          line.dispatchedQuantity,
        );
        _missingQuantities[line.id]!.text = '0';
        _damagedQuantities[line.id]!.text = '0';
        _notes[line.id]!.clear();
        _reviewed.add(line.id);
      }
    });
  }

  Future<void> _selectMobileOutcome(
    YorksV1DispatchLine line,
    YorksV1ReceiptOutcome outcome,
  ) async {
    if (_saving) return;
    if (outcome == YorksV1ReceiptOutcome.received) {
      setState(() {
        _outcomes[line.id] = outcome;
        _goodQuantities[line.id]!.text = _displayQuantity(
          line.dispatchedQuantity,
        );
        _missingQuantities[line.id]!.text = '0';
        _damagedQuantities[line.id]!.text = '0';
        _notes[line.id]!.clear();
        _reviewed.add(line.id);
      });
      return;
    }
    final result = await showDialog<_ReceiptExceptionDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MobileReceiptExceptionDialog(
        line: line,
        initialOutcome: outcome,
        initialGoodQuantity: _reviewed.contains(line.id)
            ? _goodQuantities[line.id]!.text
            : '0',
        initialMissingQuantity: _reviewed.contains(line.id)
            ? _missingQuantities[line.id]!.text
            : '0',
        initialDamagedQuantity: _reviewed.contains(line.id)
            ? _damagedQuantities[line.id]!.text
            : '0',
        initialNote: _notes[line.id]!.text,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _outcomes[line.id] = result.outcome;
      _goodQuantities[line.id]!.text = result.goodQuantity;
      _missingQuantities[line.id]!.text = result.missingQuantity;
      _damagedQuantities[line.id]!.text = result.damagedQuantity;
      _notes[line.id]!.text = result.note;
      _reviewed.add(line.id);
    });
  }
}

class _MobileReceiptReview extends StatelessWidget {
  const _MobileReceiptReview({
    required this.dispatch,
    required this.outcomes,
    required this.reviewed,
    required this.saving,
    required this.onClose,
    required this.onReceiveAll,
    required this.onOutcome,
    required this.onConfirm,
  });

  final YorksV1MaterialDispatch dispatch;
  final Map<String, YorksV1ReceiptOutcome> outcomes;
  final Set<String> reviewed;
  final bool saving;
  final VoidCallback onClose;
  final VoidCallback onReceiveAll;
  final void Function(YorksV1DispatchLine, YorksV1ReceiptOutcome) onOutcome;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.mobileSurface,
    body: Column(
      key: const ValueKey('mobile-receipt-review'),
      children: [
        YorksMobileAppBar(
          title: YorksV1LogisticsStrings.reviewDelivery.primary,
          leading: YorksMobileIconButton(
            icon: Icons.close_rounded,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: saving ? () {} : onClose,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
            children: [
              YorksMobilePageTitle(
                eyebrow: dispatch.number,
                title: YorksV1LogisticsStrings.reviewDeliveredMaterials.primary,
                description:
                    YorksV1LogisticsStrings.reviewDeliveryLineByLine.primary,
              ),
              const SizedBox(height: 14),
              _ReceiptDispatchBanner(dispatch: dispatch),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: saving ? null : onReceiveAll,
                icon: const Icon(Icons.done_all_rounded, size: 19),
                label: Text(
                  YorksV1LogisticsStrings.receiveAllAsDispatched.primary,
                ),
              ),
              const SizedBox(height: 14),
              for (var index = 0; index < dispatch.lines.length; index++) ...[
                _MobileReceiptLineCard(
                  index: index + 1,
                  line: dispatch.lines[index],
                  reviewed: reviewed.contains(dispatch.lines[index].id),
                  outcome: outcomes[dispatch.lines[index].id],
                  enabled: !saving,
                  onOutcome: (value) => onOutcome(dispatch.lines[index], value),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        YorksMobileStickyActions(
          summary: YorksV1LogisticsStrings.linesReviewed(
            reviewed.length,
            dispatch.lines.length,
          ).primary,
          children: [
            FilledButton.icon(
              onPressed: saving ? null : onConfirm,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined, size: 19),
              label: Text(YorksV1LogisticsStrings.confirmReceipt.primary),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MobileReceiptLineCard extends StatelessWidget {
  const _MobileReceiptLineCard({
    required this.index,
    required this.line,
    required this.reviewed,
    required this.outcome,
    required this.enabled,
    required this.onOutcome,
  });

  final int index;
  final YorksV1DispatchLine line;
  final bool reviewed;
  final YorksV1ReceiptOutcome? outcome;
  final bool enabled;
  final ValueChanged<YorksV1ReceiptOutcome> onOutcome;

  @override
  Widget build(BuildContext context) => YorksMobileCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ReceiptLineIdentity(lineNumber: index, line: line),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: reviewed
                    ? AppColors.successContainer
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                (reviewed
                        ? YorksV1LogisticsStrings.reviewed
                        : YorksV1LogisticsStrings.pending)
                    .primary,
                style: AppTypography.labelSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        YorksMobileSegmentedControl<YorksV1ReceiptOutcome>(
          options: [
            for (final value in YorksV1ReceiptOutcome.values)
              YorksMobileSegmentOption(
                value: value,
                label: yorksV1ReceiptOutcomeCopy(value).primary,
              ),
          ],
          selected: reviewed ? outcome : null,
          enabled: enabled,
          onSelected: onOutcome,
        ),
      ],
    ),
  );
}

class _ReceiptExceptionDraft {
  const _ReceiptExceptionDraft({
    required this.outcome,
    required this.goodQuantity,
    required this.missingQuantity,
    required this.damagedQuantity,
    required this.note,
  });

  final YorksV1ReceiptOutcome outcome;
  final String goodQuantity;
  final String missingQuantity;
  final String damagedQuantity;
  final String note;
}

class _MobileReceiptExceptionDialog extends StatefulWidget {
  const _MobileReceiptExceptionDialog({
    required this.line,
    required this.initialOutcome,
    required this.initialGoodQuantity,
    required this.initialMissingQuantity,
    required this.initialDamagedQuantity,
    required this.initialNote,
  });

  final YorksV1DispatchLine line;
  final YorksV1ReceiptOutcome initialOutcome;
  final String initialGoodQuantity;
  final String initialMissingQuantity;
  final String initialDamagedQuantity;
  final String initialNote;

  @override
  State<_MobileReceiptExceptionDialog> createState() =>
      _MobileReceiptExceptionDialogState();
}

class _MobileReceiptExceptionDialogState
    extends State<_MobileReceiptExceptionDialog> {
  late YorksV1ReceiptOutcome _outcome;
  late final TextEditingController _goodQuantity;
  late final TextEditingController _missingQuantity;
  late final TextEditingController _damagedQuantity;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _outcome = widget.initialOutcome;
    _goodQuantity = TextEditingController(text: widget.initialGoodQuantity);
    _missingQuantity = TextEditingController(
      text: widget.initialMissingQuantity,
    );
    _damagedQuantity = TextEditingController(
      text: widget.initialDamagedQuantity,
    );
    _note = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _goodQuantity.dispose();
    _missingQuantity.dispose();
    _damagedQuantity.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exception =
        (_number(widget.line.dispatchedQuantity) - _number(_goodQuantity.text))
            .clamp(0, double.infinity)
            .toDouble();
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: AppColors.mobileSurface,
        body: Column(
          key: const ValueKey('mobile-receipt-exception'),
          children: [
            YorksMobileAppBar(
              title: YorksV1LogisticsStrings.deliveryException.primary,
              leading: YorksMobileIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
                children: [
                  YorksMobilePageTitle(
                    eyebrow: widget.line.unit,
                    title: widget.line.description,
                    description:
                        '${_displayQuantity(widget.line.dispatchedQuantity)} ${widget.line.unit} ${YorksV1LogisticsStrings.dispatched.primary}',
                  ),
                  const SizedBox(height: 16),
                  YorksMobileCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          YorksV1LogisticsStrings.result.primary,
                          style: AppTypography.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        YorksMobileSegmentedControl<YorksV1ReceiptOutcome>(
                          options: [
                            for (final value in const [
                              YorksV1ReceiptOutcome.missing,
                              YorksV1ReceiptOutcome.damaged,
                              YorksV1ReceiptOutcome.mixed,
                            ])
                              YorksMobileSegmentOption(
                                value: value,
                                label: yorksV1ReceiptOutcomeCopy(value).primary,
                              ),
                          ],
                          selected: _outcome,
                          onSelected: (value) =>
                              setState(() => _outcome = value),
                        ),
                        const SizedBox(height: 14),
                        _QuantityInput(
                          controller: _goodQuantity,
                          label: YorksV1LogisticsStrings.goodQuantity.primary,
                          onChanged: (_) => setState(() {}),
                        ),
                        if (_outcome == YorksV1ReceiptOutcome.mixed) ...[
                          const SizedBox(height: 12),
                          _QuantityInput(
                            controller: _missingQuantity,
                            label:
                                YorksV1LogisticsStrings.missingQuantity.primary,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          _QuantityInput(
                            controller: _damagedQuantity,
                            label:
                                YorksV1LogisticsStrings.damagedQuantity.primary,
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: _note,
                          minLines: 3,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText:
                                YorksV1LogisticsStrings.explanation.primary,
                            helperText: YorksV1LogisticsStrings
                                .exceptionExplanationRequired
                                .primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  YorksMobileCallout(
                    icon: Icons.replay_rounded,
                    title: YorksV1LogisticsStrings.replacementEligible.primary,
                    message: YorksV1LogisticsStrings.replacementQuantity(
                      _quantityText(exception),
                      widget.line.unit,
                    ).primary,
                    warning: true,
                  ),
                ],
              ),
            ),
            YorksMobileStickyActions(
              children: [
                FilledButton(
                  onPressed: _save,
                  child: Text(YorksV1LogisticsStrings.saveReview.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final dispatched = _number(widget.line.dispatchedQuantity);
    final good = _decimalNumber(_goodQuantity.text);
    final missing = _outcome == YorksV1ReceiptOutcome.missing
        ? dispatched - (good ?? 0)
        : _outcome == YorksV1ReceiptOutcome.mixed
        ? _decimalNumber(_missingQuantity.text)
        : 0.0;
    final damaged = _outcome == YorksV1ReceiptOutcome.damaged
        ? dispatched - (good ?? 0)
        : _outcome == YorksV1ReceiptOutcome.mixed
        ? _decimalNumber(_damagedQuantity.text)
        : 0.0;
    if (good == null ||
        missing == null ||
        damaged == null ||
        good < 0 ||
        missing < 0 ||
        damaged < 0 ||
        (good + missing + damaged - dispatched).abs() > .0001 ||
        (_outcome == YorksV1ReceiptOutcome.missing && missing <= 0) ||
        (_outcome == YorksV1ReceiptOutcome.damaged && damaged <= 0) ||
        (_outcome == YorksV1ReceiptOutcome.mixed &&
            (missing <= 0 || damaged <= 0)) ||
        _note.text.trim().isEmpty) {
      YorksAppToast.show(
        context,
        title: YorksV1LogisticsStrings.invalidReceipt.primary,
        tone: YorksAppToastTone.error,
      );
      return;
    }
    Navigator.of(context).pop(
      _ReceiptExceptionDraft(
        outcome: _outcome,
        goodQuantity: _goodQuantity.text.trim(),
        missingQuantity: _quantityText(missing),
        damagedQuantity: _quantityText(damaged),
        note: _note.text.trim(),
      ),
    );
  }
}

class _ReceiptLineEditor extends StatelessWidget {
  const _ReceiptLineEditor({
    required this.lineNumber,
    required this.line,
    required this.outcome,
    required this.goodQuantity,
    required this.missingQuantity,
    required this.damagedQuantity,
    required this.note,
    required this.isDisabled,
    required this.onOutcomeChanged,
  });

  final int lineNumber;
  final YorksV1DispatchLine line;
  final YorksV1ReceiptOutcome outcome;
  final TextEditingController goodQuantity;
  final TextEditingController missingQuantity;
  final TextEditingController damagedQuantity;
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
          missingQuantity: missingQuantity,
          damagedQuantity: damagedQuantity,
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
    required this.missingQuantity,
    required this.damagedQuantity,
    required this.note,
    required this.disabled,
  });

  final YorksV1ReceiptOutcome outcome;
  final TextEditingController goodQuantity;
  final TextEditingController missingQuantity;
  final TextEditingController damagedQuantity;
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
        if (outcome == YorksV1ReceiptOutcome.mixed)
          SizedBox(
            width: constraints.maxWidth >= 330 ? 150 : double.infinity,
            child: _QuantityInput(
              controller: missingQuantity,
              label: YorksV1LogisticsStrings.missingQuantity.primary,
              enabled: !disabled,
            ),
          ),
        if (outcome == YorksV1ReceiptOutcome.mixed)
          SizedBox(
            width: constraints.maxWidth >= 330 ? 150 : double.infinity,
            child: _QuantityInput(
              controller: damagedQuantity,
              label: YorksV1LogisticsStrings.damagedQuantity.primary,
              enabled: !disabled,
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
    this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    onChanged: onChanged,
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
    this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    onChanged: onChanged,
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

double? _decimalNumber(String text) {
  final normalized = text.trim();
  if (!RegExp(r'^\d+(?:\.\d{1,4})?$').hasMatch(normalized)) return null;
  final value = double.tryParse(normalized);
  return value != null && value.isFinite ? value : null;
}

String _quantityText(double value) => value == value.truncateToDouble()
    ? value.toInt().toString()
    : value.toString();

String _displayQuantity(String raw) => yorksV1DisplayQuantity(raw);

String _dateLabel(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
