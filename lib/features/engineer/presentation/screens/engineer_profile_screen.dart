import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router.dart';
import '../../../../app/yorks_v1_workspace_status_label.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/security/session_lock.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_engineering_tools_strings.dart';
import '../../../../shared/models/yorks_v1_workspace_status.dart';
import '../../../../shared/providers/employee_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/session_provider.dart';
import '../../../../shared/providers/yorks_v1_feature_flags_provider.dart';
import '../../../../shared/providers/yorks_v1_workspace_status_provider.dart';
import '../../../../shared/services/app_config_service.dart';
import '../../../../shared/sync/connectivity_service.dart';
import '../../../../shared/sync/sync_engine.dart';

/// Profile screen — engineer account & settings.
class EngineerProfileScreen extends ConsumerWidget {
  const EngineerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final currency = ref.watch(currencyProvider);
    final role = ref.watch(currentRoleProvider);
    final online = ref.watch(isOnlineProvider);
    final engineeringToolsEnabled = ref
        .watch(yorksV1FeatureFlagsProvider)
        .documents;
    // Same source as the home "My data" card + the /me detail screen.
    final emp = ref.watch(employeeProvider);

    if (YorksMobileUi.isActive(context)) {
      return _MobileEngineerProfile(onLogout: () => _logout(context, ref));
    }

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
                            emp.linked
                                ? '${emp.title} · ${emp.employeeId}'
                                : emp.title,
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
                    // Owner/admin approves leave in the office panel — they don't
                    // request it. Engineers and procurement (linked employees) do.
                    if (!role.isAdmin)
                      _ProfileTile(
                        icon: Icons.event_available_outlined,
                        title: AppStrings.myLeave.primary,
                        subtitle: AppStrings.requestLeave.primary,
                        onTap: () => context.push(RoutePaths.myLeave),
                      ),
                    if (role.isAdmin)
                      _ProfileTile(
                        icon: Icons.history_rounded,
                        title: AppStrings.auditTrail.primary,
                        onTap: () => context.push(RoutePaths.activityLog),
                      ),
                    if (engineeringToolsEnabled)
                      _ProfileTile(
                        icon: Icons.straighten_outlined,
                        title: YorksV1EngineeringToolsStrings.ductSizer.primary,
                        onTap: () => context.push(RoutePaths.yorksV1DuctSizer),
                      ),
                    if (engineeringToolsEnabled)
                      _ProfileTile(
                        icon: Icons.calculate_outlined,
                        title: YorksV1EngineeringToolsStrings
                            .espCalculator
                            .primary,
                        onTap: () =>
                            context.push(RoutePaths.yorksV1EspCalculator),
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
                      icon: Icons.lock_clock_rounded,
                      title: AppStrings.appLock.primary,
                      // Full-row tap toggles the lock too — not just the small
                      // switch — so a gloved, imprecise tap still lands.
                      onTap: () => ref
                          .read(appLockEnabledProvider.notifier)
                          .setEnabled(!ref.read(appLockEnabledProvider)),
                      trailing: Switch(
                        value: ref.watch(appLockEnabledProvider),
                        onChanged: (v) => ref
                            .read(appLockEnabledProvider.notifier)
                            .setEnabled(v),
                        activeThumbColor: AppColors.primary,
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
                  'Yorks AC. & Ref. ${ref.watch(appVersionProvider).label} — ${role.label}',
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
          AppStrings.logoutConfirmBody.primary,
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
    await ref.read(authControllerProvider).signOut();
    if (!context.mounted) return;
    context.go(RoutePaths.login);
  }
}

/// The profile pack is a phone-only presentation over the existing profile
/// settings. Each action remains the same route, provider or session command
/// as the desktop profile; this widget adds no account or preference storage.
class _MobileEngineerProfile extends ConsumerWidget {
  const _MobileEngineerProfile({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final currency = ref.watch(currencyProvider);
    final role = ref.watch(currentRoleProvider);
    final emp = ref.watch(employeeProvider);
    final status = ref.watch(yorksV1WorkspaceStatusProvider);
    final toolsEnabled = ref.watch(yorksV1FeatureFlagsProvider).documents;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(YorksMobileUi.appBarHeight),
        child: YorksMobileAppBar(title: 'Profile', brand: true),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 96),
          children: [
            YorksMobileCard(
              onTap: () => context.push(RoutePaths.employeeDetail),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.blueContainer,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 58,
                      child: Center(
                        child: Text(
                          emp.initials,
                          style: AppTypography.titleLarge.copyWith(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(emp.name, style: AppTypography.titleMedium),
                        const SizedBox(height: 3),
                        Text(
                          '${emp.title} · ${role.label}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const YorksMobileSectionHeader(title: 'Workspace'),
            const SizedBox(height: 9),
            YorksMobileCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _MobileProfileTile(
                    icon: Icons.cloud_done_outlined,
                    title: 'Workspace sync',
                    trailing: YorksV1WorkspaceStatusLabel(
                      status: status,
                      compact: true,
                    ),
                    onTap: () => _showSyncSheet(context),
                  ),
                  if (role.isAdmin)
                    _MobileProfileTile(
                      icon: Icons.history_rounded,
                      title: AppStrings.auditTrail.primary,
                      onTap: () => context.push(RoutePaths.activityLog),
                    ),
                  if (!role.isAdmin)
                    _MobileProfileTile(
                      icon: Icons.event_available_outlined,
                      title: AppStrings.myLeave.primary,
                      onTap: () => context.push(RoutePaths.myLeave),
                    ),
                  if (toolsEnabled)
                    _MobileProfileTile(
                      icon: Icons.straighten_outlined,
                      title: YorksV1EngineeringToolsStrings.ductSizer.primary,
                      onTap: () => context.push(RoutePaths.yorksV1DuctSizer),
                    ),
                  if (toolsEnabled)
                    _MobileProfileTile(
                      icon: Icons.calculate_outlined,
                      title:
                          YorksV1EngineeringToolsStrings.espCalculator.primary,
                      onTap: () =>
                          context.push(RoutePaths.yorksV1EspCalculator),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const YorksMobileSectionHeader(title: 'Settings'),
            const SizedBox(height: 9),
            YorksMobileCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _MobileProfileTile(
                    icon: Icons.notifications_outlined,
                    title: AppStrings.notifications.primary,
                    onTap: () => context.push(RoutePaths.notifications),
                  ),
                  _MobileProfileTile(
                    icon: Icons.translate_rounded,
                    title: AppStrings.secondaryLanguage.primary,
                    subtitle: lang.name,
                    onTap: () => LanguagePickerSheet.show(
                      context,
                      current: lang,
                      onSelected: (next) =>
                          ref.read(languageProvider.notifier).setLanguage(next),
                    ),
                  ),
                  _MobileProfileTile(
                    icon: Icons.currency_exchange_rounded,
                    title: AppStrings.currency.primary,
                    subtitle: '${currency.flag} ${currency.code}',
                    onTap: () => CurrencyPickerSheet.show(
                      context,
                      current: currency,
                      onSelected: (next) =>
                          ref.read(currencyProvider.notifier).setCurrency(next),
                    ),
                  ),
                  _MobileProfileTile(
                    icon: Icons.lock_clock_rounded,
                    title: AppStrings.appLock.primary,
                    subtitle: ref.watch(appLockEnabledProvider)
                        ? 'Enabled'
                        : 'Disabled',
                    trailing: Switch(
                      value: ref.watch(appLockEnabledProvider),
                      onChanged: (value) => ref
                          .read(appLockEnabledProvider.notifier)
                          .setEnabled(value),
                    ),
                    onTap: () => ref
                        .read(appLockEnabledProvider.notifier)
                        .setEnabled(!ref.read(appLockEnabledProvider)),
                  ),
                  _MobileProfileTile(
                    icon: Icons.info_outline_rounded,
                    title: AppStrings.about.primary,
                    onTap: () => context.push(RoutePaths.about),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: AppSpacing.minTapTarget,
              child: OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded),
                label: Text(AppStrings.logout.primary),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Yorks AC. & Ref. ${ref.watch(appVersionProvider).label}',
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSyncSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MobileWorkspaceSyncSheet(),
  );
}

class _MobileProfileTile extends StatelessWidget {
  const _MobileProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.inkSecondary, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    ),
  );
}

/// Global sync intentionally states only what the connectivity service and
/// durable outbox can prove. Record-level competing-writer conflicts remain on
/// their originating editor, where both authoritative and local values exist.
class _MobileWorkspaceSyncSheet extends ConsumerWidget {
  const _MobileWorkspaceSyncSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(yorksV1WorkspaceStatusProvider);
    final failed = ref.watch(failedSyncProvider);
    final pending = ref.watch(pendingSyncCountProvider);
    final online = ref.watch(isOnlineProvider);
    final hasFailure = failed.isNotEmpty;
    final callout = switch (status.state) {
      YorksV1WorkspaceConnectionState.offline => YorksMobileCallout(
        icon: Icons.cloud_off_outlined,
        title: 'Offline workspace',
        message: pending == 0
            ? 'You can keep local drafts. Connected commands wait for the server.'
            : '$pending local change${pending == 1 ? '' : 's'} will retry when the connection returns.',
        warning: true,
      ),
      YorksV1WorkspaceConnectionState.syncing => YorksMobileCallout(
        icon: Icons.sync_rounded,
        title: 'Syncing changes',
        message:
            '$pending queued change${pending == 1 ? '' : 's'} are waiting for server confirmation.',
      ),
      YorksV1WorkspaceConnectionState.failed => YorksMobileCallout(
        icon: Icons.error_outline_rounded,
        title: 'Changes need attention',
        message:
            '${failed.length} saved local change${failed.length == 1 ? '' : 's'} could not be submitted. Retry preserves the original command identity.',
        warning: true,
      ),
      _ => YorksMobileCallout(
        icon: Icons.cloud_done_outlined,
        title: online ? 'Workspace connected' : 'Workspace status unavailable',
        message: online
            ? 'No queued changes need your attention.'
            : 'The connection status will update when it can be confirmed.',
      ),
    };
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text('Sync status', style: AppTypography.titleLarge),
                ),
                YorksV1WorkspaceStatusLabel(status: status, compact: true),
              ],
            ),
            const SizedBox(height: 16),
            callout,
            const SizedBox(height: 14),
            YorksMobileCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Conflict handling', style: AppTypography.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'If a server version changes while you edit a record, that record stays open and shows both versions for review. It is never silently overwritten from this global panel.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (hasFailure) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: AppSpacing.minTapTarget,
                child: FilledButton.icon(
                  onPressed: () => ref.read(syncEngineProvider).retryAll(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry sync'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
