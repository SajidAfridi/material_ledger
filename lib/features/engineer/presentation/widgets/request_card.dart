import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/material_request.dart';

/// Card displaying a single material request.
///
/// Follows the Architectural Ledger design: tonal layering, no borders,
/// bilingual labels, status chips with 10% opacity fill.
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request, this.onActionTap});

  final MaterialRequest request;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return LedgerCard(
      onTap: onActionTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // Fill the full height of the constrained cell (grid or list).
        mainAxisSize: MainAxisSize.max,
        children: [
          // ─── Header: Name + Status ───────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.projectName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                        height: 1.3,
                      ),
                    ),
                    const Gap(AppSpacing.xs),
                    Text(
                      request.projectNameSecondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(AppSpacing.sm),
              _buildStatusChip(),
            ],
          ),

          const Gap(AppSpacing.md),

          // ─── Stats: Date | Item Count ────────────────────
          IntrinsicHeight(
            child: Row(
              children: [
                _StatColumn(
                  label: 'Date',
                  value: dateFormat.format(request.requestDate),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Container(
                    width: 1,
                    color: AppColors.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                _StatColumn(label: 'Items', value: '${request.itemCount}'),
              ],
            ),
          ),

          // ─── Push action to bottom (flexible so no overflow) ─
          const Flexible(child: SizedBox(height: AppSpacing.sm)),

          // ─── Action ──────────────────────────────────────
          Align(alignment: Alignment.centerRight, child: _buildActionButton()),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    return switch (request.status) {
      RequestStatus.draft => StatusChip.info(request.status.label),
      RequestStatus.pending => StatusChip.warning(request.status.label),
      RequestStatus.available => StatusChip.success(request.status.label),
      RequestStatus.deployed => StatusChip.info(request.status.label),
      RequestStatus.rejected => StatusChip.error(request.status.label),
    };
  }

  Widget _buildActionButton() {
    final (label, icon) = switch (request.status) {
      RequestStatus.draft => ('EDIT DRAFT', Icons.edit_rounded),
      RequestStatus.pending => ('VIEW DETAILS', Icons.chevron_right_rounded),
      RequestStatus.available => ('PICK UP', Icons.local_shipping_outlined),
      RequestStatus.deployed => ('HISTORY', Icons.history_rounded),
      RequestStatus.rejected => ('VIEW DETAILS', Icons.chevron_right_rounded),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onActionTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
              const Gap(AppSpacing.sm),
              Icon(icon, size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stat Column ──────────────────────────────────────────────────
class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.65),
          ),
        ),
        const Gap(AppSpacing.xs),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
