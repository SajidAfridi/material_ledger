import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/constants.dart';
import '../shared/models/app_language.dart';
import '../shared/models/app_strings.dart';
import '../shared/providers/language_provider.dart';
import 'router.dart';

/// Admin/Office shell — persistent bottom navigation across all top-level routes.
///
/// Uses the same Ledger design language as the engineer shell:
/// frosted glass bottom bar, tonal layering, no borders.
class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key, required this.child});

  final Widget child;

  static const _navItems = [
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      translatable: AppStrings.dashboard,
      path: RoutePaths.dashboard,
    ),
    _NavItem(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      translatable: AppStrings.inventory,
      path: RoutePaths.inventory,
    ),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      translatable: AppStrings.transactions,
      path: RoutePaths.transactions,
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      translatable: AppStrings.settings,
      path: RoutePaths.settings,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _currentIndex(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useRail = screenWidth >= 840;
    final lang = ref.watch(languageProvider);

    if (useRail) {
      return _buildRailLayout(context, currentIndex, screenWidth, lang);
    }
    return _buildMobileLayout(context, currentIndex, lang);
  }

  // ─── Mobile: Custom Bottom Bar ─────────────────────────────────
  Widget _buildMobileLayout(
    BuildContext context,
    int currentIndex,
    AppLanguage lang,
  ) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: child,
      bottomNavigationBar: _AdminBottomBar(
        currentIndex: currentIndex,
        items: _navItems,
        lang: lang,
        onItemTap: (index) => context.go(_navItems[index].path),
      ),
    );
  }

  // ─── Desktop/Web: Custom NavigationRail ────────────────────────
  Widget _buildRailLayout(
    BuildContext context,
    int currentIndex,
    double screenWidth,
    AppLanguage lang,
  ) {
    final isExtended = screenWidth >= 1200;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(
        children: [
          _AdminNavRail(
            currentIndex: currentIndex,
            items: _navItems,
            isExtended: isExtended,
            lang: lang,
            onItemTap: (index) => context.go(_navItems[index].path),
          ),
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
//  MOBILE — Admin Bottom Bar
// ═══════════════════════════════════════════════════════════════════

class _AdminBottomBar extends StatelessWidget {
  const _AdminBottomBar({
    required this.currentIndex,
    required this.items,
    required this.lang,
    required this.onItemTap,
  });

  final int currentIndex;
  final List<_NavItem> items;
  final AppLanguage lang;
  final ValueChanged<int> onItemTap;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: AppColors.scrim.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: bottomPadding > 0 ? 0 : AppSpacing.sm,
              ),
              child: SizedBox(
                height: 64,
                child: Row(
                  children: List.generate(items.length, (index) {
                    return Expanded(
                      child: _AdminBottomBarItem(
                        item: items[index],
                        isActive: currentIndex == index,
                        lang: lang,
                        onTap: () => onItemTap(index),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminBottomBarItem extends StatelessWidget {
  const _AdminBottomBarItem({
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
                  ? AppColors.primaryFixed.withValues(alpha: 0.5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Icon(
              isActive ? item.activeIcon : item.icon,
              size: 24,
              color: isActive
                  ? AppColors.primary
                  : AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive
                  ? AppColors.primary
                  : AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              letterSpacing: isActive ? 0.1 : 0,
            ),
            child: Text(item.translatable.primary),
          ),
          Text(
            item.translatable.secondary(lang),
            style: TextStyle(
              fontSize: 9,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : AppColors.onSurfaceVariant.withValues(alpha: 0.4),
              height: 1.3,
            ),
            textDirection: lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  DESKTOP — Admin Navigation Rail
// ═══════════════════════════════════════════════════════════════════

class _AdminNavRail extends StatelessWidget {
  const _AdminNavRail({
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
              child: _AdminRailHeader(isExtended: isExtended),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ─── Nav Items ───────────────────────────────
            ...List.generate(items.length, (index) {
              return _AdminRailItem(
                item: items[index],
                isActive: currentIndex == index,
                isExtended: isExtended,
                lang: lang,
                onTap: () => onItemTap(index),
              );
            }),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: Text(
                isExtended ? 'GodownPro Admin v1.0' : 'v1.0',
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

class _AdminRailHeader extends StatelessWidget {
  const _AdminRailHeader({required this.isExtended});

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
                'Admin Panel',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminRailItem extends StatelessWidget {
  const _AdminRailItem({
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
    if (isExtended) return _buildExtended();
    return _buildCompact();
  }

  Widget _buildExtended() {
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

  Widget _buildCompact() {
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
