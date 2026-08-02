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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop =
          constraints.maxWidth >= AppSpacing.yorksV1DesktopBreakpoint;
      final name = (displayName ?? '').trim().split(RegExp(r'\\s+')).first;
      final safeName = name.isEmpty
          ? YorksV1ShellStrings.companyName.primary
          : name;
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
                _R35ProjectPanel(projects: projects, onRetry: onRetryProjects),
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
                color: const Color(0xFF82B7F4),
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
            const Spacer(),
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
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: main),
          const SizedBox(width: AppSpacing.lg),
          Expanded(flex: 2, child: snapshot),
        ],
      );
    },
  );
}

class _R35Card extends StatelessWidget {
  const _R35Card({required this.child, this.minHeight});

  final Widget child;
  final double? minHeight;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: minHeight ?? 0),
    padding: const EdgeInsets.all(AppSpacing.xxxl),
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
                  color: Color(0xFF9ABEE9),
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
      onTap: () => context.push(RoutePaths.yorksV1MaterialRequestPath(item.id)),
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
    final portfolio = ref.watch(yorksV1ProjectPortfolioProvider);
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
            return _ProjectWorkspaceBody(
              item: project,
              tab: _tab,
              language: language,
              onTabChanged: (value) => setState(() => _tab = value),
            );
          },
        ),
      ),
    );
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
    required this.onTabChanged,
  });

  final YorksV1ProjectPortfolioItem item;
  final _ProjectWorkspaceTab tab;
  final AppLanguage language;
  final ValueChanged<_ProjectWorkspaceTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final project = item.project;
    return NexusPageShell(
      eyebrow: YorksV1ProjectStrings.projectWorkspace.primary,
      title: project.name,
      description: [project.reference, project.siteLocation]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .join(' · '),
      actions: [
        SizedBox(
          height: AppSpacing.minTapTarget,
          child: FilledButton.icon(
            onPressed: () =>
                context.push(RoutePaths.yorksV1BoqGroupsPath(project.id)),
            icon: const Icon(Icons.table_chart_outlined),
            label: Text(YorksV1ProjectStrings.openBoq.primary),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CurrentActionCard(
            title: YorksV1ProjectStrings.stateLabel(project.state).primary,
            message: YorksV1ProjectStrings.workspaceDescription.primary,
            ownerLabel: YorksV1ProjectStrings.currentOwner.primary,
            ownerName: YorksV1ProjectStrings.roleLabel(
              project.currentActionOwnerRole,
            ).primary,
            tone: _toneFor(project.state),
            icon: Icons.assignment_ind_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
          _ProjectWorkspaceTabs(selected: tab, onSelected: onTabChanged),
          const SizedBox(height: AppSpacing.lg),
          switch (tab) {
            _ProjectWorkspaceTab.overview => _ProjectFacts(
              item: item,
              language: language,
            ),
            _ProjectWorkspaceTab.boq => _LinkedRecordCard(
              icon: Icons.table_chart_outlined,
              title: YorksV1ProjectStrings.boq,
              action: YorksV1ProjectStrings.openBoq,
              onOpen: () =>
                  context.push(RoutePaths.yorksV1BoqGroupsPath(project.id)),
            ),
            _ProjectWorkspaceTab.requests => _LinkedRecordCard(
              icon: Icons.assignment_outlined,
              title: YorksV1ProjectStrings.materialRequests,
              action: YorksV1ProjectStrings.openRequests,
              onOpen: () => context.push(RoutePaths.yorksV1MaterialRequests),
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
        ],
      ),
    );
  }

  NexusStatusTone _toneFor(YorksV1ProjectLifecycle state) {
    return switch (state) {
      YorksV1ProjectLifecycle.active => NexusStatusTone.success,
      YorksV1ProjectLifecycle.onHold => NexusStatusTone.warning,
      YorksV1ProjectLifecycle.completed => NexusStatusTone.info,
      YorksV1ProjectLifecycle.draft ||
      YorksV1ProjectLifecycle.archived => NexusStatusTone.neutral,
    };
  }
}

class _ProjectWorkspaceTabs extends StatelessWidget {
  const _ProjectWorkspaceTabs({
    required this.selected,
    required this.onSelected,
  });

  final _ProjectWorkspaceTab selected;
  final ValueChanged<_ProjectWorkspaceTab> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      for (final tab in _ProjectWorkspaceTab.values)
        ChoiceChip(
          selected: selected == tab,
          onSelected: (_) => onSelected(tab),
          label: Text(_tabCopy(tab).primary),
        ),
    ],
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

class _ProjectFacts extends StatelessWidget {
  const _ProjectFacts({required this.item, required this.language});

  final YorksV1ProjectPortfolioItem item;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => LedgerCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CopyText(
          copy: YorksV1ProjectStrings.projectFacts,
          language: language,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth >= 700 ? 3 : 1;
            return GridView.count(
              crossAxisCount: count,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: count == 1 ? 4.6 : 2.2,
              children: [
                _FactTile(
                  copy: YorksV1ProjectStrings.state,
                  value: YorksV1ProjectStrings.stateLabel(
                    item.project.state,
                  ).primary,
                ),
                _FactTile(
                  copy: YorksV1ProjectStrings.currentOwner,
                  value: YorksV1ProjectStrings.roleLabel(
                    item.project.currentActionOwnerRole,
                  ).primary,
                ),
                _FactTile(
                  copy: YorksV1ProjectStrings.activeTeam,
                  value: '${item.activeTeamCount}',
                ),
                _FactTile(
                  copy: YorksV1ProjectStrings.buildingsActive,
                  value: '${item.activeBuildingCount}',
                ),
                if (item.clientName != null)
                  _FactTile(
                    copy: YorksV1ProjectStrings.clientLabel,
                    value: item.clientName!,
                  ),
                if (item.project.siteLocation?.trim().isNotEmpty == true)
                  _FactTile(
                    copy: YorksV1ProjectStrings.site,
                    value: item.project.siteLocation!,
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.copy, required this.value});

  final TranslatableString copy;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          copy.primary,
          style: AppTypography.labelMedium.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleSmall,
        ),
      ],
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
