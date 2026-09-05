import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/constants.dart';
import '../../shared/models/app_language.dart';

/// A reusable bottom sheet for selecting the secondary language.
///
/// Used by both the admin Settings screen and the Engineer Profile screen.
class LanguagePickerSheet extends StatelessWidget {
  const LanguagePickerSheet({
    super.key,
    required this.current,
    required this.onSelected,
    this.title = 'Secondary Language',
    this.description = 'English is always the primary language',
    this.textDirection = TextDirection.ltr,
  });

  final AppLanguage current;
  final ValueChanged<AppLanguage> onSelected;
  final String title;
  final String description;
  final TextDirection textDirection;

  /// Convenience method to show this picker as a modal bottom sheet.
  static void show(
    BuildContext context, {
    required AppLanguage current,
    required ValueChanged<AppLanguage> onSelected,
    String title = 'Secondary Language',
    String description = 'English is always the primary language',
    TextDirection textDirection = TextDirection.ltr,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (_) => LanguagePickerSheet(
        current: current,
        title: title,
        description: description,
        textDirection: textDirection,
        onSelected: (lang) {
          onSelected(lang);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: textDirection,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.xxxl,
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
              const Gap(AppSpacing.xxl),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const Gap(AppSpacing.sm),
              Text(
                description,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.inkSecondary,
                ),
              ),
              const Gap(AppSpacing.xxl),
              ...AppLanguage.values.map((lang) {
                final isSelected = lang == current;
                return Semantics(
                  selected: isSelected,
                  button: true,
                  label: '${lang.name}, ${lang.nativeName}',
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: InkWell(
                        onTap: () => onSelected(lang),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                        child: AnimatedContainer(
                          duration: Duration.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.lg,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.surfaceContainerLowest
                                : AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusLg,
                            ),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.4)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                    const Gap(AppSpacing.xxs),
                                    Text(
                                      lang.nativeName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.inkSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
