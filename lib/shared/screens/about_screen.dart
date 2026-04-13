import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/router.dart';
import '../../core/constants/constants.dart';
import '../../core/widgets/widgets.dart';
import '../models/app_strings.dart';
import '../providers/language_provider.dart';

/// Shared About screen — used by both Engineer Profile and Admin Settings.
///
/// Follows "The Architectural Ledger" design language with:
/// - Hero brand section
/// - Paper Burden vs Digital Automation comparison
/// - Project Ecosystem role cards
/// - Industrial Strength Technology badges
/// - Footer with legal links
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 840;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── App Bar ─────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.screenHorizontal,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.onSurface,
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    BilingualText(
                      english: AppStrings.about.primary,
                      secondary: AppStrings.about.secondary(lang),
                      englishStyle: AppTypography.titleLarge,
                    ),
                  ],
                ),
              ),
            ),

            const SliverGap(AppSpacing.xl),

            // ─── Hero Brand Card ─────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverToBoxAdapter(child: _HeroBrandCard(isWide: isWide)),
            ),

            const SliverGap(AppSpacing.xxl),

            // ─── Paper Burden vs Digital Automation ──────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverToBoxAdapter(
                child: _ComparisonSection(isWide: isWide),
              ),
            ),

            const SliverGap(AppSpacing.xxl),

            // ─── Project Ecosystem ───────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverToBoxAdapter(
                child: _EcosystemSection(isWide: isWide),
              ),
            ),

            const SliverGap(AppSpacing.xxl),

            // ─── Industrial Strength Technology ──────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: const SliverToBoxAdapter(child: _TechBadgesSection()),
            ),

            const SliverGap(AppSpacing.xxl),

            // ─── App Info ────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverToBoxAdapter(child: _AppInfoCard(lang: lang)),
            ),

            const SliverGap(AppSpacing.xxl),

            // ─── Footer ──────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverToBoxAdapter(child: _Footer(lang: lang)),
            ),

            const SliverGap(AppSpacing.colossal),
          ],
        ),
      ),
    );
  }
}

// ─── Hero Brand Card ─────────────────────────────────────────────
class _HeroBrandCard extends StatelessWidget {
  const _HeroBrandCard({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Padding(
        padding: EdgeInsets.all(isWide ? AppSpacing.huge : AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Ledger icon ──────────────────────────────
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_stories_rounded,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ),
            const Gap(AppSpacing.xxl),

            // ─── Brand name ──────────────────────────────
            Text(
              'THE ARCHITECTURAL\nLEDGER',
              style: GoogleFonts.inter(
                fontSize: isWide ? 36 : 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1.1,
                color: Colors.white,
              ),
            ),
            const Gap(AppSpacing.md),

            // ─── Subtitle ─────────────────────────────────
            Text(
              'معماری لیجر',
              style: TextStyle(
                fontSize: isWide ? 20 : 16,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textDirection: TextDirection.rtl,
            ),
            const Gap(AppSpacing.xxl),

            // ─── Description ──────────────────────────────
            Text(
              'Industrial precision meets editorial clarity. '
              'A warehouse management system built for the '
              'rugged demands of construction.',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.6,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const Gap(AppSpacing.xxl),

            // ─── Version badge ────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                'v1.0.0 — April 2026',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Paper Burden vs Digital Automation ──────────────────────────
class _ComparisonSection extends StatelessWidget {
  const _ComparisonSection({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Why GodownPro?',
          subtitle: 'گوداؤن پرو کیوں؟',
        ),
        const Gap(AppSpacing.lg),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ComparisonCard.paperBurden()),
              const Gap(AppSpacing.lg),
              Expanded(child: _ComparisonCard.digitalAutomation()),
            ],
          )
        else ...[
          _ComparisonCard.paperBurden(),
          const Gap(AppSpacing.lg),
          _ComparisonCard.digitalAutomation(),
        ],
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.iconColor,
    required this.iconBg,
    this.isPositive = false,
  });

  factory _ComparisonCard.paperBurden() {
    return const _ComparisonCard(
      icon: Icons.description_outlined,
      title: 'The Paper Burden',
      subtitle: 'کاغذی بوجھ',
      iconColor: AppColors.warning,
      iconBg: AppColors.warningContainer,
      items: [
        'Manual material registers',
        'Lost requisition slips',
        'Delayed stock verification',
        'No real-time visibility',
      ],
    );
  }

  factory _ComparisonCard.digitalAutomation() {
    return const _ComparisonCard(
      icon: Icons.bolt_rounded,
      title: 'Digital Automation',
      subtitle: 'ڈیجیٹل آٹومیشن',
      iconColor: AppColors.success,
      iconBg: AppColors.successContainer,
      isPositive: true,
      items: [
        'Instant material requisitions',
        'Real-time stock tracking',
        'Automated verification',
        'Multi-project visibility',
      ],
    );
  }

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> items;
  final Color iconColor;
  final Color iconBg;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Center(child: Icon(icon, size: 22, color: iconColor)),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        height: 1.5,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.xl),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isPositive
                        ? Icons.check_circle_rounded
                        : Icons.remove_circle_outline_rounded,
                    size: 18,
                    color: isPositive
                        ? AppColors.success
                        : AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isPositive
                            ? AppColors.onSurface
                            : AppColors.onSurfaceVariant,
                        decoration: isPositive
                            ? null
                            : TextDecoration.lineThrough,
                        decorationColor: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Project Ecosystem ───────────────────────────────────────────
class _EcosystemSection extends StatelessWidget {
  const _EcosystemSection({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    const roles = [
      _RoleData(
        icon: Icons.supervisor_account_rounded,
        title: 'Project Manager',
        urdu: 'پروجیکٹ مینیجر',
        description:
            'Creates projects, approves requisitions, '
            'monitors budgets across all sites.',
        color: AppColors.primary,
      ),
      _RoleData(
        icon: Icons.engineering_rounded,
        title: 'Site Engineer',
        urdu: 'سائٹ انجینئر',
        description:
            'Submits material requests, browses warehouse '
            'inventory, tracks request status.',
        color: Color(0xFF6750A4),
      ),
      _RoleData(
        icon: Icons.warehouse_rounded,
        title: 'Godown Keeper',
        urdu: 'گودام کیپر',
        description:
            'Manages physical stock, records incoming/outgoing '
            'transactions, validates availability.',
        color: AppColors.success,
      ),
      _RoleData(
        icon: Icons.account_balance_rounded,
        title: 'Accountant',
        urdu: 'اکاؤنٹنٹ',
        description:
            'Tracks material costs, generates reports, '
            'manages budget codes and valuations.',
        color: AppColors.warning,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Project Ecosystem',
          subtitle: 'پروجیکٹ ایکو سسٹم',
        ),
        const Gap(AppSpacing.lg),
        if (isWide)
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: roles
                .map((r) => SizedBox(width: 280, child: _RoleCard(role: r)))
                .toList(),
          )
        else
          ...roles.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: _RoleCard(role: r),
            ),
          ),
      ],
    );
  }
}

class _RoleData {
  const _RoleData({
    required this.icon,
    required this.title,
    required this.urdu,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String urdu;
  final String description;
  final Color color;
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role});

  final _RoleData role;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: role.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Center(
                  child: Icon(role.icon, size: 24, color: role.color),
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      role.urdu,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        height: 1.5,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.md),
          Text(
            role.description,
            style: AppTypography.bodySmall.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ─── Industrial Strength Technology ──────────────────────────────
class _TechBadgesSection extends StatelessWidget {
  const _TechBadgesSection();

  @override
  Widget build(BuildContext context) {
    const badges = [
      _TechBadgeData(
        icon: Icons.flutter_dash,
        label: 'Flutter',
        detail: 'Cross-platform',
      ),
      _TechBadgeData(
        icon: Icons.storage_rounded,
        label: 'Local-first',
        detail: 'Offline capable',
      ),
      _TechBadgeData(
        icon: Icons.translate_rounded,
        label: '4 Languages',
        detail: 'EN · AR · UR · HI',
      ),
      _TechBadgeData(
        icon: Icons.currency_exchange_rounded,
        label: '4 Currencies',
        detail: 'AED · PKR · INR · USD',
      ),
      _TechBadgeData(
        icon: Icons.devices_rounded,
        label: 'Responsive',
        detail: 'Mobile to desktop',
      ),
      _TechBadgeData(
        icon: Icons.palette_outlined,
        label: 'MD3 Design',
        detail: 'Tonal layering',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Industrial Strength Technology',
          subtitle: 'صنعتی مضبوط ٹیکنالوجی',
        ),
        const Gap(AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: badges
              .map(
                (b) =>
                    _TechBadge(icon: b.icon, label: b.label, detail: b.detail),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _TechBadgeData {
  const _TechBadgeData({
    required this.icon,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String detail;
}

class _TechBadge extends StatelessWidget {
  const _TechBadge({
    required this.icon,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const Gap(AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                detail,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── App Info Card ───────────────────────────────────────────────
class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard({required this.lang});

  final dynamic lang;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Center(
                  child: Icon(
                    Icons.warehouse_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),
              const Gap(AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GodownPro',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Gap(AppSpacing.xxs),
                    const Text(
                      'گوداؤن پرو',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                        height: 1.5,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.xl),
          const _InfoRow(label: 'Framework', value: 'Flutter (Dart ^3.10.4)'),
          const _InfoRow(
            label: 'Design System',
            value: 'The Architectural Ledger',
          ),
          const _InfoRow(
            label: 'Languages',
            value: 'English · Arabic · Urdu · Hindi',
          ),
          const _InfoRow(label: 'Developer', value: 'GodownPro Team'),
          const _InfoRow(label: 'Version', value: '1.0.0'),
          const _InfoRow(label: 'Build', value: 'April 2026'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Footer ──────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer({required this.lang});

  final dynamic lang;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ─── Legal Links ──────────────────────────────────
        LedgerCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: [
              _FooterLink(
                icon: Icons.privacy_tip_outlined,
                label: AppStrings.privacyPolicy.primary,
                onTap: () => context.push(RoutePaths.privacyPolicy),
              ),
              _FooterLink(
                icon: Icons.gavel_rounded,
                label: AppStrings.termsOfService.primary,
                onTap: () => context.push(RoutePaths.termsOfService),
              ),
              _FooterLink(
                icon: Icons.code_rounded,
                label: AppStrings.openSourceLicenses.primary,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'GodownPro',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2026 GodownPro. All rights reserved.',
                ),
              ),
            ],
          ),
        ),

        const Gap(AppSpacing.xxl),

        // ─── Copyright ────────────────────────────────────
        Text(
          '© 2026 GodownPro — The Architectural Ledger',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(AppSpacing.xs),
        Text(
          'Built with Flutter & precision',
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
            const Gap(AppSpacing.lg),
            Expanded(child: Text(label, style: AppTypography.bodyLarge)),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ──────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.22,
            color: AppColors.onSurface,
          ),
        ),
        const Gap(AppSpacing.xxs),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.onSurfaceVariant,
            height: 1.5,
          ),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }
}
