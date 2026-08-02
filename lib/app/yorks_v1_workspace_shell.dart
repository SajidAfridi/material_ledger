import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/constants.dart';
import '../core/widgets/brand_logo.dart';
import '../shared/models/app_language.dart';
import '../shared/models/app_strings.dart';
import '../shared/models/yorks_v1_role.dart';
import '../shared/models/yorks_v1_shell_strings.dart';
import '../shared/providers/language_provider.dart';
import '../shared/providers/session_provider.dart';
import '../shared/providers/yorks_v1_identity_provider.dart';
import 'router.dart';

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

    return Scaffold(
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

class _YorksWorkspaceTopBar extends StatelessWidget {
  const _YorksWorkspaceTopBar({
    required this.title,
    required this.language,
    required this.role,
  });

  final TranslatableString title;
  final AppLanguage language;
  final YorksV1Role? role;

  @override
  Widget build(BuildContext context) {
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
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  YorksV1ShellStrings.savedJustNow.primary,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _YorksDesktopSidebar extends StatelessWidget {
  const _YorksDesktopSidebar({
    required this.destinations,
    required this.activePath,
    required this.language,
    required this.role,
    required this.userName,
  });

  final List<_YorksDestination> destinations;
  final String? activePath;
  final AppLanguage language;
  final YorksV1Role? role;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    TranslatableString? previousGroup;
    final displayName = (userName ?? '').trim();
    return Container(
      width: AppSpacing.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  const BrandLogo(size: 52, shadow: true),
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
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                children: [
                  for (final destination in destinations) ...[
                    if (destination.group != null &&
                        destination.group != previousGroup) ...[
                      if (previousGroup != null)
                        const SizedBox(height: AppSpacing.md),
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
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              padding: const EdgeInsets.all(AppSpacing.sm + 1),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
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
                            color: AppColors.success,
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
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
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
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        YorksV1ShellStrings.workspaceSaved.primary,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.inkSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
  });

  final _YorksDestination destination;
  final bool selected;
  final AppLanguage language;

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
  });

  final List<_YorksDestination> destinations;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: YorksV1ShellStrings.quickNavigation.primary,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: AppColors.surfaceContainerLowest,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: [
                Text(
                  YorksV1ShellStrings.quickNavigation.primary,
                  style: AppTypography.titleLarge,
                ),
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
