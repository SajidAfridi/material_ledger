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
import '../../../../shared/models/yorks_v1_project_portfolio.dart';
import '../../../../shared/models/yorks_v1_project_strings.dart';
import '../../../../shared/models/yorks_v1_role.dart';
import '../../../../shared/models/yorks_v1_material_request.dart';
import '../../../../shared/models/yorks_v1_material_request_strings.dart';
import '../../../../shared/models/yorks_v1_shell_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/session_provider.dart';
import '../../../../shared/providers/yorks_v1_identity_provider.dart';
import '../../../../shared/providers/yorks_v1_material_request_provider.dart';
import '../../../../shared/providers/yorks_v1_boq_provider.dart';
import '../../../../shared/providers/yorks_v1_documents_provider.dart';
import '../../../../shared/providers/yorks_v1_project_controller_provider.dart';
import '../../../../shared/providers/yorks_v1_project_portfolio_provider.dart';

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
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final user = ref.watch(currentUserProvider);
    final projects = ref.watch(yorksV1ProjectPortfolioProvider);
    final requests = ref.watch(yorksV1MaterialRequestListProvider(null));
    final canCreateProject = role?.canCreateProject == true;
    final canCreateRequest = role?.canCreateMaterialRequest == true;
    final procurement = role == YorksV1Role.procurement;

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
    final dispatchReady = requestItems
        .where(
          (item) =>
              item.state == YorksV1MaterialRequestState.approved ||
              item.state == YorksV1MaterialRequestState.partiallyDispatched,
        )
        .length;

    return _R35OverviewPage(
      displayName: user?.fullName,
      projects: projects,
      requests: requests,
      projectCount: projectItems.length,
      openRequests: openRequests,
      dispatchReady: dispatchReady,
      canCreateProject: canCreateProject,
      canCreateRequest: canCreateRequest,
      procurement: procurement,
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
    required this.displayName,
    required this.projects,
    required this.requests,
    required this.projectCount,
    required this.openRequests,
    required this.dispatchReady,
    required this.canCreateProject,
    required this.canCreateRequest,
    required this.procurement,
    required this.onCreateProject,
    required this.onCreateRequest,
    required this.onOpenProjects,
    required this.onOpenRequests,
    required this.onRetryProjects,
    required this.onRetryRequests,
  });

  final String? displayName;
  final AsyncValue<List<YorksV1ProjectPortfolioItem>> projects;
  final AsyncValue<List<YorksV1MaterialRequest>> requests;
  final int projectCount;
  final int openRequests;
  final int dispatchReady;
  final bool canCreateProject;
  final bool canCreateRequest;
  final bool procurement;
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
        onOpenRequests: onOpenRequests,
        onOpenProjects: onOpenProjects,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop =
            constraints.maxWidth >= AppSpacing.yorksV1DesktopBreakpoint;
        final name = (displayName ?? '').trim().split(RegExp(r'\s+')).first;
        final safeName = name.isEmpty
            ? YorksV1ShellStrings.companyName.primary
            : name;
        final horizontal = desktop
            ? AppSpacing.xxxl + AppSpacing.xs
            : AppSpacing.lg;
        final contentWidth = (constraints.maxWidth - horizontal * 2).clamp(
          0.0,
          AppSpacing.pageMaxWidth,
        );
        return ColoredBox(
          color: AppColors.surface,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              AppSpacing.xxxl,
              horizontal,
              72,
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
                  const SizedBox(height: AppSpacing.xxxl),
                  _R35SectionHeading(
                    title: YorksV1ShellStrings.needsYourAction.primary,
                    description:
                        YorksV1ShellStrings.roleActionDescription.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _R35ActionCard(requests: requests, onRetry: onRetryRequests),
                  const SizedBox(height: AppSpacing.xxxl),
                  _R35SectionHeading(
                    title: YorksV1ProjectStrings.projects.primary,
                    action: YorksV1ShellStrings.viewAll.primary,
                    onAction: onOpenProjects,
                  ),
                  const SizedBox(height: AppSpacing.md),
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
    required this.onOpenRequests,
    required this.onOpenProjects,
  });

  final AsyncValue<List<YorksV1MaterialRequest>> requests;
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
            constraints.maxWidth >= AppSpacing.yorksV1DesktopBreakpoint;
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
                              value: '0',
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
      final stacked = constraints.maxWidth < 800;
      final main = _R35Card(
        minHeight: stacked ? null : 314,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              YorksV1ShellStrings.goodAfternoon.primary.toUpperCase(),
              style: AppTypography.eyebrow.copyWith(
                color: AppColors.blueContainerStrong,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$name, ${YorksV1ShellStrings.workspaceReady.primary}',
              style: AppTypography.headlineLarge.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.1,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              procurement
                  ? YorksV1ShellStrings.projectCloseoutDescription.primary
                  : YorksV1ShellStrings.overviewWorkspaceDescription.primary,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (canCreateProject)
                  _R35PrimaryAction(
                    label: YorksV1ProjectStrings.createProject.primary,
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
        minHeight: stacked ? null : 314,
        child: Column(
          children: [
            _R35SnapshotTile(
              label: YorksV1ProjectStrings.projects.primary,
              value: '$projectCount',
            ),
            const SizedBox(height: AppSpacing.md),
            _R35SnapshotTile(
              label: YorksV1ShellStrings.needsYourAction.primary,
              value: '$openRequests',
            ),
            const SizedBox(height: AppSpacing.md),
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
            const SizedBox(height: AppSpacing.md),
            snapshot,
          ],
        );
      }
      // Let the cards grow to their content height. A fixed-height row makes
      // the hero overflow when the headline wraps (and can cascade into the
      // RenderBox `hasSize` assertion on narrower desktop windows).
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: main),
            const SizedBox(width: AppSpacing.lg),
            Expanded(flex: 2, child: snapshot),
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
    this.padding = const EdgeInsets.all(AppSpacing.xxxl),
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
    padding: const EdgeInsets.all(AppSpacing.lg),
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
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style:
              (valueText ? AppTypography.titleSmall : AppTypography.titleLarge)
                  .copyWith(color: AppColors.ink, fontWeight: FontWeight.w800),
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
    height: 52,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 20),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.navy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd + 2),
        ),
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
    height: 52,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 19),
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
}

class _R35SectionHeading extends StatelessWidget {
  const _R35SectionHeading({
    required this.title,
    this.description,
    this.action,
    this.onAction,
  });

  final String title;
  final String? description;
  final String? action;
  final VoidCallback? onAction;

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
        ),
      ),
      if (action != null && onAction != null)
        SizedBox(
          height: AppSpacing.minTapTarget,
          child: OutlinedButton(onPressed: onAction, child: Text(action!)),
        ),
    ],
  );
}

class _R35ActionCard extends StatelessWidget {
  const _R35ActionCard({required this.requests, required this.onRetry});

  final AsyncValue<List<YorksV1MaterialRequest>> requests;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _R35Card(
    minHeight: 300,
    child: requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _OverviewRetry(onRetry: onRetry),
      data: (items) {
        final actionable = items
            .where((item) => item.state != YorksV1MaterialRequestState.draft)
            .take(5)
            .toList();
        if (actionable.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_rounded,
                  color: AppColors.blueContainerStrong,
                  size: 40,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  YorksV1ShellStrings.nothingWaiting.primary,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  YorksV1ShellStrings.nothingWaitingDescription.primary,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
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

class _R35ProjectPanel extends StatelessWidget {
  const _R35ProjectPanel({required this.projects, required this.onRetry});

  final AsyncValue<List<YorksV1ProjectPortfolioItem>> projects;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _R35Card(
    child: projects.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => _OverviewRetry(onRetry: onRetry),
      data: (items) => items.isEmpty
          ? _OverviewEmpty(
              icon: Icons.account_tree_outlined,
              copy: YorksV1ProjectStrings.noProjects,
            )
          : Column(
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

class _OverviewEmpty extends StatelessWidget {
  const _OverviewEmpty({required this.icon, required this.copy});

  final IconData icon;
  final TranslatableString copy;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.muted, size: 36),
        const SizedBox(height: AppSpacing.md),
        Text(
          copy.primary,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
        ),
      ],
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

class YorksV1ProjectWorkspaceScreen extends ConsumerStatefulWidget {
  const YorksV1ProjectWorkspaceScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<YorksV1ProjectWorkspaceScreen> createState() =>
      _YorksV1ProjectWorkspaceScreenState();
}

class _YorksV1ProjectWorkspaceScreenState
    extends ConsumerState<YorksV1ProjectWorkspaceScreen> {
  _ProjectWorkspaceTab _tab = _ProjectWorkspaceTab.overview;

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final portfolio = ref.watch(yorksV1ProjectPortfolioProvider);
    final requests = ref.watch(
      yorksV1MaterialRequestListProvider(widget.projectId),
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
            return _ProjectWorkspaceBody(
              item: selectedProject,
              tab: _tab,
              language: language,
              requests: requests,
              groups: groups,
              documents: documents,
              onActivate:
                  selectedProject.project.state == YorksV1ProjectLifecycle.draft
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
              onTabChanged: (value) {
                // The R35 workspace treats BOQ as a full-screen worksheet
                // workspace. Open it directly from the project tab instead of
                // rendering a second "Open BOQ" card inside the page.
                if (value == _ProjectWorkspaceTab.boq) {
                  context.push(
                    RoutePaths.yorksV1BoqGroupsPath(widget.projectId),
                  );
                  return;
                }
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

enum _ProjectWorkspaceTab { overview, boq, requests, documents }

class _ProjectWorkspaceBody extends StatelessWidget {
  const _ProjectWorkspaceBody({
    required this.item,
    required this.tab,
    required this.language,
    required this.requests,
    required this.groups,
    required this.documents,
    required this.onActivate,
    required this.onNewRequest,
    required this.onTabChanged,
  });

  final YorksV1ProjectPortfolioItem item;
  final _ProjectWorkspaceTab tab;
  final AppLanguage language;
  final AsyncValue<List<YorksV1MaterialRequest>> requests;
  final AsyncValue<List<YorksV1BoqGroup>> groups;
  final AsyncValue<YorksV1DocumentWorkspace> documents;
  final VoidCallback? onActivate;
  final VoidCallback? onNewRequest;
  final ValueChanged<_ProjectWorkspaceTab> onTabChanged;

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
                      _ProjectWorkspaceTab.overview => _ProjectR35Overview(
                        item: item,
                        groups: groups,
                        requests: requests,
                        documents: documents,
                        onOpenBoq: () => context.push(
                          RoutePaths.yorksV1BoqGroupsPath(project.id),
                        ),
                        onOpenRequests: () => context.push(
                          RoutePaths.yorksV1MaterialRequestsPath(
                            projectId: project.id,
                          ),
                        ),
                        onOpenDocuments: () => context.push(
                          RoutePaths.yorksV1ProjectDocumentsPath(project.id),
                        ),
                      ),
                      _ProjectWorkspaceTab.boq => _LinkedRecordCard(
                        icon: Icons.table_chart_outlined,
                        title: YorksV1ProjectStrings.boq,
                        action: YorksV1ProjectStrings.openBoq,
                        onOpen: () => context.push(
                          RoutePaths.yorksV1BoqGroupsPath(project.id),
                        ),
                      ),
                      _ProjectWorkspaceTab.requests => _LinkedRecordCard(
                        icon: Icons.assignment_outlined,
                        title: YorksV1ProjectStrings.materialRequests,
                        action: YorksV1ProjectStrings.openRequests,
                        onOpen: () => context.push(
                          RoutePaths.yorksV1MaterialRequestsPath(
                            projectId: project.id,
                          ),
                        ),
                      ),
                      _ProjectWorkspaceTab.documents => _LinkedRecordCard(
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
  });

  final YorksV1Project project;
  final _ProjectWorkspaceTab selected;
  final ValueChanged<_ProjectWorkspaceTab> onSelected;
  final VoidCallback? onActivate;
  final VoidCallback? onNewRequest;

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

  final _ProjectWorkspaceTab selected;
  final ValueChanged<_ProjectWorkspaceTab> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final tab in _ProjectWorkspaceTab.values)
          _ProjectWorkspaceTabButton(
            label: _tabCopy(tab).primary,
            selected: selected == tab,
            onPressed: () => onSelected(tab),
          ),
      ],
    ),
  );

  TranslatableString _tabCopy(_ProjectWorkspaceTab tab) {
    return switch (tab) {
      _ProjectWorkspaceTab.overview => YorksV1ProjectStrings.overview,
      _ProjectWorkspaceTab.boq => YorksV1ProjectStrings.boq,
      _ProjectWorkspaceTab.requests => YorksV1ProjectStrings.materialRequests,
      _ProjectWorkspaceTab.documents => YorksV1ProjectStrings.documents,
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
    child: InkWell(
      onTap: onPressed,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        alignment: Alignment.center,
        decoration: BoxDecoration(
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
    required this.documents,
    required this.onOpenBoq,
    required this.onOpenRequests,
    required this.onOpenDocuments,
  });

  final YorksV1ProjectPortfolioItem item;
  final AsyncValue<List<YorksV1BoqGroup>> groups;
  final AsyncValue<List<YorksV1MaterialRequest>> requests;
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
      ],
    );
  }
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
