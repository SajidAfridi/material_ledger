import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/app_language.dart';
import '../../shared/providers/language_provider.dart';
import '../constants/constants.dart';

/// Bilingual text widget — pairs English with the user's secondary language.
///
/// **Design spec**: Every English label must be paired with its secondary
/// counterpart. Secondary text sits exactly 4px below the English baseline,
/// 2pt smaller, using [onSurfaceVariant].
class BilingualText extends ConsumerWidget {
  const BilingualText({
    super.key,
    required this.english,
    required this.secondary,
    this.englishStyle,
    this.secondaryStyle,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.gap = AppSpacing.bilingualGap,
  });

  /// The English primary text.
  final String english;

  /// The secondary language text.
  final String secondary;

  /// Style for the English text. Defaults to [bodyMedium].
  final TextStyle? englishStyle;

  /// Style override for secondary text. If null, auto-derives from English.
  final TextStyle? secondaryStyle;

  /// Alignment of the text column.
  final CrossAxisAlignment crossAxisAlignment;

  /// Gap between English and secondary baselines (default 4px).
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final secondaryIsRtl = lang.isRtl || lang == AppLanguage.english;
    final enStyle = englishStyle ?? AppTypography.bodyMedium;
    final secStyle =
        secondaryStyle ?? _secondaryStyleFor(lang, enStyle.fontSize ?? 14);

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(english, style: enStyle),
        SizedBox(height: gap),
        Text(
          secondary,
          style: secStyle,
          textDirection: secondaryIsRtl ? TextDirection.rtl : TextDirection.ltr,
        ),
      ],
    );
  }

  /// Build the secondary text style based on the selected language.
  static TextStyle _secondaryStyleFor(AppLanguage lang, double enFontSize) {
    // English mode deliberately falls back to Arabic as its secondary layer.
    // Arabic and Urdu must use the bundled Arabic-script font explicitly;
    // inheriting NexusSans renders missing-glyph boxes in deterministic web
    // and golden-test environments.
    if (lang == AppLanguage.english ||
        lang == AppLanguage.arabic ||
        lang == AppLanguage.urdu) {
      return TextStyle(
        fontFamily: 'NotoSansArabic',
        fontSize: (enFontSize - 5).clamp(8, 24).toDouble(),
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: AppColors.onSurfaceVariant.withValues(alpha: 0.9),
      );
    }
    return TextStyle(
      fontSize: (enFontSize - 5).clamp(8, 20).toDouble(),
      fontWeight: FontWeight.w400,
      height: 1.2,
      color: AppColors.onSurfaceVariant.withValues(alpha: 0.9),
    );
  }
}
