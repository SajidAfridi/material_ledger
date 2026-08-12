import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/constants.dart';

/// A root-overlay notification surface for Yorks workspace actions.
///
/// Unlike a [SnackBar], this entry is inserted into the root navigator's
/// overlay after the active route. This deliberately keeps a server-confirmed
/// result visible when the action originated inside a dialog or popup.
enum YorksAppToastTone { information, success, error }

abstract final class YorksAppToast {
  static OverlayEntry? _entry;
  static Timer? _dismissTimer;

  /// Replaces any active notice with a single, accessible, lower-right toast.
  ///
  /// [title] is always announced. [message] is optional supporting context,
  /// such as the affected record reference. The caller remains responsible for
  /// supplying localized content.
  static void show(
    BuildContext context, {
    required String title,
    String? message,
    YorksAppToastTone tone = YorksAppToastTone.information,
    Duration duration = const Duration(seconds: 5),
  }) {
    _dismissTimer?.cancel();
    _entry?.remove();
    _entry = null;

    final navigator = Navigator.of(context, rootNavigator: true);
    final overlay = navigator.overlay;
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => _YorksAppToastSurface(
        title: title,
        message: message,
        tone: tone,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _dismissTimer = Timer(duration, () => _remove(entry));
  }

  /// Removes the active notice. Exposed for deterministic widget tests and
  /// for any future explicit notification-centre dismissal affordance.
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    final entry = _entry;
    _entry = null;
    entry?.remove();
  }

  static void _remove(OverlayEntry entry) {
    if (!identical(_entry, entry)) return;
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _entry = null;
    entry.remove();
  }
}

class _YorksAppToastSurface extends StatelessWidget {
  const _YorksAppToastSurface({
    required this.title,
    required this.message,
    required this.tone,
  });

  final String title;
  final String? message;
  final YorksAppToastTone tone;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth <= 720;
          final horizontalInset = compact ? AppSpacing.md : AppSpacing.xl;
          final availableWidth = math.max(
            0.0,
            constraints.maxWidth - (horizontalInset * 2),
          );
          final desiredWidth = compact
              ? availableWidth
              : math.min(720.0, math.max(400.0, constraints.maxWidth * .55));
          return IgnorePointer(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalInset,
                AppSpacing.md,
                horizontalInset,
                compact ? 80 : AppSpacing.xl,
              ),
              child: Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  label: message == null ? title : '$title. $message',
                  child: SizedBox(
                    width: desiredWidth,
                    child: _YorksAppToastCard(
                      title: title,
                      message: message,
                      tone: tone,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _YorksAppToastCard extends StatelessWidget {
  const _YorksAppToastCard({
    required this.title,
    required this.message,
    required this.tone,
  });

  final String title;
  final String? message;
  final YorksAppToastTone tone;

  @override
  Widget build(BuildContext context) {
    final icon = switch (tone) {
      YorksAppToastTone.success => Icons.check_rounded,
      YorksAppToastTone.error => Icons.error_outline_rounded,
      YorksAppToastTone.information => Icons.info_outline_rounded,
    };
    final iconBackground = switch (tone) {
      YorksAppToastTone.success => AppColors.success.withValues(alpha: .20),
      YorksAppToastTone.error => AppColors.error.withValues(alpha: .24),
      YorksAppToastTone.information => AppColors.blue.withValues(alpha: .22),
    };
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3319304E),
              blurRadius: 30,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(icon, color: AppColors.onPrimary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (message != null && message!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        message!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.onPrimary.withValues(alpha: .76),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
