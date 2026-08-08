import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_project.dart';
import '../../../../shared/models/yorks_v1_boq.dart';
import '../../../../shared/models/yorks_v1_document.dart';
import '../../../../shared/models/yorks_v1_domain_error.dart';
import '../../../../shared/models/yorks_v1_project_portfolio.dart';
import '../../../../shared/models/yorks_v1_project_strings.dart';
import '../../../../shared/models/yorks_v1_project_team_directory_member.dart';
import '../../../../shared/models/yorks_v1_role.dart';
import '../../../../shared/models/yorks_v1_material_request.dart';
import '../../../../shared/models/yorks_v1_logistics.dart';
import '../../../../shared/models/yorks_v1_material_request_strings.dart';
import '../../../../shared/models/yorks_v1_shell_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/session_provider.dart';
import '../../../../shared/providers/yorks_v1_identity_provider.dart';
import '../../../../shared/providers/yorks_v1_material_request_provider.dart';
import '../../../../shared/providers/yorks_v1_boq_provider.dart';
import '../../../../shared/providers/yorks_v1_documents_provider.dart';
import '../../../../shared/providers/yorks_v1_logistics_provider.dart';
import '../../../../shared/providers/yorks_v1_project_controller_provider.dart';
import '../../../../shared/providers/yorks_v1_project_portfolio_provider.dart';
import '../../../../shared/providers/yorks_v1_project_team_directory_provider.dart';
import 'yorks_v1_boq_screens.dart';

/// The normalized, R35-aligned project portfolio.
///
/// It intentionally replaces the retained local project register only inside
/// the Yorks V1 rollout. Its rows are server-authorized non-commercial V1
/// projections and route into connected BOQ, request and document flows.
class YorksV1ProjectsScreen extends ConsumerStatefulWidget {
  const YorksV1ProjectsScreen({super.key});

  @override
  ConsumerState<YorksV1ProjectsScreen> createState() =>
      _YorksV1ProjectsScreenState();
}

/// R35's role-aware operational overview.
///
/// It replaces the retained V7 dashboard only while the normalized Yorks V1
/// rollout is active. Every number and card comes from a safe V1 projection;
/// the overview is deliberately a navigation surface and never owns workflow
/// transitions itself.
class YorksV1OverviewScreen extends ConsumerWidget {
  const YorksV1OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(yorksV1MaterialRequestLiveRefreshProvider);
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final user = ref.watch(currentUserProvider);
    final projects = ref.watch(yorksV1ProjectPortfolioProvider);
    final requests = ref.watch(yorksV1MaterialRequestListProvider(null));
    final canCreateProject = role?.canCreateProject == true;
    final canCreateRequest = role?.canCreateMaterialRequest == true;
    final procurement = role == YorksV1Role.procurement;
    final AsyncValue<YorksV1InventoryWorkspace?> inventory = procurement
        ? ref
              .watch(yorksV1InventoryWorkspaceProvider(null))
              .whenData<YorksV1InventoryWorkspace?>((value) => value)
        : const AsyncData<YorksV1InventoryWorkspace?>(null);

    final projectItems =
        projects.valueOrNull ?? const <YorksV1ProjectPortfolioItem>[];
    final requestItems =
        requests.valueOrNull ?? const <YorksV1MaterialRequest>[];
    final openRequests = requestItems
        .where(
          (item) =>
              item.state != YorksV1MaterialRequestState.draft &&
              item.state != YorksV1MaterialRequestState.received &&
              item.state != YorksV1MaterialRequestState.closed &&
              item.state != YorksV1MaterialRequestState.cancelled,
        )
        .length;
    final needsAction = requestItems
        .where((item) => yorksV1MaterialRequestNeedsAction(item, role))
        .length;
    final dispatchReady = requestItems
        .where(
          (item) =>
              item.state == YorksV1MaterialRequestState.approved ||
              item.state == YorksV1MaterialRequestState.partiallyDispatched,
        )
        .length;

    return _R35OverviewPage(
      role: role,
      displayName: user?.fullName,
      projects: projects,
      requests: requests,
      projectCount: projectItems.length,
      openRequests: openRequests,
      needsAction: needsAction,
      dispatchReady: dispatchReady,
      canCreateProject: canCreateProject,
      canCreateRequest: canCreateRequest,
      procurement: procurement,
      inventory: inventory,
      onCreateProject: () => context.push(RoutePaths.engineerCreateProject),
      onCreateRequest: () => context.push(
        RoutePaths.yorksV1MaterialRequestDraftPath(const Uuid().v4()),
      ),
      onOpenProjects: () => context.go(RoutePaths.yorksV1Projects),
      onOpenRequests: () => context.go(RoutePaths.yorksV1MaterialRequests),
      onRetryProjects: () => ref.invalidate(yorksV1ProjectPortfolioProvider),
      onRetryRequests: () => ref.invalidate(yorksV1MaterialRequestListProvider),
    );
  }
}

class _R35OverviewPage extends StatelessWidget {
  const _R35OverviewPage({
    required this.role,
    required this.displayName,
    required this.projects,
    required this.requests,
    required this.projectCount,
    required this.openRequests,
    required this.needsAction,
    required this.dispatchReady,
    required this.canCreateProject,
    required this.canCreateRequest,
    required this.procurement,
    required this.inventory,
    required this.onCreateProject,
    required this.onCreateRequest,
    required this.onOpenProjects,
    required this.onOpenRequests,
    required this.onRetryProjects,
    required this.onRetryRequests,
  });

  final YorksV1Role? role;
  final String? displayName;
  final AsyncValue<List<YorksV1ProjectPortfolioItem>> projects;
  final AsyncValue<List<YorksV1MaterialRequest>> requests;
  final int projectCount;
  final int openRequests;
  final int needsAction;
  final int dispatchReady;
  final bool canCreateProject;
  final bool canCreateRequest;
  final bool procurement;
  final AsyncValue<YorksV1InventoryWorkspace?> inventory;
  final VoidCallback onCreateProject;
  final VoidCallback onCreateRequest;
  final VoidCallback onOpenProjects;
  final VoidCallback onOpenRequests;
  final VoidCallback onRetryProjects;
  final VoidCallback onRetryRequests;

  @override
  Widget build(BuildContext context) {
    if (procurement) {
      return _R35ProcurementOverview(
        requests: requests,
        inventory: inventory,
        onOpenRequests: onOpenRequests,
        onOpenProjects: onOpenProjects,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop =
            MediaQuery.sizeOf(context).width >=
            AppSpacing.yorksV1ShellDesktopBreakpoint;
        final name = (displayName ?? '').trim().split(RegExp(r'\s+')).first;
        final safeName = name.isEmpty
            ? YorksV1ShellStrings.companyName.primary
            : name;
        final horizontal = desktop ? 26.0 : 14.0;
        final contentWidth = (constraints.maxWidth - horizontal * 2).clamp(
          0.0,
          AppSpacing.pageMaxWidth,
        );
        return ColoredBox(
          color: desktop ? AppColors.surface : AppColors.mobileSurface,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              desktop ? 24 : 16,
              horizontal,
              96,
            ),
            child: SizedBox(
              width: contentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _R35OverviewHero(
                    name: safeName,
                    projectCount: projectCount,
                    openRequests: openRequests,
                    canCreateProject: canCreateProject,
                    canCreateRequest: canCreateRequest,
                    procurement: procurement,
                    onCreateProject: onCreateProject,
                    onCreateRequest: onCreateRequest,
                    onOpenRequests: onOpenRequests,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _R35SectionHeading(
                    title: YorksV1ShellStrings.needsYourAction.primary,
                    description:
                        YorksV1ShellStrings.roleActionDescription.primary,
                    attentionCount: needsAction,
                  ),
                  const SizedBox(height: 8),
                  _R35ActionCard(
                    requests: requests,
                    role: role,
                    onRetry: onRetryRequests,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _R35SectionHeading(
                    title: YorksV1ProjectStrings.projects.primary,
                    action: YorksV1ShellStrings.viewAll.primary,
                    onAction: onOpenProjects,
                  ),
                  const SizedBox(height: 10),
                  _R35ProjectPanel(
                    projects: projects,
                    onRetry: onRetryProjects,
                  ),
                  if (procurement) ...[
                    const SizedBox(height: AppSpacing.xxxl),
                    _R35SectionHeading(
                      title: YorksV1ShellStrings.dispatches.primary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _R35DispatchReadiness(value: dispatchReady),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _R35ProcurementOverview extends StatelessWidget {
  const _R35ProcurementOverview({
    required this.requests,
    required this.inventory,
    required this.onOpenRequests,
    required this.onOpenProjects,
  });

  final AsyncValue<List<YorksV1MaterialRequest>> requests;
  final AsyncValue<YorksV1InventoryWorkspace?> inventory;
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenProjects;

  @override
  Widget build(BuildContext context) {
    final records = requests.valueOrNull ?? const <YorksV1MaterialRequest>[];
    final toArrange = records
        .where(
          (item) =>
              item.state == YorksV1MaterialRequestState.submitted ||
              item.state == YorksV1MaterialRequestState.arranging,
        )
        .toList();
    final needsAction = records
        .where(
          (item) =>
              yorksV1MaterialRequestNeedsAction(item, YorksV1Role.procurement),
        )
        .length;
    final awaitingApproval = records
        .where(
          (item) => item.state == YorksV1MaterialRequestState.awaitingApproval,
        )
        .length;
    final approved = records
        .where(
          (item) =>
              item.state == YorksV1MaterialRequestState.approved ||
              item.state == YorksV1MaterialRequestState.partiallyDispatched,
        )
        .length;
    final awaitingReceipt = records
        .where(
          (item) =>
              item.state == YorksV1MaterialRequestState.dispatched ||
              item.state == YorksV1MaterialRequestState.partiallyReceived,
        )
        .length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop =
            MediaQuery.sizeOf(context).width >=
            AppSpacing.yorksV1ShellDesktopBreakpoint;
        final horizontal = desktop
            ? AppSpacing.xxxl + AppSpacing.xs
            : AppSpacing.lg;
        return ColoredBox(
          color: AppColors.surface,
          child: SingleChildScrollView(
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
                  LayoutBuilder(
                    builder: (context, inner) {
                      final stacked = inner.maxWidth < 820;
                      final hero = _R35Card(
                        minHeight: stacked ? null : 286,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              YorksV1ShellStrings.procurementGreeting.primary
                                  .toUpperCase(),
                              style: AppTypography.eyebrow.copyWith(
                                color: AppColors.blueContainerStrong,
                                letterSpacing: 1.45,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              YorksV1ShellStrings.procurementHero.primary,
                              style: AppTypography.headlineLarge.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.05,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              YorksV1ShellStrings
                                  .procurementHeroDescription
                                  .primary,
                              style: AppTypography.bodyLarge.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxxl),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                _R35PrimaryAction(
                                  label: YorksV1ShellStrings
                                      .materialRequests
                                      .primary,
                                  icon: Icons.assignment_outlined,
                                  onPressed: onOpenRequests,
                                ),
                                _R35SecondaryAction(
                                  label: YorksV1ShellStrings
                                      .browseInventory
                                      .primary,
                                  icon: Icons.inventory_2_outlined,
                                  onPressed: () =>
                                      context.go(RoutePaths.yorksV1Inventory),
                                ),
                                _R35SecondaryAction(
                                  label:
                                      YorksV1ShellStrings.viewProjects.primary,
                                  icon: Icons.visibility_outlined,
                                  onPressed: onOpenProjects,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                      final snapshot = _R35Card(
                        minHeight: stacked ? null : 286,
                        child: Column(
                          children: [
                            _R35SnapshotTile(
                              label: YorksV1ShellStrings.newToArrange.primary,
                              value: '${toArrange.length}',
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _R35SnapshotTile(
                              label:
                                  YorksV1ShellStrings.readyToDispatch.primary,
                              value: '$approved',
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _R35SnapshotTile(
                              label: YorksV1ShellStrings.lowOutOfStock.primary,
                              value: inventory.when(
                                data: (workspace) => workspace == null
                                    ? '—'
                                    : '${workspace.summary.attentionCount}',
                                loading: () => '…',
                                error: (_, _) => '—',
                              ),
                            ),
                          ],
                        ),
                      );
                      return stacked
                          ? Column(
                              children: [
                                hero,
                                const SizedBox(height: AppSpacing.md),
                                snapshot,
                              ],
                            )
                          : IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(flex: 3, child: hero),
                                  const SizedBox(width: AppSpacing.lg),
                                  Expanded(flex: 2, child: snapshot),
                                ],
                              ),
                            );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ProcurementWorkflowStrip(),
                  const SizedBox(height: AppSpacing.lg),
                  _ProcurementStatusGrid(
                    newRequests: toArrange.length,
                    awaitingApproval: awaitingApproval,
                    approved: approved,
                    awaitingReceipt: awaitingReceipt,
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  Row(
                    children: [
                      Expanded(
                        child: _R35SectionHeading(
                          title: YorksV1ShellStrings
                              .needsProcurementAction
                              .primary,
                          description: YorksV1ShellStrings
                              .procurementActionDescription
                              .primary,
                          attentionCount: needsAction,
                        ),
                      ),
                      SizedBox(
                        height: AppSpacing.minTapTarget,
                        child: OutlinedButton(
                          onPressed: onOpenRequests,
                          child: Text(
                            YorksV1ShellStrings.viewAllRequests.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ProcurementRequestQueue(
                    requests: requests,
                    queued: toArrange,
                    onOpenRequests: onOpenRequests,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProcurementWorkflowStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final steps = [
          (
            YorksV1ShellStrings.request.primary,
            YorksV1ShellStrings.requestStepDescription.primary,
          ),
          (
            YorksV1ShellStrings.arrange.primary,
            YorksV1ShellStrings.arrangeStepDescription.primary,
          ),
          (
            YorksV1ShellStrings.approve.primary,
            YorksV1ShellStrings.approveStepDescription.primary,
          ),
          (
            YorksV1ShellStrings.dispatch.primary,
            YorksV1ShellStrings.dispatchStepDescription.primary,
          ),
          (
            YorksV1ShellStrings.receipt.primary,
            YorksV1ShellStrings.receiptStepDescription.primary,
          ),
        ];
        final compact = constraints.maxWidth < 760;
        return compact
            ? Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (var index = 0; index < steps.length; index++)
                    _ProcurementWorkflowStep(
                      number: index + 1,
                      title: steps[index].$1,
                      detail: steps[index].$2,
                      compact: true,
                    ),
                ],
              )
            : Row(
                children: [
                  for (var index = 0; index < steps.length; index++) ...[
                    Expanded(
                      child: _ProcurementWorkflowStep(
                        number: index + 1,
                        title: steps[index].$1,
                        detail: steps[index].$2,
                      ),
                    ),
                    if (index != steps.length - 1)
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.lineStrong,
                      ),
                  ],
                ],
              );
      },
    ),
  );
}

class _ProcurementWorkflowStep extends StatelessWidget {
  const _ProcurementWorkflowStep({
    required this.number,
    required this.title,
    required this.detail,
    this.compact = false,
  });

  final int number;
  final String title;
  final String detail;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    constraints: compact ? const BoxConstraints(minWidth: 150) : null,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.blueContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Text(
            '$number',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.blue,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          detail,
          style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _ProcurementStatusGrid extends StatelessWidget {
  const _ProcurementStatusGrid({
    required this.newRequests,
    required this.awaitingApproval,
    required this.approved,
    required this.awaitingReceipt,
  });

  final int newRequests;
  final int awaitingApproval;
  final int approved;
  final int awaitingReceipt;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = constraints.maxWidth >= 1000
          ? 4
          : constraints.maxWidth >= 640
          ? 2
          : 1;
      final metrics = [
        (
          YorksV1ShellStrings.newRequests.primary,
          '$newRequests',
          YorksV1ShellStrings.newRequestsDescription.primary,
        ),
        (
          YorksV1ShellStrings.engineerReview.primary,
          '$awaitingApproval',
          YorksV1ShellStrings.engineerReviewDescription.primary,
        ),
        (
          YorksV1ShellStrings.approved.primary,
          '$approved',
          YorksV1ShellStrings.approvedDescription.primary,
        ),
        (
          YorksV1ShellStrings.awaitingReceipt.primary,
          '$awaitingReceipt',
          YorksV1ShellStrings.awaitingReceiptDescription.primary,
        ),
      ];
      return GridView.count(
        crossAxisCount: count,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: switch (count) {
          1 => 2.5,
          2 => 2.1,
          _ => 1.8,
        },
        children: [
          for (final metric in metrics)
            _R35Card(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    metric.$1.toUpperCase(),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .85,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    metric.$2,
                    style: AppTypography.headlineMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    metric.$3,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _ProcurementRequestQueue extends StatelessWidget {
  const _ProcurementRequestQueue({
    required this.requests,
    required this.queued,
    required this.onOpenRequests,
  });

  final AsyncValue<List<YorksV1MaterialRequest>> requests;
  final List<YorksV1MaterialRequest> queued;
  final VoidCallback onOpenRequests;

  @override
  Widget build(BuildContext context) => _R35Card(
    minHeight: 150,
    child: requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Text(
          YorksV1ShellStrings.requestsUnavailable.primary,
          style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
        ),
      ),
      data: (_) {
        if (queued.isEmpty) {
          return Center(
            child: Text(
              YorksV1ShellStrings.noProcurementAction.primary,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
            ),
          );
        }
        final request = queued.first;
        final requestTitle = request.title?.trim();
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenRequests,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.blueContainer,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${request.requestNumber ?? YorksV1MaterialRequestStrings.draft.primary}${requestTitle == null || requestTitle.isEmpty ? '' : ' · $requestTitle'}',
                          style: AppTypography.labelLarge.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${request.projectReference} · ${request.scopeName} · ${request.lines.length} ${YorksV1MaterialRequestStrings.items.primary.toLowerCase()}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _R35OverviewHero extends StatelessWidget {
  const _R35OverviewHero({
    required this.name,
    required this.projectCount,
    required this.openRequests,
    required this.canCreateProject,
    required this.canCreateRequest,
    required this.procurement,
    required this.onCreateProject,
    required this.onCreateRequest,
    required this.onOpenRequests,
  });

  final String name;
  final int projectCount;
  final int openRequests;
  final bool canCreateProject;
  final bool canCreateRequest;
  final bool procurement;
  final VoidCallback onCreateProject;
  final VoidCallback onCreateRequest;
  final VoidCallback onOpenRequests;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          MediaQuery.sizeOf(context).width <= AppSpacing.compactBreakpoint;
      final main = _R35Card(
        minHeight: stacked ? null : 234,
        padding: const EdgeInsets.all(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  YorksV1ShellStrings.goodAfternoon.primary.toUpperCase(),
                  style: AppTypography.eyebrow.copyWith(
                    color: const Color(0xFF85BAFA),
                    fontSize: 9,
                    letterSpacing: 1.17,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$name, ${YorksV1ShellStrings.workspaceReady.primary}',
                  style: AppTypography.headlineLarge.copyWith(
                    color: AppColors.ink,
                    fontSize: stacked ? 24 : 29,
                    height: stacked ? 1.08 : 1.12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: stacked ? -.72 : -.87,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  procurement
                      ? YorksV1ShellStrings.projectCloseoutDescription.primary
                      : YorksV1ShellStrings
                            .overviewWorkspaceDescription
                            .primary,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.65,
                  ),
                ),
              ],
            ),
            if (stacked) const SizedBox(height: 20) else const Spacer(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (canCreateProject)
                  _R35PrimaryAction(
                    label: YorksV1ProjectStrings.newProject.primary,
                    icon: Icons.add_rounded,
                    onPressed: onCreateProject,
                  ),
                if (canCreateRequest)
                  _R35SecondaryAction(
                    label: YorksV1MaterialRequestStrings.newRequest.primary,
                    icon: Icons.assignment_outlined,
                    onPressed: onCreateRequest,
                  ),
                _R35SecondaryAction(
                  label: YorksV1ShellStrings.openRequests.primary,
                  onPressed: onOpenRequests,
                ),
              ],
            ),
          ],
        ),
      );
      final snapshot = _R35Card(
        minHeight: stacked ? null : 234,
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _R35SnapshotTile(
              label: YorksV1ProjectStrings.projects.primary,
              value: '$projectCount',
            ),
            const SizedBox(height: 10),
            _R35SnapshotTile(
              label: YorksV1ShellStrings.needsYourAction.primary,
              value: '$openRequests',
            ),
            const SizedBox(height: 10),
            _R35SnapshotTile(
              label: YorksV1ShellStrings.scope.primary,
              value: YorksV1ShellStrings.workspaceScope.primary,
              valueText: true,
            ),
          ],
        ),
      );
      if (stacked) {
        return Column(
          children: [
            main,
            const SizedBox(height: AppSpacing.lg),
            snapshot,
          ],
        );
      }
      final rightWidth = ((constraints.maxWidth - AppSpacing.lg) * .375).clamp(
        280.0,
        double.infinity,
      );
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: main),
            const SizedBox(width: AppSpacing.lg),
            SizedBox(width: rightWidth, child: snapshot),
          ],
        ),
      );
    },
  );
}

class _R35Card extends StatelessWidget {
  const _R35Card({
    required this.child,
    this.minHeight,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final double? minHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: minHeight ?? 0),
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(15),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class _R35SnapshotTile extends StatelessWidget {
  const _R35SnapshotTile({
    required this.label,
    required this.value,
    this.valueText = false,
  });

  final String label;
  final String value;
  final bool valueText;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      border: Border.all(color: AppColors.line),
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
            fontSize: 8.5,
            height: 1.2,
            letterSpacing: .85,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.ink,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _R35PrimaryAction extends StatelessWidget {
  const _R35PrimaryAction({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).width <= AppSpacing.compactBreakpoint
        ? AppSpacing.minTapTarget
        : 38,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 20),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.navy,
        padding: EdgeInsets.symmetric(
          horizontal:
              MediaQuery.sizeOf(context).width <= AppSpacing.compactBreakpoint
              ? 11
              : 13,
        ),
        textStyle: AppTypography.labelLarge.copyWith(fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        elevation: 2,
        shadowColor: AppColors.navy.withValues(alpha: .28),
      ),
    ),
  );
}

class _R35SecondaryAction extends StatelessWidget {
  const _R35SecondaryAction({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).width <= AppSpacing.compactBreakpoint
        ? AppSpacing.minTapTarget
        : 38,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 19),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.inkSecondary,
        side: const BorderSide(color: AppColors.line),
        padding: EdgeInsets.symmetric(
          horizontal:
              MediaQuery.sizeOf(context).width <= AppSpacing.compactBreakpoint
              ? 11
              : 13,
        ),
        textStyle: AppTypography.labelLarge.copyWith(fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
    ),
  );
}

class _R35SectionHeading extends StatelessWidget {
  const _R35SectionHeading({
    required this.title,
    this.description,
    this.action,
    this.onAction,
    this.attentionCount = 0,
  });

  final String title;
  final String? description;
  final String? action;
  final VoidCallback? onAction;
  final int attentionCount;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.ink,
                fontSize: 17,
                letterSpacing: -.255,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                description!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.muted,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
      if (attentionCount > 0) ...[
        const SizedBox(width: AppSpacing.sm),
        _NeedsActionBadge(count: attentionCount),
      ],
      if (action != null && onAction != null)
        SizedBox(
          height:
              MediaQuery.sizeOf(context).width <= AppSpacing.compactBreakpoint
              ? AppSpacing.minTapTarget
              : 32,
          child: OutlinedButton(onPressed: onAction, child: Text(action!)),
        ),
    ],
  );
}

class _R35ActionCard extends StatelessWidget {
  const _R35ActionCard({
    required this.requests,
    required this.role,
    required this.onRetry,
  });

  final AsyncValue<List<YorksV1MaterialRequest>> requests;
  final YorksV1Role? role;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _R35Card(
    minHeight: 220,
    child: requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _OverviewRetry(onRetry: onRetry),
      data: (items) {
        final actionable = items
            .where((item) => yorksV1MaterialRequestNeedsAction(item, role))
            .take(5)
            .toList();
        if (actionable.isEmpty) {
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 42),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_rounded,
                    color: AppColors.blueContainerStrong,
                    size: 34,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    YorksV1ShellStrings.nothingWaiting.primary,
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    YorksV1ShellStrings.nothingWaitingDescription.primary,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                      fontSize: 10,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final item in actionable) _OverviewRequestRow(item: item),
          ],
        );
      },
    ),
  );
}

class _NeedsActionBadge extends StatelessWidget {
  const _NeedsActionBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$count records need your action',
    child: Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: .10),
        border: Border.all(color: AppColors.error.withValues(alpha: .32)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _R35ProjectPanel extends StatelessWidget {
  const _R35ProjectPanel({required this.projects, required this.onRetry});

  final AsyncValue<List<YorksV1ProjectPortfolioItem>> projects;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => projects.when(
    loading: () => const _R35Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
    ),
    error: (_, _) => _R35Card(child: _OverviewRetry(onRetry: onRetry)),
    data: (items) => items.isEmpty
        ? const SizedBox.shrink()
        : _R35Card(
            child: Column(
              children: [
                for (final item in items.take(5))
                  _OverviewProjectRow(item: item),
              ],
            ),
          ),
  );
}

class _R35DispatchReadiness extends StatelessWidget {
  const _R35DispatchReadiness({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) => _R35Card(
    child: _R35SnapshotTile(
      label: YorksV1ShellStrings.dispatches.primary,
      value: '$value',
    ),
  );
}

class _OverviewProjectRow extends StatelessWidget {
  const _OverviewProjectRow({required this.item});

  final YorksV1ProjectPortfolioItem item;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => context.push(RoutePaths.yorksV1ProjectPath(item.project.id)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            _OverviewRecordIcon(icon: Icons.account_tree_outlined),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.project.name,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${item.project.reference} · ${item.project.siteLocation ?? '—'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            _ProjectStateChip(state: item.project.state),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
}

class _OverviewRequestRow extends StatelessWidget {
  const _OverviewRequestRow({required this.item});

  final YorksV1MaterialRequest item;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => context.push(_materialRequestOpenPath(item)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            _OverviewRecordIcon(icon: Icons.assignment_outlined),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.requestNumber ??
                        YorksV1MaterialRequestStrings.draft.primary,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${item.projectReference} · ${item.scopeName} · ${item.lines.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            StatusChip(
              label: yorksV1MaterialRequestStateCopy(item.state).primary,
              tone: _requestTone(item.state),
              showDot: true,
            ),
          ],
        ),
      ),
    ),
  );
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

class _OverviewRecordIcon extends StatelessWidget {
  const _OverviewRecordIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: AppSpacing.minTapTarget,
    height: AppSpacing.minTapTarget,
    decoration: BoxDecoration(
      color: AppColors.blueContainer,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Icon(icon, color: AppColors.blue, size: 21),
  );
}

class _OverviewRetry extends StatelessWidget {
  const _OverviewRetry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded),
      label: Text(YorksV1MaterialRequestStrings.refresh.primary),
    ),
  );
}

NexusStatusTone _requestTone(YorksV1MaterialRequestState state) {
  switch (state) {
    case YorksV1MaterialRequestState.approved:
    case YorksV1MaterialRequestState.received:
    case YorksV1MaterialRequestState.closed:
      return NexusStatusTone.success;
    case YorksV1MaterialRequestState.awaitingApproval:
    case YorksV1MaterialRequestState.partiallyDispatched:
    case YorksV1MaterialRequestState.dispatched:
    case YorksV1MaterialRequestState.partiallyReceived:
      return NexusStatusTone.warning;
    case YorksV1MaterialRequestState.cancelled:
      return NexusStatusTone.danger;
    case YorksV1MaterialRequestState.submitted:
    case YorksV1MaterialRequestState.arranging:
      return NexusStatusTone.info;
    case YorksV1MaterialRequestState.draft:
      return NexusStatusTone.neutral;
  }
}

class _YorksV1ProjectsScreenState extends ConsumerState<YorksV1ProjectsScreen> {
  String _search = '';
  YorksV1ProjectLifecycle? _stateFilter;

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final portfolio = ref.watch(yorksV1ProjectPortfolioProvider);
    final canCreate = role?.canCreateProject == true;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        top: false,
        child: NexusPageShell(
          eyebrow: YorksV1ProjectStrings.projects.primary,
          title: YorksV1ProjectStrings.projects.primary,
          description: role == YorksV1Role.procurement
              ? YorksV1ProjectStrings.viewOnlyPortfolio.primary
              : YorksV1ProjectStrings.portfolioDescription.primary,
          actions: [
            if (canCreate)
              SizedBox(
                height: AppSpacing.minTapTarget,
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push(RoutePaths.engineerCreateProject),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(YorksV1ProjectStrings.createProject.primary),
                ),
              ),
          ],
          child: portfolio.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.huge),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, _) => _PortfolioError(
              language: language,
              onRetry: () => ref.invalidate(yorksV1ProjectPortfolioProvider),
            ),
            data: (items) {
              final visible = _filter(items);
              return _PortfolioBody(
                items: items,
                visible: visible,
                language: language,
                stateFilter: _stateFilter,
                search: _search,
                canCreate: canCreate,
                onSearchChanged: (value) => setState(() => _search = value),
                onStateChanged: (value) => setState(() => _stateFilter = value),
                onCreate: canCreate
                    ? () => context.push(RoutePaths.engineerCreateProject)
                    : null,
              );
            },
          ),
        ),
      ),
    );
  }

  List<YorksV1ProjectPortfolioItem> _filter(
    List<YorksV1ProjectPortfolioItem> items,
  ) {
    final query = _search.trim().toLowerCase();
    return [
      for (final item in items)
        if ((_stateFilter == null || item.project.state == _stateFilter) &&
            (query.isEmpty ||
                item.project.reference.toLowerCase().contains(query) ||
                item.project.name.toLowerCase().contains(query) ||
                (item.project.siteLocation ?? '').toLowerCase().contains(
                  query,
                ) ||
                (item.clientName ?? '').toLowerCase().contains(query)))
          item,
    ];
  }
}

enum YorksV1ProjectWorkspaceTab { overview, boq, requests, documents }

class YorksV1ProjectWorkspaceScreen extends ConsumerStatefulWidget {
  const YorksV1ProjectWorkspaceScreen({
    super.key,
    required this.projectId,
    this.initialTab = YorksV1ProjectWorkspaceTab.overview,
  });

  final String projectId;
  final YorksV1ProjectWorkspaceTab initialTab;

  @override
  ConsumerState<YorksV1ProjectWorkspaceScreen> createState() =>
      _YorksV1ProjectWorkspaceScreenState();
}

class _YorksV1ProjectWorkspaceScreenState
    extends ConsumerState<YorksV1ProjectWorkspaceScreen> {
  late YorksV1ProjectWorkspaceTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  void didUpdateWidget(covariant YorksV1ProjectWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _tab = widget.initialTab;
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final authUserId = ref.watch(yorksV1AuthUserIdProvider);
    final portfolio = ref.watch(yorksV1ProjectPortfolioProvider);
    final requests = ref.watch(
      yorksV1MaterialRequestListProvider(widget.projectId),
    );
    final scopes = ref.watch(
      yorksV1MaterialRequestScopesProvider(widget.projectId),
    );
    final groups = ref.watch(yorksV1BoqGroupsProvider(widget.projectId));
    final documents = ref.watch(
      yorksV1DocumentWorkspaceProvider(widget.projectId),
    );
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
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(RoutePaths.yorksV1Projects),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            )
          : null,
      body: SafeArea(
        top: false,
        child: portfolio.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _PortfolioError(
            language: language,
            onRetry: () => ref.invalidate(yorksV1ProjectPortfolioProvider),
          ),
          data: (items) {
            YorksV1ProjectPortfolioItem? project;
            for (final item in items) {
              if (item.project.id == widget.projectId) {
                project = item;
                break;
              }
            }
            if (project == null) {
              return _PortfolioError(
                language: language,
                onRetry: () => ref.invalidate(yorksV1ProjectPortfolioProvider),
              );
            }
            final selectedProject = project;
            final projectStateIsEditable =
                selectedProject.project.state ==
                    YorksV1ProjectLifecycle.draft ||
                selectedProject.project.state == YorksV1ProjectLifecycle.active;
            final activeMember =
                authUserId != null &&
                selectedProject.activeMembers.any(
                  (member) => member.memberAuthUserId == authUserId,
                );
            final isCreator =
                authUserId != null &&
                selectedProject.project.createdByAuthUserId == authUserId;
            final hasProjectEngineerMembership =
                authUserId != null &&
                selectedProject.activeMembers.any(
                  (member) =>
                      member.memberAuthUserId == authUserId &&
                      member.projectRole ==
                          YorksV1ProjectMembershipRole.projectEngineer,
                );
            final canManageProject =
                role == YorksV1Role.admin ||
                (role?.isGlobalProjectEngineer ?? false) ||
                hasProjectEngineerMembership;
            final canEdit =
                projectStateIsEditable &&
                (role == YorksV1Role.admin ||
                    (role?.isGlobalProjectEngineer ?? false) ||
                    activeMember ||
                    isCreator);
            return _ProjectWorkspaceBody(
              item: selectedProject,
              tab: _tab,
              language: language,
              requests: requests,
              scopes: scopes,
              groups: groups,
              documents: documents,
              onActivate:
                  selectedProject.project.state ==
                          YorksV1ProjectLifecycle.draft &&
                      canManageProject
                  ? () => _activateProject(selectedProject.project)
                  : null,
              onNewRequest: role?.canCreateMaterialRequest == true
                  ? () => context.push(
                      RoutePaths.yorksV1MaterialRequestDraftPath(
                        const Uuid().v4(),
                        projectId: selectedProject.project.id,
                      ),
                    )
                  : null,
              onEdit: canEdit
                  ? () => context.push(
                      RoutePaths.yorksV1ProjectEditPath(
                        selectedProject.project.id,
                      ),
                    )
                  : null,
              onArchive:
                  role == YorksV1Role.admin &&
                      selectedProject.project.state !=
                          YorksV1ProjectLifecycle.archived
                  ? () => _confirmSafeArchive(selectedProject.project)
                  : null,
              onTabChanged: (value) {
                setState(() => _tab = value);
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _activateProject(YorksV1Project project) async {
    try {
      await ref
          .read(yorksV1ProjectCommandControllerProvider.notifier)
          .setProjectState(
            YorksV1SetProjectStateInput(
              idempotencyKey: const Uuid().v4(),
              projectId: project.id,
              currentState: project.state,
              targetState: YorksV1ProjectLifecycle.active,
              expectedProjectVersion: project.recordVersion,
            ),
          );
      ref.invalidate(yorksV1ProjectPortfolioProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(YorksV1ProjectStrings.projectActivated.primary)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(YorksV1ProjectStrings.projectActivationFailed.primary),
        ),
      );
    }
  }

  Future<void> _confirmSafeArchive(YorksV1Project project) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(YorksV1ProjectStrings.safeDeleteProject.primary),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(YorksV1ProjectStrings.safeDeleteProjectDescription.primary),
            const SizedBox(height: AppSpacing.lg),
            LedgerTextField(
              controller: reasonController,
              label: YorksV1ProjectStrings.archiveReason.primary,
              hintText: YorksV1ProjectStrings.archiveReason.primary,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(YorksV1ProjectStrings.cancel.primary),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(reasonController.text.trim()),
            child: Text(YorksV1ProjectStrings.confirmArchive.primary),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await ref
          .read(yorksV1ProjectCommandControllerProvider.notifier)
          .archiveProject(
            YorksV1ArchiveProjectInput(
              idempotencyKey: const Uuid().v4(),
              projectId: project.id,
              expectedProjectVersion: project.recordVersion,
              reason: reason,
            ),
          );
      ref.invalidate(yorksV1ProjectPortfolioProvider);
      if (!mounted) return;
      context.go(RoutePaths.yorksV1Projects);
    } on YorksV1DomainException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(YorksV1ProjectStrings.errorFor(error.code).primary),
        ),
      );
    }
  }
}

class _PortfolioBody extends StatelessWidget {
  const _PortfolioBody({
    required this.items,
    required this.visible,
    required this.language,
    required this.stateFilter,
    required this.search,
    required this.canCreate,
    required this.onSearchChanged,
    required this.onStateChanged,
    required this.onCreate,
  });

  final List<YorksV1ProjectPortfolioItem> items;
  final List<YorksV1ProjectPortfolioItem> visible;
  final AppLanguage language;
  final YorksV1ProjectLifecycle? stateFilter;
  final String search;
  final bool canCreate;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<YorksV1ProjectLifecycle?> onStateChanged;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _PortfolioEmpty(
        language: language,
        canCreate: canCreate,
        onCreate: onCreate,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop =
            constraints.maxWidth >= AppSpacing.yorksV1DesktopBreakpoint;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PortfolioControls(
              language: language,
              stateFilter: stateFilter,
              search: search,
              onSearchChanged: onSearchChanged,
              onStateChanged: onStateChanged,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (visible.isEmpty)
              _NoMatchingProjects(language: language)
            else if (desktop)
              _DesktopProjectList(items: visible, language: language)
            else
              _MobileProjectList(items: visible, language: language),
          ],
        );
      },
    );
  }
}

class _PortfolioControls extends StatelessWidget {
  const _PortfolioControls({
    required this.language,
    required this.stateFilter,
    required this.search,
    required this.onSearchChanged,
    required this.onStateChanged,
  });

  final AppLanguage language;
  final YorksV1ProjectLifecycle? stateFilter;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<YorksV1ProjectLifecycle?> onStateChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final searchField = TextFormField(
          initialValue: search,
          onChanged: onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            labelText: YorksV1ProjectStrings.searchProjects.primary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
        );
        final filter = DropdownButtonFormField<YorksV1ProjectLifecycle?>(
          initialValue: stateFilter,
          decoration: InputDecoration(
            labelText: YorksV1ProjectStrings.allStates.primary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
          items: [
            DropdownMenuItem<YorksV1ProjectLifecycle?>(
              value: null,
              child: Text(YorksV1ProjectStrings.allStates.primary),
            ),
            for (final value in YorksV1ProjectLifecycle.values)
              DropdownMenuItem(
                value: value,
                child: Text(YorksV1ProjectStrings.stateLabel(value).primary),
              ),
          ],
          onChanged: onStateChanged,
        );
        if (constraints.maxWidth < AppSpacing.compactBreakpoint) {
          return Column(
            children: [
              searchField,
              const SizedBox(height: AppSpacing.md),
              filter,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: AppSpacing.md),
            SizedBox(width: 220, child: filter),
          ],
        );
      },
    );
  }
}

class _DesktopProjectList extends StatelessWidget {
  const _DesktopProjectList({required this.items, required this.language});

  final List<YorksV1ProjectPortfolioItem> items;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _DesktopProjectHeader(),
          const Divider(height: 1, color: AppColors.line),
          for (var index = 0; index < items.length; index++) ...[
            _DesktopProjectRow(item: items[index], language: language),
            if (index + 1 < items.length)
              const Divider(height: 1, color: AppColors.line),
          ],
        ],
      ),
    );
  }
}

class _DesktopProjectHeader extends StatelessWidget {
  const _DesktopProjectHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: _TableHeader(copy: YorksV1ProjectStrings.projects),
          ),
          Expanded(
            flex: 2,
            child: _TableHeader(copy: YorksV1ProjectStrings.state),
          ),
          Expanded(
            flex: 3,
            child: _TableHeader(copy: YorksV1ProjectStrings.site),
          ),
          Expanded(
            flex: 2,
            child: _TableHeader(copy: YorksV1ProjectStrings.activeTeam),
          ),
          Expanded(
            flex: 2,
            child: _TableHeader(copy: YorksV1ProjectStrings.updated),
          ),
          SizedBox(width: AppSpacing.minTapTarget),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.copy});

  final TranslatableString copy;

  @override
  Widget build(BuildContext context) => Text(
    copy.primary,
    style: AppTypography.labelMedium.copyWith(
      color: AppColors.muted,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _DesktopProjectRow extends StatelessWidget {
  const _DesktopProjectRow({required this.item, required this.language});

  final YorksV1ProjectPortfolioItem item;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final project = item.project;
    return Semantics(
      button: true,
      label: YorksV1ProjectStrings.openProject.primary,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(RoutePaths.yorksV1ProjectPath(project.id)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _ProjectIdentity(item: item, language: language),
                ),
                Expanded(
                  flex: 2,
                  child: _ProjectStateChip(state: project.state),
                ),
                Expanded(
                  flex: 3,
                  child: _ValueText(value: project.siteLocation),
                ),
                Expanded(
                  flex: 2,
                  child: _TeamAndBuildings(item: item, compact: true),
                ),
                Expanded(flex: 2, child: _UpdatedText(date: project.updatedAt)),
                SizedBox(
                  width: AppSpacing.minTapTarget,
                  height: AppSpacing.minTapTarget,
                  child: IconButton(
                    tooltip: YorksV1ProjectStrings.openProject.primary,
                    onPressed: () =>
                        context.push(RoutePaths.yorksV1ProjectPath(project.id)),
                    icon: const Icon(Icons.chevron_right_rounded),
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

class _MobileProjectList extends StatelessWidget {
  const _MobileProjectList({required this.items, required this.language});

  final List<YorksV1ProjectPortfolioItem> items;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final item in items) ...[
        _MobileProjectCard(item: item, language: language),
        const SizedBox(height: AppSpacing.md),
      ],
    ],
  );
}

class _MobileProjectCard extends StatelessWidget {
  const _MobileProjectCard({required this.item, required this.language});

  final YorksV1ProjectPortfolioItem item;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final project = item.project;
    return LedgerCard(
      onTap: () => context.push(RoutePaths.yorksV1ProjectPath(project.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ProjectIdentity(item: item, language: language),
              ),
              const SizedBox(width: AppSpacing.sm),
              _ProjectStateChip(state: project.state),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _ValueLine(
            copy: YorksV1ProjectStrings.site,
            value: project.siteLocation,
          ),
          if (item.clientName != null)
            _ValueLine(
              copy: YorksV1ProjectStrings.clientLabel,
              value: item.clientName,
            ),
          const SizedBox(height: AppSpacing.sm),
          _TeamAndBuildings(item: item),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _UpdatedText(date: project.updatedAt)),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectIdentity extends StatelessWidget {
  const _ProjectIdentity({required this.item, required this.language});

  final YorksV1ProjectPortfolioItem item;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        item.project.reference,
        style: AppTypography.labelMedium.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        item.project.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
      ),
      if (item.clientName != null) ...[
        const SizedBox(height: AppSpacing.xxs),
        Text(
          item.clientName!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
        ),
      ],
    ],
  );
}

class _ProjectStateChip extends StatelessWidget {
  const _ProjectStateChip({required this.state});

  final YorksV1ProjectLifecycle state;

  @override
  Widget build(BuildContext context) => StatusChip(
    label: YorksV1ProjectStrings.stateLabel(state).primary,
    tone: switch (state) {
      YorksV1ProjectLifecycle.draft => NexusStatusTone.neutral,
      YorksV1ProjectLifecycle.active => NexusStatusTone.success,
      YorksV1ProjectLifecycle.onHold => NexusStatusTone.warning,
      YorksV1ProjectLifecycle.completed => NexusStatusTone.info,
      YorksV1ProjectLifecycle.archived => NexusStatusTone.neutral,
    },
    icon: switch (state) {
      YorksV1ProjectLifecycle.draft => Icons.edit_note_outlined,
      YorksV1ProjectLifecycle.active => Icons.play_circle_outline_rounded,
      YorksV1ProjectLifecycle.onHold => Icons.pause_circle_outline_rounded,
      YorksV1ProjectLifecycle.completed => Icons.task_alt_rounded,
      YorksV1ProjectLifecycle.archived => Icons.archive_outlined,
    },
  );
}

class _TeamAndBuildings extends StatelessWidget {
  const _TeamAndBuildings({required this.item, this.compact = false});

  final YorksV1ProjectPortfolioItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final team =
        '${item.activeTeamCount} ${YorksV1ProjectStrings.activeTeam.primary}';
    final buildings =
        '${item.activeBuildingCount} ${YorksV1ProjectStrings.buildings.primary}';
    if (compact) {
      return Text(
        '$team · $buildings',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.bodySmall.copyWith(color: AppColors.inkSecondary),
      );
    }
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        _MetricChip(icon: Icons.groups_outlined, label: team),
        _MetricChip(icon: Icons.apartment_outlined, label: buildings),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppColors.muted),
      const SizedBox(width: AppSpacing.xs),
      Text(label, style: AppTypography.labelMedium),
    ],
  );
}

class _UpdatedText extends StatelessWidget {
  const _UpdatedText({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) => Text(
    DateFormat.yMMMd().format(date.toLocal()),
    style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
  );
}

class _ValueText extends StatelessWidget {
  const _ValueText({required this.value});

  final String? value;

  @override
  Widget build(BuildContext context) => Text(
    value?.trim().isNotEmpty == true ? value! : '—',
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: AppTypography.bodySmall.copyWith(color: AppColors.inkSecondary),
  );
}

class _ValueLine extends StatelessWidget {
  const _ValueLine({required this.copy, required this.value});

  final TranslatableString copy;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value?.trim().isNotEmpty != true) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${copy.primary}: ',
              style: AppTypography.labelMedium.copyWith(color: AppColors.muted),
            ),
            TextSpan(
              text: value,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioEmpty extends StatelessWidget {
  const _PortfolioEmpty({
    required this.language,
    required this.canCreate,
    required this.onCreate,
  });

  final AppLanguage language;
  final bool canCreate;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => LedgerCard(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_tree_outlined,
              size: 44,
              color: AppColors.muted,
            ),
            const SizedBox(height: AppSpacing.lg),
            _CopyText(
              copy: YorksV1ProjectStrings.noProjects,
              language: language,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
              center: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            _CopyText(
              copy: YorksV1ProjectStrings.noProjectsDescription,
              language: language,
              center: true,
            ),
            if (canCreate) ...[
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: AppSpacing.minTapTarget,
                child: FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(YorksV1ProjectStrings.createProject.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _NoMatchingProjects extends StatelessWidget {
  const _NoMatchingProjects({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) => LedgerCard(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: _CopyText(
        copy: YorksV1ProjectStrings.noMatchingProjects,
        language: language,
        center: true,
      ),
    ),
  );
}

class _PortfolioError extends StatelessWidget {
  const _PortfolioError({required this.language, required this.onRetry});

  final AppLanguage language;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: LedgerCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 42,
                color: AppColors.warning,
              ),
              const SizedBox(height: AppSpacing.lg),
              _CopyText(
                copy: YorksV1ProjectStrings.portfolioUnavailable,
                language: language,
                center: true,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: AppSpacing.minTapTarget,
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(YorksV1ProjectStrings.retry.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ProjectWorkspaceBody extends StatelessWidget {
  const _ProjectWorkspaceBody({
    required this.item,
    required this.tab,
    required this.language,
    required this.requests,
    required this.scopes,
    required this.groups,
    required this.documents,
    required this.onActivate,
    required this.onNewRequest,
    required this.onEdit,
    required this.onArchive,
    required this.onTabChanged,
  });

  final YorksV1ProjectPortfolioItem item;
  final YorksV1ProjectWorkspaceTab tab;
  final AppLanguage language;
  final AsyncValue<List<YorksV1MaterialRequest>> requests;
  final AsyncValue<List<YorksV1MaterialRequestScopeOption>> scopes;
  final AsyncValue<List<YorksV1BoqGroup>> groups;
  final AsyncValue<YorksV1DocumentWorkspace> documents;
  final VoidCallback? onActivate;
  final VoidCallback? onNewRequest;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final ValueChanged<YorksV1ProjectWorkspaceTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final project = item.project;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop =
            constraints.maxWidth >= AppSpacing.yorksV1DesktopBreakpoint;
        final horizontal = desktop
            ? AppSpacing.xxxl + AppSpacing.xs
            : AppSpacing.lg;
        return ColoredBox(
          color: AppColors.surface,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 72),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProjectR35Hero(
                  project: project,
                  selected: tab,
                  onSelected: onTabChanged,
                  onActivate: onActivate,
                  onNewRequest: onNewRequest,
                  onEdit: onEdit,
                  onArchive: onArchive,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    AppSpacing.xxxl,
                    horizontal,
                    0,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSpacing.pageMaxWidth,
                    ),
                    child: switch (tab) {
                      YorksV1ProjectWorkspaceTab.overview =>
                        _ProjectR35Overview(
                          item: item,
                          groups: groups,
                          requests: requests,
                          scopes: scopes,
                          documents: documents,
                          onOpenBoq: () =>
                              onTabChanged(YorksV1ProjectWorkspaceTab.boq),
                          onOpenRequests: () => context.push(
                            RoutePaths.yorksV1MaterialRequestsPath(
                              projectId: project.id,
                            ),
                          ),
                          onOpenDocuments: () => context.push(
                            RoutePaths.yorksV1ProjectDocumentsPath(project.id),
                          ),
                        ),
                      YorksV1ProjectWorkspaceTab.boq => YorksV1BoqGroupsScreen(
                        projectId: project.id,
                        embedded: true,
                      ),
                      YorksV1ProjectWorkspaceTab.requests => _LinkedRecordCard(
                        icon: Icons.assignment_outlined,
                        title: YorksV1ProjectStrings.materialRequests,
                        action: YorksV1ProjectStrings.openRequests,
                        onOpen: () => context.push(
                          RoutePaths.yorksV1MaterialRequestsPath(
                            projectId: project.id,
                          ),
                        ),
                      ),
                      YorksV1ProjectWorkspaceTab.documents => _LinkedRecordCard(
                        icon: Icons.folder_open_outlined,
                        title: YorksV1ProjectStrings.documents,
                        action: YorksV1ProjectStrings.openDocuments,
                        onOpen: () => context.push(
                          RoutePaths.yorksV1ProjectDocumentsPath(project.id),
                        ),
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProjectR35Hero extends StatelessWidget {
  const _ProjectR35Hero({
    required this.project,
    required this.selected,
    required this.onSelected,
    required this.onActivate,
    required this.onNewRequest,
    required this.onEdit,
    required this.onArchive,
  });

  final YorksV1Project project;
  final YorksV1ProjectWorkspaceTab selected;
  final ValueChanged<YorksV1ProjectWorkspaceTab> onSelected;
  final VoidCallback? onActivate;
  final VoidCallback? onNewRequest;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.navy,
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xxxl + AppSpacing.xs,
      AppSpacing.xxxl,
      AppSpacing.xxxl + AppSpacing.xs,
      0,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 700;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.reference.toUpperCase(),
                  style: AppTypography.eyebrow.copyWith(
                    color: AppColors.blueContainerStrong,
                    letterSpacing: 1.45,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  project.name,
                  style: AppTypography.headlineLarge.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (project.siteLocation?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    project.siteLocation!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.blueContainerStrong,
                    ),
                  ),
                ],
              ],
            );
            final actions = Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (onActivate != null)
                  SizedBox(
                    height: AppSpacing.minTapTarget,
                    child: OutlinedButton.icon(
                      onPressed: onActivate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.onPrimary,
                        side: const BorderSide(color: AppColors.lineStrong),
                      ),
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      label: Text(
                        YorksV1ProjectStrings.activateProject.primary,
                      ),
                    ),
                  ),
                if (onNewRequest != null)
                  SizedBox(
                    height: AppSpacing.minTapTarget,
                    child: FilledButton.icon(
                      onPressed: onNewRequest,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerLowest,
                        foregroundColor: AppColors.navy,
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(
                        YorksV1MaterialRequestStrings.newRequest.primary,
                      ),
                    ),
                  ),
                if (onEdit != null)
                  SizedBox(
                    height: AppSpacing.minTapTarget,
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.onPrimary,
                        side: const BorderSide(color: AppColors.lineStrong),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(YorksV1ProjectStrings.editProject.primary),
                    ),
                  ),
                if (onArchive != null)
                  SizedBox(
                    height: AppSpacing.minTapTarget,
                    child: TextButton.icon(
                      onPressed: onArchive,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.errorContainer,
                      ),
                      icon: const Icon(Icons.archive_outlined),
                      label: Text(
                        YorksV1ProjectStrings.safeDeleteProject.primary,
                      ),
                    ),
                  ),
              ],
            );
            return stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      copy,
                      const SizedBox(height: AppSpacing.lg),
                      actions,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: copy),
                      actions,
                    ],
                  );
          },
        ),
        const SizedBox(height: AppSpacing.xxl),
        _ProjectWorkspaceTabs(selected: selected, onSelected: onSelected),
      ],
    ),
  );
}

class _ProjectWorkspaceTabs extends StatelessWidget {
  const _ProjectWorkspaceTabs({
    required this.selected,
    required this.onSelected,
  });

  final YorksV1ProjectWorkspaceTab selected;
  final ValueChanged<YorksV1ProjectWorkspaceTab> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final tab in YorksV1ProjectWorkspaceTab.values)
          _ProjectWorkspaceTabButton(
            label: _tabCopy(tab).primary,
            selected: selected == tab,
            onPressed: () => onSelected(tab),
          ),
      ],
    ),
  );

  TranslatableString _tabCopy(YorksV1ProjectWorkspaceTab tab) {
    return switch (tab) {
      YorksV1ProjectWorkspaceTab.overview => YorksV1ProjectStrings.overview,
      YorksV1ProjectWorkspaceTab.boq => YorksV1ProjectStrings.boq,
      YorksV1ProjectWorkspaceTab.requests =>
        YorksV1ProjectStrings.materialRequests,
      YorksV1ProjectWorkspaceTab.documents => YorksV1ProjectStrings.documents,
    };
  }
}

class _ProjectWorkspaceTabButton extends StatelessWidget {
  const _ProjectWorkspaceTabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      hoverColor: AppColors.onPrimary.withValues(alpha: .07),
      focusColor: AppColors.onPrimary.withValues(alpha: .10),
      highlightColor: AppColors.onPrimary.withValues(alpha: .06),
      splashColor: AppColors.onPrimary.withValues(alpha: .08),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? AppColors.blueContainerStrong
                  : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelLarge.copyWith(
            color: selected ? AppColors.onPrimary : AppColors.lineStrong,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

class _ProjectR35Overview extends StatelessWidget {
  const _ProjectR35Overview({
    required this.item,
    required this.groups,
    required this.requests,
    required this.scopes,
    required this.documents,
    required this.onOpenBoq,
    required this.onOpenRequests,
    required this.onOpenDocuments,
  });

  final YorksV1ProjectPortfolioItem item;
  final AsyncValue<List<YorksV1BoqGroup>> groups;
  final AsyncValue<List<YorksV1MaterialRequest>> requests;
  final AsyncValue<List<YorksV1MaterialRequestScopeOption>> scopes;
  final AsyncValue<YorksV1DocumentWorkspace> documents;
  final VoidCallback onOpenBoq;
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenDocuments;

  @override
  Widget build(BuildContext context) {
    final groupItems = groups.valueOrNull ?? const <YorksV1BoqGroup>[];
    final requestItems =
        requests.valueOrNull ?? const <YorksV1MaterialRequest>[];
    final documentItems =
        documents.valueOrNull?.documents ?? const <YorksV1Document>[];
    final boqItems = groupItems.fold<int>(
      0,
      (total, group) => total + group.rowCount,
    );
    final openRequests = requestItems
        .where(
          (request) =>
              request.state != YorksV1MaterialRequestState.received &&
              request.state != YorksV1MaterialRequestState.closed &&
              request.state != YorksV1MaterialRequestState.cancelled,
        )
        .length;
    final buildingItems = (scopes.valueOrNull ?? const [])
        .where((scope) => !scope.isCommon)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProjectMetricGrid(
          metrics: [
            _ProjectMetric(
              label: YorksV1ProjectStrings.boqGroups.primary,
              value: '${groupItems.length}',
              detail: YorksV1ProjectStrings.foldersOfMaterials.primary,
            ),
            _ProjectMetric(
              label: YorksV1ProjectStrings.boqItems.primary,
              value: '$boqItems',
              detail: YorksV1ProjectStrings.availableToRequest.primary,
            ),
            _ProjectMetric(
              label: YorksV1ProjectStrings.requests.primary,
              value: '${requestItems.length}',
              detail:
                  '$openRequests ${YorksV1ProjectStrings.currentlyOpen.primary}',
            ),
            _ProjectMetric(
              label: YorksV1ProjectStrings.documents.primary,
              value: '${documentItems.length}',
              detail: YorksV1ProjectStrings.projectLevelFiles.primary,
            ),
            _ProjectMetric(
              label: YorksV1ProjectStrings.buildings.primary,
              value: '${item.activeBuildingCount}',
              detail: YorksV1ProjectStrings.plusCommonScope.primary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _ProjectR35Guide(),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final cards = [
              _ProjectModuleCard(
                icon: Icons.folder_outlined,
                title: YorksV1ProjectStrings.boq,
                badge:
                    '${groupItems.length} ${YorksV1ProjectStrings.groups.primary}',
                description: YorksV1ProjectStrings.boqModuleDescription.primary,
                primaryMetric: YorksV1ProjectStrings.items.primary,
                primaryValue: '$boqItems',
                secondaryMetric: YorksV1ProjectStrings.ready.primary,
                secondaryValue: '$boqItems',
                onOpen: onOpenBoq,
              ),
              _ProjectModuleCard(
                icon: Icons.assignment_outlined,
                title: YorksV1ProjectStrings.materialRequests,
                badge:
                    '$openRequests ${YorksV1ProjectStrings.currentlyOpen.primary}',
                description:
                    YorksV1ProjectStrings.requestsModuleDescription.primary,
                primaryMetric: YorksV1ProjectStrings.total.primary,
                primaryValue: '${requestItems.length}',
                secondaryMetric: YorksV1ProjectStrings.received.primary,
                secondaryValue:
                    '${requestItems.where((item) => item.state == YorksV1MaterialRequestState.received).length}',
                onOpen: onOpenRequests,
              ),
              _ProjectModuleCard(
                icon: Icons.description_outlined,
                title: YorksV1ProjectStrings.documents,
                badge:
                    '${documentItems.length} ${YorksV1ProjectStrings.files.primary}',
                description:
                    YorksV1ProjectStrings.documentsModuleDescription.primary,
                primaryMetric: YorksV1ProjectStrings.files.primary,
                primaryValue: '${documentItems.length}',
                secondaryMetric: YorksV1ProjectStrings.links.primary,
                secondaryValue:
                    '${documentItems.fold<int>(0, (total, item) => total + item.links.length)}',
                onOpen: onOpenDocuments,
              ),
            ];
            return wide
                ? Row(
                    // This lives inside the page's vertical scroll view, so
                    // it has an unbounded height. `stretch` would force the
                    // module cards to an infinite height on web. Their common
                    // minimum height keeps the R35 row visually consistent
                    // without making the scroll viewport invalid.
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0; index < cards.length; index++) ...[
                        Expanded(child: cards[index]),
                        if (index != cards.length - 1)
                          const SizedBox(width: AppSpacing.lg),
                      ],
                    ],
                  )
                : Column(
                    children: [
                      for (var index = 0; index < cards.length; index++) ...[
                        cards[index],
                        if (index != cards.length - 1)
                          const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  );
          },
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    YorksV1ProjectStrings.recentMaterialRequests.primary,
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    YorksV1ProjectStrings.recentRequestsDescription.primary,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: AppSpacing.minTapTarget,
              child: OutlinedButton(
                onPressed: onOpenRequests,
                child: Text(YorksV1ShellStrings.viewAll.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _RecentProjectRequests(
          requests: requests,
          onOpenRequests: onOpenRequests,
        ),
        const SizedBox(height: AppSpacing.xxxl),
        _ProjectInformationSection(item: item, buildings: buildingItems),
      ],
    );
  }
}

class _ProjectInformationSection extends StatelessWidget {
  const _ProjectInformationSection({
    required this.item,
    required this.buildings,
  });

  final YorksV1ProjectPortfolioItem item;
  final List<YorksV1MaterialRequestScopeOption> buildings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final team = _ProjectTeamCard(item: item);
        final buildingCard = _ProjectBuildingsCard(
          buildings: buildings,
          count: item.activeBuildingCount,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              YorksV1ProjectStrings.projectInformation.primary,
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: team),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: buildingCard),
                ],
              )
            else ...[
              team,
              const SizedBox(height: AppSpacing.md),
              buildingCard,
            ],
          ],
        );
      },
    );
  }
}

class _ProjectTeamCard extends ConsumerWidget {
  const _ProjectTeamCard({required this.item});

  final YorksV1ProjectPortfolioItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final authUserId = ref.watch(yorksV1AuthUserIdProvider);
    final hasProjectEngineerMembership =
        authUserId != null &&
        item.activeMembers.any(
          (member) =>
              member.memberAuthUserId == authUserId &&
              member.projectRole ==
                  YorksV1ProjectMembershipRole.projectEngineer,
        );
    final canManage =
        role == YorksV1Role.admin ||
        (role?.isGlobalProjectEngineer ?? false) ||
        hasProjectEngineerMembership;
    final directory = canManage
        ? ref.watch(yorksV1ActiveProjectTeamDirectoryProvider)
        : null;
    final names = {
      for (final member in directory?.valueOrNull ?? const [])
        member.authUserId: member.displayName,
    };
    String namesFor(YorksV1ProjectMembershipRole projectRole, int fallback) {
      final selected = item.activeMembers
          .where((member) => member.projectRole == projectRole)
          .map(
            (member) =>
                names[member.memberAuthUserId] ??
                YorksV1ProjectStrings.notAssigned.primary,
          )
          .toList(growable: false);
      return selected.isEmpty ? '$fallback' : selected.join(', ');
    }

    return _ProjectInfoCard(
      title: YorksV1ProjectStrings.projectTeam.primary,
      subtitle: YorksV1ProjectStrings.projectTeamDescription.primary,
      action: canManage
          ? OutlinedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _ProjectTeamAssignmentDialog(item: item),
              ),
              icon: const Icon(Icons.groups_outlined),
              label: Text(YorksV1ProjectStrings.manageTeam.primary),
            )
          : null,
      children: [
        _ProjectInfoRow(
          label: YorksV1ProjectStrings.yorksReference.primary,
          value: item.project.reference,
        ),
        _ProjectInfoRow(
          label: YorksV1ProjectStrings.projectEngineers.primary,
          value: namesFor(
            YorksV1ProjectMembershipRole.projectEngineer,
            item.activeProjectEngineerCount,
          ),
        ),
        _ProjectInfoRow(
          label: YorksV1ProjectStrings.siteEngineers.primary,
          value: namesFor(
            YorksV1ProjectMembershipRole.siteEngineer,
            item.activeSiteEngineerCount,
          ),
        ),
        _ProjectInfoRow(
          label: YorksV1ProjectStrings.procurementOwner.primary,
          value: YorksV1ProjectStrings.notAssigned.primary,
        ),
      ],
    );
  }
}

class _ProjectTeamAssignmentDialog extends ConsumerStatefulWidget {
  const _ProjectTeamAssignmentDialog({required this.item});

  final YorksV1ProjectPortfolioItem item;

  @override
  ConsumerState<_ProjectTeamAssignmentDialog> createState() =>
      _ProjectTeamAssignmentDialogState();
}

class _ProjectTeamAssignmentDialogState
    extends ConsumerState<_ProjectTeamAssignmentDialog> {
  Map<String, YorksV1ProjectMembershipRole?> _selectedRoles = const {};
  bool _seeded = false;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final directory = ref.watch(yorksV1ActiveProjectTeamDirectoryProvider);
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: Column(
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
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          YorksV1ProjectStrings.manageProjectTeamTitle.primary,
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${widget.item.project.reference} · ${YorksV1ProjectStrings.teamChangesAudited.primary}',
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
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: directory.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => Text(
                    YorksV1ProjectStrings.teamDirectoryUnavailable.primary,
                  ),
                  data: (members) {
                    final current = {
                      for (final member in widget.item.activeMembers)
                        member.memberAuthUserId: member.projectRole,
                    };
                    if (!_seeded) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _selectedRoles = current;
                            _seeded = true;
                          });
                        }
                      });
                    }
                    final selected = _seeded ? _selectedRoles : current;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _ProjectTeamPermissionBanner(),
                        const SizedBox(height: AppSpacing.lg),
                        for (final member in members) ...[
                          _ProjectTeamRoleRow(
                            member: member,
                            value: selected[member.authUserId],
                            enabled: !_saving,
                            onChanged: (value) => setState(() {
                              _selectedRoles = {
                                ...selected,
                                member.authUserId: value,
                              };
                              _error = null;
                            }),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        if (members.isEmpty)
                          Text(
                            YorksV1ProjectStrings.noEligibleTeamMembers.primary,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _error!,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(YorksV1ProjectStrings.cancel.primary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(YorksV1ProjectStrings.saveProjectTeam.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final current = {
      for (final member in widget.item.activeMembers)
        member.memberAuthUserId: member.projectRole,
    };
    if (widget.item.project.state == YorksV1ProjectLifecycle.active &&
        !_selectedRoles.values.contains(
          YorksV1ProjectMembershipRole.projectEngineer,
        )) {
      setState(
        () => _error = YorksV1ProjectStrings.initialProjectEngineerHint.primary,
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var version = widget.item.project.recordVersion;
      final controller = ref.read(
        yorksV1ProjectCommandControllerProvider.notifier,
      );
      for (final entry in _selectedRoles.entries) {
        final targetRole = entry.value;
        if (targetRole == null || current[entry.key] == targetRole) continue;
        final result = await controller.assignProjectMember(
          YorksV1AssignProjectMemberInput(
            idempotencyKey: const Uuid().v4(),
            projectId: widget.item.project.id,
            memberAuthUserId: entry.key,
            projectRole: targetRole,
            expectedProjectVersion: version,
            reason: YorksV1ProjectStrings.projectTeamChangeReason.primary,
          ),
        );
        version = result.project.recordVersion;
      }
      for (final entry in current.entries) {
        if (_selectedRoles[entry.key] != null) continue;
        final result = await controller.revokeProjectMember(
          YorksV1RevokeProjectMemberInput(
            idempotencyKey: const Uuid().v4(),
            projectId: widget.item.project.id,
            memberAuthUserId: entry.key,
            projectRole: entry.value,
            expectedProjectVersion: version,
            reason: YorksV1ProjectStrings.projectTeamChangeReason.primary,
          ),
        );
        version = result.project.recordVersion;
      }
      ref.invalidate(yorksV1ProjectPortfolioProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(YorksV1ProjectStrings.projectTeamUpdated.primary),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = YorksV1ProjectStrings.teamDirectoryUnavailable.primary;
        });
      }
    }
  }
}

class _ProjectTeamPermissionBanner extends StatelessWidget {
  const _ProjectTeamPermissionBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.blueContainer.withValues(alpha: .48),
      border: Border.all(color: AppColors.blueContainerStrong),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.verified_user_outlined, color: AppColors.blue),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                YorksV1ProjectStrings.projectTeamPermissionRule.primary,
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                YorksV1ProjectStrings.projectTeamPermissionDescription.primary,
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProjectTeamRoleRow extends StatelessWidget {
  const _ProjectTeamRoleRow({
    required this.member,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final YorksV1ProjectTeamDirectoryMember member;
  final YorksV1ProjectMembershipRole? value;
  final bool enabled;
  final ValueChanged<YorksV1ProjectMembershipRole?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final identity = Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.blueContainer,
              foregroundColor: AppColors.blue,
              child: Text(_memberInitials(member.displayName)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    style: AppTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    YorksV1ProjectStrings.roleLabel(
                      member.eligibleRole.claimValue,
                    ).primary,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final selector = DropdownButtonFormField<YorksV1ProjectMembershipRole?>(
          key: ValueKey('${member.authUserId}-${value?.wireValue ?? 'none'}'),
          initialValue: value,
          decoration: const InputDecoration(isDense: true),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(YorksV1ProjectStrings.noProjectAccess.primary),
            ),
            DropdownMenuItem(
              value: YorksV1ProjectMembershipRole.projectEngineer,
              child: Text(YorksV1ProjectStrings.projectEngineerRole.primary),
            ),
            DropdownMenuItem(
              value: YorksV1ProjectMembershipRole.siteEngineer,
              child: Text(YorksV1ProjectStrings.siteEngineerRole.primary),
            ),
          ],
          onChanged: enabled ? onChanged : null,
        );
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              const SizedBox(height: AppSpacing.md),
              selector,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: identity),
            const SizedBox(width: AppSpacing.lg),
            SizedBox(width: 290, child: selector),
          ],
        );
      },
    ),
  );
}

String _memberInitials(String displayName) {
  final parts = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

class _ProjectBuildingsCard extends StatelessWidget {
  const _ProjectBuildingsCard({required this.buildings, required this.count});

  final List<YorksV1MaterialRequestScopeOption> buildings;
  final int count;

  @override
  Widget build(BuildContext context) => _ProjectInfoCard(
    title: YorksV1ProjectStrings.buildings.primary,
    subtitle: YorksV1ProjectStrings.buildingsDescription.primary,
    badge: '$count ${YorksV1ProjectStrings.buildings.primary.toLowerCase()}',
    children: [
      if (buildings.isEmpty)
        Text(
          YorksV1ProjectStrings.noBuildingsAdded.primary,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
        )
      else
        for (final building in buildings.take(6))
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                const Icon(Icons.business_outlined, color: AppColors.blue),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    building.name,
                    style: AppTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (building.deliveryAddress?.isNotEmpty == true)
                  Text(
                    'FRP',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.success,
                    ),
                  ),
              ],
            ),
          ),
    ],
  );
}

class _ProjectInfoCard extends StatelessWidget {
  const _ProjectInfoCard({
    required this.title,
    required this.subtitle,
    required this.children,
    this.action,
    this.badge,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? action;
  final String? badge;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 16,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (badge case final value?) _ProjectBadge(label: value),
            if (action case final Widget value) value,
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.md),
        ...children,
      ],
    ),
  );
}

class _ProjectInfoRow extends StatelessWidget {
  const _ProjectInfoRow({required this.label, required this.value});

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
            letterSpacing: .75,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ProjectBadge extends StatelessWidget {
  const _ProjectBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: AppSpacing.sm),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.blueContainer,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
    ),
    child: Text(
      label,
      style: AppTypography.labelSmall.copyWith(
        color: AppColors.blue,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _ProjectMetric {
  const _ProjectMetric({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;
}

class _ProjectMetricGrid extends StatelessWidget {
  const _ProjectMetricGrid({required this.metrics});

  final List<_ProjectMetric> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = constraints.maxWidth >= 1280
          ? 5
          : constraints.maxWidth >= 760
          ? 3
          : 1;
      return GridView.count(
        crossAxisCount: count,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        // The compact metrics include a label, value and explanatory line.
        // Leave enough vertical room for the 360px screen instead of clipping
        // the explanatory line in a desktop-tuned aspect ratio.
        childAspectRatio: count == 1 ? 2.9 : 1.7,
        children: [
          for (final metric in metrics)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 16,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    metric.label.toUpperCase(),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .95,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    metric.value,
                    style: AppTypography.headlineMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    metric.detail,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _ProjectR35Guide extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.blueContainer.withValues(alpha: .48),
      border: Border.all(color: AppColors.blueContainerStrong),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.checklist_rounded, color: AppColors.blue, size: 25),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                YorksV1ProjectStrings.workspaceGuide.primary,
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                YorksV1ProjectStrings.workspaceGuideDescription.primary,
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProjectModuleCard extends StatelessWidget {
  const _ProjectModuleCard({
    required this.icon,
    required this.title,
    required this.badge,
    required this.description,
    required this.primaryMetric,
    required this.primaryValue,
    required this.secondaryMetric,
    required this.secondaryValue,
    required this.onOpen,
  });

  final IconData icon;
  final TranslatableString title;
  final String badge;
  final String description;
  final String primaryMetric;
  final String primaryValue;
  final String secondaryMetric;
  final String secondaryValue;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        constraints: const BoxConstraints(minHeight: 244),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.blueContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(icon, color: AppColors.blue),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blueContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    badge,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title.primary,
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              description,
              style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
            ),
            // The workspace is vertically scrollable, so the card receives an
            // unbounded max height. Keep deliberate breathing room rather
            // than using a flex spacer, which would make web layout fail.
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _ModuleMetric(
                    label: primaryMetric,
                    value: primaryValue,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _ModuleMetric(
                    label: secondaryMetric,
                    value: secondaryValue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ModuleMetric extends StatelessWidget {
  const _ModuleMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _RecentProjectRequests extends StatelessWidget {
  const _RecentProjectRequests({
    required this.requests,
    required this.onOpenRequests,
  });

  final AsyncValue<List<YorksV1MaterialRequest>> requests;
  final VoidCallback onOpenRequests;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 138),
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
    child: requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Text(
          YorksV1ProjectStrings.requestsUnavailable.primary,
          style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text(
              YorksV1ProjectStrings.noRecentRequests.primary,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
            ),
          );
        }
        final request = items.first;
        return InkWell(
          onTap: onOpenRequests,
          child: Row(
            children: [
              Container(
                width: AppSpacing.minTapTarget,
                height: AppSpacing.minTapTarget,
                decoration: BoxDecoration(
                  color: AppColors.blueContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.requestNumber ??
                          YorksV1MaterialRequestStrings.draft.primary,
                      style: AppTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${request.scopeName} · ${request.lines.length} ${YorksV1MaterialRequestStrings.items.primary.toLowerCase()}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        );
      },
    ),
  );
}

class _LinkedRecordCard extends StatelessWidget {
  const _LinkedRecordCard({
    required this.icon,
    required this.title,
    required this.action,
    required this.onOpen,
  });

  final IconData icon;
  final TranslatableString title;
  final TranslatableString action;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => LedgerCard(
    child: Row(
      children: [
        Container(
          width: AppSpacing.minTapTarget,
          height: AppSpacing.minTapTarget,
          decoration: BoxDecoration(
            color: AppColors.blueContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            title.primary,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          height: AppSpacing.minTapTarget,
          child: OutlinedButton(onPressed: onOpen, child: Text(action.primary)),
        ),
      ],
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
