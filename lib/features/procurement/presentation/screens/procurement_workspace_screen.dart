import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/feedback/feedback_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_notification.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/material_request.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_plan_provider.dart';
import '../../../../shared/providers/material_request_provider.dart';
import '../../../../shared/providers/notification_provider.dart';
import '../../../../shared/providers/nexus_feature_flags_provider.dart';
import '../../../../shared/providers/project_provider.dart';
import '../../../../shared/providers/session_provider.dart';

/// Procurement workspace — the two SRS work queues: Phase-1 plans awaiting
/// arrangement, and Phase-2 requests awaiting dispatch. Procurement & Admin.
class ProcurementWorkspaceScreen extends ConsumerWidget {
  const ProcurementWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    // Same status sets that drive the Home "Awaiting you" KPI + hub badge, so
    // the count a user sees never disagrees with what's actually listed here.
    final plans = ref
        .watch(materialPlansProvider)
        .where((p) => planReviewQueueStatuses.contains(p.status))
        .toList();
    final requests = ref
        .watch(materialRequestsProvider)
        .where((r) => dispatchQueueStatuses.contains(r.status))
        .toList();
    final projects = ref.watch(projectsProvider);
    // Newly-created projects nobody's acknowledged yet — the earliest stage in
    // the pipeline, shown first.
    final newProjects = ref.watch(projectsAwaitingAcceptanceProvider);

    String projectName(String projectId) {
      for (final p in projects) {
        if (p.id == projectId) return p.name;
      }
      return projectId;
    }

    final urgentCount = requests
        .where((r) => r.priority == RequestPriority.urgent)
        .length;
    final totalPending = newProjects.length + plans.length + requests.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: BilingualText(
          english: AppStrings.procurement.primary,
          secondary: AppStrings.procurement.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          if (ref.watch(nexusFeatureFlagsProvider).projects)
            IconButton(
              tooltip: AppStrings.createProject.primary,
              onPressed: () => context.push(RoutePaths.engineerCreateProject),
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              // ─── Hero summary ───────────────────────────────
              _Hero(totalPending: totalPending, urgentCount: urgentCount),
              const Gap(AppSpacing.xl),

              // ─── New projects awaiting acceptance ───────────
              _QueueHeader(
                label: AppStrings.newProjectsQueue.primary,
                count: newProjects.length,
              ),
              const Gap(AppSpacing.md),
              if (newProjects.isEmpty)
                _EmptyState(text: AppStrings.noNewProjects.primary)
              else
                for (final p in newProjects) ...[
                  _NewProjectCard(project: p),
                  const Gap(AppSpacing.listItemGap),
                ],
              const Gap(AppSpacing.xl),

              // ─── Plans to review ────────────────────────────
              _QueueHeader(
                label: AppStrings.plansToReview.primary,
                count: plans.length,
              ),
              const Gap(AppSpacing.md),
              if (plans.isEmpty)
                _EmptyState(text: AppStrings.noPlansToReview.primary)
              else
                for (final p in plans) ...[
                  _QueueCard(
                    icon: Icons.fact_check_outlined,
                    title: projectName(p.projectId),
                    subtitle:
                        '${p.items.length} ${AppStrings.items.primary} · ${p.status.label}',
                    statusChip: StatusChip.info(p.status.label),
                    onTap: () => context.push(
                      RoutePaths.planReviewProcurementPath(p.projectId),
                    ),
                  ),
                  const Gap(AppSpacing.listItemGap),
                ],

              const Gap(AppSpacing.xl),

              // ─── Requests to dispatch ───────────────────────
              _QueueHeader(
                label: AppStrings.requestsToDispatch.primary,
                count: requests.length,
              ),
              const Gap(AppSpacing.md),
              if (requests.isEmpty)
                _EmptyState(text: AppStrings.noRequestsToDispatch.primary)
              else
                for (final r in requests) ...[
                  _QueueCard(
                    icon: Icons.local_shipping_outlined,
                    title: r.projectName,
                    subtitle:
                        '${r.itemCount} ${AppStrings.items.primary} · ${r.status.label}',
                    statusChip: r.priority == RequestPriority.urgent
                        ? StatusChip.error(AppStrings.urgent.primary)
                        : StatusChip.info(r.status.label),
                    onTap: () => context.push(RoutePaths.dispatchPath(r.id)),
                  ),
                  const Gap(AppSpacing.listItemGap),
                ],
              const Gap(AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Landing summary — frames the two queues with a single "what needs me" line.
class _Hero extends StatelessWidget {
  const _Hero({required this.totalPending, required this.urgentCount});

  final int totalPending;
  final int urgentCount;

  @override
  Widget build(BuildContext context) {
    final clear = totalPending == 0;
    return LedgerCard(
      color: AppColors.surfaceContainerLowest,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(
              clear
                  ? Icons.check_circle_outline_rounded
                  : Icons.inventory_2_outlined,
              color: clear ? AppColors.success : AppColors.primary,
            ),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clear
                      ? AppStrings.allCaughtUp.primary
                      : '$totalPending ${AppStrings.needYourAttention.primary}',
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  AppStrings.procurementSubtitle.primary,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                if (urgentCount > 0) ...[
                  const Gap(AppSpacing.sm),
                  StatusChip.error('$urgentCount ${AppStrings.urgent.primary}'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const Gap(AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: count > 0 ? AppColors.primary : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text(
            '$count',
            style: AppTypography.labelMedium.copyWith(
              color: count > 0
                  ? AppColors.onPrimary
                  : AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.statusChip,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget statusChip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.sm),
          statusChip,
          const Gap(AppSpacing.xs),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}

/// A newly-created project awaiting procurement's acknowledgment. Unlike the
/// Plans/Requests cards (which push to a review screen — there's real per-line
/// work to do there), acceptance has no sub-screen worth building: it's a
/// single acknowledgment, so tapping the card OR the explicit button both open
/// the same confirm dialog directly.
class _NewProjectCard extends ConsumerWidget {
  const _NewProjectCard({required this.project});

  final Project project;

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.acceptProjectConfirmTitle.primary),
        content: Text(AppStrings.acceptProjectConfirmBody.primary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel.primary),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.acceptProject.primary),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final updated = await ref
        .read(projectsProvider.notifier)
        .acceptProject(project.id, acceptedBy: ref.read(actorNameProvider));
    if (updated == null) return; // already accepted (e.g. a second tap) — no-op

    final engineerId = updated.assignedEngineerId;
    if (engineerId != null) {
      final lang = ref.read(languageProvider);
      await ref
          .read(notificationsProvider.notifier)
          .add(
            type: NotificationType.project,
            title: AppStrings.notifProjectAcceptedTitle.primary,
            titleSecondary: AppStrings.notifProjectAcceptedTitle.secondary(
              lang,
            ),
            body: updated.name,
            refId: updated.id,
            route: RoutePaths.engineerProjects,
            userId: engineerId,
          );
    }
    await ref.logAudit(
      action: 'Project accepted by procurement',
      module: AuditModule.materials,
      refId: updated.id,
      detail: updated.name,
    );
    if (!context.mounted) return;
    AppFeedback.confirm();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.projectAccepted.primary)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = [
      if ((project.clientName ?? '').isNotEmpty) project.clientName,
      if ((project.jobNumber ?? '').isNotEmpty) 'Job ${project.jobNumber}',
    ].whereType<String>().join(' · ');

    return LedgerCard(
      onTap: ref.watch(nexusFeatureFlagsProvider).projects
          ? () => context.push(RoutePaths.projectWorkspacePath(project.id))
          : () => _accept(context, ref),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.successContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Icon(
              Icons.domain_add_outlined,
              size: 20,
              color: AppColors.success,
            ),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: AppTypography.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const Gap(AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const Gap(AppSpacing.sm),
          SecondaryButton(
            label: AppStrings.acceptProject.primary,
            isExpanded: false,
            onPressed: () => _accept(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Tall, centered empty state for a clear queue.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 32,
              color: AppColors.success.withValues(alpha: 0.7),
            ),
            const Gap(AppSpacing.sm),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(AppSpacing.xxs),
            Text(
              AppStrings.queueClear.primary,
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
