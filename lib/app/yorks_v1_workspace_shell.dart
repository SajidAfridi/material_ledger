import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/constants.dart';
import '../core/widgets/brand_logo.dart';
import '../core/widgets/yorks_mobile_ui.dart';
import '../shared/models/app_language.dart';
import '../shared/models/app_strings.dart';
import '../shared/models/yorks_v1_project_strings.dart';
import '../shared/models/yorks_v1_role.dart';
import '../shared/models/yorks_v1_shell_strings.dart';
import '../shared/models/yorks_v1_team_chat_strings.dart';
import '../shared/providers/language_provider.dart';
import '../shared/providers/notification_provider.dart';
import '../shared/providers/session_provider.dart';
import '../shared/providers/employee_provider.dart';
import '../shared/providers/yorks_v1_material_request_provider.dart';
import '../shared/providers/yorks_v1_project_portfolio_provider.dart';
import '../shared/providers/yorks_v1_identity_provider.dart';
import '../shared/providers/yorks_v1_feature_flags_provider.dart';
import '../shared/providers/yorks_v1_team_chat_provider.dart';
import '../shared/providers/yorks_v1_workspace_status_provider.dart';
import '../shared/widgets/notification_bell.dart';
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
    final teamChatEnabled = ref.watch(yorksV1FeatureFlagsProvider).teamChat;
    final chatUnread = teamChatEnabled
        ? ref.watch(yorksV1TeamChatUnreadProvider)
        : 0;
    final destinations = _destinationsFor(
      role,
      teamChatEnabled: teamChatEnabled,
      chatUnread: chatUnread,
    );
    final current = _currentDestination(destinations, location);
    final desktop =
        MediaQuery.sizeOf(context).width >=
        AppSpacing.yorksV1ShellDesktopBreakpoint;
    final sidebarExpanded = desktop
        ? ref.watch(yorksV1SidebarExpandedProvider)
        : true;
    final breadcrumbs = _breadcrumbsFor(location, current);
    final focusedMobileRoute = location == RoutePaths.engineerCreateProject;
    final featureOwnsMobileTopBar = _featureOwnsMobileTopBar(location);

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

    final sidebar = _YorksDesktopSidebar(
      destinations: destinations,
      activePath: current?.path,
      language: language,
      role: role,
      userName: user?.fullName,
      expanded: sidebarExpanded,
      onToggle: () => ref.read(yorksV1SidebarExpandedProvider.notifier).state =
          !sidebarExpanded,
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): openSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            openSearch,
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        drawer: desktop
            ? null
            : Drawer(
                width: 246,
                shape: const RoundedRectangleBorder(),
                child: _YorksDesktopSidebar(
                  destinations: destinations,
                  activePath: current?.path,
                  language: language,
                  role: role,
                  userName: user?.fullName,
                  expanded: true,
                  onToggle: () => Navigator.of(context).maybePop(),
                ),
              ),
        body: Builder(
          builder: (scaffoldContext) {
            if (!desktop) {
              final unread = ref.watch(unreadNotificationCountProvider);
              return ColoredBox(
                color: AppColors.mobileSurface,
                child: Column(
                  children: [
                    if (!(YorksMobileUi.isActive(context) &&
                        featureOwnsMobileTopBar))
                      _YorksWorkspaceMobileTopBar(
                        breadcrumbs: breadcrumbs,
                        location: location,
                        unreadNotifications: unread,
                        teamChatEnabled: teamChatEnabled,
                        unreadChat: chatUnread,
                        onMenu: () => context.go(RoutePaths.yorksV1MobileMore),
                        onBack: () => context.canPop()
                            ? context.pop()
                            : context.go(RoutePaths.yorksV1Projects),
                      ),
                    Expanded(child: child),
                    if (!focusedMobileRoute)
                      _YorksMobileNavigation(
                        destinations: _mobileDestinationsFor(
                          role,
                          nativeMobile: YorksMobileUi.isActive(context),
                          teamChatEnabled: teamChatEnabled,
                          chatUnread: chatUnread,
                        ),
                        activePath: location,
                        language: language,
                      ),
                  ],
                ),
              );
            }
            return Row(
              children: [
                sidebar,
                Expanded(
                  child: Column(
                    children: [
                      _YorksWorkspaceTopBar(
                        breadcrumbs: breadcrumbs,
                        language: language,
                        role: role,
                      ),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Record-oriented Project and Material Request screens have titles and
  /// actions that only their own controller-backed projections can supply.
  /// They own the compact phone header while the shell retains its bottom
  /// navigation. This avoids stacking a generic workspace toolbar above a
  /// focused record toolbar on the native mobile breakpoint.
  bool _featureOwnsMobileTopBar(String location) {
    // The retained engineering calculators use a focused, controller-backed
    // phone header just like record routes. Keep the shared bottom navigation,
    // but do not stack the generic workspace toolbar above their own actions.
    if (location == RoutePaths.yorksV1DuctSizer ||
        location == RoutePaths.yorksV1EspCalculator ||
        location == RoutePaths.engineerProfile ||
        location.startsWith(RoutePaths.yorksV1TeamChat)) {
      return true;
    }
    final segments = Uri(path: location).pathSegments;
    if (segments.length < 2 || segments[0] != 'yorks') {
      return false;
    }
    if (segments[1] == 'material-requests') return true;
    if (segments[1] != 'projects' || segments.length < 3) return false;
    return segments.last != 'edit';
  }

  List<_YorksDestination> _mobileDestinationsFor(
    YorksV1Role? role, {
    required bool nativeMobile,
    bool teamChatEnabled = true,
    int chatUnread = 0,
  }) {
    final all = _destinationsFor(
      role,
      teamChatEnabled: teamChatEnabled,
      chatUnread: chatUnread,
    );
    _YorksDestination path(String route) =>
        all.firstWhere((destination) => destination.path == route);
    if (!nativeMobile) {
      final more = _YorksDestination(
        label: AppStrings.more,
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view_rounded,
        path: RoutePaths.yorksV1MobileMore,
      );
      if (role == YorksV1Role.procurement) {
        return [
          path(RoutePaths.engineerHome),
          path(RoutePaths.yorksV1MaterialRequests),
          path(RoutePaths.yorksV1Inventory),
          teamChatEnabled
              ? path(RoutePaths.yorksV1TeamChat)
              : path(RoutePaths.yorksV1Dispatches),
          more,
        ];
      }
      return [
        path(RoutePaths.engineerHome),
        path(RoutePaths.yorksV1Projects),
        if (teamChatEnabled) path(RoutePaths.yorksV1TeamChat),
        path(RoutePaths.yorksV1MaterialRequests),
        more,
      ];
    }
    _YorksDestination mobilePath(
      String route,
      IconData icon,
      IconData selectedIcon, {
      TranslatableString? mobileLabel,
    }) {
      final source = path(route);
      return _YorksDestination(
        label: mobileLabel ?? source.label,
        compactLabel: mobileLabel ?? source.compactLabel,
        icon: icon,
        selectedIcon: selectedIcon,
        path: source.path,
      );
    }

    final home = mobilePath(
      RoutePaths.engineerHome,
      Icons.home_outlined,
      Icons.home_rounded,
      mobileLabel: AppStrings.home,
    );
    final projects = mobilePath(
      RoutePaths.yorksV1Projects,
      Icons.folder_outlined,
      Icons.folder_rounded,
    );
    final requests = mobilePath(
      RoutePaths.yorksV1MaterialRequests,
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
    );
    final chat = teamChatEnabled
        ? mobilePath(
            RoutePaths.yorksV1TeamChat,
            Icons.chat_bubble_outline_rounded,
            Icons.chat_bubble_rounded,
          )
        : null;
    final more = _YorksDestination(
      label: AppStrings.more,
      icon: Icons.menu_rounded,
      selectedIcon: Icons.menu_rounded,
      path: RoutePaths.yorksV1MobileMore,
    );
    if (role == YorksV1Role.procurement) {
      return [
        home,
        requests,
        path(RoutePaths.yorksV1Inventory),
        if (chat != null) chat else path(RoutePaths.yorksV1Dispatches),
        more,
      ];
    }
    return [home, projects, ?chat, requests, more];
  }

  List<_YorksDestination> _destinationsFor(
    YorksV1Role? role, {
    bool teamChatEnabled = true,
    int chatUnread = 0,
  }) {
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
        compactLabel: YorksV1ShellStrings.requestsCompact,
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment_rounded,
        path: RoutePaths.yorksV1MaterialRequests,
      ),
      if (teamChatEnabled)
        _YorksDestination(
          label: YorksV1TeamChatStrings.teamChat,
          icon: Icons.chat_bubble_outline_rounded,
          selectedIcon: Icons.chat_bubble_rounded,
          path: RoutePaths.yorksV1TeamChat,
          badgeCount: chatUnread,
          group: YorksV1ShellStrings.collaboration,
        ),
    ];

    return switch (role) {
      YorksV1Role.projectEngineer ||
      YorksV1Role.siteEngineer ||
      YorksV1Role.seniorMechanicalEngineer ||
      YorksV1Role.projectManager ||
      YorksV1Role.workshopInCharge ||
      YorksV1Role.documentController => [
        ...shared,
        if (role?.canBrowseInventory ?? false)
          _YorksDestination(
            label: YorksV1ShellStrings.browseInventory,
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2_rounded,
            path: RoutePaths.yorksV1Inventory,
            suffix: YorksV1ShellStrings.viewOnly,
          ),
        _YorksDestination(
          label: YorksV1ShellStrings.materialReturns,
          compactLabel: YorksV1ShellStrings.returnsCompact,
          icon: Icons.assignment_return_outlined,
          selectedIcon: Icons.assignment_return_rounded,
          path: RoutePaths.yorksV1Returns,
        ),
        _YorksDestination(
          label: YorksV1ShellStrings.ductSizer,
          compactLabel: YorksV1ShellStrings.ductCompact,
          icon: Icons.straighten_outlined,
          selectedIcon: Icons.straighten_rounded,
          path: RoutePaths.yorksV1DuctSizer,
          group: YorksV1ShellStrings.engineeringTools,
        ),
        _YorksDestination(
          label: YorksV1ShellStrings.espCalculator,
          compactLabel: YorksV1ShellStrings.espCompact,
          icon: Icons.speed_outlined,
          selectedIcon: Icons.speed_rounded,
          path: RoutePaths.yorksV1EspCalculator,
          group: YorksV1ShellStrings.engineeringTools,
        ),
        if (role?.canConfigureUsers ?? false)
          _YorksDestination(
            label: YorksV1ShellStrings.userManagement,
            icon: Icons.manage_accounts_outlined,
            selectedIcon: Icons.manage_accounts_rounded,
            path: RoutePaths.users,
            group: YorksV1ShellStrings.administration,
          ),
      ],
      YorksV1Role.procurement => [
        shared.first,
        shared[2],
        if (teamChatEnabled) shared.last,
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
          path: RoutePaths.yorksV1Configuration,
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
          (path == RoutePaths.yorksV1Projects &&
              location == RoutePaths.engineerCreateProject) ||
          (path == RoutePaths.yorksV1MaterialRequests &&
              location.startsWith('/yorks/material-requests')) ||
          (path == RoutePaths.yorksV1TeamChat &&
              location.startsWith(RoutePaths.yorksV1TeamChat)) ||
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

  List<TranslatableString> _breadcrumbsFor(
    String location,
    _YorksDestination? current,
  ) {
    if (location == RoutePaths.engineerCreateProject) {
      return const [
        YorksV1ProjectStrings.projects,
        YorksV1ProjectStrings.createProject,
      ];
    }
    return [current?.label ?? YorksV1ShellStrings.overview];
  }
}

/// Full mobile destination used by the fixed bottom navigation. It exposes
/// only routes already available to the authenticated role.
class YorksV1MobileMoreScreen extends ConsumerWidget {
  const YorksV1MobileMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final user = ref.watch(currentUserProvider);
    final teamChatEnabled = ref.watch(yorksV1FeatureFlagsProvider).teamChat;
    final chatUnread = teamChatEnabled
        ? ref.watch(yorksV1TeamChatUnreadProvider)
        : 0;
    final shell = YorksV1WorkspaceShell(child: const SizedBox.shrink());
    final all = shell._destinationsFor(
      role,
      teamChatEnabled: teamChatEnabled,
      chatUnread: chatUnread,
    );
    final primaryRoutes = shell
        ._mobileDestinationsFor(
          role,
          nativeMobile: YorksMobileUi.isActive(context),
          teamChatEnabled: teamChatEnabled,
          chatUnread: chatUnread,
        )
        .map((destination) => destination.path)
        .whereType<String>()
        .toSet();
    final moreDestinations = all
        .where(
          (destination) =>
              destination.path != null &&
              !primaryRoutes.contains(destination.path),
        )
        .toList();

    return ColoredBox(
      color: AppColors.mobileSurface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          Semantics(
            button: true,
            label: AppStrings.profile.active(language),
            child: YorksMobileCard(
              key: const ValueKey('mobile-profile-entry'),
              onTap: () => context.go(RoutePaths.engineerProfile),
              child: Row(
                children: [
                  _Avatar(name: user?.fullName ?? '', size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _roleCopy(role).active(language),
                          style: AppTypography.bodySmall,
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
          ),
          const SizedBox(height: 18),
          Text(
            _workspaceCopy(role).active(language),
            style: AppTypography.labelMedium.copyWith(
              letterSpacing: .8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          YorksMobileCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < moreDestinations.length;
                  index++
                ) ...[
                  _MoreDestinationRow(
                    destination: moreDestinations[index],
                    language: language,
                  ),
                  if (index != moreDestinations.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            AppStrings.settings.active(language),
            style: AppTypography.labelMedium.copyWith(
              letterSpacing: .8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          YorksMobileCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MoreDestinationRow(
                  destination: _YorksDestination(
                    label: AppStrings.notifications,
                    icon: Icons.notifications_outlined,
                    selectedIcon: Icons.notifications_rounded,
                    path: RoutePaths.notifications,
                  ),
                  language: language,
                ),
                const Divider(height: 1),
                _MoreDestinationRow(
                  destination: _YorksDestination(
                    label: AppStrings.profile,
                    icon: Icons.person_outline_rounded,
                    selectedIcon: Icons.person_rounded,
                    path: RoutePaths.engineerProfile,
                  ),
                  language: language,
                ),
                const Divider(height: 1),
                Semantics(
                  button: true,
                  child: InkWell(
                    onTap: () => _signOut(context, ref, language),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.logout_rounded,
                              size: 21,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              AppStrings.signOut.active(language),
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref,
    AppLanguage language,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.signOut.active(language)),
        content: Text(AppStrings.logoutConfirmBody.active(language)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppStrings.cancel.active(language)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppStrings.signOut.active(language)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider).signOut();
    if (context.mounted) context.go(RoutePaths.login);
  }
}

class _MoreDestinationRow extends StatelessWidget {
  const _MoreDestinationRow({
    required this.destination,
    required this.language,
  });

  final _YorksDestination destination;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: destination.label.active(language),
    child: InkWell(
      onTap: () => context.go(destination.path!),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(destination.icon, size: 21, color: AppColors.inkSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  destination.label.active(language),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _YorksWorkspaceTopBar extends ConsumerWidget {
  const _YorksWorkspaceTopBar({
    required this.breadcrumbs,
    required this.language,
    required this.role,
  });

  final List<TranslatableString> breadcrumbs;
  final AppLanguage language;
  final YorksV1Role? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceStatus = ref.watch(yorksV1WorkspaceStatusProvider);
    final teamChatEnabled = ref.watch(yorksV1FeatureFlagsProvider).teamChat;
    final unreadChat = teamChatEnabled
        ? ref.watch(yorksV1TeamChatUnreadProvider)
        : 0;
    return Material(
      color: AppColors.workspaceChrome,
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
            for (final breadcrumb in breadcrumbs) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text('/', style: TextStyle(color: AppColors.lineStrong)),
              ),
              Flexible(
                child: Text(
                  breadcrumb.primary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (teamChatEnabled) ...[
              IconButton(
                tooltip: YorksV1TeamChatStrings.teamChat.active(language),
                onPressed: () => context.go(RoutePaths.yorksV1TeamChat),
                icon: Badge(
                  isLabelVisible: unreadChat > 0,
                  label: Text(unreadChat > 99 ? '99+' : '$unreadChat'),
                  child: const Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            const NotificationBell(),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 220,
              child: _YorksQuickNavigationButton(
                destinations: _topLevelDestinationsFor(
                  role,
                  teamChatEnabled: teamChatEnabled,
                  chatUnread: unreadChat,
                ),
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

class _YorksWorkspaceMobileTopBar extends StatelessWidget {
  const _YorksWorkspaceMobileTopBar({
    required this.breadcrumbs,
    required this.location,
    required this.unreadNotifications,
    required this.teamChatEnabled,
    required this.unreadChat,
    required this.onMenu,
    required this.onBack,
  });

  final List<TranslatableString> breadcrumbs;
  final String location;
  final int unreadNotifications;
  final bool teamChatEnabled;
  final int unreadChat;
  final VoidCallback onMenu;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final focused = location == RoutePaths.engineerCreateProject;
    final home = location == RoutePaths.engineerHome;
    final title = home
        ? YorksV1ShellStrings.companyName.primary
        : breadcrumbs.last.primary;
    return YorksMobileAppBar(
      title: title,
      brand: home,
      leading: home
          ? null
          : YorksMobileIconButton(
              icon: focused ? Icons.arrow_back_rounded : Icons.menu_rounded,
              tooltip: focused
                  ? MaterialLocalizations.of(context).backButtonTooltip
                  : MaterialLocalizations.of(context).openAppDrawerTooltip,
              onPressed: focused ? onBack : onMenu,
            ),
      trailing: home
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (teamChatEnabled)
                  YorksMobileIconButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    tooltip: YorksV1TeamChatStrings.teamChat.primary,
                    badge: unreadChat > 0,
                    onPressed: () => context.go(RoutePaths.yorksV1TeamChat),
                  ),
                YorksMobileIconButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: AppStrings.notifications.primary,
                  badge: unreadNotifications > 0,
                  onPressed: () => context.push(RoutePaths.notifications),
                ),
              ],
            )
          : null,
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
        color: AppColors.workspaceChrome,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                expanded ? 22 : AppSpacing.xs,
                expanded ? 24 : AppSpacing.lg,
                expanded ? 14 : AppSpacing.xs,
                expanded ? 24 : AppSpacing.lg,
              ),
              child: Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  if (expanded) ...[
                    const BrandLogo(size: 48, shadow: true),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            YorksV1ShellStrings.companyName.primary,
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.navy,
                              fontSize: 14,
                              height: 1.15,
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
                    _HoverRevealSidebarToggle(
                      onPressed: onToggle,
                      tooltip: YorksV1ShellStrings.collapsePanel.primary,
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
                  AppSpacing.sm,
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
                            AppSpacing.sm,
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
              padding: EdgeInsets.zero,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  onTap: () => _showYorksProfileDialog(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisAlignment: expanded
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _Avatar(name: displayName, size: 36),
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

class _HoverRevealSidebarToggle extends StatefulWidget {
  const _HoverRevealSidebarToggle({
    required this.onPressed,
    required this.tooltip,
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  State<_HoverRevealSidebarToggle> createState() =>
      _HoverRevealSidebarToggleState();
}

class _HoverRevealSidebarToggleState extends State<_HoverRevealSidebarToggle> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _visible = true),
    onExit: (_) => setState(() => _visible = false),
    child: Focus(
      onFocusChange: (focused) => setState(() => _visible = focused),
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        child: IconButton(
          onPressed: widget.onPressed,
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: widget.tooltip,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
        ),
      ),
    ),
  );
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
    await ref.read(authControllerProvider).signOut();
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
  });

  final List<_YorksDestination> destinations;
  final String? activePath;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    if (!YorksMobileUi.isActive(context)) {
      return SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: DecoratedBox(
          key: const ValueKey('yorks-compact-navigation-legacy'),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: SizedBox(
            height: YorksMobileUi.navigationHeight,
            child: _navigationRow(),
          ),
        ),
      );
    }
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Container(
        key: const ValueKey('yorks-mobile-navigation'),
        height: YorksMobileUi.navigationHeight,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: .97),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24142F50),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: _navigationRow(),
      ),
    );
  }

  Widget _navigationRow() => Row(
    children: [
      for (final destination in destinations)
        Expanded(
          child: _YorksMobileItem(
            destination: destination,
            selected:
                destination.path == activePath ||
                (destination.path == RoutePaths.yorksV1Projects &&
                    activePath?.startsWith('/yorks/projects') == true) ||
                (destination.path == RoutePaths.yorksV1MaterialRequests &&
                    activePath?.startsWith('/yorks/material-requests') ==
                        true) ||
                (destination.path == RoutePaths.yorksV1TeamChat &&
                    activePath?.startsWith(RoutePaths.yorksV1TeamChat) == true),
            language: language,
          ),
        ),
    ],
  );
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
                    _DestinationIcon(
                      destination: destination,
                      selected: selected,
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
  Widget build(BuildContext context) {
    if (!YorksMobileUi.isActive(context)) {
      return Semantics(
        button: true,
        selected: selected,
        label: destination.label.primary,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(destination.path!),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppSpacing.minTapTarget,
              minHeight: AppSpacing.minTapTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DestinationIcon(
                    destination: destination,
                    selected: selected,
                    color: selected ? AppColors.blue : AppColors.muted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (destination.compactLabel ?? destination.label).primary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: selected ? AppColors.blue : AppColors.muted,
                      fontSize: 9,
                      height: 1,
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
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label.primary,
      child: Material(
        color: selected
            ? AppColors.onPrimary.withValues(alpha: .12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => context.go(destination.path!),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppSpacing.minTapTarget,
              minHeight: AppSpacing.minTapTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DestinationIcon(
                    destination: destination,
                    selected: selected,
                    color: selected
                        ? AppColors.onPrimary
                        : AppColors.lineStrong,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (destination.compactLabel ?? destination.label).primary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: selected
                          ? AppColors.onPrimary
                          : AppColors.lineStrong,
                      fontSize: 9,
                      height: 1,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
          height: 36,
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    this.compactLabel,
    this.path,
    this.group,
    this.suffix,
    this.badgeCount = 0,
  });

  final TranslatableString label;
  final IconData icon;
  final IconData selectedIcon;
  final TranslatableString? compactLabel;
  final String? path;
  final TranslatableString? group;
  final TranslatableString? suffix;
  final int badgeCount;
}

class _DestinationIcon extends StatelessWidget {
  const _DestinationIcon({
    required this.destination,
    required this.selected,
    required this.color,
  });

  final _YorksDestination destination;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      selected ? destination.selectedIcon : destination.icon,
      size: 20,
      color: color,
    );
    // Preserve the established shell geometry exactly when no badge is
    // visible. Wrapping every destination in the wider badge canvas shifts
    // unrelated navigation icons and creates needless visual churn.
    if (destination.badgeCount <= 0) return icon;
    return SizedBox(
      width: 25,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 1, top: 2, child: icon),
          Positioned(
            right: -2,
            top: -3,
            child: Container(
              constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: Text(
                destination.badgeCount > 99
                    ? '99+'
                    : '${destination.badgeCount}',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white,
                  fontSize: 8,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

TranslatableString _roleCopy(YorksV1Role? role) => switch (role) {
  YorksV1Role.projectEngineer => AppStrings.projectEngineerRole,
  YorksV1Role.siteEngineer => AppStrings.siteEngineerRole,
  YorksV1Role.seniorMechanicalEngineer =>
    AppStrings.seniorMechanicalEngineerRole,
  YorksV1Role.projectManager => AppStrings.projectManagerRole,
  YorksV1Role.workshopInCharge => AppStrings.workshopInChargeRole,
  YorksV1Role.documentController => AppStrings.documentControllerRole,
  YorksV1Role.procurement => AppStrings.procurementRole,
  YorksV1Role.admin => AppStrings.adminRole,
  null => YorksV1ShellStrings.account,
};

TranslatableString _workspaceCopy(YorksV1Role? role) => switch (role) {
  YorksV1Role.projectEngineer ||
  YorksV1Role.siteEngineer ||
  YorksV1Role.seniorMechanicalEngineer ||
  YorksV1Role.projectManager ||
  YorksV1Role.workshopInCharge ||
  YorksV1Role.documentController => YorksV1ShellStrings.engineerWorkspace,
  YorksV1Role.procurement => YorksV1ShellStrings.procurementWorkspace,
  YorksV1Role.admin => YorksV1ShellStrings.managementWorkspace,
  null => YorksV1ShellStrings.operationalWorkspace,
};

List<_YorksDestination> _topLevelDestinationsFor(
  YorksV1Role? role, {
  required bool teamChatEnabled,
  required int chatUnread,
}) {
  final shell = YorksV1WorkspaceShell(child: const SizedBox.shrink());
  return shell
      ._destinationsFor(
        role,
        teamChatEnabled: teamChatEnabled,
        chatUnread: chatUnread,
      )
      .where((item) => item.path != null)
      .toList();
}
