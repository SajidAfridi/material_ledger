import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/controllers/yorks_v1_material_request_draft_controller.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_boq.dart';
import '../../../../shared/models/yorks_v1_arrangement_strings.dart';
import '../../../../shared/models/yorks_v1_document.dart';
import '../../../../shared/models/yorks_v1_document_strings.dart';
import '../../../../shared/models/yorks_v1_logistics_strings.dart';
import '../../../../shared/models/yorks_v1_material_request.dart';
import '../../../../shared/models/yorks_v1_material_request_strings.dart';
import '../../../../shared/models/yorks_v1_role.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_boq_repository_provider.dart';
import '../../../../shared/providers/yorks_v1_boq_workbook_provider.dart';
import '../../../../shared/providers/yorks_v1_feature_flags_provider.dart';
import '../../../../shared/providers/yorks_v1_identity_provider.dart';
import '../../../../shared/providers/yorks_v1_documents_repository_provider.dart';
import '../../../../shared/providers/yorks_v1_material_request_provider.dart';
import '../../../../shared/providers/yorks_v1_material_request_repository_provider.dart';
import '../../../../shared/services/yorks_v1_material_request_document_service.dart';

/// V1 material request overview. It reads only the server projection; drafts
/// are returned only to their creator by the database contract.
class YorksV1MaterialRequestsScreen extends ConsumerWidget {
  const YorksV1MaterialRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final requests = ref.watch(yorksV1MaterialRequestListProvider(null));
    final canCreate = role?.canCreateMaterialRequest ?? false;
    final canOpenInventory =
        ref.watch(yorksV1FeatureFlagsProvider).logistics &&
        (role == YorksV1Role.procurement || role == YorksV1Role.admin);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: _CopyText(
          copy: YorksV1MaterialRequestStrings.requests,
          language: language,
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (canOpenInventory)
            IconButton(
              tooltip: YorksV1LogisticsStrings.inventory.primary,
              onPressed: () => context.push(RoutePaths.yorksV1Inventory),
              icon: const Icon(Icons.inventory_2_outlined),
            ),
          IconButton(
            tooltip: YorksV1MaterialRequestStrings.refresh.primary,
            onPressed: () => ref.invalidate(yorksV1MaterialRequestListProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push(
                RoutePaths.yorksV1MaterialRequestDraftPath(const Uuid().v4()),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(YorksV1MaterialRequestStrings.newRequest.primary),
            )
          : null,
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          child: requests.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _RequestError(
              language: language,
              onRetry: () => ref.invalidate(yorksV1MaterialRequestListProvider),
            ),
            data: (items) => items.isEmpty
                ? _EmptyRequests(language: language, canCreate: canCreate)
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) => _RequestCard(
                      request: items[index],
                      language: language,
                      onOpen: () => context.push(
                        RoutePaths.yorksV1MaterialRequestPath(items[index].id),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class YorksV1MaterialRequestDraftScreen extends ConsumerWidget {
  const YorksV1MaterialRequestDraftScreen({super.key, required this.draftId});

  final String draftId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(yorksV1AuthUserIdProvider);
    final language = ref.watch(languageProvider);
    if (owner == null || owner.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(backgroundColor: AppColors.surface),
        body: _RequestError(language: language, onRetry: () {}),
      );
    }
    final key = YorksV1MaterialRequestDraftKey(
      ownerAuthUserId: owner,
      draftId: draftId,
    );
    final state = ref.watch(yorksV1MaterialRequestDraftControllerProvider(key));
    final controller = ref.read(
      yorksV1MaterialRequestDraftControllerProvider(key).notifier,
    );
    return _DraftForm(
      state: state,
      controller: controller,
      draftKey: key,
      language: language,
    );
  }
}

class YorksV1MaterialRequestDetailScreen extends ConsumerWidget {
  const YorksV1MaterialRequestDetailScreen({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final request = ref.watch(yorksV1MaterialRequestDetailProvider(requestId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: _CopyText(
          copy: YorksV1MaterialRequestStrings.requests,
          language: language,
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: YorksV1MaterialRequestStrings.refresh.primary,
            onPressed: () =>
                ref.invalidate(yorksV1MaterialRequestDetailProvider(requestId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: request.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _RequestError(
          language: language,
          onRetry: () =>
              ref.invalidate(yorksV1MaterialRequestDetailProvider(requestId)),
        ),
        data: (value) => _RequestDetailBody(request: value, language: language),
      ),
    );
  }
}

class _DraftForm extends ConsumerWidget {
  const _DraftForm({
    required this.state,
    required this.controller,
    required this.draftKey,
    required this.language,
  });

  final YorksV1MaterialRequestDraftState state;
  final YorksV1MaterialRequestDraftController controller;
  final YorksV1MaterialRequestDraftKey draftKey;
  final AppLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = state.draft;
    final projects = ref.watch(yorksV1MaterialRequestDraftProjectsProvider);
    final scopes = draft.projectId == null
        ? const AsyncData<List<YorksV1MaterialRequestScopeOption>>([])
        : ref.watch(yorksV1MaterialRequestScopesProvider(draft.projectId!));
    final canSubmit =
        draft.canSubmitLocally &&
        state.status != YorksV1MaterialRequestDraftSyncStatus.submitting;
    final isBusy =
        state.status == YorksV1MaterialRequestDraftSyncStatus.saving ||
        state.status == YorksV1MaterialRequestDraftSyncStatus.submitting;
    final excelEnabled = ref.watch(yorksV1FeatureFlagsProvider).excel;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: _CopyText(
          copy: draft.serverRecordVersion == 0
              ? YorksV1MaterialRequestStrings.newRequest
              : YorksV1MaterialRequestStrings.editDraft,
          language: language,
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.pageMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NexusSectionCard(
                    child: _CopyText(
                      copy: YorksV1MaterialRequestStrings.draftPrivate,
                      language: language,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  NexusSectionCard(
                    title: YorksV1MaterialRequestStrings.project.primary,
                    child: _RequestFormFields(
                      draft: draft,
                      projects: projects,
                      scopes: scopes,
                      controller: controller,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  NexusSectionCard(
                    title: YorksV1MaterialRequestStrings.lines.primary,
                    trailing: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        SecondaryButton(
                          label: YorksV1MaterialRequestStrings
                              .addCustomLine
                              .primary,
                          isExpanded: false,
                          icon: Icons.add_rounded,
                          onPressed: isBusy ? null : controller.addCustomLine,
                        ),
                        SecondaryButton(
                          label:
                              YorksV1MaterialRequestStrings.addFromBoq.primary,
                          isExpanded: false,
                          icon: Icons.playlist_add_rounded,
                          onPressed: isBusy || draft.projectId == null
                              ? null
                              : () => _addBoqRows(
                                  context,
                                  ref,
                                  controller,
                                  draft,
                                ),
                        ),
                        if (excelEnabled)
                          SecondaryButton(
                            label: YorksV1MaterialRequestStrings
                                .importExcel
                                .primary,
                            isExpanded: false,
                            icon: Icons.upload_file_outlined,
                            onPressed: isBusy
                                ? null
                                : () => _importExcel(context, ref, controller),
                          ),
                      ],
                    ),
                    child: _RequestLinesEditor(
                      lines: draft.lines,
                      controller: controller,
                      enabled: !isBusy,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (state.status ==
                          YorksV1MaterialRequestDraftSyncStatus.failed ||
                      state.status ==
                          YorksV1MaterialRequestDraftSyncStatus.conflict)
                    _InlineMessage(
                      copy:
                          state.status ==
                              YorksV1MaterialRequestDraftSyncStatus.conflict
                          ? YorksV1MaterialRequestStrings.saveFailed
                          : YorksV1MaterialRequestStrings.submitFailed,
                      language: language,
                    ),
                  if (!draft.canSubmitLocally)
                    _InlineMessage(
                      copy: YorksV1MaterialRequestStrings.missingRequired,
                      language: language,
                    ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 640;
                      final save = SecondaryButton(
                        label: YorksV1MaterialRequestStrings.saveDraft.primary,
                        icon: Icons.save_outlined,
                        onPressed: isBusy
                            ? null
                            : () => _save(context, ref, controller, draft),
                      );
                      final submit = PrimaryButton(
                        label: YorksV1MaterialRequestStrings
                            .submitToProcurement
                            .primary,
                        icon: Icons.send_rounded,
                        isLoading:
                            state.status ==
                            YorksV1MaterialRequestDraftSyncStatus.submitting,
                        onPressed: canSubmit
                            ? () => _submit(context, ref, controller)
                            : null,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: stacked
                            ? Column(
                                children: [
                                  save,
                                  const SizedBox(height: AppSpacing.sm),
                                  submit,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: save),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(child: submit),
                                ],
                              ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    YorksV1MaterialRequestDraftController controller,
    YorksV1MaterialRequestDraft draft,
  ) async {
    final saved = await controller.saveConnected();
    if (!context.mounted) return;
    if (saved == null) {
      _snack(context, YorksV1MaterialRequestStrings.saveFailed.primary);
      return;
    }
    _snack(context, YorksV1MaterialRequestStrings.saved.primary);
    ref.invalidate(yorksV1MaterialRequestListProvider);
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    YorksV1MaterialRequestDraftController controller,
  ) async {
    final submitted = await controller.submit();
    if (!context.mounted) return;
    if (submitted == null) {
      _snack(context, YorksV1MaterialRequestStrings.submitFailed.primary);
      return;
    }
    ref.invalidate(yorksV1MaterialRequestListProvider);
    context.go(RoutePaths.yorksV1MaterialRequestPath(submitted.id));
  }
}

class _RequestFormFields extends StatelessWidget {
  const _RequestFormFields({
    required this.draft,
    required this.projects,
    required this.scopes,
    required this.controller,
  });

  final YorksV1MaterialRequestDraft draft;
  final AsyncValue<List<YorksV1MaterialRequestProjectOption>> projects;
  final AsyncValue<List<YorksV1MaterialRequestScopeOption>> scopes;
  final YorksV1MaterialRequestDraftController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final half = constraints.maxWidth >= 760;
      final fields = <Widget>[
        _ProjectDropdown(
          value: draft.projectId,
          projects: projects,
          onChanged: controller.setProject,
        ),
        _ScopeDropdown(
          value: draft.scopeId,
          scopes: scopes,
          onChanged: controller.setScope,
        ),
        TextFormField(
          key: ValueKey('mr_title_${draft.title}'),
          initialValue: draft.title ?? '',
          onChanged: controller.setTitle,
          decoration: InputDecoration(
            labelText: YorksV1MaterialRequestStrings.requestTitle.primary,
          ),
        ),
        _TimingPicker(draft: draft, controller: controller),
        if (draft.timing == YorksV1MaterialRequestTiming.scheduled)
          _ScheduledDateField(draft: draft, controller: controller),
        TextFormField(
          key: ValueKey('mr_delivery_${draft.deliveryNote}'),
          initialValue: draft.deliveryNote ?? '',
          minLines: 2,
          maxLines: 3,
          onChanged: controller.setDeliveryNote,
          decoration: InputDecoration(
            labelText: YorksV1MaterialRequestStrings.deliveryNote.primary,
          ),
        ),
      ];
      if (!half) {
        return Column(
          children: [
            for (final field in fields) ...[
              field,
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      }
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final field in fields)
            SizedBox(
              width: (constraints.maxWidth - AppSpacing.md) / 2,
              child: field,
            ),
        ],
      );
    },
  );
}

class _ProjectDropdown extends StatelessWidget {
  const _ProjectDropdown({
    required this.value,
    required this.projects,
    required this.onChanged,
  });

  final String? value;
  final AsyncValue<List<YorksV1MaterialRequestProjectOption>> projects;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => projects.when(
    loading: () => const LinearProgressIndicator(),
    error: (_, _) => Text(YorksV1MaterialRequestStrings.saveFailed.primary),
    data: (items) => DropdownButtonFormField<String>(
      initialValue: items.any((item) => item.id == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: YorksV1MaterialRequestStrings.project.primary,
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(
            value: item.id,
            child: Text(
              '${item.reference} · ${item.name}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    ),
  );
}

class _ScopeDropdown extends StatelessWidget {
  const _ScopeDropdown({
    required this.value,
    required this.scopes,
    required this.onChanged,
  });

  final String? value;
  final AsyncValue<List<YorksV1MaterialRequestScopeOption>> scopes;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => scopes.when(
    loading: () => const LinearProgressIndicator(),
    error: (_, _) => Text(YorksV1MaterialRequestStrings.saveFailed.primary),
    data: (items) => DropdownButtonFormField<String>(
      initialValue: items.any((item) => item.id == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: YorksV1MaterialRequestStrings.scope.primary,
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(value: item.id, child: Text(item.name)),
      ],
      onChanged: onChanged,
    ),
  );
}

class _TimingPicker extends StatelessWidget {
  const _TimingPicker({required this.draft, required this.controller});

  final YorksV1MaterialRequestDraft draft;
  final YorksV1MaterialRequestDraftController controller;

  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<YorksV1MaterialRequestTiming>(
        initialValue: draft.timing,
        decoration: InputDecoration(
          labelText: YorksV1MaterialRequestStrings.timing.primary,
        ),
        items: [
          for (final timing in YorksV1MaterialRequestTiming.values)
            DropdownMenuItem(
              value: timing,
              child: Text(yorksV1MaterialRequestTimingCopy(timing).primary),
            ),
        ],
        onChanged: (value) {
          if (value != null) controller.setTiming(value);
        },
      );
}

class _ScheduledDateField extends StatelessWidget {
  const _ScheduledDateField({required this.draft, required this.controller});

  final YorksV1MaterialRequestDraft draft;
  final YorksV1MaterialRequestDraftController controller;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.calendar_today_outlined),
    label: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        draft.scheduledDate == null
            ? YorksV1MaterialRequestStrings.scheduledDate.primary
            : MaterialLocalizations.of(
                context,
              ).formatMediumDate(draft.scheduledDate!),
      ),
    ),
    onPressed: () async {
      final now = DateTime.now();
      final selected = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 10),
        initialDate: draft.scheduledDate ?? now,
      );
      if (selected != null) await controller.setScheduledDate(selected);
    },
  );
}

class _RequestLinesEditor extends StatelessWidget {
  const _RequestLinesEditor({
    required this.lines,
    required this.controller,
    required this.enabled,
  });

  final List<YorksV1MaterialRequestLine> lines;
  final YorksV1MaterialRequestDraftController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Text(
        YorksV1MaterialRequestStrings.missingRequired.primary,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 900
          ? _DesktopLinesTable(
              lines: lines,
              controller: controller,
              enabled: enabled,
            )
          : Column(
              children: [
                for (final line in lines) ...[
                  _FocusedLineEditor(
                    line: line,
                    controller: controller,
                    enabled: enabled,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
    );
  }
}

class _DesktopLinesTable extends StatelessWidget {
  const _DesktopLinesTable({
    required this.lines,
    required this.controller,
    required this.enabled,
  });

  final List<YorksV1MaterialRequestLine> lines;
  final YorksV1MaterialRequestDraftController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columnSpacing: AppSpacing.md,
      headingTextStyle: AppTypography.labelLarge,
      columns: [
        DataColumn(
          label: Text(YorksV1MaterialRequestStrings.rowNumber.primary),
        ),
        DataColumn(
          label: Text(YorksV1MaterialRequestStrings.itemDescription.primary),
        ),
        DataColumn(
          label: Text(YorksV1MaterialRequestStrings.brandOrigin.primary),
        ),
        DataColumn(label: Text(YorksV1MaterialRequestStrings.quantity.primary)),
        DataColumn(label: Text(YorksV1MaterialRequestStrings.unit.primary)),
        const DataColumn(label: SizedBox.shrink()),
      ],
      rows: [
        for (final line in lines)
          DataRow(
            cells: [
              DataCell(Text(line.displayOrder.toString())),
              DataCell(
                _LineTextField(
                  initialValue: line.description,
                  enabled: enabled,
                  onChanged: (value) => controller.updateLine(
                    line.id,
                    (current) => current.copyWith(description: value),
                  ),
                ),
              ),
              DataCell(
                _LineTextField(
                  initialValue: line.brandOrigin ?? '',
                  enabled: enabled,
                  onChanged: (value) => controller.updateLine(
                    line.id,
                    (current) => current.copyWith(
                      brandOrigin: value.trim().isEmpty ? null : value,
                    ),
                  ),
                ),
              ),
              DataCell(
                _LineTextField(
                  initialValue: line.quantity,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (value) => controller.updateLine(
                    line.id,
                    (current) => current.copyWith(quantity: value),
                  ),
                ),
              ),
              DataCell(
                _LineTextField(
                  initialValue: line.unit,
                  enabled: enabled,
                  onChanged: (value) => controller.updateLine(
                    line.id,
                    (current) => current.copyWith(unit: value),
                  ),
                ),
              ),
              DataCell(
                IconButton(
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).deleteButtonTooltip,
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: enabled
                      ? () => controller.removeLine(line.id)
                      : null,
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

class _FocusedLineEditor extends StatelessWidget {
  const _FocusedLineEditor({
    required this.line,
    required this.controller,
    required this.enabled,
  });

  final YorksV1MaterialRequestLine line;
  final YorksV1MaterialRequestDraftController controller;
  final bool enabled;

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
        Row(
          children: [
            Text('${line.displayOrder}', style: AppTypography.titleSmall),
            const Spacer(),
            IconButton(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: enabled ? () => controller.removeLine(line.id) : null,
            ),
          ],
        ),
        _LineLabeledField(
          label: YorksV1MaterialRequestStrings.itemDescription.primary,
          initialValue: line.description,
          enabled: enabled,
          onChanged: (value) => controller.updateLine(
            line.id,
            (current) => current.copyWith(description: value),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _LineLabeledField(
          label: YorksV1MaterialRequestStrings.brandOrigin.primary,
          initialValue: line.brandOrigin ?? '',
          enabled: enabled,
          onChanged: (value) => controller.updateLine(
            line.id,
            (current) => current.copyWith(
              brandOrigin: value.trim().isEmpty ? null : value,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _LineLabeledField(
                label: YorksV1MaterialRequestStrings.quantity.primary,
                initialValue: line.quantity,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (value) => controller.updateLine(
                  line.id,
                  (current) => current.copyWith(quantity: value),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _LineLabeledField(
                label: YorksV1MaterialRequestStrings.unit.primary,
                initialValue: line.unit,
                enabled: enabled,
                onChanged: (value) => controller.updateLine(
                  line.id,
                  (current) => current.copyWith(unit: value),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _LineTextField extends StatelessWidget {
  const _LineTextField({
    required this.initialValue,
    required this.onChanged,
    required this.enabled,
    this.keyboardType,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: TextFormField(
      key: ValueKey(initialValue),
      initialValue: initialValue,
      enabled: enabled,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: const InputDecoration(isDense: true),
    ),
  );
}

class _LineLabeledField extends StatelessWidget {
  const _LineLabeledField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    required this.enabled,
    this.keyboardType,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: ValueKey('$label-$initialValue'),
    initialValue: initialValue,
    enabled: enabled,
    keyboardType: keyboardType,
    onChanged: onChanged,
    decoration: InputDecoration(labelText: label),
  );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.language,
    required this.onOpen,
  });

  final YorksV1MaterialRequest request;
  final AppLanguage language;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.requestNumber ??
                        YorksV1MaterialRequestStrings.draftPrivate.primary,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StateChip(request: request, language: language),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              request.title ?? request.projectName,
              style: AppTypography.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${request.projectReference} · ${request.scopeName}',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${yorksV1MaterialRequestTimingCopy(request.timing).primary} · ${request.lines.length}',
              style: AppTypography.labelLarge.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RequestDetailBody extends ConsumerWidget {
  const _RequestDetailBody({required this.request, required this.language});

  final YorksV1MaterialRequest request;
  final AppLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final arrangementEnabled = ref
        .watch(yorksV1FeatureFlagsProvider)
        .arrangement;
    final logisticsEnabled = ref.watch(yorksV1FeatureFlagsProvider).logistics;
    final returnsDocumentsEnabled = ref
        .watch(yorksV1FeatureFlagsProvider)
        .returnsDocuments;
    final documentsEnabled = ref.watch(yorksV1FeatureFlagsProvider).documents;
    final fileService = ref.watch(yorksV1BoqWorkbookFileServiceProvider);
    final documentService = YorksV1MaterialRequestDocumentService();
    final canCancel =
        (role == YorksV1Role.projectEngineer ||
            role == YorksV1Role.siteEngineer ||
            role == YorksV1Role.admin) &&
        (request.state == YorksV1MaterialRequestState.submitted ||
            request.state == YorksV1MaterialRequestState.arranging ||
            request.state == YorksV1MaterialRequestState.awaitingApproval ||
            request.state == YorksV1MaterialRequestState.approved);
    final canOpenArrangement =
        arrangementEnabled &&
        request.state != YorksV1MaterialRequestState.draft &&
        request.state != YorksV1MaterialRequestState.cancelled;
    final canOpenLogistics =
        logisticsEnabled &&
        request.state != YorksV1MaterialRequestState.draft &&
        request.state != YorksV1MaterialRequestState.cancelled;
    final canOpenReturnsDocuments =
        returnsDocumentsEnabled &&
        request.state != YorksV1MaterialRequestState.draft &&
        request.state != YorksV1MaterialRequestState.cancelled;
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
                NexusSectionCard(
                  child: _RequestSummary(request: request, language: language),
                ),
                const SizedBox(height: AppSpacing.lg),
                NexusSectionCard(
                  title: YorksV1MaterialRequestStrings.lines.primary,
                  child: _RequestReadOnlyLines(lines: request.lines),
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final actions = [
                      SecondaryButton(
                        label:
                            YorksV1MaterialRequestStrings.exportExcel.primary,
                        isExpanded: false,
                        icon: Icons.download_outlined,
                        onPressed: () async {
                          final saved = await fileService.saveWorkbook(
                            bytes: documentService.buildExcel(request),
                            suggestedName: documentService.suggestedExcelName(
                              request,
                            ),
                          );
                          if (context.mounted && saved) {
                            _snack(
                              context,
                              YorksV1MaterialRequestStrings.saved.primary,
                            );
                          }
                        },
                      ),
                      if (canOpenArrangement)
                        SecondaryButton(
                          label: YorksV1ArrangementStrings.arrangement.primary,
                          isExpanded: false,
                          icon: Icons.playlist_add_check_rounded,
                          onPressed: () => context.push(
                            RoutePaths.yorksV1MaterialRequestArrangementPath(
                              request.id,
                            ),
                          ),
                        ),
                      if (canOpenLogistics)
                        SecondaryButton(
                          label: YorksV1LogisticsStrings
                              .dispatchAndReceipt
                              .primary,
                          isExpanded: false,
                          icon: Icons.local_shipping_outlined,
                          onPressed: () => context.push(
                            RoutePaths.yorksV1MaterialRequestLogisticsPath(
                              request.id,
                            ),
                          ),
                        ),
                      if (canOpenReturnsDocuments)
                        SecondaryButton(
                          label: YorksV1LogisticsStrings
                              .deliveryOrdersAndReturns
                              .primary,
                          isExpanded: false,
                          icon: Icons.assignment_return_outlined,
                          onPressed: () => context.push(
                            RoutePaths.yorksV1MaterialRequestReturnsDocumentsPath(
                              request.id,
                            ),
                          ),
                        ),
                      if (documentsEnabled)
                        SecondaryButton(
                          label: YorksV1DocumentStrings.documents.primary,
                          isExpanded: false,
                          icon: Icons.folder_open_outlined,
                          onPressed: () => context.push(
                            RoutePaths.yorksV1ProjectDocumentsPath(
                              request.projectId,
                              entityType: 'material_request',
                              entityId: request.id,
                            ),
                          ),
                        ),
                      SecondaryButton(
                        label: YorksV1MaterialRequestStrings.printPdf.primary,
                        isExpanded: false,
                        icon: Icons.print_outlined,
                        onPressed: () => documentService.printPdf(request),
                      ),
                      if (documentsEnabled)
                        SecondaryButton(
                          label: YorksV1DocumentStrings
                              .storeControlledVersion
                              .primary,
                          isExpanded: false,
                          icon: Icons.verified_outlined,
                          onPressed: () => _storePdfSnapshot(
                            context,
                            ref,
                            request,
                            documentService,
                          ),
                        ),
                      if (canCancel)
                        SecondaryButton(
                          label: YorksV1MaterialRequestStrings
                              .cancelRequest
                              .primary,
                          isExpanded: false,
                          icon: Icons.cancel_outlined,
                          onPressed: () => _cancel(context, ref, request),
                        ),
                    ];
                    return Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: actions,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    YorksV1MaterialRequest request,
  ) async {
    final reason = await _cancelReason(context);
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await ref
          .read(yorksV1MaterialRequestRepositoryProvider)
          .cancel(
            YorksV1CancelMaterialRequestInput(
              requestId: request.id,
              expectedVersion: request.recordVersion,
              reason: reason,
              idempotencyKey: const Uuid().v4(),
            ),
          );
      if (!context.mounted) return;
      ref.invalidate(yorksV1MaterialRequestDetailProvider(request.id));
      ref.invalidate(yorksV1MaterialRequestListProvider);
      _snack(context, YorksV1MaterialRequestStrings.cancelled.primary);
    } catch (_) {
      if (context.mounted) {
        _snack(context, YorksV1MaterialRequestStrings.saveFailed.primary);
      }
    }
  }

  Future<void> _storePdfSnapshot(
    BuildContext context,
    WidgetRef ref,
    YorksV1MaterialRequest request,
    YorksV1MaterialRequestDocumentService documentService,
  ) async {
    try {
      final bytes = await documentService.buildPdf(request, PdfPageFormat.a4);
      await ref
          .read(yorksV1DocumentsRepositoryProvider)
          .upload(
            YorksV1DocumentUploadInput(
              projectId: request.projectId,
              entityType: YorksV1DocumentEntityType.materialRequest,
              entityId: request.id,
              classification: YorksV1DocumentClassification.operational,
              fileName: documentService
                  .suggestedExcelName(request)
                  .replaceFirst(RegExp(r'\.xlsx$'), '.pdf'),
              mimeType: 'application/pdf',
              bytes: bytes,
              origin: YorksV1DocumentOrigin.generated,
              sourceEntityType: YorksV1DocumentEntityType.materialRequest,
              sourceEntityId: request.id,
              sourceRevision: request.recordVersion.toString(),
              idempotencyKey: const Uuid().v5(
                Namespace.url.value,
                'yorks-mr-pdf:${request.id}:${request.recordVersion}',
              ),
            ),
          );
      if (context.mounted) {
        _snack(context, YorksV1DocumentStrings.uploadSucceeded.primary);
      }
    } catch (_) {
      if (context.mounted) {
        _snack(context, YorksV1DocumentStrings.uploadFailed.primary);
      }
    }
  }
}

class _RequestSummary extends StatelessWidget {
  const _RequestSummary({required this.request, required this.language});

  final YorksV1MaterialRequest request;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              request.requestNumber ??
                  YorksV1MaterialRequestStrings.draftPrivate.primary,
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _StateChip(request: request, language: language),
        ],
      ),
      if (request.title != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(request.title!, style: AppTypography.titleMedium),
      ],
      const SizedBox(height: AppSpacing.lg),
      Wrap(
        spacing: AppSpacing.xxl,
        runSpacing: AppSpacing.md,
        children: [
          _Meta(
            label: YorksV1MaterialRequestStrings.project.primary,
            value: '${request.projectReference} · ${request.projectName}',
          ),
          _Meta(
            label: YorksV1MaterialRequestStrings.scope.primary,
            value: request.scopeName,
          ),
          _Meta(
            label: YorksV1MaterialRequestStrings.timing.primary,
            value: yorksV1MaterialRequestTimingCopy(request.timing).primary,
          ),
          if (request.requesterDisplayName != null)
            _Meta(
              label: YorksV1MaterialRequestStrings.requester.primary,
              value: request.requesterDisplayName!,
            ),
          if (request.currentActionOwnerRole != null)
            _Meta(
              label: YorksV1MaterialRequestStrings.currentOwner.primary,
              value: request.currentActionOwnerRole!,
            ),
          if (request.currentActionCode != null)
            _Meta(
              label: YorksV1MaterialRequestStrings.nextAction.primary,
              value: request.currentActionCode!,
            ),
          _Meta(
            label: YorksV1MaterialRequestStrings.requestNumber.primary,
            value: MaterialLocalizations.of(
              context,
            ).formatMediumDate(request.updatedAt.toLocal()),
          ),
        ],
      ),
      if (request.deliveryNote != null) ...[
        const SizedBox(height: AppSpacing.lg),
        Text(request.deliveryNote!, style: AppTypography.bodyMedium),
      ],
    ],
  );
}

class _RequestReadOnlyLines extends StatelessWidget {
  const _RequestReadOnlyLines({required this.lines});

  final List<YorksV1MaterialRequestLine> lines;

  @override
  Widget build(BuildContext context) {
    final commercial = lines.any((line) => line.unitCost != null);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(
            label: Text(YorksV1MaterialRequestStrings.rowNumber.primary),
          ),
          DataColumn(
            label: Text(YorksV1MaterialRequestStrings.itemDescription.primary),
          ),
          DataColumn(
            label: Text(YorksV1MaterialRequestStrings.brandOrigin.primary),
          ),
          DataColumn(
            label: Text(YorksV1MaterialRequestStrings.quantity.primary),
          ),
          DataColumn(label: Text(YorksV1MaterialRequestStrings.unit.primary)),
          if (commercial)
            DataColumn(
              label: Text(YorksV1MaterialRequestStrings.unitCost.primary),
            ),
          if (commercial)
            DataColumn(
              label: Text(YorksV1MaterialRequestStrings.totalCost.primary),
            ),
        ],
        rows: [
          for (final line in lines)
            DataRow(
              cells: [
                DataCell(Text(line.displayOrder.toString())),
                DataCell(Text(line.description)),
                DataCell(Text(line.brandOrigin ?? '—')),
                DataCell(Text(line.quantity)),
                DataCell(Text(line.unit)),
                if (commercial) DataCell(Text(line.unitCost ?? '—')),
                if (commercial) DataCell(Text(line.totalCost ?? '—')),
              ],
            ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.request, required this.language});

  final YorksV1MaterialRequest request;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: request.state == YorksV1MaterialRequestState.cancelled
          ? AppColors.errorContainer
          : AppColors.blueContainer,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
    ),
    child: Text(
      yorksV1MaterialRequestStateCopy(request.state).primary,
      style: AppTypography.labelLarge,
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
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

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests({required this.language, required this.canCreate});
  final AppLanguage language;
  final bool canCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: NexusSectionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 42, color: AppColors.muted),
          const SizedBox(height: AppSpacing.lg),
          _CopyText(
            copy: YorksV1MaterialRequestStrings.noRequests,
            language: language,
            center: true,
          ),
        ],
      ),
    ),
  );
}

class _RequestError extends StatelessWidget {
  const _RequestError({required this.language, required this.onRetry});
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
            size: 42,
            color: AppColors.error,
          ),
          const SizedBox(height: AppSpacing.md),
          _CopyText(
            copy: YorksV1MaterialRequestStrings.saveFailed,
            language: language,
            center: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          SecondaryButton(
            label: YorksV1MaterialRequestStrings.refresh.primary,
            isExpanded: false,
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ],
      ),
    ),
  );
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.copy, required this.language});
  final TranslatableString copy;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: _CopyText(
      copy: copy,
      language: language,
      style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
    ),
  );
}

class _CopyText extends StatelessWidget {
  const _CopyText({
    required this.copy,
    required this.language,
    this.style,
    this.center = false,
  });

  final TranslatableString copy;
  final AppLanguage language;
  final TextStyle? style;
  final bool center;

  @override
  Widget build(BuildContext context) => BilingualText(
    english: copy.primary,
    secondary: copy.secondary(language),
    englishStyle: style ?? AppTypography.bodyMedium,
    secondaryStyle: (style ?? AppTypography.bodyMedium).copyWith(
      color: AppColors.muted,
    ),
    crossAxisAlignment: center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
  );
}

Future<void> _addBoqRows(
  BuildContext context,
  WidgetRef ref,
  YorksV1MaterialRequestDraftController controller,
  YorksV1MaterialRequestDraft draft,
) async {
  try {
    final groups = await ref
        .read(yorksV1BoqRepositoryProvider)
        .listGroups(draft.projectId!);
    if (!context.mounted) return;
    final selectedGroup = await showModalBottomSheet<YorksV1BoqGroup>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        children: [
          for (final group in groups.where((group) => group.rowCount > 0))
            ListTile(
              title: Text(group.effectiveTitle),
              subtitle: Text('${group.rowCount}'),
              onTap: () => Navigator.of(context).pop(group),
            ),
        ],
      ),
    );
    if (selectedGroup == null) return;
    final worksheet = await ref
        .read(yorksV1BoqRepositoryProvider)
        .getWorksheet(selectedGroup.id);
    if (!context.mounted) return;
    final selectedRowIds = await _pickRows(context, worksheet);
    if (selectedRowIds == null || selectedRowIds.isEmpty) return;
    await controller.addBoqRows(worksheet: worksheet, rowIds: selectedRowIds);
  } catch (_) {
    if (context.mounted) {
      _snack(context, YorksV1MaterialRequestStrings.saveFailed.primary);
    }
  }
}

Future<Set<String>?> _pickRows(
  BuildContext context,
  YorksV1BoqWorksheet worksheet,
) async {
  final selected = <String>{};
  return showDialog<Set<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(YorksV1MaterialRequestStrings.addFromBoq.primary),
        content: SizedBox(
          width: 620,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final row in worksheet.rows)
                CheckboxListTile(
                  value: selected.contains(row.id),
                  title: Text(
                    row.canonicalValues['description']?.toString() ?? '',
                  ),
                  subtitle: Text(
                    '${row.canonicalValues['quantity'] ?? ''} ${row.canonicalValues['unit'] ?? ''}',
                  ),
                  onChanged: (value) => setState(() {
                    if (value ?? false) {
                      selected.add(row.id);
                    } else {
                      selected.remove(row.id);
                    }
                  }),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(YorksV1MaterialRequestStrings.cancel.primary),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(selected),
            child: Text(YorksV1MaterialRequestStrings.addFromBoq.primary),
          ),
        ],
      ),
    ),
  );
}

Future<void> _importExcel(
  BuildContext context,
  WidgetRef ref,
  YorksV1MaterialRequestDraftController controller,
) async {
  try {
    final selected = await ref
        .read(yorksV1BoqWorkbookFileServiceProvider)
        .selectWorkbook();
    if (selected == null) return;
    final codec = ref.read(yorksV1BoqWorkbookCodecProvider);
    final workbook = codec.decode(
      bytes: selected.bytes,
      fileName: selected.fileName,
    );
    final preview = codec.preview(
      workbook: workbook,
      sheet: workbook.sheets.first,
      fallbackTitle: selected.fileName,
    );
    final fields = <YorksV1BoqCanonicalField, int>{
      for (final column in preview.columns)
        if (column.canonicalField != null)
          column.canonicalField!: column.sourceIndex,
    };
    final description = fields[YorksV1BoqCanonicalField.description];
    final quantity = fields[YorksV1BoqCanonicalField.quantity];
    final unit = fields[YorksV1BoqCanonicalField.unit];
    if (description == null || quantity == null || unit == null) {
      throw StateError('required columns');
    }
    final brand = fields[YorksV1BoqCanonicalField.brandOrigin];
    final lines = [
      for (var index = 0; index < preview.rows.length; index++)
        YorksV1MaterialRequestLine(
          id: const Uuid().v4(),
          displayOrder: index + 1,
          source: YorksV1MaterialRequestLineSource.excel,
          description: preview.rows[index].valueFor(description),
          brandOrigin: brand == null
              ? null
              : preview.rows[index].valueFor(brand),
          quantity: preview.rows[index].valueFor(quantity),
          unit: preview.rows[index].valueFor(unit),
        ),
    ].where((line) => line.hasValidOperationalValues);
    await controller.addExcelLines(lines);
  } catch (_) {
    if (context.mounted) {
      _snack(context, YorksV1MaterialRequestStrings.importFailed.primary);
    }
  }
}

Future<String?> _cancelReason(BuildContext context) async {
  final text = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(YorksV1MaterialRequestStrings.cancelRequest.primary),
      content: TextField(
        controller: text,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: YorksV1MaterialRequestStrings.cancelReason.primary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(YorksV1MaterialRequestStrings.cancel.primary),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(text.text),
          child: Text(YorksV1MaterialRequestStrings.cancelRequest.primary),
        ),
      ],
    ),
  );
  text.dispose();
  return result;
}

void _snack(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
