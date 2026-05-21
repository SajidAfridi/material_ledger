import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
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

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    final current = ref.read(transactionFilterProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransactionFilterSheet(
        current: current,
        onSelected: (f) =>
            ref.read(transactionFilterProvider.notifier).state = f,
      ),
    );
  }

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
    final transactions = ref.watch(filteredTransactionsProvider);
    final allTransactions = ref.watch(transactionsProvider);
    final filter = ref.watch(transactionFilterProvider);

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
                      if (allTransactions.isNotEmpty) ...[
                        if (filter != TransactionFilter.all)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (filter != TransactionFilter.all)
                          const Gap(AppSpacing.xs),
                        IconButton(
                          onPressed: () => _showFilterSheet(context, ref),
                          icon: const Icon(Icons.filter_list_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: filter != TransactionFilter.all
                                ? AppColors.primaryContainer.withValues(
                                    alpha: 0.15,
                                  )
                                : AppColors.surfaceContainerLowest,
                            foregroundColor: filter != TransactionFilter.all
                                ? AppColors.primary
                                : null,
                          ),
                        ),
                      ],
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
          if (allTransactions.isEmpty)
            _buildEmptyState(lang)
          else if (transactions.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverToBoxAdapter(
                child: LedgerCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.colossal),
                      child: Column(
                        children: [
                          Icon(
                            Icons.filter_list_off_rounded,
                            size: 48,
                            color: AppColors.onSurfaceVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const Gap(AppSpacing.lg),
                          Text(
                            'No ${filter.name} transactions.',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
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

// ─── Transaction Filter Sheet ─────────────────────────────────────
class _TransactionFilterSheet extends StatelessWidget {
  const _TransactionFilterSheet({
    required this.current,
    required this.onSelected,
  });

  final TransactionFilter current;
  final ValueChanged<TransactionFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Gap(AppSpacing.xl),
              Text(
                AppStrings.filterByType.primary,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const Gap(AppSpacing.lg),
              for (final filter in TransactionFilter.values)
                _FilterOption(
                  filter: filter,
                  isSelected: current == filter,
                  onTap: () {
                    onSelected(filter);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.filter,
    required this.isSelected,
    required this.onTap,
  });

  final TransactionFilter filter;
  final bool isSelected;
  final VoidCallback onTap;

  String get _label => switch (filter) {
    TransactionFilter.all => AppStrings.filterAll.primary,
    TransactionFilter.incoming => AppStrings.filterIncoming.primary,
    TransactionFilter.outgoing => AppStrings.filterOutgoing.primary,
  };

  IconData get _icon => switch (filter) {
    TransactionFilter.all => Icons.list_rounded,
    TransactionFilter.incoming => Icons.arrow_downward_rounded,
    TransactionFilter.outgoing => Icons.arrow_upward_rounded,
  };

  Color get _color => switch (filter) {
    TransactionFilter.all => AppColors.onSurface,
    TransactionFilter.incoming => AppColors.success,
    TransactionFilter.outgoing => AppColors.error,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(_icon, size: 20, color: _color),
              ),
              const Gap(AppSpacing.lg),
              Expanded(
                child: Text(
                  _label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : AppColors.onSurface,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
