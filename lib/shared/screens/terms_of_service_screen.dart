import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/constants.dart';
import '../../core/widgets/widgets.dart';
import '../models/app_strings.dart';
import '../providers/language_provider.dart';

/// Terms of Service screen — shared, accessible from About.
///
/// Follows "The Architectural Ledger" design: tonal layering, bilingual
/// section headers, no borders, extreme white space.
class TermsOfServiceScreen extends ConsumerWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: CustomScrollView(
              slivers: [
                // ─── App Bar ──────────────────────────────────
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
                        Expanded(
                          child: BilingualText(
                            english: AppStrings.termsOfService.primary,
                            secondary: AppStrings.termsOfService.secondary(
                              lang,
                            ),
                            englishStyle: AppTypography.titleLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverGap(AppSpacing.lg),

                // ─── Hero Banner ──────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _HeroBanner(
                      icon: Icons.gavel_rounded,
                      title: 'Terms of Service',
                      titleSecondary: 'سروس کی شرائط',
                      subtitle:
                          'Last updated: April 2026  •  Effective: April 1, 2026',
                    ),
                  ),
                ),

                const SliverGap(AppSpacing.xl),

                // ─── Acceptance Notice ────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  sliver: const SliverToBoxAdapter(child: _AcceptanceNotice()),
                ),

                const SliverGap(AppSpacing.lg),

                // ─── Sections ─────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  sliver: SliverList.separated(
                    itemCount: _sections.length,
                    separatorBuilder: (_, i) =>
                        const Gap(AppSpacing.listItemGap),
                    itemBuilder: (context, i) =>
                        _TermsSection(section: _sections[i]),
                  ),
                ),

                const SliverGap(AppSpacing.xxl),

                // ─── Footer Notice ────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  sliver: const SliverToBoxAdapter(child: _FooterNotice()),
                ),

                const SliverGap(AppSpacing.colossal),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hero Banner ─────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.icon,
    required this.title,
    required this.titleSecondary,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String titleSecondary;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.warningContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Center(
              child: Icon(icon, size: 26, color: AppColors.warning),
            ),
          ),
          const Gap(AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.22,
                    color: AppColors.onSurface,
                  ),
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  titleSecondary,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const Gap(AppSpacing.sm),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
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

// ─── Acceptance Notice ────────────────────────────────────────────
class _AcceptanceNotice extends StatelessWidget {
  const _AcceptanceNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Text(
              'By accessing or using Yorks GodownPro, you agree to be bound by these Terms of Service. If you do not agree to these terms, you may not use the application.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Terms Section Card ───────────────────────────────────────────
class _TermsSectionData {
  const _TermsSectionData({
    required this.icon,
    required this.title,
    required this.titleSecondary,
    required this.paragraphs,
    this.bullets,
  });

  final IconData icon;
  final String title;
  final String titleSecondary;
  final List<String> paragraphs;
  final List<String>? bullets;
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({required this.section});

  final _TermsSectionData section;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Section Header ───────────────────────────
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.warningContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Center(
                  child: Icon(section.icon, size: 18, color: AppColors.warning),
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      section.titleSecondary,
                      style: const TextStyle(
                        fontSize: 11,
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

          // ─── Paragraphs ───────────────────────────────
          ...section.paragraphs.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                p,
                style: AppTypography.bodyMedium.copyWith(
                  height: 1.65,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),

          // ─── Bullet Points ────────────────────────────
          if (section.bullets != null) ...[
            const Gap(AppSpacing.xs),
            ...section.bullets!.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(
                        top: 7,
                        right: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        b,
                        style: AppTypography.bodyMedium.copyWith(
                          height: 1.55,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Footer Notice ────────────────────────────────────────────────
class _FooterNotice extends StatelessWidget {
  const _FooterNotice();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LedgerCard(
          color: AppColors.inverseSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.balance_rounded,
                    size: 20,
                    color: AppColors.onInverseSurface,
                  ),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Governing Law',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onInverseSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(AppSpacing.md),
              Text(
                'These Terms shall be governed by and construed in accordance with the laws of the United Arab Emirates (UAE). Any disputes arising from these Terms shall be subject to the exclusive jurisdiction of the courts of Dubai, UAE.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.onInverseSurface.withValues(alpha: 0.75),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        const Gap(AppSpacing.xl),
        Text(
          '© 2026 Yorks GodownPro — All Rights Reserved',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.45),
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(AppSpacing.xs),
        Text(
          'Version 1.0.0  •  April 2026',
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Content Data ─────────────────────────────────────────────────
const _sections = [
  _TermsSectionData(
    icon: Icons.warehouse_rounded,
    title: '1. License to Use',
    titleSecondary: '1. استعمال کا لائسنس',
    paragraphs: [
      'Yorks GodownPro grants you a limited, non-exclusive, non-transferable, revocable license to use the application solely for your internal warehouse management operations.',
      'This license does not include the right to sublicense, sell, resell, transfer, assign, or commercially exploit the application in any way.',
    ],
  ),
  _TermsSectionData(
    icon: Icons.assignment_turned_in_rounded,
    title: '2. Acceptable Use',
    titleSecondary: '2. قابل قبول استعمال',
    paragraphs: [
      'You agree to use Yorks GodownPro only for lawful warehouse and inventory management purposes. The following uses are strictly prohibited:',
    ],
    bullets: [
      'Recording fictitious or fraudulent inventory transactions',
      'Attempting to reverse-engineer, decompile, or modify the application',
      'Using the application to store illegal goods or materials',
      'Sharing your account credentials with unauthorized persons',
      'Circumventing any security or authentication mechanisms',
    ],
  ),
  _TermsSectionData(
    icon: Icons.inventory_2_rounded,
    title: '3. Inventory Data Responsibility',
    titleSecondary: '3. انوینٹری ڈیٹا کی ذمہ داری',
    paragraphs: [
      'You are solely responsible for the accuracy and integrity of all inventory data entered into Yorks GodownPro. This includes material quantities, prices, project names, and transaction records.',
      'Yorks GodownPro provides tools to manage your data but does not verify the accuracy of the information you enter. Decisions made based on Yorks GodownPro data are your sole responsibility.',
      'Regular data backups are your responsibility. Yorks GodownPro is not liable for data loss resulting from device failure, uninstallation, or other circumstances.',
    ],
  ),
  _TermsSectionData(
    icon: Icons.engineering_rounded,
    title: '4. Material Requisitions',
    titleSecondary: '4. مواد کی درخواستیں',
    paragraphs: [
      'Material requisitions created within Yorks GodownPro are internal workflow tools. They do not constitute legally binding purchase orders unless explicitly printed, signed, and processed through your organization\'s official procurement channels.',
      'Yorks GodownPro is not responsible for procurement decisions, vendor negotiations, or financial commitments made based on requisitions generated within the application.',
    ],
  ),
  _TermsSectionData(
    icon: Icons.warning_amber_rounded,
    title: '5. Disclaimer of Warranties',
    titleSecondary: '5. ضمانت کا دستبرداری',
    paragraphs: [
      'Yorks GodownPro is provided "AS IS" without warranty of any kind, express or implied. We do not warrant that the application will be error-free, uninterrupted, or free of security vulnerabilities.',
      'We do not warrant the accuracy of any stock valuations, financial calculations, or inventory counts generated by the application. All figures should be verified against your physical inventory.',
    ],
  ),
  _TermsSectionData(
    icon: Icons.shield_outlined,
    title: '6. Limitation of Liability',
    titleSecondary: '6. ذمہ داری کی حد',
    paragraphs: [
      'To the maximum extent permitted by applicable law, Yorks GodownPro and its developers shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the application.',
      'This includes but is not limited to: loss of inventory data, incorrect stock valuations, procurement errors, or business interruption caused by application downtime or malfunction.',
    ],
  ),
  _TermsSectionData(
    icon: Icons.update_rounded,
    title: '7. Changes to Terms',
    titleSecondary: '7. شرائط میں تبدیلیاں',
    paragraphs: [
      'We reserve the right to modify these Terms of Service at any time. We will notify users of material changes through an in-app notification or upon next login.',
      'Your continued use of Yorks GodownPro after changes have been posted constitutes your acceptance of the revised Terms. If you do not agree to the new Terms, you should discontinue use of the application.',
    ],
  ),
];
