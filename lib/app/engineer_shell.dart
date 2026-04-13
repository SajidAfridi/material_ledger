import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/constants.dart';
import 'router.dart';

/// Engineer shell — responsive navigation.
///
/// Mobile (< 840px): Bottom NavigationBar with 4 tabs.
/// Tablet/Desktop (≥ 840px): NavigationRail on the left + content area.
///
/// Tabs: My Requests, Browse Materials, New Request, Profile.
class EngineerShellScreen extends StatelessWidget {
  const EngineerShellScreen({super.key, required this.child});

  final Widget child;

  static const _navItems = [
    _NavItem(
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment_rounded,
      label: 'My Requests',
      path: RoutePaths.engineerHome,
    ),
    _NavItem(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      label: 'Browse',
      path: RoutePaths.engineerBrowse,
    ),
    _NavItem(
      icon: Icons.add_circle_outline_rounded,
      activeIcon: Icons.add_circle_rounded,
      label: 'New Request',
      path: RoutePaths.engineerNewRequest,
    ),
    _NavItem(
      icon: Icons.person_outlined,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
      path: RoutePaths.engineerProfile,
    ),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _navItems.length; i++) {
      if (location == _navItems[i].path) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useRail = screenWidth >= 840;

    if (useRail) {
      return _buildRailLayout(context, currentIndex);
    }
    return _buildMobileLayout(context, currentIndex);
  }

  // ─── Mobile: Bottom NavigationBar ──────────────────────────────
  Widget _buildMobileLayout(BuildContext context, int currentIndex) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          context.go(_navItems[index].path);
        },
        destinations: _navItems.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.activeIcon),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }

  // ─── Desktop/Web: NavigationRail ───────────────────────────────
  Widget _buildRailLayout(BuildContext context, int currentIndex) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(
        children: [
          // ─── Rail ──────────────────────────────────────
          Container(
            color: AppColors.surfaceContainerLowest,
            child: NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                context.go(_navItems[index].path);
              },
              extended: MediaQuery.sizeOf(context).width >= 1200,
              backgroundColor: AppColors.surfaceContainerLowest,
              indicatorColor: AppColors.primaryFixed,
              labelType: MediaQuery.sizeOf(context).width >= 1200
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xxl,
                  horizontal: AppSpacing.md,
                ),
                child: _buildRailHeader(context),
              ),
              destinations: _navItems.map((item) {
                return NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.activeIcon),
                  label: Text(item.label),
                );
              }).toList(),
            ),
          ),

          // ─── Content ──────────────────────────────────
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Rail Header ───────────────────────────────────────────────
  Widget _buildRailHeader(BuildContext context) {
    final isExtended = MediaQuery.sizeOf(context).width >= 1200;

    if (isExtended) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(
                Icons.inventory_2_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'GodownPro',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
        ],
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.inventory_2_rounded, size: 20, color: Colors.white),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
}
