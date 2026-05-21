import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/project.dart';
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
            onPressed: () => context.go(RoutePaths.engineerCreateProject),
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

class _ProjectSummaryCard extends StatelessWidget {
  const _ProjectSummaryCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final phase = project.phase;

    return LedgerCard(
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
                if (project.clientName != null) project.clientName!,
                if (project.siteLocation != null) project.siteLocation!,
              ].join(' · '),
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
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
