import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/material_request.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_request_provider.dart';

/// Request detail screen — shows full info for a single material request.
///
/// Matches the Architectural Ledger design:
/// - Back nav, large ID header, status chip
/// - Stats row: Total Value | Items | Issue Date
/// - Material Breakdown table
/// - Request Timeline (vertical stepper)
/// - Verification card (Issued By / Requested By)
/// - Action buttons (Download Receipt, Print Order)
class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final requests = ref.watch(materialRequestsProvider);
    final request = requests.where((r) => r.id == requestId).firstOrNull;

    if (request == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: Text('Request not found', style: AppTypography.titleMedium),
        ),
      );
    }

    final timeFormat = DateFormat('hh:mm a');
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 840;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Back Button + Header ──────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.lg,
                AppSpacing.screenHorizontal,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    InkWell(
                      onTap: () => context.go(RoutePaths.engineerHome),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const Gap(AppSpacing.sm),
                            BilingualText(
                              english: AppStrings.backToRequests.primary,
                              secondary: AppStrings.backToRequests.secondary(
                                lang,
                              ),
                              englishStyle: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                              gap: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(AppSpacing.lg),

                    // Request ID (large)
                    Text(
                      request.id.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: isWide ? 36 : 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Gap(AppSpacing.sm),

                    // Status + Updated
                    Row(
                      children: [
                        _buildStatusChip(request.status),
                        const Gap(AppSpacing.md),
                        Text(
                          '${AppStrings.updated.primary} ${_timeAgo(request.requestDate)}',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                    const Gap(AppSpacing.xl),

                    // Action buttons — draft vs submitted
                    if (request.status == RequestStatus.draft)
                      _DraftActionButtons(
                        requestId: request.id,
                        isWide: isWide,
                        lang: lang,
                      )
                    else if (isWide)
                      Row(
                        children: [
                          const Spacer(),
                          _ActionButton(
                            label: AppStrings.downloadReceipt.primary,
                            secondaryLabel: AppStrings.downloadReceipt
                                .secondary(lang),
                            icon: Icons.download_rounded,
                            isPrimary: false,
                          ),
                          const Gap(AppSpacing.md),
                          _ActionButton(
                            label: AppStrings.printOrder.primary,
                            secondaryLabel: AppStrings.printOrder.secondary(
                              lang,
                            ),
                            icon: Icons.print_rounded,
                            isPrimary: true,
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              label: AppStrings.downloadReceipt.primary,
                              secondaryLabel: AppStrings.downloadReceipt
                                  .secondary(lang),
                              icon: Icons.download_rounded,
                              isPrimary: false,
                            ),
                          ),
                          const Gap(AppSpacing.md),
                          Expanded(
                            child: _ActionButton(
                              label: AppStrings.printOrder.primary,
                              secondaryLabel: AppStrings.printOrder.secondary(
                                lang,
                              ),
                              icon: Icons.print_rounded,
                              isPrimary: true,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SliverGap(AppSpacing.xxl),

            // ─── Stats Row ─────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverToBoxAdapter(
                child: isWide
                    ? Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: AppStrings.totalValueLabel.primary,
                              labelSecondary: AppStrings.totalValueLabel
                                  .secondary(lang),
                              value: 'Rs. 1.2M',
                              subtitle:
                                  '${AppStrings.budgetCode.primary}: CON-24-X',
                            ),
                          ),
                          const Gap(AppSpacing.listItemGap),
                          Expanded(
                            child: _StatCard(
                              label: 'ITEMS',
                              labelSecondary: AppStrings.items.secondary(lang),
                              value: '${request.itemCount} Units',
                              subtitle:
                                  '${request.categoryCount} ${AppStrings.categories.primary}',
                            ),
                          ),
                          const Gap(AppSpacing.listItemGap),
                          Expanded(
                            child: _StatCard(
                              label: AppStrings.issueDateLabel.primary,
                              labelSecondary: AppStrings.issueDateLabel
                                  .secondary(lang),
                              value: DateFormat(
                                'MMM d',
                              ).format(request.requestDate),
                              subtitle:
                                  'Time: ${timeFormat.format(request.requestDate)}',
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: AppStrings.totalValueLabel.primary,
                                  labelSecondary: AppStrings.totalValueLabel
                                      .secondary(lang),
                                  value: 'Rs. 1.2M',
                                  subtitle:
                                      '${AppStrings.budgetCode.primary}: CON-24-X',
                                ),
                              ),
                              const Gap(AppSpacing.listItemGap),
                              Expanded(
                                child: _StatCard(
                                  label: 'ITEMS',
                                  labelSecondary: AppStrings.items.secondary(
                                    lang,
                                  ),
                                  value: '${request.itemCount} Units',
                                  subtitle:
                                      '${request.categoryCount} ${AppStrings.categories.primary}',
                                ),
                              ),
                            ],
                          ),
                          const Gap(AppSpacing.listItemGap),
                          _StatCard(
                            label: AppStrings.issueDateLabel.primary,
                            labelSecondary: AppStrings.issueDateLabel.secondary(
                              lang,
                            ),
                            value: DateFormat(
                              'MMM d',
                            ).format(request.requestDate),
                            subtitle:
                                'Time: ${timeFormat.format(request.requestDate)}',
                          ),
                        ],
                      ),
              ),
            ),

            const SliverGap(AppSpacing.xxl),

            // ─── Content: Material Breakdown + Timeline ─────
            if (isWide)
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _MaterialBreakdownCard(
                          request: request,
                          lang: lang,
                        ),
                      ),
                      const Gap(AppSpacing.listItemGap),
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            _TimelineCard(request: request, lang: lang),
                            const Gap(AppSpacing.listItemGap),
                            _VerificationCard(lang: lang),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Mobile: stacked
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                sliver: SliverToBoxAdapter(
                  child: _MaterialBreakdownCard(request: request, lang: lang),
                ),
              ),
              const SliverGap(AppSpacing.listItemGap),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                sliver: SliverToBoxAdapter(
                  child: _TimelineCard(request: request, lang: lang),
                ),
              ),
              const SliverGap(AppSpacing.listItemGap),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                sliver: SliverToBoxAdapter(
                  child: _VerificationCard(lang: lang),
                ),
              ),
            ],

            const SliverGap(AppSpacing.colossal),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(RequestStatus status) {
    return switch (status) {
      RequestStatus.draft => StatusChip.info(status.label),
      RequestStatus.pending => StatusChip.warning(status.label),
      RequestStatus.available => StatusChip.success(status.label),
      RequestStatus.deployed => StatusChip.info(status.label),
      RequestStatus.rejected => StatusChip.error(status.label),
    };
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }
}

// ─── Action Button ──────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.secondaryLabel,
    required this.icon,
    required this.isPrimary,
  });

  final String label;
  final String secondaryLabel;
  final IconData icon;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: AppColors.onPrimary),
                const Gap(AppSpacing.sm),
                Flexible(
                  child: Text(
                    '$label / $secondaryLabel',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  '$label / $secondaryLabel',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Draft Action Buttons ───────────────────────────────────────────
class _DraftActionButtons extends ConsumerWidget {
  const _DraftActionButtons({
    required this.requestId,
    required this.isWide,
    required this.lang,
  });

  final String requestId;
  final bool isWide;
  final dynamic lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // Delete Draft
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    ),
                    title: Text(
                      AppStrings.deleteDraft.primary,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    content: Text(
                      'This draft will be permanently removed.',
                      style: AppTypography.bodyMedium,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(
                          AppStrings.cancel.primary,
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          AppStrings.delete.primary,
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                ref
                    .read(materialRequestsProvider.notifier)
                    .removeRequest(requestId);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppStrings.requestDeletedSuccess.primary),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                );
                context.go(RoutePaths.engineerHome);
              },
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: AppColors.error,
                    ),
                    const Gap(AppSpacing.sm),
                    Flexible(
                      child: Text(
                        AppStrings.deleteDraft.primary,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Gap(AppSpacing.md),
        // Submit Draft
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ref
                    .read(materialRequestsProvider.notifier)
                    .submitDraft(requestId);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppStrings.requestSubmitted.primary),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                );
                context.go(RoutePaths.engineerHome);
              },
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.send_rounded,
                      size: 18,
                      color: AppColors.onPrimary,
                    ),
                    const Gap(AppSpacing.sm),
                    Flexible(
                      child: Text(
                        '${AppStrings.submitRequest.primary} / ${AppStrings.submitRequest.secondary(lang)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Stat Card ──────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.labelSecondary,
    required this.value,
    this.subtitle,
  });

  final String label;
  final String labelSecondary;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 840;

    return LedgerCard(
      padding: EdgeInsets.all(isWide ? AppSpacing.cardPadding : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: isWide ? 11 : 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Gap(AppSpacing.xs),
              Flexible(
                child: Text(
                  '/ $labelSecondary',
                  style: TextStyle(
                    fontSize: isWide ? 10 : 9,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.md),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isWide ? 24 : 18,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const Gap(AppSpacing.xs),
            Text(
              subtitle!,
              style: AppTypography.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Material Breakdown Card ────────────────────────────────────────
class _MaterialBreakdownCard extends StatelessWidget {
  const _MaterialBreakdownCard({required this.request, required this.lang});

  final MaterialRequest request;
  final dynamic lang;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 840;

    // Use real line items from the request
    final items = request.lineItems;

    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: BilingualText(
                  english: AppStrings.materialBreakdown.primary,
                  secondary: AppStrings.materialBreakdown.secondary(lang),
                  englishStyle: GoogleFonts.inter(
                    fontSize: isWide ? 18 : 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  '${items.length} ${AppStrings.items.primary}',
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.xl),

          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.2),
                    ),
                    const Gap(AppSpacing.md),
                    Text(
                      'No items in this request',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          else if (isWide) ...[
            // Table header (wide only)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _tableHeader(
                    AppStrings.itemLabel.primary,
                    AppStrings.itemLabel.secondary(lang),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _tableHeader(
                    AppStrings.reqQty.primary,
                    AppStrings.reqQty.secondary(lang),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _tableHeader(
                    AppStrings.unit.primary.toUpperCase(),
                    AppStrings.unit.secondary(lang),
                  ),
                ),
              ],
            ),
            const Gap(AppSpacing.lg),

            // Wide rows
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                child: _buildRow(item),
              ),
            ),
          ] else ...[
            // Mobile: card-based layout
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _buildMobileCard(item),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tableHeader(String primary, String secondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          primary,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
        if (secondary.isNotEmpty)
          Text(
            secondary,
            style: TextStyle(
              fontSize: 9,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
      ],
    );
  }

  IconData _iconForUnit(String unitSymbol) {
    return switch (unitSymbol.toLowerCase()) {
      'bags' => Icons.diamond_outlined,
      'tons' || 'kg' => Icons.grid_4x4_rounded,
      'l' => Icons.water_drop_outlined,
      'm' || 'sqft' || 'm³' => Icons.straighten_rounded,
      'pcs' || 'sheets' || 'rods' => Icons.view_module_outlined,
      _ => Icons.inventory_2_outlined,
    };
  }

  Widget _buildRow(RequestLineItem item) {
    return Row(
      children: [
        // Item name + icon
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  _iconForUnit(item.unitSymbol),
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const Gap(AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.materialName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.materialNameSecondary.isNotEmpty)
                      Text(
                        item.materialNameSecondary,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Quantity
        Expanded(
          flex: 2,
          child: Text(
            '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unitSymbol}',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ),

        // Unit chip
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                item.unitSymbol.toUpperCase(),
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCard(RequestLineItem item) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              _iconForUnit(item.unitSymbol),
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.materialName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.materialNameSecondary.isNotEmpty)
                  Text(
                    item.materialNameSecondary,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const Gap(AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  item.unitSymbol.toUpperCase(),
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Timeline Card ──────────────────────────────────────────────────
class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.request, required this.lang});

  final MaterialRequest request;
  final dynamic lang;

  @override
  Widget build(BuildContext context) {
    final isDeployed = request.status == RequestStatus.deployed;
    final isAvailable = request.status == RequestStatus.available || isDeployed;

    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BilingualText(
            english: AppStrings.requestTimeline.primary,
            secondary: AppStrings.requestTimeline.secondary(lang),
            englishStyle: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const Gap(AppSpacing.xxl),

          // Timeline events (newest first)
          if (isDeployed)
            _TimelineEvent(
              icon: Icons.local_shipping_rounded,
              iconColor: AppColors.primary,
              title: AppStrings.requestDeployed.primary,
              subtitle: AppStrings.requestDeployed.secondary(lang),
              time: 'Today, 2:30 PM',
              timeColor: AppColors.primary,
              isFirst: true,
            ),
          if (isAvailable)
            _TimelineEvent(
              icon: Icons.check_box_rounded,
              iconColor: AppColors.success,
              title: AppStrings.stockValidated.primary,
              subtitle: AppStrings.stockValidated.secondary(lang),
              time: 'Oct 24, 11:15 AM',
              isFirst: !isDeployed,
            ),
          _TimelineEvent(
            icon: Icons.edit_document,
            iconColor: AppColors.primary,
            title: AppStrings.requestCreated.primary,
            subtitle: AppStrings.requestCreated.secondary(lang),
            time: DateFormat('MMM d, hh:mm a').format(request.requestDate),
            isLast: true,
            isFirst: !isAvailable && !isDeployed,
          ),
        ],
      ),
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  const _TimelineEvent({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    this.timeColor,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  final Color? timeColor;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ),
          const Gap(AppSpacing.md),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Gap(AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const Gap(AppSpacing.xs),
                  Text(
                    time,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: timeColor ?? AppColors.onSurfaceVariant,
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

// ─── Verification Card ──────────────────────────────────────────────
class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.lang});

  final dynamic lang;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BilingualText(
            english: AppStrings.verification.primary,
            secondary: AppStrings.verification.secondary(lang),
            englishStyle: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const Gap(AppSpacing.xxl),

          // Issued By
          _PersonRow(
            roleLabel: AppStrings.issuedBy.primary,
            name: 'Arshad Khan',
            title: 'Store Supervisor',
          ),
          const Gap(AppSpacing.xl),

          // Requested By
          _PersonRow(
            roleLabel: AppStrings.requestedBy.primary,
            name: 'Engr. Salman Ahmed',
            title: 'Project Lead',
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.roleLabel,
    required this.name,
    required this.title,
  });

  final String roleLabel;
  final String name;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.person_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
        ),
        const Gap(AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                roleLabel,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              const Gap(AppSpacing.xxs),
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              Text(title, style: AppTypography.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
