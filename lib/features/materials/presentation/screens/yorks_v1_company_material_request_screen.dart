import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/yorks_v1_company_material_request.dart';
import '../../../../shared/models/yorks_v1_company_material_request_strings.dart';
import '../../../../shared/models/yorks_v1_domain_error.dart';
import '../../../../shared/models/yorks_v1_material_request.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_company_material_request_provider.dart';

/// Focused, responsive first-step composer for a non-project company need.
/// It is intentionally not an alternate project MR editor and has no route to
/// BOQ, scope or inventory data.
class YorksV1CompanyMaterialRequestScreen extends ConsumerStatefulWidget {
  const YorksV1CompanyMaterialRequestScreen({super.key});

  @override
  ConsumerState<YorksV1CompanyMaterialRequestScreen> createState() =>
      _YorksV1CompanyMaterialRequestScreenState();
}

class _YorksV1CompanyMaterialRequestScreenState
    extends ConsumerState<YorksV1CompanyMaterialRequestScreen> {
  final _purpose = TextEditingController();
  final _point = TextEditingController();
  late YorksV1CompanyMaterialRequestDraft _draft;
  YorksV1CompanyMaterialRequestApprovalPreflight? _preflight;
  bool _routeChecking = false;
  bool _routeUnavailable = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    const uuid = Uuid();
    _draft = YorksV1CompanyMaterialRequestDraft(
      id: uuid.v4(),
      recordVersion: 0,
      submissionIdempotencyKey: uuid.v4(),
      timing: YorksV1MaterialRequestTiming.normal,
      lines: [
        YorksV1CompanyMaterialRequestLine(
          id: uuid.v4(),
          displayOrder: 1,
          description: '',
          quantity: '',
          unit: '',
        ),
      ],
    );
  }

  @override
  void dispose() {
    _purpose.dispose();
    _point.dispose();
    super.dispose();
  }

  void _update(YorksV1CompanyMaterialRequestDraft next) {
    setState(() {
      _draft = next;
      _preflight = null;
      _routeUnavailable = false;
      _routeChecking = false;
    });
    _checkRoute();
  }

  Future<void> _checkRoute() async {
    final category = _draft.categoryId;
    final unit = _draft.responsibleUnitId;
    final beneficiary = _draft.beneficiaryAuthUserId;
    final receiver = _draft.authorizedReceiverAuthUserId;
    if (category == null ||
        unit == null ||
        beneficiary == null ||
        receiver == null) {
      return;
    }
    setState(() => _routeChecking = true);
    try {
      final result = await ref
          .read(yorksV1CompanyMaterialRequestRepositoryProvider)
          .preflightApproval(
            categoryId: category,
            responsibleUnitId: unit,
            beneficiaryAuthUserId: beneficiary,
            authorizedReceiverAuthUserId: receiver,
          );
      if (!mounted ||
          category != _draft.categoryId ||
          unit != _draft.responsibleUnitId ||
          beneficiary != _draft.beneficiaryAuthUserId ||
          receiver != _draft.authorizedReceiverAuthUserId) {
        return;
      }
      setState(() {
        _preflight = result;
        _routeUnavailable = false;
        _routeChecking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preflight = null;
        _routeUnavailable = true;
        _routeChecking = false;
      });
    }
  }

  YorksV1CompanyMaterialRequestDraft get _current => _draft.copyWith(
    purpose: _purpose.text,
    deliveryCollectionPoint: _point.text,
  );

  Future<void> _save({required bool submit, AppLanguage? language}) async {
    final draft = _current;
    if (!draft.canSave) {
      _show(YorksV1CompanyMaterialRequestStrings.validation.active(language!));
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(
        yorksV1CompanyMaterialRequestRepositoryProvider,
      );
      final result = submit
          ? await repository.saveAndSubmit(draft)
          : await repository.saveDraft(draft);
      if (!mounted) return;
      setState(
        () => _draft = _draft.copyWith(recordVersion: result.recordVersion),
      );
      _show(
        (submit
                ? YorksV1CompanyMaterialRequestStrings.submitted
                : YorksV1CompanyMaterialRequestStrings.draftSaved)
            .active(language!),
      );
      if (submit && mounted) {
        context.pop();
      }
    } on YorksV1DomainException {
      if (mounted) {
        _show(YorksV1CompanyMaterialRequestStrings.failed.active(language!));
      }
    } catch (_) {
      if (mounted) {
        _show(YorksV1CompanyMaterialRequestStrings.failed.active(language!));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final options = ref.watch(
      yorksV1CompanyMaterialRequestDraftOptionsProvider,
    );
    final compact =
        MediaQuery.sizeOf(context).width < AppSpacing.compactBreakpoint;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          YorksV1CompanyMaterialRequestStrings.title.active(language),
        ),
      ),
      body: options.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _CompanyRequestPolicyEmpty(language: language),
        data: (items) => items.isEmpty
            ? _CompanyRequestPolicyEmpty(language: language)
            : SafeArea(
                top: false,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.all(
                          compact ? AppSpacing.md : AppSpacing.xl,
                        ),
                        children: [
                          _Heading(language: language),
                          const SizedBox(height: AppSpacing.lg),
                          _ContextCard(
                            language: language,
                            options: items,
                            draft: _draft,
                            onChanged: _update,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _RequestDetailsCard(
                            language: language,
                            purpose: _purpose,
                            collectionPoint: _point,
                            draft: _draft,
                            onChanged: _update,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _CompanyLineEditor(
                            language: language,
                            lines: _draft.lines,
                            onChanged: (lines) =>
                                _update(_draft.copyWith(lines: lines)),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _ApprovalCard(
                            language: language,
                            checking: _routeChecking,
                            routeUnavailable: _routeUnavailable,
                            preflight: _preflight,
                          ),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? AppSpacing.md : AppSpacing.xl,
                          AppSpacing.sm,
                          compact ? AppSpacing.md : AppSpacing.xl,
                          AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => _save(
                                        submit: false,
                                        language: language,
                                      ),
                                child: Text(
                                  YorksV1CompanyMaterialRequestStrings.saveDraft
                                      .active(language),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: FilledButton(
                                onPressed: _saving || _preflight == null
                                    ? null
                                    : () => _save(
                                        submit: true,
                                        language: language,
                                      ),
                                child: _saving
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        YorksV1CompanyMaterialRequestStrings
                                            .submit
                                            .active(language),
                                      ),
                              ),
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
}

class _Heading extends StatelessWidget {
  const _Heading({required this.language});
  final AppLanguage language;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        YorksV1CompanyMaterialRequestStrings.companyUse.active(language),
        style: AppTypography.headlineMedium.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        YorksV1CompanyMaterialRequestStrings.subtitle.active(language),
        style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
      ),
    ],
  );
}

class _CompanyRequestPolicyEmpty extends StatelessWidget {
  const _CompanyRequestPolicyEmpty({required this.language});
  final AppLanguage language;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(
        YorksV1CompanyMaterialRequestStrings.noEligibleOptions.active(language),
        textAlign: TextAlign.center,
        style: AppTypography.bodyLarge.copyWith(color: AppColors.muted),
      ),
    ),
  );
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.language,
    required this.options,
    required this.draft,
    required this.onChanged,
  });
  final AppLanguage language;
  final List<YorksV1CompanyMaterialRequestDraftOption> options;
  final YorksV1CompanyMaterialRequestDraft draft;
  final ValueChanged<YorksV1CompanyMaterialRequestDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = options
        .where(
          (option) =>
              option.categoryId == draft.categoryId &&
              option.responsibleUnitId == draft.responsibleUnitId,
        )
        .firstOrNull;
    return _CompanyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            YorksV1CompanyMaterialRequestStrings.categoryAndUnit.active(
              language,
            ),
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<YorksV1CompanyMaterialRequestDraftOption>(
            key: const ValueKey('company-material-request-context'),
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            hint: Text(
              YorksV1CompanyMaterialRequestStrings.categoryAndUnit.active(
                language,
              ),
            ),
            items: [
              for (final option in options)
                DropdownMenuItem(
                  value: option,
                  child: Text(
                    '${option.categoryName} · ${option.responsibleUnitName}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (option) {
              if (option == null) return;
              onChanged(
                draft.copyWith(
                  categoryId: option.categoryId,
                  responsibleUnitId: option.responsibleUnitId,
                  clearBeneficiary: true,
                  clearAuthorizedReceiver: true,
                ),
              );
            },
          ),
          if (selected != null) ...[
            const SizedBox(height: AppSpacing.md),
            _PersonPicker(
              fieldKey: const ValueKey('company-material-request-beneficiary'),
              label: YorksV1CompanyMaterialRequestStrings.beneficiary.active(
                language,
              ),
              value: draft.beneficiaryAuthUserId,
              options: selected.beneficiaries,
              onChanged: (value) =>
                  onChanged(draft.copyWith(beneficiaryAuthUserId: value)),
            ),
            const SizedBox(height: AppSpacing.sm),
            _PersonPicker(
              fieldKey: const ValueKey('company-material-request-receiver'),
              label: YorksV1CompanyMaterialRequestStrings.authorizedReceiver
                  .active(language),
              value: draft.authorizedReceiverAuthUserId,
              options: selected.receivers,
              onChanged: (value) => onChanged(
                draft.copyWith(authorizedReceiverAuthUserId: value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonPicker extends StatelessWidget {
  const _PersonPicker({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final Key fieldKey;
  final String label;
  final String? value;
  final List<YorksV1CompanyMaterialRequestPerson> options;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: fieldKey,
    initialValue: options.any((person) => person.authUserId == value)
        ? value
        : null,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final person in options)
        DropdownMenuItem(
          value: person.authUserId,
          child: Text(person.displayName, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onChanged,
  );
}

class _RequestDetailsCard extends StatelessWidget {
  const _RequestDetailsCard({
    required this.language,
    required this.purpose,
    required this.collectionPoint,
    required this.draft,
    required this.onChanged,
  });
  final AppLanguage language;
  final TextEditingController purpose;
  final TextEditingController collectionPoint;
  final YorksV1CompanyMaterialRequestDraft draft;
  final ValueChanged<YorksV1CompanyMaterialRequestDraft> onChanged;
  @override
  Widget build(BuildContext context) => _CompanyCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('company-material-request-purpose'),
          controller: purpose,
          maxLength: 1000,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: YorksV1CompanyMaterialRequestStrings.purpose.active(
              language,
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const ValueKey('company-material-request-collection-point'),
          controller: collectionPoint,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: YorksV1CompanyMaterialRequestStrings
                .deliveryCollectionPoint
                .active(language),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<YorksV1MaterialRequestTiming>(
          initialValue: draft.timing,
          decoration: InputDecoration(
            labelText: YorksV1CompanyMaterialRequestStrings.timing.active(
              language,
            ),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: YorksV1MaterialRequestTiming.normal,
              child: Text(
                YorksV1CompanyMaterialRequestStrings.normal.active(language),
              ),
            ),
            DropdownMenuItem(
              value: YorksV1MaterialRequestTiming.urgent,
              child: Text(
                YorksV1CompanyMaterialRequestStrings.urgent.active(language),
              ),
            ),
            DropdownMenuItem(
              value: YorksV1MaterialRequestTiming.scheduled,
              child: Text(
                YorksV1CompanyMaterialRequestStrings.scheduled.active(language),
              ),
            ),
          ],
          onChanged: (timing) => onChanged(
            draft.copyWith(
              timing: timing,
              clearScheduledDate:
                  timing != YorksV1MaterialRequestTiming.scheduled,
            ),
          ),
        ),
        if (draft.timing == YorksV1MaterialRequestTiming.scheduled) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 730)),
                initialDate: draft.scheduledDate ?? DateTime.now(),
              );
              if (selected != null) {
                onChanged(draft.copyWith(scheduledDate: selected));
              }
            },
            icon: const Icon(Icons.event_outlined),
            label: Text(
              draft.scheduledDate == null
                  ? YorksV1CompanyMaterialRequestStrings.requiredDate.active(
                      language,
                    )
                  : '${draft.scheduledDate!.day}/${draft.scheduledDate!.month}/${draft.scheduledDate!.year}',
            ),
          ),
        ],
      ],
    ),
  );
}

class _CompanyLineEditor extends StatelessWidget {
  const _CompanyLineEditor({
    required this.language,
    required this.lines,
    required this.onChanged,
  });
  final AppLanguage language;
  final List<YorksV1CompanyMaterialRequestLine> lines;
  final ValueChanged<List<YorksV1CompanyMaterialRequestLine>> onChanged;
  @override
  Widget build(BuildContext context) => _CompanyCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          YorksV1CompanyMaterialRequestStrings.materialItems.active(language),
          style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
        ),
        for (var index = 0; index < lines.length; index++) ...[
          const SizedBox(height: AppSpacing.sm),
          _CompanyLineFields(
            key: ValueKey(lines[index].id),
            language: language,
            line: lines[index],
            canDelete: lines.length > 1,
            onChanged: (line) {
              final next = [...lines]
                ..[index] = line.copyWith(displayOrder: index + 1);
              onChanged(next);
            },
            onDelete: () => onChanged([
              for (var i = 0; i < lines.length; i++)
                if (i != index)
                  lines[i].copyWith(displayOrder: i < index ? i + 1 : i),
            ]),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: () {
            const uuid = Uuid();
            onChanged([
              ...lines,
              YorksV1CompanyMaterialRequestLine(
                id: uuid.v4(),
                displayOrder: lines.length + 1,
                description: '',
                quantity: '',
                unit: '',
              ),
            ]);
          },
          icon: const Icon(Icons.add_rounded),
          label: Text(
            YorksV1CompanyMaterialRequestStrings.addItem.active(language),
          ),
        ),
      ],
    ),
  );
}

class _CompanyLineFields extends StatelessWidget {
  const _CompanyLineFields({
    super.key,
    required this.language,
    required this.line,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });
  final AppLanguage language;
  final YorksV1CompanyMaterialRequestLine line;
  final bool canDelete;
  final ValueChanged<YorksV1CompanyMaterialRequestLine> onChanged;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${line.displayOrder}',
                style: AppTypography.labelLarge,
              ),
            ),
            if (canDelete)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        TextFormField(
          initialValue: line.description,
          onChanged: (value) => onChanged(line.copyWith(description: value)),
          decoration: InputDecoration(
            labelText: YorksV1CompanyMaterialRequestStrings.itemDescription
                .active(language),
          ),
        ),
        TextFormField(
          initialValue: line.brandOrigin,
          onChanged: (value) => onChanged(
            line.copyWith(
              brandOrigin: value,
              clearBrandOrigin: value.trim().isEmpty,
            ),
          ),
          decoration: InputDecoration(
            labelText: YorksV1CompanyMaterialRequestStrings.brandOrigin.active(
              language,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: line.quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (value) => onChanged(line.copyWith(quantity: value)),
                decoration: InputDecoration(
                  labelText: YorksV1CompanyMaterialRequestStrings.quantity
                      .active(language),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextFormField(
                initialValue: line.unit,
                onChanged: (value) => onChanged(line.copyWith(unit: value)),
                decoration: InputDecoration(
                  labelText: YorksV1CompanyMaterialRequestStrings.unit.active(
                    language,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.language,
    required this.checking,
    required this.routeUnavailable,
    required this.preflight,
  });
  final AppLanguage language;
  final bool checking;
  final bool routeUnavailable;
  final YorksV1CompanyMaterialRequestApprovalPreflight? preflight;
  @override
  Widget build(BuildContext context) => _CompanyCard(
    child: checking
        ? const LinearProgressIndicator()
        : preflight != null
        ? Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: AppColors.success,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${YorksV1CompanyMaterialRequestStrings.approver.active(language)}: ${preflight!.approver.displayName}',
                  style: AppTypography.bodyMedium,
                ),
              ),
            ],
          )
        : routeUnavailable
        ? Text(
            YorksV1CompanyMaterialRequestStrings.routeUnavailable.active(
              language,
            ),
            style: AppTypography.bodyMedium.copyWith(color: AppColors.warning),
          )
        : Text(
            YorksV1CompanyMaterialRequestStrings.approver.active(language),
            style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
          ),
  );
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
    child: child,
  );
}
