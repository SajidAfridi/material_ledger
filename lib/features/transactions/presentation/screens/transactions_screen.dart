import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/inventory_transaction.dart';
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../widgets/record_transaction_sheet.dart';

/// Transactions — Record of material ins/outs.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  void _openRecordTransaction(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, controller) => const RecordTransactionSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final transactions = ref.watch(transactionsProvider);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // ─── Header ──────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.screenVertical,
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BilingualText(
                    english: AppStrings.transactions.primary,
                    secondary: AppStrings.transactions.secondary(lang),
                    englishStyle: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.28,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Row(
                    children: [
                      if (transactions.isNotEmpty)
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.filter_list_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surfaceContainerLowest,
                          ),
                        ),
                      const Gap(AppSpacing.xs),
                      IconButton(
                        onPressed: () => _openRecordTransaction(context),
                        icon: const Icon(Icons.add_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─── Content ─────────────────────────────────────
          if (transactions.isEmpty)
            _buildEmptyState(lang)
          else
            _buildTransactionList(transactions),

          const SliverGap(AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildEmptyState(dynamic lang) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      sliver: SliverToBoxAdapter(
        child: LedgerCard(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.colossal,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                  const Gap(AppSpacing.xl),
                  BilingualText(
                    english: AppStrings.noTransactions.primary,
                    secondary: AppStrings.noTransactions.secondary(lang),
                    englishStyle: AppTypography.titleMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    crossAxisAlignment: CrossAxisAlignment.center,
                  ),
                  const Gap(AppSpacing.sm),
                  Text(
                    AppStrings.transactionsWillAppear.primary,
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionList(List<InventoryTransaction> transactions) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      sliver: SliverList.separated(
        itemCount: transactions.length,
        separatorBuilder: (_, _) => const Gap(AppSpacing.listItemGap),
        itemBuilder: (context, index) {
          final txn = transactions[index];
          return _TransactionCard(txn: txn);
        },
      ),
    );
  }
}

// ─── Transaction Card ────────────────────────────────────────────
class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.txn});

  final InventoryTransaction txn;

  @override
  Widget build(BuildContext context) {
    final isIncoming = txn.type == TransactionType.incoming;
    final dateFormat = DateFormat('MMM d, h:mm a');

    return LedgerCard(
      child: Row(
        children: [
          // Direction indicator
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isIncoming
                  ? AppColors.successContainer.withValues(alpha: 0.25)
                  : AppColors.errorContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              isIncoming
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 20,
              color: isIncoming ? AppColors.success : AppColors.error,
            ),
          ),
          const Gap(AppSpacing.md),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn.materialName, style: AppTypography.titleSmall),
                const Gap(AppSpacing.xxs),
                Text(
                  dateFormat.format(txn.timestamp),
                  style: AppTypography.bodySmall,
                ),
                if (txn.notes.isNotEmpty) ...[
                  const Gap(AppSpacing.xxs),
                  Text(
                    txn.notes,
                    style: AppTypography.labelSmall.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Quantity
          Text(
            txn.formattedQuantity,
            style: AppTypography.titleSmall.copyWith(
              color: isIncoming ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
