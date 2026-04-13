import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/providers/language_provider.dart';

/// Settings — App configuration.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final currency = ref.watch(currencyProvider);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // ─── Header ──────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.screenVertical,
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
            ),
            sliver: SliverToBoxAdapter(
              child: BilingualText(
                english: AppStrings.settings.primary,
                secondary: AppStrings.settings.secondary(lang),
                englishStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.28,
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ),

          // ─── Settings Items ──────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(
              child: LedgerCard(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.notifications_outlined,
                      title: AppStrings.notifications.primary,
                      secondaryTitle: AppStrings.notifications.secondary(lang),
                      showChevron: true,
                      onTap: () => context.push(RoutePaths.notifications),
                    ),
                    _SettingsTile(
                      icon: Icons.translate_rounded,
                      title: AppStrings.secondaryLanguage.primary,
                      secondaryTitle: AppStrings.secondaryLanguage.secondary(
                        lang,
                      ),
                      trailing: Text(
                        lang.name,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => LanguagePickerSheet.show(
                        context,
                        current: lang,
                        onSelected: (l) =>
                            ref.read(languageProvider.notifier).setLanguage(l),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.currency_exchange_rounded,
                      title: AppStrings.currency.primary,
                      secondaryTitle: AppStrings.currency.secondary(lang),
                      trailing: Text(
                        '${currency.flag} ${currency.code}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => CurrencyPickerSheet.show(
                        context,
                        current: currency,
                        onSelected: (c) =>
                            ref.read(currencyProvider.notifier).setCurrency(c),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.palette_outlined,
                      title: AppStrings.appearance.primary,
                      secondaryTitle: AppStrings.appearance.secondary(lang),
                      trailing: Text(
                        AppStrings.light.primary,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      onTap: () {},
                    ),
                    _SettingsTile(
                      icon: Icons.backup_outlined,
                      title: AppStrings.backupSync.primary,
                      secondaryTitle: AppStrings.backupSync.secondary(lang),
                      onTap: () {},
                    ),
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: AppStrings.about.primary,
                      secondaryTitle: AppStrings.about.secondary(lang),
                      onTap: () => context.push(RoutePaths.about),
                      showChevron: true,
                    ),
                    _SettingsTile(
                      icon: Icons.logout_rounded,
                      title: AppStrings.logout.primary,
                      secondaryTitle: AppStrings.logout.secondary(lang),
                      onTap: () => _logout(context, ref),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── App Version ─────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Text(
                  'GodownPro v1.0.0',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final lang = ref.read(languageProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        title: Text(
          AppStrings.logout.primary,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to logout?',
              style: AppTypography.bodyMedium,
            ),
            const Gap(AppSpacing.xs),
            Text(
              AppStrings.logout.secondary(lang),
              style: AppTypography.bodySmall,
              textDirection: lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppStrings.logout.primary,
              style: AppTypography.labelLarge.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(authSessionProvider.notifier).logout();
    if (!context.mounted) return;
    context.go(RoutePaths.login);
  }
}

// ─── Settings Tile ──────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.secondaryTitle,
    this.trailing,
    this.onTap,
    this.showChevron = false,
  });

  final IconData icon;
  final String title;
  final String secondaryTitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.onSurfaceVariant),
            const Gap(AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyLarge),
                  const Gap(AppSpacing.xxs),
                  Text(secondaryTitle, style: AppTypography.bodySmall),
                ],
              ),
            ),
            ?trailing,
            if (showChevron)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
