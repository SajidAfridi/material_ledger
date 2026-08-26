import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/yorks_v1_accounts_strings.dart';
import '../../application/accounts_controller.dart';
import '../../application/accounts_providers.dart';
import '../../domain/accounts_decimal.dart';
import '../../domain/accounts_inputs.dart';
import '../../domain/accounts_models.dart';

Future<bool> showYorksAccountsBaselineActionSheet(
  BuildContext context, {
  required String projectId,
  required YorksAccountsBaselineProjection projection,
  required AppLanguage language,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BaselineActionSheet(
        projectId: projectId,
        projection: projection,
        language: language,
      ),
    ) ??
    false;

class _BaselineActionSheet extends ConsumerStatefulWidget {
  const _BaselineActionSheet({
    required this.projectId,
    required this.projection,
    required this.language,
  });

  final String projectId;
  final YorksAccountsBaselineProjection projection;
  final AppLanguage language;

  @override
  ConsumerState<_BaselineActionSheet> createState() =>
      _BaselineActionSheetState();
}

class _BaselineActionSheetState extends ConsumerState<_BaselineActionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _contract;
  late final TextEditingController _currency;
  late final TextEditingController _vat;
  late final TextEditingController _terms;
  late final TextEditingController _reminder;
  late final TextEditingController _threshold;
  late final TextEditingController _reason;
  late final Map<String, TextEditingController> _buildings;
  late final Map<String, TextEditingController> _stages;
  late final List<YorksAccountsStageTemplate> _stageDefinitions;
  late bool _alwaysReview;
  late Set<String> _reviewRoles;
  String? _error;

  bool get _isRevision => widget.projection.baseline != null;
  String _text(String key) => YorksV1AccountsStrings.text(widget.language, key);

  @override
  void initState() {
    super.initState();
    final baseline = widget.projection.baseline;
    _contract = TextEditingController(
      text: baseline?.contractValue?.canonicalText ?? '',
    );
    _currency = TextEditingController(text: baseline?.currencyCode ?? 'AED');
    _vat = TextEditingController(text: baseline?.vatRate?.canonicalText ?? '5');
    _terms = TextEditingController(
      text: (baseline?.paymentTermsDays ?? 90).toString(),
    );
    _reminder = TextEditingController(
      text: (baseline?.reminderLeadDays ?? 10).toString(),
    );
    _threshold = TextEditingController(
      text: baseline?.managementReviewPolicy?.thresholdAmount?.canonicalText,
    );
    _reason = TextEditingController();
    _alwaysReview = baseline?.managementReviewPolicy?.alwaysRequired ?? false;
    _reviewRoles = {...?baseline?.managementReviewPolicy?.confirmingExactRoles};

    final existingBuilding = {
      for (final item in widget.projection.buildingAllocations)
        item.buildingScopeId: item.allocationPercent.canonicalText,
    };
    final defaults = _equalAllocations(
      widget.projection.physicalBuildings.length,
    );
    _buildings = {
      for (
        var index = 0;
        index < widget.projection.physicalBuildings.length;
        index++
      )
        widget.projection.physicalBuildings[index].buildingScopeId:
            TextEditingController(
              text:
                  existingBuilding[widget
                      .projection
                      .physicalBuildings[index]
                      .buildingScopeId] ??
                  (_isRevision ? '' : defaults[index]),
            ),
    };

    final existingStages = widget.projection.stageAllocations;
    _stageDefinitions = existingStages.isNotEmpty
        ? [
            for (final item in existingStages)
              YorksAccountsStageTemplate(
                stageKey: item.stageKey,
                stageLabel: item.stageLabel ?? item.stageKey,
                position: item.position,
                allocationPercent: item.allocationPercent,
              ),
          ]
        : widget.projection.stageTemplates;
    _stages = {
      for (final item in _stageDefinitions)
        item.stageKey: TextEditingController(
          text: item.allocationPercent.canonicalText,
        ),
    };
    for (final controller in [..._buildings.values, ..._stages.values]) {
      controller.addListener(_allocationChanged);
    }
  }

  void _allocationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in [
      _contract,
      _currency,
      _vat,
      _terms,
      _reminder,
      _threshold,
      _reason,
      ..._buildings.values,
      ..._stages.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _error = _text('review_invalid_fields'));
      return;
    }
    final input = _input();
    if (input == null || !input.isValid) {
      setState(() => _error = _text('allocation_validation_failed'));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _text(_isRevision ? 'confirm_baseline_revision' : 'confirm_baseline'),
        ),
        content: Text(_text('baseline_confirmation_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_text('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_text('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final controller = ref.read(
      yorksAccountsProjectControllerProvider(widget.projectId).notifier,
    );
    final result = _isRevision
        ? await controller.reviseBaseline(input)
        : await controller.initializeBaseline(input);
    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop(true);
      return;
    }
    final status = ref
        .read(yorksAccountsProjectControllerProvider(widget.projectId))
        .status;
    setState(() => _error = _commandError(status));
  }

  YorksAccountsBaselineInput? _input() {
    final contract = YorksAccountsDecimal.tryParse(_contract.text);
    final vat = YorksAccountsDecimal.tryParse(_vat.text);
    final terms = int.tryParse(_terms.text.trim());
    final reminder = int.tryParse(_reminder.text.trim());
    final threshold = _threshold.text.trim().isEmpty
        ? null
        : YorksAccountsDecimal.tryParse(_threshold.text);
    if (contract == null || vat == null || terms == null || reminder == null) {
      return null;
    }
    final buildingInputs = <YorksAccountsBuildingAllocationInput>[];
    for (final building in widget.projection.physicalBuildings) {
      final value = YorksAccountsDecimal.tryParse(
        _buildings[building.buildingScopeId]!.text,
      );
      if (value == null) return null;
      buildingInputs.add(
        YorksAccountsBuildingAllocationInput(
          buildingScopeId: building.buildingScopeId,
          allocationPercent: value,
          isCommonScope: false,
        ),
      );
    }
    final stageInputs = <YorksAccountsStageAllocationInput>[];
    for (final stage in _stageDefinitions) {
      final value = YorksAccountsDecimal.tryParse(
        _stages[stage.stageKey]!.text,
      );
      if (value == null) return null;
      stageInputs.add(
        YorksAccountsStageAllocationInput(
          stageKey: stage.stageKey,
          stageLabel: stage.stageLabel,
          position: stage.position,
          allocationPercent: value,
        ),
      );
    }
    return YorksAccountsBaselineInput(
      projectId: widget.projectId,
      contractValue: contract,
      currencyCode: _currency.text,
      vatRate: vat,
      paymentTermsDays: terms,
      reminderLeadDays: reminder,
      buildingAllocations: buildingInputs,
      stageAllocations: stageInputs,
      managementReviewPolicy: YorksAccountsManagementReviewPolicy(
        alwaysRequired: _alwaysReview,
        thresholdAmount: threshold,
        confirmingExactRoles: _reviewRoles.toList()..sort(),
      ),
      reason: _reason.text,
      expectedBaselineVersion: widget.projection.baseline?.recordVersion,
    );
  }

  String _commandError(YorksAccountsViewStatus status) => switch (status) {
    YorksAccountsViewStatus.conflict => _text('stale_conflict'),
    YorksAccountsViewStatus.uncertain => _text('uncertain_commit'),
    YorksAccountsViewStatus.offline => _text('offline'),
    YorksAccountsViewStatus.forbidden => _text('forbidden'),
    YorksAccountsViewStatus.sessionExpired => _text('session_expired'),
    _ => _text('action_failed'),
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      yorksAccountsProjectControllerProvider(widget.projectId),
    );
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.94;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text(
                          _isRevision
                              ? 'revise_commercial_baseline'
                              : 'set_commercial_baseline',
                        ),
                        style: AppTypography.titleLarge,
                      ),
                      Text(
                        _text('baseline_editor_guidance'),
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _text('close'),
                  onPressed: Navigator.of(context).pop,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionTitle(_text('commercial_terms')),
                    _ResponsiveFields(
                      children: [
                        _decimalField(
                          _contract,
                          _text('contract_value'),
                          positive: true,
                        ),
                        TextFormField(
                          controller: _currency,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: _text('currency'),
                          ),
                          validator: (value) =>
                              RegExp(
                                r'^[A-Za-z]{3}$',
                              ).hasMatch(value?.trim() ?? '')
                              ? null
                              : _text('invalid_currency'),
                        ),
                        _decimalField(_vat, _text('vat_rate')),
                        _integerField(_terms, _text('payment_terms_days')),
                        _integerField(
                          _reminder,
                          _text('reminder_lead_days'),
                          allowZero: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SectionTitle(_text('physical_building_allocations')),
                    Text(
                      _text('common_scope_excluded'),
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (widget.projection.physicalBuildings.isEmpty)
                      _InlineError(_text('no_physical_buildings'))
                    else
                      _ResponsiveFields(
                        children: [
                          for (final building
                              in widget.projection.physicalBuildings)
                            _decimalField(
                              _buildings[building.buildingScopeId]!,
                              '${building.scopeCode} · ${building.buildingName}',
                              suffix: '%',
                              positive: true,
                            ),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    _AllocationTotal(
                      label: _text('building_total'),
                      controllers: _buildings.values,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SectionTitle(_text('billing_stage_allocations')),
                    _ResponsiveFields(
                      children: [
                        for (final stage in _stageDefinitions)
                          _decimalField(
                            _stages[stage.stageKey]!,
                            '${stage.position}. ${stage.stageLabel}',
                            suffix: '%',
                            positive: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _AllocationTotal(
                      label: _text('stage_total'),
                      controllers: _stages.values,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SectionTitle(_text('management_review_policy')),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_text('always_require_review')),
                      value: _alwaysReview,
                      onChanged: (value) =>
                          setState(() => _alwaysReview = value),
                    ),
                    _decimalField(
                      _threshold,
                      _text('review_threshold_optional'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _text('review_roles'),
                      style: AppTypography.titleSmall,
                    ),
                    for (final role in _allowedReviewRoles)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _reviewRoles.contains(role.$1),
                        title: Text(_text(role.$2)),
                        onChanged: (selected) => setState(() {
                          if (selected == true) {
                            _reviewRoles.add(role.$1);
                          } else {
                            _reviewRoles.remove(role.$1);
                          }
                        }),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _reason,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(labelText: _text('reason')),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? _text('reason_required')
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _InlineError(_error!),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: state.isMutating
                          ? null
                          : Navigator.of(context).pop,
                      child: Text(_text('cancel')),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: state.isMutating ? null : _submit,
                      icon: state.isMutating
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _text(
                          _isRevision ? 'save_revision' : 'activate_baseline',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextFormField _decimalField(
    TextEditingController controller,
    String label, {
    String? suffix,
    bool positive = false,
  }) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, suffixText: suffix),
    validator: (value) {
      if (!positive && (value == null || value.trim().isEmpty)) return null;
      final decimal = YorksAccountsDecimal.tryParse(value ?? '');
      if (decimal == null || (positive && !decimal.isPositive)) {
        return _text('invalid_amount');
      }
      return null;
    },
  );

  TextFormField _integerField(
    TextEditingController controller,
    String label, {
    bool allowZero = false,
  }) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final parsed = int.tryParse(value?.trim() ?? '');
      if (parsed == null || (allowZero ? parsed < 0 : parsed <= 0)) {
        return _text('invalid_whole_number');
      }
      return null;
    },
  );
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 760 ? 2 : 1;
      final width = columns == 1
          ? constraints.maxWidth
          : (constraints.maxWidth - AppSpacing.md) / 2;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Text(label, style: AppTypography.titleMedium),
  );
}

class _AllocationTotal extends StatelessWidget {
  const _AllocationTotal({required this.label, required this.controllers});
  final String label;
  final Iterable<TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    var total = YorksAccountsDecimal.zero;
    var valid = true;
    for (final controller in controllers) {
      final parsed = YorksAccountsDecimal.tryParse(controller.text);
      if (parsed == null) {
        valid = false;
      } else {
        total += parsed;
      }
    }
    final exact = valid && total == YorksAccountsDecimal.hundred;
    return Row(
      children: [
        Icon(
          exact ? Icons.check_circle_outline : Icons.error_outline,
          color: exact ? AppColors.success : AppColors.error,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('$label: ${total.canonicalText}%'),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.errorContainer,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      border: Border.all(color: AppColors.error),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

List<String> _equalAllocations(int count) {
  if (count <= 0) return const [];
  const totalUnits = 1000000;
  final base = totalUnits ~/ count;
  var remainder = totalUnits - base * count;
  return List.generate(count, (index) {
    final units = base + (remainder > 0 ? 1 : 0);
    if (remainder > 0) remainder--;
    final digits = units.toString().padLeft(5, '0');
    return '${digits.substring(0, digits.length - 4)}.'
        '${digits.substring(digits.length - 4)}';
  });
}

const _allowedReviewRoles = <(String, String)>[
  ('project_engineer', 'role_project_engineer'),
  ('senior_mechanical_engineer', 'role_senior_mechanical_engineer'),
  ('project_manager', 'role_project_manager'),
  ('workshop_in_charge', 'role_workshop_in_charge'),
  ('document_controller', 'role_document_controller'),
];
