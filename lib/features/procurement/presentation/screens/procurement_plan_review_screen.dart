import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/material_plan.dart';
import '../../../../shared/models/app_notification.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_plan_provider.dart';
import '../../../../shared/providers/notification_provider.dart';
import '../../../../shared/providers/project_provider.dart';
import '../../../../shared/providers/session_provider.dart';

/// Procurement reviews a submitted Phase-1 plan: arrange each item, comment,
/// then "Mark Done" to send it back to the engineer for final approval (FR).
class ProcurementPlanReviewScreen extends ConsumerStatefulWidget {
  const ProcurementPlanReviewScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProcurementPlanReviewScreen> createState() =>
      _ProcurementPlanReviewScreenState();
}

class _ProcurementPlanReviewScreenState
    extends ConsumerState<ProcurementPlanReviewScreen> {
  final _commentController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool _isArranged(PlanItem i) =>
      i.status == PlanItemStatus.arranged || i.status == PlanItemStatus.ticked;

  Future<void> _toggle(MaterialPlan plan, PlanItem item) async {
    final next = _isArranged(item)
        ? PlanItemStatus.pending
        : PlanItemStatus.arranged;
    await ref
        .read(materialPlansProvider.notifier)
        .setItemStatus(plan.id, item.id, next);
  }

  Future<void> _addComment(MaterialPlan plan) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    await ref
        .read(materialPlansProvider.notifier)
        .addComment(
          planId: plan.id,
          text: text,
          authorName: ref.read(actorNameProvider),
          authorRole: 'Procurement',
        );
    // Notify the engineer immediately (FR-059), deep-linked to their plan.
    final lang = ref.read(languageProvider);
    final projectName =
        ref.read(projectsProvider.notifier).byId(widget.projectId)?.name ??
        widget.projectId;
    await ref.read(notificationsProvider.notifier).add(
          type: NotificationType.plan,
          title: AppStrings.notifPlanCommentTitle.primary,
          titleSecondary: AppStrings.notifPlanCommentTitle.secondary(lang),
          body: '$projectName · "$text"',
          refId: widget.projectId,
          route: RoutePaths.planReviewPath(widget.projectId),
          audience: UserRole.engineer.name,
        );
    _commentController.clear();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  Future<void> _markDone(MaterialPlan plan, String projectName) async {
    setState(() => _busy = true);
    await ref.read(materialPlansProvider.notifier).markPlanDone(plan.id);
    await ref.read(notificationsProvider.notifier).add(
          type: NotificationType.plan,
          title: 'Procurement marked your plan as Done',
          titleSecondary: 'پروکیورمنٹ نے آپ کا پلان مکمل کر دیا',
          body: '$projectName · ready for your final review.',
          refId: widget.projectId,
          route: RoutePaths.planReviewPath(widget.projectId),
          audience: UserRole.engineer.name,
        );
    await ref.logAudit(
      action: 'Plan arranged & marked Done',
      module: AuditModule.materials,
      refId: widget.projectId,
      detail: '$projectName · ${plan.items.length} items',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.planMarkedDone.primary)),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final plan = ref.watch(planForProjectProvider(widget.projectId));
    final project = ref.watch(projectsProvider.notifier).byId(widget.projectId);
    final projectName = project?.name ?? widget.projectId;

    if (plan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(AppStrings.noDataYet.primary)),
      );
    }

    final allArranged = plan.items.every(_isArranged);

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
          english: AppStrings.reviewPlan.primary,
          secondary: AppStrings.reviewPlan.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              _ProgressCard(
                projectName: projectName,
                arranged: plan.items.where(_isArranged).length,
                total: plan.items.length,
                allArranged: allArranged,
                onMarkAll: allArranged
                    ? null
                    : () => ref
                        .read(materialPlansProvider.notifier)
                        .markAllArranged(plan.id),
              ),
              const Gap(AppSpacing.xl),

              Text(
                AppStrings.items.primary,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Gap(AppSpacing.md),

              for (final item in plan.items) ...[
                _ItemCard(
                  item: item,
                  arranged: _isArranged(item),
                  onToggle: () => _toggle(plan, item),
                ),
                const Gap(AppSpacing.listItemGap),
              ],

              const Gap(AppSpacing.xl),

              // ─── Comments ───────────────────────────────────
              Text(
                AppStrings.comments.primary,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Gap(AppSpacing.sm),
              if (plan.comments.isEmpty) ...[
                Text(
                  AppStrings.noCommentsYet.primary,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const Gap(AppSpacing.sm),
              ],
              for (final c in plan.comments) ...[
                _CommentRow(comment: c),
                const Gap(AppSpacing.sm),
              ],
              Row(
                children: [
                  Expanded(
                    child: LedgerTextField(
                      controller: _commentController,
                      label: AppStrings.addComment.primary,
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  IconButton.filled(
                    onPressed: () => _addComment(plan),
                    icon: const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const Gap(AppSpacing.xl),

              PrimaryButton(
                label: AppStrings.markDone.primary,
                icon: Icons.check_circle_outline_rounded,
                isLoading: _busy,
                onPressed: allArranged && !_busy
                    ? () => _markDone(plan, projectName)
                    : null,
              ),
              if (!allArranged) ...[
                const Gap(AppSpacing.sm),
                Center(
                  child: Text(
                    AppStrings.arrangeAllFirst.primary,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const Gap(AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top-of-screen progress summary: project, an arranged/total bar, and a
/// one-tap "mark all arranged" shortcut that disables once everything is done.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.projectName,
    required this.arranged,
    required this.total,
    required this.allArranged,
    required this.onMarkAll,
  });

  final String projectName;
  final int arranged;
  final int total;
  final bool allArranged;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : arranged / total;
    return LedgerCard(
      color: AppColors.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  projectName,
                  style: AppTypography.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Gap(AppSpacing.sm),
              if (allArranged)
                StatusChip.success(AppStrings.arranged.primary)
              else
                StatusChip.info('$arranged / $total'),
            ],
          ),
          const Gap(AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(
                allArranged ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
          const Gap(AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$arranged / $total ${AppStrings.arranged.primary.toLowerCase()}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onMarkAll,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: Text(AppStrings.markAllArranged.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.arranged,
    required this.onToggle,
  });

  final PlanItem item;
  final bool arranged;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final spec = [item.brand, item.size, item.ralColour]
        .where((s) => s.isNotEmpty)
        .join(' · ');
    final inStock = item.status == PlanItemStatus.ticked;
    return LedgerCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: AppTypography.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} ${item.unitSymbol}'
                  '${spec.isNotEmpty ? ' · $spec' : ''}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.sm),
          if (inStock)
            StatusChip.success(PlanItemStatus.ticked.label)
          else
            GestureDetector(
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: arranged
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.primaryContainer.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      arranged
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: arranged ? AppColors.success : AppColors.primary,
                    ),
                    const Gap(AppSpacing.xs),
                    Text(
                      arranged
                          ? AppStrings.arranged.primary
                          : AppStrings.markArranged.primary,
                      style: AppTypography.labelMedium.copyWith(
                        color: arranged ? AppColors.success : AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});
  final PlanComment comment;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      color: AppColors.surfaceContainerLow,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${comment.authorName} · ${comment.authorRole}',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(AppSpacing.xxs),
          Text(comment.text, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}
