import 'package:flutter/material.dart';

import '../constants/constants.dart';

/// Responsive V7 browser/mobile page primitive.
///
/// Desktop keeps an operational inspector beside the main content. Tablet and
/// mobile stack that inspector below the primary work area instead of squeezing
/// a desktop split view.
class NexusPageShell extends StatelessWidget {
  const NexusPageShell({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.child,
    this.description,
    this.actions = const [],
    this.inspector,
    this.controller,
    this.maxWidth = AppSpacing.pageMaxWidth,
  });

  static const primaryContentKey = ValueKey('nexus-page-primary-content');
  static const inspectorKey = ValueKey('nexus-page-inspector');

  final String eyebrow;
  final String title;
  final String? description;
  final List<Widget> actions;
  final Widget child;
  final Widget? inspector;
  final ScrollController? controller;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth <= AppSpacing.compactBreakpoint;
          final stackInspector =
              constraints.maxWidth <= AppSpacing.stackedBreakpoint;
          final horizontal = compact
              ? AppSpacing.mobileScreenHorizontal
              : AppSpacing.screenHorizontal;
          final vertical = compact
              ? AppSpacing.mobileScreenVertical
              : AppSpacing.screenVertical;

          final primary = KeyedSubtree(key: primaryContentKey, child: child);
          final inspectorContent = inspector == null
              ? null
              : KeyedSubtree(key: inspectorKey, child: inspector!);

          return SingleChildScrollView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(horizontal, vertical, horizontal, 70),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NexusPageHeader(
                      eyebrow: eyebrow,
                      title: title,
                      description: description,
                      actions: actions,
                      compact: compact,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (inspectorContent == null)
                      primary
                    else if (stackInspector)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          primary,
                          const SizedBox(height: AppSpacing.lg),
                          inspectorContent,
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: primary),
                          const SizedBox(width: AppSpacing.lg),
                          SizedBox(
                            width: AppSpacing.inspectorWidth,
                            child: inspectorContent,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class NexusPageHeader extends StatelessWidget {
  const NexusPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
    this.actions = const [],
    this.compact = false,
  });

  final String eyebrow;
  final String title;
  final String? description;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow.toUpperCase(), style: AppTypography.eyebrow),
        const SizedBox(height: 7),
        Text(
          title,
          style: compact
              ? AppTypography.headlineMedium
              : AppTypography.headlineLarge,
        ),
        if (description != null) ...[
          const SizedBox(height: 7),
          Text(description!, style: AppTypography.bodyMedium),
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
