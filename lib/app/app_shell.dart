import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/constants.dart';
import '../core/feedback/feedback_service.dart';
import '../shared/models/app_language.dart';
import '../shared/models/app_strings.dart';
import '../shared/models/user_role.dart';
import '../shared/providers/language_provider.dart';
import '../shared/providers/permissions_provider.dart';
import '../shared/providers/session_provider.dart';
import '../shared/sync/sync_status_banner.dart';
import 'router.dart';

/// The single, role-aware application shell.
///
/// One [StatefulShellRoute] feeds this widget a [StatefulNavigationShell] with
/// five always-present branches (Home · Materials · Rentals · People · More).
/// The bottom bar / rail renders only the destinations the current [UserRole]
/// may use and `goBranch`es to the fixed branch index, so each tab keeps its own
/// navigation stack and back-button behavior.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Fixed branch indices (must match the branch order in `router.dart`).
  static const int _home = 0;
  static const int _materials = 1;
  static const int _rentals = 2;
  static const int _people = 3;
  static const int _more = 4;

  List<_Destination> _destinationsFor(
    UserRole role, {
    required bool canRentals,
    required bool canPeople,
  }) => [
    const _Destination(
      branch: _home,
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: AppStrings.home,
    ),
    const _Destination(
      branch: _materials,
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      label: AppStrings.materials,
    ),
    if (canRentals)
      const _Destination(
        branch: _rentals,
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront_rounded,
        label: AppStrings.rentalShops,
      ),
    if (canPeople)
      const _Destination(
        branch: _people,
        icon: Icons.groups_outlined,
        activeIcon: Icons.groups_rounded,
        label: AppStrings.people,
      ),
    if (role.isAdmin)
      const _Destination(
        branch: _more,
        icon: Icons.more_horiz_outlined,
        activeIcon: Icons.more_horiz_rounded,
        label: AppStrings.more,
      ),
  ];

  void _goBranch(int branch) {
    AppFeedback.tabSwitch(); // light haptic tick, eyes-free confirmation
    // Tapping the active tab returns it to its root (standard tab behavior).
    navigationShell.goBranch(
      branch,
      initialLocation: branch == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final lang = ref.watch(languageProvider);
    final destinations = _destinationsFor(
      role,
      canRentals: ref.watch(canAccessRentalsProvider),
      canPeople: ref.watch(canAccessPeopleProvider),
    );
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useRail = screenWidth >= 840;

    // Engineers raise material requests constantly — keep a prominent docked
    // "New Request" CTA for them (office roles don't raise site requests).
    final showNewRequest = !role.usesAdminPanel;

    if (useRail) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Row(
          children: [
            _LedgerRail(
              destinations: destinations,
              currentBranch: navigationShell.currentIndex,
              lang: lang,
              showNewRequest: showNewRequest,
              onSelect: _goBranch,
            ),
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      floatingActionButton: showNewRequest
          ? _CenterAddButton(
              onTap: () => context.push(RoutePaths.engineerNewRequest),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _LedgerBottomBar(
        destinations: destinations,
        currentBranch: navigationShell.currentIndex,
        lang: lang,
        reserveCenterSlot: showNewRequest,
        onSelect: _goBranch,
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.branch,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final int branch;
  final IconData icon;
  final IconData activeIcon;
  final TranslatableString label;
}

// ═══════════════════════════════════════════════════════════════════
//  MOBILE — bottom navigation bar
// ═══════════════════════════════════════════════════════════════════

class _LedgerBottomBar extends StatelessWidget {
  const _LedgerBottomBar({
    required this.destinations,
    required this.currentBranch,
    required this.lang,
    required this.reserveCenterSlot,
    required this.onSelect,
  });

  final List<_Destination> destinations;
  final int currentBranch;
  final AppLanguage lang;
  final bool reserveCenterSlot;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    const radius = BorderRadius.vertical(top: Radius.circular(26));
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.96),
        borderRadius: radius,
        // Layered shadow → the bar reads as a raised, floating surface (3D).
        boxShadow: [
          BoxShadow(
            color: AppColors.scrim.withValues(alpha: 0.10),
            blurRadius: 28,
            spreadRadius: 1,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: bottomPadding > 0 ? 0 : AppSpacing.sm,
              ),
              child: SizedBox(
                height: 66,
                child: Row(
                  children: [
                    for (var i = 0; i < destinations.length; i++) ...[
                      // Reserve the centre slot for the docked New Request FAB.
                      if (reserveCenterSlot && i == (destinations.length + 1) ~/ 2)
                        const SizedBox(width: 72),
                      Expanded(
                        child: _BottomBarItem(
                          destination: destinations[i],
                          isActive: destinations[i].branch == currentBranch,
                          lang: lang,
                          onTap: () => onSelect(destinations[i].branch),
                        ),
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

class _BottomBarItem extends StatefulWidget {
  const _BottomBarItem({
    required this.destination,
    required this.isActive,
    required this.lang,
    required this.onTap,
  });

  final _Destination destination;
  final bool isActive;
  final AppLanguage lang;
  final VoidCallback onTap;

  @override
  State<_BottomBarItem> createState() => _BottomBarItemState();
}

class _BottomBarItemState extends State<_BottomBarItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: isActive ? AppSpacing.lg : 0,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primaryFixed.withValues(alpha: 0.55)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                // The active pill lifts off the bar with a soft tinted shadow.
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isActive ? destination.activeIcon : destination.icon,
                size: 24,
                color: isActive
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              destination.label.primary,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              letterSpacing: 0.1,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _CenterAddButton extends StatelessWidget {
  const _CenterAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, size: 28, color: AppColors.onPrimary),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  DESKTOP / WEB — navigation rail
// ═══════════════════════════════════════════════════════════════════

class _LedgerRail extends StatelessWidget {
  const _LedgerRail({
    required this.destinations,
    required this.currentBranch,
    required this.lang,
    required this.showNewRequest,
    required this.onSelect,
  });

  final List<_Destination> destinations;
  final int currentBranch;
  final AppLanguage lang;
  final bool showNewRequest;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final isExtended = MediaQuery.sizeOf(context).width >= 1200;

    return Container(
      width: isExtended ? 240 : 80,
      color: AppColors.surfaceContainerLowest,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xxl,
                horizontal: AppSpacing.md,
              ),
              child: _RailHeader(isExtended: isExtended),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final d in destinations)
              _RailItem(
                destination: d,
                isActive: d.branch == currentBranch,
                isExtended: isExtended,
                lang: lang,
                onTap: () => onSelect(d.branch),
              ),
            if (showNewRequest)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isExtended ? AppSpacing.lg : AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: _RailNewRequestButton(
                  isExtended: isExtended,
                  onTap: () =>
                      GoRouter.of(context).push(RoutePaths.engineerNewRequest),
                ),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: Text(
                isExtended ? 'Yorks GodownPro v1.0' : 'v1.0',
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

class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.isExtended});

  final bool isExtended;

  @override
  Widget build(BuildContext context) {
    final logo = Container(
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
    if (!isExtended) return logo;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            'Yorks GodownPro',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.isActive,
    required this.isExtended,
    required this.lang,
    required this.onTap,
  });

  final _Destination destination;
  final bool isActive;
  final bool isExtended;
  final AppLanguage lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isExtended ? AppSpacing.md : AppSpacing.sm,
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
            padding: EdgeInsets.symmetric(
              horizontal: isExtended ? AppSpacing.lg : 0,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primaryFixed.withValues(alpha: 0.4)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              mainAxisAlignment: isExtended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  isActive ? destination.activeIcon : destination.icon,
                  size: 22,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                if (isExtended) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      destination.label.primary,
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
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailNewRequestButton extends StatelessWidget {
  const _RailNewRequestButton({required this.isExtended, required this.onTap});

  final bool isExtended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, size: 20, color: AppColors.onPrimary),
              if (isExtended) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  AppStrings.newRequest.primary,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
