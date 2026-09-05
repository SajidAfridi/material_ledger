import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/constants.dart';
import '../core/feedback/feedback_service.dart';
import '../core/widgets/widgets.dart';
import '../shared/models/app_language.dart';
import '../shared/models/app_strings.dart';
import '../shared/models/yorks_v1_project_strings.dart';
import '../shared/providers/language_provider.dart';
import '../shared/providers/yorks_v1_feature_flags_provider.dart';
import '../shared/sync/sync_status_banner.dart';
import 'router.dart';
import 'yorks_v1_workspace_shell.dart';

/// Engineer shell — responsive navigation.
///
/// Mobile (< 840px): Custom bottom navigation with a legacy request CTA when
/// that retained workflow is active. Tablet/Desktop (≥ 840px): custom rail.
///
/// Tabs: Dashboard · Browse · Projects · Profile
class EngineerShellScreen extends ConsumerWidget {
  const EngineerShellScreen({super.key, required this.navigationShell});

  /// The indexed-stack shell — keeps all four tabs mounted so switching tabs
  /// never loses typed quantities or search filters.
  final StatefulNavigationShell navigationShell;

  static const _navItems = [
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      translatable: AppStrings.dashboard,
      path: RoutePaths.engineerHome,
    ),
    _NavItem(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      translatable: AppStrings.browse,
      path: RoutePaths.engineerBrowse,
    ),
    _NavItem(
      icon: Icons.account_tree_outlined,
      activeIcon: Icons.account_tree_rounded,
      translatable: AppStrings.projects,
      path: RoutePaths.engineerProjects,
    ),
    _NavItem(
      icon: Icons.person_outlined,
      activeIcon: Icons.person_rounded,
      translatable: AppStrings.profile,
      path: RoutePaths.engineerProfile,
    ),
  ];

  /// The third retained shell branch is the generic local project list. During
  /// the Batch 2 V1 rollout it must not be entered; use that familiar nav slot
  /// to open the connected V1 creation flow instead. The underlying branch
  /// index remains stable for the other tabs.
  static const _yorksV1NavItems = [
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      translatable: AppStrings.dashboard,
      path: RoutePaths.engineerHome,
    ),
    _NavItem(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      translatable: AppStrings.browse,
      path: RoutePaths.engineerBrowse,
    ),
    _NavItem(
      icon: Icons.add_circle_outline_rounded,
      activeIcon: Icons.add_circle_rounded,
      translatable: YorksV1ProjectStrings.createProject,
      path: RoutePaths.engineerCreateProject,
    ),
    _NavItem(
      icon: Icons.person_outlined,
      activeIcon: Icons.person_rounded,
      translatable: AppStrings.profile,
      path: RoutePaths.engineerProfile,
    ),
  ];

  /// New Request is the 5th branch (no visible tab) — reached via the centre
  /// "+" FAB / rail button. Index follows the 4 tab branches (0–3).
  static const _newRequestIndex = 4;

  /// Switch tabs, preserving each branch's state. A light haptic tick confirms
  /// the change without the worker looking down.
  void _goBranch(int index) {
    AppFeedback.tabSwitch();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useRail = screenWidth >= 840;
    final lang = ref.watch(languageProvider);
    final yorksV1ProjectsEnabled = ref
        .watch(yorksV1FeatureFlagsProvider)
        .projects;
    // The connected V1 routes share one production R35 chrome. Keeping this
    // switch at the shell boundary avoids nesting a legacy rail/bottom bar
    // around the new Yorks workspace as soon as the V1 project authority is
    // active. The stateful branches still remain mounted for a safe rollback.
    if (yorksV1ProjectsEnabled) {
      return YorksV1WorkspaceShell(child: navigationShell);
    }
    // Batch 2 supplies the normalized project foundation only. Its requests
    // arrive later, so this rollout must not open the retained generic request
    // workflow beside normalized project records.
    final showLegacyRequestAction = !yorksV1ProjectsEnabled;
    final navItems = yorksV1ProjectsEnabled ? _yorksV1NavItems : _navItems;
    void onNavItemTap(int index) {
      if (yorksV1ProjectsEnabled && index == 2) {
        context.push(RoutePaths.engineerCreateProject);
        return;
      }
      _goBranch(index);
    }

    if (useRail) {
      return _buildRailLayout(
        context,
        ref,
        currentIndex,
        screenWidth,
        lang,
        navItems,
        onNavItemTap,
        showLegacyRequestAction,
      );
    }
    return _buildMobileLayout(
      context,
      ref,
      currentIndex,
      lang,
      navItems,
      onNavItemTap,
      showLegacyRequestAction,
    );
  }

  // ─── Mobile: Custom Bottom NavigationBar ───────────────────────
  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    int currentIndex,
    AppLanguage lang,
    List<_NavItem> navItems,
    ValueChanged<int> onNavItemTap,
    bool showLegacyRequestAction,
  ) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      // The retained CTA is hidden while V1 projects are active. A V1 request
      // entry point arrives with the corresponding normalized request slice.
      floatingActionButton: showLegacyRequestAction
          ? _CenterAddButton(
              isActive: currentIndex == _newRequestIndex,
              onTap: () {
                AppFeedback.primaryAction();
                navigationShell.goBranch(
                  _newRequestIndex,
                  initialLocation: _newRequestIndex == currentIndex,
                );
              },
            )
          : null,
      // Centre-docked but lowered — a real FAB location (not a Transform), so
      // the tappable area moves down WITH the button and stays easy to hit.
      floatingActionButtonLocation: showLegacyRequestAction
          ? const _LoweredCenterDockedFab()
          : null,
      bottomNavigationBar: _LedgerBottomBar(
        currentIndex: currentIndex,
        items: navItems,
        lang: lang,
        onItemTap: onNavItemTap,
        showCenterAction: showLegacyRequestAction,
      ),
    );
  }

  // ─── Desktop/Web: Custom NavigationRail ─────────────────────────
  Widget _buildRailLayout(
    BuildContext context,
    WidgetRef ref,
    int currentIndex,
    double screenWidth,
    AppLanguage lang,
    List<_NavItem> navItems,
    ValueChanged<int> onNavItemTap,
    bool showLegacyRequestAction,
  ) {
    final isExtended = screenWidth >= 1200;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(
        children: [
          // ─── Custom Rail ──────────────────────────────
          _LedgerNavRail(
            currentIndex: currentIndex,
            items: navItems,
            isExtended: isExtended,
            lang: lang,
            onItemTap: onNavItemTap,
            showNewRequest: showLegacyRequestAction,
            onNewRequest: () {
              AppFeedback.primaryAction();
              navigationShell.goBranch(
                _newRequestIndex,
                initialLocation: _newRequestIndex == currentIndex,
              );
            },
          ),

          // ─── Content ────────────────────────────────
          Expanded(
            child: Column(
              children: [
                const SyncStatusBanner(),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: navigationShell,
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
}

// ═══════════════════════════════════════════════════════════════════
//  MOBILE — Custom Bottom Navigation Bar
// ═══════════════════════════════════════════════════════════════════

class _LedgerBottomBar extends StatelessWidget {
  const _LedgerBottomBar({
    required this.currentIndex,
    required this.items,
    required this.lang,
    required this.onItemTap,
    required this.showCenterAction,
  });

  final int currentIndex;
  final List<_NavItem> items;
  final AppLanguage lang;
  final ValueChanged<int> onItemTap;
  final bool showCenterAction;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    const radius = BorderRadius.vertical(top: Radius.circular(26));
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: radius,
        // Raised, floating 3D surface.
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 28,
            spreadRadius: 1,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: bottomPadding > 0 ? 0 : AppSpacing.sm,
            ),
            child: SizedBox(
              height: 68,
              child: Row(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    // Reserve the centre slot only while the retained request
                    // CTA is available.
                    if (showCenterAction && index == items.length ~/ 2)
                      const SizedBox(width: 76),
                    Expanded(
                      child: _BottomBarItem(
                        item: items[index],
                        isActive: currentIndex == index,
                        lang: lang,
                        onTap: () => onItemTap(index),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Standard Bottom Bar Item ─────────────────────────────────────

class _BottomBarItem extends StatefulWidget {
  const _BottomBarItem({
    required this.item,
    required this.isActive,
    required this.lang,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final AppLanguage lang;
  final VoidCallback onTap;

  @override
  State<_BottomBarItem> createState() => _BottomBarItemState();
}

class _BottomBarItemState extends State<_BottomBarItem> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isActive = widget.isActive;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      // Yorks uses a stable, immediate navigation affordance.
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ─── Icon with optional indicator pill ──────────
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isActive ? AppSpacing.lg : 0,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.onPrimary.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Icon(
              isActive ? item.activeIcon : item.icon,
              size: 22,
              color: isActive
                  ? AppColors.onPrimary
                  : AppColors.onPrimary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          DefaultTextStyle(
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive
                  ? AppColors.onPrimary
                  : AppColors.onPrimary.withValues(alpha: 0.75),
              letterSpacing: 0.2,
            ),
            child: Text(item.translatable.active(widget.lang)),
          ),
        ],
      ),
    );
  }
}

// ─── Centred, popped-out "New Request" button (docked in the bottom bar) ──

class _CenterAddButton extends StatelessWidget {
  const _CenterAddButton({required this.onTap, required this.isActive});

  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Opaque + the full 72px square is the hit area → easy to tap.
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Top-lit → bottom-shaded gradient gives the disc a 3D sphere look.
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryContainer,
              AppColors.primary,
              AppColors.onPrimaryFixed,
            ],
            stops: [0.0, 0.55, 1.0],
          ),
          border: Border.all(color: AppColors.surface, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppColors.scrim.withValues(alpha: 0.22),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          Icons.add_rounded,
          size: isActive ? 36 : 34,
          color: AppColors.onPrimary,
        ),
      ),
    );
  }
}

/// Centre-docked, but lowered so the hero button tucks into the bar. Because
/// this adjusts the FAB's *layout* position (not a paint transform), the hit
/// area stays aligned with what you see.
class _LoweredCenterDockedFab extends StandardFabLocation
    with FabCenterOffsetX, FabDockedOffsetY {
  const _LoweredCenterDockedFab();

  @override
  double getOffsetY(
    ScaffoldPrelayoutGeometry scaffoldGeometry,
    double adjustment,
  ) => super.getOffsetY(scaffoldGeometry, adjustment) + 30;
}

// ═══════════════════════════════════════════════════════════════════
//  DESKTOP — Custom Navigation Rail
// ═══════════════════════════════════════════════════════════════════

class _LedgerNavRail extends StatelessWidget {
  const _LedgerNavRail({
    required this.currentIndex,
    required this.items,
    required this.isExtended,
    required this.lang,
    required this.onItemTap,
    required this.onNewRequest,
    required this.showNewRequest,
  });

  final int currentIndex;
  final List<_NavItem> items;
  final bool isExtended;
  final AppLanguage lang;
  final ValueChanged<int> onItemTap;
  final VoidCallback onNewRequest;
  final bool showNewRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isExtended ? 240 : 80,
      color: AppColors.surfaceContainerLowest,
      child: SafeArea(
        child: Column(
          children: [
            // ─── Brand Header ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xxl,
                horizontal: AppSpacing.md,
              ),
              child: _RailHeader(isExtended: isExtended),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ─── Nav Items ───────────────────────────────
            ...List.generate(items.length, (index) {
              return _RailItem(
                item: items[index],
                isActive: currentIndex == index,
                isExtended: isExtended,
                lang: lang,
                onTap: () => onItemTap(index),
              );
            }),

            if (showNewRequest)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isExtended ? AppSpacing.lg : AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: _RailNewRequestButton(
                  isExtended: isExtended,
                  lang: lang,
                  onTap: onNewRequest,
                ),
              ),

            const Spacer(),

            // ─── Subtle version text ─────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: Text(
                isExtended ? 'Yorks AC. & Ref. v1.0' : 'v1.0',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Rail Brand Header ────────────────────────────────────────────

class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.isExtended});

  final bool isExtended;

  @override
  Widget build(BuildContext context) {
    if (isExtended) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLogo(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yorks AC. & Ref.',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'گودام پرو',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return _buildLogo();
  }

  Widget _buildLogo() => const BrandLogo(size: 40, shadow: false);
}

// ─── Rail Standard Item ──────────────────────────────────────────

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.item,
    required this.isActive,
    required this.isExtended,
    required this.lang,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final bool isExtended;
  final AppLanguage lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isExtended) {
      return _buildExtendedItem();
    }
    return _buildCompactItem();
  }

  Widget _buildExtendedItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primaryFixed.withValues(alpha: 0.4)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  size: 22,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.translatable.active(lang),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Active indicator dot
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 80,
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isActive ? AppSpacing.lg : AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primaryFixed.withValues(alpha: 0.5)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Icon(
                    isActive ? item.activeIcon : item.icon,
                    size: 22,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.translatable.active(lang),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  textDirection: lang.isRtl
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Rail "New Request" CTA Button ────────────────────────────────

class _RailNewRequestButton extends StatelessWidget {
  const _RailNewRequestButton({
    required this.isExtended,
    required this.lang,
    required this.onTap,
  });

  final bool isExtended;
  final AppLanguage lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isExtended) {
      return _buildExtended();
    }
    return _buildCompact();
  }

  Widget _buildExtended() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: AppColors.onPrimary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      AppStrings.newRequest.active(lang),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onPrimary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompact() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  DATA
// ═══════════════════════════════════════════════════════════════════

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.translatable,
    required this.path,
  });

  final IconData icon;
  final IconData activeIcon;
  final TranslatableString translatable;
  final String path;
}
