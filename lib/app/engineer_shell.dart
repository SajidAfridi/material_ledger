import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/constants.dart';
import '../core/feedback/feedback_service.dart';
import '../shared/models/app_language.dart';
import '../shared/models/app_strings.dart';
import '../shared/providers/language_provider.dart';
import '../shared/sync/sync_status_banner.dart';
import 'router.dart';

/// Engineer shell — responsive navigation.
///
/// Mobile (< 840px): Custom bottom navigation with floating "New Request" CTA.
/// Tablet/Desktop (≥ 840px): Custom NavigationRail with highlighted CTA.
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

    if (useRail) {
      return _buildRailLayout(context, ref, currentIndex, screenWidth, lang);
    }
    return _buildMobileLayout(context, ref, currentIndex, lang);
  }

  // ─── Mobile: Custom Bottom NavigationBar ───────────────────────
  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    int currentIndex,
    AppLanguage lang,
  ) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      // The "New Request" CTA lives in the bottom bar — a centred, popped-out
      // button docked into the navigation. It activates the New Request branch
      // (kept mounted in the IndexedStack) so the draft survives tab switches.
      floatingActionButton: _CenterAddButton(
        isActive: currentIndex == _newRequestIndex,
        onTap: () {
          AppFeedback.primaryAction();
          navigationShell.goBranch(
            _newRequestIndex,
            initialLocation: _newRequestIndex == currentIndex,
          );
        },
      ),
      // Centre-docked but lowered — a real FAB location (not a Transform), so
      // the tappable area moves down WITH the button and stays easy to hit.
      floatingActionButtonLocation: const _LoweredCenterDockedFab(),
      bottomNavigationBar: _LedgerBottomBar(
        currentIndex: currentIndex,
        items: _navItems,
        onItemTap: _goBranch,
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
  ) {
    final isExtended = screenWidth >= 1200;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(
        children: [
          // ─── Custom Rail ──────────────────────────────
          _LedgerNavRail(
            currentIndex: currentIndex,
            items: _navItems,
            isExtended: isExtended,
            lang: lang,
            onItemTap: _goBranch,
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
    required this.onItemTap,
  });

  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onItemTap;

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
                    // Reserve the centre slot for the docked "New Request" button.
                    if (index == items.length ~/ 2) const SizedBox(width: 76),
                    Expanded(
                      child: _BottomBarItem(
                        item: items[index],
                        isActive: currentIndex == index,
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
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_BottomBarItem> createState() => _BottomBarItemState();
}

class _BottomBarItemState extends State<_BottomBarItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isActive = widget.isActive;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      // Press dip-and-pop — same feel as the hero +; the tab stays in place.
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ─── Icon with optional indicator pill ──────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
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
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? AppColors.onPrimary
                    : AppColors.onPrimary.withValues(alpha: 0.75),
                letterSpacing: 0.2,
              ),
              child: Text(item.translatable.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Centred, popped-out "New Request" button (docked in the bottom bar) ──

class _CenterAddButton extends StatefulWidget {
  const _CenterAddButton({required this.onTap, required this.isActive});

  final VoidCallback onTap;
  final bool isActive;

  @override
  State<_CenterAddButton> createState() => _CenterAddButtonState();
}

class _CenterAddButtonState extends State<_CenterAddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Opaque + the full 72px square is the hit area → easy to tap.
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        // Press dips it, release springs it back past 1.0 — an elegant pop.
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
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
            size: widget.isActive ? 36 : 34,
            color: AppColors.onPrimary,
          ),
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
  });

  final int currentIndex;
  final List<_NavItem> items;
  final bool isExtended;
  final AppLanguage lang;
  final ValueChanged<int> onItemTap;
  final VoidCallback onNewRequest;

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
                isExtended ? 'GodownPro v1.0' : 'v1.0',
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
                  'GodownPro',
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

  Widget _buildLogo() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.inventory_2_rounded, size: 20, color: Colors.white),
      ),
    );
  }
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
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
                        item.translatable.primary,
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
                      Text(
                        item.translatable.secondary(lang),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: isActive
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : AppColors.onSurfaceVariant.withValues(
                                  alpha: 0.45,
                                ),
                          height: 1.4,
                        ),
                        textDirection: lang.isRtl
                            ? TextDirection.rtl
                            : TextDirection.ltr,
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
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
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
                  item.translatable.secondary(lang),
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
                      AppStrings.newRequest.primary,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onPrimary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.newRequest.secondary(lang),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onPrimary.withValues(alpha: 0.7),
                    height: 1.3,
                  ),
                  textDirection: lang.isRtl
                      ? TextDirection.rtl
                      : TextDirection.ltr,
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
