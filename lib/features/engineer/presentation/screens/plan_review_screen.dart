import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_notification.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/material_plan.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_plan_provider.dart';
import '../../../../shared/providers/notification_provider.dart';
import '../../../../shared/providers/project_provider.dart';

/// Phase 1 — Engineer reviews the arranged plan and either approves it
/// (project → Active) or requests changes on specific items (FR-024–FR-029).
class PlanReviewScreen extends ConsumerStatefulWidget {
  const PlanReviewScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<PlanReviewScreen> createState() => _PlanReviewScreenState();
}

class _PlanReviewScreenState extends ConsumerState<PlanReviewScreen> {
  bool _changeMode = false;
  final Set<String> _selected = {};
  final _commentController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _approve(MaterialPlan plan) async {
    setState(() => _busy = true);
    await ref.read(materialPlansProvider.notifier).approvePlan(plan.id);
    ref
        .read(projectsProvider.notifier)
        .activateFromPlanApproval(widget.projectId);
    await _notifyProcurement(
      title: AppStrings.notifPlanApprovedTitle,
      detail: _projectName,
    );
    await ref.logAudit(
      action: 'Plan approved — project activated',
      module: AuditModule.materials,
      refId: widget.projectId,
      detail: '${plan.items.length} line items',
    );
    if (!mounted) return;
    _toast(AppStrings.planApproved.primary);
    context.pop();
  }

  String get _projectName =>
      ref.read(projectsProvider.notifier).byId(widget.projectId)?.name ??
      widget.projectId;

  /// Close the loop back to procurement (FR-061/062), deep-linked to the plan.
  Future<void> _notifyProcurement({
    required TranslatableString title,
    required String detail,
  }) async {
    final lang = ref.read(languageProvider);
    await ref.read(notificationsProvider.notifier).add(
          type: NotificationType.plan,
          title: title.primary,
          titleSecondary: title.secondary(lang),
          body: detail,
          refId: widget.projectId,
          route: RoutePaths.planReviewProcurementPath(widget.projectId),
          audience: UserRole.procurement.name,
        );
  }

  Future<void> _sendChanges(MaterialPlan plan) async {
    if (_selected.isEmpty && _commentController.text.trim().isEmpty) {
      _toast(AppStrings.selectItemsToChange.primary);
      return;
    }
    setState(() => _busy = true);
    await ref
        .read(materialPlansProvider.notifier)
        .requestChanges(
          planId: plan.id,
          rejectedItemIds: _selected,
          comment: _commentController.text,
          authorName: 'Site Engineer',
        );
    await _notifyProcurement(
      title: AppStrings.notifPlanChangesTitle,
      detail: '$_projectName · ${_selected.length} item(s)',
    );
    await ref.logAudit(
      action: 'Plan changes requested',
      module: AuditModule.materials,
      refId: widget.projectId,
      detail: '${_selected.length} item(s) flagged',
    );
    if (!mounted) return;
    _toast(AppStrings.changesSent.primary);
    context.pop();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _differs(MaterialPlan plan) {
    final baseQty = {for (final i in plan.baselineItems) i.id: i.quantity};
    final currIds = plan.items.map((e) => e.id).toSet();
    return plan.items.any(
          (i) => !baseQty.containsKey(i.id) || baseQty[i.id] != i.quantity,
        ) ||
        plan.baselineItems.any((i) => !currIds.contains(i.id));
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final project = ref.watch(projectsProvider.notifier).byId(widget.projectId);
    final plan = ref.watch(planForProjectProvider(widget.projectId));
    final showDiff =
        plan != null && plan.baselineItems.isNotEmpty && _differs(plan);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: BilingualText(
          english: AppStrings.planReview.primary,
          secondary: AppStrings.planReview.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      body: ResponsiveCenter(
        child: plan == null
            ? _EmptyPlanState(projectName: project?.name ?? '')
            : SafeArea(
                top: false,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          AppSpacing.lg,
                          AppSpacing.screenHorizontal,
                          AppSpacing.xxl,
                        ),
                        children: [
                          if (project != null)
                            Text(
                              project.name,
                              style: AppTypography.headlineSmall.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          const Gap(AppSpacing.sm),
                          Text(
                            _changeMode
                                ? AppStrings.selectItemsToChange.primary
                                : AppStrings.planReviewSubtitle.primary,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const Gap(AppSpacing.xl),
                          if (showDiff) ...[
                            LedgerCard(
                              color: AppColors.warningContainer.withValues(
                                alpha: 0.25,
                              ),
                              onTap: () => context.push(
                                RoutePaths.planDiffPath(widget.projectId),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.history_rounded,
                                    color: AppColors.warning,
                                  ),
                                  const Gap(AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      AppStrings.changesAwaitingReview.primary,
                                      style: AppTypography.labelLarge.copyWith(
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    AppStrings.viewChanges.primary,
                                    style: AppTypography.labelMedium.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                            const Gap(AppSpacing.xl),
                          ],
                          if (!showDiff &&
                              (plan.status ==
                                      MaterialPlanStatus.procurementReview ||
                                  plan.status ==
                                      MaterialPlanStatus.submitted)) ...[
                            LedgerCard(
                              color: AppColors.surfaceContainerLow,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.hourglass_empty_rounded,
                                    size: 18,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  const Gap(AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      AppStrings.changesAwaitingReview.primary,
                                      style: AppTypography.labelLarge.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Gap(AppSpacing.xl),
                          ],
                          Text(
                            AppStrings.planItems.primary,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Gap(AppSpacing.md),
                          for (final item in plan.items) ...[
                            _PlanItemCard(
                              item: item,
                              lang: lang,
                              selectable: _changeMode,
                              selected: _selected.contains(item.id),
                              onToggle: () => setState(() {
                                if (_selected.contains(item.id)) {
                                  _selected.remove(item.id);
                                } else {
                                  _selected.add(item.id);
                                }
                              }),
                            ),
                            const Gap(AppSpacing.listItemGap),
                          ],
                          const Gap(AppSpacing.lg),
                          _CommentsSection(
                            plan: plan,
                            lang: lang,
                            controller: _commentController,
                            showInput: _changeMode,
                          ),
                        ],
                      ),
                    ),
                    _ActionBar(
                      plan: plan,
                      busy: _busy,
                      changeMode: _changeMode,
                      onApprove: () => _approve(plan),
                      onStartChanges: () => setState(() => _changeMode = true),
                      onSendChanges: () => _sendChanges(plan),
                      onCancelChanges: () => setState(() {
                        _changeMode = false;
                        _selected.clear();
                      }),
                      onEditPlan: () => context.push(
                        RoutePaths.planBuildPath(widget.projectId),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PlanItemCard extends StatelessWidget {
  const _PlanItemCard({
    required this.item,
    required this.lang,
    required this.selectable,
    required this.selected,
    required this.onToggle,
  });

  final PlanItem item;
  final dynamic lang;
  final bool selectable;
  final bool selected;
  final VoidCallback onToggle;

  StatusChip get _chip => switch (item.status) {
    PlanItemStatus.ticked => StatusChip.success(
      item.status.label,
      icon: Icons.check_circle_outline_rounded,
    ),
    PlanItemStatus.arranged => StatusChip.success(item.status.label),
    PlanItemStatus.lowStock => StatusChip.warning(
      item.status.label,
      icon: Icons.warning_amber_rounded,
    ),
    PlanItemStatus.rejected => StatusChip.error(item.status.label),
    PlanItemStatus.pending => StatusChip.info(item.status.label),
  };

  @override
  Widget build(BuildContext context) {
    final spec = [
      if (item.size.isNotEmpty) item.size,
      if (item.brand.isNotEmpty) item.brand,
      if (item.ralColour.isNotEmpty) item.ralColour,
      if (item.countryOfOrigin.isNotEmpty) item.countryOfOrigin,
    ].join(' · ');

    return LedgerCard(
      color: selected
          ? AppColors.primaryContainer.withValues(alpha: 0.08)
          : null,
      onTap: selectable ? onToggle : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectable) ...[
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.primary : AppColors.outlineVariant,
            ),
            const Gap(AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.description,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    if (item.isCustom)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.tertiaryContainer.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                        child: Text(
                          AppStrings.customItem.primary,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.onTertiaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                if (item.descriptionSecondary.isNotEmpty) ...[
                  const Gap(2),
                  Text(
                    item.descriptionSecondary,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    textDirection: lang.isRtl
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                ],
                const Gap(AppSpacing.sm),
                Text(
                  '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)} ${item.unitSymbol}'
                  '${spec.isNotEmpty ? '  ·  $spec' : ''}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                if (item.note.isNotEmpty) ...[
                  const Gap(AppSpacing.xs),
                  Text(
                    item.note,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const Gap(AppSpacing.sm),
                _chip,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.plan,
    required this.lang,
    required this.controller,
    required this.showInput,
  });

  final MaterialPlan plan;
  final dynamic lang;
  final TextEditingController controller;
  final bool showInput;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.forum_outlined,
              size: 18,
              color: AppColors.onSurfaceVariant,
            ),
            const Gap(AppSpacing.sm),
            Text(
              '${AppStrings.comments.primary} (${plan.comments.length})',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const Gap(AppSpacing.md),
        if (plan.comments.isEmpty)
          Text(
            AppStrings.noComments.primary,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          )
        else
          for (final c in plan.comments) ...[
            LedgerCard(
              color: AppColors.surfaceContainerLow,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c.authorName} · ${c.authorRole}',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Gap(AppSpacing.xs),
                  Text(c.text, style: AppTypography.bodyMedium),
                ],
              ),
            ),
            const Gap(AppSpacing.sm),
          ],
        if (showInput) ...[
          const Gap(AppSpacing.sm),
          LedgerTextField(
            controller: controller,
            label: AppStrings.addComment.primary,
            hintText: AppStrings.optional.primary,
            maxLines: 2,
          ),
        ],
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.plan,
    required this.busy,
    required this.changeMode,
    required this.onApprove,
    required this.onStartChanges,
    required this.onSendChanges,
    required this.onCancelChanges,
    required this.onEditPlan,
  });

  final MaterialPlan plan;
  final bool busy;
  final bool changeMode;
  final VoidCallback onApprove;
  final VoidCallback onStartChanges;
  final VoidCallback onSendChanges;
  final VoidCallback onCancelChanges;
  final VoidCallback onEditPlan;

  @override
  Widget build(BuildContext context) {
    final canApprove = plan.isReadyForApproval;

    return Container(
      decoration: const BoxDecoration(color: AppColors.surfaceContainerLowest),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: changeMode
          ? Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: AppStrings.cancel.primary,
                    onPressed: busy ? null : onCancelChanges,
                  ),
                ),
                const Gap(AppSpacing.md),
                Expanded(
                  child: PrimaryButton(
                    label: AppStrings.requestChanges.primary,
                    icon: Icons.send_rounded,
                    isLoading: busy,
                    onPressed: busy ? null : onSendChanges,
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PrimaryButton(
                  label: AppStrings.approvePlan.primary,
                  icon: Icons.check_rounded,
                  isLoading: busy,
                  onPressed: (busy || !canApprove) ? null : onApprove,
                ),
                const Gap(AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: AppStrings.requestChanges.primary,
                        icon: Icons.rule_rounded,
                        onPressed: busy ? null : onStartChanges,
                      ),
                    ),
                    const Gap(AppSpacing.md),
                    Expanded(
                      child: SecondaryButton(
                        label: AppStrings.editPlan.primary,
                        icon: Icons.edit_outlined,
                        onPressed: busy ? null : onEditPlan,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _EmptyPlanState extends StatelessWidget {
  const _EmptyPlanState({required this.projectName});

  final String projectName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.assignment_outlined,
              size: 48,
              color: AppColors.outlineVariant,
            ),
            const Gap(AppSpacing.lg),
            Text(
              AppStrings.emptyPlan.primary,
              style: AppTypography.titleMedium,
              textAlign: TextAlign.center,
            ),
            const Gap(AppSpacing.sm),
            Text(
              AppStrings.buildPlanSubtitle.primary,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
