import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/controllers/yorks_v1_boq_controller.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_boq.dart';
import '../../../../shared/models/yorks_v1_boq_strings.dart';
import '../../../../shared/models/yorks_v1_boq_workbook.dart';
import '../../../../shared/models/yorks_v1_material_request_strings.dart';
import '../../../../shared/models/yorks_v1_role.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_boq_provider.dart';
import '../../../../shared/providers/yorks_v1_boq_repository_provider.dart';
import '../../../../shared/providers/yorks_v1_boq_workbook_provider.dart';
import '../../../../shared/providers/yorks_v1_feature_flags_provider.dart';
import '../../../../shared/providers/yorks_v1_identity_provider.dart';
import '../../../../shared/services/yorks_v1_boq_workbook_service.dart';

/// Ordered BOQ folder view.  It is intentionally separate from the retained
/// V7 project workspace so normalized V1 data never falls back to a legacy
/// local project store.
class YorksV1BoqGroupsScreen extends ConsumerWidget {
  const YorksV1BoqGroupsScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final groups = ref.watch(yorksV1BoqGroupsProvider(projectId));
    final editable = role != null && role != YorksV1Role.procurement;
    final requestsEnabled = ref.watch(yorksV1FeatureFlagsProvider).requests;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: _CopyText(
          copy: YorksV1BoqStrings.worksheets,
          language: language,
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (requestsEnabled)
            IconButton(
              tooltip: YorksV1MaterialRequestStrings.requests.primary,
              onPressed: () => context.push(RoutePaths.yorksV1MaterialRequests),
              icon: const Icon(Icons.assignment_outlined),
            ),
          if (requestsEnabled && role?.canCreateMaterialRequest == true)
            IconButton(
              tooltip: YorksV1MaterialRequestStrings.newRequest.primary,
              onPressed: () => context.push(
                RoutePaths.yorksV1MaterialRequestDraftPath(const Uuid().v4()),
              ),
              icon: const Icon(Icons.add_task_outlined),
            ),
        ],
      ),
      floatingActionButton: editable
          ? FloatingActionButton.extended(
              onPressed: () => _createGroup(context, ref),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: Text(YorksV1BoqStrings.addGroup.primary),
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
          child: groups.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _ErrorState(
              language: language,
              onRetry: () =>
                  ref.invalidate(yorksV1BoqGroupsProvider(projectId)),
            ),
            data: (items) => _GroupsBody(
              groups: items,
              language: language,
              projectId: projectId,
              editable: editable,
              onAddGroup: () => _createGroup(context, ref),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final name = await _promptForText(
      context: context,
      title: YorksV1BoqStrings.addGroup,
      label: YorksV1BoqStrings.customGroupName,
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref
          .read(yorksV1BoqRepositoryProvider)
          .createCustomGroup(
            YorksV1CreateBoqGroupInput(
              projectId: projectId,
              name: name,
              idempotencyKey: const Uuid().v4(),
            ),
          );
      ref.invalidate(yorksV1BoqGroupsProvider(projectId));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(YorksV1BoqStrings.saveFailed.primary)),
      );
    }
  }
}

class _GroupsBody extends StatelessWidget {
  const _GroupsBody({
    required this.groups,
    required this.language,
    required this.projectId,
    required this.editable,
    required this.onAddGroup,
  });

  final List<YorksV1BoqGroup> groups;
  final AppLanguage language;
  final String projectId;
  final bool editable;
  final VoidCallback onAddGroup;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: NexusSectionCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.folder_off_outlined,
                  size: 42,
                  color: AppColors.muted,
                ),
                const SizedBox(height: AppSpacing.lg),
                _CopyText(
                  copy: YorksV1BoqStrings.noGroups,
                  language: language,
                  center: true,
                ),
                if (editable) ...[
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: YorksV1BoqStrings.addGroup.primary,
                    icon: Icons.add_rounded,
                    onPressed: onAddGroup,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1120
            ? 3
            : constraints.maxWidth >= 700
            ? 2
            : 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CopyText(
              copy: YorksV1BoqStrings.boqDescription,
              language: language,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: count,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: count == 1 ? 2.75 : 1.85,
                ),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _BoqGroupCard(
                    group: group,
                    language: language,
                    onOpen: () => context.push(
                      RoutePaths.yorksV1BoqWorksheetPath(projectId, group.id),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BoqGroupCard extends StatelessWidget {
  const _BoqGroupCard({
    required this.group,
    required this.language,
    required this.onOpen,
  });

  final YorksV1BoqGroup group;
  final AppLanguage language;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: group.effectiveTitle,
      child: Material(
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
                    Container(
                      width: AppSpacing.minTapTarget,
                      height: AppSpacing.minTapTarget,
                      decoration: BoxDecoration(
                        color: group.isCustom
                            ? AppColors.purpleContainer
                            : AppColors.blueContainer,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                      child: Icon(
                        group.isCustom
                            ? Icons.folder_special_outlined
                            : Icons.folder_outlined,
                        color: group.isCustom
                            ? AppColors.purple
                            : AppColors.blue,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${group.displayOrder}'.padLeft(2, '0'),
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  group.effectiveTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _CopyText(
                  copy: group.isCustom
                      ? YorksV1BoqStrings.customGroup
                      : YorksV1BoqStrings.defaultGroup,
                  language: language,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${group.rowCount} ${YorksV1BoqStrings.rows.primary} · '
                  '${group.columnCount} ${YorksV1BoqStrings.columns.primary}',
                  style: AppTypography.labelLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class YorksV1BoqWorksheetScreen extends ConsumerWidget {
  const YorksV1BoqWorksheetScreen({
    super.key,
    required this.projectId,
    required this.groupId,
  });

  final String projectId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final state = ref.watch(yorksV1BoqWorksheetControllerProvider(groupId));
    final controller = ref.read(
      yorksV1BoqWorksheetControllerProvider(groupId).notifier,
    );
    final excelEnabled = ref.watch(yorksV1FeatureFlagsProvider).excel;
    final requestsEnabled = ref.watch(yorksV1FeatureFlagsProvider).requests;
    final editable =
        role != null && role != YorksV1Role.procurement && !state.isReadOnly;

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
          copy: YorksV1BoqStrings.worksheet,
          language: language,
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (editable && state.worksheet?.group.isCustom == true)
            IconButton(
              tooltip: YorksV1BoqStrings.archiveGroup.primary,
              icon: const Icon(Icons.archive_outlined),
              onPressed: () => _archive(context, ref, state.worksheet!.group),
            ),
          IconButton(
            tooltip: YorksV1BoqStrings.refresh.primary,
            onPressed: controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (requestsEnabled && role?.canCreateMaterialRequest == true)
            IconButton(
              tooltip: YorksV1MaterialRequestStrings.newRequest.primary,
              onPressed: () => context.push(
                RoutePaths.yorksV1MaterialRequestDraftPath(const Uuid().v4()),
              ),
              icon: const Icon(Icons.add_task_outlined),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: switch (state.status) {
          YorksV1BoqSyncStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          YorksV1BoqSyncStatus.failed when state.worksheet == null =>
            _ErrorState(language: language, onRetry: controller.load),
          _ => _WorksheetBody(
            state: state,
            controller: controller,
            language: language,
            editable: editable,
            excelEnabled: excelEnabled,
            onSaved: () => ref.invalidate(yorksV1BoqGroupsProvider(projectId)),
            onImport: editable && excelEnabled && state.worksheet != null
                ? () => _importWorkbook(
                    context,
                    ref,
                    controller,
                    state.worksheet!,
                    language,
                  )
                : null,
            onExport: excelEnabled && state.worksheet != null
                ? () => _exportWorkbook(context, ref, state.worksheet!)
                : null,
          ),
        },
      ),
    );
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    YorksV1BoqGroup group,
  ) async {
    final confirmed = await _confirm(
      context: context,
      title: YorksV1BoqStrings.archiveGroup,
      body: YorksV1BoqStrings.archiveGroupConfirmation,
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(yorksV1BoqRepositoryProvider)
          .archiveGroup(
            groupId: group.id,
            expectedVersion: group.version,
            idempotencyKey: const Uuid().v4(),
          );
      ref.invalidate(yorksV1BoqGroupsProvider(projectId));
      if (context.mounted) context.pop();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(YorksV1BoqStrings.saveFailed.primary)),
      );
    }
  }

  Future<void> _importWorkbook(
    BuildContext context,
    WidgetRef ref,
    YorksV1BoqWorksheetController controller,
    YorksV1BoqWorksheet worksheet,
    AppLanguage language,
  ) async {
    try {
      final selected = await ref
          .read(yorksV1BoqWorkbookFileServiceProvider)
          .selectWorkbook();
      if (selected == null || !context.mounted) return;
      final codec = ref.read(yorksV1BoqWorkbookCodecProvider);
      final workbook = codec.decode(
        bytes: selected.bytes,
        fileName: selected.fileName,
      );
      final preview = await showDialog<YorksV1BoqImportPreview>(
        context: context,
        builder: (_) => _BoqWorkbookImportDialog(
          workbook: workbook,
          codec: codec,
          fallbackTitle: worksheet.group.effectiveTitle,
          language: language,
        ),
      );
      if (preview == null) return;
      final imported = await controller.importWorkbook(preview);
      if (!context.mounted) return;
      if (imported) {
        ref.invalidate(yorksV1BoqGroupsProvider(projectId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(YorksV1BoqStrings.imported.primary)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(YorksV1BoqStrings.importFailed.primary)),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(YorksV1BoqStrings.importFailed.primary)),
      );
    }
  }

  Future<void> _exportWorkbook(
    BuildContext context,
    WidgetRef ref,
    YorksV1BoqWorksheet worksheet,
  ) async {
    try {
      final codec = ref.read(yorksV1BoqWorkbookCodecProvider);
      final saved = await ref
          .read(yorksV1BoqWorkbookFileServiceProvider)
          .saveWorkbook(
            bytes: codec.encodeWorksheet(worksheet),
            suggestedName: _workbookFileName(worksheet.group.effectiveTitle),
          );
      if (!context.mounted || !saved) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(YorksV1BoqStrings.exported.primary)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(YorksV1BoqStrings.exportFailed.primary)),
      );
    }
  }

  static String _workbookFileName(String title) {
    final safe = title
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return '${safe.isEmpty ? 'Yorks_BOQ' : safe}.xlsx';
  }
}

class _WorksheetBody extends StatelessWidget {
  const _WorksheetBody({
    required this.state,
    required this.controller,
    required this.language,
    required this.editable,
    required this.excelEnabled,
    required this.onSaved,
    this.onImport,
    this.onExport,
  });

  final YorksV1BoqWorksheetState state;
  final YorksV1BoqWorksheetController controller;
  final AppLanguage language;
  final bool editable;
  final bool excelEnabled;
  final VoidCallback onSaved;
  final Future<void> Function()? onImport;
  final Future<void> Function()? onExport;

  @override
  Widget build(BuildContext context) {
    final worksheet = state.worksheet!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WorksheetHeader(
            worksheet: worksheet,
            language: language,
            editable: editable,
            excelEnabled: excelEnabled,
            state: state,
            onTitleChanged: controller.updateTitle,
            onImport: onImport,
            onExport: onExport,
            onSave: () async {
              final saved = await controller.save();
              if (!context.mounted) return;
              if (saved) {
                onSaved();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(YorksV1BoqStrings.saved.primary)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(YorksV1BoqStrings.saveFailed.primary)),
                );
              }
            },
            onRefresh: controller.load,
          ),
          const SizedBox(height: AppSpacing.md),
          if (!editable) _ReadOnlyBanner(language: language),
          if (!editable) const SizedBox(height: AppSpacing.md),
          if (state.status == YorksV1BoqSyncStatus.conflict)
            _ConflictBanner(language: language, onRefresh: controller.load),
          if (state.status == YorksV1BoqSyncStatus.conflict)
            const SizedBox(height: AppSpacing.md),
          Expanded(
            child: YorksV1BoqSpreadsheet(
              worksheet: worksheet,
              editable: editable,
              onUpdateCell: controller.updateCell,
              onAddBlankRow: controller.addBlankRow,
              onAddSimilarRow: controller.addSimilarRow,
              onRemoveRow: controller.removeRow,
              onAddColumn: controller.addColumn,
              onRenameColumn: controller.renameColumn,
              onRemoveColumn: controller.removeColumn,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorksheetHeader extends StatelessWidget {
  const _WorksheetHeader({
    required this.worksheet,
    required this.language,
    required this.editable,
    required this.excelEnabled,
    required this.state,
    required this.onTitleChanged,
    required this.onSave,
    this.onImport,
    this.onExport,
    required this.onRefresh,
  });

  final YorksV1BoqWorksheet worksheet;
  final AppLanguage language;
  final bool editable;
  final bool excelEnabled;
  final YorksV1BoqWorksheetState state;
  final ValueChanged<String> onTitleChanged;
  final Future<void> Function() onSave;
  final Future<void> Function()? onImport;
  final Future<void> Function()? onExport;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final status = switch (state.status) {
      YorksV1BoqSyncStatus.saving => YorksV1BoqStrings.saving,
      YorksV1BoqSyncStatus.saved ||
      YorksV1BoqSyncStatus.ready => YorksV1BoqStrings.saved,
      _ => YorksV1BoqStrings.unsavedChanges,
    };
    final statusColor = state.status == YorksV1BoqSyncStatus.saving
        ? AppColors.blue
        : state.status == YorksV1BoqSyncStatus.saved ||
              state.status == YorksV1BoqSyncStatus.ready
        ? AppColors.success
        : AppColors.warning;
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < AppSpacing.compactBreakpoint;
            final title = TextFormField(
              key: ValueKey('boq-title-${worksheet.group.id}'),
              initialValue: worksheet.group.worksheetTitle,
              enabled: editable,
              onChanged: onTitleChanged,
              decoration: InputDecoration(
                labelText: YorksV1BoqStrings.worksheetTitle.primary,
                border: const OutlineInputBorder(),
              ),
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            );
            final actions = Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _SyncChip(copy: status, color: statusColor),
                if (excelEnabled && onExport != null)
                  OutlinedButton.icon(
                    key: const ValueKey('boq-export-workbook'),
                    onPressed: onExport,
                    icon: const Icon(Icons.file_download_outlined),
                    label: Text(YorksV1BoqStrings.exportWorkbook.primary),
                  ),
                if (excelEnabled && onImport != null)
                  OutlinedButton.icon(
                    key: const ValueKey('boq-import-workbook'),
                    onPressed: state.status == YorksV1BoqSyncStatus.saving
                        ? null
                        : onImport,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: Text(YorksV1BoqStrings.importWorkbook.primary),
                  ),
                if (editable)
                  FilledButton.icon(
                    onPressed: state.status == YorksV1BoqSyncStatus.saving
                        ? null
                        : onSave,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(YorksV1BoqStrings.save.primary),
                  ),
              ],
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: AppSpacing.sm),
                  actions,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: AppSpacing.md),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BoqWorkbookImportDialog extends StatefulWidget {
  const _BoqWorkbookImportDialog({
    required this.workbook,
    required this.codec,
    required this.fallbackTitle,
    required this.language,
  });

  final YorksV1BoqParsedWorkbook workbook;
  final YorksV1BoqWorkbookCodec codec;
  final String fallbackTitle;
  final AppLanguage language;

  @override
  State<_BoqWorkbookImportDialog> createState() =>
      _BoqWorkbookImportDialogState();
}

class _BoqWorkbookImportDialogState extends State<_BoqWorkbookImportDialog> {
  late YorksV1BoqWorkbookSheet _sheet;
  late int _headerRowIndex;
  late bool _hasSelectedHeader;
  late String _title;
  late List<YorksV1BoqImportColumn> _columns;
  late List<YorksV1BoqImportRow> _rows;

  @override
  void initState() {
    super.initState();
    _sheet = widget.workbook.sheets.first;
    _headerRowIndex = 0;
    _hasSelectedHeader = false;
    _resetPreview();
  }

  YorksV1BoqImportPreview get _preview => YorksV1BoqImportPreview(
    fileName: widget.workbook.fileName,
    worksheetName: _sheet.name,
    title: _title,
    headerRowIndex: _headerRowIndex,
    columns: _columns,
    rows: _rows,
    validationIssues: widget.codec.validatePreviewColumns(_columns),
  );

  void _resetPreview() {
    final detected = widget.codec.preview(
      workbook: widget.workbook,
      sheet: _sheet,
      fallbackTitle: widget.fallbackTitle,
      headerRowIndex: _hasSelectedHeader ? _headerRowIndex : null,
    );
    _headerRowIndex = detected.headerRowIndex;
    _title = detected.title;
    _columns = detected.columns;
    _rows = detected.rows;
  }

  void _selectSheet(YorksV1BoqWorkbookSheet sheet) {
    setState(() {
      _sheet = sheet;
      _headerRowIndex = 0;
      _hasSelectedHeader = false;
      _resetPreview();
    });
  }

  void _selectHeader(int index) {
    setState(() {
      _headerRowIndex = index;
      _hasSelectedHeader = true;
      _resetPreview();
    });
  }

  void _updateColumn(
    int index,
    YorksV1BoqImportColumn Function(YorksV1BoqImportColumn current) update,
  ) {
    setState(() {
      _columns = [
        for (var item = 0; item < _columns.length; item++)
          item == index ? update(_columns[item]) : _columns[item],
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final headerCandidates = _sheet.nonEmptyRowIndexes;
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CopyText(
                copy: YorksV1BoqStrings.importPreview,
                language: widget.language,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.workbook.fileName,
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.sm),
              _CopyText(
                copy: YorksV1BoqStrings.importDescription,
                language: widget.language,
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 600;
                          final selectors = [
                            Expanded(
                              child:
                                  DropdownButtonFormField<
                                    YorksV1BoqWorkbookSheet
                                  >(
                                    key: ValueKey(
                                      'boq-import-sheet-${_sheet.name}',
                                    ),
                                    initialValue: _sheet,
                                    decoration: InputDecoration(
                                      labelText: YorksV1BoqStrings
                                          .worksheetSelection
                                          .primary,
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: [
                                      for (final sheet
                                          in widget.workbook.sheets)
                                        DropdownMenuItem(
                                          value: sheet,
                                          child: Text(sheet.name),
                                        ),
                                    ],
                                    onChanged: (sheet) {
                                      if (sheet != null) _selectSheet(sheet);
                                    },
                                  ),
                            ),
                            const SizedBox(
                              width: AppSpacing.sm,
                              height: AppSpacing.sm,
                            ),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                key: ValueKey(
                                  'boq-import-header-$_headerRowIndex',
                                ),
                                initialValue:
                                    headerCandidates.contains(_headerRowIndex)
                                    ? _headerRowIndex
                                    : null,
                                decoration: InputDecoration(
                                  labelText:
                                      YorksV1BoqStrings.headerRow.primary,
                                  border: const OutlineInputBorder(),
                                ),
                                items: [
                                  for (final index in headerCandidates)
                                    DropdownMenuItem(
                                      value: index,
                                      child: Text('#${index + 1}'),
                                    ),
                                ],
                                onChanged: (index) {
                                  if (index != null) _selectHeader(index);
                                },
                              ),
                            ),
                          ];
                          return narrow
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: selectors,
                                )
                              : Row(children: selectors);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        key: ValueKey(
                          'boq-import-title-${_sheet.name}-$_headerRowIndex',
                        ),
                        initialValue: _title,
                        onChanged: (value) => setState(() => _title = value),
                        decoration: InputDecoration(
                          labelText: YorksV1BoqStrings.detectedTitle.primary,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      if (preview.validationIssues.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        for (final issue in preview.validationIssues)
                          _ImportIssueBanner(
                            copy: _importIssueCopy(issue.code),
                            language: widget.language,
                          ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _CopyText(
                        copy: YorksV1BoqStrings.columnMapping,
                        language: widget.language,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (var index = 0; index < _columns.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _ImportColumnEditor(
                            key: ValueKey(
                              'boq-import-column-${_columns[index].sourceIndex}',
                            ),
                            column: _columns[index],
                            onHeadingChanged: (value) => _updateColumn(
                              index,
                              (current) => current.copyWith(heading: value),
                            ),
                            onCanonicalChanged: (field) => _updateColumn(
                              index,
                              (current) => current.copyWith(
                                canonicalField: field,
                                clearCanonicalField: field == null,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      _CopyText(
                        copy: YorksV1BoqStrings.previewRows,
                        language: widget.language,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ImportSampleTable(preview: preview),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(YorksV1BoqStrings.cancel.primary),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('boq-confirm-import'),
                    onPressed: !preview.isValid || preview.title.trim().isEmpty
                        ? null
                        : () => Navigator.pop(context, preview),
                    icon: const Icon(Icons.file_upload_outlined),
                    label: Text(YorksV1BoqStrings.commitImport.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportColumnEditor extends StatelessWidget {
  const _ImportColumnEditor({
    super.key,
    required this.column,
    required this.onHeadingChanged,
    required this.onCanonicalChanged,
  });

  final YorksV1BoqImportColumn column;
  final ValueChanged<String> onHeadingChanged;
  final ValueChanged<YorksV1BoqCanonicalField?> onCanonicalChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = TextFormField(
        initialValue: column.heading,
        onChanged: onHeadingChanged,
        decoration: InputDecoration(
          labelText: YorksV1BoqStrings.columnHeading.primary,
          border: const OutlineInputBorder(),
        ),
      );
      final mapping = DropdownButtonFormField<YorksV1BoqCanonicalField?>(
        initialValue: column.canonicalField,
        decoration: InputDecoration(
          labelText: YorksV1BoqStrings.columnMapping.primary,
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem<YorksV1BoqCanonicalField?>(
            value: null,
            child: Text(YorksV1BoqStrings.noCanonicalMapping.primary),
          ),
          for (final field in YorksV1BoqCanonicalField.values)
            DropdownMenuItem<YorksV1BoqCanonicalField?>(
              value: field,
              child: Text(_canonicalCopy(field).primary),
            ),
        ],
        onChanged: onCanonicalChanged,
      );
      return constraints.maxWidth < 600
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: AppSpacing.sm),
                mapping,
              ],
            )
          : Row(
              children: [
                Expanded(flex: 3, child: heading),
                const SizedBox(width: AppSpacing.sm),
                Expanded(flex: 2, child: mapping),
              ],
            );
    },
  );
}

class _ImportSampleTable extends StatelessWidget {
  const _ImportSampleTable({required this.preview});

  final YorksV1BoqImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final columns = preview.columns.take(6).toList(growable: false);
    final rows = preview.rows.take(4).toList(growable: false);
    if (columns.isEmpty) {
      return _EmptyWorksheet(copy: YorksV1BoqStrings.importNoColumns);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          for (final column in columns)
            DataColumn(label: Text(column.heading.trim())),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                for (final column in columns)
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        row.valueFor(column.sourceIndex),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ImportIssueBanner extends StatelessWidget {
  const _ImportIssueBanner({required this.copy, required this.language});

  final TranslatableString copy;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: _InfoBanner(
      icon: Icons.error_outline,
      color: AppColors.error,
      title: YorksV1BoqStrings.importFailed,
      body: copy,
      language: language,
    ),
  );
}

TranslatableString _importIssueCopy(YorksV1BoqImportValidationCode code) =>
    switch (code) {
      YorksV1BoqImportValidationCode.noColumns =>
        YorksV1BoqStrings.importNoColumns,
      YorksV1BoqImportValidationCode.blankHeading =>
        YorksV1BoqStrings.importBlankHeading,
      YorksV1BoqImportValidationCode.duplicateHeading =>
        YorksV1BoqStrings.importDuplicateHeading,
      YorksV1BoqImportValidationCode.duplicateCanonicalMapping =>
        YorksV1BoqStrings.importDuplicateCanonical,
    };

class YorksV1BoqSpreadsheet extends StatefulWidget {
  const YorksV1BoqSpreadsheet({
    super.key,
    required this.worksheet,
    required this.editable,
    required this.onUpdateCell,
    required this.onAddBlankRow,
    required this.onAddSimilarRow,
    required this.onRemoveRow,
    required this.onAddColumn,
    required this.onRenameColumn,
    required this.onRemoveColumn,
  });

  final YorksV1BoqWorksheet worksheet;
  final bool editable;
  final void Function({
    required String rowId,
    required String columnId,
    required String value,
  })
  onUpdateCell;
  final YorksV1BoqRow Function({String? afterRowId}) onAddBlankRow;
  final YorksV1BoqRow Function({required String sourceRowId}) onAddSimilarRow;
  final ValueChanged<String> onRemoveRow;
  final void Function({
    required String heading,
    YorksV1BoqCanonicalField? canonicalField,
  })
  onAddColumn;
  final void Function(String columnId, String heading) onRenameColumn;
  final ValueChanged<String> onRemoveColumn;

  @override
  State<YorksV1BoqSpreadsheet> createState() => _YorksV1BoqSpreadsheetState();
}

class _YorksV1BoqSpreadsheetState extends State<YorksV1BoqSpreadsheet> {
  static const _rowHeight = 54.0;
  static const _serialWidth = 64.0;
  static const _columnWidth = 184.0;
  final _serialScroll = ScrollController();
  final _bodyScroll = ScrollController();
  final _horizontalScroll = ScrollController();
  final Map<String, FocusNode> _focusNodes = {};
  bool _syncingVertical = false;
  String? _selectedRowId;

  @override
  void initState() {
    super.initState();
    _selectedRowId = widget.worksheet.rows.firstOrNull?.id;
    _serialScroll.addListener(() => _sync(_serialScroll, _bodyScroll));
    _bodyScroll.addListener(() => _sync(_bodyScroll, _serialScroll));
  }

  @override
  void didUpdateWidget(covariant YorksV1BoqSpreadsheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.worksheet.rows.any((row) => row.id == _selectedRowId)) {
      _selectedRowId = widget.worksheet.rows.firstOrNull?.id;
    }
  }

  @override
  void dispose() {
    _serialScroll.dispose();
    _bodyScroll.dispose();
    _horizontalScroll.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _sync(ScrollController source, ScrollController target) {
    if (_syncingVertical || !source.hasClients || !target.hasClients) return;
    _syncingVertical = true;
    target.jumpTo(
      source.offset.clamp(
        target.position.minScrollExtent,
        target.position.maxScrollExtent,
      ),
    );
    _syncingVertical = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth <= AppSpacing.compactBreakpoint
          ? _buildMobile(context)
          : _buildDesktop(context),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final hasSelection = _selectedRowId != null;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          if (widget.editable) ...[
            OutlinedButton.icon(
              key: const ValueKey('boq-add-column'),
              onPressed: _addColumn,
              icon: const Icon(Icons.view_column_outlined, size: 18),
              label: Text(YorksV1BoqStrings.addColumn.primary),
            ),
            OutlinedButton.icon(
              key: const ValueKey('boq-add-blank-row'),
              onPressed: widget.worksheet.columns.isEmpty
                  ? null
                  : () {
                      final row = widget.onAddBlankRow(
                        afterRowId: _selectedRowId,
                      );
                      setState(() => _selectedRowId = row.id);
                    },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(YorksV1BoqStrings.blankRow.primary),
            ),
            OutlinedButton.icon(
              key: const ValueKey('boq-add-similar-row'),
              onPressed: !hasSelection
                  ? null
                  : () {
                      final row = widget.onAddSimilarRow(
                        sourceRowId: _selectedRowId!,
                      );
                      setState(() => _selectedRowId = row.id);
                    },
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: Text(YorksV1BoqStrings.similarRow.primary),
            ),
          ],
          _CountPill(
            label:
                '${widget.worksheet.rows.length} ${YorksV1BoqStrings.rows.primary}',
          ),
          _CountPill(
            label:
                '${widget.worksheet.columns.length} ${YorksV1BoqStrings.columns.primary}',
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final rows = widget.worksheet.rows;
    final columns = widget.worksheet.columns;
    return Container(
      key: const ValueKey('yorks-v1-boq-desktop-grid'),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildToolbar(context),
          if (columns.isEmpty)
            Expanded(child: _EmptyWorksheet(copy: YorksV1BoqStrings.noColumns))
          else
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: _serialWidth,
                    child: Column(
                      children: [
                        _HeaderCell(
                          label: YorksV1BoqStrings.serialNumber.primary,
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _serialScroll,
                            itemExtent: _rowHeight,
                            itemCount: rows.length,
                            itemBuilder: (context, index) => _SerialCell(
                              number: index + 1,
                              selected: rows[index].id == _selectedRowId,
                              onTap: () => setState(
                                () => _selectedRowId = rows[index].id,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1, color: AppColors.line),
                  Expanded(
                    child: Scrollbar(
                      controller: _horizontalScroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _horizontalScroll,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: columns.length * _columnWidth,
                          child: Column(
                            children: [
                              SizedBox(
                                height: _rowHeight,
                                child: Row(
                                  children: [
                                    for (final column in columns)
                                      _ColumnHeader(
                                        column: column,
                                        editable: widget.editable,
                                        onRename: widget.onRenameColumn,
                                        onDelete: () => _deleteColumn(column),
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: rows.isEmpty
                                    ? _EmptyWorksheet(
                                        copy: YorksV1BoqStrings.noRows,
                                      )
                                    : ListView.builder(
                                        controller: _bodyScroll,
                                        itemExtent: _rowHeight,
                                        itemCount: rows.length,
                                        itemBuilder: (context, rowIndex) {
                                          final row = rows[rowIndex];
                                          return Row(
                                            children: [
                                              for (
                                                var colIndex = 0;
                                                colIndex < columns.length;
                                                colIndex++
                                              )
                                                _GridCell(
                                                  width: _columnWidth,
                                                  row: row,
                                                  column: columns[colIndex],
                                                  editable: widget.editable,
                                                  focusNode: _focusNode(
                                                    row.id,
                                                    columns[colIndex].id,
                                                  ),
                                                  onSelected: () => setState(
                                                    () =>
                                                        _selectedRowId = row.id,
                                                  ),
                                                  onValueChanged: (value) =>
                                                      widget.onUpdateCell(
                                                        rowId: row.id,
                                                        columnId:
                                                            columns[colIndex]
                                                                .id,
                                                        value: value,
                                                      ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    final rows = widget.worksheet.rows;
    return Container(
      key: const ValueKey('yorks-v1-boq-mobile-list'),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildToolbar(context),
          Expanded(
            child: widget.worksheet.columns.isEmpty
                ? _EmptyWorksheet(copy: YorksV1BoqStrings.noColumns)
                : rows.isEmpty
                ? _EmptyWorksheet(copy: YorksV1BoqStrings.noRows)
                : ListView.separated(
                    itemCount: rows.length,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => _MobileRowCard(
                      key: ValueKey('mobile-boq-row-${rows[index].id}'),
                      row: rows[index],
                      number: index + 1,
                      columns: widget.worksheet.columns,
                      editable: widget.editable,
                      onTap: () {
                        setState(() => _selectedRowId = rows[index].id);
                        _openMobileEditor(index);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  FocusNode _focusNode(String rowId, String columnId) {
    final key = '$rowId:$columnId';
    return _focusNodes.putIfAbsent(key, () {
      final node = FocusNode(debugLabel: key);
      node.onKeyEvent = (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final delta = switch (event.logicalKey) {
          LogicalKeyboardKey.enter =>
            HardwareKeyboard.instance.isShiftPressed ? -1 : 1,
          LogicalKeyboardKey.arrowDown => 1,
          LogicalKeyboardKey.arrowUp => -1,
          _ => 0,
        };
        if (delta == 0) return KeyEventResult.ignored;
        _moveVertical(rowId, columnId, delta);
        return KeyEventResult.handled;
      };
      node.addListener(() {
        if (node.hasFocus && mounted) setState(() => _selectedRowId = rowId);
      });
      return node;
    });
  }

  void _moveVertical(String rowId, String columnId, int delta) {
    final rows = widget.worksheet.rows;
    final current = rows.indexWhere((row) => row.id == rowId);
    if (current < 0) return;
    final target = (current + delta).clamp(0, rows.length - 1);
    if (target == current || !_bodyScroll.hasClients) return;
    _bodyScroll.animateTo(
      (target * _rowHeight).clamp(
        _bodyScroll.position.minScrollExtent,
        _bodyScroll.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode(rows[target].id, columnId).requestFocus();
    });
  }

  Future<void> _addColumn() async {
    final result = await _showAddColumnDialog(context);
    if (result == null) return;
    widget.onAddColumn(heading: result.heading, canonicalField: result.mapping);
  }

  Future<void> _deleteColumn(YorksV1BoqColumn column) async {
    final hasValues = widget.worksheet.rows.any(
      (row) =>
          row.valueFor(column.id) != null &&
          '${row.valueFor(column.id)}'.isNotEmpty,
    );
    if (hasValues) {
      final confirmed = await _confirm(
        context: context,
        title: YorksV1BoqStrings.deleteColumn,
        body: YorksV1BoqStrings.deleteColumnConfirmation,
      );
      if (confirmed != true) return;
    }
    widget.onRemoveColumn(column.id);
  }

  Future<void> _openMobileEditor(int rowIndex) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _MobileBoqRowEditor(
        initialIndex: rowIndex,
        rows: widget.worksheet.rows,
        columns: widget.worksheet.columns,
        editable: widget.editable,
        onUpdateCell: widget.onUpdateCell,
        onRemoveRow: widget.onRemoveRow,
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.column,
    required this.editable,
    required this.onRename,
    required this.onDelete,
  });

  final YorksV1BoqColumn column;
  final bool editable;
  final void Function(String, String) onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _YorksV1BoqSpreadsheetState._columnWidth,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
          0,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLow,
          border: Border(right: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey('boq-column-${column.id}'),
                initialValue: column.heading,
                enabled: editable,
                onFieldSubmitted: (value) => onRename(column.id, value),
                onChanged: (value) {
                  if (value.trim().isNotEmpty) onRename(column.id, value);
                },
                style: AppTypography.labelLarge,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                ),
              ),
            ),
            if (editable)
              IconButton(
                tooltip: YorksV1BoqStrings.deleteColumn.primary,
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.minTapTarget,
                  minWidth: AppSpacing.minTapTarget,
                ),
                padding: EdgeInsets.zero,
                onPressed: onDelete,
                icon: const Icon(Icons.close_rounded, size: 17),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: _YorksV1BoqSpreadsheetState._rowHeight,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.surfaceContainerLow,
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Text(label, style: AppTypography.labelLarge),
  );
}

class _SerialCell extends StatelessWidget {
  const _SerialCell({
    required this.number,
    required this.selected,
    required this.onTap,
  });

  final int number;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.blueContainer
            : AppColors.surfaceContainerLowest,
        border: const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Text('$number', style: AppTypography.labelLarge),
    ),
  );
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.width,
    required this.row,
    required this.column,
    required this.editable,
    required this.focusNode,
    required this.onSelected,
    required this.onValueChanged,
  });

  final double width;
  final YorksV1BoqRow row;
  final YorksV1BoqColumn column;
  final bool editable;
  final FocusNode focusNode;
  final VoidCallback onSelected;
  final ValueChanged<String> onValueChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 5,
      ),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: AppColors.line),
          bottom: BorderSide(color: AppColors.line),
        ),
      ),
      child: TextFormField(
        key: ValueKey('boq-cell-${row.id}-${column.id}'),
        initialValue: '${row.valueFor(column.id) ?? ''}',
        focusNode: focusNode,
        enabled: editable,
        onTap: onSelected,
        onChanged: onValueChanged,
        style: AppTypography.bodySmall,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: 8,
          ),
        ),
      ),
    ),
  );
}

class _MobileRowCard extends StatelessWidget {
  const _MobileRowCard({
    super.key,
    required this.row,
    required this.number,
    required this.columns,
    required this.editable,
    required this.onTap,
  });

  final YorksV1BoqRow row;
  final int number;
  final List<YorksV1BoqColumn> columns;
  final bool editable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final populated = columns
        .where((column) => '${row.valueFor(column.id) ?? ''}'.trim().isNotEmpty)
        .take(2)
        .toList(growable: false);
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.blueContainer,
                foregroundColor: AppColors.blue,
                child: Text('$number', style: AppTypography.labelLarge),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final column in populated)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Text(
                          '${column.heading}: ${row.valueFor(column.id)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium,
                        ),
                      ),
                    if (populated.isEmpty)
                      Text(
                        YorksV1BoqStrings.mobileEditor.primary,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                editable ? Icons.edit_outlined : Icons.visibility_outlined,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileBoqRowEditor extends StatefulWidget {
  const _MobileBoqRowEditor({
    required this.initialIndex,
    required this.rows,
    required this.columns,
    required this.editable,
    required this.onUpdateCell,
    required this.onRemoveRow,
  });

  final int initialIndex;
  final List<YorksV1BoqRow> rows;
  final List<YorksV1BoqColumn> columns;
  final bool editable;
  final void Function({
    required String rowId,
    required String columnId,
    required String value,
  })
  onUpdateCell;
  final ValueChanged<String> onRemoveRow;

  @override
  State<_MobileBoqRowEditor> createState() => _MobileBoqRowEditorState();
}

class _MobileBoqRowEditorState extends State<_MobileBoqRowEditor> {
  late int _index;
  final Map<String, TextEditingController> _controllers = {};

  YorksV1BoqRow get _row => widget.rows[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _loadControllers();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    for (final column in widget.columns) {
      _controllers[column.id] = TextEditingController(
        text: '${_row.valueFor(column.id) ?? ''}',
      );
    }
  }

  void _saveCurrent() {
    if (!widget.editable) return;
    for (final column in widget.columns) {
      widget.onUpdateCell(
        rowId: _row.id,
        columnId: column.id,
        value: _controllers[column.id]!.text,
      );
    }
  }

  void _move(int delta) {
    _saveCurrent();
    final next = (_index + delta).clamp(0, widget.rows.length - 1);
    if (next == _index) return;
    setState(() {
      _index = next;
      _loadControllers();
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${YorksV1BoqStrings.mobileEditor.primary} ${_index + 1}',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: YorksV1BoqStrings.deleteRow.primary,
                  onPressed: !widget.editable
                      ? null
                      : () {
                          widget.onRemoveRow(_row.id);
                          Navigator.pop(context);
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
          const Divider(height: AppSpacing.lg),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (final column in widget.columns) ...[
                  TextFormField(
                    controller: _controllers[column.id],
                    enabled: widget.editable,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: column.heading,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _index == 0 ? null : () => _move(-1),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(YorksV1BoqStrings.previous.primary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _index == widget.rows.length - 1
                          ? null
                          : () => _move(1),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(YorksV1BoqStrings.next.primary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        _saveCurrent();
                        Navigator.pop(context);
                      },
                      child: Text(YorksV1BoqStrings.save.primary),
                    ),
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

class _SyncChip extends StatelessWidget {
  const _SyncChip({required this.copy, required this.color});
  final TranslatableString copy;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
    ),
    alignment: Alignment.center,
    child: Text(
      copy.primary,
      style: AppTypography.labelLarge.copyWith(color: color),
    ),
  );
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
    ),
    child: Text(label, style: AppTypography.labelLarge),
  );
}

class _EmptyWorksheet extends StatelessWidget {
  const _EmptyWorksheet({required this.copy});
  final TranslatableString copy;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Text(
        copy.primary,
        textAlign: TextAlign.center,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
      ),
    ),
  );
}

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner({required this.language});
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => _InfoBanner(
    icon: Icons.lock_outline,
    color: AppColors.navy,
    title: YorksV1BoqStrings.readOnly,
    body: YorksV1BoqStrings.readOnlyDescription,
    language: language,
  );
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.language, required this.onRefresh});
  final AppLanguage language;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => _InfoBanner(
    icon: Icons.sync_problem_outlined,
    color: AppColors.warning,
    title: YorksV1BoqStrings.unsavedChanges,
    body: YorksV1BoqStrings.syncConflict,
    language: language,
    action: TextButton(
      onPressed: onRefresh,
      child: Text(YorksV1BoqStrings.refresh.primary),
    ),
  );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.language,
    this.action,
  });
  final IconData icon;
  final Color color;
  final TranslatableString title;
  final TranslatableString body;
  final AppLanguage language;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CopyText(
                copy: title,
                language: language,
                style: AppTypography.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              _CopyText(
                copy: body,
                language: language,
                style: AppTypography.bodySmall,
              ),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.language, required this.onRetry});
  final AppLanguage language;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 42,
            color: AppColors.muted,
          ),
          const SizedBox(height: AppSpacing.md),
          _CopyText(
            copy: YorksV1BoqStrings.saveFailed,
            language: language,
            center: true,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(YorksV1BoqStrings.refresh.primary),
          ),
        ],
      ),
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

class _AddColumnResult {
  const _AddColumnResult({required this.heading, required this.mapping});
  final String heading;
  final YorksV1BoqCanonicalField? mapping;
}

Future<_AddColumnResult?> _showAddColumnDialog(BuildContext context) async {
  final controller = TextEditingController();
  YorksV1BoqCanonicalField? mapping;
  return showDialog<_AddColumnResult>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(YorksV1BoqStrings.addColumn.primary),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: YorksV1BoqStrings.columnHeading.primary,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<YorksV1BoqCanonicalField?>(
              initialValue: mapping,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint: Text(YorksV1BoqStrings.worksheet.primary),
              items: [
                const DropdownMenuItem(value: null, child: SizedBox.shrink()),
                for (final item in YorksV1BoqCanonicalField.values)
                  DropdownMenuItem(
                    value: item,
                    child: Text(_canonicalCopy(item).primary),
                  ),
              ],
              onChanged: (value) => setState(() => mapping = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(YorksV1BoqStrings.cancel.primary),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _AddColumnResult(heading: controller.text, mapping: mapping),
            ),
            child: Text(YorksV1BoqStrings.add.primary),
          ),
        ],
      ),
    ),
  ).whenComplete(controller.dispose);
}

Future<String?> _promptForText({
  required BuildContext context,
  required TranslatableString title,
  required TranslatableString label,
}) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title.primary),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: label.primary,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(YorksV1BoqStrings.cancel.primary),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(YorksV1BoqStrings.add.primary),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

Future<bool?> _confirm({
  required BuildContext context,
  required TranslatableString title,
  required TranslatableString body,
}) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title.primary),
    content: Text(body.primary),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(YorksV1BoqStrings.cancel.primary),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(title.primary),
      ),
    ],
  ),
);

TranslatableString _canonicalCopy(YorksV1BoqCanonicalField field) =>
    switch (field) {
      YorksV1BoqCanonicalField.description => YorksV1BoqStrings.description,
      YorksV1BoqCanonicalField.brandOrigin => YorksV1BoqStrings.brandOrigin,
      YorksV1BoqCanonicalField.quantity => YorksV1BoqStrings.quantity,
      YorksV1BoqCanonicalField.unit => YorksV1BoqStrings.unit,
      YorksV1BoqCanonicalField.planningModelTag =>
        YorksV1BoqStrings.planningModelTag,
    };
