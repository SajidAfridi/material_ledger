import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/providers/employee_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/session_provider.dart';
import '../../../../shared/sync/connectivity_service.dart';

/// Profile screen — engineer account & settings.
class EngineerProfileScreen extends ConsumerWidget {
  const EngineerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final currency = ref.watch(currencyProvider);
    final role = ref.watch(currentRoleProvider);
    final online = ref.watch(isOnlineProvider);
    // Same source as the home "My data" card + the /me detail screen.
    final emp = ref.watch(employeeProvider);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // ─── Header ─────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.screenVertical,
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
            ),
            sliver: SliverToBoxAdapter(
              child: BilingualText(
                english: AppStrings.profile.primary,
                secondary: AppStrings.profile.secondary(lang),
                englishStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.28,
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ),

          // ─── Profile Card ──────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(
              child: LedgerCard(
                // Tapping the header opens the same employee-data screen as the
                // home "My data → Show more" card.
                onTap: () => context.push(RoutePaths.employeeDetail),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.15,
                        ),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        emp.initials,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Gap(AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(emp.name, style: AppTypography.titleMedium),
                          const Gap(AppSpacing.xxs),
                          Text(
                            '${emp.title} · ${emp.employeeId}',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverGap(AppSpacing.xl),

          // ─── Workspace ─────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(
              child: LedgerCard(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    _ProfileTile(
                      icon: Icons.history_rounded,
                      title: 'Activity Log',
                      onTap: () => context.push(RoutePaths.activityLog),
                    ),
                    // Dev-only role switcher. In production the role comes from
                    // the signed-in user's credentials and routing is automatic,
                    // so this is hidden in release builds.
                    if (kDebugMode)
                      _ProfileTile(
                        icon: Icons.badge_outlined,
                        title: 'Role (dev)',
                        subtitle: role.label,
                        onTap: () => RolePickerSheet.show(context),
                      ),
                    // Dev-only connectivity simulator — demo the offline →
                    // queued → synced flow without leaving Wi-Fi. Release-hidden.
                    if (kDebugMode)
                      _ProfileTile(
                        icon: online
                            ? Icons.wifi_rounded
                            : Icons.wifi_off_rounded,
                        title: 'Simulate offline (dev)',
                        trailing: Switch(
                          value: !online,
                          onChanged: (offline) =>
                              _setOffline(ref, offline: offline),
                        ),
                        onTap: () => _setOffline(ref, offline: online),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SliverGap(AppSpacing.xl),

          // ─── Settings ──────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(
              child: LedgerCard(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    _ProfileTile(
                      icon: Icons.notifications_outlined,
                      title: AppStrings.notifications.primary,
                      onTap: () => context.push(RoutePaths.notifications),
                    ),
                    _ProfileTile(
                      icon: Icons.translate_rounded,
                      title: AppStrings.secondaryLanguage.primary,
                      subtitle: lang.name,
                      onTap: () => LanguagePickerSheet.show(
                        context,
                        current: lang,
                        onSelected: (l) =>
                            ref.read(languageProvider.notifier).setLanguage(l),
                      ),
                    ),
                    _ProfileTile(
                      icon: Icons.currency_exchange_rounded,
                      title: AppStrings.currency.primary,
                      subtitle: '${currency.flag} ${currency.code}',
                      onTap: () => CurrencyPickerSheet.show(
                        context,
                        current: currency,
                        onSelected: (c) =>
                            ref.read(currencyProvider.notifier).setCurrency(c),
                      ),
                    ),
                    _ProfileTile(
                      icon: Icons.info_outline_rounded,
                      title: AppStrings.about.primary,
                      onTap: () => context.push(RoutePaths.about),
                    ),
                    _ProfileTile(
                      icon: Icons.logout_rounded,
                      title: AppStrings.logout.primary,
                      onTap: () => _logout(context, ref),
                      isDestructive: true,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Version ───────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Text(
                  'Yorks GodownPro v1.0.0 — ${role.label}',
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

  /// Dev helper: flip the simulated connectivity so the sync states are
  /// demoable. No-op against a real connectivity service in production.
  void _setOffline(WidgetRef ref, {required bool offline}) {
    final c = ref.read(connectivityProvider);
    if (c is DefaultConnectivity) c.setOnline(!offline);
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
        content: Text(
          'Are you sure you want to logout?',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              AppStrings.cancel.primary,
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
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

// ─── Profile Tile ────────────────────────────────────────────────
class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.isDestructive = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.onSurfaceVariant;

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
            Icon(icon, size: 22, color: color),
            const Gap(AppSpacing.lg),
            Expanded(
              child: Text(
                title,
                style: AppTypography.bodyLarge.copyWith(
                  color: isDestructive ? AppColors.error : null,
                ),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
