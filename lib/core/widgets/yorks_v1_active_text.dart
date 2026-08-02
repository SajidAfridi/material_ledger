import 'package:flutter/material.dart';

import '../../shared/models/app_language.dart';
import '../../shared/models/app_strings.dart';

/// R35 workspace copy rendered in exactly one configured language.
///
/// This is intentionally scoped to the Yorks V1 redesign. Retained modules
/// continue using [BilingualText] until they receive their own approved UI
/// convergence work.
class YorksV1ActiveText extends StatelessWidget {
  const YorksV1ActiveText({
    super.key,
    required this.copy,
    required this.language,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final TranslatableString copy;
  final AppLanguage language;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => Text(
    copy.active(language),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    textDirection: language.isRtl ? TextDirection.rtl : TextDirection.ltr,
  );
}
