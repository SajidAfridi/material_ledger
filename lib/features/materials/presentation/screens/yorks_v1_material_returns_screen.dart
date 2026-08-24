import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/yorks_v1_material_return_strings.dart';
import '../../../../shared/models/yorks_v1_material_return_workflow.dart';
import '../../../../shared/models/yorks_v1_quantity.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_boq_workbook_provider.dart';
import '../../../../shared/providers/yorks_v1_identity_provider.dart';
import '../../../../shared/providers/yorks_v1_logistics_provider.dart';
import '../../../../shared/providers/yorks_v1_logistics_repository_provider.dart';
import '../../../../shared/repositories/yorks_v1_logistics_repository.dart';
import '../../../../shared/services/yorks_v1_logistics_document_service.dart';

class YorksV1MaterialReturnsScreen extends ConsumerStatefulWidget {
  const YorksV1MaterialReturnsScreen({super.key});

  @override
  ConsumerState<YorksV1MaterialReturnsScreen> createState() =>
      _YorksV1MaterialReturnsScreenState();
}

class _YorksV1MaterialReturnsScreenState
    extends ConsumerState<YorksV1MaterialReturnsScreen> {
  final _searchController = TextEditingController();
  String? _state;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final query = YorksV1MaterialReturnRegisterQuery(
      state: _state,
      search: _searchController.text.trim(),
    );
    final returns = ref.watch(yorksV1MaterialReturnRegisterProvider(query));
    final compact = MediaQuery.sizeOf(context).width < 760;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(yorksV1MaterialReturnRegisterProvider);
            await ref.read(yorksV1MaterialReturnRegisterProvider(query).future);
          },
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: compact
                  ? AppSpacing.mobileScreenHorizontal
                  : AppSpacing.screenHorizontal,
              vertical: compact
                  ? AppSpacing.mobileScreenVertical
                  : AppSpacing.screenVertical,
            ),
            children: [
              YorksR35PageHeader(
                eyebrow: YorksV1MaterialReturnStrings.workspace.active(
                  language,
                ),
                title: YorksV1MaterialReturnStrings.centre.active(language),
                description: YorksV1MaterialReturnStrings.centreDescription
                    .active(language),
                actions: [
                  if (role?.canCreateMaterialReturn == true)
                    PrimaryButton(
                      label: YorksV1MaterialReturnStrings.newReturn.active(
                        language,
                      ),
                      icon: Icons.add_rounded,
                      isExpanded: false,
                      onPressed: () =>
                          context.go(RoutePaths.yorksV1MaterialReturnNew),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _FlowBanner(language: language),
              const SizedBox(height: AppSpacing.lg),
              _ReturnFilters(
                language: language,
                searchController: _searchController,
                state: _state,
                onSearch: () => setState(() {}),
                onStateChanged: (value) => setState(() => _state = value),
              ),
              const SizedBox(height: AppSpacing.md),
              returns.when(
                loading: () => const _ReturnLoading(),
                error: (_, _) => _ReturnError(
                  language: language,
                  onRetry: () => ref.invalidate(
                    yorksV1MaterialReturnRegisterProvider(query),
                  ),
                ),
                data: (items) => items.isEmpty
                    ? _ReturnEmpty(language: language)
                    : _ReturnRegister(
                        items: items,
                        language: language,
                        compact: compact,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlowBanner extends StatelessWidget {
  const _FlowBanner({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.blueContainer,
      border: Border.all(color: AppColors.blueContainerStrong),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
    child: Row(
      children: [
        const Icon(Icons.sync_alt_rounded, color: AppColors.blue),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            YorksV1MaterialReturnStrings.controlledFlow.active(language),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.inkSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ReturnFilters extends StatelessWidget {
  const _ReturnFilters({
    required this.language,
    required this.searchController,
    required this.state,
    required this.onSearch,
    required this.onStateChanged,
  });

  final AppLanguage language;
  final TextEditingController searchController;
  final String? state;
  final VoidCallback onSearch;
  final ValueChanged<String?> onStateChanged;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final search = TextField(
      controller: searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSearch(),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: YorksV1MaterialReturnStrings.searchHint.active(language),
        suffixIcon: IconButton(
          tooltip: YorksV1MaterialReturnStrings.searchHint.active(language),
          onPressed: onSearch,
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ),
    );
    final status = DropdownButtonFormField<String?>(
      isExpanded: true,
      initialValue: state,
      decoration: InputDecoration(
        labelText: YorksV1MaterialReturnStrings.status.active(language),
        prefixIcon: const Icon(Icons.filter_alt_outlined),
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(
            YorksV1MaterialReturnStrings.allReturns.active(language),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final value in YorksV1ProjectMaterialReturnState.values)
          DropdownMenuItem<String?>(
            value: value.wireValue,
            child: Text(
              yorksV1ProjectMaterialReturnStateCopy(value).active(language),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onStateChanged,
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _panelDecoration,
      child: compact
          ? Column(
              children: [
                search,
                const SizedBox(height: AppSpacing.md),
                status,
              ],
            )
          : Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: AppSpacing.md),
                SizedBox(width: 260, child: status),
              ],
            ),
    );
  }
}

class _ReturnRegister extends StatelessWidget {
  const _ReturnRegister({
    required this.items,
    required this.language,
    required this.compact,
  });

  final List<YorksV1MaterialReturnRegisterItem> items;
  final AppLanguage language;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.lg),
    decoration: _panelDecoration,
    child: Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _ReturnRegisterTile(
            item: items[index],
            language: language,
            compact: compact,
          ),
          if (index != items.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    ),
  );
}

class _ReturnRegisterTile extends StatelessWidget {
  const _ReturnRegisterTile({
    required this.item,
    required this.language,
    required this.compact,
  });

  final YorksV1MaterialReturnRegisterItem item;
  final AppLanguage language;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final title =
        item.number ??
        yorksV1ProjectMaterialReturnStateCopy(item.state).active(language);
    final state = _ReturnStatePill(state: item.state, language: language);
    return Semantics(
      button: true,
      label: '$title ${item.projectReference} ${item.projectName}',
      child: Material(
        color: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          onTap: () =>
              context.go(RoutePaths.yorksV1MaterialReturnPath(item.id)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const _ReturnIcon(),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              title,
                              style: AppTypography.titleMedium,
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '${item.projectReference} · ${item.projectName}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${item.scopeName} · ${item.lineCount} · ${yorksV1DisplayQuantity(item.totalQuantity)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      state,
                    ],
                  )
                : Row(
                    children: [
                      const _ReturnIcon(),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: AppTypography.titleMedium),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${item.projectReference} · ${item.projectName}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium,
                            ),
                            Text(
                              item.scopeName,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${item.lineCount}',
                          textAlign: TextAlign.center,
                          style: AppTypography.titleMedium,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          yorksV1DisplayQuantity(item.totalQuantity),
                          textAlign: TextAlign.center,
                          style: AppTypography.titleMedium,
                        ),
                      ),
                      SizedBox(width: 190, child: state),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ReturnIcon extends StatelessWidget {
  const _ReturnIcon();

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: AppColors.blueContainer,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: const Icon(Icons.assignment_return_outlined, color: AppColors.blue),
  );
}

class _ReturnStatePill extends StatelessWidget {
  const _ReturnStatePill({required this.state, required this.language});

  final YorksV1ProjectMaterialReturnState state;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (state) {
      YorksV1ProjectMaterialReturnState.confirmed => (
        AppColors.successContainer,
        AppColors.success,
      ),
      YorksV1ProjectMaterialReturnState.rejected ||
      YorksV1ProjectMaterialReturnState.cancelled => (
        AppColors.errorContainer,
        AppColors.error,
      ),
      YorksV1ProjectMaterialReturnState.returnedForChanges => (
        AppColors.warningContainer,
        AppColors.warning,
      ),
      _ => (AppColors.blueContainer, AppColors.blue),
    };
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Text(
          yorksV1ProjectMaterialReturnStateCopy(state).active(language),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelMedium.copyWith(color: foreground),
        ),
      ),
    );
  }
}

class YorksV1MaterialReturnEditorScreen extends ConsumerStatefulWidget {
  const YorksV1MaterialReturnEditorScreen({
    super.key,
    this.initialProjectId,
    this.returnId,
  });

  final String? initialProjectId;
  final String? returnId;

  @override
  ConsumerState<YorksV1MaterialReturnEditorScreen> createState() =>
      _YorksV1MaterialReturnEditorScreenState();
}

class _YorksV1MaterialReturnEditorScreenState
    extends ConsumerState<YorksV1MaterialReturnEditorScreen> {
  final _purposeController = TextEditingController();
  final _noteController = TextEditingController();
  final _candidateQuantities = <String, TextEditingController>{};
  final _customRows = <_CustomReturnRow>[];
  String? _projectId;
  String? _scopeId;
  DateTime? _requestedDate;
  String? _hydratedDraftId;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _projectId = widget.initialProjectId;
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _noteController.dispose();
    for (final controller in _candidateQuantities.values) {
      controller.dispose();
    }
    for (final row in _customRows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final projects = ref.watch(yorksV1MaterialReturnProjectsProvider);
    final workspace = _projectId == null
        ? null
        : ref.watch(
            yorksV1MaterialReturnCreationWorkspaceProvider((
              projectId: _projectId!,
              returnId: widget.returnId,
            )),
          );
    final compact = MediaQuery.sizeOf(context).width < 820;

    if (workspace case AsyncData(:final value)) {
      _hydrate(value);
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: compact
          ? AppBar(
              backgroundColor: AppColors.surface,
              title: Text(
                YorksV1MaterialReturnStrings.newReturn.active(language),
              ),
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: compact
                ? AppSpacing.mobileScreenHorizontal
                : AppSpacing.screenHorizontal,
            vertical: AppSpacing.screenVertical,
          ),
          children: [
            if (!compact)
              YorksR35PageHeader(
                eyebrow: YorksV1MaterialReturnStrings.workspace.active(
                  language,
                ),
                title: YorksV1MaterialReturnStrings.newReturn.active(language),
                description: YorksV1MaterialReturnStrings.controlledFlow.active(
                  language,
                ),
              ),
            if (!compact) const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: _panelDecoration,
              child: projects.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => _ReturnError(
                  language: language,
                  onRetry: () =>
                      ref.invalidate(yorksV1MaterialReturnProjectsProvider),
                ),
                data: (values) => DropdownButtonFormField<String>(
                  initialValue: values.any((item) => item.id == _projectId)
                      ? _projectId
                      : null,
                  decoration: InputDecoration(
                    labelText: YorksV1MaterialReturnStrings.project.active(
                      language,
                    ),
                    prefixIcon: const Icon(Icons.folder_outlined),
                  ),
                  items: [
                    for (final project in values)
                      DropdownMenuItem(
                        value: project.id,
                        child: Text(
                          '${project.reference} · ${project.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _working
                      ? null
                      : (value) => setState(() {
                          _projectId = value;
                          _scopeId = null;
                          _hydratedDraftId = null;
                          _clearCandidateControllers();
                        }),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (workspace == null)
              _EditorNotice(
                icon: Icons.folder_open_outlined,
                copy: YorksV1MaterialReturnStrings.chooseProject.active(
                  language,
                ),
              )
            else
              workspace.when(
                loading: () => const _ReturnLoading(),
                error: (_, _) => _ReturnError(
                  language: language,
                  onRetry: () => ref.invalidate(
                    yorksV1MaterialReturnCreationWorkspaceProvider((
                      projectId: _projectId!,
                      returnId: widget.returnId,
                    )),
                  ),
                ),
                data: (value) =>
                    _buildEditor(context, language, value, compact),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(
    BuildContext context,
    AppLanguage language,
    YorksV1MaterialReturnCreationWorkspace workspace,
    bool compact,
  ) {
    final scopeId = workspace.scopes.any((scope) => scope.id == _scopeId)
        ? _scopeId
        : workspace.scopes.firstOrNull?.id;
    if (_scopeId == null && scopeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scopeId == null) setState(() => _scopeId = scopeId);
      });
    }
    final candidates = workspace.candidates
        .where((item) => scopeId == null || item.scopeId == scopeId)
        .toList(growable: false);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: _panelDecoration,
          child: Column(
            children: [
              if (compact) ...[
                DropdownButtonFormField<String>(
                  initialValue: scopeId,
                  decoration: InputDecoration(
                    labelText: YorksV1MaterialReturnStrings.scope.active(
                      language,
                    ),
                  ),
                  items: [
                    for (final scope in workspace.scopes)
                      DropdownMenuItem(
                        value: scope.id,
                        child: Text(scope.name),
                      ),
                  ],
                  onChanged: _working
                      ? null
                      : (value) => setState(() => _scopeId = value),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _purposeController,
                  decoration: InputDecoration(
                    labelText: YorksV1MaterialReturnStrings.purpose.active(
                      language,
                    ),
                    hintText: YorksV1MaterialReturnStrings.purposeHint.active(
                      language,
                    ),
                  ),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: scopeId,
                        decoration: InputDecoration(
                          labelText: YorksV1MaterialReturnStrings.scope.active(
                            language,
                          ),
                        ),
                        items: [
                          for (final scope in workspace.scopes)
                            DropdownMenuItem(
                              value: scope.id,
                              child: Text(scope.name),
                            ),
                        ],
                        onChanged: _working
                            ? null
                            : (value) => setState(() => _scopeId = value),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _purposeController,
                        decoration: InputDecoration(
                          labelText: YorksV1MaterialReturnStrings.purpose
                              .active(language),
                          hintText: YorksV1MaterialReturnStrings.purposeHint
                              .active(language),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: YorksV1MaterialReturnStrings.notes.active(
                    language,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: _working ? null : () => _pickDate(context),
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _requestedDate == null
                        ? YorksV1MaterialReturnStrings.requestedDate.active(
                            language,
                          )
                        : DateFormat.yMMMd().format(_requestedDate!),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _ReturnLineEditor(
          language: language,
          candidates: candidates,
          candidateQuantities: _candidateQuantities,
          customRows: _customRows,
          units: workspace.units,
          compact: compact,
          enabled: !_working,
          onAddCustom: () => setState(() {
            _customRows.add(
              _CustomReturnRow(unit: workspace.units.firstOrNull),
            );
          }),
          onRemoveCustom: (row) => setState(() {
            row.dispose();
            _customRows.remove(row);
          }),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          alignment: WrapAlignment.end,
          children: [
            SizedBox(
              width: compact ? double.infinity : 190,
              child: SecondaryButton(
                label: YorksV1MaterialReturnStrings.saveDraft.active(language),
                icon: Icons.save_outlined,
                onPressed: _working
                    ? null
                    : () => _save(workspace, submit: false),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 230,
              child: PrimaryButton(
                label: YorksV1MaterialReturnStrings.submitForApproval.active(
                  language,
                ),
                icon: Icons.send_rounded,
                isLoading: _working,
                onPressed: _working
                    ? null
                    : () => _save(workspace, submit: true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _hydrate(YorksV1MaterialReturnCreationWorkspace workspace) {
    final draft = workspace.draft;
    if (draft == null || _hydratedDraftId == draft.id) return;
    _hydratedDraftId = draft.id;
    _scopeId = draft.scopeId;
    _purposeController.text = draft.purpose ?? '';
    _noteController.text = draft.note ?? '';
    _requestedDate = draft.requestedReturnDate;
    _clearCandidateControllers();
    for (final line in draft.lines) {
      if (line.origin == YorksV1ReturnLineOrigin.delivered &&
          line.receiptReviewLineId != null) {
        _candidateQuantities[line.receiptReviewLineId!] = TextEditingController(
          text: yorksV1DisplayQuantity(line.returnQuantity),
        );
      } else {
        _customRows.add(
          _CustomReturnRow(
            description: line.description,
            brandOrigin: line.brandOrigin,
            quantity: yorksV1DisplayQuantity(line.returnQuantity),
            unit: line.unit,
            note: line.lineNote,
          ),
        );
      }
    }
  }

  void _clearCandidateControllers() {
    for (final controller in _candidateQuantities.values) {
      controller.dispose();
    }
    _candidateQuantities.clear();
    for (final row in _customRows) {
      row.dispose();
    }
    _customRows.clear();
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _requestedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null && mounted) setState(() => _requestedDate = picked);
  }

  Future<void> _save(
    YorksV1MaterialReturnCreationWorkspace workspace, {
    required bool submit,
  }) async {
    final language = ref.read(languageProvider);
    if (_purposeController.text.trim().isEmpty) {
      _toast(
        context,
        YorksV1MaterialReturnStrings.purposeRequired.active(language),
        error: true,
      );
      return;
    }
    final lines = <YorksV1MaterialReturnDraftLineInput>[];
    for (final candidate in workspace.candidates.where(
      (candidate) => candidate.scopeId == _scopeId,
    )) {
      final quantity = _candidateQuantities[candidate.receiptReviewLineId]?.text
          .trim();
      if ((double.tryParse(quantity ?? '') ?? 0) > 0) {
        lines.add(
          YorksV1MaterialReturnDraftLineInput(
            origin: YorksV1ReturnLineOrigin.delivered,
            receiptReviewLineId: candidate.receiptReviewLineId,
            quantity: quantity!,
          ),
        );
      }
    }
    for (final row in _customRows) {
      if ((double.tryParse(row.quantity.text.trim()) ?? 0) <= 0) continue;
      if (row.description.text.trim().isEmpty || row.unit.trim().isEmpty) {
        _toast(
          context,
          YorksV1MaterialReturnStrings.customLineRequired.active(language),
          error: true,
        );
        return;
      }
      lines.add(
        YorksV1MaterialReturnDraftLineInput(
          origin: YorksV1ReturnLineOrigin.custom,
          description: row.description.text,
          brandOrigin: row.brandOrigin.text,
          unit: row.unit,
          quantity: row.quantity.text,
          note: row.note.text,
        ),
      );
    }
    if (lines.isEmpty || _scopeId == null) {
      _toast(
        context,
        YorksV1MaterialReturnStrings.atLeastOneLine.active(language),
        error: true,
      );
      return;
    }
    setState(() => _working = true);
    try {
      final repository = _returnRepository(ref);
      var saved = await repository.saveProjectMaterialReturnDraft(
        YorksV1SaveMaterialReturnDraftInput(
          returnId: workspace.draft?.id,
          projectId: workspace.projectId,
          scopeId: _scopeId!,
          expectedVersion: workspace.draft?.recordVersion ?? 0,
          purpose: _purposeController.text,
          note: _noteController.text,
          requestedReturnDate: _requestedDate,
          lines: lines,
          idempotencyKey: const Uuid().v4(),
        ),
      );
      if (submit) {
        saved = await repository.submitProjectMaterialReturn(
          YorksV1MaterialReturnCommandInput(
            returnId: saved.id,
            expectedVersion: saved.recordVersion,
            idempotencyKey: const Uuid().v4(),
          ),
        );
      }
      if (!mounted) return;
      ref.invalidate(yorksV1MaterialReturnRegisterProvider);
      context.go(RoutePaths.yorksV1MaterialReturnPath(saved.id));
      _toast(
        context,
        submit
            ? YorksV1MaterialReturnStrings.updated.active(language)
            : YorksV1MaterialReturnStrings.saved.active(language),
      );
    } catch (_) {
      if (mounted) {
        _toast(
          context,
          YorksV1MaterialReturnStrings.failed.active(language),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}

class _ReturnLineEditor extends StatelessWidget {
  const _ReturnLineEditor({
    required this.language,
    required this.candidates,
    required this.candidateQuantities,
    required this.customRows,
    required this.units,
    required this.compact,
    required this.enabled,
    required this.onAddCustom,
    required this.onRemoveCustom,
  });

  final AppLanguage language;
  final List<YorksV1MaterialReturnCandidate> candidates;
  final Map<String, TextEditingController> candidateQuantities;
  final List<_CustomReturnRow> customRows;
  final List<String> units;
  final bool compact;
  final bool enabled;
  final VoidCallback onAddCustom;
  final ValueChanged<_CustomReturnRow> onRemoveCustom;

  @override
  Widget build(BuildContext context) => Container(
    decoration: _panelDecoration,
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            YorksV1MaterialReturnStrings.deliveredMaterials.active(language),
            style: AppTypography.titleLarge,
          ),
        ),
        if (candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Text(
              YorksV1MaterialReturnStrings.noDeliveredItems.active(language),
              style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
            ),
          )
        else if (compact)
          for (final item in candidates)
            _CandidateCard(
              item: item,
              language: language,
              controller: candidateQuantities.putIfAbsent(
                item.receiptReviewLineId,
                TextEditingController.new,
              ),
              enabled: enabled,
            )
        else
          _CandidateTable(
            candidates: candidates,
            language: language,
            quantities: candidateQuantities,
            enabled: enabled,
          ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  YorksV1MaterialReturnStrings.customMaterials.active(language),
                  style: AppTypography.titleLarge,
                ),
              ),
              OutlinedButton.icon(
                onPressed: enabled ? onAddCustom : null,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  YorksV1MaterialReturnStrings.addCustomRow.active(language),
                ),
              ),
            ],
          ),
        ),
        for (final row in customRows)
          _CustomRowEditor(
            row: row,
            language: language,
            compact: compact,
            units: units,
            enabled: enabled,
            onRemove: () => onRemoveCustom(row),
          ),
        if (customRows.isEmpty) const SizedBox(height: AppSpacing.sm),
      ],
    ),
  );
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.item,
    required this.language,
    required this.controller,
    required this.enabled,
  });

  final YorksV1MaterialReturnCandidate item;
  final AppLanguage language;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      AppSpacing.sm,
    ),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.description, style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${item.requestNumber} · ${item.dispatchNumber}',
          style: AppTypography.bodySmall.copyWith(color: AppColors.blue),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                '${YorksV1MaterialReturnStrings.available.active(language)}: ${yorksV1DisplayQuantity(item.eligibleReturnQuantity)} ${item.unit}',
                style: AppTypography.bodySmall,
              ),
            ),
            SizedBox(
              width: 105,
              child: TextField(
                controller: controller,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: YorksV1MaterialReturnStrings.quantity.active(
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

class _CandidateTable extends StatefulWidget {
  const _CandidateTable({
    required this.candidates,
    required this.language,
    required this.quantities,
    required this.enabled,
  });

  final List<YorksV1MaterialReturnCandidate> candidates;
  final AppLanguage language;
  final Map<String, TextEditingController> quantities;
  final bool enabled;

  @override
  State<_CandidateTable> createState() => _CandidateTableState();
}

class _CandidateTableState extends State<_CandidateTable> {
  final _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(
            AppColors.surfaceContainerLow,
          ),
          columns: [
            DataColumn(
              label: Text(
                YorksV1MaterialReturnStrings.description.active(
                  widget.language,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                YorksV1MaterialReturnStrings.sourceReference.active(
                  widget.language,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                YorksV1MaterialReturnStrings.available.active(widget.language),
              ),
            ),
            DataColumn(
              label: Text(
                YorksV1MaterialReturnStrings.quantity.active(widget.language),
              ),
            ),
            DataColumn(
              label: Text(
                YorksV1MaterialReturnStrings.unit.active(widget.language),
              ),
            ),
          ],
          rows: [
            for (final item in widget.candidates)
              DataRow(
                cells: [
                  DataCell(SizedBox(width: 320, child: Text(item.description))),
                  DataCell(
                    Text('${item.requestNumber} · ${item.dispatchNumber}'),
                  ),
                  DataCell(
                    Text(yorksV1DisplayQuantity(item.eligibleReturnQuantity)),
                  ),
                  DataCell(
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: widget.quantities.putIfAbsent(
                          item.receiptReviewLineId,
                          TextEditingController.new,
                        ),
                        enabled: widget.enabled,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(item.unit)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CustomRowEditor extends StatelessWidget {
  const _CustomRowEditor({
    required this.row,
    required this.language,
    required this.compact,
    required this.enabled,
    required this.onRemove,
    required this.units,
  });

  final _CustomReturnRow row;
  final AppLanguage language;
  final bool compact;
  final bool enabled;
  final VoidCallback onRemove;
  final List<String> units;

  @override
  Widget build(BuildContext context) {
    final description = TextField(
      controller: row.description,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: YorksV1MaterialReturnStrings.description.active(language),
      ),
    );
    final brand = TextField(
      controller: row.brandOrigin,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: YorksV1MaterialReturnStrings.brandOrigin.active(language),
      ),
    );
    final quantity = TextField(
      controller: row.quantity,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: YorksV1MaterialReturnStrings.quantity.active(language),
      ),
    );
    final unit = DropdownButtonFormField<String>(
      initialValue: units.contains(row.unit) ? row.unit : null,
      decoration: InputDecoration(
        labelText: YorksV1MaterialReturnStrings.unit.active(language),
      ),
      items: [
        for (final unit in units)
          DropdownMenuItem(value: unit, child: Text(unit)),
      ],
      onChanged: enabled ? (value) => row.unit = value ?? row.unit : null,
    );
    final remove = IconButton(
      tooltip: YorksV1MaterialReturnStrings.remove.active(language),
      onPressed: enabled ? onRemove : null,
      icon: const Icon(Icons.close_rounded, color: AppColors.error),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: compact
          ? Column(
              children: [
                description,
                const SizedBox(height: AppSpacing.sm),
                brand,
                const SizedBox(height: AppSpacing.sm),
                quantity,
                const SizedBox(height: AppSpacing.sm),
                unit,
                Align(alignment: AlignmentDirectional.centerEnd, child: remove),
                TextField(
                  controller: row.note,
                  enabled: enabled,
                  decoration: InputDecoration(
                    labelText: YorksV1MaterialReturnStrings.notes.active(
                      language,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 3, child: description),
                const SizedBox(width: AppSpacing.sm),
                Expanded(flex: 2, child: brand),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(width: 120, child: quantity),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(width: 150, child: unit),
                const SizedBox(width: AppSpacing.sm),
                remove,
              ],
            ),
    );
  }
}

class _CustomReturnRow {
  _CustomReturnRow({
    String? description,
    String? brandOrigin,
    String? quantity,
    String? unit,
    String? note,
  }) : description = TextEditingController(text: description),
       brandOrigin = TextEditingController(text: brandOrigin),
       quantity = TextEditingController(text: quantity),
       unit = unit ?? '',
       note = TextEditingController(text: note);

  final TextEditingController description;
  final TextEditingController brandOrigin;
  final TextEditingController quantity;
  String unit;
  final TextEditingController note;

  void dispose() {
    description.dispose();
    brandOrigin.dispose();
    quantity.dispose();
    note.dispose();
  }
}

class YorksV1MaterialReturnDetailScreen extends ConsumerStatefulWidget {
  const YorksV1MaterialReturnDetailScreen({super.key, required this.returnId});

  final String returnId;

  @override
  ConsumerState<YorksV1MaterialReturnDetailScreen> createState() =>
      _YorksV1MaterialReturnDetailScreenState();
}

class _YorksV1MaterialReturnDetailScreenState
    extends ConsumerState<YorksV1MaterialReturnDetailScreen> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final detail = ref.watch(
      yorksV1ProjectMaterialReturnProvider(widget.returnId),
    );
    final compact = MediaQuery.sizeOf(context).width < 820;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: compact
          ? AppBar(
              backgroundColor: AppColors.surface,
              title: Text(YorksV1MaterialReturnStrings.centre.active(language)),
            )
          : null,
      body: SafeArea(
        child: detail.when(
          loading: () => const _ReturnLoading(),
          error: (_, _) => _ReturnError(
            language: language,
            onRetry: () => ref.invalidate(
              yorksV1ProjectMaterialReturnProvider(widget.returnId),
            ),
          ),
          data: (value) => _detailBody(value, language, compact),
        ),
      ),
    );
  }

  Widget _detailBody(
    YorksV1ProjectMaterialReturn value,
    AppLanguage language,
    bool compact,
  ) => ListView(
    padding: EdgeInsets.symmetric(
      horizontal: compact
          ? AppSpacing.mobileScreenHorizontal
          : AppSpacing.screenHorizontal,
      vertical: AppSpacing.screenVertical,
    ),
    children: [
      YorksR35PageHeader(
        eyebrow: YorksV1MaterialReturnStrings.workspace.active(language),
        title:
            value.number ??
            yorksV1ProjectMaterialReturnStateCopy(value.state).active(language),
        description: '${value.projectReference} · ${value.projectName}',
        actions: [_ReturnStatePill(state: value.state, language: language)],
      ),
      const SizedBox(height: AppSpacing.lg),
      _ReturnSummary(detail: value, language: language, compact: compact),
      const SizedBox(height: AppSpacing.md),
      _ReturnDetailLines(detail: value, language: language, compact: compact),
      const SizedBox(height: AppSpacing.lg),
      _actionBar(value, language, compact),
    ],
  );

  Widget _actionBar(
    YorksV1ProjectMaterialReturn detail,
    AppLanguage language,
    bool compact,
  ) {
    final actions = <Widget>[
      if (detail.canEdit)
        SecondaryButton(
          label: YorksV1MaterialReturnStrings.saveDraft.active(language),
          icon: Icons.edit_outlined,
          isExpanded: compact,
          onPressed: _working
              ? null
              : () => context.go(
                  RoutePaths.yorksV1MaterialReturnEditPath(
                    detail.projectId,
                    detail.id,
                  ),
                ),
        ),
      if (detail.canSubmit)
        PrimaryButton(
          label: YorksV1MaterialReturnStrings.submitForApproval.active(
            language,
          ),
          icon: Icons.send_rounded,
          isExpanded: compact,
          onPressed: _working ? null : () => _submit(detail),
        ),
      if (detail.canApprove)
        PrimaryButton(
          label: YorksV1MaterialReturnStrings.approve.active(language),
          icon: Icons.verified_outlined,
          isExpanded: compact,
          onPressed: _working
              ? null
              : () =>
                    _decide(detail, YorksV1ProjectMaterialReturnState.approved),
        ),
      if (detail.canReturnForChanges)
        SecondaryButton(
          label: YorksV1MaterialReturnStrings.returnForChanges.active(language),
          icon: Icons.undo_rounded,
          isExpanded: compact,
          onPressed: _working
              ? null
              : () => _decisionWithReason(
                  detail,
                  YorksV1ProjectMaterialReturnState.returnedForChanges,
                ),
        ),
      if (detail.canApprove)
        SecondaryButton(
          label: YorksV1MaterialReturnStrings.reject.active(language),
          icon: Icons.close_rounded,
          isExpanded: compact,
          onPressed: _working
              ? null
              : () => _decisionWithReason(
                  detail,
                  YorksV1ProjectMaterialReturnState.rejected,
                ),
        ),
      if (detail.canDispatch)
        PrimaryButton(
          label: YorksV1MaterialReturnStrings.dispatchToWarehouse.active(
            language,
          ),
          icon: Icons.local_shipping_outlined,
          isExpanded: compact,
          onPressed: _working ? null : () => _dispatch(detail),
        ),
      if (detail.canConfirm)
        PrimaryButton(
          label: YorksV1MaterialReturnStrings.confirmReceipt.active(language),
          icon: Icons.inventory_outlined,
          isExpanded: compact,
          onPressed: _working ? null : () => _confirm(detail),
        ),
      if (detail.canCancel)
        SecondaryButton(
          label: YorksV1MaterialReturnStrings.cancelReturn.active(language),
          icon: Icons.block_outlined,
          isExpanded: compact,
          onPressed: _working ? null : () => _cancel(detail),
        ),
      SecondaryButton(
        label: YorksV1MaterialReturnStrings.print.active(language),
        icon: Icons.print_outlined,
        isExpanded: compact,
        onPressed: _working
            ? null
            : () => const YorksV1LogisticsDocumentService()
                  .printProjectMaterialReturn(detail),
      ),
      SecondaryButton(
        label: YorksV1MaterialReturnStrings.downloadPdf.active(language),
        icon: Icons.picture_as_pdf_outlined,
        isExpanded: compact,
        onPressed: _working
            ? null
            : () => const YorksV1LogisticsDocumentService()
                  .shareProjectMaterialReturnPdf(detail),
      ),
      SecondaryButton(
        label: YorksV1MaterialReturnStrings.exportExcel.active(language),
        icon: Icons.file_download_outlined,
        isExpanded: compact,
        onPressed: _working ? null : () => _export(detail),
      ),
    ];
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      alignment: WrapAlignment.end,
      children: [
        for (final action in actions)
          SizedBox(width: compact ? double.infinity : 220, child: action),
      ],
    );
  }

  Future<void> _run(
    Future<YorksV1ProjectMaterialReturn> Function() command,
  ) async {
    final language = ref.read(languageProvider);
    setState(() => _working = true);
    try {
      await command();
      ref.invalidate(yorksV1ProjectMaterialReturnProvider(widget.returnId));
      ref.invalidate(yorksV1MaterialReturnRegisterProvider);
      if (mounted) {
        _toast(context, YorksV1MaterialReturnStrings.updated.active(language));
      }
    } catch (_) {
      if (mounted) {
        _toast(
          context,
          YorksV1MaterialReturnStrings.failed.active(language),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _submit(YorksV1ProjectMaterialReturn detail) => _run(
    () => _returnRepository(ref).submitProjectMaterialReturn(
      YorksV1MaterialReturnCommandInput(
        returnId: detail.id,
        expectedVersion: detail.recordVersion,
        idempotencyKey: const Uuid().v4(),
      ),
    ),
  );

  Future<void> _decide(
    YorksV1ProjectMaterialReturn detail,
    YorksV1ProjectMaterialReturnState decision, {
    String? reason,
  }) => _run(
    () => _returnRepository(ref).decideProjectMaterialReturn(
      YorksV1MaterialReturnDecisionInput(
        returnId: detail.id,
        expectedVersion: detail.recordVersion,
        idempotencyKey: const Uuid().v4(),
        decision: decision,
        reason: reason,
      ),
    ),
  );

  Future<void> _decisionWithReason(
    YorksV1ProjectMaterialReturn detail,
    YorksV1ProjectMaterialReturnState decision,
  ) async {
    final reason = await _textDialog(
      context,
      title: decision == YorksV1ProjectMaterialReturnState.rejected
          ? YorksV1MaterialReturnStrings.reject.active(
              ref.read(languageProvider),
            )
          : YorksV1MaterialReturnStrings.returnForChanges.active(
              ref.read(languageProvider),
            ),
      label: YorksV1MaterialReturnStrings.reason.active(
        ref.read(languageProvider),
      ),
    );
    if (reason != null && reason.trim().isNotEmpty) {
      await _decide(detail, decision, reason: reason);
    }
  }

  Future<void> _dispatch(YorksV1ProjectMaterialReturn detail) async {
    final result = await showDialog<_DispatchValues>(
      context: context,
      builder: (_) => _DispatchDialog(language: ref.read(languageProvider)),
    );
    if (result == null) return;
    await _run(
      () => _returnRepository(ref).dispatchProjectMaterialReturn(
        YorksV1MaterialReturnDispatchInput(
          returnId: detail.id,
          expectedVersion: detail.recordVersion,
          idempotencyKey: const Uuid().v4(),
          driverName: result.driver,
          vehicleReference: result.vehicle,
          deliveryNoteReference: result.deliveryNote,
        ),
      ),
    );
  }

  Future<void> _confirm(YorksV1ProjectMaterialReturn detail) async {
    final result = await showModalBottomSheet<_ReceiptValues>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      builder: (_) =>
          _ReceiptSheet(detail: detail, language: ref.read(languageProvider)),
    );
    if (result == null) return;
    await _run(
      () => _returnRepository(ref).confirmProjectMaterialReturn(
        YorksV1MaterialReturnReceiptInput(
          returnId: detail.id,
          expectedVersion: detail.recordVersion,
          idempotencyKey: const Uuid().v4(),
          receiptNote: result.note,
          lineReceipts: result.lines,
        ),
      ),
    );
  }

  Future<void> _cancel(YorksV1ProjectMaterialReturn detail) async {
    final language = ref.read(languageProvider);
    final reason = await _textDialog(
      context,
      title: YorksV1MaterialReturnStrings.cancelReturn.active(language),
      label: YorksV1MaterialReturnStrings.reason.active(language),
    );
    if (reason == null || reason.trim().isEmpty) return;
    await _run(
      () => _returnRepository(ref).cancelProjectMaterialReturn(
        YorksV1MaterialReturnCancellationInput(
          returnId: detail.id,
          expectedVersion: detail.recordVersion,
          idempotencyKey: const Uuid().v4(),
          reason: reason,
        ),
      ),
    );
  }

  Future<void> _export(YorksV1ProjectMaterialReturn detail) async {
    final documents = const YorksV1LogisticsDocumentService();
    await ref
        .read(yorksV1BoqWorkbookFileServiceProvider)
        .saveWorkbook(
          bytes: documents.buildProjectMaterialReturnExcel(detail),
          suggestedName: documents.suggestedProjectMaterialReturnExcelName(
            detail,
          ),
        );
  }
}

class _ReturnSummary extends StatelessWidget {
  const _ReturnSummary({
    required this.detail,
    required this.language,
    required this.compact,
  });

  final YorksV1ProjectMaterialReturn detail;
  final AppLanguage language;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final values = <(String, String)>[
      (
        YorksV1MaterialReturnStrings.project.active(language),
        detail.projectReference,
      ),
      (YorksV1MaterialReturnStrings.scope.active(language), detail.scopeName),
      (
        YorksV1MaterialReturnStrings.purpose.active(language),
        detail.purpose ?? '—',
      ),
      if (detail.driverName != null)
        (
          YorksV1MaterialReturnStrings.driverName.active(language),
          detail.driverName!,
        ),
      if (detail.vehicleReference != null)
        (
          YorksV1MaterialReturnStrings.vehicleReference.active(language),
          detail.vehicleReference!,
        ),
      if (detail.deliveryNoteReference != null)
        (
          YorksV1MaterialReturnStrings.deliveryNote.active(language),
          detail.deliveryNoteReference!,
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _panelDecoration,
      child: Wrap(
        spacing: AppSpacing.xxl,
        runSpacing: AppSpacing.lg,
        children: [
          for (final value in values)
            SizedBox(
              width: compact ? double.infinity : 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.$1,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(value.$2, style: AppTypography.bodyLarge),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReturnDetailLines extends StatefulWidget {
  const _ReturnDetailLines({
    required this.detail,
    required this.language,
    required this.compact,
  });

  final YorksV1ProjectMaterialReturn detail;
  final AppLanguage language;
  final bool compact;

  @override
  State<_ReturnDetailLines> createState() => _ReturnDetailLinesState();
}

class _ReturnDetailLinesState extends State<_ReturnDetailLines> {
  final _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: _panelDecoration,
    child: widget.compact
        ? Column(
            children: [
              for (final line in widget.detail.lines)
                _DetailLineCard(line: line, language: widget.language),
            ],
          )
        : Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('#')),
                  DataColumn(
                    label: Text(
                      YorksV1MaterialReturnStrings.description.active(
                        widget.language,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      YorksV1MaterialReturnStrings.sourceReference.active(
                        widget.language,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      YorksV1MaterialReturnStrings.quantity.active(
                        widget.language,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      YorksV1MaterialReturnStrings.unit.active(widget.language),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      YorksV1MaterialReturnStrings.notes.active(
                        widget.language,
                      ),
                    ),
                  ),
                ],
                rows: [
                  for (final line in widget.detail.lines)
                    DataRow(
                      cells: [
                        DataCell(Text('${line.displayOrder}')),
                        DataCell(
                          SizedBox(width: 320, child: Text(line.description)),
                        ),
                        DataCell(
                          Text(
                            line.origin == YorksV1ReturnLineOrigin.custom
                                ? YorksV1MaterialReturnStrings.customMaterials
                                      .active(widget.language)
                                : [
                                    line.sourceRequestNumber,
                                    line.sourceDispatchNumber,
                                  ].whereType<String>().join(' · '),
                          ),
                        ),
                        DataCell(
                          Text(yorksV1DisplayQuantity(line.returnQuantity)),
                        ),
                        DataCell(Text(line.unit)),
                        DataCell(Text(line.lineNote ?? '—')),
                      ],
                    ),
                ],
              ),
            ),
          ),
  );
}

class _DetailLineCard extends StatelessWidget {
  const _DetailLineCard({required this.line, required this.language});
  final YorksV1MaterialReturnLineRecord line;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(line.description, style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          line.origin == YorksV1ReturnLineOrigin.custom
              ? YorksV1MaterialReturnStrings.customMaterials.active(language)
              : [
                  line.sourceRequestNumber,
                  line.sourceDispatchNumber,
                ].whereType<String>().join(' · '),
          style: AppTypography.bodySmall.copyWith(color: AppColors.blue),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${yorksV1DisplayQuantity(line.returnQuantity)} ${line.unit}',
          style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _DispatchDialog extends StatefulWidget {
  const _DispatchDialog({required this.language});
  final AppLanguage language;

  @override
  State<_DispatchDialog> createState() => _DispatchDialogState();
}

class _DispatchDialogState extends State<_DispatchDialog> {
  final driver = TextEditingController();
  final vehicle = TextEditingController();
  final deliveryNote = TextEditingController();

  @override
  void dispose() {
    driver.dispose();
    vehicle.dispose();
    deliveryNote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      YorksV1MaterialReturnStrings.dispatchToWarehouse.active(widget.language),
    ),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: driver,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: YorksV1MaterialReturnStrings.driverName.active(
                widget.language,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: vehicle,
            decoration: InputDecoration(
              labelText: YorksV1MaterialReturnStrings.vehicleReference.active(
                widget.language,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: deliveryNote,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: YorksV1MaterialReturnStrings.deliveryNote.active(
                widget.language,
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          YorksV1MaterialReturnStrings.cancel.active(widget.language),
        ),
      ),
      FilledButton(
        onPressed:
            driver.text.trim().isEmpty || deliveryNote.text.trim().isEmpty
            ? null
            : () => Navigator.pop(
                context,
                _DispatchValues(
                  driver.text.trim(),
                  vehicle.text.trim(),
                  deliveryNote.text.trim(),
                ),
              ),
        child: Text(
          YorksV1MaterialReturnStrings.continueAction.active(widget.language),
        ),
      ),
    ],
  );
}

class _DispatchValues {
  const _DispatchValues(this.driver, this.vehicle, this.deliveryNote);

  final String driver;
  final String vehicle;
  final String deliveryNote;
}

class _ReceiptSheet extends StatefulWidget {
  const _ReceiptSheet({required this.detail, required this.language});
  final YorksV1ProjectMaterialReturn detail;
  final AppLanguage language;

  @override
  State<_ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends State<_ReceiptSheet> {
  late final Map<String, _ReceiptRow> rows;
  final note = TextEditingController();

  @override
  void initState() {
    super.initState();
    rows = {
      for (final line in widget.detail.lines)
        line.id: _ReceiptRow(
          good: yorksV1DisplayQuantity(line.returnQuantity),
          inventoryItemId: line.sourceInventoryItemId,
        ),
    };
  }

  @override
  void dispose() {
    note.dispose();
    for (final row in rows.values) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 760),
        child: Column(
          children: [
            Text(
              YorksV1MaterialReturnStrings.confirmReceipt.active(
                widget.language,
              ),
              style: AppTypography.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: ListView(
                children: [
                  for (final line in widget.detail.lines)
                    _ReceiptLineEditor(
                      line: line,
                      row: rows[line.id]!,
                      inventory: widget.detail.inventoryItems,
                      language: widget.language,
                      onChanged: () => setState(() {}),
                    ),
                  TextField(
                    controller: note,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: YorksV1MaterialReturnStrings
                          .warehouseReceiptNote
                          .active(widget.language),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: YorksV1MaterialReturnStrings.cancel.active(
                      widget.language,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: PrimaryButton(
                    label: YorksV1MaterialReturnStrings.confirmReceipt.active(
                      widget.language,
                    ),
                    onPressed: _valid
                        ? () => Navigator.pop(
                            context,
                            _ReceiptValues(note.text.trim(), [
                              for (final line in widget.detail.lines)
                                rows[line.id]!.toInput(line),
                            ]),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  bool get _valid {
    for (final line in widget.detail.lines) {
      final row = rows[line.id]!;
      final good = double.tryParse(row.good.text) ?? -1;
      final damaged = double.tryParse(row.damaged.text) ?? -1;
      final missing = double.tryParse(row.missing.text) ?? -1;
      final expected = double.tryParse(line.returnQuantity) ?? 0;
      if (good < 0 || damaged < 0 || missing < 0) return false;
      if ((good + damaged + missing - expected).abs() > 0.0001) return false;
      if (good > 0 && row.inventoryItemId == null && !row.createNewItem) {
        return false;
      }
    }
    return true;
  }
}

class _ReceiptLineEditor extends StatelessWidget {
  const _ReceiptLineEditor({
    required this.line,
    required this.row,
    required this.inventory,
    required this.language,
    required this.onChanged,
  });

  final YorksV1MaterialReturnLineRecord line;
  final _ReceiptRow row;
  final List<YorksV1MaterialReturnInventoryOption> inventory;
  final AppLanguage language;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(line.description, style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _quantityField(
              row.good,
              YorksV1MaterialReturnStrings.goodQuantity.active(language),
            ),
            _quantityField(
              row.damaged,
              YorksV1MaterialReturnStrings.damagedQuantity.active(language),
            ),
            _quantityField(
              row.missing,
              YorksV1MaterialReturnStrings.notReceivedQuantity.active(language),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String?>(
          initialValue: inventory.any((item) => item.id == row.inventoryItemId)
              ? row.inventoryItemId
              : null,
          decoration: InputDecoration(
            labelText: YorksV1MaterialReturnStrings.inventoryMapping.active(
              language,
            ),
          ),
          items: [
            for (final item in inventory)
              DropdownMenuItem(
                value: item.id,
                child: Text(item.description, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            row.inventoryItemId = value;
            row.createNewItem = false;
            onChanged();
          },
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: row.createNewItem,
          title: Text(
            YorksV1MaterialReturnStrings.createWarehouseItem.active(language),
          ),
          onChanged: (value) {
            row.createNewItem = value == true;
            if (row.createNewItem) row.inventoryItemId = null;
            onChanged();
          },
        ),
      ],
    ),
  );

  Widget _quantityField(TextEditingController controller, String label) =>
      SizedBox(
        width: 190,
        child: TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
        ),
      );
}

class _ReceiptRow {
  _ReceiptRow({required String good, this.inventoryItemId})
    : good = TextEditingController(text: good),
      damaged = TextEditingController(text: '0'),
      missing = TextEditingController(text: '0');

  final TextEditingController good;
  final TextEditingController damaged;
  final TextEditingController missing;
  String? inventoryItemId;
  bool createNewItem = false;

  YorksV1MaterialReturnReceiptLineInput toInput(
    YorksV1MaterialReturnLineRecord line,
  ) => YorksV1MaterialReturnReceiptLineInput(
    returnLineId: line.id,
    receivedGoodQuantity: good.text,
    damagedQuantity: damaged.text,
    notReceivedQuantity: missing.text,
    inventoryItemId: inventoryItemId,
    newItemDescription: createNewItem ? line.description : null,
    newItemBrandOrigin: createNewItem ? line.brandOrigin : null,
    unit: createNewItem ? line.unit : null,
  );

  void dispose() {
    good.dispose();
    damaged.dispose();
    missing.dispose();
  }
}

class _ReceiptValues {
  const _ReceiptValues(this.note, this.lines);

  final String note;
  final List<YorksV1MaterialReturnReceiptLineInput> lines;
}

class _ReturnLoading extends StatelessWidget {
  const _ReturnLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(AppSpacing.massive),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _ReturnEmpty extends StatelessWidget {
  const _ReturnEmpty({required this.language});
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => _EditorNotice(
    icon: Icons.assignment_return_outlined,
    copy: YorksV1MaterialReturnStrings.noReturns.active(language),
  );
}

class _ReturnError extends StatelessWidget {
  const _ReturnError({required this.language, required this.onRetry});
  final AppLanguage language;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    decoration: _panelDecoration,
    child: Column(
      children: [
        const Icon(Icons.cloud_off_outlined, color: AppColors.muted, size: 42),
        const SizedBox(height: AppSpacing.md),
        Text(
          YorksV1MaterialReturnStrings.failed.active(language),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(
            YorksV1MaterialReturnStrings.continueAction.active(language),
          ),
        ),
      ],
    ),
  );
}

class _EditorNotice extends StatelessWidget {
  const _EditorNotice({required this.icon, required this.copy});
  final IconData icon;
  final String copy;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.massive),
    decoration: _panelDecoration,
    child: Column(
      children: [
        Icon(icon, size: 42, color: AppColors.blue),
        const SizedBox(height: AppSpacing.md),
        Text(copy, textAlign: TextAlign.center, style: AppTypography.bodyLarge),
      ],
    ),
  );
}

YorksV1ProjectMaterialReturnRepository _returnRepository(WidgetRef ref) {
  final repository = ref.read(yorksV1LogisticsRepositoryProvider);
  if (repository is! YorksV1ProjectMaterialReturnRepository) {
    throw StateError('Material return workflow is unavailable.');
  }
  return repository as YorksV1ProjectMaterialReturnRepository;
}

Future<String?> _textDialog(
  BuildContext context, {
  required String title,
  required String label,
}) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        minLines: 2,
        maxLines: 5,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(YorksV1MaterialReturnStrings.cancel.primary),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(YorksV1MaterialReturnStrings.continueAction.primary),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}

void _toast(BuildContext context, String message, {bool error = false}) {
  YorksAppToast.show(
    context,
    title: message,
    tone: error ? YorksAppToastTone.error : YorksAppToastTone.success,
    dismissible: true,
    duration: const Duration(seconds: 4),
  );
}

const _panelDecoration = BoxDecoration(
  color: AppColors.surfaceContainerLowest,
  borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusLg)),
  border: Border.fromBorderSide(BorderSide(color: AppColors.line)),
  boxShadow: [
    BoxShadow(color: AppColors.shadow, blurRadius: 14, offset: Offset(0, 5)),
  ],
);
