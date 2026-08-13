import 'dart:async';
import 'dart:convert';

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
import '../../../../shared/models/yorks_v1_document_strings.dart';
import '../../../../shared/models/yorks_v1_logistics.dart';
import '../../../../shared/models/yorks_v1_logistics_strings.dart';
import '../../../../shared/models/yorks_v1_material_request.dart';
import '../../../../shared/models/yorks_v1_material_request_document.dart';
import '../../../../shared/models/yorks_v1_material_request_strings.dart';
import '../../../../shared/models/yorks_v1_project.dart';
import '../../../../shared/models/yorks_v1_project_strings.dart';
import '../../../../shared/models/yorks_v1_quantity.dart';
import '../../../../shared/models/yorks_v1_role.dart';
import '../../../../shared/models/yorks_v1_shell_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_boq_repository_provider.dart';
import '../../../../shared/providers/yorks_v1_boq_workbook_provider.dart';
import '../../../../shared/providers/yorks_v1_feature_flags_provider.dart';
import '../../../../shared/providers/yorks_v1_identity_provider.dart';
import '../../../../shared/providers/yorks_v1_logistics_provider.dart';
import '../../../../shared/providers/yorks_v1_material_request_provider.dart';
import '../../../../shared/providers/yorks_v1_material_workflow_command_provider.dart';
import '../../../../shared/providers/yorks_v1_arrangement_provider.dart';
import '../../../../shared/services/yorks_v1_material_request_document_service.dart';
import '../../../../shared/services/yorks_v1_boq_workbook_service.dart';
import '../../../../shared/services/yorks_v1_logistics_document_service.dart';
import '../../../../shared/providers/session_provider.dart';

import 'yorks_v1_arrangement_screen.dart';
import 'yorks_v1_logistics_screen.dart';
import 'yorks_v1_returns_documents_screen.dart';

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
  'Ton',
  'Boxes',
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
    // The phone register is intentionally a separate composition.  It keeps
    // the same provider, routing and authorization preflight as the R35
    // register below, while preserving the accepted tablet/web tree intact.
    if (YorksMobileUi.isActive(context)) {
      return _YorksMobileMaterialRequestsPage(projectId: projectId);
    }
    final language = ref.watch(languageProvider);
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final requests = ref.watch(yorksV1MaterialRequestListProvider(projectId));
    final canCreate = role?.canCreateMaterialRequest ?? false;
    final ownerAuthUserId = ref.watch(yorksV1AuthUserIdProvider);
    final localDrafts = ownerAuthUserId == null || ownerAuthUserId.isEmpty
        ? const <YorksV1MaterialRequestDraft>[]
        : ref
              .watch(yorksV1MaterialRequestLocalDraftsProvider(ownerAuthUserId))
              .where(
                (draft) => projectId == null || draft.projectId == projectId,
              )
              .toList(growable: false);
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
              if (canCreate && localDrafts.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _RecoverableMaterialDraftNotice(
                  drafts: localDrafts,
                  onResume: (draft) => context.push(
                    RoutePaths.yorksV1MaterialRequestDraftPath(
                      draft.id,
                      projectId: draft.projectId,
                    ),
                  ),
                ),
              ],
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

enum _MobileMaterialRequestFilter { all, draft, submitted, approved }

/// Phone-only, status-led register for the authorized MR projection.
///
/// Counts, owner labels and state chips are deliberately derived from the
/// records returned by [yorksV1MaterialRequestListProvider].  In particular,
/// a transport failure is not rendered as an empty register or a zero count.
class _YorksMobileMaterialRequestsPage extends ConsumerStatefulWidget {
  const _YorksMobileMaterialRequestsPage({this.projectId});

  final String? projectId;

  @override
  ConsumerState<_YorksMobileMaterialRequestsPage> createState() =>
      _YorksMobileMaterialRequestsPageState();
}

class _YorksMobileMaterialRequestsPageState
    extends ConsumerState<_YorksMobileMaterialRequestsPage> {
  _MobileMaterialRequestFilter _filter = _MobileMaterialRequestFilter.all;

  Future<void> _refreshRequests() async {
    final provider = yorksV1MaterialRequestListProvider(widget.projectId);
    ref.invalidate(provider);
    try {
      await ref.read(provider.future);
    } catch (_) {
      // The register's AsyncValue renders the existing retry experience.
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final canCreate = role?.canCreateMaterialRequest ?? false;
    final ownerAuthUserId = ref.watch(yorksV1AuthUserIdProvider);
    final localDrafts = ownerAuthUserId == null || ownerAuthUserId.isEmpty
        ? const <YorksV1MaterialRequestDraft>[]
        : ref
              .watch(yorksV1MaterialRequestLocalDraftsProvider(ownerAuthUserId))
              .where(
                (draft) =>
                    widget.projectId == null ||
                    draft.projectId == widget.projectId,
              )
              .toList(growable: false);
    final requests = ref.watch(
      yorksV1MaterialRequestListProvider(widget.projectId),
    );
    return Scaffold(
      backgroundColor: AppColors.mobileSurface,
      body: ColoredBox(
        color: AppColors.mobileSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            YorksMobileAppBar(
              title: YorksV1MaterialRequestStrings.requests.primary,
              leading: YorksMobileIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(RoutePaths.engineerHome),
              ),
              trailing: YorksMobileIconButton(
                icon: Icons.refresh_rounded,
                tooltip: YorksV1MaterialRequestStrings.refresh.primary,
                onPressed: () => unawaited(_refreshRequests()),
              ),
            ),
            Expanded(
              child: requests.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _MobileMaterialRequestError(
                  language: language,
                  onRetry: () => ref.invalidate(
                    yorksV1MaterialRequestListProvider(widget.projectId),
                  ),
                ),
                data: (items) => _MobileMaterialRequestRegister(
                  items: items,
                  canCreate: canCreate,
                  localDrafts: localDrafts,
                  filter: _filter,
                  onFilterChanged: (value) => setState(() => _filter = value),
                  onCreate: canCreate
                      ? () => context.push(
                          RoutePaths.yorksV1MaterialRequestDraftPath(
                            const Uuid().v4(),
                            projectId: widget.projectId,
                          ),
                        )
                      : null,
                  onOpen: (request) =>
                      context.push(_materialRequestOpenPath(request)),
                  onResume: (draft) => context.push(
                    RoutePaths.yorksV1MaterialRequestDraftPath(
                      draft.id,
                      projectId: draft.projectId,
                    ),
                  ),
                  onRefresh: _refreshRequests,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileMaterialRequestRegister extends StatelessWidget {
  const _MobileMaterialRequestRegister({
    required this.items,
    required this.canCreate,
    required this.localDrafts,
    required this.filter,
    required this.onFilterChanged,
    required this.onCreate,
    required this.onOpen,
    required this.onResume,
    required this.onRefresh,
  });

  final List<YorksV1MaterialRequest> items;
  final bool canCreate;
  final List<YorksV1MaterialRequestDraft> localDrafts;
  final _MobileMaterialRequestFilter filter;
  final ValueChanged<_MobileMaterialRequestFilter> onFilterChanged;
  final VoidCallback? onCreate;
  final ValueChanged<YorksV1MaterialRequest> onOpen;
  final ValueChanged<YorksV1MaterialRequestDraft> onResume;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final visible = items.where(_matches).toList(growable: false);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const ValueKey('mobile-material-request-register'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 104),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      YorksV1MaterialRequestStrings.requests.primary,
                      style: AppTypography.headlineMedium.copyWith(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      YorksV1MaterialRequestStrings.requestsDescription.primary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (canCreate)
                Semantics(
                  button: true,
                  label: YorksV1MaterialRequestStrings.newRequest.primary,
                  child: SizedBox.square(
                    dimension: AppSpacing.minTapTarget,
                    child: FilledButton(
                      onPressed: onCreate,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.add_rounded),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (canCreate && localDrafts.isNotEmpty) ...[
            _RecoverableMaterialDraftNotice(
              drafts: localDrafts,
              onResume: onResume,
              compact: true,
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            height: AppSpacing.minTapTarget,
            child: SingleChildScrollView(
              key: const ValueKey('mobile-material-request-filter-rail'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 14),
              child: Row(
                children: [
                  _MobileMaterialRequestFilterTab(
                    label: YorksV1MaterialRequestStrings.all.primary,
                    selected: filter == _MobileMaterialRequestFilter.all,
                    onTap: () =>
                        onFilterChanged(_MobileMaterialRequestFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _MobileMaterialRequestFilterTab(
                    label: YorksV1MaterialRequestStrings.draft.primary,
                    selected: filter == _MobileMaterialRequestFilter.draft,
                    onTap: () =>
                        onFilterChanged(_MobileMaterialRequestFilter.draft),
                  ),
                  const SizedBox(width: 8),
                  _MobileMaterialRequestFilterTab(
                    label: YorksV1MaterialRequestStrings.submitted.primary,
                    selected: filter == _MobileMaterialRequestFilter.submitted,
                    onTap: () =>
                        onFilterChanged(_MobileMaterialRequestFilter.submitted),
                  ),
                  const SizedBox(width: 8),
                  _MobileMaterialRequestFilterTab(
                    label: YorksV1MaterialRequestStrings.approved.primary,
                    selected: filter == _MobileMaterialRequestFilter.approved,
                    onTap: () =>
                        onFilterChanged(_MobileMaterialRequestFilter.approved),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            _MobileMaterialRequestEmpty(
              canCreate: canCreate,
              onCreate: onCreate,
            )
          else if (visible.isEmpty)
            _MobileMaterialRequestNoMatches()
          else
            for (final request in visible) ...[
              _MobileMaterialRequestCard(
                request: request,
                onTap: () => onOpen(request),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  bool _matches(YorksV1MaterialRequest request) => switch (filter) {
    _MobileMaterialRequestFilter.all => true,
    _MobileMaterialRequestFilter.draft => request.state.isDraft,
    _MobileMaterialRequestFilter.submitted =>
      request.state == YorksV1MaterialRequestState.submitted ||
          request.state == YorksV1MaterialRequestState.arranging ||
          request.state == YorksV1MaterialRequestState.awaitingApproval,
    _MobileMaterialRequestFilter.approved =>
      request.state == YorksV1MaterialRequestState.approved ||
          request.state == YorksV1MaterialRequestState.partiallyDispatched ||
          request.state == YorksV1MaterialRequestState.dispatched ||
          request.state == YorksV1MaterialRequestState.partiallyReceived ||
          request.state == YorksV1MaterialRequestState.received ||
          request.state == YorksV1MaterialRequestState.closed,
  };
}

/// The server request queue intentionally excludes incomplete records.  This
/// explicit owner/device-local recovery notice makes those drafts discoverable
/// without presenting them as Procurement-visible workflow records.
class _RecoverableMaterialDraftNotice extends StatelessWidget {
  const _RecoverableMaterialDraftNotice({
    required this.drafts,
    required this.onResume,
    this.compact = false,
  });

  final List<YorksV1MaterialRequestDraft> drafts;
  final ValueChanged<YorksV1MaterialRequestDraft> onResume;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final latest = drafts.first;
    final title = latest.title?.trim();
    final summary = title == null || title.isEmpty
        ? YorksV1MaterialRequestStrings.materialRequestDraft.primary
        : title;
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: compact ? 36 : 42,
          height: compact ? 36 : 42,
          decoration: BoxDecoration(
            color: AppColors.blueContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: const Icon(Icons.restore_rounded, color: AppColors.blue),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                YorksV1MaterialRequestStrings.localDraftCount(
                  drafts.length,
                ).primary,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 2),
                Text(
                  YorksV1MaterialRequestStrings.localDraftPrivate.primary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        OutlinedButton(
          onPressed: () => onResume(latest),
          child: Text(YorksV1MaterialRequestStrings.resumeSavedDraft.primary),
        ),
      ],
    );
    return LedgerCard(
      color: AppColors.surfaceContainerLow,
      padding: EdgeInsets.all(compact ? 12 : AppSpacing.md),
      child: body,
    );
  }
}

/// A single, scrollable rail keeps every request state reachable on narrow
/// phones instead of detaching a filter into a second row.
class _MobileMaterialRequestFilterTab extends StatelessWidget {
  const _MobileMaterialRequestFilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: YorksMobilePill(label: label, selected: selected, onTap: onTap),
  );
}

class _MobileMaterialRequestCard extends StatelessWidget {
  const _MobileMaterialRequestCard({
    required this.request,
    required this.onTap,
  });

  final YorksV1MaterialRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => YorksMobileCard(
    onTap: onTap,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                request.requestNumber ??
                    YorksV1MaterialRequestStrings.draft.primary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _MobileRequestStateChip(request: request),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          request.title?.trim().isNotEmpty == true
              ? request.title!
              : request.projectName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '${request.projectReference} · ${request.scopeName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 17,
                color: AppColors.blue,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${request.lines.length} ${YorksV1MaterialRequestStrings.items.primary.toLowerCase()}',
                  style: AppTypography.labelMedium,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MobileRequestStateChip extends StatelessWidget {
  const _MobileRequestStateChip({required this.request});

  final YorksV1MaterialRequest request;

  @override
  Widget build(BuildContext context) {
    final done =
        request.state == YorksV1MaterialRequestState.received ||
        request.state == YorksV1MaterialRequestState.closed;
    final cancelled = request.state == YorksV1MaterialRequestState.cancelled;
    final background = cancelled
        ? AppColors.errorContainer
        : done
        ? AppColors.successContainer
        : AppColors.blueContainer;
    final foreground = cancelled
        ? AppColors.onErrorContainer
        : done
        ? AppColors.onSuccessContainer
        : AppColors.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        yorksV1MaterialRequestStateCopy(request.state).primary,
        style: AppTypography.labelSmall.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MobileMaterialRequestEmpty extends StatelessWidget {
  const _MobileMaterialRequestEmpty({required this.canCreate, this.onCreate});

  final bool canCreate;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => YorksMobileCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 38, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(
            YorksV1MaterialRequestStrings.noRequests.primary,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
          ),
          if (canCreate) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: Text(YorksV1MaterialRequestStrings.newRequest.primary),
            ),
          ],
        ],
      ),
    ),
  );
}

class _MobileMaterialRequestNoMatches extends StatelessWidget {
  @override
  Widget build(BuildContext context) => YorksMobileCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Text(
        YorksV1MaterialRequestStrings.noRequests.primary,
        textAlign: TextAlign.center,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
      ),
    ),
  );
}

class _MobileMaterialRequestError extends StatelessWidget {
  const _MobileMaterialRequestError({
    required this.language,
    required this.onRetry,
  });

  final AppLanguage language;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: YorksMobileCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sync_problem_rounded,
              size: 38,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            _CopyText(
              copy: YorksV1MaterialRequestStrings.saveFailed,
              language: language,
              center: true,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(YorksV1MaterialRequestStrings.refresh.primary),
            ),
          ],
        ),
      ),
    ),
  );
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
        YorksV1MaterialRequestState.partiallyReceived ||
        YorksV1MaterialRequestState.received ||
        YorksV1MaterialRequestState.closed => true,
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
      if (request.state.isDraft || request.canEditBeforeApproval) {
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
      final worksheet = await ref
          .read(yorksV1BoqRepositoryProvider)
          .getWorksheet(groupId);
      final worksheetProjectId = worksheet.group.projectId.trim();
      if (projectId != null &&
          projectId.isNotEmpty &&
          worksheetProjectId != projectId) {
        throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
      }
      final selectedProjectId = projectId?.isNotEmpty == true
          ? projectId!
          : worksheetProjectId;
      if (!await controller.setProject(selectedProjectId)) {
        throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
      }
      final worksheetScopeId = worksheet.group.scopeId?.trim();
      if (worksheetScopeId == null ||
          worksheetScopeId.isEmpty ||
          !await controller.setScope(worksheetScopeId)) {
        throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
      }
      await controller.addBoqRows(
        worksheet: worksheet,
        rowIds: worksheet.rows.map((row) => row.id),
      );
    } catch (_) {
      if (!mounted) return;
      YorksAppToast.show(
        context,
        title: YorksV1MaterialRequestStrings.saveFailed.primary,
        tone: YorksAppToastTone.error,
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

/// The single prominent action in a Material Request record follows the
/// server-owned R35 workflow.  This only governs presentation; each command
/// still checks role, membership, version and quantities in its RPC.
///
/// Keeping this resolver small and explicit prevents an old Arrange action
/// from leaking into the approved/dispatch stage simply because the viewer is
/// a Procurement user.
enum YorksV1MaterialRequestDetailPrimaryAction {
  arrange,
  dispatch,
  receiptReview,
  close,
  generateDeliveryOrder,
}

/// Presentation preflight for the server-authorized close command. An exact
/// Site Engineer still needs an active membership in the request project;
/// that authoritative check is performed by the trusted RPC.
@visibleForTesting
bool yorksV1CanOfferMaterialRequestClose({
  required YorksV1MaterialRequestState state,
  required YorksV1Role? role,
}) {
  return state == YorksV1MaterialRequestState.received &&
      ((role?.isEngineering ?? false) || role == YorksV1Role.admin);
}

@visibleForTesting
YorksV1MaterialRequestDetailPrimaryAction?
yorksV1MaterialRequestDetailPrimaryAction({
  required YorksV1MaterialRequestState state,
  required YorksV1Role? role,
  required bool canArrange,
  required bool canDispatch,
  required bool canConfirmReceipt,
  required bool canGenerateDeliveryOrder,
  bool canClose = false,
}) {
  final isProcurement =
      role == YorksV1Role.procurement || role == YorksV1Role.admin;
  final isReceivingEngineer =
      (role?.isEngineering ?? false) || role == YorksV1Role.admin;

  if (isProcurement &&
      canArrange &&
      (state == YorksV1MaterialRequestState.approvedForArrangement ||
          state == YorksV1MaterialRequestState.arranging)) {
    return YorksV1MaterialRequestDetailPrimaryAction.arrange;
  }
  if (isProcurement &&
      canDispatch &&
      (state == YorksV1MaterialRequestState.approved ||
          state == YorksV1MaterialRequestState.partiallyDispatched ||
          state == YorksV1MaterialRequestState.partiallyReceived)) {
    return YorksV1MaterialRequestDetailPrimaryAction.dispatch;
  }
  if (isReceivingEngineer &&
      canConfirmReceipt &&
      (state == YorksV1MaterialRequestState.partiallyDispatched ||
          state == YorksV1MaterialRequestState.dispatched ||
          state == YorksV1MaterialRequestState.partiallyReceived)) {
    return YorksV1MaterialRequestDetailPrimaryAction.receiptReview;
  }
  if (canClose && state == YorksV1MaterialRequestState.received) {
    return YorksV1MaterialRequestDetailPrimaryAction.close;
  }
  if (canGenerateDeliveryOrder &&
      (state == YorksV1MaterialRequestState.partiallyDispatched ||
          state == YorksV1MaterialRequestState.dispatched ||
          state == YorksV1MaterialRequestState.partiallyReceived ||
          state == YorksV1MaterialRequestState.received ||
          state == YorksV1MaterialRequestState.closed)) {
    return YorksV1MaterialRequestDetailPrimaryAction.generateDeliveryOrder;
  }
  return null;
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
      appBar: compactRoute && !YorksMobileUi.isActive(context)
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
    final selectedScope = scopes.valueOrNull
        ?.where((item) => item.id == draft.scopeId)
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
    final serverBackedRequest = draft.serverRecordVersion > 0
        ? ref.watch(yorksV1MaterialRequestDetailProvider(draft.id))
        : null;
    final compactRoute =
        MediaQuery.sizeOf(context).width < AppSpacing.yorksV1DesktopBreakpoint;

    if (YorksMobileUi.isActive(context)) {
      return _MaterialRequestDraftExitGuard(
        state: state,
        controller: controller,
        language: language,
        child: _YorksMobileMaterialRequestDraftFlow(
          state: state,
          controller: controller,
          projects: projects,
          scopes: scopes,
          onSave: () => _save(context, ref, controller, draft),
          onSubmit: () => _submitForMobile(context, ref, controller),
        ),
      );
    }

    return _MaterialRequestDraftExitGuard(
      state: state,
      controller: controller,
      language: language,
      child: Scaffold(
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
                sectionNumber: 1,
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
                sectionNumber: 2,
                title: YorksV1MaterialRequestStrings.materialItems.primary,
                description: YorksV1MaterialRequestStrings
                    .materialItemsDescription
                    .primary,
                actions: [
                  _R35MaterialActionBar(
                    canEdit: !isBusy,
                    canUseBoq:
                        !isBusy &&
                        draft.projectId != null &&
                        draft.scopeId != null,
                    excelEnabled: excelEnabled,
                    onAddCustom: controller.addCustomLine,
                    onAddBlank: controller.addBlankLine,
                    onAddBoq: () => _addBoqRows(
                      context,
                      ref,
                      controller,
                      draft,
                      language: language,
                      projectReference: selectedProject?.reference,
                      scopeName: selectedScope?.name,
                    ),
                    onImport: () => _importExcel(context, ref, controller),
                    onExport: () => _exportDraft(
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
                  projectId: draft.projectId,
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
                          onSave: save,
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
                              width: 360,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _R35RequestReview(
                                    draft: draft,
                                    projects: projects,
                                    scopes: scopes,
                                    requesterName: ref.watch(actorNameProvider),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  if (serverBackedRequest != null)
                                    serverBackedRequest.when(
                                      loading: () =>
                                          const _DraftDiscussionLoading(),
                                      error: (_, _) => _DraftDiscussionPrompt(
                                        canSave: canSubmit,
                                        onSave: save,
                                      ),
                                      data: (request) =>
                                          _MaterialRequestDiscussion(
                                            request: request,
                                            compact: true,
                                          ),
                                    )
                                  else
                                    _DraftDiscussionPrompt(
                                      canSave: canSubmit,
                                      onSave: save,
                                    ),
                                ],
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
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (serverBackedRequest != null)
                          serverBackedRequest.when(
                            loading: () => const _DraftDiscussionLoading(),
                            error: (_, _) => _DraftDiscussionPrompt(
                              canSave: canSubmit,
                              onSave: save,
                            ),
                            data: (request) => _MaterialRequestDiscussion(
                              request: request,
                              compact: true,
                            ),
                          )
                        else
                          _DraftDiscussionPrompt(
                            canSave: canSubmit,
                            onSave: save,
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
    final submitted = await _submitForMobile(context, ref, controller);
    if (!context.mounted || submitted == null) return;
    context.go(RoutePaths.yorksV1MaterialRequestPath(submitted.id));
  }

  Future<YorksV1MaterialRequest?> _submitForMobile(
    BuildContext context,
    WidgetRef ref,
    YorksV1MaterialRequestDraftController controller,
  ) async {
    // See _save: Submit must validate the value the engineer can still see in
    // the active local editor instead of a stale draft snapshot.
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    final submitted = await controller.submit();
    if (!context.mounted) return null;
    if (submitted == null) {
      final message = controller.lastErrorCode == YorksV1DomainErrorCode.offline
          ? YorksV1MaterialRequestStrings.offlineSubmit.primary
          : YorksV1MaterialRequestStrings.submitFailed.primary;
      _snack(context, message);
      return null;
    }
    ref.invalidate(yorksV1MaterialRequestListProvider);
    return submitted;
  }
}

enum _MaterialRequestDraftExitChoice { save, discard }

String _materialRequestDraftContentFingerprint(
  YorksV1MaterialRequestDraft draft,
) {
  final content = Map<String, dynamic>.from(draft.toJson())
    ..remove('submissionIdempotencyKey')
    ..remove('serverRecordVersion')
    ..remove('updatedAt');
  return jsonEncode(content);
}

/// Guards route-level Back without interfering with the phone composer's
/// internal Back steps. A restored draft becomes the visit baseline; only
/// edits made after that point prompt the user.
class _MaterialRequestDraftExitGuard extends ConsumerStatefulWidget {
  const _MaterialRequestDraftExitGuard({
    required this.state,
    required this.controller,
    required this.language,
    required this.child,
  });

  final YorksV1MaterialRequestDraftState state;
  final YorksV1MaterialRequestDraftController controller;
  final AppLanguage language;
  final Widget child;

  @override
  ConsumerState<_MaterialRequestDraftExitGuard> createState() =>
      _MaterialRequestDraftExitGuardState();
}

class _MaterialRequestDraftExitGuardState
    extends ConsumerState<_MaterialRequestDraftExitGuard> {
  late YorksV1MaterialRequestDraft _baseline;
  late String _baselineFingerprint;
  bool _allowPop = false;
  bool _decisionOpen = false;

  @override
  void initState() {
    super.initState();
    _setBaseline(widget.controller.acceptedDraft);
  }

  @override
  void didUpdateWidget(covariant _MaterialRequestDraftExitGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.draft.id != widget.state.draft.id) {
      _allowPop = false;
      _setBaseline(widget.state.draft);
      return;
    }
    final accepted = widget.controller.acceptedDraft;
    final acceptedFingerprint = _materialRequestDraftContentFingerprint(
      accepted,
    );
    if (acceptedFingerprint != _baselineFingerprint &&
        acceptedFingerprint ==
            _materialRequestDraftContentFingerprint(widget.state.draft)) {
      _setBaseline(accepted);
    }
  }

  void _setBaseline(YorksV1MaterialRequestDraft draft) {
    _baseline = draft;
    _baselineFingerprint = _materialRequestDraftContentFingerprint(draft);
  }

  bool get _hasUnsavedChanges =>
      widget.state.status != YorksV1MaterialRequestDraftSyncStatus.submitted &&
      _materialRequestDraftContentFingerprint(widget.state.draft) !=
          _baselineFingerprint;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || !_hasUnsavedChanges,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop || _allowPop || _decisionOpen) return;
      await _requestExit();
    },
    child: widget.child,
  );

  Future<void> _requestExit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    if (!_hasUnsavedChanges) {
      _leave();
      return;
    }
    _decisionOpen = true;
    final choice = await showDialog<_MaterialRequestDraftExitChoice>(
      context: context,
      barrierDismissible: false,
      animationStyle: AnimationStyle.noAnimation,
      builder: (dialogContext) => _MaterialRequestDraftExitDialog(
        language: widget.language,
        onSave: _saveBeforeLeaving,
        onDiscard: _discardBeforeLeaving,
      ),
    );
    _decisionOpen = false;
    if (!mounted || choice == null) return;
    _leave();
  }

  Future<bool> _saveBeforeLeaving() async {
    final canSaveOnServer = widget.controller.currentDraft.canSubmitLocally;
    try {
      final saved = await widget.controller.saveDraft();
      if (canSaveOnServer && saved == null) return false;
      ref.invalidate(yorksV1MaterialRequestListProvider);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _discardBeforeLeaving() async {
    try {
      if (_baseline.hasRecoverableContent ||
          _baseline.serverRecordVersion > 0) {
        await widget.controller.restoreLocalSnapshot(_baseline);
      } else {
        await widget.controller.discardLocal();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void _leave() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }
}

class _MaterialRequestDraftExitDialog extends StatefulWidget {
  const _MaterialRequestDraftExitDialog({
    required this.language,
    required this.onSave,
    required this.onDiscard,
  });

  final AppLanguage language;
  final Future<bool> Function() onSave;
  final Future<bool> Function() onDiscard;

  @override
  State<_MaterialRequestDraftExitDialog> createState() =>
      _MaterialRequestDraftExitDialogState();
}

class _MaterialRequestDraftExitDialogState
    extends State<_MaterialRequestDraftExitDialog> {
  bool _busy = false;
  TranslatableString? _error;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;
    return PopScope(
      canPop: !_busy,
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: AppColors.blueContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox.square(
                        dimension: 48,
                        child: Icon(
                          Icons.edit_note_rounded,
                          color: AppColors.blue,
                          size: 27,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          YorksV1ActiveText(
                            copy: YorksV1MaterialRequestStrings.leaveDraftTitle,
                            language: widget.language,
                            style: AppTypography.headlineSmall.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          YorksV1ActiveText(
                            copy: YorksV1MaterialRequestStrings.leaveDraftBody,
                            language: widget.language,
                            style: AppTypography.bodyMedium.copyWith(
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
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(AppSpacing.minTapTarget),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 20,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: YorksV1ActiveText(
                              copy: YorksV1MaterialRequestStrings
                                  .draftRecoveryAssurance,
                              language: widget.language,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        key: const ValueKey('mr-draft-exit-error'),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        child: YorksV1ActiveText(
                          copy: _error!,
                          language: widget.language,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _actions(context, vertical: true),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: _actions(context),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, {bool vertical = false}) {
    final gap = vertical
        ? const SizedBox(height: AppSpacing.sm)
        : const SizedBox(width: AppSpacing.sm);
    return [
      TextButton(
        key: const ValueKey('mr-draft-keep-editing'),
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: Text(AppStrings.keepEditing.active(widget.language)),
      ),
      gap,
      OutlinedButton(
        key: const ValueKey('mr-draft-discard-and-leave'),
        onPressed: _busy ? null : _discard,
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
        child: Text(
          YorksV1MaterialRequestStrings.discardChangesAndLeave.active(
            widget.language,
          ),
        ),
      ),
      gap,
      FilledButton.icon(
        key: const ValueKey('mr-draft-save-and-leave'),
        onPressed: _busy ? null : _save,
        icon: _busy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(
          YorksV1MaterialRequestStrings.saveDraftAndLeave.active(
            widget.language,
          ),
        ),
      ),
    ];
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await widget.onSave();
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, _MaterialRequestDraftExitChoice.save);
      return;
    }
    setState(() {
      _busy = false;
      _error = YorksV1MaterialRequestStrings.draftExitSaveFailed;
    });
  }

  Future<void> _discard() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final discarded = await widget.onDiscard();
    if (!mounted) return;
    if (discarded) {
      Navigator.pop(context, _MaterialRequestDraftExitChoice.discard);
      return;
    }
    setState(() {
      _busy = false;
      _error = YorksV1MaterialRequestStrings.draftExitDiscardFailed;
    });
  }
}

enum _MobileMaterialRequestDraftStep { information, materials, review }

enum _MobileMaterialRequestSourcePage { none, boqFolders, boqRows, custom }

/// The phone request composer is a presentation-only state machine layered on
/// the existing draft controller. It never owns a second draft or command:
/// all edits flow through [YorksV1MaterialRequestDraftController], and the
/// success panel appears only after its connected submit returns a request.
class _YorksMobileMaterialRequestDraftFlow extends ConsumerStatefulWidget {
  const _YorksMobileMaterialRequestDraftFlow({
    required this.state,
    required this.controller,
    required this.projects,
    required this.scopes,
    required this.onSave,
    required this.onSubmit,
  });

  final YorksV1MaterialRequestDraftState state;
  final YorksV1MaterialRequestDraftController controller;
  final AsyncValue<List<YorksV1MaterialRequestProjectOption>> projects;
  final AsyncValue<List<YorksV1MaterialRequestScopeOption>> scopes;
  final Future<void> Function() onSave;
  final Future<YorksV1MaterialRequest?> Function() onSubmit;

  @override
  ConsumerState<_YorksMobileMaterialRequestDraftFlow> createState() =>
      _YorksMobileMaterialRequestDraftFlowState();
}

class _YorksMobileMaterialRequestDraftFlowState
    extends ConsumerState<_YorksMobileMaterialRequestDraftFlow> {
  _MobileMaterialRequestDraftStep _step =
      _MobileMaterialRequestDraftStep.information;
  _MobileMaterialRequestSourcePage _sourcePage =
      _MobileMaterialRequestSourcePage.none;
  List<YorksV1BoqGroup>? _groups;
  YorksV1BoqWorksheet? _worksheet;
  final Set<String> _selectedBoqRows = <String>{};
  bool _loadingSource = false;
  bool _reviewConfirmed = false;
  YorksV1MaterialRequest? _submitted;
  late final TextEditingController _customDescription;
  late final TextEditingController _customBrand;
  late final TextEditingController _customSize;
  late final TextEditingController _customModel;
  late final TextEditingController _customQuantity;
  String _customUnit = 'Nos';

  @override
  void initState() {
    super.initState();
    _customDescription = TextEditingController();
    _customBrand = TextEditingController();
    _customSize = TextEditingController();
    _customModel = TextEditingController();
    _customQuantity = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _customDescription.dispose();
    _customBrand.dispose();
    _customSize.dispose();
    _customModel.dispose();
    _customQuantity.dispose();
    super.dispose();
  }

  YorksV1MaterialRequestDraft get _draft => widget.state.draft;

  bool get _busy =>
      widget.state.status == YorksV1MaterialRequestDraftSyncStatus.saving ||
      widget.state.status == YorksV1MaterialRequestDraftSyncStatus.submitting;

  @override
  Widget build(BuildContext context) {
    if (_submitted != null) {
      return Scaffold(
        backgroundColor: AppColors.mobileSurface,
        body: _successPage(context, _submitted!),
      );
    }
    final sourceTitle = switch (_sourcePage) {
      _MobileMaterialRequestSourcePage.none => null,
      _MobileMaterialRequestSourcePage.boqFolders =>
        YorksV1MaterialRequestStrings.addFromBoq.primary,
      _MobileMaterialRequestSourcePage.boqRows =>
        YorksV1MaterialRequestStrings.selectedItems.primary,
      _MobileMaterialRequestSourcePage.custom =>
        YorksV1MaterialRequestStrings.unplannedMaterial.primary,
    };
    return Scaffold(
      backgroundColor: AppColors.mobileSurface,
      body: ColoredBox(
        color: AppColors.mobileSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            YorksMobileAppBar(
              title: sourceTitle ?? _stepTitle,
              leading: YorksMobileIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: _back,
              ),
            ),
            Expanded(
              child: switch (_sourcePage) {
                _MobileMaterialRequestSourcePage.none => _draftStepBody(),
                _MobileMaterialRequestSourcePage.boqFolders =>
                  _boqFoldersBody(),
                _MobileMaterialRequestSourcePage.boqRows => _boqRowsBody(),
                _MobileMaterialRequestSourcePage.custom =>
                  _customMaterialBody(),
              },
            ),
          ],
        ),
      ),
    );
  }

  String get _stepTitle => switch (_step) {
    _MobileMaterialRequestDraftStep.information =>
      YorksV1MaterialRequestStrings.requestInformation.primary,
    _MobileMaterialRequestDraftStep.materials =>
      YorksV1MaterialRequestStrings.materialItems.primary,
    _MobileMaterialRequestDraftStep.review =>
      YorksV1MaterialRequestStrings.review.primary,
  };

  Widget _draftStepBody() => switch (_step) {
    _MobileMaterialRequestDraftStep.information => _informationBody(),
    _MobileMaterialRequestDraftStep.materials => _materialsBody(),
    _MobileMaterialRequestDraftStep.review => _reviewBody(),
  };

  Widget _informationBody() => Column(
    children: [
      Expanded(
        child: ListView(
          key: const ValueKey('mobile-mr-information'),
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
          children: [
            _MobileMrProgress(step: _step),
            const SizedBox(height: 20),
            Text(
              YorksV1MaterialRequestStrings.requestInformation.primary,
              style: AppTypography.headlineMedium.copyWith(
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              YorksV1MaterialRequestStrings
                  .requestInformationDescription
                  .primary,
              style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            YorksMobileCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const ValueKey('mobile-mr-title'),
                    initialValue: _draft.title ?? '',
                    onChanged: widget.controller.setTitle,
                    decoration: InputDecoration(
                      labelText:
                          YorksV1MaterialRequestStrings.requestTitle.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _mobileProjectField(),
                  const SizedBox(height: 12),
                  _mobileScopeField(),
                  const SizedBox(height: 18),
                  Text(
                    YorksV1MaterialRequestStrings.requestTiming.primary,
                    style: AppTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final timing in YorksV1MaterialRequestTiming.values)
                        YorksMobilePill(
                          label: yorksV1MaterialRequestTimingCopy(
                            timing,
                          ).primary,
                          selected: _draft.timing == timing,
                          onTap: _busy
                              ? () {}
                              : () => widget.controller.setTiming(timing),
                        ),
                    ],
                  ),
                  if (_draft.timing ==
                      YorksV1MaterialRequestTiming.scheduled) ...[
                    const SizedBox(height: 12),
                    _mobileScheduledDate(),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('mobile-mr-delivery-note'),
                    initialValue: _draft.deliveryNote ?? '',
                    minLines: 2,
                    maxLines: 3,
                    onChanged: widget.controller.setDeliveryNote,
                    decoration: InputDecoration(
                      labelText:
                          YorksV1MaterialRequestStrings.deliveryNote.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _MobileMrNotice(
              icon: Icons.lock_outline_rounded,
              text: YorksV1MaterialRequestStrings.draftPrivate.primary,
            ),
          ],
        ),
      ),
      _MobileMrStickyActions(
        primaryLabel: YorksV1MaterialRequestStrings.continueAction.primary,
        primaryIcon: Icons.arrow_forward_rounded,
        onPrimary: _busy ? null : _continueToMaterials,
      ),
    ],
  );

  Widget _mobileProjectField() => widget.projects.when(
    loading: () => const LinearProgressIndicator(),
    error: (_, _) => _MobileMrNotice(
      icon: Icons.sync_problem_rounded,
      text: YorksV1MaterialRequestStrings.saveFailed.primary,
      error: true,
    ),
    data: (items) => DropdownButtonFormField<String>(
      key: const ValueKey('mobile-mr-project'),
      initialValue: items.any((item) => item.id == _draft.projectId)
          ? _draft.projectId
          : null,
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
      onChanged: _busy ? null : _changeProject,
    ),
  );

  Widget _mobileScopeField() => widget.scopes.when(
    loading: () => const LinearProgressIndicator(),
    error: (_, _) => _MobileMrNotice(
      icon: Icons.sync_problem_rounded,
      text: YorksV1MaterialRequestStrings.saveFailed.primary,
      error: true,
    ),
    data: (items) => DropdownButtonFormField<String>(
      key: const ValueKey('mobile-mr-scope'),
      initialValue: items.any((item) => item.id == _draft.scopeId)
          ? _draft.scopeId
          : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: YorksV1MaterialRequestStrings.scope.primary,
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(value: item.id, child: Text(item.name)),
      ],
      onChanged: _busy ? null : _changeScope,
    ),
  );

  Widget _mobileScheduledDate() => OutlinedButton.icon(
    icon: const Icon(Icons.calendar_today_outlined, size: 18),
    label: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        _draft.scheduledDate == null
            ? YorksV1MaterialRequestStrings.scheduledDate.primary
            : MaterialLocalizations.of(
                context,
              ).formatMediumDate(_draft.scheduledDate!),
      ),
    ),
    onPressed: _busy ? null : _pickScheduledDate,
  );

  Widget _materialsBody() => Column(
    children: [
      Expanded(
        child: ListView(
          key: const ValueKey('mobile-mr-materials'),
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
          children: [
            _MobileMrProgress(step: _step),
            const SizedBox(height: 20),
            Text(
              YorksV1MaterialRequestStrings.materialItems.primary,
              style: AppTypography.headlineMedium.copyWith(
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              YorksV1MaterialRequestStrings.materialItemsDescription.primary,
              style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            _MobileMrSourceAction(
              icon: Icons.folder_outlined,
              title: YorksV1MaterialRequestStrings.addFromBoq.primary,
              description:
                  YorksV1MaterialRequestStrings.selectScopeToAddBoq.primary,
              onTap: _busy ? null : _openBoqFolders,
            ),
            const SizedBox(height: 10),
            _MobileMrSourceAction(
              icon: Icons.add_box_outlined,
              title: YorksV1MaterialRequestStrings.addCustomItem.primary,
              description:
                  YorksV1MaterialRequestStrings.requestScopeDescription.primary,
              onTap: _busy
                  ? null
                  : () => setState(() {
                      _sourcePage = _MobileMaterialRequestSourcePage.custom;
                    }),
            ),
            const SizedBox(height: 16),
            YorksMobileSectionHeader(
              title: YorksV1MaterialRequestStrings.selectedItems.primary,
              subtitle:
                  '${_draft.lines.length} ${YorksV1MaterialRequestStrings.items.primary.toLowerCase()}',
            ),
            const SizedBox(height: 10),
            if (_draft.lines.isEmpty)
              _MobileMaterialRequestEmpty(canCreate: false)
            else ...[
              if (_draft.lines.any((line) => line.quantityIsSuggested))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MobileMrNotice(
                    icon: Icons.info_outline_rounded,
                    text: YorksV1MaterialRequestStrings
                        .suggestedQuantityReview
                        .primary,
                  ),
                ),
              for (final line in _draft.lines) ...[
                _MobileMrDraftLineCard(
                  line: line,
                  enabled: !_busy,
                  onRemove: () => widget.controller.removeLine(line.id),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
      _MobileMrStickyActions(
        secondaryLabel: YorksV1MaterialRequestStrings.back.primary,
        onSecondary: () =>
            setState(() => _step = _MobileMaterialRequestDraftStep.information),
        primaryLabel: YorksV1MaterialRequestStrings.review.primary,
        primaryIcon: Icons.arrow_forward_rounded,
        onPrimary: _busy || _draft.lines.isEmpty
            ? null
            : () => setState(
                () => _step = _MobileMaterialRequestDraftStep.review,
              ),
      ),
    ],
  );

  Widget _reviewBody() {
    final project = widget.projects.valueOrNull
        ?.where((item) => item.id == _draft.projectId)
        .firstOrNull;
    final scope = widget.scopes.valueOrNull
        ?.where((item) => item.id == _draft.scopeId)
        .firstOrNull;
    final active = project?.state == YorksV1ProjectLifecycle.active.wireValue;
    final canSubmit =
        _draft.canSubmitLocally && active && _reviewConfirmed && !_busy;
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('mobile-mr-review'),
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
            children: [
              _MobileMrProgress(step: _step),
              const SizedBox(height: 20),
              Text(
                YorksV1MaterialRequestStrings.reviewAndSubmit.primary,
                style: AppTypography.headlineMedium.copyWith(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                YorksV1MaterialRequestStrings.reviewDescription.primary,
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              YorksMobileCard(
                child: Column(
                  children: [
                    _MobileMrFact(
                      label: YorksV1MaterialRequestStrings.project.primary,
                      value: project == null
                          ? YorksV1MaterialRequestStrings.notProvided.primary
                          : '${project.reference} · ${project.name}',
                    ),
                    _MobileMrFact(
                      label: YorksV1MaterialRequestStrings.scopeLabel.primary,
                      value:
                          scope?.name ??
                          YorksV1MaterialRequestStrings.notProvided.primary,
                    ),
                    _MobileMrFact(
                      label: YorksV1MaterialRequestStrings.delivery.primary,
                      value: yorksV1MaterialRequestTimingCopy(
                        _draft.timing,
                      ).primary,
                    ),
                    _MobileMrFact(
                      label: YorksV1MaterialRequestStrings.items.primary,
                      value: _draft.lines.length.toString(),
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_draft.lines.any((line) => line.quantityIsSuggested))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MobileMrNotice(
                    icon: Icons.info_outline_rounded,
                    text: YorksV1MaterialRequestStrings
                        .suggestedQuantityReview
                        .primary,
                  ),
                ),
              if (!active)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MobileMrNotice(
                    icon: Icons.error_outline_rounded,
                    text: YorksV1MaterialRequestStrings
                        .projectMustBeActive
                        .primary,
                    error: true,
                  ),
                ),
              Material(
                color: Colors.transparent,
                child: CheckboxListTile(
                  value: _reviewConfirmed,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: _busy
                      ? null
                      : (value) =>
                            setState(() => _reviewConfirmed = value ?? false),
                  title: Text(
                    YorksV1MaterialRequestStrings.confirmScopeAndLines.primary,
                    style: AppTypography.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
        _MobileMrStickyActions(
          secondaryLabel: YorksV1MaterialRequestStrings.saveDraft.primary,
          onSecondary: _busy ? null : widget.onSave,
          primaryLabel:
              YorksV1MaterialRequestStrings.submitToProcurement.primary,
          primaryIcon: Icons.send_rounded,
          loading:
              _busy &&
              widget.state.status ==
                  YorksV1MaterialRequestDraftSyncStatus.submitting,
          onPrimary: canSubmit ? _submit : null,
        ),
      ],
    );
  }

  Widget _boqFoldersBody() {
    if (_loadingSource) return const Center(child: CircularProgressIndicator());
    final groups = _groups ?? const <YorksV1BoqGroup>[];
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('mobile-mr-boq-folders'),
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
            children: [
              Text(
                YorksV1MaterialRequestStrings.addFromBoq.primary,
                style: AppTypography.headlineMedium.copyWith(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                YorksV1MaterialRequestStrings.selectScopeToAddBoq.primary,
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              if (groups.isEmpty)
                _MobileMrNotice(
                  icon: Icons.folder_off_outlined,
                  text: YorksV1MaterialRequestStrings.noBoqItems.primary,
                )
              else
                for (final group in groups) ...[
                  YorksMobileCard(
                    onTap: group.rowCount > 0
                        ? () => _openWorksheet(group)
                        : null,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.folder_outlined,
                          color: AppColors.blue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.effectiveTitle,
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${group.rowCount} ${YorksV1MaterialRequestStrings.items.primary.toLowerCase()}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (group.rowCount == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull,
                              ),
                            ),
                            child: Text(
                              YorksV1BoqStrings.emptyFolders.primary,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        else
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.muted,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _boqRowsBody() {
    final worksheet = _worksheet;
    if (_loadingSource || worksheet == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('mobile-mr-boq-rows'),
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
            children: [
              Text(
                worksheet.group.effectiveTitle,
                style: AppTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_selectedBoqRows.length} ${YorksV1MaterialRequestStrings.selectedItems.primary.toLowerCase()}',
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              for (final row in worksheet.rows) ...[
                YorksMobileCard(
                  onTap: () => setState(() {
                    if (_selectedBoqRows.contains(row.id)) {
                      _selectedBoqRows.remove(row.id);
                    } else {
                      _selectedBoqRows.add(row.id);
                    }
                  }),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _selectedBoqRows.contains(row.id),
                        onChanged: (_) => setState(() {
                          if (_selectedBoqRows.contains(row.id)) {
                            _selectedBoqRows.remove(row.id);
                          } else {
                            _selectedBoqRows.add(row.id);
                          }
                        }),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _boqDisplayValue(
                                    worksheet,
                                    row,
                                    YorksV1BoqCanonicalField.description,
                                  ).isEmpty
                                  ? YorksV1MaterialRequestStrings
                                        .notProvided
                                        .primary
                                  : _boqDisplayValue(
                                      worksheet,
                                      row,
                                      YorksV1BoqCanonicalField.description,
                                    ),
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_boqDisplayValue(worksheet, row, YorksV1BoqCanonicalField.quantity)} ${_boqDisplayValue(worksheet, row, YorksV1BoqCanonicalField.unit)}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        _MobileMrStickyActions(
          secondaryLabel: YorksV1MaterialRequestStrings.back.primary,
          onSecondary: () => setState(
            () => _sourcePage = _MobileMaterialRequestSourcePage.boqFolders,
          ),
          primaryLabel: YorksV1MaterialRequestStrings.addFromBoq.primary,
          primaryIcon: Icons.add_rounded,
          onPrimary: _selectedBoqRows.isEmpty || _busy
              ? null
              : _addSelectedBoqRows,
        ),
      ],
    );
  }

  Widget _customMaterialBody() => Column(
    children: [
      Expanded(
        child: ListView(
          key: const ValueKey('mobile-mr-custom-material'),
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
          children: [
            Text(
              YorksV1MaterialRequestStrings.unplannedMaterial.primary,
              style: AppTypography.headlineMedium.copyWith(
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              YorksV1MaterialRequestStrings.requestScopeDescription.primary,
              style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            YorksMobileCard(
              child: Column(
                children: [
                  _MobileInventoryDescriptionField(
                    controller: _customDescription,
                    projectId: _draft.projectId,
                    enabled: !_busy,
                    onSelected: (suggestion) => setState(() {
                      _customBrand.text = suggestion.brandOrigin ?? '';
                      _customSize.text = suggestion.size ?? '';
                      _customModel.text = suggestion.model ?? '';
                      _customUnit = suggestion.unit;
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customBrand,
                    decoration: InputDecoration(
                      labelText:
                          YorksV1MaterialRequestStrings.brandOrigin.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customSize,
                    decoration: InputDecoration(
                      labelText: YorksV1MaterialRequestStrings.size.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customModel,
                    decoration: InputDecoration(
                      labelText: YorksV1MaterialRequestStrings
                          .planningModelTag
                          .primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _customQuantity,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                YorksV1MaterialRequestStrings.quantity.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _customUnit,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText:
                                YorksV1MaterialRequestStrings.unit.primary,
                          ),
                          items: [
                            for (final unit in _mrUnitOptions)
                              DropdownMenuItem(value: unit, child: Text(unit)),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) => setState(
                                  () => _customUnit = value ?? _customUnit,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _MobileMrStickyActions(
        secondaryLabel: YorksV1MaterialRequestStrings.back.primary,
        onSecondary: () =>
            setState(() => _sourcePage = _MobileMaterialRequestSourcePage.none),
        primaryLabel: YorksV1MaterialRequestStrings.addCustomItem.primary,
        primaryIcon: Icons.add_rounded,
        onPrimary: _busy ? null : _addCustomMaterial,
      ),
    ],
  );

  Widget _successPage(
    BuildContext context,
    YorksV1MaterialRequest request,
  ) => ColoredBox(
    color: AppColors.mobileSurface,
    child: Column(
      children: [
        YorksMobileAppBar(
          title: YorksV1MaterialRequestStrings.submitted.primary,
          leading: YorksMobileIconButton(
            icon: Icons.close_rounded,
            tooltip: YorksV1MaterialRequestStrings.backToRequests.primary,
            onPressed: () => context.go(RoutePaths.yorksV1MaterialRequests),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: YorksMobileCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          color: AppColors.successContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox.square(
                          dimension: 64,
                          child: Icon(
                            Icons.check_rounded,
                            color: AppColors.success,
                            size: 34,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        YorksV1MaterialRequestStrings.submitted.primary,
                        textAlign: TextAlign.center,
                        style: AppTypography.headlineSmall.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        YorksV1MaterialRequestStrings.serverConfirmed.primary,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        request.requestNumber ??
                            YorksV1MaterialRequestStrings
                                .assignedOnSubmit
                                .primary,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.blue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        _MobileMrStickyActions(
          secondaryLabel: YorksV1MaterialRequestStrings.backToRequests.primary,
          onSecondary: () => context.go(RoutePaths.yorksV1MaterialRequests),
          primaryLabel: YorksV1MaterialRequestStrings.viewRequest.primary,
          primaryIcon: Icons.arrow_forward_rounded,
          onPrimary: () =>
              context.go(RoutePaths.yorksV1MaterialRequestPath(request.id)),
        ),
      ],
    ),
  );

  Future<void> _continueToMaterials() async {
    if (_draft.projectId == null || _draft.scopeId == null) {
      _snack(context, YorksV1MaterialRequestStrings.missingRequired.primary);
      return;
    }
    setState(() => _step = _MobileMaterialRequestDraftStep.materials);
  }

  Future<void> _changeProject(String? projectId) async {
    final requiresConfirmation =
        _draft.lines.isNotEmpty && projectId != _draft.projectId;
    if (requiresConfirmation &&
        !await _confirmDiscard(
          YorksV1MaterialRequestStrings.changeProject.primary,
          YorksV1MaterialRequestStrings.changeProjectDiscardLines.primary
              .replaceFirst('{count}', _draft.lines.length.toString()),
        )) {
      return;
    }
    await widget.controller.setProject(
      projectId,
      discardExistingLines: requiresConfirmation,
    );
  }

  Future<void> _changeScope(String? scopeId) async {
    final boqRows = _draft.lines
        .where((line) => line.source == YorksV1MaterialRequestLineSource.boq)
        .length;
    final requiresConfirmation = scopeId != _draft.scopeId && boqRows > 0;
    if (requiresConfirmation &&
        !await _confirmDiscard(
          YorksV1MaterialRequestStrings.changeScope.primary,
          YorksV1MaterialRequestStrings.changeScopeDiscardBoqRows.primary
              .replaceFirst('{count}', boqRows.toString()),
        )) {
      return;
    }
    await widget.controller.setScope(
      scopeId,
      discardIncompatibleBoqRows: requiresConfirmation,
    );
  }

  Future<bool> _confirmDiscard(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        animationStyle: AnimationStyle.noAnimation,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(YorksV1MaterialRequestStrings.cancel.primary),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(title),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _pickScheduledDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      initialDate: _draft.scheduledDate ?? now,
    );
    if (selected != null) await widget.controller.setScheduledDate(selected);
  }

  Future<void> _openBoqFolders() async {
    if (_draft.projectId == null || _draft.scopeId == null) {
      _snack(
        context,
        YorksV1MaterialRequestStrings.selectScopeToAddBoq.primary,
      );
      return;
    }
    setState(() {
      _loadingSource = true;
      _sourcePage = _MobileMaterialRequestSourcePage.boqFolders;
    });
    try {
      final groups = await ref
          .read(yorksV1BoqRepositoryProvider)
          .listGroupsForScope(_draft.projectId!, scopeId: _draft.scopeId!);
      if (mounted) {
        setState(() => _groups = groups);
      }
    } catch (_) {
      if (mounted) {
        _snack(context, YorksV1MaterialRequestStrings.saveFailed.primary);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingSource = false);
      }
    }
  }

  Future<void> _openWorksheet(YorksV1BoqGroup group) async {
    setState(() => _loadingSource = true);
    try {
      final worksheet = await ref
          .read(yorksV1BoqRepositoryProvider)
          .getWorksheet(group.id);
      if (!mounted) return;
      final existing = _draft.lines
          .map((line) => line.sourceBoqRowId)
          .whereType<String>();
      setState(() {
        _worksheet = worksheet;
        _selectedBoqRows
          ..clear()
          ..addAll(
            existing.where((id) => worksheet.rows.any((row) => row.id == id)),
          );
        _sourcePage = _MobileMaterialRequestSourcePage.boqRows;
      });
    } catch (_) {
      if (mounted) {
        _snack(context, YorksV1MaterialRequestStrings.saveFailed.primary);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingSource = false);
      }
    }
  }

  Future<void> _addSelectedBoqRows() async {
    final worksheet = _worksheet;
    if (worksheet == null) return;
    try {
      await widget.controller.addBoqRows(
        worksheet: worksheet,
        rowIds: _selectedBoqRows,
      );
      if (!mounted) return;
      setState(() {
        _sourcePage = _MobileMaterialRequestSourcePage.none;
        _selectedBoqRows.clear();
      });
      _snack(context, YorksV1MaterialRequestStrings.itemAdded.primary);
    } on YorksV1DomainException {
      if (mounted) {
        _snack(
          context,
          YorksV1MaterialRequestStrings.selectScopeToAddBoq.primary,
        );
      }
    } catch (_) {
      if (mounted) {
        _snack(context, YorksV1MaterialRequestStrings.saveFailed.primary);
      }
    }
  }

  Future<void> _addCustomMaterial() async {
    if (_customDescription.text.trim().isEmpty ||
        _customQuantity.text.trim().isEmpty) {
      _snack(context, YorksV1MaterialRequestStrings.missingRequired.primary);
      return;
    }
    await widget.controller.addCustomLine();
    final line = widget.controller.currentDraft.lines.lastOrNull;
    if (line == null) return;
    await widget.controller.updateLine(
      line.id,
      (current) => current.copyWith(
        description: _customDescription.text,
        brandOrigin: _customBrand.text.trim().isEmpty
            ? null
            : _customBrand.text,
        size: _customSize.text.trim().isEmpty ? null : _customSize.text,
        model: _customModel.text.trim().isEmpty ? null : _customModel.text,
        quantity: _customQuantity.text,
        unit: _customUnit,
      ),
    );
    if (!mounted) return;
    setState(() {
      _sourcePage = _MobileMaterialRequestSourcePage.none;
      _customDescription.clear();
      _customBrand.clear();
      _customSize.clear();
      _customModel.clear();
      _customQuantity.text = '1';
      _customUnit = 'Nos';
    });
    _snack(context, YorksV1MaterialRequestStrings.itemAdded.primary);
  }

  Future<void> _submit() async {
    final submitted = await widget.onSubmit();
    if (submitted != null && mounted) setState(() => _submitted = submitted);
  }

  void _back() {
    if (_sourcePage == _MobileMaterialRequestSourcePage.boqRows) {
      setState(() => _sourcePage = _MobileMaterialRequestSourcePage.boqFolders);
      return;
    }
    if (_sourcePage != _MobileMaterialRequestSourcePage.none) {
      setState(() => _sourcePage = _MobileMaterialRequestSourcePage.none);
      return;
    }
    if (_step == _MobileMaterialRequestDraftStep.review) {
      setState(() => _step = _MobileMaterialRequestDraftStep.materials);
      return;
    }
    if (_step == _MobileMaterialRequestDraftStep.materials) {
      setState(() => _step = _MobileMaterialRequestDraftStep.information);
      return;
    }
    context.pop();
  }
}

class _MobileMrProgress extends StatelessWidget {
  const _MobileMrProgress({required this.step});

  final _MobileMaterialRequestDraftStep step;

  @override
  Widget build(BuildContext context) {
    const labels = [
      YorksV1MaterialRequestStrings.requestInformation,
      YorksV1MaterialRequestStrings.materialItems,
      YorksV1MaterialRequestStrings.review,
    ];
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: index <= step.index
                        ? AppColors.blue
                        : AppColors.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: index < step.index
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: AppColors.onPrimary,
                        )
                      : Text(
                          '${index + 1}',
                          style: AppTypography.labelSmall.copyWith(
                            color: index <= step.index
                                ? AppColors.onPrimary
                                : AppColors.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[index].primary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelSmall.copyWith(
                    color: index == step.index
                        ? AppColors.blue
                        : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (index + 1 < labels.length)
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.only(bottom: 22),
                color: index < step.index ? AppColors.blue : AppColors.line,
              ),
            ),
        ],
      ],
    );
  }
}

class _MobileMrStickyActions extends StatelessWidget {
  const _MobileMrStickyActions({
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.loading = false,
  });

  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool loading;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          if (secondaryLabel != null) ...[
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('mobile-mr-secondary-action'),
                onPressed: onSecondary,
                child: Text(secondaryLabel!),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: secondaryLabel == null ? 1 : 2,
            child: FilledButton.icon(
              key: const ValueKey('mobile-mr-primary-action'),
              onPressed: onPrimary,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Icon(primaryIcon),
              label: Text(primaryLabel),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MobileMrSourceAction extends StatelessWidget {
  const _MobileMrSourceAction({
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => YorksMobileCard(
    onTap: onTap,
    child: Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.blueContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox.square(
            dimension: 38,
            child: Icon(icon, size: 20, color: AppColors.blue),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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

class _MobileMrDraftLineCard extends StatelessWidget {
  const _MobileMrDraftLineCard({
    required this.line,
    required this.enabled,
    required this.onRemove,
  });

  final YorksV1MaterialRequestLine line;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => YorksMobileCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${line.displayOrder}',
            style: AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.description.isEmpty
                    ? YorksV1MaterialRequestStrings.notProvided.primary
                    : line.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${yorksV1DisplayQuantity(line.quantity)} ${line.unit}${line.brandOrigin?.trim().isNotEmpty == true ? ' · ${line.brandOrigin}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        SizedBox.square(
          dimension: AppSpacing.minTapTarget,
          child: IconButton(
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
            onPressed: enabled ? onRemove : null,
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.error,
              size: 20,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MobileMrFact extends StatelessWidget {
  const _MobileMrFact({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        if (!last)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Divider(height: 1, color: AppColors.line),
          ),
      ],
    ),
  );
}

class _MobileMrNotice extends StatelessWidget {
  const _MobileMrNotice({
    required this.icon,
    required this.text,
    this.error = false,
  });

  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: error ? AppColors.errorContainer : AppColors.blueContainer,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: error ? AppColors.errorContainer : AppColors.blueContainerStrong,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: error ? AppColors.error : AppColors.blue),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.inkSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Display-only preview matching the R35 prototype. The server assigns the
/// authoritative request number during Submit; this value must never be used
/// as an identifier for a write or workflow transition.
String _previewRequestNumber(YorksV1MaterialRequestProjectOption? project) =>
    YorksV1MaterialRequestStrings.assignedOnSubmit.primary;

int _materialRequestStage(YorksV1MaterialRequestState state) => switch (state) {
  YorksV1MaterialRequestState.draft => 1,
  YorksV1MaterialRequestState.submitted ||
  YorksV1MaterialRequestState.awaitingRequestApproval ||
  YorksV1MaterialRequestState.changesRequested => 2,
  YorksV1MaterialRequestState.approvedForArrangement ||
  YorksV1MaterialRequestState.arranging ||
  YorksV1MaterialRequestState.awaitingApproval => 3,
  YorksV1MaterialRequestState.approved => 4,
  YorksV1MaterialRequestState.partiallyDispatched ||
  YorksV1MaterialRequestState.dispatched => 5,
  YorksV1MaterialRequestState.partiallyReceived ||
  YorksV1MaterialRequestState.received => 6,
  YorksV1MaterialRequestState.closed => 7,
  YorksV1MaterialRequestState.cancelled => 1,
};

List<TranslatableString> get _materialRequestStageLabels => const [
  YorksV1MaterialRequestStrings.requestCreated,
  YorksV1MaterialRequestStrings.engineeringApproval,
  YorksV1MaterialRequestStrings.procurementArrangement,
  YorksV1MaterialRequestStrings.readyForDeliveryStage,
  YorksV1MaterialRequestStrings.dispatch,
  YorksV1MaterialRequestStrings.receivedStage,
  YorksV1MaterialRequestStrings.completedStage,
];

List<TranslatableString> get _materialRequestCompactStageLabels => const [
  YorksV1MaterialRequestStrings.requestCreated,
  YorksV1MaterialRequestStrings.engineeringApprovalShort,
  YorksV1MaterialRequestStrings.procurementArrangementShort,
  YorksV1MaterialRequestStrings.readyForDeliveryShort,
  YorksV1MaterialRequestStrings.dispatch,
  YorksV1MaterialRequestStrings.receivedStage,
  YorksV1MaterialRequestStrings.completedStage,
];

String _materialRequestNextAction(YorksV1MaterialRequest value) {
  if (value.currentActionCode == 'replacement_dispatch_required') {
    return YorksV1MaterialRequestStrings.replacementDispatchRequired.primary;
  }
  if (value.currentActionCode == 'receipt_review_required') {
    return YorksV1MaterialRequestStrings.awaitingReceipt.primary;
  }
  if (value.currentActionCode == 'material_request_close_review') {
    return YorksV1MaterialRequestStrings.closeReviewRequired.primary;
  }
  return switch (value.state) {
    YorksV1MaterialRequestState.submitted ||
    YorksV1MaterialRequestState.awaitingRequestApproval =>
      YorksV1MaterialRequestStrings.awaitingRequestApproval.primary,
    YorksV1MaterialRequestState.changesRequested =>
      YorksV1MaterialRequestStrings.changesRequested.primary,
    YorksV1MaterialRequestState.approvedForArrangement ||
    YorksV1MaterialRequestState.arranging =>
      YorksV1MaterialRequestStrings.procurementArranging.primary,
    YorksV1MaterialRequestState.awaitingApproval =>
      YorksV1MaterialRequestStrings.waitingForApproval.primary,
    YorksV1MaterialRequestState.approved =>
      YorksV1MaterialRequestStrings.readyForDispatch.primary,
    YorksV1MaterialRequestState.partiallyDispatched ||
    YorksV1MaterialRequestState.dispatched =>
      YorksV1MaterialRequestStrings.awaitingReceipt.primary,
    YorksV1MaterialRequestState.partiallyReceived =>
      YorksV1MaterialRequestStrings.replacementDispatchRequired.primary,
    YorksV1MaterialRequestState.received ||
    YorksV1MaterialRequestState.closed =>
      YorksV1MaterialRequestStrings.receiptCompleted.primary,
    YorksV1MaterialRequestState.draft =>
      YorksV1MaterialRequestStrings.draftPrivate.primary,
    YorksV1MaterialRequestState.cancelled =>
      YorksV1MaterialRequestStrings.cancelled.primary,
  };
}

class _R35RequestHero extends StatelessWidget {
  const _R35RequestHero({
    required this.title,
    required this.requesterName,
    required this.projectName,
    required this.lineCount,
    required this.onCancel,
    required this.onSave,
    required this.onSubmit,
    required this.submitting,
  });

  final String title;
  final String requesterName;
  final String? projectName;
  final int lineCount;
  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final VoidCallback? onSubmit;
  final bool submitting;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked = constraints.maxWidth < 920;
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            YorksV1MaterialRequestStrings.requests.primary.toUpperCase(),
            style: AppTypography.eyebrow,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                YorksV1MaterialRequestStrings.newRequest.primary,
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _IndustrialStageChip(stage: 1),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            YorksV1MaterialRequestStrings.requestScopeDescription.primary,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              _IndustrialMeta(icon: Icons.tag_rounded, value: title),
              _IndustrialMeta(
                icon: Icons.person_outline_rounded,
                value: requesterName.trim().isEmpty
                    ? YorksV1MaterialRequestStrings.requester.primary
                    : requesterName,
              ),
              if (projectName?.trim().isNotEmpty == true)
                _IndustrialMeta(
                  icon: Icons.business_outlined,
                  value: projectName!,
                ),
              _IndustrialMeta(
                icon: Icons.inventory_2_outlined,
                value:
                    '$lineCount ${YorksV1MaterialRequestStrings.items.primary.toLowerCase()}',
              ),
            ],
          ),
        ],
      );
      final actions = Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        alignment: stacked ? WrapAlignment.start : WrapAlignment.end,
        children: [
          _R35RequestAction(
            label: YorksV1MaterialRequestStrings.saveDraft.primary,
            icon: Icons.save_outlined,
            onPressed: onSave,
          ),
          _R35RequestAction(
            label: YorksV1MaterialRequestStrings.cancel.primary,
            onPressed: onCancel,
          ),
          _R35RequestAction(
            label: YorksV1MaterialRequestStrings.submitToProcurement.primary,
            icon: Icons.arrow_forward_rounded,
            primary: true,
            onPressed: onSubmit,
            loading: submitting,
          ),
        ],
      );
      return Container(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: stacked
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
                  const SizedBox(width: AppSpacing.xl),
                  actions,
                ],
              ),
      );
    },
  );
}

class _IndustrialStageChip extends StatelessWidget {
  const _IndustrialStageChip({required this.stage});

  final int stage;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.successContainer,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      border: Border.all(color: AppColors.success.withValues(alpha: .18)),
    ),
    child: Text(
      YorksV1MaterialRequestStrings.stageOfSeven(stage).primary,
      style: AppTypography.labelSmall.copyWith(
        color: AppColors.onSuccessContainer,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _IndustrialMeta extends StatelessWidget {
  const _IndustrialMeta({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 260),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.muted),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    ),
  );
}

class _IndustrialSectionNumber extends StatelessWidget {
  const _IndustrialSectionNumber({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.blue,
      shape: BoxShape.circle,
    ),
    child: Text(
      '$value',
      style: AppTypography.labelSmall.copyWith(
        color: AppColors.onPrimary,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _IndustrialWorkflowStrip extends StatelessWidget {
  const _IndustrialWorkflowStrip({required this.stage, this.condensed = false});

  final int stage;
  final bool condensed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Long approval/arrangement labels cannot remain legible in a narrow
      // mobile viewport when all seven are squeezed into equal columns. The
      // desktop inspector keeps the familiar single-row lifecycle, while the
      // same seven-stage truth becomes a compact timeline on mobile.
      if (MediaQuery.sizeOf(context).width <
          AppSpacing.yorksV1DesktopBreakpoint) {
        return Column(
          children: [
            for (
              var index = 0;
              index < _materialRequestStageLabels.length;
              index++
            )
              _CompactWorkflowStage(
                number: index + 1,
                label: _materialRequestStageLabels[index].primary,
                stage: stage,
                last: index == _materialRequestStageLabels.length - 1,
              ),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (
            var index = 0;
            index < _materialRequestStageLabels.length;
            index++
          )
            Expanded(
              child: _IndustrialWorkflowStage(
                number: index + 1,
                label:
                    (condensed
                            ? _materialRequestCompactStageLabels[index]
                            : _materialRequestStageLabels[index])
                        .primary,
                stage: stage,
                first: index == 0,
                last: index == _materialRequestStageLabels.length - 1,
                condensed: condensed,
              ),
            ),
        ],
      );
    },
  );
}

class _CompactWorkflowStage extends StatelessWidget {
  const _CompactWorkflowStage({
    required this.number,
    required this.label,
    required this.stage,
    required this.last,
  });

  final int number;
  final String label;
  final int stage;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final complete = number < stage;
    final active = number == stage;
    return SizedBox(
      height: last ? 34 : 42,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: complete
                        ? AppColors.success
                        : active
                        ? AppColors.blue
                        : AppColors.surfaceContainerLowest,
                    border: Border.all(
                      color: active
                          ? AppColors.blue
                          : complete
                          ? AppColors.success
                          : AppColors.lineStrong,
                    ),
                  ),
                  child: complete
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: AppColors.onSuccess,
                        )
                      : Text(
                          '$number',
                          style: AppTypography.labelSmall.copyWith(
                            color: active
                                ? AppColors.onPrimary
                                : AppColors.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: complete ? AppColors.success : AppColors.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium.copyWith(
                  color: active || complete ? AppColors.ink : AppColors.muted,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndustrialWorkflowStage extends StatelessWidget {
  const _IndustrialWorkflowStage({
    required this.number,
    required this.label,
    required this.stage,
    required this.first,
    required this.last,
    required this.condensed,
  });

  final int number;
  final String label;
  final int stage;
  final bool first;
  final bool last;
  final bool condensed;

  @override
  Widget build(BuildContext context) {
    final complete = number < stage;
    final active = number == stage;
    final color = complete
        ? AppColors.success
        : active
        ? AppColors.blue
        : AppColors.lineStrong;
    final diameter = condensed ? 22.0 : 26.0;
    return Column(
      children: [
        SizedBox(
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PositionedDirectional(
                start: first ? diameter / 2 : 0,
                end: last ? diameter / 2 : 0,
                child: Container(
                  height: 1.5,
                  color: number <= stage
                      ? AppColors.success.withValues(alpha: .55)
                      : AppColors.line,
                ),
              ),
              Container(
                width: diameter,
                height: diameter,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: complete
                      ? AppColors.success
                      : active
                      ? AppColors.blue
                      : AppColors.surfaceContainerLowest,
                  border: Border.all(color: color, width: active ? 2 : 1.2),
                ),
                child: complete
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.onSuccess,
                      )
                    : Text(
                        '$number',
                        style: AppTypography.labelSmall.copyWith(
                          color: active ? AppColors.onPrimary : AppColors.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: condensed ? 2 : 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelSmall.copyWith(
            fontSize: condensed ? 7.8 : 9,
            color: complete || active
                ? AppColors.inkSecondary
                : AppColors.muted,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _IndustrialNotice extends StatelessWidget {
  const _IndustrialNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.warningContainer.withValues(alpha: .62),
      border: Border.all(color: AppColors.warning.withValues(alpha: .2)),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.warning),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.inkSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _IndustrialFactRow extends StatelessWidget {
  const _IndustrialFactRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _R35RequestCard extends StatelessWidget {
  const _R35RequestCard({
    required this.title,
    required this.child,
    this.sectionNumber,
    this.description,
    this.actions = const [],
  });

  final String title;
  final int? sectionNumber;
  final String? description;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) => _R35RequestSurface(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final heading = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sectionNumber != null) ...[
              _IndustrialSectionNumber(value: sectionNumber!),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      description!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
            const SizedBox(height: AppSpacing.lg),
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
  });

  final YorksV1MaterialRequestDraft draft;
  final AsyncValue<List<YorksV1MaterialRequestProjectOption>> projects;
  final AsyncValue<List<YorksV1MaterialRequestScopeOption>> scopes;
  final String requesterName;

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
            children: [
              const Icon(
                Icons.account_tree_outlined,
                size: 19,
                color: AppColors.blue,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  YorksV1MaterialRequestStrings.requestStatus.primary,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _ReviewStatusChip(ready: ready),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _IndustrialWorkflowStrip(stage: 1, condensed: true),
          const SizedBox(height: AppSpacing.lg),
          _IndustrialNotice(
            icon: Icons.info_outline_rounded,
            text: YorksV1MaterialRequestStrings.requestApprovalPrompt.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.lg),
          Text(
            YorksV1MaterialRequestStrings.review.primary,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _IndustrialFactRow(
            label: YorksV1MaterialRequestStrings.requestNumber.primary,
            value: _previewRequestNumber(project),
          ),
          _IndustrialFactRow(
            label: YorksV1MaterialRequestStrings.project.primary,
            value: project == null
                ? YorksV1MaterialRequestStrings.project.primary
                : '${project.reference} · ${project.name}',
          ),
          _IndustrialFactRow(
            label: YorksV1MaterialRequestStrings.scopeLabel.primary,
            value: scope?.name ?? YorksV1MaterialRequestStrings.scope.primary,
          ),
          _IndustrialFactRow(
            label: YorksV1MaterialRequestStrings.delivery.primary,
            value: yorksV1MaterialRequestTimingCopy(draft.timing).primary,
          ),
          _IndustrialFactRow(
            label: YorksV1MaterialRequestStrings.requestedBy.primary,
            value: requesterName.trim().isEmpty
                ? YorksV1MaterialRequestStrings.notProvided.primary
                : requesterName,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _R35RequestSurface extends StatelessWidget {
  const _R35RequestSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xl),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 12,
          offset: Offset(0, 4),
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

class _DraftDiscussionLoading extends StatelessWidget {
  const _DraftDiscussionLoading();

  @override
  Widget build(BuildContext context) => _R35RequestSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          YorksV1MaterialRequestStrings.discussion.primary,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const LinearProgressIndicator(),
      ],
    ),
  );
}

class _DraftDiscussionPrompt extends StatelessWidget {
  const _DraftDiscussionPrompt({required this.canSave, required this.onSave});

  final bool canSave;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) => _R35RequestSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.forum_outlined, size: 19, color: AppColors.blue),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                YorksV1MaterialRequestStrings.discussion.primary,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Icon(
          Icons.chat_bubble_outline_rounded,
          size: 34,
          color: AppColors.muted.withValues(alpha: .7),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          YorksV1MaterialRequestStrings.saveDraftToDiscuss.primary,
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
        ),
        if (canSave && onSave != null) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(YorksV1MaterialRequestStrings.saveDraft.primary),
          ),
        ],
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
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool loading;

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
                backgroundColor: AppColors.blue,
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
    return child;
  }
}

/// Keeps source/import actions in the primary visual lane while preserving the
/// spreadsheet row tools required for fast desktop entry. The two concerns no
/// longer compete in one unstructured wrap at medium desktop widths.
class _R35MaterialActionBar extends StatelessWidget {
  const _R35MaterialActionBar({
    required this.canEdit,
    required this.canUseBoq,
    required this.excelEnabled,
    required this.onAddCustom,
    required this.onAddBlank,
    required this.onAddBoq,
    required this.onImport,
    required this.onExport,
  });

  final bool canEdit;
  final bool canUseBoq;
  final bool excelEnabled;
  final VoidCallback onAddCustom;
  final VoidCallback onAddBlank;
  final VoidCallback onAddBoq;
  final VoidCallback onImport;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      _R35RequestAction(
        label: YorksV1MaterialRequestStrings.addCustomItem.primary,
        icon: Icons.add_rounded,
        primary: true,
        onPressed: canEdit ? onAddCustom : null,
      ),
      _R35RequestAction(
        label: YorksV1MaterialRequestStrings.addFromBoq.primary,
        icon: Icons.folder_outlined,
        onPressed: canUseBoq ? onAddBoq : null,
      ),
      if (excelEnabled)
        _R35RequestAction(
          label: YorksV1MaterialRequestStrings.importExcel.primary,
          icon: Icons.upload_outlined,
          onPressed: canEdit ? onImport : null,
        ),
      if (excelEnabled)
        _R35RequestAction(
          label: YorksV1MaterialRequestStrings.exportExcel.primary,
          icon: Icons.download_outlined,
          onPressed: canEdit ? onExport : null,
        ),
      _R35RequestAction(
        label: YorksV1MaterialRequestStrings.addBlankRow.primary,
        icon: Icons.table_rows_outlined,
        onPressed: canEdit ? onAddBlank : null,
      ),
    ],
  );
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
      final wide = constraints.maxWidth >= 680;
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
          enabled: !controller.isEditingBeforeApproval,
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
          onChanged: (scopeId) async {
            final boqLineCount = controller.currentDraft.lines
                .where(
                  (line) => line.source == YorksV1MaterialRequestLineSource.boq,
                )
                .length;
            final requiresConfirmation =
                scopeId != controller.currentDraft.scopeId && boqLineCount > 0;
            if (requiresConfirmation) {
              final confirmed = await showDialog<bool>(
                context: context,
                animationStyle: AnimationStyle.noAnimation,
                builder: (dialogContext) => AlertDialog(
                  title: Text(
                    YorksV1MaterialRequestStrings.changeScope.primary,
                  ),
                  content: Text(
                    YorksV1MaterialRequestStrings
                        .changeScopeDiscardBoqRows
                        .primary
                        .replaceFirst('{count}', boqLineCount.toString()),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(YorksV1MaterialRequestStrings.cancel.primary),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(
                        YorksV1MaterialRequestStrings.changeScope.primary,
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
            }
            await controller.setScope(
              scopeId,
              discardIncompatibleBoqRows: requiresConfirmation,
            );
          },
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
          if (!wide)
            for (final field in fields) ...[
              field,
              const SizedBox(height: AppSpacing.md),
            ]
          else
            Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: fields[0]),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(flex: 2, child: fields[1]),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: fields[2]),
                    if (fields.length > 4) ...[
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: fields[3]),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: fields[4]),
                    ] else ...[
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: fields[3]),
                    ],
                  ],
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
    this.enabled = true,
  });

  final String? value;
  final AsyncValue<List<YorksV1MaterialRequestProjectOption>> projects;
  final ValueChanged<String?> onChanged;
  final bool enabled;

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
      onChanged: enabled ? onChanged : null,
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

class _MobileInventoryDescriptionField extends ConsumerStatefulWidget {
  const _MobileInventoryDescriptionField({
    required this.controller,
    required this.projectId,
    required this.enabled,
    required this.onSelected,
  });

  final TextEditingController controller;
  final String? projectId;
  final bool enabled;
  final ValueChanged<YorksV1MaterialRequestInventorySuggestion> onSelected;

  @override
  ConsumerState<_MobileInventoryDescriptionField> createState() =>
      _MobileInventoryDescriptionFieldState();
}

class _MobileInventoryDescriptionFieldState
    extends ConsumerState<_MobileInventoryDescriptionField> {
  final FocusNode _focusNode = FocusNode();

  Future<Iterable<YorksV1MaterialRequestInventorySuggestion>> _options(
    TextEditingValue value,
  ) async {
    final query = value.text.trim();
    final projectId = widget.projectId?.trim();
    if (!widget.enabled ||
        projectId == null ||
        projectId.isEmpty ||
        query.length < 2) {
      return const <YorksV1MaterialRequestInventorySuggestion>[];
    }
    try {
      return await ref.read(
        yorksV1MaterialRequestInventorySearchProvider(
          YorksV1MaterialRequestInventorySearchKey(
            projectId: projectId,
            query: query,
          ),
        ).future,
      );
    } catch (_) {
      return const <YorksV1MaterialRequestInventorySuggestion>[];
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => RawAutocomplete<YorksV1MaterialRequestInventorySuggestion>(
    textEditingController: widget.controller,
    focusNode: _focusNode,
    displayStringForOption: (option) => option.description,
    optionsBuilder: _options,
    onSelected: widget.onSelected,
    fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          textCapitalization: TextCapitalization.sentences,
          onFieldSubmitted: (_) => onSubmitted(),
          decoration: InputDecoration(
            labelText: YorksV1MaterialRequestStrings.itemDescription.primary,
            suffixIcon: const Icon(Icons.search_rounded, size: 19),
          ),
        ),
    optionsViewBuilder: (context, select, options) {
      final values = options.toList(growable: false);
      return Align(
        alignment: AlignmentDirectional.topStart,
        child: Material(
          elevation: 8,
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340, maxHeight: 280),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: values.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = values[index];
                return ListTile(
                  minTileHeight: AppSpacing.minTapTarget,
                  leading: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.blue,
                  ),
                  title: Text(item.description),
                  subtitle: Text(
                    [?item.size, ?item.model, item.unit].join(' · '),
                  ),
                  onTap: () => select(item),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _chooseInventorySuggestion(
  BuildContext context,
  WidgetRef _, {
  required String projectId,
  required YorksV1MaterialRequestLine line,
  required YorksV1MaterialRequestDraftController controller,
}) async {
  final suggestion =
      await showDialog<YorksV1MaterialRequestInventorySuggestion>(
        context: context,
        animationStyle: AnimationStyle.noAnimation,
        builder: (_) => _InventorySuggestionDialog(
          projectId: projectId,
          initialQuery: line.description,
        ),
      );
  if (suggestion == null) return;
  await controller.updateLine(
    line.id,
    (current) => current.copyWith(
      description: suggestion.description,
      brandOrigin: suggestion.brandOrigin,
      size: suggestion.size,
      model: suggestion.model,
      unit: suggestion.unit,
    ),
  );
}

class _InventorySuggestionDialog extends ConsumerStatefulWidget {
  const _InventorySuggestionDialog({
    required this.projectId,
    required this.initialQuery,
  });

  final String projectId;
  final String initialQuery;

  @override
  ConsumerState<_InventorySuggestionDialog> createState() =>
      _InventorySuggestionDialogState();
}

class _InventorySuggestionDialogState
    extends ConsumerState<_InventorySuggestionDialog> {
  late final TextEditingController _queryController;
  Timer? _debounce;
  late String _query = widget.initialQuery.trim();

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _query.length < 2
        ? const AsyncData<List<YorksV1MaterialRequestInventorySuggestion>>([])
        : ref.watch(
            yorksV1MaterialRequestInventorySearchProvider(
              YorksV1MaterialRequestInventorySearchKey(
                projectId: widget.projectId,
                query: _query,
              ),
            ),
          );
    return AlertDialog(
      title: Text(YorksV1MaterialRequestStrings.searchInventory.primary),
      content: SizedBox(
        width: 620,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _queryController,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                labelText:
                    YorksV1MaterialRequestStrings.itemDescription.primary,
              ),
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 280), () {
                  if (mounted) setState(() => _query = value.trim());
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: results.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _RequestError(
                  language: AppLanguage.english,
                  onRetry: () => ref.invalidate(
                    yorksV1MaterialRequestInventorySearchProvider(
                      YorksV1MaterialRequestInventorySearchKey(
                        projectId: widget.projectId,
                        query: _query,
                      ),
                    ),
                  ),
                ),
                data: (items) => ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final details = <String>[
                      ?item.itemCode,
                      ?item.brandOrigin,
                      if (item.size != null)
                        '${YorksV1MaterialRequestStrings.size.primary}: ${item.size}',
                      if (item.model != null)
                        '${YorksV1MaterialRequestStrings.planningModelTag.primary}: ${item.model}',
                      item.unit,
                    ];
                    return ListTile(
                      minTileHeight: AppSpacing.minTapTarget,
                      title: Text(item.description),
                      subtitle: details.isEmpty
                          ? null
                          : Text(details.join(' · ')),
                      trailing: const Icon(Icons.north_west_rounded),
                      onTap: () => Navigator.of(context).pop(item),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(YorksV1MaterialRequestStrings.cancel.primary),
        ),
      ],
    );
  }
}

class _RequestLinesEditor extends ConsumerWidget {
  const _RequestLinesEditor({
    required this.lines,
    required this.controller,
    required this.enabled,
    required this.projectId,
  });

  final List<YorksV1MaterialRequestLine> lines;
  final YorksV1MaterialRequestDraftController controller;
  final bool enabled;
  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (lines.isEmpty) {
      return Text(
        YorksV1MaterialRequestStrings.missingRequired.primary,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
      );
    }
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
          builder: (context, constraints) =>
              MediaQuery.sizeOf(context).width >=
                  AppSpacing.yorksV1DesktopBreakpoint
              ? _DesktopLinesTable(
                  lines: lines,
                  controller: controller,
                  enabled: enabled,
                  projectId: projectId,
                )
              : Column(
                  children: [
                    for (final line in lines) ...[
                      _FocusedLineEditor(
                        line: line,
                        controller: controller,
                        enabled: enabled,
                        onSearchInventory: projectId == null
                            ? null
                            : () => _chooseInventorySuggestion(
                                context,
                                ref,
                                projectId: projectId!,
                                line: line,
                                controller: controller,
                              ),
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
    required this.projectId,
  });

  final List<YorksV1MaterialRequestLine> lines;
  final YorksV1MaterialRequestDraftController controller;
  final bool enabled;
  final String? projectId;

  @override
  Widget build(BuildContext context) {
    // The UI intentionally mirrors the familiar Yorks material form.  The
    // controlled Excel/PDF contract remains role-safe, but the editable web
    // grid keeps size and model/tag visible as first-class columns so an
    // engineer can scan and correct a row without opening a secondary editor.
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
              AppStrings.action.primary.toUpperCase(),
              style: headerStyle,
            ),
          ),
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
              child: _InventoryDescriptionField(
                line: line,
                controller: controller,
                enabled: enabled,
                projectId: projectId,
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
                initialValue: yorksV1DisplayQuantity(line.quantity),
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
        child: Table(
          columnWidths: const {
            0: FixedColumnWidth(50),
            1: FlexColumnWidth(2.5),
            2: FlexColumnWidth(1.25),
            3: FlexColumnWidth(1.4),
            4: FlexColumnWidth(1.45),
            5: FlexColumnWidth(.9),
            6: FixedColumnWidth(106),
            7: FixedColumnWidth(68),
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

/// Inventory suggestions belong to the description cell so an engineer gets
/// useful matches while typing, without leaving the row or opening a dialog.
/// Selecting a result copies only the trusted non-commercial descriptive
/// projection; quantity remains deliberate user input.
class _InventoryDescriptionField extends ConsumerStatefulWidget {
  const _InventoryDescriptionField({
    required this.line,
    required this.controller,
    required this.enabled,
    required this.projectId,
  });

  final YorksV1MaterialRequestLine line;
  final YorksV1MaterialRequestDraftController controller;
  final bool enabled;
  final String? projectId;

  @override
  ConsumerState<_InventoryDescriptionField> createState() =>
      _InventoryDescriptionFieldState();
}

class _InventoryDescriptionFieldState
    extends ConsumerState<_InventoryDescriptionField> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  late String _lastCommitted;

  @override
  void initState() {
    super.initState();
    _lastCommitted = widget.line.description;
    _textController = TextEditingController(text: widget.line.description);
    _focusNode = FocusNode()..addListener(_commitOnBlur);
  }

  @override
  void didUpdateWidget(covariant _InventoryDescriptionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus &&
        widget.line.description != _textController.text) {
      _lastCommitted = widget.line.description;
      _textController.value = TextEditingValue(
        text: widget.line.description,
        selection: TextSelection.collapsed(
          offset: widget.line.description.length,
        ),
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
    widget.controller.updateLine(
      widget.line.id,
      (current) => current.copyWith(description: value),
    );
  }

  Future<Iterable<YorksV1MaterialRequestInventorySuggestion>> _options(
    TextEditingValue value,
  ) async {
    final query = value.text.trim();
    final projectId = widget.projectId?.trim();
    if (!widget.enabled ||
        projectId == null ||
        projectId.isEmpty ||
        query.length < 2) {
      return const <YorksV1MaterialRequestInventorySuggestion>[];
    }
    try {
      return await ref.read(
        yorksV1MaterialRequestInventorySearchProvider(
          YorksV1MaterialRequestInventorySearchKey(
            projectId: projectId,
            query: query,
          ),
        ).future,
      );
    } catch (_) {
      return const <YorksV1MaterialRequestInventorySuggestion>[];
    }
  }

  void _select(YorksV1MaterialRequestInventorySuggestion suggestion) {
    _lastCommitted = suggestion.description;
    widget.controller.updateLine(
      widget.line.id,
      (current) => current.copyWith(
        description: suggestion.description,
        brandOrigin: suggestion.brandOrigin,
        size: suggestion.size,
        model: suggestion.model,
        unit: suggestion.unit,
      ),
    );
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
  Widget build(BuildContext context) =>
      RawAutocomplete<YorksV1MaterialRequestInventorySuggestion>(
        textEditingController: _textController,
        focusNode: _focusNode,
        displayStringForOption: (option) => option.description,
        optionsBuilder: _options,
        onSelected: _select,
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
            TextFormField(
              key: ValueKey('${widget.line.id}-description'),
              controller: controller,
              focusNode: focusNode,
              enabled: widget.enabled,
              textCapitalization: TextCapitalization.sentences,
              onFieldSubmitted: (_) {
                _commit();
                onFieldSubmitted();
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: YorksV1MaterialRequestStrings.itemDescription.primary,
                suffixIcon: widget.enabled && widget.projectId != null
                    ? const Icon(
                        Icons.search_rounded,
                        size: 17,
                        color: AppColors.muted,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 9,
                ),
              ),
            ),
        optionsViewBuilder: (context, onSelected, options) {
          final values = options.toList(growable: false);
          return Align(
            alignment: AlignmentDirectional.topStart,
            child: Material(
              elevation: 8,
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 440,
                  maxHeight: 280,
                ),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: values.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = values[index];
                    final details = <String>[
                      ?item.size,
                      ?item.model,
                      ?item.brandOrigin,
                      item.unit,
                    ].join(' · ');
                    return ListTile(
                      dense: true,
                      minTileHeight: AppSpacing.minTapTarget,
                      leading: const Icon(
                        Icons.inventory_2_outlined,
                        size: 19,
                        color: AppColors.blue,
                      ),
                      title: Text(
                        item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onSelected(item),
                    );
                  },
                ),
              ),
            ),
          );
        },
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
    required this.onSearchInventory,
  });

  final YorksV1MaterialRequestLine line;
  final YorksV1MaterialRequestDraftController controller;
  final bool enabled;
  final VoidCallback? onSearchInventory;

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
        if (enabled && onSearchInventory != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onSearchInventory,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Text(
                YorksV1MaterialRequestStrings.searchInventory.primary,
              ),
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
                initialValue: yorksV1DisplayQuantity(line.quantity),
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
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.blue, width: 2),
      ),
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
    final featureFlags = ref.watch(yorksV1FeatureFlagsProvider);
    final arrangementEnabled = featureFlags.arrangement;
    final logisticsEnabled = featureFlags.logistics;
    final returnsDocumentsEnabled = featureFlags.returnsDocuments;
    final fileService = ref.watch(yorksV1BoqWorkbookFileServiceProvider);
    final documentService = YorksV1MaterialRequestDocumentService();
    final AsyncValue<YorksV1ArrangementWorkspace?> arrangement =
        arrangementEnabled
        ? ref.watch(yorksV1ArrangementWorkspaceProvider(request.id))
        : const AsyncData(null);
    // These are role-safe server projections.  The client uses their action
    // flags to choose the correct hand-off in the record header; it never
    // treats the local role label as authority for dispatch, receipt or DO.
    final logisticsWorkspace = logisticsEnabled
        ? ref.watch(yorksV1LogisticsWorkspaceProvider(request.id)).valueOrNull
        : null;
    final returnsDocumentsWorkspace = returnsDocumentsEnabled
        ? ref
              .watch(yorksV1ReturnsDocumentsWorkspaceProvider(request.id))
              .valueOrNull
        : null;
    final documentModel = ref.watch(
      yorksV1MaterialRequestDocumentProvider(request.id),
    );
    final desktop =
        MediaQuery.sizeOf(context).width >= AppSpacing.yorksV1DesktopBreakpoint;
    final isProcurement =
        role == YorksV1Role.procurement || role == YorksV1Role.admin;
    final canArrange =
        arrangementEnabled &&
        isProcurement &&
        (request.state == YorksV1MaterialRequestState.approvedForArrangement ||
            request.state == YorksV1MaterialRequestState.arranging);
    // Cancellation is a Project Engineer/Admin command. A Site Engineer who
    // also holds a Project Engineer membership is authorized by the server,
    // but the role-safe request projection does not expose that composite
    // capability yet, so do not surface an action that can be rejected.
    final canCancel =
        ((role?.isGlobalProjectEngineer ?? false) ||
            role == YorksV1Role.projectEngineer ||
            role == YorksV1Role.admin) &&
        (request.state == YorksV1MaterialRequestState.submitted ||
            request.state ==
                YorksV1MaterialRequestState.awaitingRequestApproval ||
            request.state == YorksV1MaterialRequestState.changesRequested ||
            request.state ==
                YorksV1MaterialRequestState.approvedForArrangement ||
            request.state == YorksV1MaterialRequestState.arranging ||
            request.state == YorksV1MaterialRequestState.awaitingApproval ||
            request.state == YorksV1MaterialRequestState.approved);
    final canOpenLogistics =
        logisticsEnabled &&
        request.state != YorksV1MaterialRequestState.draft &&
        request.state != YorksV1MaterialRequestState.submitted &&
        request.state != YorksV1MaterialRequestState.awaitingRequestApproval &&
        request.state != YorksV1MaterialRequestState.changesRequested &&
        request.state != YorksV1MaterialRequestState.approvedForArrangement &&
        request.state != YorksV1MaterialRequestState.cancelled;
    final canOpenReturnsDocuments =
        returnsDocumentsEnabled &&
        request.state != YorksV1MaterialRequestState.draft &&
        request.state != YorksV1MaterialRequestState.cancelled;
    final arrangementWorkspace = arrangement.valueOrNull;
    final arrangementForApproval = featureFlags.legacyArrangementReview
        ? arrangementWorkspace?.currentArrangement
        : null;
    final receiptDispatch = _firstReceiptDispatch(logisticsWorkspace);
    final deliveryOrderDispatch = _firstDeliveryOrderDispatch(
      returnsDocumentsWorkspace,
    );
    final canGenerateDeliveryOrder = deliveryOrderDispatch != null;
    final canClose = yorksV1CanOfferMaterialRequestClose(
      state: request.state,
      role: role,
    );
    final onGenerateDeliveryOrder =
        returnsDocumentsWorkspace != null && deliveryOrderDispatch != null
        ? () => _generateDeliveryOrder(
            context,
            ref,
            request,
            returnsDocumentsWorkspace,
            deliveryOrderDispatch,
          )
        : null;
    final onReviewReceipt =
        logisticsWorkspace == null || receiptDispatch == null
        ? null
        : () => _reviewReceipt(
            context,
            ref,
            request,
            logisticsWorkspace,
            receiptDispatch,
          );
    final primaryAction = yorksV1MaterialRequestDetailPrimaryAction(
      state: request.state,
      role: role,
      canArrange:
          canArrange &&
          arrangementWorkspace != null &&
          (arrangementWorkspace.canBegin || arrangementWorkspace.canSave),
      canDispatch: logisticsWorkspace?.canDispatch == true,
      canConfirmReceipt: receiptDispatch != null,
      canGenerateDeliveryOrder: canGenerateDeliveryOrder,
      canClose: canClose,
    );
    final onPrimaryAction = switch (primaryAction) {
      YorksV1MaterialRequestDetailPrimaryAction.arrange =>
        () => _openArrangement(context, ref, request.id, arrangementWorkspace),
      YorksV1MaterialRequestDetailPrimaryAction.dispatch => () => context.push(
        RoutePaths.yorksV1MaterialRequestLogisticsPath(request.id),
      ),
      YorksV1MaterialRequestDetailPrimaryAction.receiptReview =>
        onReviewReceipt,
      YorksV1MaterialRequestDetailPrimaryAction.close => () => _close(
        context,
        ref,
        request,
      ),
      YorksV1MaterialRequestDetailPrimaryAction.generateDeliveryOrder =>
        onGenerateDeliveryOrder,
      null => null,
    };
    final Widget? approvalActions =
        request.canDecideRequest || request.canEditBeforeApproval
        ? _RequestApprovalActions(request: request)
        : featureFlags.legacyArrangementReview &&
              arrangementWorkspace?.canDecide == true &&
              arrangementForApproval != null
        ? _RequestArrangementApprovalActions(
            workspace: arrangementWorkspace!,
            arrangement: arrangementForApproval,
          )
        : null;
    if (YorksMobileUi.isActive(context)) {
      return _MobileMaterialRequestLifecycle(
        request: request,
        primaryAction: primaryAction,
        onPrimaryAction: onPrimaryAction,
        onRefresh: onRefresh,
        approvalActions: approvalActions,
        onCancel: canCancel ? () => _cancel(context, ref, request) : null,
        onOpenLogistics: canOpenLogistics
            ? () => context.push(
                RoutePaths.yorksV1MaterialRequestLogisticsPath(request.id),
              )
            : null,
        onOpenDocuments: canOpenReturnsDocuments
            ? () => context.push(
                RoutePaths.yorksV1MaterialRequestReturnsDocumentsPath(
                  request.id,
                ),
              )
            : null,
        documentModel: documentModel,
        onPdf: documentModel.valueOrNull == null
            ? null
            : () =>
                  documentService.shareDocumentPdf(documentModel.valueOrNull!),
        onPrint: documentModel.valueOrNull == null
            ? null
            : () =>
                  documentService.printDocumentPdf(documentModel.valueOrNull!),
      );
    }
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
                  onRefresh: onRefresh,
                  primaryAction: primaryAction,
                  onPrimaryAction: onPrimaryAction,
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
                  approvalActions: approvalActions,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (desktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _RequestRecordContent(
                              request: request,
                              language: language,
                              arrangement: arrangement,
                              documentModel: documentModel,
                              canOpenLogistics: canOpenLogistics,
                              canOpenReturnsDocuments: canOpenReturnsDocuments,
                              logisticsWorkspace: logisticsWorkspace,
                              returnsDocumentsWorkspace:
                                  returnsDocumentsWorkspace,
                              onReviewReceipt: logisticsWorkspace == null
                                  ? null
                                  : (dispatch) => _reviewReceipt(
                                      context,
                                      ref,
                                      request,
                                      logisticsWorkspace,
                                      dispatch,
                                    ),
                              onGenerateDeliveryOrder:
                                  returnsDocumentsWorkspace == null
                                  ? null
                                  : (dispatch) => _generateDeliveryOrder(
                                      context,
                                      ref,
                                      request,
                                      returnsDocumentsWorkspace,
                                      dispatch,
                                    ),
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
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          SizedBox(
                            width: 372,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _RequestWorkflowCard(
                                  request: request,
                                  language: language,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                _RequestDetailsRail(
                                  request: request,
                                  language: language,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                _MaterialRequestDiscussion(
                                  request: request,
                                  compact: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _RequestWorkflowCard(
                            request: request,
                            language: language,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _RequestDetailsRail(
                            request: request,
                            language: language,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _RequestRecordContent(
                            request: request,
                            language: language,
                            arrangement: arrangement,
                            documentModel: documentModel,
                            canOpenLogistics: canOpenLogistics,
                            canOpenReturnsDocuments: canOpenReturnsDocuments,
                            logisticsWorkspace: logisticsWorkspace,
                            returnsDocumentsWorkspace:
                                returnsDocumentsWorkspace,
                            onReviewReceipt: logisticsWorkspace == null
                                ? null
                                : (dispatch) => _reviewReceipt(
                                    context,
                                    ref,
                                    request,
                                    logisticsWorkspace,
                                    dispatch,
                                  ),
                            onGenerateDeliveryOrder:
                                returnsDocumentsWorkspace == null
                                ? null
                                : (dispatch) => _generateDeliveryOrder(
                                    context,
                                    ref,
                                    request,
                                    returnsDocumentsWorkspace,
                                    dispatch,
                                  ),
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
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _MaterialRequestDiscussion(
                            request: request,
                            compact: true,
                          ),
                        ],
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

  Future<void> _openArrangement(
    BuildContext context,
    WidgetRef ref,
    String requestId,
    YorksV1ArrangementWorkspace? workspace,
  ) async {
    // Entering an arrangement is an explicit server command.  Start the first
    // version here so the Arrange action opens the editor directly, rather
    // than exposing a second, visually unrelated start screen.  The trusted
    // RPC remains the authority for the state transition and idempotency.
    if (workspace?.canBegin == true && workspace?.workingArrangement == null) {
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        await ref
            .read(yorksV1MaterialWorkflowCommandControllerProvider)
            .beginArrangement(
              YorksV1BeginArrangementInput(
                requestId: requestId,
                expectedRequestVersion: workspace!.requestRecordVersion,
                idempotencyKey: const Uuid().v4(),
              ),
            );
        ref.invalidate(yorksV1ArrangementWorkspaceProvider(requestId));
        ref.invalidate(yorksV1MaterialRequestDetailProvider(requestId));
        ref.invalidate(yorksV1MaterialRequestListProvider);
      } on YorksV1DomainException catch (error) {
        if (context.mounted) {
          _snack(
            context,
            YorksV1MaterialRequestStrings.commandFailure(error.code).primary,
          );
        }
        return;
      } catch (_) {
        if (context.mounted) {
          _snack(context, YorksV1ArrangementStrings.savingFailed.primary);
        }
        return;
      } finally {
        if (rootNavigator.canPop()) rootNavigator.pop();
      }
    }
    if (!context.mounted) return;
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
            height: (size.height - AppSpacing.colossal * 2)
                .clamp(520.0, 820.0)
                .toDouble(),
            child: YorksV1ArrangementScreen(
              requestId: requestId,
              embedded: true,
              onClose: () => Navigator.of(dialogContext).pop(),
              onCompleted: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        );
      },
    );
  }

  YorksV1MaterialDispatch? _firstReceiptDispatch(
    YorksV1LogisticsWorkspace? workspace,
  ) {
    if (workspace == null || !workspace.canConfirmReceipt) return null;
    for (final dispatch in workspace.dispatches) {
      if (dispatch.canConfirmReceipt) return dispatch;
    }
    return null;
  }

  YorksV1DeliveryOrderDispatch? _firstDeliveryOrderDispatch(
    YorksV1ReturnsDocumentsWorkspace? workspace,
  ) {
    if (workspace == null || !workspace.canGenerateDeliveryOrder) return null;
    for (final dispatch in workspace.deliveryOrderDispatches) {
      if (dispatch.canGenerate) return dispatch;
    }
    return null;
  }

  Future<void> _reviewReceipt(
    BuildContext context,
    WidgetRef ref,
    YorksV1MaterialRequest request,
    YorksV1LogisticsWorkspace workspace,
    YorksV1MaterialDispatch dispatch,
  ) async {
    final changed = await showYorksV1ReceiptReviewDialog(
      context,
      workspace: workspace,
      dispatch: dispatch,
      onChanged: () => _refreshWorkflow(ref, request),
    );
    if (changed == true) _refreshWorkflow(ref, request);
  }

  Future<void> _generateDeliveryOrder(
    BuildContext context,
    WidgetRef ref,
    YorksV1MaterialRequest request,
    YorksV1ReturnsDocumentsWorkspace workspace,
    YorksV1DeliveryOrderDispatch dispatch,
  ) async {
    final changed = await showYorksV1DeliveryOrderGenerationDialog(
      context,
      workspace: workspace,
      dispatch: dispatch,
      documents: const YorksV1LogisticsDocumentService(),
    );
    if (changed == true) _refreshWorkflow(ref, request);
  }

  void _refreshWorkflow(WidgetRef ref, YorksV1MaterialRequest request) {
    ref.invalidate(yorksV1MaterialRequestDetailProvider(request.id));
    ref.invalidate(yorksV1MaterialRequestDocumentProvider(request.id));
    ref.invalidate(yorksV1ArrangementWorkspaceProvider(request.id));
    ref.invalidate(yorksV1LogisticsWorkspaceProvider(request.id));
    ref.invalidate(yorksV1ReturnsDocumentsWorkspaceProvider(request.id));
    ref.invalidate(yorksV1MaterialRequestListProvider(null));
    ref.invalidate(yorksV1MaterialRequestListProvider(request.projectId));
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
          .read(yorksV1MaterialWorkflowCommandControllerProvider)
          .cancelMaterialRequest(
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
    } on YorksV1DomainException catch (error) {
      if (context.mounted) {
        _snack(
          context,
          YorksV1MaterialRequestStrings.commandFailure(error.code).primary,
        );
      }
    } catch (_) {
      if (context.mounted) {
        _snack(context, YorksV1MaterialRequestStrings.saveFailed.primary);
      }
    }
  }

  Future<void> _close(
    BuildContext context,
    WidgetRef ref,
    YorksV1MaterialRequest request,
  ) async {
    try {
      await ref
          .read(yorksV1MaterialWorkflowCommandControllerProvider)
          .closeMaterialRequest(
            YorksV1CloseMaterialRequestInput(
              requestId: request.id,
              expectedVersion: request.recordVersion,
              idempotencyKey: '',
            ),
          );
      if (!context.mounted) return;
      _refreshWorkflow(ref, request);
      _snack(context, YorksV1MaterialRequestStrings.requestClosed.primary);
    } on YorksV1DomainException catch (error) {
      if (context.mounted) {
        _snack(
          context,
          YorksV1MaterialRequestStrings.commandFailure(error.code).primary,
        );
      }
    } catch (_) {
      if (context.mounted) {
        _snack(context, YorksV1MaterialRequestStrings.saveFailed.primary);
      }
    }
  }
}

/// Compact lifecycle surface for a committed request.  It intentionally uses
/// only the role-safe request projection and the already-resolved existing
/// command callbacks supplied by [_RequestDetailBody].
class _MobileMaterialRequestLifecycle extends StatelessWidget {
  const _MobileMaterialRequestLifecycle({
    required this.request,
    required this.primaryAction,
    required this.onPrimaryAction,
    required this.onRefresh,
    required this.approvalActions,
    required this.onCancel,
    required this.onOpenLogistics,
    required this.onOpenDocuments,
    required this.documentModel,
    required this.onPdf,
    required this.onPrint,
  });

  final YorksV1MaterialRequest request;
  final YorksV1MaterialRequestDetailPrimaryAction? primaryAction;
  final VoidCallback? onPrimaryAction;
  final VoidCallback onRefresh;
  final Widget? approvalActions;
  final VoidCallback? onCancel;
  final VoidCallback? onOpenLogistics;
  final VoidCallback? onOpenDocuments;
  final AsyncValue<YorksV1MaterialRequestDocumentModel> documentModel;
  final VoidCallback? onPdf;
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context) {
    final title =
        request.requestNumber ??
        YorksV1MaterialRequestStrings.materialRequest.primary;
    final requestTitle = request.title?.trim();
    final displayedTitle = requestTitle == null || requestTitle.isEmpty
        ? title
        : '$title · $requestTitle';
    final controlledModel = documentModel.valueOrNull;
    final (actionLabel, actionIcon) = _primaryActionCopy(primaryAction);
    return Scaffold(
      backgroundColor: AppColors.mobileSurface,
      body: ColoredBox(
        color: AppColors.mobileSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            YorksMobileAppBar(
              title: title,
              leading: YorksMobileIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(RoutePaths.yorksV1MaterialRequests),
              ),
              trailing: YorksMobileIconButton(
                icon: Icons.refresh_rounded,
                tooltip: YorksV1MaterialRequestStrings.refresh.primary,
                onPressed: onRefresh,
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('mobile-mr-lifecycle'),
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 104),
                children: [
                  Text(
                    request.projectReference.toUpperCase(),
                    style: AppTypography.eyebrow.copyWith(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayedTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headlineMedium.copyWith(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${request.scopeName} · ${request.requesterDisplayName ?? YorksV1MaterialRequestStrings.requester.primary}'
                    '${_mobileRequesterRole(request)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  YorksMobileCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    YorksV1MaterialRequestStrings
                                        .requestStatus
                                        .primary,
                                    style: AppTypography.labelMedium.copyWith(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    yorksV1MaterialRequestStateCopy(
                                      request.state,
                                    ).primary,
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _MobileRequestStateChip(request: request),
                          ],
                        ),
                        const Divider(height: 22),
                        _MobileMrFact(
                          label: YorksV1MaterialRequestStrings
                              .currentOwner
                              .primary,
                          value: _mobileOwner(request),
                        ),
                        _MobileMrFact(
                          label:
                              YorksV1MaterialRequestStrings.nextAction.primary,
                          value: _mobileNextAction(request),
                          last: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  YorksMobileSectionHeader(
                    title: YorksV1MaterialRequestStrings.items.primary,
                    subtitle: YorksV1MaterialRequestStrings
                        .controlledTableDescription
                        .primary,
                  ),
                  const SizedBox(height: 10),
                  for (
                    var index = 0;
                    index < request.lines.length;
                    index++
                  ) ...[
                    _MobileMrLifecycleLineCard(
                      number: index + 1,
                      line: request.lines[index],
                      lifecycle: controlledModel
                          ?.lineLifecycles[request.lines[index].id],
                    ),
                    if (index != request.lines.length - 1)
                      const SizedBox(height: 10),
                  ],
                  if (controlledModel != null &&
                      (controlledModel.arrangement != null ||
                          controlledModel.approval != null ||
                          controlledModel.dispatch != null)) ...[
                    const SizedBox(height: 14),
                    _MobileMrActorHistory(model: controlledModel),
                  ],
                  const SizedBox(height: 14),
                  YorksMobileSectionHeader(
                    title:
                        YorksV1MaterialRequestStrings.workflowTimeline.primary,
                    subtitle: YorksV1MaterialRequestStrings
                        .requestStatusDescription
                        .primary,
                  ),
                  const SizedBox(height: 10),
                  _MobileMrLifecycleTimeline(request: request),
                  const SizedBox(height: 14),
                  _MaterialRequestDiscussion(request: request, compact: true),
                  const SizedBox(height: 14),
                  YorksMobileSectionHeader(
                    title: YorksV1MaterialRequestStrings.recentActivity.primary,
                  ),
                  const SizedBox(height: 10),
                  YorksMobileCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          yorksV1MaterialRequestStateCopy(
                            request.state,
                          ).primary,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(request.updatedAt.toLocal()),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (approvalActions != null) ...[
                    const SizedBox(height: 14),
                    approvalActions!,
                  ],
                  if (onOpenLogistics != null ||
                      onOpenDocuments != null ||
                      onCancel != null) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (onOpenLogistics != null)
                          OutlinedButton.icon(
                            onPressed: onOpenLogistics,
                            icon: const Icon(
                              Icons.local_shipping_outlined,
                              size: 18,
                            ),
                            label: Text(
                              YorksV1LogisticsStrings
                                  .dispatchAndReceipt
                                  .primary,
                            ),
                          ),
                        if (onOpenDocuments != null)
                          OutlinedButton.icon(
                            onPressed: onOpenDocuments,
                            icon: const Icon(
                              Icons.folder_open_outlined,
                              size: 18,
                            ),
                            label: Text(
                              YorksV1DocumentStrings.documents.primary,
                            ),
                          ),
                        if (onPdf != null)
                          OutlinedButton.icon(
                            onPressed: onPdf,
                            icon: const Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 18,
                            ),
                            label: Text(
                              YorksV1LogisticsStrings.downloadPdf.primary,
                            ),
                          ),
                        if (onPrint != null)
                          OutlinedButton.icon(
                            onPressed: onPrint,
                            icon: const Icon(Icons.print_outlined, size: 18),
                            label: Text(
                              YorksV1LogisticsStrings.printDocument.primary,
                            ),
                          ),
                        if (onCancel != null)
                          OutlinedButton.icon(
                            onPressed: onCancel,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                            ),
                            label: Text(
                              YorksV1MaterialRequestStrings
                                  .cancelRequest
                                  .primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (actionLabel != null && onPrimaryAction != null)
              _MobileMrStickyActions(
                primaryLabel: actionLabel,
                primaryIcon: actionIcon!,
                onPrimary: onPrimaryAction,
              ),
          ],
        ),
      ),
    );
  }

  (String?, IconData?) _primaryActionCopy(
    YorksV1MaterialRequestDetailPrimaryAction? action,
  ) => switch (action) {
    YorksV1MaterialRequestDetailPrimaryAction.arrange => (
      YorksV1MaterialRequestStrings.arrangeItems.primary,
      Icons.inventory_2_outlined,
    ),
    YorksV1MaterialRequestDetailPrimaryAction.dispatch => (
      YorksV1LogisticsStrings.dispatchApprovedItems.primary,
      Icons.local_shipping_outlined,
    ),
    YorksV1MaterialRequestDetailPrimaryAction.receiptReview => (
      YorksV1LogisticsStrings.reviewAndMarkReceived.primary,
      Icons.fact_check_outlined,
    ),
    YorksV1MaterialRequestDetailPrimaryAction.close => (
      YorksV1MaterialRequestStrings.closeRequest.primary,
      Icons.task_alt_outlined,
    ),
    YorksV1MaterialRequestDetailPrimaryAction.generateDeliveryOrder => (
      YorksV1LogisticsStrings.generateDeliveryOrder.primary,
      Icons.receipt_long_outlined,
    ),
    null => (null, null),
  };

  String _mobileOwner(YorksV1MaterialRequest value) {
    final raw = value.currentActionOwnerRole?.trim();
    if (raw == null || raw.isEmpty) {
      return YorksV1MaterialRequestStrings.notProvided.primary;
    }
    return _displayWorkflowRole(raw, AppLanguage.english);
  }

  String _mobileNextAction(YorksV1MaterialRequest value) {
    return _materialRequestNextAction(value);
  }
}

String _mobileRequesterRole(YorksV1MaterialRequest request) {
  final label = YorksV1MaterialRequestDocumentService.requesterRoleLabel(
    request,
  );
  return label.isEmpty ? '' : ' · $label';
}

class _MobileMrLifecycleLineCard extends StatelessWidget {
  const _MobileMrLifecycleLineCard({
    required this.number,
    required this.line,
    required this.lifecycle,
  });

  final int number;
  final YorksV1MaterialRequestLine line;
  final YorksV1MaterialRequestLineLifecycle? lifecycle;

  @override
  Widget build(BuildContext context) {
    final progress = lifecycle;
    final arrangementReason = progress?.arrangementReason;
    final facts = <(String, String)>[
      (
        YorksV1ArrangementStrings.requested.primary,
        '${yorksV1DisplayQuantity(line.quantity)} ${line.unit}',
      ),
      if (progress != null) ...[
        (
          YorksV1ArrangementStrings.arranged.primary,
          '${yorksV1DisplayQuantity(progress.arrangedQuantity)} ${line.unit}',
        ),
        (
          YorksV1MaterialRequestStrings.approved.primary,
          '${yorksV1DisplayQuantity(progress.approvedQuantity)} ${line.unit}',
        ),
        (
          YorksV1LogisticsStrings.dispatched.primary,
          '${yorksV1DisplayQuantity(progress.dispatchedQuantity)} ${line.unit}',
        ),
        (
          YorksV1LogisticsStrings.goodReceived.primary,
          '${yorksV1DisplayQuantity(progress.goodQuantity)} ${line.unit}',
        ),
        (
          yorksV1ReceiptOutcomeCopy(YorksV1ReceiptOutcome.missing).primary,
          '${yorksV1DisplayQuantity(progress.missingQuantity)} ${line.unit}',
        ),
        (
          yorksV1ReceiptOutcomeCopy(YorksV1ReceiptOutcome.damaged).primary,
          '${yorksV1DisplayQuantity(progress.damagedQuantity)} ${line.unit}',
        ),
        (
          YorksV1LogisticsStrings.stillNeeded.primary,
          '${yorksV1DisplayQuantity(progress.remainingApprovedQuantity)} ${line.unit}',
        ),
        if (YorksV1DecimalQuantity.tryParse(
              progress.replacementEligibleQuantity,
            )?.isPositive ==
            true)
          (
            YorksV1LogisticsStrings.replacementEligible.primary,
            '${yorksV1DisplayQuantity(progress.replacementEligibleQuantity)} ${line.unit}',
          ),
      ],
    ];
    return YorksMobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$number.', style: AppTypography.titleSmall),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  line.description,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (progress?.status.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              progress!.status,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              for (final fact in facts)
                SizedBox(
                  width: 142,
                  child: _MobileMrFact(label: fact.$1, value: fact.$2),
                ),
            ],
          ),
          if (arrangementReason != null && arrangementReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${YorksV1ArrangementStrings.reason.primary}: $arrangementReason',
              style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileMrActorHistory extends StatelessWidget {
  const _MobileMrActorHistory({required this.model});

  final YorksV1MaterialRequestDocumentModel model;

  @override
  Widget build(BuildContext context) => YorksMobileCard(
    child: Column(
      children: [
        if (model.arrangement != null)
          _MobileMrActorFact(
            label: YorksV1ArrangementStrings.arrangement.primary,
            actor: model.arrangement!,
          ),
        if (model.approval != null)
          _MobileMrActorFact(
            label: YorksV1MaterialRequestStrings.approved.primary,
            actor: model.approval!,
          ),
        if (model.dispatch != null)
          _MobileMrActorFact(
            label: YorksV1LogisticsStrings.dispatched.primary,
            actor: model.dispatch!,
            last: true,
          ),
      ],
    ),
  );
}

class _MobileMrActorFact extends StatelessWidget {
  const _MobileMrActorFact({
    required this.label,
    required this.actor,
    this.last = false,
  });

  final String label;
  final YorksV1MaterialRequestDocumentActor actor;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final role = actor.role.isEmpty
        ? ''
        : YorksV1ProjectStrings.roleLabel(actor.role).primary;
    final date = actor.actedAt == null
        ? ''
        : MaterialLocalizations.of(
            context,
          ).formatMediumDate(actor.actedAt!.toLocal());
    final detail = [
      if (role.isNotEmpty) role,
      if (actor.reference.isNotEmpty) actor.reference,
      if (date.isNotEmpty) date,
    ].join(' · ');
    return _MobileMrFact(
      label: label,
      value: detail.isEmpty
          ? actor.displayName
          : '${actor.displayName} · $detail',
      last: last,
    );
  }
}

class _MobileMrLifecycleTimeline extends StatelessWidget {
  const _MobileMrLifecycleTimeline({required this.request});

  final YorksV1MaterialRequest request;

  @override
  Widget build(BuildContext context) {
    final stage = _materialRequestStage(request.state);
    final labels = _materialRequestStageLabels;
    return YorksMobileCard(
      child: Column(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index + 1 <= stage
                            ? AppColors.successContainer
                            : AppColors.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: index + 1 < stage
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: AppColors.success,
                            )
                          : Text(
                              '${index + 1}',
                              style: AppTypography.labelSmall.copyWith(
                                color: index + 1 == stage
                                    ? AppColors.blue
                                    : AppColors.muted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    if (index + 1 < labels.length)
                      Container(
                        width: 1,
                        height: 21,
                        color: index + 1 < stage
                            ? AppColors.success
                            : AppColors.line,
                      ),
                  ],
                ),
                const SizedBox(width: 11),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    labels[index].primary,
                    style: AppTypography.labelLarge.copyWith(
                      color: index + 1 == stage
                          ? AppColors.ink
                          : AppColors.muted,
                      fontWeight: index + 1 == stage ? FontWeight.w800 : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestApprovalActions extends ConsumerStatefulWidget {
  const _RequestApprovalActions({required this.request});

  final YorksV1MaterialRequest request;

  @override
  ConsumerState<_RequestApprovalActions> createState() =>
      _RequestApprovalActionsState();
}

class _RequestApprovalActionsState
    extends ConsumerState<_RequestApprovalActions> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      if (widget.request.canEditBeforeApproval)
        _RecordActionButton(
          label: YorksV1MaterialRequestStrings.editRequest.primary,
          icon: Icons.edit_outlined,
          onPressed: _busy
              ? () {}
              : () => context.push(
                  RoutePaths.yorksV1MaterialRequestDraftPath(
                    widget.request.id,
                    projectId: widget.request.projectId,
                  ),
                ),
        ),
      if (widget.request.canDecideRequest)
        _RecordActionButton(
          label: YorksV1MaterialRequestStrings.approveForProcurement.primary,
          icon: Icons.verified_rounded,
          primary: true,
          onPressed: _busy
              ? () {}
              : () => _decide(YorksV1MaterialRequestReviewDecision.approved),
        ),
      if (widget.request.canDecideRequest)
        _RecordActionButton(
          label: YorksV1MaterialRequestStrings.returnForChanges.primary,
          icon: Icons.reply_rounded,
          onPressed: _busy
              ? () {}
              : () => _decide(YorksV1MaterialRequestReviewDecision.returned),
        ),
    ],
  );

  Future<void> _decide(YorksV1MaterialRequestReviewDecision decision) async {
    String? reason;
    if (decision == YorksV1MaterialRequestReviewDecision.returned) {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        animationStyle: AnimationStyle.noAnimation,
        builder: (dialogContext) => AlertDialog(
          title: Text(YorksV1MaterialRequestStrings.returnForChanges.primary),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: YorksV1ArrangementStrings.returnReason.primary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(YorksV1MaterialRequestStrings.cancel.primary),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.of(dialogContext).pop(value);
              },
              child: Text(
                YorksV1MaterialRequestStrings.returnForChanges.primary,
              ),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        animationStyle: AnimationStyle.noAnimation,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            YorksV1MaterialRequestStrings.approveForProcurement.primary,
          ),
          content: Text(
            YorksV1MaterialRequestStrings.requestApprovalPrompt.primary,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(YorksV1MaterialRequestStrings.cancel.primary),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.verified_rounded),
              label: Text(
                YorksV1MaterialRequestStrings.approveForProcurement.primary,
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(yorksV1MaterialWorkflowCommandControllerProvider)
          .decideMaterialRequest(
            YorksV1DecideMaterialRequestInput(
              requestId: widget.request.id,
              expectedVersion: widget.request.recordVersion,
              decision: decision,
              reason: reason,
              idempotencyKey: const Uuid().v4(),
            ),
          );
      ref.invalidate(yorksV1MaterialRequestDetailProvider(widget.request.id));
      ref.invalidate(yorksV1MaterialRequestListProvider);
    } on YorksV1DomainException catch (error) {
      if (mounted) {
        _snack(
          context,
          YorksV1MaterialRequestStrings.commandFailure(error.code).primary,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _MaterialRequestDiscussion extends ConsumerStatefulWidget {
  const _MaterialRequestDiscussion({
    required this.request,
    this.compact = false,
  });

  final YorksV1MaterialRequest request;
  final bool compact;

  @override
  ConsumerState<_MaterialRequestDiscussion> createState() =>
      _MaterialRequestDiscussionState();
}

class _MaterialRequestDiscussionState
    extends ConsumerState<_MaterialRequestDiscussion> {
  final _commentController = TextEditingController();
  final Set<String> _mentions = {};
  String? _mentionQuery;
  int? _mentionStart;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_updateMentionQuery);
  }

  @override
  void dispose() {
    _commentController.removeListener(_updateMentionQuery);
    _commentController.dispose();
    super.dispose();
  }

  void _updateMentionQuery() {
    final selection = _commentController.selection;
    if (!selection.isValid || !selection.isCollapsed) return;
    final cursor = selection.baseOffset;
    final before = _commentController.text.substring(0, cursor);
    final match = RegExp(
      r'(^|\s)@([\p{L}\p{N}._-]*)$',
      unicode: true,
    ).firstMatch(before);
    final nextQuery = match?.group(2)?.toLowerCase();
    final nextStart = match == null
        ? null
        : match.start + match.group(1)!.length;
    if (nextQuery == _mentionQuery && nextStart == _mentionStart) return;
    setState(() {
      _mentionQuery = nextQuery;
      _mentionStart = nextStart;
    });
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final candidates = ref.watch(
      yorksV1MaterialRequestMentionCandidatesProvider(widget.request.id),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.compact) ...[
          Text(
            YorksV1MaterialRequestStrings.discussion.primary,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            YorksV1MaterialRequestStrings.discussionDescription.primary,
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (widget.request.comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: 34,
                  color: AppColors.muted.withValues(alpha: .6),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  YorksV1MaterialRequestStrings.noComments.primary,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          )
        else
          for (final comment in widget.request.comments) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${comment.authorDisplayName} · ${_displayWorkflowRole(comment.authorExactRole, language)}',
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(comment.body, style: AppTypography.bodyMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(comment.createdAt.toLocal()),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        const Divider(height: AppSpacing.lg),
        candidates.when(
          loading: () => _mentionQuery == null
              ? const SizedBox.shrink()
              : const LinearProgressIndicator(),
          error: (_, _) => const SizedBox.shrink(),
          data: (users) => _MentionSuggestions(
            users: users,
            query: _mentionQuery,
            onSelected: _insertMention,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                minLines: 1,
                maxLines: 4,
                enabled: !_posting,
                decoration: InputDecoration(
                  hintText:
                      YorksV1MaterialRequestStrings.commentComposerHint.primary,
                  prefixIcon: const Icon(
                    Icons.alternate_email_rounded,
                    size: 19,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              tooltip: YorksV1MaterialRequestStrings.postComment.primary,
              onPressed: _posting ? null : _post,
              icon: _posting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 19),
              style: IconButton.styleFrom(
                minimumSize: const Size.square(AppSpacing.minTapTarget),
              ),
            ),
          ],
        ),
        if (_mentions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${_mentions.length} ${YorksV1MaterialRequestStrings.mentionTeammates.primary.toLowerCase()}',
            style: AppTypography.labelSmall.copyWith(color: AppColors.blue),
          ),
        ],
      ],
    );
    return widget.compact
        ? YorksMobileCard(child: content)
        : _R35RequestCard(
            title: YorksV1MaterialRequestStrings.discussion.primary,
            description:
                YorksV1MaterialRequestStrings.discussionDescription.primary,
            child: content,
          );
  }

  void _insertMention(YorksV1MaterialRequestMention user) {
    final start = _mentionStart;
    final selection = _commentController.selection;
    if (start == null || !selection.isValid) return;
    final current = _commentController.text;
    final handle = _mentionHandle(user.displayName);
    final next = current.replaceRange(start, selection.baseOffset, '@$handle ');
    final cursor = start + handle.length + 2;
    _mentions.add(user.authUserId);
    _commentController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: cursor),
    );
    setState(() {
      _mentionQuery = null;
      _mentionStart = null;
    });
  }

  Future<void> _post() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    setState(() => _posting = true);
    try {
      await ref
          .read(yorksV1MaterialWorkflowCommandControllerProvider)
          .addMaterialRequestComment(
            YorksV1AddMaterialRequestCommentInput(
              requestId: widget.request.id,
              body: body,
              mentionedAuthUserIds: _mentions.toList(growable: false),
              idempotencyKey: const Uuid().v4(),
            ),
          );
      _commentController.clear();
      _mentions.clear();
      ref.invalidate(yorksV1MaterialRequestDetailProvider(widget.request.id));
    } on YorksV1DomainException catch (error) {
      if (mounted) {
        _snack(
          context,
          YorksV1MaterialRequestStrings.commandFailure(error.code).primary,
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }
}

String _mentionHandle(String displayName) => displayName
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

class _MentionSuggestions extends StatelessWidget {
  const _MentionSuggestions({
    required this.users,
    required this.query,
    required this.onSelected,
  });

  final List<YorksV1MaterialRequestMention> users;
  final String? query;
  final ValueChanged<YorksV1MaterialRequestMention> onSelected;

  @override
  Widget build(BuildContext context) {
    if (query == null) return const SizedBox.shrink();
    final normalized = query!.toLowerCase();
    final matches = users
        .where((user) {
          final name = user.displayName.toLowerCase();
          return name.contains(normalized) ||
              _mentionHandle(user.displayName).contains(normalized);
        })
        .take(6)
        .toList(growable: false);
    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          YorksV1MaterialRequestStrings.mentionNoMatches.primary,
          style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var index = 0; index < matches.length; index++) ...[
              ListTile(
                dense: true,
                minTileHeight: AppSpacing.minTapTarget,
                leading: CircleAvatar(
                  radius: 15,
                  backgroundColor: AppColors.blueContainer,
                  child: Text(
                    matches[index].displayName.trim().isEmpty
                        ? '@'
                        : matches[index].displayName.trim()[0].toUpperCase(),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(matches[index].displayName),
                subtitle: Text(
                  '@${_mentionHandle(matches[index].displayName)}',
                ),
                onTap: () => onSelected(matches[index]),
              ),
              if (index != matches.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
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
    required this.onRefresh,
    required this.primaryAction,
    required this.onPrimaryAction,
    required this.onExport,
    required this.onPdf,
    required this.onPrint,
    required this.approvalActions,
    required this.onCancel,
  });

  final YorksV1MaterialRequest request;
  final VoidCallback onRefresh;
  final YorksV1MaterialRequestDetailPrimaryAction? primaryAction;
  final VoidCallback? onPrimaryAction;
  final VoidCallback onExport;
  final VoidCallback? onPdf;
  final VoidCallback? onPrint;
  final Widget? approvalActions;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Approval and document actions can be wider than the record canvas
      // after the persistent desktop sidebar is accounted for. Stack before
      // those actions can squeeze the title to a one-character column.
      final compact =
          constraints.maxWidth < (approvalActions == null ? 900 : 1240);
      final title =
          request.requestNumber ??
          YorksV1MaterialRequestStrings.materialRequest.primary;
      final requestTitle = request.title?.trim();
      final heading = KeyedSubtree(
        key: const ValueKey('material-request-record-heading'),
        child: Column(
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
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
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
                _IndustrialStageChip(
                  stage: _materialRequestStage(request.state),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${request.scopeName} · ${request.requesterDisplayName ?? YorksV1MaterialRequestStrings.requester.primary}',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      );
      final actions = Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        alignment: compact ? WrapAlignment.start : WrapAlignment.end,
        children: [
          if (primaryAction != null && onPrimaryAction != null)
            _RequestPrimaryActionButton(
              action: primaryAction!,
              onPressed: onPrimaryAction!,
            ),
          ?approvalActions,
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

/// A stage-specific command stays in one predictable position in the record
/// header.  The label deliberately reflects the next permitted workflow step,
/// rather than a generic workspace name that can be mistaken for an earlier
/// stage (for example, "Procurement arrangement" after approval).
class _RequestPrimaryActionButton extends StatelessWidget {
  const _RequestPrimaryActionButton({
    required this.action,
    required this.onPressed,
  });

  final YorksV1MaterialRequestDetailPrimaryAction action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (action) {
      YorksV1MaterialRequestDetailPrimaryAction.arrange => (
        YorksV1MaterialRequestStrings.arrangeItems.primary,
        Icons.inventory_2_outlined,
      ),
      YorksV1MaterialRequestDetailPrimaryAction.dispatch => (
        YorksV1LogisticsStrings.dispatchApprovedItems.primary,
        Icons.local_shipping_outlined,
      ),
      YorksV1MaterialRequestDetailPrimaryAction.receiptReview => (
        YorksV1LogisticsStrings.reviewAndMarkReceived.primary,
        Icons.fact_check_outlined,
      ),
      YorksV1MaterialRequestDetailPrimaryAction.close => (
        YorksV1MaterialRequestStrings.closeRequest.primary,
        Icons.task_alt_outlined,
      ),
      YorksV1MaterialRequestDetailPrimaryAction.generateDeliveryOrder => (
        YorksV1LogisticsStrings.generateDeliveryOrder.primary,
        Icons.receipt_long_outlined,
      ),
    };
    return _RecordActionButton(
      label: label,
      icon: icon,
      primary: true,
      onPressed: onPressed,
    );
  }
}

/// The primary project engineer reviews the same immutable arrangement shown
/// in the request record. This keeps the next action visible without making
/// the procurement editor writable by an engineer.
class _RequestArrangementApprovalActions extends ConsumerStatefulWidget {
  const _RequestArrangementApprovalActions({
    required this.workspace,
    required this.arrangement,
  });

  final YorksV1ArrangementWorkspace workspace;
  final YorksV1ProcurementArrangement arrangement;

  @override
  ConsumerState<_RequestArrangementApprovalActions> createState() =>
      _RequestArrangementApprovalActionsState();
}

class _RequestArrangementApprovalActionsState
    extends ConsumerState<_RequestArrangementApprovalActions> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      SizedBox(
        height: AppSpacing.minTapTarget,
        child: FilledButton.icon(
          onPressed: _busy ? null : _reviewAndApprove,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_rounded, size: 19),
          label: Text(YorksV1ArrangementStrings.reviewAndApprove.primary),
        ),
      ),
      SizedBox(
        height: AppSpacing.minTapTarget,
        child: OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _decide(YorksV1ArrangementReviewDecision.returned),
          icon: const Icon(Icons.reply_rounded, size: 19),
          label: Text(YorksV1ArrangementStrings.returnToProcurement.primary),
        ),
      ),
    ],
  );

  Future<void> _reviewAndApprove() async {
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: !_busy,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.all(AppSpacing.xl),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1120,
              maxHeight: (size.height - AppSpacing.colossal)
                  .clamp(440.0, 760.0)
                  .toDouble(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              YorksV1ArrangementStrings
                                  .reviewAndApprove
                                  .primary,
                              style: AppTypography.titleLarge.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              '${widget.workspace.requestNumber ?? ''} · ${widget.arrangement.lines.length} ${YorksV1MaterialRequestStrings.items.primary.toLowerCase()}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          dialogContext,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.blueContainer,
                            border: Border.all(
                              color: AppColors.blueContainerStrong,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                          child: Text(
                            YorksV1MaterialRequestStrings
                                .arrangementDescription
                                .primary,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        for (final line in widget.arrangement.lines) ...[
                          _ArrangementApprovalReviewLine(line: line),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(AppStrings.cancel.primary),
                      ),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        icon: const Icon(Icons.verified_rounded, size: 19),
                        label: Text(
                          YorksV1ArrangementStrings.approveArrangement.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (approved == true && mounted) {
      await _decide(YorksV1ArrangementReviewDecision.approved);
    }
  }

  Future<void> _decide(YorksV1ArrangementReviewDecision decision) async {
    String? reason;
    if (decision == YorksV1ArrangementReviewDecision.returned) {
      reason = await _arrangementReturnReason(context);
      if (reason == null || reason.trim().isEmpty) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(yorksV1MaterialWorkflowCommandControllerProvider)
          .decideArrangement(
            YorksV1DecideArrangementInput(
              requestId: widget.workspace.requestId,
              arrangementId: widget.arrangement.id,
              expectedRequestVersion: widget.workspace.requestRecordVersion,
              expectedArrangementVersion: widget.arrangement.recordVersion,
              decision: decision,
              reason: reason,
              idempotencyKey: const Uuid().v4(),
            ),
          );
      ref.invalidate(
        yorksV1ArrangementWorkspaceProvider(widget.workspace.requestId),
      );
      ref.invalidate(
        yorksV1MaterialRequestDetailProvider(widget.workspace.requestId),
      );
      ref.invalidate(yorksV1MaterialRequestListProvider);
      if (mounted) {
        _snack(
          context,
          decision == YorksV1ArrangementReviewDecision.approved
              ? YorksV1ArrangementStrings.approveArrangement.primary
              : YorksV1ArrangementStrings.returnToProcurement.primary,
        );
      }
    } on YorksV1DomainException catch (error) {
      if (mounted) {
        _snack(
          context,
          YorksV1MaterialRequestStrings.commandFailure(error.code).primary,
        );
      }
    } catch (_) {
      if (mounted) {
        _snack(context, YorksV1ArrangementStrings.savingFailed.primary);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ArrangementApprovalReviewLine extends StatelessWidget {
  const _ArrangementApprovalReviewLine({required this.line});

  final YorksV1ArrangementLine line;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: line.decision == YorksV1ArrangementDecision.unavailable
          ? AppColors.errorContainer
          : line.decision == YorksV1ArrangementDecision.partial
          ? AppColors.warningContainer
          : AppColors.surfaceContainerLow,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Builder(
      builder: (_) {
        final facts = [
          _ArrangementApprovalFact(
            YorksV1ArrangementStrings.decision.primary,
            line.decision == null
                ? YorksV1MaterialRequestStrings.notProvided.primary
                : yorksV1ArrangementDecisionCopy(line.decision!).primary,
          ),
          _ArrangementApprovalFact(
            YorksV1ArrangementStrings.source.primary,
            line.source == YorksV1ArrangementSource.externalSupplier
                ? (line.externalSupplier ??
                      YorksV1ArrangementStrings.externalSupplier.primary)
                : YorksV1ArrangementStrings.warehouse.primary,
          ),
          _ArrangementApprovalFact(
            YorksV1ArrangementStrings.requested.primary,
            '${yorksV1DisplayQuantity(line.requestedQuantity)} ${line.unit}',
          ),
          _ArrangementApprovalFact(
            YorksV1ArrangementStrings.arranged.primary,
            '${yorksV1DisplayQuantity(line.arrangedQuantity ?? '0')} ${line.unit}',
          ),
          if (line.reason != null && line.reason!.trim().isNotEmpty)
            _ArrangementApprovalFact(
              YorksV1ArrangementStrings.reason.primary,
              line.reason!,
            ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${line.displayOrder}. ${line.description}',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (line.brandOrigin != null && line.brandOrigin!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                line.brandOrigin!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.sm,
              children: facts,
            ),
          ],
        );
      },
    ),
  );
}

class _ArrangementApprovalFact extends StatelessWidget {
  const _ArrangementApprovalFact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(value, style: AppTypography.bodySmall),
      ],
    ),
  );
}

class _RequestDecisionBanner extends StatelessWidget {
  const _RequestDecisionBanner({required this.request, required this.language});

  final YorksV1MaterialRequest request;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final decision = request.requestDecision;
    final approved = decision?.decision == 'approved';
    final returned = decision?.decision == 'returned';
    final tone = approved
        ? AppColors.success
        : returned
        ? AppColors.error
        : AppColors.blue;
    final background = approved
        ? AppColors.successContainer
        : returned
        ? AppColors.errorContainer
        : AppColors.blueContainer;
    final title = approved
        ? YorksV1MaterialRequestStrings.approvedByEngineer.primary
        : returned
        ? YorksV1MaterialRequestStrings.changesRequested.primary
        : yorksV1MaterialRequestStateCopy(request.state).primary;
    final meta = decision == null
        ? _displayWorkflowRole(request.currentActionOwnerRole, language)
        : [
            decision.decidedByDisplayName,
            _displayWorkflowRole(decision.decidedByExactRole, language),
            MaterialLocalizations.of(
              context,
            ).formatMediumDate(decision.decidedAt.toLocal()),
          ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                approved
                    ? Icons.check_rounded
                    : returned
                    ? Icons.reply_rounded
                    : Icons.schedule_rounded,
                size: 19,
                color: tone,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleSmall.copyWith(
                      color: tone,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    meta,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  if (decision?.reason?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      decision!.reason!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.inkSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const VerticalDivider(width: AppSpacing.xxl),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    YorksV1MaterialRequestStrings.nextAction.primary,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _materialRequestNextAction(request),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestedItemsSurface extends StatelessWidget {
  const _RequestedItemsSurface({required this.request});

  final YorksV1MaterialRequest request;

  @override
  Widget build(BuildContext context) => _R35RecordSurface(
    padding: EdgeInsets.zero,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 920),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: const TableBorder(
              horizontalInside: BorderSide(color: AppColors.line),
              verticalInside: BorderSide(color: AppColors.line),
            ),
            columnWidths: const {
              0: FixedColumnWidth(54),
              1: FlexColumnWidth(2.5),
              2: FlexColumnWidth(1.15),
              3: FlexColumnWidth(1.25),
              4: FlexColumnWidth(1.2),
              5: FixedColumnWidth(105),
              6: FixedColumnWidth(78),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                ),
                children: [
                  _FormalCell(
                    YorksV1MaterialRequestStrings.serialNumber.primary,
                    header: true,
                  ),
                  _FormalCell(
                    YorksV1MaterialRequestStrings.itemDescription.primary,
                    header: true,
                  ),
                  _FormalCell(
                    YorksV1MaterialRequestStrings.size.primary,
                    header: true,
                  ),
                  _FormalCell(
                    YorksV1MaterialRequestStrings.modelSerialNumber.primary,
                    header: true,
                  ),
                  _FormalCell(
                    YorksV1MaterialRequestStrings.brandOrigin.primary,
                    header: true,
                  ),
                  _FormalCell(
                    YorksV1MaterialRequestStrings.quantity.primary,
                    header: true,
                  ),
                  _FormalCell(
                    YorksV1MaterialRequestStrings.unit.primary,
                    header: true,
                  ),
                ],
              ),
              for (var index = 0; index < request.lines.length; index++)
                TableRow(
                  decoration: BoxDecoration(
                    color: index.isEven
                        ? AppColors.surfaceContainerLowest
                        : AppColors.surfaceContainerLow.withValues(alpha: .35),
                  ),
                  children: [
                    _FormalCell('${index + 1}'),
                    _FormalCell(request.lines[index].description),
                    _FormalCell(request.lines[index].size ?? '—'),
                    _FormalCell(
                      request.lines[index].model ??
                          request.lines[index].equipmentTag ??
                          request.lines[index].planningModelTag ??
                          '—',
                    ),
                    _FormalCell(request.lines[index].brandOrigin ?? '—'),
                    _FormalCell(
                      yorksV1DisplayQuantity(request.lines[index].quantity),
                      alignEnd: true,
                    ),
                    _FormalCell(request.lines[index].unit),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RequestRecordContent extends StatelessWidget {
  const _RequestRecordContent({
    required this.request,
    required this.language,
    required this.arrangement,
    required this.documentModel,
    required this.canOpenLogistics,
    required this.canOpenReturnsDocuments,
    required this.logisticsWorkspace,
    required this.returnsDocumentsWorkspace,
    required this.onReviewReceipt,
    required this.onGenerateDeliveryOrder,
    required this.onOpenLogistics,
    required this.onOpenReturns,
  });

  final YorksV1MaterialRequest request;
  final AppLanguage language;
  final AsyncValue<YorksV1ArrangementWorkspace?> arrangement;
  final AsyncValue<YorksV1MaterialRequestDocumentModel> documentModel;
  final bool canOpenLogistics;
  final bool canOpenReturnsDocuments;
  final YorksV1LogisticsWorkspace? logisticsWorkspace;
  final YorksV1ReturnsDocumentsWorkspace? returnsDocumentsWorkspace;
  final ValueChanged<YorksV1MaterialDispatch>? onReviewReceipt;
  final ValueChanged<YorksV1DeliveryOrderDispatch>? onGenerateDeliveryOrder;
  final VoidCallback onOpenLogistics;
  final VoidCallback onOpenReturns;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _RequestDecisionBanner(request: request, language: language),
      const SizedBox(height: AppSpacing.lg),
      _R35RecordSectionHeading(
        title: YorksV1MaterialRequestStrings.materialItems.primary,
        description:
            YorksV1MaterialRequestStrings.controlledTableDescription.primary,
      ),
      const SizedBox(height: AppSpacing.sm),
      _RequestedItemsSurface(request: request),
      const SizedBox(height: AppSpacing.lg),
      _R35RecordSurface(
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            leading: const Icon(
              Icons.description_outlined,
              color: AppColors.blue,
            ),
            title: Text(
              YorksV1MaterialRequestStrings.materialRequest.primary,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              YorksV1MaterialRequestStrings
                  .controlledDocumentDescription
                  .primary,
              style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
            ),
            children: [
              _ControlledRequestPreview(
                request: request,
                documentModel: documentModel,
              ),
            ],
          ),
        ),
      ),
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
      _DispatchReceiptSummarySurface(
        request: request,
        workspace: logisticsWorkspace,
        canOpenLogistics: canOpenLogistics,
        onOpenLogistics: onOpenLogistics,
        onReviewReceipt: onReviewReceipt,
      ),
      const SizedBox(height: AppSpacing.xxl),
      _R35RecordSectionHeading(
        title: YorksV1LogisticsStrings.deliveryOrdersAndReturns.primary,
        description: YorksV1MaterialRequestStrings.returnsDescription.primary,
      ),
      const SizedBox(height: AppSpacing.sm),
      _DeliveryOrderSummarySurface(
        request: request,
        workspace: returnsDocumentsWorkspace,
        canOpenReturnsDocuments: canOpenReturnsDocuments,
        onGenerateDeliveryOrder: onGenerateDeliveryOrder,
        onOpenReturns: onOpenReturns,
      ),
    ],
  );
}

class _DispatchReceiptSummarySurface extends StatelessWidget {
  const _DispatchReceiptSummarySurface({
    required this.request,
    required this.workspace,
    required this.canOpenLogistics,
    required this.onOpenLogistics,
    required this.onReviewReceipt,
  });

  final YorksV1MaterialRequest request;
  final YorksV1LogisticsWorkspace? workspace;
  final bool canOpenLogistics;
  final VoidCallback onOpenLogistics;
  final ValueChanged<YorksV1MaterialDispatch>? onReviewReceipt;

  @override
  Widget build(BuildContext context) {
    final dispatches =
        workspace?.dispatches ?? const <YorksV1MaterialDispatch>[];
    if (dispatches.isEmpty) {
      final ready =
          request.state == YorksV1MaterialRequestState.approved ||
          request.state == YorksV1MaterialRequestState.partiallyDispatched;
      return _PendingWorkflowSurface(
        icon: Icons.local_shipping_outlined,
        title: ready
            ? YorksV1MaterialRequestStrings.readyForDispatch.primary
            : YorksV1MaterialRequestStrings.noDispatchYet.primary,
        description: ready
            ? YorksV1MaterialRequestStrings.dispatchReadyDescription.primary
            : YorksV1MaterialRequestStrings.dispatchPendingDescription.primary,
        action: canOpenLogistics
            ? _RecordActionButton(
                label: YorksV1LogisticsStrings.dispatchAndReceipt.primary,
                icon: Icons.local_shipping_outlined,
                onPressed: onOpenLogistics,
              )
            : null,
      );
    }
    return _R35RecordSurface(
      child: Column(
        children: [
          for (var index = 0; index < dispatches.length; index++) ...[
            _DispatchReceiptRow(
              dispatch: dispatches[index],
              onReviewReceipt:
                  dispatches[index].canConfirmReceipt && onReviewReceipt != null
                  ? () => onReviewReceipt!(dispatches[index])
                  : null,
            ),
            if (index != dispatches.length - 1)
              const Divider(height: AppSpacing.xxl),
          ],
        ],
      ),
    );
  }
}

class _DispatchReceiptRow extends StatelessWidget {
  const _DispatchReceiptRow({required this.dispatch, this.onReviewReceipt});

  final YorksV1MaterialDispatch dispatch;
  final VoidCallback? onReviewReceipt;

  @override
  Widget build(BuildContext context) {
    final role = dispatch.dispatchedByRole == null
        ? null
        : YorksV1ProjectStrings.roleLabel(dispatch.dispatchedByRole!).primary;
    final meta = [
      yorksV1DispatchStateCopy(dispatch.state).primary,
      dispatch.dispatchedByDisplayName,
      if (role != null && role.isNotEmpty) role,
      if (dispatch.deliveryReference != null) dispatch.deliveryReference!,
      MaterialLocalizations.of(
        context,
      ).formatMediumDate(dispatch.dispatchedAt.toLocal()),
    ].join(' · ');
    return Row(
      children: [
        const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dispatch.number, style: AppTypography.titleSmall),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                meta,
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        if (onReviewReceipt != null)
          _RecordActionButton(
            label: YorksV1LogisticsStrings.reviewAndMarkReceived.primary,
            icon: Icons.fact_check_outlined,
            onPressed: onReviewReceipt!,
            primary: true,
          ),
      ],
    );
  }
}

class _DeliveryOrderSummarySurface extends StatelessWidget {
  const _DeliveryOrderSummarySurface({
    required this.request,
    required this.workspace,
    required this.canOpenReturnsDocuments,
    required this.onGenerateDeliveryOrder,
    required this.onOpenReturns,
  });

  final YorksV1MaterialRequest request;
  final YorksV1ReturnsDocumentsWorkspace? workspace;
  final bool canOpenReturnsDocuments;
  final ValueChanged<YorksV1DeliveryOrderDispatch>? onGenerateDeliveryOrder;
  final VoidCallback onOpenReturns;

  bool get _receiptReviewed =>
      request.state == YorksV1MaterialRequestState.partiallyReceived ||
      request.state == YorksV1MaterialRequestState.received ||
      request.state == YorksV1MaterialRequestState.closed;

  @override
  Widget build(BuildContext context) {
    final dispatches =
        workspace?.deliveryOrderDispatches ??
        const <YorksV1DeliveryOrderDispatch>[];
    if (dispatches.isEmpty) {
      return _PendingWorkflowSurface(
        icon: _receiptReviewed
            ? Icons.receipt_long_outlined
            : Icons.assignment_return_outlined,
        title: _receiptReviewed
            ? YorksV1LogisticsStrings.deliveryOrderTitle.primary
            : YorksV1MaterialRequestStrings.noReturnedMaterial.primary,
        description: _receiptReviewed
            ? YorksV1MaterialRequestStrings.deliveryOrderAfterReceipt.primary
            : YorksV1MaterialRequestStrings.returnAfterReceipt.primary,
        action: _fallbackAction(),
      );
    }
    return _R35RecordSurface(
      child: Column(
        children: [
          for (var index = 0; index < dispatches.length; index++) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final dispatch = dispatches[index];
                final action =
                    dispatch.canGenerate && onGenerateDeliveryOrder != null
                    ? _RecordActionButton(
                        label: YorksV1LogisticsStrings
                            .generateDeliveryOrder
                            .primary,
                        icon: Icons.receipt_long_outlined,
                        onPressed: () => onGenerateDeliveryOrder!(dispatch),
                        primary: true,
                      )
                    : null;
                final summary = Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dispatch.deliveryOrder?.reference ??
                                dispatch.dispatchNumber,
                            style: AppTypography.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            dispatch.deliveryOrder == null
                                ? YorksV1MaterialRequestStrings
                                      .deliveryOrderAfterReceipt
                                      .primary
                                : YorksV1LogisticsStrings.deliveryOrder.primary,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                if (constraints.maxWidth < 560 && action != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summary,
                      const SizedBox(height: AppSpacing.md),
                      Align(alignment: Alignment.centerLeft, child: action),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: summary),
                    if (action != null) ...[
                      const SizedBox(width: AppSpacing.md),
                      action,
                    ],
                  ],
                );
              },
            ),
            if (index != dispatches.length - 1)
              const Divider(height: AppSpacing.xxl),
          ],
        ],
      ),
    );
  }

  Widget? _fallbackAction() {
    if (!canOpenReturnsDocuments) return null;
    return _RecordActionButton(
      label: YorksV1LogisticsStrings.deliveryOrdersAndReturns.primary,
      icon: Icons.assignment_return_outlined,
      onPressed: onOpenReturns,
    );
  }
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
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

String _displayWorkflowRole(String? value, AppLanguage language) {
  final role = value?.trim();
  if (role == null || role.isEmpty) return '—';
  return YorksV1ProjectStrings.roleLabel(role).active(language);
}

class _RequestWorkflowCard extends StatelessWidget {
  const _RequestWorkflowCard({required this.request, required this.language});

  final YorksV1MaterialRequest request;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final stage = _materialRequestStage(request.state);
    return _R35RecordSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.account_tree_outlined,
                        size: 19,
                        color: AppColors.blue,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          YorksV1MaterialRequestStrings.requestStatus.primary,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
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
          _IndustrialWorkflowStrip(stage: stage, condensed: true),
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
                  '${YorksV1MaterialRequestStrings.currentOwner.primary}: ${_displayWorkflowRole(request.currentActionOwnerRole, language)}',
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

  String _ownerHeading(YorksV1MaterialRequest value) => switch (value.state) {
    YorksV1MaterialRequestState.submitted ||
    YorksV1MaterialRequestState.awaitingRequestApproval =>
      YorksV1MaterialRequestStrings.awaitingRequestApproval.primary,
    YorksV1MaterialRequestState.changesRequested =>
      YorksV1MaterialRequestStrings.changesRequested.primary,
    YorksV1MaterialRequestState.approvedForArrangement ||
    YorksV1MaterialRequestState.arranging =>
      YorksV1MaterialRequestStrings.procurementArranging.primary,
    YorksV1MaterialRequestState.awaitingApproval =>
      YorksV1MaterialRequestStrings.waitingForApproval.primary,
    YorksV1MaterialRequestState.approved =>
      YorksV1MaterialRequestStrings.readyForDispatch.primary,
    YorksV1MaterialRequestState.partiallyDispatched ||
    YorksV1MaterialRequestState.dispatched =>
      YorksV1MaterialRequestStrings.awaitingReceipt.primary,
    YorksV1MaterialRequestState.partiallyReceived =>
      request.currentActionCode == 'receipt_review_required'
          ? YorksV1MaterialRequestStrings.awaitingReceipt.primary
          : YorksV1MaterialRequestStrings.replacementDispatchRequired.primary,
    YorksV1MaterialRequestState.received =>
      YorksV1MaterialRequestStrings.closeReviewRequired.primary,
    YorksV1MaterialRequestState.closed =>
      YorksV1MaterialRequestStrings.receiptCompleted.primary,
    YorksV1MaterialRequestState.draft =>
      YorksV1MaterialRequestStrings.draftPrivate.primary,
    YorksV1MaterialRequestState.cancelled =>
      YorksV1MaterialRequestStrings.cancelled.primary,
  };
}

class _RequestDetailsRail extends StatelessWidget {
  const _RequestDetailsRail({required this.request, required this.language});

  final YorksV1MaterialRequest request;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => _R35RecordSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.assignment_outlined,
              size: 19,
              color: AppColors.blue,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                YorksV1MaterialRequestStrings.requestDetails.primary,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
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
          value: _displayWorkflowRole(
            request.requesterExactRole ?? request.requesterProjectRole,
            language,
          ),
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
          value: _displayWorkflowRole(request.currentActionOwnerRole, language),
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
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
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
                          '${yorksV1DisplayQuantity(line.requestedQuantity)} ${line.unit}',
                          alignEnd: true,
                        ),
                        _FormalCell(
                          '${yorksV1DisplayQuantity(line.arrangedQuantity ?? '0')} ${line.unit}',
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
              [
                '${current.lines.length} ${YorksV1MaterialRequestStrings.items.primary.toLowerCase()}',
                current.savedByDisplayName ?? current.startedByDisplayName,
                if (current.decidedByDisplayName != null)
                  current.decidedByDisplayName!,
                if (current.decidedByRole != null)
                  YorksV1ProjectStrings.roleLabel(
                    current.decidedByRole,
                  ).primary,
                if (current.decidedAt != null)
                  MaterialLocalizations.of(
                    context,
                  ).formatMediumDate(current.decidedAt!.toLocal()),
              ].join(' · '),
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
  YorksV1MaterialRequestDraft draft, {
  required AppLanguage language,
  String? projectReference,
  String? scopeName,
}) async {
  final scopeId = draft.scopeId;
  final projectId = draft.projectId;
  if (scopeId == null || projectId == null) {
    _snack(context, YorksV1MaterialRequestStrings.selectScopeToAddBoq.primary);
    return;
  }
  final repository = ref.read(yorksV1BoqRepositoryProvider);
  final worksheets = () async {
    final groups = await repository.listGroupsForScope(
      projectId,
      scopeId: scopeId,
    );
    final started =
        groups
            .where(
              (group) =>
                  !group.isArchived &&
                  group.isScopeAssigned &&
                  group.scopeId == scopeId &&
                  group.rowCount > 0,
            )
            .toList(growable: false)
          ..sort(
            (left, right) => left.displayOrder.compareTo(right.displayOrder),
          );
    return Future.wait([
      for (final group in started) repository.getWorksheet(group.id),
    ]);
  }();
  final selected = await showDialog<_BoqPickerSelection>(
    context: context,
    animationStyle: AnimationStyle.noAnimation,
    builder: (context) => _R35BoqItemPickerDialog(
      worksheets: worksheets,
      language: language,
      projectReference: projectReference,
      scopeName: scopeName,
      existingSourceRowIds: draft.lines
          .map((line) => line.sourceBoqRowId)
          .whereType<String>()
          .toSet(),
    ),
  );
  if (selected == null || selected.rowIdsByGroup.isEmpty) return;
  try {
    final loaded = await worksheets;
    for (final worksheet in loaded) {
      final rowIds = selected.rowIdsByGroup[worksheet.group.id];
      if (rowIds == null || rowIds.isEmpty) continue;
      await controller.addBoqRows(worksheet: worksheet, rowIds: rowIds);
    }
  } catch (_) {
    if (context.mounted) {
      _snack(context, YorksV1MaterialRequestStrings.saveFailed.primary);
    }
  }
}

class _BoqPickerSelection {
  const _BoqPickerSelection(this.rowIdsByGroup);

  final Map<String, Set<String>> rowIdsByGroup;
}

class _R35BoqItemPickerDialog extends StatefulWidget {
  const _R35BoqItemPickerDialog({
    required this.worksheets,
    required this.language,
    required this.existingSourceRowIds,
    this.projectReference,
    this.scopeName,
  });

  final Future<List<YorksV1BoqWorksheet>> worksheets;
  final AppLanguage language;
  final Set<String> existingSourceRowIds;
  final String? projectReference;
  final String? scopeName;

  @override
  State<_R35BoqItemPickerDialog> createState() =>
      _R35BoqItemPickerDialogState();
}

class _R35BoqItemPickerDialogState extends State<_R35BoqItemPickerDialog> {
  final Set<String> _selectedRowIds = <String>{};

  String get _scopeName {
    final value = widget.scopeName?.trim();
    return value == null || value.isEmpty
        ? YorksV1MaterialRequestStrings.scope.primary
        : value;
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1160,
          maxHeight: viewport.height - (AppSpacing.lg * 2),
        ),
        child: FutureBuilder<List<YorksV1BoqWorksheet>>(
          future: widget.worksheets,
          builder: (context, snapshot) {
            final worksheets = snapshot.data ?? const <YorksV1BoqWorksheet>[];
            final loading = snapshot.connectionState != ConnectionState.done;
            final failed = snapshot.hasError;
            return PopScope(
              canPop: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _boqPickerHeader(context),
                  const Divider(height: 1),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : failed
                        ? _boqPickerError()
                        : _boqPickerBody(worksheets),
                  ),
                  const Divider(height: 1),
                  _boqPickerFooter(context, enabled: !loading && !failed),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _boqPickerHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                YorksV1MaterialRequestStrings.addItemsFromBoq(
                  _scopeName,
                ).active(widget.language),
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  if (widget.projectReference?.trim().isNotEmpty == true)
                    widget.projectReference!.trim(),
                  _scopeName,
                  YorksV1MaterialRequestStrings.boqScopeOnly.active(
                    widget.language,
                  ),
                ].join(' · '),
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceContainerLow,
            minimumSize: const Size.square(AppSpacing.minTapTarget),
          ),
        ),
      ],
    ),
  );

  Widget _boqPickerBody(List<YorksV1BoqWorksheet> worksheets) {
    final withRows = worksheets
        .where((worksheet) => worksheet.rows.isNotEmpty)
        .toList(growable: false);
    return ListView(
      key: const ValueKey('desktop-mr-boq-picker'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _BoqPickerScopeBanner(scopeName: _scopeName, language: widget.language),
        const SizedBox(height: AppSpacing.md),
        if (withRows.isEmpty)
          _BoqPickerEmptyState(scopeName: _scopeName, language: widget.language)
        else
          for (final worksheet in withRows) ...[
            _BoqPickerWorksheetSection(
              worksheet: worksheet,
              language: widget.language,
              selectedRowIds: _selectedRowIds,
              existingSourceRowIds: widget.existingSourceRowIds,
              onChanged: _setRowSelected,
              onSelectAll: _setWorksheetSelected,
            ),
            if (worksheet != withRows.last)
              const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }

  Widget _boqPickerError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.error,
            size: 36,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            YorksV1MaterialRequestStrings.saveFailed.active(widget.language),
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _boqPickerFooter(BuildContext context, {required bool enabled}) =>
      Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                YorksV1MaterialRequestStrings.selectedItemCount(
                  _selectedRowIds.length,
                ).active(widget.language),
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                YorksV1MaterialRequestStrings.cancel.active(widget.language),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              key: const ValueKey('desktop-mr-add-selected-boq-items'),
              onPressed: enabled && _selectedRowIds.isNotEmpty
                  ? _submitSelection
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                minimumSize: const Size(0, AppSpacing.minTapTarget),
              ),
              child: Text(
                YorksV1MaterialRequestStrings.addSelectedItems.active(
                  widget.language,
                ),
              ),
            ),
          ],
        ),
      );

  void _setRowSelected(String rowId, bool selected) => setState(() {
    if (selected) {
      _selectedRowIds.add(rowId);
    } else {
      _selectedRowIds.remove(rowId);
    }
  });

  void _setWorksheetSelected(YorksV1BoqWorksheet worksheet, bool selected) {
    final eligible = worksheet.rows
        .map((row) => row.id)
        .where((id) => !widget.existingSourceRowIds.contains(id));
    setState(() {
      if (selected) {
        _selectedRowIds.addAll(eligible);
      } else {
        _selectedRowIds.removeAll(eligible);
      }
    });
  }

  void _submitSelection() {
    final byGroup = <String, Set<String>>{};
    widget.worksheets.then((worksheets) {
      if (!mounted) return;
      for (final worksheet in worksheets) {
        final selected = worksheet.rows
            .map((row) => row.id)
            .where(_selectedRowIds.contains)
            .toSet();
        if (selected.isNotEmpty) byGroup[worksheet.group.id] = selected;
      }
      Navigator.of(context).pop(_BoqPickerSelection(byGroup));
    });
  }
}

class _BoqPickerScopeBanner extends StatelessWidget {
  const _BoqPickerScopeBanner({
    required this.scopeName,
    required this.language,
  });

  final String scopeName;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: AppColors.blueContainer.withValues(alpha: 0.55),
      border: Border.all(color: AppColors.blueContainerStrong),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                scopeName,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                YorksV1MaterialRequestStrings.changeScopeToBrowseBoq.active(
                  language,
                ),
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              border: Border.all(color: AppColors.blueContainerStrong),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(
              scopeName.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.blue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _BoqPickerEmptyState extends StatelessWidget {
  const _BoqPickerEmptyState({required this.scopeName, required this.language});

  final String scopeName;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 300,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.folder_open_outlined,
            color: AppColors.blue,
            size: 40,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            YorksV1MaterialRequestStrings.noMaterialsInBoq(
              scopeName,
            ).active(language),
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              YorksV1MaterialRequestStrings.noBoqMaterialsHelp.active(language),
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BoqPickerWorksheetSection extends StatelessWidget {
  const _BoqPickerWorksheetSection({
    required this.worksheet,
    required this.language,
    required this.selectedRowIds,
    required this.existingSourceRowIds,
    required this.onChanged,
    required this.onSelectAll,
  });

  final YorksV1BoqWorksheet worksheet;
  final AppLanguage language;
  final Set<String> selectedRowIds;
  final Set<String> existingSourceRowIds;
  final void Function(String rowId, bool selected) onChanged;
  final void Function(YorksV1BoqWorksheet worksheet, bool selected) onSelectAll;

  @override
  Widget build(BuildContext context) {
    final eligibleIds = worksheet.rows
        .map((row) => row.id)
        .where((id) => !existingSourceRowIds.contains(id))
        .toSet();
    final selectedInWorksheet = eligibleIds.where(selectedRowIds.contains);
    final allSelected =
        eligibleIds.isNotEmpty &&
        selectedInWorksheet.length == eligibleIds.length;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${worksheet.group.displayOrder.toString().padLeft(2, '0')} · ${worksheet.group.effectiveTitle}',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${worksheet.rows.length} ${YorksV1BoqStrings.materials.active(language)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: allSelected,
                  onChanged: eligibleIds.isEmpty
                      ? null
                      : (value) => onSelectAll(worksheet, value ?? false),
                ),
                Text(
                  YorksV1MaterialRequestStrings.selectAll.active(language),
                  style: AppTypography.labelLarge,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1060,
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(56),
                  1: FixedColumnWidth(380),
                  2: FixedColumnWidth(140),
                  3: FixedColumnWidth(170),
                  4: FixedColumnWidth(170),
                  5: FixedColumnWidth(72),
                  6: FixedColumnWidth(72),
                },
                border: const TableBorder(
                  horizontalInside: BorderSide(color: AppColors.line),
                ),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                    ),
                    children: [
                      const SizedBox.shrink(),
                      _BoqPickerHeaderCell(
                        YorksV1MaterialRequestStrings.itemDescription.active(
                          language,
                        ),
                      ),
                      _BoqPickerHeaderCell(
                        YorksV1MaterialRequestStrings.size.active(language),
                      ),
                      _BoqPickerHeaderCell(
                        YorksV1MaterialRequestStrings.planningModelTag.active(
                          language,
                        ),
                      ),
                      _BoqPickerHeaderCell(
                        YorksV1MaterialRequestStrings.brandOrigin.active(
                          language,
                        ),
                      ),
                      _BoqPickerHeaderCell(
                        YorksV1MaterialRequestStrings.quantity.active(language),
                      ),
                      _BoqPickerHeaderCell(
                        YorksV1MaterialRequestStrings.unit.active(language),
                      ),
                    ],
                  ),
                  for (final row in worksheet.rows) _row(context, row),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TableRow _row(BuildContext context, YorksV1BoqRow row) {
    final alreadyAdded = existingSourceRowIds.contains(row.id);
    final selected = selectedRowIds.contains(row.id);
    final description = _boqDisplayValue(
      worksheet,
      row,
      YorksV1BoqCanonicalField.description,
    );
    return TableRow(
      decoration: BoxDecoration(
        color: alreadyAdded
            ? AppColors.surfaceContainerLow.withValues(alpha: 0.6)
            : null,
      ),
      children: [
        Center(
          child: Checkbox(
            key: ValueKey('desktop-mr-boq-row-${row.id}'),
            value: alreadyAdded || selected,
            onChanged: alreadyAdded
                ? null
                : (value) => onChanged(row.id, value ?? false),
          ),
        ),
        _BoqPickerDataCell(
          description.isEmpty ? '—' : description,
          trailing: alreadyAdded
              ? YorksV1MaterialRequestStrings.alreadyAdded.active(language)
              : null,
          emphasized: true,
        ),
        _BoqPickerDataCell(
          _boqDisplayValue(worksheet, row, YorksV1BoqCanonicalField.size),
        ),
        _BoqPickerDataCell(
          _boqDisplayValue(
            worksheet,
            row,
            YorksV1BoqCanonicalField.planningModelTag,
          ),
        ),
        _BoqPickerDataCell(
          _boqDisplayValue(
            worksheet,
            row,
            YorksV1BoqCanonicalField.brandOrigin,
          ),
        ),
        _BoqPickerDataCell(
          _boqDisplayValue(worksheet, row, YorksV1BoqCanonicalField.quantity),
          alignEnd: true,
        ),
        _BoqPickerDataCell(
          _boqDisplayValue(worksheet, row, YorksV1BoqCanonicalField.unit),
        ),
      ],
    );
  }
}

class _BoqPickerHeaderCell extends StatelessWidget {
  const _BoqPickerHeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.sm,
    ),
    child: Text(
      label.toUpperCase(),
      style: AppTypography.labelSmall.copyWith(
        color: AppColors.muted,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _BoqPickerDataCell extends StatelessWidget {
  const _BoqPickerDataCell(
    this.value, {
    this.trailing,
    this.emphasized = false,
    this.alignEnd = false,
  });

  final String value;
  final String? trailing;
  final bool emphasized;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.md,
    ),
    child: Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          value.trim().isEmpty ? '—' : value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.ink,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(height: 2),
          Text(
            trailing!,
            style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
          ),
        ],
      ],
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
    r'\b(nos?|each|pcs?|pieces?|meter|metre|cm|length|sets?|pairs?|rolls?|boxes?|tons?|kg|lit(?:re|er)s?|packs?|lots?)\b',
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
      return 'Box';
    case 'boxes':
      return 'Boxes';
    case 'ton':
    case 'tons':
      return 'Ton';
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

Future<String?> _arrangementReturnReason(BuildContext context) async {
  final text = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    animationStyle: AnimationStyle.noAnimation,
    builder: (context) => AlertDialog(
      title: Text(YorksV1ArrangementStrings.returnToProcurement.primary),
      content: TextField(
        controller: text,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: YorksV1ArrangementStrings.returnReason.primary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(YorksV1MaterialRequestStrings.cancel.primary),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(text.text),
          child: Text(YorksV1ArrangementStrings.returnToProcurement.primary),
        ),
      ],
    ),
  );
  text.dispose();
  return result;
}

void _snack(BuildContext context, String message) =>
    YorksAppToast.show(context, title: message);
