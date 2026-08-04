import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/controllers/yorks_v1_material_request_draft_controller.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_boq.dart';
import '../../../../shared/models/yorks_v1_boq_strings.dart';
import '../../../../shared/models/yorks_v1_boq_workbook.dart';
import '../../../../shared/models/yorks_v1_arrangement_strings.dart';
import '../../../../shared/models/yorks_v1_arrangement.dart';
import '../../../../shared/models/yorks_v1_domain_error.dart';
import '../../../../shared/models/yorks_v1_document.dart';
import '../../../../shared/models/yorks_v1_document_strings.dart';
import '../../../../shared/models/yorks_v1_logistics_strings.dart';
import '../../../../shared/models/yorks_v1_material_request.dart';
import '../../../../shared/models/yorks_v1_material_request_document.dart';
import '../../../../shared/models/yorks_v1_material_request_strings.dart';
import '../../../../shared/models/yorks_v1_project.dart';
import '../../../../shared/models/yorks_v1_role.dart';
import '../../../../shared/models/yorks_v1_shell_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_boq_repository_provider.dart';
import '../../../../shared/providers/yorks_v1_boq_workbook_provider.dart';
import '../../../../shared/providers/yorks_v1_feature_flags_provider.dart';
import '../../../../shared/providers/yorks_v1_identity_provider.dart';
import '../../../../shared/providers/yorks_v1_documents_repository_provider.dart';
import '../../../../shared/providers/yorks_v1_material_request_provider.dart';
import '../../../../shared/providers/yorks_v1_material_request_repository_provider.dart';
import '../../../../shared/providers/yorks_v1_arrangement_provider.dart';
import '../../../../shared/services/yorks_v1_material_request_document_service.dart';
import '../../../../shared/services/yorks_v1_boq_workbook_service.dart';
import '../../../../shared/providers/session_provider.dart';
import '../../../../shared/providers/permissions_provider.dart';

import 'yorks_v1_arrangement_screen.dart';

const _mrUnitOptions = <String>[
  'Nos',
  'Each',
  'Meter',
  'Cm',
  'Length',
  'Set',
  'Pairs',
  'Roll',
  'Box',
  'Kg',
  'Litre',
  'Pack',
  'Lot',
];

/// V1 material request overview. It reads only the server projection; drafts
/// are returned only to their creator by the database contract.
class YorksV1MaterialRequestsScreen extends ConsumerWidget {
  const YorksV1MaterialRequestsScreen({super.key, this.projectId});

  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final requests = ref.watch(yorksV1MaterialRequestListProvider(projectId));
    final canCreate = role?.canCreateMaterialRequest ?? false;
    final compactRoute =
        MediaQuery.sizeOf(context).width < AppSpacing.yorksV1DesktopBreakpoint;
    final canOpenInventory =
        ref.watch(yorksV1FeatureFlagsProvider).logistics &&
        (role == YorksV1Role.procurement || role == YorksV1Role.admin);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: compactRoute
          ? AppBar(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              title: _CopyText(
                copy: YorksV1MaterialRequestStrings.requests,
                language: language,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
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
                  onPressed: () =>
                      ref.invalidate(yorksV1MaterialRequestListProvider),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            )
          : null,
      floatingActionButton: compactRoute && canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push(
                RoutePaths.yorksV1MaterialRequestDraftPath(
                  const Uuid().v4(),
                  projectId: projectId,
                ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!compactRoute) ...[
                YorksR35PageHeader(
                  eyebrow: YorksV1ShellStrings.operationalWorkspace.primary,
                  title: YorksV1MaterialRequestStrings.requests.primary,
                  description:
                      YorksV1MaterialRequestStrings.requestsDescription.primary,
                  actions: [
                    if (canCreate)
                      SizedBox(
                        height: AppSpacing.minTapTarget,
                        child: FilledButton.icon(
                          onPressed: () => context.push(
                            RoutePaths.yorksV1MaterialRequestDraftPath(
                              const Uuid().v4(),
                              projectId: projectId,
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(
                            YorksV1MaterialRequestStrings.newRequest.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              _RequestsWorkflowBanner(),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: requests.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => _RequestError(
                    language: language,
                    onRetry: () =>
                        ref.invalidate(yorksV1MaterialRequestListProvider),
                  ),
                  data: (items) => _RequestsPanel(
                    requests: items,
                    language: language,
                    canCreate: canCreate,
                    onOpen: (request) =>
                        context.push(_materialRequestOpenPath(request)),
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

/// Route-level R35 queues make the sidebar Dispatches and Material Returns
/// destinations usable without first opening a specific material request.
/// They are safe server projections only; selection simply opens the existing
/// request-scoped workflow that owns all transition commands.
enum YorksV1WorkflowQueueKind { dispatches, returns }

class YorksV1WorkflowQueueScreen extends ConsumerWidget {
  const YorksV1WorkflowQueueScreen({super.key, required this.kind});

  final YorksV1WorkflowQueueKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final requests = ref.watch(yorksV1MaterialRequestListProvider(null));
    final title = switch (kind) {
      YorksV1WorkflowQueueKind.dispatches => YorksV1ShellStrings.dispatches,
      YorksV1WorkflowQueueKind.returns => YorksV1ShellStrings.materialReturns,
    };
    final description = switch (kind) {
      YorksV1WorkflowQueueKind.dispatches =>
        YorksV1LogisticsStrings.dispatchAndReceipt,
      YorksV1WorkflowQueueKind.returns =>
        YorksV1LogisticsStrings.deliveryOrdersAndReturns,
    };

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        top: false,
        child: NexusPageShell(
          eyebrow: YorksV1ShellStrings.operationalWorkspace.primary,
          title: title.primary,
          description: description.primary,
          actions: [
            SizedBox(
              height: AppSpacing.controlHeight,
              child: OutlinedButton.icon(
                onPressed: () =>
                    ref.invalidate(yorksV1MaterialRequestListProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(YorksV1MaterialRequestStrings.refresh.primary),
              ),
            ),
          ],
          child: requests.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.huge),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, _) => _RequestError(
              language: language,
              onRetry: () => ref.invalidate(yorksV1MaterialRequestListProvider),
            ),
            data: (items) {
              final visible = [
                for (final request in items)
                  if (_isVisibleInQueue(request, kind)) request,
              ];
              if (visible.isEmpty) {
                return _WorkflowQueueEmpty(kind: kind, language: language);
              }
              return LedgerCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title.primary,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          StatusChip.info(
                            '${visible.length}',
                            icon: Icons.format_list_numbered_rounded,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.line),
                    for (var index = 0; index < visible.length; index++) ...[
                      _WorkflowQueueRow(request: visible[index], kind: kind),
                      if (index + 1 < visible.length)
                        const Divider(height: 1, color: AppColors.line),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  bool _isVisibleInQueue(
    YorksV1MaterialRequest request,
    YorksV1WorkflowQueueKind value,
  ) {
    return switch (value) {
      YorksV1WorkflowQueueKind.dispatches => switch (request.state) {
        YorksV1MaterialRequestState.approved ||
        YorksV1MaterialRequestState.partiallyDispatched ||
        YorksV1MaterialRequestState.dispatched ||
        YorksV1MaterialRequestState.partiallyReceived => true,
        _ => false,
      },
      YorksV1WorkflowQueueKind.returns => switch (request.state) {
        YorksV1MaterialRequestState.partiallyReceived ||
        YorksV1MaterialRequestState.received ||
        YorksV1MaterialRequestState.closed => true,
        _ => false,
      },
    };
  }
}

class _WorkflowQueueRow extends StatelessWidget {
  const _WorkflowQueueRow({required this.request, required this.kind});

  final YorksV1MaterialRequest request;
  final YorksV1WorkflowQueueKind kind;

  @override
  Widget build(BuildContext context) {
    final action = switch (kind) {
      YorksV1WorkflowQueueKind.dispatches =>
        YorksV1LogisticsStrings.dispatchAndReceipt,
      YorksV1WorkflowQueueKind.returns =>
        YorksV1LogisticsStrings.deliveryOrdersAndReturns,
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(
          kind == YorksV1WorkflowQueueKind.dispatches
              ? RoutePaths.yorksV1MaterialRequestLogisticsPath(request.id)
              : RoutePaths.yorksV1MaterialRequestReturnsDocumentsPath(
                  request.id,
                ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final identity = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.requestNumber ??
                          YorksV1MaterialRequestStrings.draft.primary,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      request.title ?? request.projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${request.projectReference} · ${request.scopeName} · ${request.lines.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                );
                final controls = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StateChip(request: request, language: AppLanguage.english),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              action.primary,
                              style: AppTypography.labelMedium.copyWith(
                                color: AppColors.inkSecondary,
                              ),
                            ),
                          ),
                          controls,
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: AppSpacing.lg),
                    Text(
                      action.primary,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    controls,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkflowQueueEmpty extends StatelessWidget {
  const _WorkflowQueueEmpty({required this.kind, required this.language});

  final YorksV1WorkflowQueueKind kind;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final copy = switch (kind) {
      YorksV1WorkflowQueueKind.dispatches =>
        YorksV1LogisticsStrings.noDeliveryOrders,
      YorksV1WorkflowQueueKind.returns =>
        YorksV1MaterialRequestStrings.noRequests,
    };
    return LedgerCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              kind == YorksV1WorkflowQueueKind.dispatches
                  ? Icons.local_shipping_outlined
                  : Icons.assignment_return_outlined,
              size: 42,
              color: AppColors.muted,
            ),
            const SizedBox(height: AppSpacing.lg),
            _CopyText(copy: copy, language: language, center: true),
          ],
        ),
      ),
    );
  }
}

class YorksV1MaterialRequestDraftScreen extends ConsumerStatefulWidget {
  const YorksV1MaterialRequestDraftScreen({
    super.key,
    required this.draftId,
    this.boqGroupId,
    this.projectId,
  });

  final String draftId;
  final String? boqGroupId;
  final String? projectId;

  @override
  ConsumerState<YorksV1MaterialRequestDraftScreen> createState() =>
      _YorksV1MaterialRequestDraftScreenState();
}

class _YorksV1MaterialRequestDraftScreenState
    extends ConsumerState<YorksV1MaterialRequestDraftScreen> {
  bool _seededFromBoq = false;
  bool _seededProjectFromRoute = false;
  bool _hydratedFromServer = false;

  @override
  Widget build(BuildContext context) {
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
      draftId: widget.draftId,
    );
    final state = ref.watch(yorksV1MaterialRequestDraftControllerProvider(key));
    final controller = ref.read(
      yorksV1MaterialRequestDraftControllerProvider(key).notifier,
    );
    final shouldHydrateFromServer =
        state.draft.serverRecordVersion == 0 &&
        state.draft.updatedAt.millisecondsSinceEpoch == 0;
    final serverDraft = shouldHydrateFromServer
        ? ref.watch(yorksV1MaterialRequestDetailProvider(widget.draftId))
        : null;
    if (!_hydratedFromServer &&
        serverDraft is AsyncData<YorksV1MaterialRequest>) {
      final request = serverDraft.value;
      if (request.state.isDraft) {
        _hydratedFromServer = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) controller.hydrateFromServer(request);
        });
      }
    }
    final routeProjectId = widget.projectId?.trim();
    final canSeedProjectFromRoute =
        routeProjectId != null &&
        routeProjectId.isNotEmpty &&
        state.draft.projectId == null &&
        (!_shouldHydrateFromServer(state) || serverDraft is AsyncError);
    if (!_seededProjectFromRoute && canSeedProjectFromRoute) {
      _seededProjectFromRoute = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.setProject(routeProjectId);
      });
    }
    if (!_seededFromBoq && widget.boqGroupId != null) {
      _seededFromBoq = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _seedDraftFromBoq(controller, state.draft);
      });
    }
    return _DraftForm(
      state: state,
      controller: controller,
      draftKey: key,
      language: language,
    );
  }

  bool _shouldHydrateFromServer(YorksV1MaterialRequestDraftState state) =>
      state.draft.serverRecordVersion == 0 &&
      state.draft.updatedAt.millisecondsSinceEpoch == 0;

  Future<void> _seedDraftFromBoq(
    YorksV1MaterialRequestDraftController controller,
    YorksV1MaterialRequestDraft draft,
  ) async {
    final groupId = widget.boqGroupId?.trim();
    final projectId = widget.projectId?.trim();
    if (groupId == null || groupId.isEmpty || draft.lines.isNotEmpty) return;
    try {
      if (projectId != null && projectId.isNotEmpty) {
        await controller.setProject(projectId);
      }
      final worksheet = await ref
          .read(yorksV1BoqRepositoryProvider)
          .getWorksheet(groupId);
      await controller.addBoqRows(
        worksheet: worksheet,
        rowIds: worksheet.rows.map((row) => row.id),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(YorksV1MaterialRequestStrings.saveFailed.primary),
        ),
      );
    }
  }
}

String _materialRequestOpenPath(YorksV1MaterialRequest request) {
  if (request.state.isDraft) {
    return RoutePaths.yorksV1MaterialRequestDraftPath(
      request.id,
      projectId: request.projectId,
    );
  }
  return RoutePaths.yorksV1MaterialRequestPath(request.id);
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
    final compactRoute =
        MediaQuery.sizeOf(context).width < AppSpacing.yorksV1DesktopBreakpoint;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: compactRoute
          ? AppBar(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              title: _CopyText(
                copy: YorksV1MaterialRequestStrings.requests,
                language: language,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: YorksV1MaterialRequestStrings.refresh.primary,
                  onPressed: () => ref.invalidate(
                    yorksV1MaterialRequestDetailProvider(requestId),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            )
          : null,
      body: request.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _RequestError(
          language: language,
          onRetry: () =>
              ref.invalidate(yorksV1MaterialRequestDetailProvider(requestId)),
        ),
        data: (value) => _RequestDetailBody(
          request: value,
          language: language,
          showPageHeader: !compactRoute,
          onRefresh: () =>
              ref.invalidate(yorksV1MaterialRequestDetailProvider(requestId)),
        ),
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
    // R35 starts every new request at the server-created Common / All
    // Buildings scope.  Keep that convenience without making the scope a
    // client-side authority: the ordered RPC response is still the source of
    // truth and the submit RPC validates the selected scope again.
    if (draft.projectId != null &&
        draft.scopeId == null &&
        scopes is AsyncData<List<YorksV1MaterialRequestScopeOption>> &&
        scopes.value.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final current = controller.currentDraft;
        if (current.projectId == draft.projectId && current.scopeId == null) {
          controller.setScope(scopes.value.first.id);
        }
      });
    }
    final selectedProject = projects.valueOrNull
        ?.where((item) => item.id == draft.projectId)
        .firstOrNull;
    final projectIsActive =
        selectedProject?.state == YorksV1ProjectLifecycle.active.wireValue;
    final canSubmit =
        draft.canSubmitLocally &&
        projectIsActive &&
        state.status != YorksV1MaterialRequestDraftSyncStatus.submitting;
    final isBusy =
        state.status == YorksV1MaterialRequestDraftSyncStatus.saving ||
        state.status == YorksV1MaterialRequestDraftSyncStatus.submitting;
    final excelEnabled = ref.watch(yorksV1FeatureFlagsProvider).excel;
    final workbookFileService = ref.watch(
      yorksV1BoqWorkbookFileServiceProvider,
    );
    final documentService = YorksV1MaterialRequestDocumentService();
    final compactRoute =
        MediaQuery.sizeOf(context).width < AppSpacing.yorksV1DesktopBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: compactRoute
          ? AppBar(
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
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop =
                constraints.maxWidth >= AppSpacing.yorksV1DesktopBreakpoint;
            final horizontal = desktop
                ? AppSpacing.xxxl + AppSpacing.xs
                : AppSpacing.lg;
            final submit = canSubmit
                ? () => _submit(context, ref, controller)
                : null;
            final save = isBusy
                ? null
                : () => _save(context, ref, controller, draft);
            final requestNumber = _previewRequestNumber(selectedProject);
            final form = _R35RequestCard(
              title: YorksV1MaterialRequestStrings.requestInformation.primary,
              description: YorksV1MaterialRequestStrings
                  .requestInformationDescription
                  .primary,
              child: _RequestFormFields(
                draft: draft,
                projects: projects,
                scopes: scopes,
                controller: controller,
              ),
            );
            final items = _R35RequestCard(
              title: YorksV1MaterialRequestStrings.materialItems.primary,
              description: YorksV1MaterialRequestStrings
                  .materialItemsDescription
                  .primary,
              actions: [
                _R35RequestAction(
                  label: YorksV1MaterialRequestStrings.addCustomItem.primary,
                  icon: Icons.add_rounded,
                  primary: true,
                  onPressed: isBusy ? null : controller.addCustomLine,
                ),
                _R35RequestAction(
                  label: YorksV1MaterialRequestStrings.addBlankRow.primary,
                  icon: Icons.table_rows_outlined,
                  onPressed: isBusy ? null : controller.addBlankLine,
                ),
                if (draft.lines.isNotEmpty)
                  _R35RequestAction(
                    label: YorksV1MaterialRequestStrings.addSimilarRow.primary,
                    icon: Icons.copy_outlined,
                    onPressed: isBusy ? null : controller.addSimilarLine,
                  ),
                _R35RequestAction(
                  label: YorksV1MaterialRequestStrings.addFromBoq.primary,
                  icon: Icons.folder_outlined,
                  onPressed: isBusy || draft.projectId == null
                      ? null
                      : () => _addBoqRows(context, ref, controller, draft),
                ),
                if (excelEnabled)
                  _R35RequestAction(
                    label: YorksV1MaterialRequestStrings.importExcel.primary,
                    icon: Icons.upload_outlined,
                    onPressed: isBusy
                        ? null
                        : () => _importExcel(context, ref, controller),
                  ),
                if (excelEnabled)
                  _R35RequestAction(
                    label: YorksV1MaterialRequestStrings.exportExcel.primary,
                    icon: Icons.download_outlined,
                    onPressed: isBusy
                        ? null
                        : () => _exportDraft(
                            context,
                            workbookFileService,
                            documentService,
                            draft,
                          ),
                  ),
              ],
              child: _RequestLinesEditor(
                lines: draft.lines,
                controller: controller,
                enabled: !isBusy,
              ),
            );
            final notices = [
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
              if (draft.projectId != null &&
                  selectedProject != null &&
                  !projectIsActive)
                _InlineMessage(
                  copy: YorksV1MaterialRequestStrings.projectMustBeActive,
                  language: language,
                ),
            ];
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                AppSpacing.xxxl,
                horizontal,
                72,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.pageMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!compactRoute) ...[
                      _R35RequestHero(
                        title: requestNumber,
                        requesterName: ref.watch(actorNameProvider),
                        projectName: selectedProject?.name,
                        lineCount: draft.lines.length,
                        onCancel: () => context.pop(),
                        onSubmit: submit,
                        submitting:
                            state.status ==
                            YorksV1MaterialRequestDraftSyncStatus.submitting,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (desktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                form,
                                const SizedBox(height: AppSpacing.xxxl),
                                items,
                                for (final notice in notices) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  notice,
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          SizedBox(
                            width: 320,
                            child: _R35RequestReview(
                              draft: draft,
                              projects: projects,
                              scopes: scopes,
                              requesterName: ref.watch(actorNameProvider),
                              onSave: save,
                              onSubmit: submit,
                              submitting:
                                  state.status ==
                                  YorksV1MaterialRequestDraftSyncStatus
                                      .submitting,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      form,
                      const SizedBox(height: AppSpacing.lg),
                      _R35RequestReview(
                        draft: draft,
                        projects: projects,
                        scopes: scopes,
                        requesterName: ref.watch(actorNameProvider),
                        onSave: save,
                        onSubmit: submit,
                        submitting:
                            state.status ==
                            YorksV1MaterialRequestDraftSyncStatus.submitting,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      items,
                      for (final notice in notices) ...[
                        const SizedBox(height: AppSpacing.lg),
                        notice,
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
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
    // Grid cells keep their editing buffer locally for responsive web input.
    // Commit the active cell before a deliberate workflow action reads the
    // draft, so Save always includes the visible value.
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    final wasServerReady = controller.currentDraft.canSubmitLocally;
    final saved = await controller.saveDraft();
    if (!context.mounted) return;
    if (saved == null) {
      _snack(
        context,
        wasServerReady
            ? YorksV1MaterialRequestStrings.saveFailed.primary
            : YorksV1MaterialRequestStrings.savedLocally.primary,
      );
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
    // See _save: Submit must validate the value the engineer can still see in
    // the active local editor instead of a stale draft snapshot.
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    final submitted = await controller.submit();
    if (!context.mounted) return;
    if (submitted == null) {
      final message = controller.lastErrorCode == YorksV1DomainErrorCode.offline
          ? YorksV1MaterialRequestStrings.offlineSubmit.primary
          : YorksV1MaterialRequestStrings.submitFailed.primary;
      _snack(context, message);
      return;
    }
    ref.invalidate(yorksV1MaterialRequestListProvider);
    context.go(RoutePaths.yorksV1MaterialRequestPath(submitted.id));
  }
}

/// Display-only preview matching the R35 prototype. The server assigns the
/// authoritative request number during Submit; this value must never be used
/// as an identifier for a write or workflow transition.
String _previewRequestNumber(YorksV1MaterialRequestProjectOption? project) =>
    YorksV1MaterialRequestStrings.assignedOnSubmit.primary;

class _R35RequestHero extends StatelessWidget {
  const _R35RequestHero({
    required this.title,
    required this.requesterName,
    required this.projectName,
    required this.lineCount,
    required this.onCancel,
    required this.onSubmit,
    required this.submitting,
  });

  final String title;
  final String requesterName;
  final String? projectName;
  final int lineCount;
  final VoidCallback onCancel;
  final VoidCallback? onSubmit;
  final bool submitting;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked = constraints.maxWidth < 820;
      final lead = _R35RequestSurface(
        minHeight: stacked ? null : 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              YorksV1MaterialRequestStrings.newRequest.primary.toUpperCase(),
              style: AppTypography.eyebrow.copyWith(
                color: const Color(0xFF82B7F4),
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: AppTypography.headlineLarge.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              YorksV1MaterialRequestStrings.requestScopeDescription.primary,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _R35RequestAction(
                  label: YorksV1MaterialRequestStrings.cancel.primary,
                  onPressed: onCancel,
                ),
                _R35RequestAction(
                  label:
                      YorksV1MaterialRequestStrings.submitToProcurement.primary,
                  icon: Icons.arrow_forward_rounded,
                  primary: true,
                  onPressed: onSubmit,
                  loading: submitting,
                ),
              ],
            ),
          ],
        ),
      );
      final summary = _R35RequestSurface(
        minHeight: stacked ? null : 250,
        child: Column(
          children: [
            _R35RequestFact(
              label: YorksV1MaterialRequestStrings.requestedBy.primary,
              value: requesterName.trim().isEmpty
                  ? YorksV1MaterialRequestStrings.requester.primary
                  : requesterName,
            ),
            const SizedBox(height: AppSpacing.md),
            _R35RequestFact(
              label: YorksV1MaterialRequestStrings.projectEngineer.primary,
              value: projectName?.trim().isNotEmpty == true
                  ? YorksV1MaterialRequestStrings.notProvided.primary
                  : YorksV1MaterialRequestStrings.selectProject.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            _R35RequestFact(
              label: YorksV1MaterialRequestStrings.items.primary,
              value: '$lineCount',
            ),
          ],
        ),
      );
      if (stacked) {
        return Column(
          children: [
            lead,
            const SizedBox(height: AppSpacing.md),
            summary,
          ],
        );
      }
      return Row(
        // This row lives inside the draft's vertical SingleChildScrollView,
        // so its incoming height is unbounded. Stretching children across
        // that axis would request an infinite height and leave the viewport
        // without a size on Flutter web.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: lead),
          const SizedBox(width: AppSpacing.lg),
          Expanded(flex: 2, child: summary),
        ],
      );
    },
  );
}

class _R35RequestCard extends StatelessWidget {
  const _R35RequestCard({
    required this.title,
    required this.child,
    this.description,
    this.actions = const [],
  });

  final String title;
  final String? description;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) => _R35RequestSurface(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                description!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
          ],
        );
        final actionWrap = Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: actions,
        );
        // The action row is intentionally stacked until there is enough room
        // for the title to retain a readable width.  Without this guard the
        // Material Items heading is squeezed into one character per line on
        // medium desktop windows when the review panel shares the row.  The
        // card threshold is intentionally wider than the app breakpoint
        // because this card has its own constrained column.
        final compact = constraints.maxWidth < 1320;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact) ...[
              heading,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                actionWrap,
              ],
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heading),
                  if (actions.isNotEmpty) actionWrap,
                ],
              ),
            const SizedBox(height: AppSpacing.xl),
            child,
          ],
        );
      },
    ),
  );
}

class _R35RequestReview extends StatelessWidget {
  const _R35RequestReview({
    required this.draft,
    required this.projects,
    required this.scopes,
    required this.requesterName,
    required this.onSave,
    required this.onSubmit,
    required this.submitting,
  });

  final YorksV1MaterialRequestDraft draft;
  final AsyncValue<List<YorksV1MaterialRequestProjectOption>> projects;
  final AsyncValue<List<YorksV1MaterialRequestScopeOption>> scopes;
  final String requesterName;
  final VoidCallback? onSave;
  final VoidCallback? onSubmit;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final projectMatches = (projects.valueOrNull ?? const [])
        .where((item) => item.id == draft.projectId)
        .toList(growable: false);
    final project = projectMatches.isEmpty ? null : projectMatches.first;
    final scopeMatches = (scopes.valueOrNull ?? const [])
        .where((item) => item.id == draft.scopeId)
        .toList(growable: false);
    final scope = scopeMatches.isEmpty ? null : scopeMatches.first;
    final ready =
        draft.canSubmitLocally &&
        project?.state == YorksV1ProjectLifecycle.active.wireValue;
    return _R35RequestSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  YorksV1MaterialRequestStrings.review.primary,
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _ReviewStatusChip(ready: ready),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            YorksV1MaterialRequestStrings.reviewDescription.primary,
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.lg),
          _R35RequestFact(
            label: YorksV1MaterialRequestStrings.requestNumber.primary,
            value: _previewRequestNumber(project),
          ),
          const SizedBox(height: AppSpacing.sm),
          _R35RequestFact(
            label: YorksV1MaterialRequestStrings.project.primary,
            value: project == null
                ? YorksV1MaterialRequestStrings.project.primary
                : '${project.reference} · ${project.name}',
          ),
          const SizedBox(height: AppSpacing.sm),
          _R35RequestFact(
            label: YorksV1MaterialRequestStrings.scopeLabel.primary,
            value: scope?.name ?? YorksV1MaterialRequestStrings.scope.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          _R35RequestFact(
            label: YorksV1MaterialRequestStrings.delivery.primary,
            value: yorksV1MaterialRequestTimingCopy(draft.timing).primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          _R35RequestFact(
            label: YorksV1MaterialRequestStrings.requestedBy.primary,
            value: requesterName.trim().isEmpty
                ? YorksV1MaterialRequestStrings.notProvided.primary
                : requesterName,
          ),
          const SizedBox(height: AppSpacing.sm),
          _R35RequestFact(
            label: YorksV1MaterialRequestStrings.projectEngineer.primary,
            value: YorksV1MaterialRequestStrings.notProvided.primary,
          ),
          const SizedBox(height: AppSpacing.xl),
          _R35RequestAction(
            label: YorksV1MaterialRequestStrings.submitToProcurement.primary,
            icon: Icons.arrow_forward_rounded,
            primary: true,
            onPressed: onSubmit,
            loading: submitting,
            expanded: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          _R35RequestAction(
            label: YorksV1MaterialRequestStrings.saveDraft.primary,
            icon: Icons.save_outlined,
            onPressed: onSave,
            expanded: true,
          ),
        ],
      ),
    );
  }
}

class _R35RequestSurface extends StatelessWidget {
  const _R35RequestSurface({required this.child, this.minHeight});

  final Widget child;
  final double? minHeight;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: minHeight ?? 0),
    padding: const EdgeInsets.all(AppSpacing.xl + AppSpacing.xs),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 26,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: child,
  );
}

class _ReviewStatusChip extends StatelessWidget {
  const _ReviewStatusChip({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    final background = ready
        ? AppColors.successContainer
        : AppColors.warningContainer;
    final foreground = ready
        ? AppColors.onSuccessContainer
        : AppColors.onWarningContainer;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        (ready
                ? YorksV1MaterialRequestStrings.ready
                : YorksV1MaterialRequestStrings.addItems)
            .primary,
        style: AppTypography.labelMedium.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _R35RequestFact extends StatelessWidget {
  const _R35RequestFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _R35RequestAction extends StatelessWidget {
  const _R35RequestAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.loading = false,
    this.expanded = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      height: AppSpacing.minTapTarget,
      child: primary
          ? FilledButton.icon(
              onPressed: loading ? null : onPressed,
              icon: loading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(icon ?? Icons.arrow_forward_rounded, size: 19),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd + 2),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: icon == null
                  ? const SizedBox.shrink()
                  : Icon(icon, size: 18),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.inkSecondary,
                side: const BorderSide(color: AppColors.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd + 2),
                ),
              ),
            ),
    );
    return expanded ? SizedBox(width: double.infinity, child: child) : child;
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
      final title = TextFormField(
        key: const ValueKey('mr-title'),
        initialValue: draft.title ?? '',
        onChanged: controller.setTitle,
        decoration: InputDecoration(
          labelText: YorksV1MaterialRequestStrings.requestTitle.primary,
        ),
      );
      final fields = <Widget>[
        _ProjectDropdown(
          value: draft.projectId,
          projects: projects,
          onChanged: (projectId) async {
            final requiresConfirmation =
                controller.currentDraft.lines.isNotEmpty &&
                projectId != controller.currentDraft.projectId;
            if (requiresConfirmation) {
              final confirmed = await showDialog<bool>(
                context: context,
                animationStyle: AnimationStyle.noAnimation,
                builder: (dialogContext) => AlertDialog(
                  title: Text(
                    YorksV1MaterialRequestStrings.changeProject.primary,
                  ),
                  content: Text(
                    YorksV1MaterialRequestStrings
                        .changeProjectDiscardLines
                        .primary
                        .replaceFirst(
                          '{count}',
                          controller.currentDraft.lines.length.toString(),
                        ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(YorksV1MaterialRequestStrings.cancel.primary),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(
                        YorksV1MaterialRequestStrings.changeProject.primary,
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
            }
            await controller.setProject(
              projectId,
              discardExistingLines: requiresConfirmation,
            );
          },
        ),
        _ScopeDropdown(
          value: draft.scopeId,
          scopes: scopes,
          onChanged: controller.setScope,
        ),
        _TimingPicker(draft: draft, controller: controller),
        if (draft.timing == YorksV1MaterialRequestTiming.scheduled)
          _ScheduledDateField(draft: draft, controller: controller),
        _OptionalDeliveryNote(draft: draft, controller: controller),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: AppSpacing.md),
          if (!half)
            for (final field in fields) ...[
              field,
              const SizedBox(height: AppSpacing.md),
            ]
          else
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final field in fields)
                  SizedBox(
                    width: (constraints.maxWidth - AppSpacing.md) / 2,
                    child: field,
                  ),
              ],
            ),
        ],
      );
    },
  );
}

class _OptionalDeliveryNote extends StatefulWidget {
  const _OptionalDeliveryNote({required this.draft, required this.controller});

  final YorksV1MaterialRequestDraft draft;
  final YorksV1MaterialRequestDraftController controller;

  @override
  State<_OptionalDeliveryNote> createState() => _OptionalDeliveryNoteState();
}

class _OptionalDeliveryNoteState extends State<_OptionalDeliveryNote> {
  late bool _expanded = widget.draft.deliveryNote?.trim().isNotEmpty == true;

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _expanded = true),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(YorksV1MaterialRequestStrings.deliveryNote.primary),
        ),
      );
    }
    return TextFormField(
      key: const ValueKey('mr-delivery'),
      initialValue: widget.draft.deliveryNote ?? '',
      minLines: 2,
      maxLines: 3,
      onChanged: widget.controller.setDeliveryNote,
      decoration: InputDecoration(
        labelText: YorksV1MaterialRequestStrings.deliveryNote.primary,
        suffixIcon: IconButton(
          tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            widget.controller.setDeliveryNote(null);
            setState(() => _expanded = false);
          },
        ),
      ),
    );
  }
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
        labelText: YorksV1MaterialRequestStrings.buildingOther.primary,
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
          labelText: YorksV1MaterialRequestStrings.requestTiming.primary,
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

class _RequestLinesEditor extends ConsumerWidget {
  const _RequestLinesEditor({
    required this.lines,
    required this.controller,
    required this.enabled,
  });

  final List<YorksV1MaterialRequestLine> lines;
  final YorksV1MaterialRequestDraftController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (lines.isEmpty) {
      return Text(
        YorksV1MaterialRequestStrings.missingRequired.primary,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
      );
    }
    final showCommercial = ref.watch(canViewCommercialsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lines.any((line) => line.quantityIsSuggested)) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.warningContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    YorksV1MaterialRequestStrings
                        .suggestedQuantityReview
                        .primary,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 760
              ? _DesktopLinesTable(
                  lines: lines,
                  controller: controller,
                  enabled: enabled,
                  showCommercial: showCommercial,
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
        ),
      ],
    );
  }
}

class _DesktopLinesTable extends StatelessWidget {
  const _DesktopLinesTable({
    required this.lines,
    required this.controller,
    required this.enabled,
    required this.showCommercial,
  });

  final List<YorksV1MaterialRequestLine> lines;
  final YorksV1MaterialRequestDraftController controller;
  final bool enabled;
  final bool showCommercial;

  @override
  Widget build(BuildContext context) {
    // The UI intentionally mirrors the familiar Yorks material form.  The
    // controlled Excel/PDF contract remains role-safe, but the editable web
    // grid keeps size and model/tag visible as first-class columns so an
    // engineer can scan and correct a row without opening a secondary editor.
    final tableWidth = 1360.0;
    final headerStyle = AppTypography.labelSmall.copyWith(
      color: AppColors.muted,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
    );
    final rows = <TableRow>[
      TableRow(
        decoration: const BoxDecoration(color: AppColors.surfaceContainerLow),
        children: [
          _MrTableCell(
            child: Text(
              YorksV1MaterialRequestStrings.serialNumber.primary,
              style: headerStyle,
            ),
          ),
          _MrTableCell(
            child: Text(
              YorksV1MaterialRequestStrings.itemDescription.primary
                  .toUpperCase(),
              style: headerStyle,
            ),
          ),
          _MrTableCell(
            child: Text(
              YorksV1MaterialRequestStrings.size.primary.toUpperCase(),
              style: headerStyle,
            ),
          ),
          _MrTableCell(
            child: Text(
              YorksV1MaterialRequestStrings.planningModelTag.primary
                  .toUpperCase(),
              style: headerStyle,
            ),
          ),
          _MrTableCell(
            child: Text(
              YorksV1MaterialRequestStrings.brandOrigin.primary.toUpperCase(),
              style: headerStyle,
            ),
          ),
          _MrTableCell(
            child: Text(
              YorksV1MaterialRequestStrings.quantity.primary.toUpperCase(),
              style: headerStyle,
            ),
          ),
          _MrTableCell(
            child: Text(
              YorksV1MaterialRequestStrings.unit.primary.toUpperCase(),
              style: headerStyle,
            ),
          ),
          _MrTableCell(
            child: Text(
              YorksV1MaterialRequestStrings.unitCost.primary.toUpperCase(),
              style: headerStyle,
            ),
          ),
          _MrTableCell(
            child: Text(
              YorksV1MaterialRequestStrings.totalCost.primary.toUpperCase(),
              style: headerStyle,
            ),
          ),
          _MrTableCell(child: const SizedBox.shrink()),
        ],
      ),
    ];
    for (final line in lines) {
      rows.add(
        TableRow(
          children: [
            _MrTableCell(
              child: Text(
                line.displayOrder.toString(),
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.inkSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _MrTableCell(
              child: _LineTextField(
                fieldKey: ValueKey('${line.id}-description'),
                initialValue: line.description,
                enabled: enabled,
                onChanged: (value) => controller.updateLine(
                  line.id,
                  (current) => current.copyWith(description: value),
                ),
              ),
            ),
            _MrTableCell(
              child: _LineTextField(
                fieldKey: ValueKey('${line.id}-size'),
                initialValue: line.size ?? '',
                enabled: enabled,
                hintText: YorksV1MaterialRequestStrings.size.primary,
                onChanged: (value) => controller.updateLine(
                  line.id,
                  (current) => current.copyWith(
                    size: value.trim().isEmpty ? null : value,
                  ),
                ),
              ),
            ),
            _MrTableCell(
              child: _LineTextField(
                fieldKey: ValueKey('${line.id}-planning-model-tag'),
                initialValue: line.model ?? line.planningModelTag ?? '',
                enabled: enabled,
                hintText:
                    YorksV1MaterialRequestStrings.planningModelTag.primary,
                onChanged: (value) => controller.updateLine(
                  line.id,
                  (current) => current.copyWith(
                    model: value.trim().isEmpty ? null : value,
                  ),
                ),
              ),
            ),
            _MrTableCell(
              child: _LineTextField(
                fieldKey: ValueKey('${line.id}-brand-origin'),
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
            _MrTableCell(
              child: _LineTextField(
                fieldKey: ValueKey('${line.id}-quantity'),
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
            _MrTableCell(
              child: _LineUnitDropdown(
                fieldKey: ValueKey('${line.id}-unit'),
                initialValue: line.unit,
                enabled: enabled,
                onChanged: (value) => controller.updateLine(
                  line.id,
                  (current) => current.copyWith(unit: value),
                ),
              ),
            ),
            _MrTableCell(
              child: Text(
                showCommercial ? (line.unitCost ?? '—') : '—',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.inkSecondary,
                ),
              ),
            ),
            _MrTableCell(
              child: Text(
                showCommercial ? (line.totalCost ?? '—') : '—',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.inkSecondary,
                ),
              ),
            ),
            _MrTableCell(
              child: _MrDeleteButton(
                enabled: enabled,
                onPressed: () => controller.removeLine(line.id),
              ),
            ),
          ],
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Table(
              columnWidths: {
                0: const FixedColumnWidth(64),
                1: const FixedColumnWidth(270),
                2: const FixedColumnWidth(150),
                3: const FixedColumnWidth(180),
                4: const FixedColumnWidth(170),
                5: const FixedColumnWidth(90),
                6: const FixedColumnWidth(110),
                7: const FixedColumnWidth(110),
                8: const FixedColumnWidth(125),
                9: const FixedColumnWidth(58),
              },
              border: TableBorder(
                horizontalInside: BorderSide(color: AppColors.line),
                verticalInside: BorderSide(color: AppColors.line),
                top: BorderSide(color: AppColors.line),
                bottom: BorderSide(color: AppColors.line),
                left: BorderSide(color: AppColors.line),
                right: BorderSide(color: AppColors.line),
              ),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: rows,
            ),
          ),
        ),
      ),
    );
  }
}

class _MrTableCell extends StatelessWidget {
  const _MrTableCell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.sm,
    ),
    child: child,
  );
}

class _MrDeleteButton extends StatelessWidget {
  const _MrDeleteButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
    icon: const Icon(Icons.close_rounded, color: AppColors.error),
    style: IconButton.styleFrom(
      side: const BorderSide(color: AppColors.error),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      minimumSize: const Size(44, 44),
    ),
    onPressed: enabled ? onPressed : null,
  );
}

class _LineUnitDropdown extends StatelessWidget {
  const _LineUnitDropdown({
    required this.fieldKey,
    required this.initialValue,
    required this.enabled,
    required this.onChanged,
  });

  final Key fieldKey;
  final String initialValue;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = initialValue.trim();
    final options = <String>{
      if (value.isNotEmpty && !_mrUnitOptions.contains(value)) value,
      ..._mrUnitOptions,
    }.toList(growable: false);
    return DropdownButtonFormField<String>(
      key: fieldKey,
      initialValue: options.contains(value) && value.isNotEmpty ? value : 'Nos',
      isExpanded: true,
      style: AppTypography.bodySmall.copyWith(color: AppColors.ink),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: enabled
          ? (next) {
              if (next != null) onChanged(next);
            }
          : null,
    );
  }
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
            _MrDeleteButton(
              enabled: enabled,
              onPressed: () => controller.removeLine(line.id),
            ),
          ],
        ),
        _LineLabeledField(
          fieldKey: ValueKey('${line.id}-description'),
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
          fieldKey: ValueKey('${line.id}-brand-origin'),
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
        _LineLabeledField(
          fieldKey: ValueKey('${line.id}-size'),
          label: YorksV1MaterialRequestStrings.size.primary,
          initialValue: line.size ?? '',
          enabled: enabled,
          onChanged: (value) => controller.updateLine(
            line.id,
            (current) =>
                current.copyWith(size: value.trim().isEmpty ? null : value),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _LineLabeledField(
          fieldKey: ValueKey('${line.id}-planning-model-tag'),
          label: YorksV1MaterialRequestStrings.planningModelTag.primary,
          initialValue: line.model ?? line.planningModelTag ?? '',
          enabled: enabled,
          onChanged: (value) => controller.updateLine(
            line.id,
            (current) =>
                current.copyWith(model: value.trim().isEmpty ? null : value),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _LineLabeledField(
                fieldKey: ValueKey('${line.id}-quantity'),
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
              child: _LineLabeledUnitDropdown(
                fieldKey: ValueKey('${line.id}-unit'),
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

/// A local edit buffer for a dense material grid cell.  Calling the Riverpod
/// controller from [TextField.onChanged] used to replace the complete draft
/// line list for every character.  On desktop browsers that made long sheets
/// feel noticeably sluggish.  We instead commit validated user intent when
/// the cell loses focus or the user presses Enter.
class _LineTextField extends StatefulWidget {
  const _LineTextField({
    required this.fieldKey,
    required this.initialValue,
    required this.onChanged,
    required this.enabled,
    this.keyboardType,
    this.hintText,
  });

  final Key fieldKey;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? hintText;

  @override
  State<_LineTextField> createState() => _LineTextFieldState();
}

class _LineTextFieldState extends State<_LineTextField> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  late String _lastCommitted;

  @override
  void initState() {
    super.initState();
    _lastCommitted = widget.initialValue;
    _textController = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _focusNode.addListener(_commitOnBlur);
  }

  @override
  void didUpdateWidget(covariant _LineTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Preserve the in-progress browser input.  Server/local draft updates are
    // reflected only after the field is no longer active.
    if (!_focusNode.hasFocus && widget.initialValue != _textController.text) {
      _lastCommitted = widget.initialValue;
      _textController.value = TextEditingValue(
        text: widget.initialValue,
        selection: TextSelection.collapsed(offset: widget.initialValue.length),
      );
    }
  }

  void _commitOnBlur() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _commit() {
    final value = _textController.text;
    if (value == _lastCommitted) return;
    _lastCommitted = value;
    widget.onChanged(value);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_commitOnBlur)
      ..dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    key: widget.fieldKey,
    controller: _textController,
    focusNode: _focusNode,
    enabled: widget.enabled,
    keyboardType: widget.keyboardType,
    onFieldSubmitted: (_) => _commit(),
    decoration: const InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    ).copyWith(hintText: widget.hintText),
  );
}

class _LineLabeledUnitDropdown extends StatelessWidget {
  const _LineLabeledUnitDropdown({
    required this.fieldKey,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    required this.enabled,
  });

  final Key fieldKey;
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final value = initialValue.trim();
    final options = <String>{
      if (value.isNotEmpty && !_mrUnitOptions.contains(value)) value,
      ..._mrUnitOptions,
    }.toList(growable: false);
    return DropdownButtonFormField<String>(
      key: fieldKey,
      initialValue: options.contains(value) && value.isNotEmpty ? value : 'Nos',
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: enabled
          ? (next) {
              if (next != null) onChanged(next);
            }
          : null,
    );
  }
}

class _LineLabeledField extends StatefulWidget {
  const _LineLabeledField({
    required this.fieldKey,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    required this.enabled,
    this.keyboardType,
  });

  final Key fieldKey;
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final TextInputType? keyboardType;

  @override
  State<_LineLabeledField> createState() => _LineLabeledFieldState();
}

class _LineLabeledFieldState extends State<_LineLabeledField> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  late String _lastCommitted;

  @override
  void initState() {
    super.initState();
    _lastCommitted = widget.initialValue;
    _textController = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _focusNode.addListener(_commitOnBlur);
  }

  @override
  void didUpdateWidget(covariant _LineLabeledField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && widget.initialValue != _textController.text) {
      _lastCommitted = widget.initialValue;
      _textController.value = TextEditingValue(
        text: widget.initialValue,
        selection: TextSelection.collapsed(offset: widget.initialValue.length),
      );
    }
  }

  void _commitOnBlur() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _commit() {
    final value = _textController.text;
    if (value == _lastCommitted) return;
    _lastCommitted = value;
    widget.onChanged(value);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_commitOnBlur)
      ..dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    key: widget.fieldKey,
    controller: _textController,
    focusNode: _focusNode,
    enabled: widget.enabled,
    keyboardType: widget.keyboardType,
    onFieldSubmitted: (_) => _commit(),
    decoration: InputDecoration(labelText: widget.label),
  );
}

class _RequestsWorkflowBanner extends StatelessWidget {
  const _RequestsWorkflowBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    decoration: BoxDecoration(
      color: AppColors.blueContainer.withValues(alpha: 0.55),
      border: Border.all(color: AppColors.blueContainerStrong),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.blueContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: const Icon(
            Icons.description_outlined,
            color: AppColors.blue,
            size: 21,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                YorksV1MaterialRequestStrings.workflowTitle.primary,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                YorksV1MaterialRequestStrings.workflowDescription.primary,
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RequestsPanel extends StatelessWidget {
  const _RequestsPanel({
    required this.requests,
    required this.language,
    required this.canCreate,
    required this.onOpen,
  });

  final List<YorksV1MaterialRequest> requests;
  final AppLanguage language;
  final bool canCreate;
  final ValueChanged<YorksV1MaterialRequest> onOpen;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return _EmptyRequests(language: language, canCreate: canCreate);
    }
    return LedgerCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _RequestCard(
              request: requests[index],
              language: language,
              onOpen: () => onOpen(requests[index]),
            ),
          ),
        ),
      ),
    );
  }
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
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.blueContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: AppColors.blue,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${request.requestNumber ?? YorksV1MaterialRequestStrings.draft.primary} · ${request.title ?? request.projectName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${request.projectReference} · ${request.scopeName} · ${request.lines.length} ${YorksV1MaterialRequestStrings.items.primary.toLowerCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            _StateChip(request: request, language: language),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
}

class _RequestDetailBody extends ConsumerWidget {
  const _RequestDetailBody({
    required this.request,
    required this.language,
    required this.showPageHeader,
    required this.onRefresh,
  });

  final YorksV1MaterialRequest request;
  final AppLanguage language;
  final bool showPageHeader;
  final VoidCallback onRefresh;

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
    final AsyncValue<YorksV1ArrangementWorkspace?> arrangement =
        arrangementEnabled
        ? ref.watch(yorksV1ArrangementWorkspaceProvider(request.id))
        : const AsyncData(null);
    final documentModel = ref.watch(
      yorksV1MaterialRequestDocumentProvider(request.id),
    );
    final desktop =
        MediaQuery.sizeOf(context).width >= AppSpacing.yorksV1DesktopBreakpoint;
    final canArrange =
        role == YorksV1Role.procurement || role == YorksV1Role.admin;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                desktop ? AppSpacing.xxxl + AppSpacing.xs : AppSpacing.lg,
                AppSpacing.xxl,
                desktop ? AppSpacing.xxxl + AppSpacing.xs : AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.pageMaxWidth,
                ),
                child: _RequestRecordHeader(
                  request: request,
                  role: role,
                  onRefresh: onRefresh,
                  onOpenArrangement: canOpenArrangement && canArrange
                      ? () => _openArrangement(context, request.id)
                      : null,
                  canArrange: canArrange,
                  onExport: () async {
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
                  onPdf: documentModel.valueOrNull == null
                      ? null
                      : () => documentService.shareDocumentPdf(
                          documentModel.valueOrNull!,
                        ),
                  onPrint: documentModel.valueOrNull == null
                      ? null
                      : () => documentService.printDocumentPdf(
                          documentModel.valueOrNull!,
                        ),
                  onCancel: canCancel
                      ? () => _cancel(context, ref, request)
                      : null,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                desktop ? AppSpacing.xxxl + AppSpacing.xs : AppSpacing.lg,
                0,
                desktop ? AppSpacing.xxxl + AppSpacing.xs : AppSpacing.lg,
                72,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.pageMaxWidth,
                ),
                child: desktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _RequestRecordContent(
                              request: request,
                              language: language,
                              arrangement: arrangement,
                              documentModel: documentModel,
                              documentsEnabled: documentsEnabled,
                              canOpenLogistics: canOpenLogistics,
                              canOpenReturnsDocuments: canOpenReturnsDocuments,
                              onOpenLogistics: () => context.push(
                                RoutePaths.yorksV1MaterialRequestLogisticsPath(
                                  request.id,
                                ),
                              ),
                              onOpenReturns: () => context.push(
                                RoutePaths.yorksV1MaterialRequestReturnsDocumentsPath(
                                  request.id,
                                ),
                              ),
                              onOpenDocuments: () => context.push(
                                RoutePaths.yorksV1ProjectDocumentsPath(
                                  request.projectId,
                                  entityType: 'material_request',
                                  entityId: request.id,
                                ),
                              ),
                              onStoreDocument:
                                  documentsEnabled &&
                                      documentModel.valueOrNull != null
                                  ? () => _storePdfSnapshot(
                                      context,
                                      ref,
                                      request,
                                      documentService,
                                      documentModel.valueOrNull!,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          SizedBox(
                            width: AppSpacing.inspectorWidth,
                            child: _RequestDetailsRail(request: request),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _RequestDetailsRail(request: request),
                          const SizedBox(height: AppSpacing.lg),
                          _RequestRecordContent(
                            request: request,
                            language: language,
                            arrangement: arrangement,
                            documentModel: documentModel,
                            documentsEnabled: documentsEnabled,
                            canOpenLogistics: canOpenLogistics,
                            canOpenReturnsDocuments: canOpenReturnsDocuments,
                            onOpenLogistics: () => context.push(
                              RoutePaths.yorksV1MaterialRequestLogisticsPath(
                                request.id,
                              ),
                            ),
                            onOpenReturns: () => context.push(
                              RoutePaths.yorksV1MaterialRequestReturnsDocumentsPath(
                                request.id,
                              ),
                            ),
                            onOpenDocuments: () => context.push(
                              RoutePaths.yorksV1ProjectDocumentsPath(
                                request.projectId,
                                entityType: 'material_request',
                                entityId: request.id,
                              ),
                            ),
                            onStoreDocument:
                                documentsEnabled &&
                                    documentModel.valueOrNull != null
                                ? () => _storePdfSnapshot(
                                    context,
                                    ref,
                                    request,
                                    documentService,
                                    documentModel.valueOrNull!,
                                  )
                                : null,
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

  Future<void> _openArrangement(BuildContext context, String requestId) async {
    if (MediaQuery.sizeOf(context).width <
        AppSpacing.yorksV1DesktopBreakpoint) {
      context.push(RoutePaths.yorksV1MaterialRequestArrangementPath(requestId));
      return;
    }
    await showDialog<void>(
      context: context,
      animationStyle: AnimationStyle.noAnimation,
      barrierColor: AppColors.scrim.withValues(alpha: .42),
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.all(AppSpacing.xxxl),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          child: SizedBox(
            width: 1320,
            height: (size.height - AppSpacing.colossal * 2).clamp(520.0, 820.0),
            child: Stack(
              children: [
                YorksV1ArrangementScreen(requestId: requestId),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: IconButton(
                    tooltip: MaterialLocalizations.of(
                      dialogContext,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    YorksV1MaterialRequestDocumentModel documentModel,
  ) async {
    try {
      final bytes = await documentService.buildDocumentPdf(
        documentModel,
        PdfPageFormat.a4,
      );
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

/// The submitted-request canvas follows the final R35 prototype: record
/// context and actions are separated from the immutable controlled form, and
/// the role-safe detail rail remains visible while engineers work through the
/// request.  It deliberately reads the existing server projections instead of
/// manufacturing workflow state in the widget tree.
class _RequestRecordHeader extends StatelessWidget {
  const _RequestRecordHeader({
    required this.request,
    required this.role,
    required this.onRefresh,
    required this.onOpenArrangement,
    required this.canArrange,
    required this.onExport,
    required this.onPdf,
    required this.onPrint,
    required this.onCancel,
  });

  final YorksV1MaterialRequest request;
  final YorksV1Role? role;
  final VoidCallback onRefresh;
  final VoidCallback? onOpenArrangement;
  final bool canArrange;
  final VoidCallback onExport;
  final VoidCallback? onPdf;
  final VoidCallback? onPrint;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      final title =
          request.requestNumber ??
          YorksV1MaterialRequestStrings.materialRequest.primary;
      final requestTitle = request.title?.trim();
      final actionLabel =
          canArrange &&
              (request.state == YorksV1MaterialRequestState.submitted ||
                  request.state == YorksV1MaterialRequestState.arranging)
          ? YorksV1MaterialRequestStrings.arrangeItems.primary
          : YorksV1ArrangementStrings.arrangement.primary;
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.projectReference.toUpperCase(),
            style: AppTypography.eyebrow.copyWith(
              color: AppColors.blueContainerStrong,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            requestTitle == null || requestTitle.isEmpty
                ? title
                : '$title · $requestTitle',
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.65,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${request.scopeName} · ${request.requesterDisplayName ?? YorksV1MaterialRequestStrings.requester.primary}',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
          ),
        ],
      );
      final actions = Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        alignment: compact ? WrapAlignment.start : WrapAlignment.end,
        children: [
          if (onOpenArrangement != null)
            _RecordActionButton(
              label: actionLabel,
              icon: Icons.inventory_2_outlined,
              primary: canArrange,
              onPressed: onOpenArrangement!,
            ),
          _RecordActionButton(
            label: YorksV1MaterialRequestStrings.exportExcel.primary,
            icon: Icons.download_outlined,
            onPressed: onExport,
          ),
          if (onPdf != null)
            _RecordActionButton(
              label: YorksV1MaterialRequestStrings.pdf.primary,
              icon: Icons.picture_as_pdf_outlined,
              onPressed: onPdf!,
            ),
          if (onPrint != null)
            _RecordActionButton(
              label: YorksV1MaterialRequestStrings.print.primary,
              icon: Icons.print_outlined,
              onPressed: onPrint!,
            ),
          if (onCancel != null)
            _RecordActionButton(
              label: YorksV1MaterialRequestStrings.cancelRequest.primary,
              icon: Icons.close_rounded,
              destructive: true,
              onPressed: onCancel!,
            ),
          IconButton(
            tooltip: YorksV1MaterialRequestStrings.refresh.primary,
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      );
      return compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: AppSpacing.lg),
                actions,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: heading),
                const SizedBox(width: AppSpacing.lg),
                actions,
              ],
            );
    },
  );
}

class _RecordActionButton extends StatelessWidget {
  const _RecordActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;
  final bool destructive;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppSpacing.minTapTarget,
    child: primary
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 19),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: destructive
                ? OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.errorContainer),
                  )
                : null,
            icon: Icon(icon, size: 19),
            label: Text(label),
          ),
  );
}

class _RequestRecordContent extends StatelessWidget {
  const _RequestRecordContent({
    required this.request,
    required this.language,
    required this.arrangement,
    required this.documentModel,
    required this.documentsEnabled,
    required this.canOpenLogistics,
    required this.canOpenReturnsDocuments,
    required this.onOpenLogistics,
    required this.onOpenReturns,
    required this.onOpenDocuments,
    required this.onStoreDocument,
  });

  final YorksV1MaterialRequest request;
  final AppLanguage language;
  final AsyncValue<YorksV1ArrangementWorkspace?> arrangement;
  final AsyncValue<YorksV1MaterialRequestDocumentModel> documentModel;
  final bool documentsEnabled;
  final bool canOpenLogistics;
  final bool canOpenReturnsDocuments;
  final VoidCallback onOpenLogistics;
  final VoidCallback onOpenReturns;
  final VoidCallback onOpenDocuments;
  final VoidCallback? onStoreDocument;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _RequestWorkflowCard(request: request, language: language),
      const SizedBox(height: AppSpacing.xxl),
      _R35RecordSectionHeading(
        title: YorksV1MaterialRequestStrings.materialRequest.primary,
        description:
            YorksV1MaterialRequestStrings.controlledTableDescription.primary,
      ),
      const SizedBox(height: AppSpacing.sm),
      _ControlledRequestPreview(request: request, documentModel: documentModel),
      if (documentsEnabled) ...[
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _RecordActionButton(
              label: YorksV1DocumentStrings.documents.primary,
              icon: Icons.folder_open_outlined,
              onPressed: onOpenDocuments,
            ),
            if (onStoreDocument != null)
              _RecordActionButton(
                label: YorksV1DocumentStrings.storeControlledVersion.primary,
                icon: Icons.verified_outlined,
                onPressed: onStoreDocument!,
              ),
          ],
        ),
      ],
      const SizedBox(height: AppSpacing.xxl),
      _R35RecordSectionHeading(
        title: YorksV1ArrangementStrings.arrangement.primary,
        description:
            YorksV1MaterialRequestStrings.arrangementDescription.primary,
      ),
      const SizedBox(height: AppSpacing.sm),
      arrangement.when(
        loading: () => const _R35RecordSurface(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: LinearProgressIndicator(),
          ),
        ),
        error: (_, _) => _PendingWorkflowSurface(
          icon: Icons.inventory_2_outlined,
          title: YorksV1MaterialRequestStrings.arrangementUnavailable.primary,
          description: YorksV1MaterialRequestStrings
              .arrangementUnavailableDescription
              .primary,
        ),
        data: (workspace) =>
            _ArrangementSummarySurface(request: request, workspace: workspace),
      ),
      const SizedBox(height: AppSpacing.xxl),
      _R35RecordSectionHeading(
        title: YorksV1LogisticsStrings.dispatchAndReceipt.primary,
        description: YorksV1MaterialRequestStrings.dispatchDescription.primary,
      ),
      const SizedBox(height: AppSpacing.sm),
      _PendingWorkflowSurface(
        icon: Icons.local_shipping_outlined,
        title: _dispatchTitle(request),
        description: _dispatchDescription(request),
        action: canOpenLogistics
            ? _RecordActionButton(
                label: YorksV1LogisticsStrings.dispatchAndReceipt.primary,
                icon: Icons.local_shipping_outlined,
                onPressed: onOpenLogistics,
              )
            : null,
      ),
      const SizedBox(height: AppSpacing.xxl),
      _R35RecordSectionHeading(
        title: YorksV1LogisticsStrings.deliveryOrdersAndReturns.primary,
        description: YorksV1MaterialRequestStrings.returnsDescription.primary,
      ),
      const SizedBox(height: AppSpacing.sm),
      _PendingWorkflowSurface(
        icon: _receiptReviewed(request)
            ? Icons.receipt_long_outlined
            : Icons.assignment_return_outlined,
        title: _receiptReviewed(request)
            ? YorksV1LogisticsStrings.deliveryOrderTitle.primary
            : YorksV1MaterialRequestStrings.noReturnedMaterial.primary,
        description: _receiptReviewed(request)
            ? YorksV1MaterialRequestStrings.deliveryOrderAfterReceipt.primary
            : YorksV1MaterialRequestStrings.returnAfterReceipt.primary,
        action: canOpenReturnsDocuments
            ? _RecordActionButton(
                label: _receiptReviewed(request)
                    ? YorksV1LogisticsStrings.generateDeliveryOrder.primary
                    : YorksV1LogisticsStrings.deliveryOrdersAndReturns.primary,
                icon: _receiptReviewed(request)
                    ? Icons.receipt_long_outlined
                    : Icons.assignment_return_outlined,
                onPressed: onOpenReturns,
              )
            : null,
      ),
    ],
  );

  String _dispatchTitle(YorksV1MaterialRequest value) {
    final ready =
        value.state == YorksV1MaterialRequestState.approved ||
        value.state == YorksV1MaterialRequestState.partiallyDispatched;
    return ready
        ? YorksV1MaterialRequestStrings.readyForDispatch.primary
        : YorksV1MaterialRequestStrings.noDispatchYet.primary;
  }

  String _dispatchDescription(YorksV1MaterialRequest value) {
    final ready =
        value.state == YorksV1MaterialRequestState.approved ||
        value.state == YorksV1MaterialRequestState.partiallyDispatched;
    return ready
        ? YorksV1MaterialRequestStrings.dispatchReadyDescription.primary
        : YorksV1MaterialRequestStrings.dispatchPendingDescription.primary;
  }

  bool _receiptReviewed(YorksV1MaterialRequest value) =>
      value.state == YorksV1MaterialRequestState.partiallyReceived ||
      value.state == YorksV1MaterialRequestState.received ||
      value.state == YorksV1MaterialRequestState.closed;
}

class _R35RecordSectionHeading extends StatelessWidget {
  const _R35RecordSectionHeading({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: AppSpacing.xxs),
      Text(
        description,
        style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
      ),
    ],
  );
}

class _R35RecordSurface extends StatelessWidget {
  const _R35RecordSurface({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class _RequestWorkflowCard extends StatelessWidget {
  const _RequestWorkflowCard({required this.request, required this.language});

  final YorksV1MaterialRequest request;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final activeIndex = _activeIndex(request.state);
    return _R35RecordSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    YorksV1MaterialRequestStrings.requestStatus.primary,
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    YorksV1MaterialRequestStrings
                        .requestStatusDescription
                        .primary,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              );
              final state = _StateChip(request: request, language: language);
              if (constraints.maxWidth < 440) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    copy,
                    const SizedBox(height: AppSpacing.sm),
                    state,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: AppSpacing.sm),
                  state,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final labels = [
                YorksV1MaterialRequestStrings.request.primary,
                YorksV1MaterialRequestStrings.procurement.primary,
                YorksV1MaterialRequestStrings.projectEngineer.primary,
                YorksV1MaterialRequestStrings.dispatch.primary,
                YorksV1MaterialRequestStrings.received.primary,
              ];
              if (compact) {
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (var index = 0; index < labels.length; index++)
                      _WorkflowStep(
                        index: index,
                        label: labels[index],
                        activeIndex: activeIndex,
                        compact: true,
                      ),
                  ],
                );
              }
              return Row(
                children: [
                  for (var index = 0; index < labels.length; index++) ...[
                    Expanded(
                      child: _WorkflowStep(
                        index: index,
                        label: labels[index],
                        activeIndex: activeIndex,
                      ),
                    ),
                    if (index != labels.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.only(bottom: 24),
                          color: index < activeIndex
                              ? AppColors.success
                              : AppColors.lineStrong,
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              border: Border.all(color: AppColors.blueContainerStrong),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ownerHeading(request),
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${YorksV1MaterialRequestStrings.currentOwner.primary}: ${request.currentActionOwnerRole ?? YorksV1MaterialRequestStrings.procurement.primary}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _activeIndex(YorksV1MaterialRequestState state) => switch (state) {
    YorksV1MaterialRequestState.draft => 0,
    YorksV1MaterialRequestState.submitted ||
    YorksV1MaterialRequestState.arranging => 1,
    YorksV1MaterialRequestState.awaitingApproval => 2,
    YorksV1MaterialRequestState.approved ||
    YorksV1MaterialRequestState.partiallyDispatched ||
    YorksV1MaterialRequestState.dispatched => 3,
    YorksV1MaterialRequestState.partiallyReceived ||
    YorksV1MaterialRequestState.received ||
    YorksV1MaterialRequestState.closed => 4,
    YorksV1MaterialRequestState.cancelled => 0,
  };

  String _ownerHeading(YorksV1MaterialRequest value) => switch (value.state) {
    YorksV1MaterialRequestState.submitted ||
    YorksV1MaterialRequestState.arranging =>
      YorksV1MaterialRequestStrings.procurementArranging.primary,
    YorksV1MaterialRequestState.awaitingApproval =>
      YorksV1MaterialRequestStrings.waitingForApproval.primary,
    YorksV1MaterialRequestState.approved =>
      YorksV1MaterialRequestStrings.readyForDispatch.primary,
    YorksV1MaterialRequestState.partiallyDispatched ||
    YorksV1MaterialRequestState.dispatched =>
      YorksV1MaterialRequestStrings.awaitingReceipt.primary,
    YorksV1MaterialRequestState.partiallyReceived ||
    YorksV1MaterialRequestState.received ||
    YorksV1MaterialRequestState.closed =>
      YorksV1MaterialRequestStrings.receiptCompleted.primary,
    YorksV1MaterialRequestState.draft =>
      YorksV1MaterialRequestStrings.draftPrivate.primary,
    YorksV1MaterialRequestState.cancelled =>
      YorksV1MaterialRequestStrings.cancelled.primary,
  };
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({
    required this.index,
    required this.label,
    required this.activeIndex,
    this.compact = false,
  });

  final int index;
  final String label;
  final int activeIndex;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final complete = index < activeIndex;
    final active = index == activeIndex;
    final color = complete
        ? AppColors.success
        : active
        ? AppColors.blue
        : AppColors.lineStrong;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: complete
                ? AppColors.successContainer
                : AppColors.surfaceContainerLow,
            border: Border.all(color: color, width: active ? 2.2 : 1.5),
          ),
          child: Icon(
            complete ? Icons.check_rounded : Icons.looks_one_outlined,
            size: 19,
            color: color,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelSmall.copyWith(
            color: active || complete ? color : AppColors.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RequestDetailsRail extends StatelessWidget {
  const _RequestDetailsRail({required this.request});

  final YorksV1MaterialRequest request;

  @override
  Widget build(BuildContext context) => _R35RecordSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          YorksV1MaterialRequestStrings.requestDetails.primary,
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.md),
        _RequestRailFact(
          label: YorksV1MaterialRequestStrings.requestNumber.primary,
          value: request.requestNumber ?? '—',
        ),
        _RequestRailFact(
          label: YorksV1MaterialRequestStrings.project.primary,
          value: request.projectName,
        ),
        _RequestRailFact(
          label: YorksV1MaterialRequestStrings.projectReference.primary,
          value: request.projectReference,
        ),
        _RequestRailFact(
          label: YorksV1MaterialRequestStrings.requestedBy.primary,
          value: request.requesterDisplayName ?? '—',
        ),
        _RequestRailFact(
          label: YorksV1MaterialRequestStrings.requestingRole.primary,
          value: request.requesterProjectRole ?? '—',
        ),
        _RequestRailFact(
          label: YorksV1MaterialRequestStrings.scope.primary,
          value: request.scopeName,
        ),
        _RequestRailFact(
          label: YorksV1MaterialRequestStrings.requested.primary,
          value:
              '${request.lines.length} ${YorksV1MaterialRequestStrings.items.primary.toLowerCase()}',
        ),
        _RequestRailFact(
          label: YorksV1MaterialRequestStrings.currentOwner.primary,
          value: request.currentActionOwnerRole ?? '—',
        ),
        _RequestRailFact(
          label: YorksV1MaterialRequestStrings.lastUpdated.primary,
          value: MaterialLocalizations.of(
            context,
          ).formatMediumDate(request.updatedAt.toLocal()),
        ),
      ],
    ),
  );
}

class _RequestRailFact extends StatelessWidget {
  const _RequestRailFact({required this.label, required this.value});

  final String label;
  final String value;

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
        Text(
          label.toUpperCase(),
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w800,
            letterSpacing: .75,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: AppTypography.labelLarge.copyWith(color: AppColors.ink),
        ),
      ],
    ),
  );
}

class _ControlledRequestPreview extends StatelessWidget {
  const _ControlledRequestPreview({
    required this.request,
    required this.documentModel,
  });

  final YorksV1MaterialRequest request;
  final AsyncValue<YorksV1MaterialRequestDocumentModel> documentModel;

  @override
  Widget build(BuildContext context) => _R35RecordSurface(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: SizedBox(
      key: const ValueKey('yorks-v1-controlled-material-request-preview'),
      height:
          MediaQuery.sizeOf(context).width < AppSpacing.yorksV1DesktopBreakpoint
          ? 620
          : 900,
      child: documentModel.when(
        data: (model) => PdfPreview(
          build: (_) => YorksV1MaterialRequestDocumentService()
              .buildDocumentPdf(model, PdfPageFormat.a4),
          allowPrinting: false,
          allowSharing: false,
          canChangeOrientation: false,
          canChangePageFormat: false,
          initialPageFormat: PdfPageFormat.a4,
          useActions: false,
        ),
        loading: () => const _ControlledDocumentAvailability(loading: true),
        error: (_, _) => const _ControlledDocumentAvailability(),
      ),
    ),
  );
}

class _ControlledDocumentAvailability extends StatelessWidget {
  const _ControlledDocumentAvailability({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            loading ? Icons.description_outlined : Icons.sync_problem_rounded,
            color: loading ? AppColors.muted : AppColors.error,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            loading
                ? YorksV1MaterialRequestStrings
                      .controlledDocumentLoading
                      .primary
                : YorksV1MaterialRequestStrings
                      .controlledDocumentUnavailable
                      .primary,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _FormalCell extends StatelessWidget {
  const _FormalCell(
    this.value, {
    this.header = false,
    this.supporting,
    this.alignEnd = false,
  });

  final String value;
  final bool header;
  final String? supporting;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.sm),
    child: Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          value,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: (header ? AppTypography.labelSmall : AppTypography.bodySmall)
              .copyWith(fontWeight: header ? FontWeight.w800 : null),
        ),
        if (supporting != null && supporting!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            supporting!,
            style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    ),
  );
}

class _ArrangementSummarySurface extends StatelessWidget {
  const _ArrangementSummarySurface({
    required this.request,
    required this.workspace,
  });

  final YorksV1MaterialRequest request;
  final YorksV1ArrangementWorkspace? workspace;

  @override
  Widget build(BuildContext context) {
    final current = workspace?.currentArrangement;
    if (current == null) {
      return _PendingWorkflowSurface(
        icon: Icons.inventory_2_outlined,
        title: YorksV1MaterialRequestStrings.notArrangedYet.primary,
        description:
            YorksV1MaterialRequestStrings.arrangementPendingDescription.primary,
      );
    }
    return _R35RecordSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 650),
              child: Table(
                border: TableBorder.all(color: AppColors.line),
                columnWidths: const {
                  0: FlexColumnWidth(2.2),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1.5),
                  3: FixedColumnWidth(90),
                  4: FixedColumnWidth(94),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                    ),
                    children: [
                      _FormalCell(
                        YorksV1MaterialRequestStrings.item.primary,
                        header: true,
                      ),
                      _FormalCell(
                        YorksV1ArrangementStrings.decision.primary,
                        header: true,
                      ),
                      _FormalCell(
                        YorksV1ArrangementStrings.source.primary,
                        header: true,
                      ),
                      _FormalCell(
                        YorksV1ArrangementStrings.requested.primary,
                        header: true,
                      ),
                      _FormalCell(
                        YorksV1ArrangementStrings.arranged.primary,
                        header: true,
                      ),
                    ],
                  ),
                  for (final line in current.lines)
                    TableRow(
                      children: [
                        _FormalCell(
                          line.description,
                          supporting: line.brandOrigin,
                        ),
                        _FormalCell(
                          line.decision == null
                              ? '—'
                              : yorksV1ArrangementDecisionCopy(
                                  line.decision!,
                                ).primary,
                        ),
                        _FormalCell(
                          line.source == YorksV1ArrangementSource.warehouse
                              ? YorksV1MaterialRequestStrings.warehouse.primary
                              : line.externalSupplier ??
                                    YorksV1MaterialRequestStrings
                                        .externalSupplier
                                        .primary,
                        ),
                        _FormalCell(
                          '${line.requestedQuantity} ${line.unit}',
                          alignEnd: true,
                        ),
                        _FormalCell(
                          '${line.arrangedQuantity ?? '0'} ${line.unit}',
                          alignEnd: true,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.blueContainer.withValues(alpha: .58),
              border: Border.all(color: AppColors.blueContainerStrong),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Text(
              '${current.lines.length} ${YorksV1MaterialRequestStrings.items.primary.toLowerCase()} · ${current.savedByDisplayName ?? current.startedByDisplayName}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingWorkflowSurface extends StatelessWidget {
  const _PendingWorkflowSurface({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => _R35RecordSurface(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxxl,
        horizontal: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.blueContainerStrong),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    ),
  );
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
  Widget build(BuildContext context) => YorksV1ActiveText(
    copy: copy,
    language: language,
    style: style ?? AppTypography.bodyMedium,
    textAlign: center ? TextAlign.center : null,
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
    final selected = await showModalBottomSheet<_BoqSourceSelection>(
      context: context,
      sheetAnimationStyle: AnimationStyle.noAnimation,
      showDragHandle: true,
      builder: (context) => ListView(
        children: [
          for (final group in groups.where((group) => group.rowCount > 0)) ...[
            ListTile(
              title: Text(group.effectiveTitle),
              subtitle: Text('${group.rowCount}'),
              leading: const Icon(Icons.folder_outlined),
              onTap: () => Navigator.of(
                context,
              ).pop(_BoqSourceSelection(group: group, wholeFolder: false)),
            ),
            ListTile(
              title: Text(
                '${YorksV1MaterialRequestStrings.useEntireBoqFolder.primary} · ${group.effectiveTitle}',
              ),
              subtitle: Text(
                YorksV1BoqStrings.createRequestFromFolderDescription.primary,
              ),
              leading: const Icon(Icons.playlist_add_check_outlined),
              onTap: () => Navigator.of(
                context,
              ).pop(_BoqSourceSelection(group: group, wholeFolder: true)),
            ),
          ],
        ],
      ),
    );
    if (selected == null) return;
    final worksheet = await ref
        .read(yorksV1BoqRepositoryProvider)
        .getWorksheet(selected.group.id);
    if (!context.mounted) return;
    final selectedRowIds = selected.wholeFolder
        ? worksheet.rows.map((row) => row.id).toSet()
        : await _pickRows(context, worksheet);
    if (selectedRowIds == null || selectedRowIds.isEmpty) return;
    await controller.addBoqRows(worksheet: worksheet, rowIds: selectedRowIds);
  } catch (_) {
    if (context.mounted) {
      _snack(context, YorksV1MaterialRequestStrings.saveFailed.primary);
    }
  }
}

class _BoqSourceSelection {
  const _BoqSourceSelection({required this.group, required this.wholeFolder});

  final YorksV1BoqGroup group;
  final bool wholeFolder;
}

Future<Set<String>?> _pickRows(
  BuildContext context,
  YorksV1BoqWorksheet worksheet,
) async {
  final selected = <String>{};
  return showDialog<Set<String>>(
    context: context,
    animationStyle: AnimationStyle.noAnimation,
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
                    _boqDisplayValue(
                      worksheet,
                      row,
                      YorksV1BoqCanonicalField.description,
                    ),
                  ),
                  subtitle: Text(
                    '${_boqDisplayValue(worksheet, row, YorksV1BoqCanonicalField.quantity)} '
                    '${_boqDisplayValue(worksheet, row, YorksV1BoqCanonicalField.unit)}',
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

String _boqDisplayValue(
  YorksV1BoqWorksheet worksheet,
  YorksV1BoqRow row,
  YorksV1BoqCanonicalField field,
) {
  final canonical = row.canonicalValues[field.wireValue];
  if (canonical != null && '$canonical'.trim().isNotEmpty) {
    return '$canonical'.trim();
  }
  final column = worksheet.columns
      .where((item) => item.canonicalField == field)
      .firstOrNull;
  final value = column == null ? null : row.valueFor(column.id);
  return value?.toString().trim() ?? '';
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
    if (!context.mounted) return;
    final sheet = await _chooseWorkbookSheet(context, workbook);
    if (sheet == null) return;
    if (!context.mounted) return;
    final preview = codec.preview(
      workbook: workbook,
      sheet: sheet,
      fallbackTitle: selected.fileName,
    );
    final fields = <YorksV1BoqCanonicalField, int>{};
    for (final column in preview.columns) {
      final canonical = column.canonicalField;
      if (canonical != null) {
        fields.putIfAbsent(canonical, () => column.sourceIndex);
      }
    }
    final description =
        fields[YorksV1BoqCanonicalField.description] ??
        _mrFallbackDescriptionIndex(preview);
    final quantity = fields[YorksV1BoqCanonicalField.quantity];
    final unit = fields[YorksV1BoqCanonicalField.unit];
    if (description == null) {
      throw StateError('required columns');
    }
    final brand = fields[YorksV1BoqCanonicalField.brandOrigin];
    final model = fields[YorksV1BoqCanonicalField.model];
    final equipmentTag = fields[YorksV1BoqCanonicalField.equipmentTag];
    final planningModelTag = fields[YorksV1BoqCanonicalField.planningModelTag];
    final size =
        fields[YorksV1BoqCanonicalField.size] ??
        preview.columns
            .where(
              (column) => RegExp(
                r'(^|\b)(size|dimension|dimensions)(\b|$)',
                caseSensitive: false,
              ).hasMatch(column.heading.trim()),
            )
            .map((column) => column.sourceIndex)
            .firstOrNull;
    final unitCost = _mrHeaderIndex(
      preview,
      RegExp(r'unit\s*cost|cost\s*per\s*unit', caseSensitive: false),
    );
    final totalCost = _mrHeaderIndex(
      preview,
      RegExp(r'total\s*cost|amount', caseSensitive: false),
    );
    final addRows = await _previewMaterialRequestImport(
      context,
      preview: preview,
      descriptionIndex: description,
      brandIndex: brand,
      quantityIndex: quantity,
      unitIndex: unit,
      unitCostIndex: unitCost,
      totalCostIndex: totalCost,
    );
    if (!addRows || !context.mounted) return;
    // Import is an editing operation, not a submit operation. Preserve rows
    // that are incomplete (for example a draft export with an empty Qty) so
    // the engineer can correct them in the same spreadsheet editor instead
    // of silently losing the row during round-trip.
    final lines = [
      for (var index = 0; index < preview.rows.length; index++)
        (() {
          final technical = _splitExportedDescription(
            preview.rows[index].valueFor(description),
          );
          final tag = equipmentTag == null
              ? ''
              : preview.rows[index].valueFor(equipmentTag).trim();
          final explicitQuantity = quantity == null
              ? ''
              : preview.rows[index].valueFor(quantity);
          final rawModel = model == null
              ? ''
              : preview.rows[index].valueFor(model).trim();
          final contextualDescription = technical.$1.trim();
          return YorksV1MaterialRequestLine(
            id: const Uuid().v4(),
            displayOrder: index + 1,
            source: YorksV1MaterialRequestLineSource.excel,
            description: contextualDescription.isEmpty
                ? (tag.isEmpty ? 'Imported equipment' : tag)
                : _composeImportedMrDescription(tag, contextualDescription),
            brandOrigin: brand == null
                ? _mrFallbackBrandValue(preview, preview.rows[index])
                : preview.rows[index].valueFor(brand),
            size: size == null
                ? technical.$2
                : preview.rows[index].valueFor(size),
            model: rawModel.isNotEmpty
                ? rawModel
                : (tag.isNotEmpty
                      ? tag
                      : (_mrFallbackModelValue(preview, preview.rows[index]) ??
                            technical.$3)),
            equipmentTag: tag.isEmpty ? null : tag,
            planningModelTag: planningModelTag == null
                ? null
                : preview.rows[index].valueFor(planningModelTag),
            quantity: _mrInferredQuantity(
              rawQuantity: explicitQuantity,
              description: contextualDescription,
              model: rawModel.isNotEmpty ? rawModel : tag,
            ),
            quantityIsSuggested:
                explicitQuantity.trim().isEmpty && tag.isNotEmpty,
            unit: _mrInferredUnit(
              rawUnit: unit == null ? '' : preview.rows[index].valueFor(unit),
              description: technical.$1,
            ),
          );
        })(),
    ];
    await controller.addExcelLines(lines);
  } catch (_) {
    if (context.mounted) {
      _snack(context, YorksV1MaterialRequestStrings.importFailed.primary);
    }
  }
}

String _composeImportedMrDescription(String tag, String context) {
  if (tag.isEmpty || context.toLowerCase() == tag.toLowerCase()) return context;
  return '$tag — $context';
}

int? _mrFallbackDescriptionIndex(YorksV1BoqImportPreview preview) {
  final preferred = RegExp(
    r'description|item|equipment|serving\s*area|location|interlock\s*with|unit\s*ref',
    caseSensitive: false,
  );
  for (final column in preview.columns) {
    if (!preferred.hasMatch(column.heading)) continue;
    if (preview.rows.any(
      (row) => row.valueFor(column.sourceIndex).isNotEmpty,
    )) {
      return column.sourceIndex;
    }
  }
  for (final column in preview.columns) {
    if (column.canonicalField == YorksV1BoqCanonicalField.planningModelTag ||
        RegExp(
          r'tag|model|serial|qty|unit|make|brand',
          caseSensitive: false,
        ).hasMatch(column.heading)) {
      continue;
    }
    if (preview.rows.any(
      (row) => row.valueFor(column.sourceIndex).isNotEmpty,
    )) {
      return column.sourceIndex;
    }
  }
  return null;
}

String? _mrFallbackModelValue(
  YorksV1BoqImportPreview preview,
  YorksV1BoqImportRow row,
) {
  final pattern = RegExp(
    r'(^|\b)(tag|tag\s*no|equipment\s*tag|model|serial|reference|ref|s\s*no)(\b|#)',
    caseSensitive: false,
  );
  for (final column in preview.columns) {
    if (!pattern.hasMatch(column.heading)) continue;
    final value = row.valueFor(column.sourceIndex).trim();
    if (value.isNotEmpty) return value;
  }
  return null;
}

String? _mrFallbackBrandValue(
  YorksV1BoqImportPreview preview,
  YorksV1BoqImportRow row,
) {
  final pattern = RegExp(r'brand|make|manufacturer', caseSensitive: false);
  for (final column in preview.columns) {
    if (!pattern.hasMatch(column.heading)) continue;
    final value = row.valueFor(column.sourceIndex).trim();
    if (value.isNotEmpty) return value;
  }
  return null;
}

String _mrInferredQuantity({
  required String rawQuantity,
  required String description,
  required String? model,
}) {
  final value = rawQuantity.trim();
  if (value.isNotEmpty) return value;
  // Equipment schedules commonly encode grouped quantities in the item
  // description (for example "Supply Air Register - 4 Nos"). Preserve that
  // quantity instead of importing every grouped row as one.
  final embedded = RegExp(
    r'(\d+(?:\.\d+)?)\s*(?:nos?|each|pcs?|pieces?|sets?|pairs?)\b',
    caseSensitive: false,
  ).firstMatch(description);
  if (embedded != null) return embedded.group(1)!;
  // A tagged equipment row is an individually requestable item.  A blank
  // quantity is therefore safely initialised to one and remains editable.
  return model?.trim().isNotEmpty == true ? '1' : '';
}

String _mrInferredUnit({required String rawUnit, required String description}) {
  final value = rawUnit.trim();
  if (value.isNotEmpty) return _mrNormaliseUnit(value);
  final embedded = RegExp(
    r'\b(nos?|each|pcs?|pieces?|meter|metre|cm|length|sets?|pairs?|rolls?|boxes?|kg|lit(?:re|er)s?|packs?|lots?)\b',
    caseSensitive: false,
  ).firstMatch(description);
  return embedded == null ? 'Nos' : _mrNormaliseUnit(embedded.group(1)!);
}

String _mrNormaliseUnit(String value) {
  switch (value.trim().toLowerCase()) {
    case 'no':
    case 'nos':
    case 'number':
    case 'numbers':
    case 'pc':
    case 'pcs':
    case 'piece':
    case 'pieces':
      return 'Nos';
    case 'each':
      return 'Each';
    case 'm':
    case 'meter':
    case 'metre':
    case 'meters':
    case 'metres':
      return 'Meter';
    case 'cm':
      return 'Cm';
    case 'length':
      return 'Length';
    case 'set':
    case 'sets':
      return 'Set';
    case 'pair':
    case 'pairs':
      return 'Pairs';
    case 'roll':
    case 'rolls':
      return 'Roll';
    case 'box':
    case 'boxes':
      return 'Box';
    case 'kg':
      return 'Kg';
    case 'litre':
    case 'litres':
    case 'liter':
    case 'liters':
      return 'Litre';
    case 'pack':
    case 'packs':
      return 'Pack';
    case 'lot':
    case 'lots':
      return 'Lot';
    default:
      return value;
  }
}

Future<bool> _previewMaterialRequestImport(
  BuildContext context, {
  required YorksV1BoqImportPreview preview,
  required int descriptionIndex,
  required int? brandIndex,
  required int? quantityIndex,
  required int? unitIndex,
  required int? unitCostIndex,
  required int? totalCostIndex,
}) async {
  final visibleRows = preview.rows.take(25).toList(growable: false);
  final mismatchedTotals = _mrTotalMismatchCount(
    preview.rows,
    quantityIndex,
    unitCostIndex,
    totalCostIndex,
  );
  final headings = [
    YorksV1MaterialRequestStrings.rowNumber.primary,
    YorksV1MaterialRequestStrings.itemDescription.primary,
    YorksV1MaterialRequestStrings.brandOrigin.primary,
    YorksV1MaterialRequestStrings.quantity.primary,
    YorksV1MaterialRequestStrings.unit.primary,
    YorksV1MaterialRequestStrings.unitCost.primary,
    YorksV1MaterialRequestStrings.totalCost.primary,
  ];
  return await showDialog<bool>(
        context: context,
        animationStyle: AnimationStyle.noAnimation,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 680),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          YorksV1MaterialRequestStrings.previewImport.primary,
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    '${preview.worksheetName} · ${preview.rows.length} ${YorksV1MaterialRequestStrings.rows.primary}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  if (mismatchedTotals > 0) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 17,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            YorksV1MaterialRequestStrings
                                .importCostMismatch
                                .primary,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStatePropertyAll(
                              AppColors.surfaceContainerLow,
                            ),
                            columns: [
                              for (final heading in headings)
                                DataColumn(
                                  label: Text(
                                    heading.toUpperCase(),
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                            rows: [
                              for (
                                var rowIndex = 0;
                                rowIndex < visibleRows.length;
                                rowIndex++
                              )
                                DataRow(
                                  cells: [
                                    DataCell(Text('${rowIndex + 1}')),
                                    DataCell(
                                      SizedBox(
                                        width: 360,
                                        child: Text(
                                          visibleRows[rowIndex].valueFor(
                                            descriptionIndex,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        brandIndex == null
                                            ? ''
                                            : visibleRows[rowIndex].valueFor(
                                                brandIndex,
                                              ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        quantityIndex == null
                                            ? '1'
                                            : visibleRows[rowIndex].valueFor(
                                                quantityIndex,
                                              ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        unitIndex == null
                                            ? 'Nos'
                                            : visibleRows[rowIndex].valueFor(
                                                unitIndex,
                                              ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        unitCostIndex == null
                                            ? ''
                                            : visibleRows[rowIndex].valueFor(
                                                unitCostIndex,
                                              ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        totalCostIndex == null
                                            ? ''
                                            : visibleRows[rowIndex].valueFor(
                                                totalCostIndex,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (preview.rows.length > visibleRows.length) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      YorksV1MaterialRequestStrings.importPreviewLimit.primary,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          YorksV1MaterialRequestStrings.cancelImport.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(
                          YorksV1MaterialRequestStrings.addImportedRows.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ) ??
      false;
}

int? _mrHeaderIndex(YorksV1BoqImportPreview preview, RegExp pattern) => preview
    .columns
    .where((column) => pattern.hasMatch(column.heading.trim()))
    .map((column) => column.sourceIndex)
    .firstOrNull;

int _mrTotalMismatchCount(
  List<YorksV1BoqImportRow> rows,
  int? quantityIndex,
  int? unitCostIndex,
  int? totalCostIndex,
) {
  if (quantityIndex == null ||
      unitCostIndex == null ||
      totalCostIndex == null) {
    return 0;
  }
  var count = 0;
  for (final row in rows) {
    final qty = double.tryParse(row.valueFor(quantityIndex));
    final unitCost = double.tryParse(row.valueFor(unitCostIndex));
    final total = double.tryParse(row.valueFor(totalCostIndex));
    if (qty == null || unitCost == null || total == null) continue;
    if ((qty * unitCost - total).abs() > 0.01) count++;
  }
  return count;
}

/// Material Request workbooks keep BOQ-only technical context in the
/// description cell. Parse that stable, human-readable suffix on re-import so
/// an exported MR can be edited and round-tripped without losing the context.
(String, String?, String?) _splitExportedDescription(String raw) {
  final lines = raw.split(RegExp(r'\r?\n'));
  if (lines.length == 1) return (raw.trim(), null, null);
  String? size;
  String? model;
  final description = <String>[];
  for (final line in lines) {
    final value = line.trim();
    if (value.toLowerCase().startsWith('size:')) {
      size = value.substring(5).trim();
    } else if (value.toLowerCase().startsWith('model / tag:')) {
      model = value.substring('model / tag:'.length).trim();
    } else if (value.isNotEmpty) {
      description.add(value);
    }
  }
  return (description.join('\n').trim(), size, model);
}

Future<YorksV1BoqWorkbookSheet?> _chooseWorkbookSheet(
  BuildContext context,
  YorksV1BoqParsedWorkbook workbook,
) => showDialog<YorksV1BoqWorkbookSheet>(
  context: context,
  animationStyle: AnimationStyle.noAnimation,
  builder: (context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.68;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 720, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          YorksV1MaterialRequestStrings
                              .chooseEquipmentSchedule
                              .primary,
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${workbook.fileName} contains ${workbook.sheets.length} worksheets. ${YorksV1MaterialRequestStrings.worksheetImportDescription.primary}',
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
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xl),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisExtent: 78,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                  ),
                  itemCount: workbook.sheets.length,
                  itemBuilder: (context, index) {
                    final sheet = workbook.sheets[index];
                    final populated = sheet.nonEmptyRowIndexes.length;
                    return OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(sheet),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.table_chart_outlined, size: 19),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sheet.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelLarge.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '$populated ${YorksV1BoqStrings.rows.primary}',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 19),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: AppSpacing.xl),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(YorksV1MaterialRequestStrings.cancel.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);

Future<void> _exportDraft(
  BuildContext context,
  YorksV1BoqWorkbookFileService fileService,
  YorksV1MaterialRequestDocumentService documentService,
  YorksV1MaterialRequestDraft draft,
) async {
  try {
    final saved = await fileService.saveWorkbook(
      bytes: documentService.buildDraftExcel(draft),
      suggestedName: documentService.suggestedDraftExcelName(draft),
    );
    if (saved && context.mounted) {
      _snack(context, YorksV1MaterialRequestStrings.saved.primary);
    }
  } catch (_) {
    if (context.mounted) {
      _snack(context, YorksV1MaterialRequestStrings.saveFailed.primary);
    }
  }
}

Future<String?> _cancelReason(BuildContext context) async {
  final text = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    animationStyle: AnimationStyle.noAnimation,
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
