import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/constants.dart';
import '../core/widgets/brand_logo.dart';
import '../shared/models/app_language.dart';
import '../shared/models/app_strings.dart';
import '../shared/models/yorks_v1_role.dart';
import '../shared/models/yorks_v1_shell_strings.dart';
import '../shared/providers/language_provider.dart';
import '../shared/providers/session_provider.dart';
import '../shared/providers/employee_provider.dart';
import '../shared/providers/yorks_v1_material_request_provider.dart';
import '../shared/providers/yorks_v1_project_portfolio_provider.dart';
import '../shared/providers/yorks_v1_identity_provider.dart';
import '../shared/providers/yorks_v1_workspace_status_provider.dart';
import 'router.dart';
import 'yorks_v1_workspace_search.dart';
import 'yorks_v1_workspace_status_label.dart';

/// Desktop-only shell preference. It lives above individual route widgets so
/// navigating between Yorks screens does not reopen the panel unexpectedly.
final yorksV1SidebarExpandedProvider = StateProvider<bool>((ref) => true);

/// R35 workspace chrome for every connected Yorks V1 operational route.
///
/// This widget is intentionally presentation-only. It does not widen routes,
/// client permissions or server data; individual feature screens continue to
/// request their own safe projections and call their existing controllers.
class YorksV1WorkspaceShell extends ConsumerWidget {
  const YorksV1WorkspaceShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final user = ref.watch(currentUserProvider);
    final location = GoRouterState.of(context).uri.path;
    final destinations = _destinationsFor(role);
    final current = _currentDestination(destinations, location);
    final desktop =
        MediaQuery.sizeOf(context).width >= AppSpacing.yorksV1DesktopBreakpoint;
    final sidebarExpanded = desktop
        ? ref.watch(yorksV1SidebarExpandedProvider)
        : true;

    void openSearch() {
      showYorksV1WorkspaceSearch(
        context,
        targets: [
          for (final destination in destinations)
            if (destination.path != null)
              YorksV1SearchNavigationTarget(
                label: destination.label,
                icon: destination.icon,
                path: destination.path!,
              ),
        ],
        language: language,
        role: role,
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): openSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            openSearch,
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Row(
          children: [
            if (desktop)
              _YorksDesktopSidebar(
                destinations: destinations,
                activePath: current?.path,
                language: language,
                role: role,
                userName: user?.fullName,
                expanded: sidebarExpanded,
                onToggle: () =>
                    ref.read(yorksV1SidebarExpandedProvider.notifier).state =
                        !sidebarExpanded,
              ),
            Expanded(
              child: Column(
                children: [
                  // Feature screens own the compact mobile/tablet app bar. A
                  // second global header there would crowd the focused editor
                  // and duplicate the title; the full R35 context top bar is a
                  // desktop office affordance.
                  if (desktop)
                    _YorksWorkspaceTopBar(
                      title: current?.label ?? YorksV1ShellStrings.overview,
                      language: language,
                      role: role,
                    ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: desktop
            ? null
            : _YorksMobileNavigation(
                destinations: destinations,
                activePath: current?.path,
                language: language,
                role: role,
              ),
      ),
    );
  }

  List<_YorksDestination> _destinationsFor(YorksV1Role? role) {
    final workspace = _workspaceCopy(role);
    final shared = <_YorksDestination>[
      _YorksDestination(
        label: YorksV1ShellStrings.overview,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        path: RoutePaths.engineerHome,
        group: workspace,
      ),
      _YorksDestination(
        label: YorksV1ShellStrings.projects,
        icon: Icons.account_tree_outlined,
        selectedIcon: Icons.account_tree_rounded,
        path: RoutePaths.yorksV1Projects,
      ),
      _YorksDestination(
        label: YorksV1ShellStrings.materialRequests,
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment_rounded,
        path: RoutePaths.yorksV1MaterialRequests,
      ),
    ];

    return switch (role) {
      YorksV1Role.projectEngineer || YorksV1Role.siteEngineer => [
        ...shared,
        _YorksDestination(
          label: YorksV1ShellStrings.materialReturns,
          icon: Icons.assignment_return_outlined,
          selectedIcon: Icons.assignment_return_rounded,
          path: RoutePaths.yorksV1Returns,
        ),
        _YorksDestination(
          label: YorksV1ShellStrings.ductSizer,
          icon: Icons.straighten_outlined,
          selectedIcon: Icons.straighten_rounded,
          path: RoutePaths.yorksV1DuctSizer,
          group: YorksV1ShellStrings.engineeringTools,
        ),
        _YorksDestination(
          label: YorksV1ShellStrings.espCalculator,
          icon: Icons.speed_outlined,
          selectedIcon: Icons.speed_rounded,
          path: RoutePaths.yorksV1EspCalculator,
          group: YorksV1ShellStrings.engineeringTools,
        ),
      ],
      YorksV1Role.procurement => [
        shared.first,
        shared[2],
        _YorksDestination(
          label: YorksV1ShellStrings.browseInventory,
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2_rounded,
          path: RoutePaths.yorksV1Inventory,
        ),
        _YorksDestination(
          label: YorksV1ShellStrings.dispatches,
          icon: Icons.local_shipping_outlined,
          selectedIcon: Icons.local_shipping_rounded,
          path: RoutePaths.yorksV1Dispatches,
        ),
        _YorksDestination(
          label: YorksV1ShellStrings.materialReturns,
          icon: Icons.assignment_return_outlined,
          selectedIcon: Icons.assignment_return_rounded,
          path: RoutePaths.yorksV1Returns,
        ),
        _YorksDestination(
          label: YorksV1ShellStrings.projects,
          icon: Icons.account_tree_outlined,
          selectedIcon: Icons.account_tree_rounded,
          path: RoutePaths.yorksV1Projects,
          suffix: YorksV1ShellStrings.viewOnly,
        ),
      ],
      YorksV1Role.admin => [
        ...shared,
        _YorksDestination(
          label: YorksV1ShellStrings.browseInventory,
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2_rounded,
          path: RoutePaths.yorksV1Inventory,
        ),
        _YorksDestination(
          label: YorksV1ShellStrings.materialReturns,
          icon: Icons.assignment_return_outlined,
          selectedIcon: Icons.assignment_return_rounded,
          path: RoutePaths.yorksV1Returns,
        ),
        _YorksDestination(
          label: YorksV1ShellStrings.dispatches,
          icon: Icons.local_shipping_outlined,
          selectedIcon: Icons.local_shipping_rounded,
          path: RoutePaths.yorksV1Dispatches,
        ),
        _YorksDestination(
          label: YorksV1ShellStrings.configuration,
          icon: Icons.tune_outlined,
          selectedIcon: Icons.tune_rounded,
          path: RoutePaths.more,
          group: YorksV1ShellStrings.administration,
        ),
        _YorksDestination(
          label: YorksV1ShellStrings.rentalProperties,
          icon: Icons.apartment_outlined,
          selectedIcon: Icons.apartment_rounded,
          path: RoutePaths.rentals,
          group: YorksV1ShellStrings.administration,
        ),
        _YorksDestination(
          label: YorksV1ShellStrings.userManagement,
          icon: Icons.manage_accounts_outlined,
          selectedIcon: Icons.manage_accounts_rounded,
          path: RoutePaths.users,
          group: YorksV1ShellStrings.administration,
        ),
        _YorksDestination(
          label: YorksV1ShellStrings.auditTrail,
          icon: Icons.history_outlined,
          selectedIcon: Icons.history_rounded,
          path: RoutePaths.activityLog,
          group: YorksV1ShellStrings.administration,
        ),
      ],
      null => shared,
    };
  }

  _YorksDestination? _currentDestination(
    List<_YorksDestination> destinations,
    String location,
  ) {
    for (final destination in destinations) {
      final path = destination.path;
      if (path == null) continue;
      if (location == path ||
          (path == RoutePaths.yorksV1MaterialRequests &&
              location.startsWith('/yorks/material-requests')) ||
          (path == RoutePaths.yorksV1Projects &&
              location.startsWith('/yorks/projects'))) {
        return destination;
      }
      if (path == RoutePaths.yorksV1Dispatches &&
          location == RoutePaths.yorksV1Dispatches) {
        return destination;
      }
      if (path == RoutePaths.yorksV1Returns &&
          location == RoutePaths.yorksV1Returns) {
        return destination;
      }
    }
    return null;
  }
}

class _YorksWorkspaceTopBar extends ConsumerWidget {
  const _YorksWorkspaceTopBar({
    required this.title,
    required this.language,
    required this.role,
  });

  final TranslatableString title;
  final AppLanguage language;
  final YorksV1Role? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceStatus = ref.watch(yorksV1WorkspaceStatusProvider);
    return Material(
      color: AppColors.surfaceContainerLow,
      child: Container(
        height: AppSpacing.topBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Text(
              YorksV1ShellStrings.companyName.primary,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text('/', style: TextStyle(color: AppColors.lineStrong)),
            ),
            Text(
              title.primary,
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 300,
              child: _YorksQuickNavigationButton(
                destinations: _topLevelDestinationsFor(role),
                language: language,
                role: role,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            YorksV1WorkspaceStatusLabel(status: workspaceStatus),
          ],
        ),
      ),
    );
  }
}

class _YorksDesktopSidebar extends ConsumerWidget {
  const _YorksDesktopSidebar({
    required this.destinations,
    required this.activePath,
    required this.language,
    required this.role,
    required this.userName,
    required this.expanded,
    required this.onToggle,
  });

  final List<_YorksDestination> destinations;
  final String? activePath;
  final AppLanguage language;
  final YorksV1Role? role;
  final String? userName;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceStatus = ref.watch(yorksV1WorkspaceStatusProvider);
    TranslatableString? previousGroup;
    final displayName = (userName ?? '').trim();
    return Container(
      width: expanded
          ? AppSpacing.sidebarWidth
          : AppSpacing.sidebarCollapsedWidth,
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                expanded ? AppSpacing.lg : AppSpacing.xs,
                AppSpacing.lg,
                expanded ? AppSpacing.lg : AppSpacing.xs,
                AppSpacing.lg,
              ),
              child: Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  if (expanded) ...[
                    const BrandLogo(size: 44, shadow: true),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            YorksV1ShellStrings.companyName.primary,
                            style: AppTypography.titleLarge.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            YorksV1ShellStrings.companyLegalName.primary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      onPressed: onToggle,
                      icon: const Icon(Icons.chevron_left_rounded),
                      tooltip: YorksV1ShellStrings.collapsePanel.primary,
                      constraints: const BoxConstraints.tightFor(
                        width: AppSpacing.minTapTarget,
                        height: AppSpacing.minTapTarget,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ] else
                    IconButton(
                      onPressed: onToggle,
                      icon: const Icon(Icons.chevron_right_rounded),
                      tooltip: YorksV1ShellStrings.expandPanel.primary,
                      constraints: const BoxConstraints.tightFor(
                        width: AppSpacing.minTapTarget,
                        height: AppSpacing.minTapTarget,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  expanded ? AppSpacing.md : AppSpacing.xs,
                  AppSpacing.lg,
                  expanded ? AppSpacing.md : AppSpacing.xs,
                  AppSpacing.sm,
                ),
                children: [
                  for (final destination in destinations) ...[
                    if (destination.group != null &&
                        destination.group != previousGroup) ...[
                      if (previousGroup != null)
                        const SizedBox(height: AppSpacing.md),
                      if (expanded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.sm,
                            AppSpacing.lg,
                            AppSpacing.sm,
                            AppSpacing.sm,
                          ),
                          child: Text(
                            destination.group!.primary.toUpperCase(),
                            style: AppTypography.labelSmall.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                    ],
                    _YorksNavigationTile(
                      destination: destination,
                      selected:
                          destination.path != null &&
                          destination.path == activePath,
                      language: language,
                      compact: !expanded,
                    ),
                    () {
                      previousGroup = destination.group;
                      return const SizedBox.shrink();
                    }(),
                  ],
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.fromLTRB(
                expanded ? AppSpacing.md : AppSpacing.xs,
                AppSpacing.sm,
                expanded ? AppSpacing.md : AppSpacing.xs,
                AppSpacing.md,
              ),
              padding: const EdgeInsets.all(AppSpacing.sm + 1),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  onTap: () => _showYorksProfileDialog(context),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Row(
                      mainAxisAlignment: expanded
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _Avatar(name: displayName, size: 42),
                            Positioned(
                              right: -1,
                              bottom: -1,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: YorksV1WorkspaceStatusLabel.colorFor(
                                    workspaceStatus.state,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.surfaceContainerLowest,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (expanded) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName.isEmpty
                                      ? YorksV1ShellStrings.account.primary
                                      : displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelLarge.copyWith(
                                    color: AppColors.ink,
                                  ),
                                ),
                                Text(
                                  _roleCopy(role).primary,
                                  style: AppTypography.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.muted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    YorksV1WorkspaceStatusLabel(
                      status: workspaceStatus,
                      compact: true,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      YorksV1ShellStrings.connectedProjectControl.primary,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void _showYorksProfileDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: AppColors.scrim.withValues(alpha: 0.38),
    builder: (_) => const _YorksProfileDialog(),
  );
}

class _YorksProfileDialog extends ConsumerWidget {
  const _YorksProfileDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final profile = ref.watch(employeeProvider);
    final projects = ref.watch(yorksV1ProjectPortfolioProvider);
    final requests = ref.watch(yorksV1MaterialRequestListProvider(null));
    final name = profile.name == '—'
        ? (user?.fullName ?? 'Yorks user')
        : profile.name;
    final email = profile.email == '—' ? (user?.email ?? '—') : profile.email;

    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 704),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Profile', style: AppTypography.headlineSmall),
                        const SizedBox(height: 4),
                        Text(
                          'Account, project assignments and workspace access.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.blueContainer.withValues(alpha: 0.24),
                  border: Border.all(color: AppColors.blueContainerStrong),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: Row(
                  children: [
                    _Avatar(name: name, size: 64),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: AppTypography.titleLarge),
                          const SizedBox(height: 2),
                          Text(
                            _roleCopy(role).primary,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            children: [
                              _ProfileStatusChip(
                                label: 'Active',
                                color: AppColors.success,
                              ),
                              _ProfileStatusChip(
                                label:
                                    '${projects.valueOrNull?.length ?? 0} assigned projects',
                                color: AppColors.blue,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _ProfileStat(
                      label: 'Assigned projects',
                      value: '${projects.valueOrNull?.length ?? 0}',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ProfileStat(
                      label: 'Open requests',
                      value: '${requests.valueOrNull?.length ?? 0}',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: _ProfileStat(
                      label: 'Workspace',
                      value: 'BOQ · MR · Docs',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.successContainer.withValues(alpha: 0.55),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.25),
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Signed in securely\n',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            TextSpan(
                              text:
                                  '$email · Every request, approval, dispatch and receipt is attributed to this account.',
                            ),
                          ],
                        ),
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _signOut(context, ref),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (confirmContext) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('You will need to sign in again to access Yorks.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(confirmContext, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true) return;
    await ref.read(authSessionProvider.notifier).logout();
    if (!context.mounted) return;
    Navigator.pop(context);
    context.go(RoutePaths.login);
  }
}

class _ProfileStatusChip extends StatelessWidget {
  const _ProfileStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
    ),
    child: Text(label, style: AppTypography.labelMedium.copyWith(color: color)),
  );
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 74),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.labelSmall.copyWith(letterSpacing: 0.6),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleMedium,
        ),
      ],
    ),
  );
}

class _YorksMobileNavigation extends StatelessWidget {
  const _YorksMobileNavigation({
    required this.destinations,
    required this.activePath,
    required this.language,
    required this.role,
  });

  final List<_YorksDestination> destinations;
  final String? activePath;
  final AppLanguage language;
  final YorksV1Role? role;

  @override
  Widget build(BuildContext context) {
    final visible = destinations
        .where((item) => item.path != null)
        .take(5)
        .toList();
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: const Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            for (final destination in visible)
              Expanded(
                child: _YorksMobileItem(
                  destination: destination,
                  selected: destination.path == activePath,
                  language: language,
                ),
              ),
            if (destinations.length > visible.length)
              Expanded(
                child: _YorksMobileMoreItem(
                  destinations: destinations.skip(visible.length).toList(),
                  language: language,
                  role: role,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _YorksNavigationTile extends StatelessWidget {
  const _YorksNavigationTile({
    required this.destination,
    required this.selected,
    required this.language,
    this.compact = false,
  });

  final _YorksDestination destination;
  final bool selected;
  final AppLanguage language;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final disabled = destination.path == null;
    return Semantics(
      button: !disabled,
      selected: selected,
      enabled: !disabled,
      label: destination.label.primary,
      child: Tooltip(
        message: destination.label.active(language),
        child: Material(
          color: selected ? AppColors.blueContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            onTap: disabled ? null : () => context.go(destination.path!),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.minTapTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: compact
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      size: 20,
                      color: disabled
                          ? AppColors.mutedLight
                          : selected
                          ? AppColors.blue
                          : AppColors.inkSecondary,
                    ),
                    if (!compact) ...[
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          destination.label.primary,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(
                            color: disabled
                                ? AppColors.mutedLight
                                : selected
                                ? AppColors.navy
                                : AppColors.inkSecondary,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (destination.suffix != null)
                        Text(
                          destination.suffix!.primary,
                          style: AppTypography.labelSmall,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _YorksMobileItem extends StatelessWidget {
  const _YorksMobileItem({
    required this.destination,
    required this.selected,
    required this.language,
  });

  final _YorksDestination destination;
  final bool selected;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: destination.label.primary,
    child: InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: () => context.go(destination.path!),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 21,
                color: selected ? AppColors.blue : AppColors.muted,
              ),
              const SizedBox(height: 2),
              Text(
                destination.label.primary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: selected ? AppColors.blue : AppColors.muted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _YorksMobileMoreItem extends StatelessWidget {
  const _YorksMobileMoreItem({
    required this.destinations,
    required this.language,
    required this.role,
  });

  final List<_YorksDestination> destinations;
  final AppLanguage language;
  final YorksV1Role? role;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: AppStrings.more.primary,
    child: InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        sheetAnimationStyle: AnimationStyle.noAnimation,
        showDragHandle: true,
        backgroundColor: AppColors.surfaceContainerLowest,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(AppStrings.more.primary, style: AppTypography.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              for (final destination in destinations)
                _YorksNavigationTile(
                  destination: destination,
                  selected: false,
                  language: language,
                ),
            ],
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: AppSpacing.minTapTarget),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.more_horiz_rounded,
              size: 21,
              color: AppColors.blueContainerStrong,
            ),
            SizedBox(height: 2),
          ],
        ),
      ),
    ),
  );
}

class _YorksQuickNavigationButton extends StatelessWidget {
  const _YorksQuickNavigationButton({
    required this.destinations,
    required this.language,
    required this.role,
  });

  final List<_YorksDestination> destinations;
  final AppLanguage language;
  final YorksV1Role? role;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: YorksV1ShellStrings.quickNavigation.primary,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showYorksV1WorkspaceSearch(
          context,
          targets: [
            for (final destination in destinations)
              if (destination.path != null)
                YorksV1SearchNavigationTarget(
                  label: destination.label,
                  icon: destination.icon,
                  path: destination.path!,
                ),
          ],
          language: language,
          role: role,
        ),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                size: 19,
                color: AppColors.muted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  YorksV1ShellStrings.searchOrJump.primary,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text('⌘K', style: AppTypography.labelSmall),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.size = 32});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    final initials = words.take(2).map((word) => word.characters.first).join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.blueContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials.isEmpty ? 'Y' : initials.toUpperCase(),
        style: AppTypography.labelLarge.copyWith(color: AppColors.navy),
      ),
    );
  }
}

class _YorksDestination {
  const _YorksDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.path,
    this.group,
    this.suffix,
  });

  final TranslatableString label;
  final IconData icon;
  final IconData selectedIcon;
  final String? path;
  final TranslatableString? group;
  final TranslatableString? suffix;
}

TranslatableString _roleCopy(YorksV1Role? role) => switch (role) {
  YorksV1Role.projectEngineer => AppStrings.projectEngineerRole,
  YorksV1Role.siteEngineer => AppStrings.siteEngineerRole,
  YorksV1Role.procurement => AppStrings.procurementRole,
  YorksV1Role.admin => AppStrings.adminRole,
  null => YorksV1ShellStrings.account,
};

TranslatableString _workspaceCopy(YorksV1Role? role) => switch (role) {
  YorksV1Role.projectEngineer ||
  YorksV1Role.siteEngineer => YorksV1ShellStrings.engineerWorkspace,
  YorksV1Role.procurement => YorksV1ShellStrings.procurementWorkspace,
  YorksV1Role.admin => YorksV1ShellStrings.managementWorkspace,
  null => YorksV1ShellStrings.operationalWorkspace,
};

List<_YorksDestination> _topLevelDestinationsFor(YorksV1Role? role) {
  final shell = YorksV1WorkspaceShell(child: const SizedBox.shrink());
  return shell
      ._destinationsFor(role)
      .where((item) => item.path != null)
      .toList();
}
