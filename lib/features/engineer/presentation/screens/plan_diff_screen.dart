import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/material_plan.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_plan_provider.dart';

/// Phase 1 — Shows what changed between the arranged plan (baseline) and the
/// engineer's edited plan, so only changed items go back for re-review
/// (FR-030/031/032).
class PlanDiffScreen extends ConsumerWidget {
  const PlanDiffScreen({super.key, required this.projectId});

  final String projectId;

  String _fmt(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final plan = ref.watch(planForProjectProvider(projectId));

    final baseline = plan?.baselineItems ?? const <PlanItem>[];
    final current = plan?.items ?? const <PlanItem>[];
    final baseById = {for (final i in baseline) i.id: i};
    final currById = {for (final i in current) i.id: i};

    final added = [
      for (final i in current)
        if (!baseById.containsKey(i.id)) i,
    ];
    final removed = [
      for (final i in baseline)
        if (!currById.containsKey(i.id)) i,
    ];
    final changed = [
      for (final i in current)
        if (baseById.containsKey(i.id) &&
            baseById[i.id]!.quantity != i.quantity)
          (old: baseById[i.id]!, now: i),
    ];
    final unchanged = current.length - added.length - changed.length;
    final hasAny = added.isNotEmpty || removed.isNotEmpty || changed.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: BilingualText(
          english: AppStrings.whatChanged.primary,
          secondary: AppStrings.whatChanged.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      body: ResponsiveCenter(
        child: !hasAny
            ? Center(
                child: Text(
                  AppStrings.noChanges.primary,
                  style: AppTypography.titleMedium,
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.lg,
                  AppSpacing.screenHorizontal,
                  AppSpacing.xxl,
                ),
                children: [
                  for (final c in changed)
                    _DiffRow(
                      title: c.now.description,
                      chip: StatusChip.info(AppStrings.diffChanged.primary),
                      detail:
                          '${_fmt(c.old.quantity)} ${c.old.unitSymbol}  →  ${_fmt(c.now.quantity)} ${c.now.unitSymbol}',
                      strikeDetail: false,
                    ),
                  for (final i in added)
                    _DiffRow(
                      title: i.description,
                      chip: StatusChip.success(AppStrings.diffAdded.primary),
                      detail: '${_fmt(i.quantity)} ${i.unitSymbol}',
                      strikeDetail: false,
                    ),
                  for (final i in removed)
                    _DiffRow(
                      title: i.description,
                      chip: StatusChip.error(AppStrings.diffRemoved.primary),
                      detail: '${_fmt(i.quantity)} ${i.unitSymbol}',
                      strikeDetail: true,
                    ),
                  if (unchanged > 0) ...[
                    const Gap(AppSpacing.md),
                    Row(
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const Gap(AppSpacing.xs),
                        Expanded(
                          child: Text(
                            '$unchanged ${AppStrings.unchangedUnaffected.primary}',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({
    required this.title,
    required this.chip,
    required this.detail,
    required this.strikeDetail,
  });

  final String title;
  final StatusChip chip;
  final String detail;
  final bool strikeDetail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.listItemGap),
      child: LedgerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: strikeDetail
                          ? TextDecoration.lineThrough
                          : null,
                      color: strikeDetail
                          ? AppColors.onSurfaceVariant
                          : AppColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Gap(AppSpacing.sm),
                chip,
              ],
            ),
            const Gap(AppSpacing.xs),
            Text(
              detail,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
