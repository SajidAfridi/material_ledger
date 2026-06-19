import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/sync/sync_engine.dart';

/// "More" tab — administration ONLY (admin role). The operational modules that
/// used to live in the old Admin Panel (procurement, inventory, requests,
/// project costs, people, rentals) now have their own tabs; this hub keeps only
/// User management, Access & roles, Audit trail, Settings, Data & sync, Sign out.
class MoreHubScreen extends ConsumerWidget {
  const MoreHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final syncState = ref.watch(syncStatusProvider);

    return SafeArea(
      child: ResponsiveCenter(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.screenVertical,
            AppSpacing.screenHorizontal,
            AppSpacing.xxl,
          ),
          children: [
            BilingualText(
              english: AppStrings.adminSettings.primary,
              secondary: AppStrings.adminSettingsSubtitle.primary,
              englishStyle: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.28,
                color: AppColors.onSurface,
              ),
              secondaryStyle: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const Gap(AppSpacing.xl),

            // ─── Administration ──────────────────────────────
            _SectionHeader(label: AppStrings.administration.primary),
            const Gap(AppSpacing.md),
            _NavCard(
              icon: Icons.manage_accounts_outlined,
              title: AppStrings.userManagement.primary,
              subtitle: AppStrings.userManagementHint.primary,
              onTap: () => context.push(RoutePaths.users),
            ),
            const Gap(AppSpacing.listItemGap),
            _NavCard(
              icon: Icons.admin_panel_settings_outlined,
              title: AppStrings.accessRoles.primary,
              subtitle: AppStrings.accessRolesHint.primary,
              onTap: () => context.push(RoutePaths.accessRoles),
            ),
            const Gap(AppSpacing.listItemGap),
            _NavCard(
              icon: Icons.history_rounded,
              title: AppStrings.auditTrail.primary,
              subtitle: AppStrings.auditTrailHint.primary,
              onTap: () => context.push(RoutePaths.activityLog),
            ),
            const Gap(AppSpacing.xl),

            // ─── System ──────────────────────────────────────
            _SectionHeader(label: AppStrings.system.primary),
            const Gap(AppSpacing.md),
            // One unified account/settings screen for every role — the same
            // clean Profile screen engineers and procurement reach, so there's
            // no second, divergent settings page to get lost in.
            _NavCard(
              icon: Icons.person_outline_rounded,
              title: AppStrings.profile.primary,
              subtitle: AppStrings.settings.primary,
              onTap: () => context.push(RoutePaths.engineerProfile),
            ),
            const Gap(AppSpacing.listItemGap),
            _NavCard(
              icon: Icons.cloud_sync_outlined,
              title: AppStrings.dataSync.primary,
              subtitle: AppStrings.dataSyncHint.primary,
              trailing: _SyncBadge(state: syncState),
              onTap: () => context.push(RoutePaths.dataSync),
            ),
            const Gap(AppSpacing.listItemGap),
            _NavCard(
              icon: Icons.logout_rounded,
              iconColor: AppColors.error,
              title: AppStrings.signOut.primary,
              subtitle: AppStrings.logout.secondary(lang),
              titleColor: AppColors.error,
              onTap: () => _signOut(context, ref),
            ),
            const Gap(AppSpacing.huge),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
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
        content: Text(
          'Are you sure you want to logout?',
          style: AppTypography.bodyMedium,
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

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      SyncState.synced => (AppStrings.allSynced.primary, AppColors.success),
      SyncState.syncing => ('Syncing', AppColors.primary),
      SyncState.offlineQueued => ('Queued', AppColors.warning),
      SyncState.error => ('Needs attention', AppColors.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppTypography.titleMedium);
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, size: 22, color: iconColor ?? AppColors.primary),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(color: titleColor),
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[trailing!, const Gap(AppSpacing.sm)],
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
