import 'package:flutter/material.dart';

import '../constants/constants.dart';

/// Visible actor, role and time metadata for auditable records.
class AuditMeta extends StatelessWidget {
  const AuditMeta({
    super.key,
    required this.actor,
    required this.role,
    required this.timestamp,
  });

  final String actor;
  final String role;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.labelSmall.copyWith(color: AppColors.muted);

    return Semantics(
      container: true,
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xxs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            actor,
            style: style.copyWith(
              color: AppColors.inkSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text('•', style: style),
          Text(role, style: style),
          Text('•', style: style),
          Text(timestamp, style: style),
        ],
      ),
    );
  }
}

/// A compact activity row that keeps action detail tied to [AuditMeta].
class AuditTrailItem extends StatelessWidget {
  const AuditTrailItem({
    super.key,
    required this.action,
    required this.detail,
    required this.actor,
    required this.role,
    required this.timestamp,
    this.icon = Icons.monitor_heart_outlined,
    this.showDivider = true,
  });

  final String action;
  final String detail;
  final String actor;
  final String role;
  final String timestamp;
  final IconData icon;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.line))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, size: 15, color: AppColors.neutralText),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action, style: AppTypography.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(detail, style: AppTypography.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                AuditMeta(actor: actor, role: role, timestamp: timestamp),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
