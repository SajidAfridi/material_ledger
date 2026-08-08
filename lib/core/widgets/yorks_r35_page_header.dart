import 'package:flutter/material.dart';

import '../constants/constants.dart';

/// Final R35 content header used by Yorks V1 operational routes.
///
/// The global shell owns the breadcrumb/context bar. This header intentionally
/// owns the record-page hierarchy underneath it: a compact eyebrow, a clear
/// title, a calm explanatory line and one controlled action group.
class YorksR35PageHeader extends StatelessWidget {
  const YorksR35PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
    this.actions = const [],
  });

  final String eyebrow;
  final String title;
  final String? description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < AppSpacing.compactBreakpoint;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: AppTypography.eyebrow.copyWith(
            color: AppColors.blue,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          style: compact
              ? AppTypography.headlineLarge.copyWith(
                  color: AppColors.ink,
                  fontSize: 27,
                  height: 1.08,
                  letterSpacing: -0.75,
                )
              : AppTypography.headlineLarge.copyWith(color: AppColors.ink),
        ),
        if (description != null) ...[
          const SizedBox(height: 7),
          Text(
            description!,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.muted,
              fontSize: compact ? 11.5 : 12.5,
            ),
          ),
        ],
      ],
    );

    if (compact || actions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: actions,
            ),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: heading),
        const SizedBox(width: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.end,
          children: actions,
        ),
      ],
    );
  }
}
