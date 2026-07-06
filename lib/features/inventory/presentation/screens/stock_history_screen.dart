import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/stock_movement_provider.dart';

/// The append-only stock ledger — every change to on-hand quantity, newest
/// first, with the resulting balance. Answers "why is on-hand 84, not 120?"
/// Read-only: movements are written only by the stock actions that cause them.
class StockHistoryScreen extends ConsumerWidget {
  const StockHistoryScreen({super.key, this.materialId});

  /// When set, shows only this material's history (opened from its detail).
  final String? materialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final all = ref.watch(recentStockMovementsProvider);
    final movements =
        materialId == null ? all : all.where((m) => m.materialId == materialId).toList();
    final df = DateFormat('d MMM yyyy · h:mm a');

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
          english: 'Stock history',
          secondary: lang.isRtl ? 'سجل المخزون' : 'Stock history',
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
          child: movements.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Text(
                      'No stock movements yet.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  itemCount: movements.length,
                  separatorBuilder: (_, _) => const Gap(AppSpacing.listItemGap),
                  itemBuilder: (context, i) {
                    final m = movements[i];
                    final isIn = m.delta >= 0;
                    return LedgerCard(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: (isIn ? AppColors.success : AppColors.error)
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isIn
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              size: 18,
                              color: isIn ? AppColors.success : AppColors.error,
                            ),
                          ),
                          const Gap(AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (materialId == null)
                                  Text(m.materialName, style: AppTypography.titleSmall),
                                Text(
                                  '${m.type.label} · ${df.format(m.timestamp)}'
                                  '${m.actor != null ? ' · ${m.actor}' : ''}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                m.signedQty,
                                style: AppTypography.titleSmall.copyWith(
                                  color: isIn ? AppColors.success : AppColors.error,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Balance: ${m.resultingBalance.toStringAsFixed(m.resultingBalance.truncateToDouble() == m.resultingBalance ? 0 : 1)}',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
