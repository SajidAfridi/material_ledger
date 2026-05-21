import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/constants.dart';
import '../shared/models/app_language.dart';
import '../shared/models/app_strings.dart';
import '../shared/providers/language_provider.dart';
import 'router.dart';

/// Engineer shell — responsive navigation.
///
/// Mobile (< 840px): Custom bottom navigation with floating "New Request" CTA.
/// Tablet/Desktop (≥ 840px): Custom NavigationRail with highlighted CTA.
///
/// Tabs: Dashboard · Browse · Projects · Profile
class EngineerShellScreen extends ConsumerWidget {
  const EngineerShellScreen({super.key, required this.child});

  final Widget child;

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

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == RoutePaths.engineerCreateProject) return 2;
    for (int i = 0; i < _navItems.length; i++) {
      if (location == _navItems[i].path) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _currentIndex(context);
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
      body: child,
      floatingActionButton: _FloatingNewRequestFab(
        lang: lang,
        onTap: () => context.go(RoutePaths.engineerNewRequest),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _LedgerBottomBar(
        currentIndex: currentIndex,
        items: _navItems,
        onItemTap: (index) => context.go(_navItems[index].path),
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
            onItemTap: (index) => context.go(_navItems[index].path),
          ),

          // ─── Content ────────────────────────────────
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

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
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
              children: List.generate(items.length, (index) {
                return Expanded(
                  child: _BottomBarItem(
                    item: items[index],
                    isActive: currentIndex == index,
                    onTap: () => onItemTap(index),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Standard Bottom Bar Item ─────────────────────────────────────

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  size: 22,
                  color: isActive
                      ? AppColors.onPrimary
                      : AppColors.onPrimary.withValues(alpha: 0.7),
                ),
              ],
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
    );
  }
}

// ─── Floating "New Request" CTA Button ────────────────────────────

class _FloatingNewRequestFab extends StatelessWidget {
  const _FloatingNewRequestFab({required this.lang, required this.onTap});

  final AppLanguage lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 116,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, size: 34, color: AppColors.onPrimary),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.newRequest.secondary(lang),
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w500,
                color: AppColors.onPrimary,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textDirection: lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }
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
  });

  final int currentIndex;
  final List<_NavItem> items;
  final bool isExtended;
  final AppLanguage lang;
  final ValueChanged<int> onItemTap;

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
                onTap: () =>
                    GoRouter.of(context).go(RoutePaths.engineerNewRequest),
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
