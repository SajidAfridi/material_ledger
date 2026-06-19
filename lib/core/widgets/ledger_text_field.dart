import 'package:flutter/material.dart';

import '../constants/constants.dart';

/// Input field following design spec:
/// Flat design. [surfaceContainerHighest] background with
/// bottom-only primary stroke (2px) on focus.
/// Bilingual: English label above, Urdu placeholder inside.
class LedgerTextField extends StatelessWidget {
  const LedgerTextField({
    super.key,
    this.controller,
    this.label,
    this.urduHint,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController? controller;
  final String? label;
  final String? urduHint;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          enabled: enabled,
          autofocus: autofocus,
          readOnly: readOnly,
          onTap: onTap,
          style: AppTypography.bodyLarge,
          decoration: InputDecoration(
            hintText: urduHint ?? hintText,
            hintTextDirection: urduHint != null ? TextDirection.rtl : null,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
