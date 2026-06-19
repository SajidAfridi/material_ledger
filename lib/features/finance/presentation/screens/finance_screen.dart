import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/project_cost_provider.dart';

/// Admin read-only cost roll-up: per-project dispatched value, returned value
/// and net consumed cost, with a CSV export (FR-091). (Finance was the former
/// Accountant role, now merged into Admin.)
class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final currency = ref.watch(currencyProvider);
    final rows = ref.watch(projectCostRowsProvider);
    final total = ref.watch(totalProjectCostProvider);

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
          english: AppStrings.projectCosts.primary,
          secondary: AppStrings.projectCosts.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.exportCsv.primary,
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: rows.isEmpty
                ? null
                : () => _exportCsv(context, ref, rows),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              // ─── Total ─────────────────────────────────────
              LedgerCard(
                color: AppColors.surfaceContainerLowest,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.totalNetCost.primary,
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    Text(
                      currency.format(total),
                      style: AppTypography.displaySmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(AppSpacing.lg),

              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxl),
                  child: Center(
                    child: Text(
                      AppStrings.noDataYet.primary,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                for (final row in rows) ...[
                  _CostCard(row: row, currency: currency),
                  const Gap(AppSpacing.listItemGap),
                ],
              const Gap(AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    WidgetRef ref,
    List<ProjectCostRow> rows,
  ) async {
    final buffer = StringBuffer(
      'Project,Dispatched (AED),Returned (AED),Net (AED)\n',
    );
    for (final r in rows) {
      final name = r.projectName.replaceAll(',', ' ');
      buffer.writeln(
        '$name,${r.cost.dispatchedAED.toStringAsFixed(2)},'
        '${r.cost.returnedAED.toStringAsFixed(2)},'
        '${r.cost.netAED.toStringAsFixed(2)}',
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    await ref.logAudit(
      action: 'Project cost report exported (CSV)',
      module: AuditModule.materials,
      detail: '${rows.length} project(s)',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.csvCopied.primary)));
  }
}

// ─── Per-project cost card ───────────────────────────────────────
class _CostCard extends StatelessWidget {
  const _CostCard({required this.row, required this.currency});

  final ProjectCostRow row;
  final dynamic currency;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.projectName,
            style: AppTypography.titleSmall,
          ),
          const Gap(AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: AppStrings.dispatched.primary,
                  value: currency.format(row.cost.dispatchedAED),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: AppStrings.returnedLabel.primary,
                  value: currency.format(row.cost.returnedAED),
                  valueColor: AppColors.warning,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: AppStrings.netCost.primary,
                  value: currency.format(row.cost.netAED),
                  valueColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const Gap(AppSpacing.xxs),
        Text(
          value,
          style: AppTypography.titleSmall.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
