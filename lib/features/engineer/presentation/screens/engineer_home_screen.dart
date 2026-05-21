import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/material_dispatch.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/providers/dispatch_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_request_provider.dart';
import '../../../../shared/providers/notification_provider.dart';
import '../../../../shared/providers/project_provider.dart';

/// Engineer dashboard for the GodownPro Phase 1 + Phase 2 workflow.
///
/// The shell owns the bottom navigation / side navigation and New Request CTA;
/// this screen only renders dashboard content to avoid duplicate floating CTAs.
class EngineerHomeScreen extends ConsumerWidget {
  const EngineerHomeScreen({super.key});

  static const double _tabletBreakpoint = 840;
  static const double _wideBreakpoint = 1200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isCompact = width < _tabletBreakpoint;
          final isWide = width >= _wideBreakpoint;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact ? AppSpacing.screenHorizontal : AppSpacing.xxl,
              AppSpacing.lg,
              isCompact ? AppSpacing.screenHorizontal : AppSpacing.xxl,
              0,
            ),
            child: Column(
              children: [
                _LedgerTopBar(isCompact: isCompact),
                const Gap(AppSpacing.xl),
                Expanded(
                  child: isWide
                      ? const _WideDashboard()
                      : const _StackedDashboard(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WideDashboard extends StatelessWidget {
  const _WideDashboard();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Expanded(
          flex: 7,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              right: AppSpacing.xl,
              bottom: AppSpacing.xxl,
            ),
            child: _MainContent(),
          ),
        ),
        SizedBox(
          width: 340,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: AppSpacing.xxl),
            child: _MaterialFeedPanel(),
          ),
        ),
      ],
    );
  }
}

class _StackedDashboard extends StatelessWidget {
  const _StackedDashboard();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.only(bottom: AppSpacing.xxl),
      child: _MainContent(),
    );
  }
}

class _MainContent extends ConsumerWidget {
  const _MainContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvalProject = ref.watch(pendingApprovalProjectProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (approvalProject != null) ...[
          _ApprovalBanner(project: approvalProject),
          const Gap(AppSpacing.xl),
        ],
        const _StatsRow(),
        const Gap(AppSpacing.xxl),
        const _ProjectsHeader(),
        const Gap(AppSpacing.lg),
        const _FilterPills(),
        const Gap(AppSpacing.lg),
        const _ProjectsList(),
      ],
    );
  }
}

class _LedgerTopBar extends ConsumerWidget {
  const _LedgerTopBar({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);

    return Row(
      children: [
        const _BrandAvatar(),
        const Gap(AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Yorks AC',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const Gap(AppSpacing.md),
        _TopBarButton(
          icon: Icons.search_rounded,
          tooltip: AppStrings.searchParameters.primary,
          onTap: () => context.go(RoutePaths.engineerBrowse),
        ),
        const Gap(AppSpacing.xs),
        _NotificationButton(unread: unread),
      ],
    );
  }
}

class _BrandAvatar extends StatelessWidget {
  const _BrandAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.engineering_rounded,
        color: AppColors.onPrimary,
        size: 26,
      ),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusFull);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            width: AppSpacing.minTapTarget,
            height: AppSpacing.minTapTarget,
            child: Icon(icon, size: 24, color: AppColors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _TopBarButton(
          icon: Icons.notifications_none_rounded,
          tooltip: AppStrings.notifications.primary,
          onTap: () => context.push(RoutePaths.notifications),
        ),
        if (unread > 0)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.surfaceContainer,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ApprovalBanner extends ConsumerWidget {
  const _ApprovalBanner({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);

    return LedgerCard(
      color: AppColors.successContainer.withValues(alpha: 0.22),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: AppColors.onSuccess),
          ),
          const Gap(AppSpacing.lg),
          Expanded(
            child: BilingualText(
              english: AppStrings.planReadyForApproval.primary,
              secondary: AppStrings.planReadyForApproval.secondary(lang),
              englishStyle: AppTypography.titleMedium.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
              secondaryStyle: AppTypography.labelMedium.copyWith(
                color: AppColors.success.withValues(alpha: 0.85),
              ),
            ),
          ),
          const Gap(AppSpacing.md),
          Flexible(
            child: Text(
              project.name,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.success.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCount = ref.watch(activeProjectCountProvider);
    final actionsCount = ref.watch(actionsNeededCountProvider);
    final openCount = ref.watch(openRequestCountProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final spacing = isCompact ? AppSpacing.sm : AppSpacing.lg;
        final cards = [
          _StatCard(
            label: AppStrings.activeProjects,
            value: activeCount,
            accent: AppColors.onSurface,
            compact: isCompact,
          ),
          _StatCard(
            label: AppStrings.actionsNeeded,
            value: actionsCount,
            accent: actionsCount > 0 ? AppColors.error : AppColors.onSurface,
            compact: isCompact,
          ),
          _StatCard(
            label: AppStrings.openRequests,
            value: openCount,
            accent: openCount > 0 ? AppColors.error : AppColors.onSurface,
            compact: isCompact,
          ),
        ];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1) Gap(spacing),
            ],
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.compact,
  });

  final TranslatableString label;
  final int value;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.primary,
            style:
                (compact ? AppTypography.labelMedium : AppTypography.bodyMedium)
                    .copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Gap(compact ? AppSpacing.sm : AppSpacing.md),
          Text(
            '$value',
            style:
                (compact
                        ? AppTypography.headlineLarge
                        : AppTypography.displaySmall)
                    .copyWith(color: accent, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ProjectsHeader extends ConsumerWidget {
  const _ProjectsHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(projectsProvider).length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            AppStrings.myProjects.primary,
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

class _FilterPills extends ConsumerWidget {
  const _FilterPills();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(engineerProjectFilterProvider);

    final entries = <(DashboardProjectFilter, TranslatableString)>[
      (DashboardProjectFilter.all, AppStrings.filterAllShort),
      (DashboardProjectFilter.active, AppStrings.filterActive),
      (DashboardProjectFilter.planning, AppStrings.filterPlanning),
      (DashboardProjectFilter.onHold, AppStrings.filterOnHold),
      (DashboardProjectFilter.completed, AppStrings.filterCompleted),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in entries) ...[
            _FilterPill(
              label: entry.$2.primary,
              selected: selected == entry.$1,
              onTap: () =>
                  ref.read(engineerProjectFilterProvider.notifier).state =
                      entry.$1,
            ),
            if (entry != entries.last) const Gap(AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusFull);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.onSurface
                : AppColors.surfaceContainerLowest,
            borderRadius: radius,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectsList extends ConsumerWidget {
  const _ProjectsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(engineerFilteredProjectsProvider);

    if (projects.isEmpty) return const _EmptyProjects();

    return Column(
      children: [
        for (var i = 0; i < projects.length; i++) ...[
          _ProjectCard(project: projects[i]),
          if (i != projects.length - 1) const Gap(AppSpacing.listItemGap),
        ],
      ],
    );
  }
}

class _EmptyProjects extends ConsumerWidget {
  const _EmptyProjects();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.noProjectsInFilter.primary,
            style: AppTypography.titleMedium,
          ),
          const Gap(AppSpacing.md),
          SecondaryButton(
            label: AppStrings.showAll.primary,
            icon: Icons.refresh_rounded,
            isExpanded: false,
            onPressed: () =>
                ref.read(engineerProjectFilterProvider.notifier).state =
                    DashboardProjectFilter.all,
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final phase = project.phase;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;

        return LedgerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project.name,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (project.nameSecondary.isNotEmpty) ...[
                const Gap(AppSpacing.xs),
                Text(
                  project.nameSecondary,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textDirection: lang.isRtl
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (phase != null) ...[
                const Gap(AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    StatusChip.info(phase.label),
                    _StateChip(state: phase.state),
                  ],
                ),
              ],
              if (project.clientName != null ||
                  project.siteLocation != null) ...[
                const Gap(AppSpacing.lg),
                Text(
                  [
                    if (project.clientName != null) project.clientName!,
                    if (project.siteLocation != null) project.siteLocation!,
                  ].join(' · '),
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Gap(AppSpacing.xl),
              Container(height: 1, color: AppColors.surfaceContainer),
              const Gap(AppSpacing.md),
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProjectFooterAction(project: project),
                    if (project.lastUpdated != null) ...[
                      const Gap(AppSpacing.xs),
                      _UpdatedLabel(timestamp: project.lastUpdated!),
                    ],
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: _ProjectFooterAction(project: project)),
                    if (project.lastUpdated != null)
                      _UpdatedLabel(timestamp: project.lastUpdated!),
                  ],
                ),
            ],
          ),
        );
      },
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

class _ProjectFooterAction extends ConsumerWidget {
  const _ProjectFooterAction({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final IconData icon;
    final Color color;
    final String english;

    if (project.awaitingApproval) {
      icon = Icons.check_circle_outline_rounded;
      color = AppColors.success;
      english = AppStrings.approvePlan.primary;
    } else if (project.openRequestCount > 0) {
      icon = Icons.inbox_outlined;
      color = AppColors.warning;
      english =
          '${project.openRequestCount} ${AppStrings.openRequestsLabel.primary}';
    } else if (project.allDispatched) {
      icon = Icons.local_shipping_outlined;
      color = AppColors.success;
      english = AppStrings.allDispatched.primary;
    } else {
      icon = Icons.chevron_right_rounded;
      color = AppColors.onSurfaceVariant;
      english = AppStrings.viewDetails.primary;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const Gap(AppSpacing.sm),
        Flexible(
          child: Text(
            english,
            style: AppTypography.labelLarge.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _UpdatedLabel extends StatelessWidget {
  const _UpdatedLabel({required this.timestamp});

  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${AppStrings.updatedAgo.primary} ${_formatRelativeTime(timestamp)}',
      style: AppTypography.labelMedium.copyWith(
        color: AppColors.onSurfaceVariant.withValues(alpha: 0.72),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _MaterialFeedPanel extends ConsumerWidget {
  const _MaterialFeedPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispatches = ref.watch(dispatchesProvider);
    final lang = ref.watch(languageProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BilingualText(
          english: AppStrings.materialFeed.primary,
          secondary: AppStrings.materialFeed.secondary(lang),
          englishStyle: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const Gap(AppSpacing.xs),
        BilingualText(
          english: AppStrings.realTimeDispatches.primary,
          secondary: AppStrings.realTimeDispatches.secondary(lang),
          englishStyle: AppTypography.bodyMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const Gap(AppSpacing.xl),
        for (var i = 0; i < dispatches.length; i++) ...[
          _DispatchCard(dispatch: dispatches[i]),
          if (i != dispatches.length - 1) const Gap(AppSpacing.md),
        ],
      ],
    );
  }
}

class _DispatchCard extends StatelessWidget {
  const _DispatchCard({required this.dispatch});

  final MaterialDispatch dispatch;

  Color get _accent => switch (dispatch.status) {
    DispatchStatus.inTransit => AppColors.primary,
    DispatchStatus.readyForInspection => AppColors.primaryContainer,
    DispatchStatus.delayed => AppColors.error,
  };

  IconData get _icon => switch (dispatch.status) {
    DispatchStatus.inTransit => Icons.local_shipping_outlined,
    DispatchStatus.readyForInspection => Icons.engineering_outlined,
    DispatchStatus.delayed => Icons.warning_amber_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _accent;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(_icon, size: 20, color: accent),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dispatch.materialName} (X${dispatch.quantity})',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(AppSpacing.xxs),
                    Text(
                      'ID: ${dispatch.id}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(AppSpacing.sm),
              Text(
                _formatRelativeTime(dispatch.timestamp).toUpperCase(),
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.md),
          _DispatchBody(dispatch: dispatch, accent: accent),
        ],
      ),
    );
  }
}

class _DispatchBody extends StatelessWidget {
  const _DispatchBody({required this.dispatch, required this.accent});

  final MaterialDispatch dispatch;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return switch (dispatch.status) {
      DispatchStatus.inTransit => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DispatchMetaRow(
            icon: Icons.location_on_outlined,
            text:
                '${AppStrings.dispatchTo.primary}: ${dispatch.destination ?? '—'}',
          ),
          const Gap(AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: dispatch.progress.clamp(0, 1),
              minHeight: 4,
              backgroundColor: AppColors.surfaceContainer,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
      DispatchStatus.readyForInspection => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DispatchMetaRow(
            icon: Icons.person_outline_rounded,
            text:
                '${AppStrings.dispatchAssigned.primary}: ${dispatch.assignedTo ?? '—'}',
          ),
          if (dispatch.note != null && dispatch.note!.trim().isNotEmpty) ...[
            const Gap(AppSpacing.sm),
            Text(
              dispatch.note!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
      DispatchStatus.delayed => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.errorContainer.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dispatch.status.label,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (dispatch.delayReason != null &&
                dispatch.delayReason!.trim().isNotEmpty) ...[
              const Gap(AppSpacing.xs),
              Text(
                dispatch.delayReason!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.error.withValues(alpha: 0.9),
                ),
              ),
            ],
          ],
        ),
      ),
    };
  }
}

class _DispatchMetaRow extends StatelessWidget {
  const _DispatchMetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
        const Gap(AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

String _formatRelativeTime(DateTime then) {
  final diff = DateTime.now().difference(then);
  if (diff.inMinutes < 1) return AppStrings.justNow.primary;
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}${AppStrings.minuteAbbrev.primary}';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}${AppStrings.hourAbbrev.primary}';
  }
  return '${diff.inDays}${AppStrings.dayAbbrev.primary}';
}
