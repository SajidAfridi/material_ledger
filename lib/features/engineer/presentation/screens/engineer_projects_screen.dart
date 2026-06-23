import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/project_provider.dart';

/// Engineer Projects tab — current projects plus a clear project creation CTA.
class EngineerProjectsScreen extends ConsumerWidget {
  const EngineerProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 840;
          final horizontalPadding = isWide
              ? AppSpacing.xxl
              : AppSpacing.screenHorizontal;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AppSpacing.lg,
                      horizontalPadding,
                      AppSpacing.xl,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _ProjectsHeader(total: projects.length),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _AddProjectCard(projectCount: projects.length),
                    ),
                  ),
                  const SliverGap(AppSpacing.xl),
                  if (projects.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: const _EmptyProjectsState(),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      sliver: SliverList.separated(
                        itemCount: projects.length,
                        separatorBuilder: (_, _) =>
                            const Gap(AppSpacing.listItemGap),
                        itemBuilder: (context, index) {
                          return _ProjectSummaryCard(project: projects[index]);
                        },
                      ),
                    ),
                  const SliverGap(AppSpacing.colossal),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProjectsHeader extends StatelessWidget {
  const _ProjectsHeader({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            AppStrings.projects.primary,
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text(
            '$total ${AppStrings.totalLabel.primary}',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _AddProjectCard extends StatelessWidget {
  const _AddProjectCard({required this.projectCount});

  final int projectCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(
              Icons.add_business_rounded,
              color: AppColors.onPrimary,
            ),
          ),
          const Gap(AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  projectCount == 0
                      ? 'Start by creating your first project'
                      : AppStrings.addAnotherProject.primary,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Gap(AppSpacing.xs),
                Text(
                  'Create projects before raising material requests.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.md),
          IconButton.filled(
            onPressed: () => context.push(RoutePaths.engineerCreateProject),
            icon: const Icon(Icons.arrow_forward_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.onPrimary,
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectSummaryCard extends ConsumerWidget {
  const _ProjectSummaryCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = project.phase;
    final isActive = phase?.state == ProjectState.active;
    final canComplete = ref.watch(canCompleteProjectProvider(project.id));

    return LedgerCard(
      onTap: project.awaitingApproval
          ? () => context.push(RoutePaths.planReviewPath(project.id))
          : project.phase?.state == ProjectState.planning
          ? () => context.push(RoutePaths.planBuildPath(project.id))
          : () => context.push(RoutePaths.requests, extra: project.name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  project.name,
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (project.awaitingApproval) StatusChip.warning('Approval'),
            ],
          ),
          if (project.nameSecondary.isNotEmpty) ...[
            const Gap(AppSpacing.xs),
            Text(
              project.nameSecondary,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
            ),
          ],
          const Gap(AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (phase != null) StatusChip.info(phase.label),
              if (phase != null) _StateChip(state: phase.state),
              if (project.openRequestCount > 0)
                StatusChip.warning('${project.openRequestCount} requests'),
            ],
          ),
          if (project.clientName != null || project.siteLocation != null) ...[
            const Gap(AppSpacing.lg),
            Text(
              [
                if (project.clientName != null &&
                    project.clientName!.isNotEmpty)
                  project.clientName!,
                if (project.siteLocation != null &&
                    project.siteLocation!.isNotEmpty)
                  project.siteLocation!,
              ].join(' · '),
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (project.buildingName != null || project.floorNumbers != null) ...[
            const Gap(AppSpacing.xs),
            Text(
              [
                if (project.buildingName != null &&
                    project.buildingName!.isNotEmpty)
                  'Building: ${project.buildingName}',
                if (project.floorNumbers != null &&
                    project.floorNumbers!.isNotEmpty)
                  'Floors: ${project.floorNumbers}',
              ].join(' · '),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (isActive) ...[
            const Gap(AppSpacing.lg),
            _CompleteAction(
              enabled: canComplete,
              onComplete: () => _complete(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        title: Text(
          AppStrings.markComplete.primary,
          style: AppTypography.titleMedium,
        ),
        content: Text(
          project.name,
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel.primary),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.markComplete.primary),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = ref.read(projectsProvider.notifier).completeProject(project.id);
    if (ok) {
      await ref.logAudit(
        action: 'Project closed out',
        module: AuditModule.materials,
        refId: project.id,
        detail: project.name,
      );
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? AppStrings.projectCompleted.primary
              : AppStrings.cannotCompleteOpenRequests.primary,
        ),
      ),
    );
  }
}

// ─── Closeout action ─────────────────────────────────────────────
class _CompleteAction extends StatelessWidget {
  const _CompleteAction({required this.enabled, required this.onComplete});

  final bool enabled;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: enabled ? onComplete : null,
        icon: const Icon(Icons.task_alt_rounded, size: 18),
        label: Text(
          enabled
              ? AppStrings.markComplete.primary
              : AppStrings.cannotCompleteOpenRequests.primary,
        ),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.onSurfaceVariant.withValues(
            alpha: 0.5,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});

  final ProjectState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ProjectState.active => StatusChip.success(state.label),
      ProjectState.planning => StatusChip.info(state.label),
      ProjectState.onHold => StatusChip.warning(state.label),
      ProjectState.completed => StatusChip.success(state.label),
    };
  }
}

class _EmptyProjectsState extends StatelessWidget {
  const _EmptyProjectsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 64,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.28),
          ),
          const Gap(AppSpacing.xl),
          Text(
            'No projects yet',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const Gap(AppSpacing.sm),
          Text(
            'Add a project to begin tracking requests and dispatches.',
            style: AppTypography.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
