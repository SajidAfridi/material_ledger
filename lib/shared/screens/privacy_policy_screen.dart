import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/constants.dart';
import '../../core/widgets/widgets.dart';
import '../models/app_strings.dart';
import '../providers/language_provider.dart';

/// Privacy Policy screen — shared, accessible from About.
///
/// Follows "The Architectural Ledger" design: tonal layering, bilingual
/// section headers, no borders, extreme white space.
class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

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
                            english: AppStrings.privacyPolicy.primary,
                            secondary: AppStrings.privacyPolicy.secondary(lang),
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
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      titleSecondary: 'رازداری کی پالیسی',
                      subtitle:
                          'Last updated: April 2026  •  Effective: April 1, 2026',
                    ),
                  ),
                ),

                const SliverGap(AppSpacing.xxl),

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
                        _PolicySection(section: _sections[i]),
                  ),
                ),

                const SliverGap(AppSpacing.xxl),

                // ─── Contact Box ──────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  sliver: const SliverToBoxAdapter(child: _ContactBox()),
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
        color: AppColors.primaryFixed.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Center(
              child: Icon(icon, size: 26, color: AppColors.primary),
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

// ─── Policy Section Card ─────────────────────────────────────────
class _PolicySectionData {
  const _PolicySectionData({
    required this.icon,
    required this.title,
    required this.titleSecondary,
    required this.paragraphs,
  });

  final IconData icon;
  final String title;
  final String titleSecondary;
  final List<String> paragraphs;
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.section});

  final _PolicySectionData section;

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
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Center(
                  child: Icon(section.icon, size: 18, color: AppColors.primary),
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
        ],
      ),
    );
  }
}

// ─── Contact Box ─────────────────────────────────────────────────
class _ContactBox extends StatelessWidget {
  const _ContactBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTACT US',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const Gap(AppSpacing.sm),
          Text(
            'Questions about this Privacy Policy?',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const Gap(AppSpacing.xs),
          Text(
            'رازداری کی پالیسی کے بارے میں سوالات؟',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
            textDirection: TextDirection.rtl,
          ),
          const Gap(AppSpacing.xl),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(
              'support@godownpro.com',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Content Data ─────────────────────────────────────────────────
const _sections = [
  _PolicySectionData(
    icon: Icons.info_outline_rounded,
    title: '1. Information We Collect',
    titleSecondary: '1. ہم کیا معلومات جمع کرتے ہیں',
    paragraphs: [
      'GodownPro collects only the information necessary to operate the warehouse management system effectively. All data is stored locally on your device using secure storage mechanisms.',
      'We collect: inventory item details (names, quantities, prices, categories), transaction records (incoming and outgoing material logs), material requisition data (project names, line items, status), user preferences (selected language, currency, appearance settings), and authentication session flags.',
      'We do NOT collect: personal identification beyond a username, biometric data, location data, payment card information, or any data that is not directly related to warehouse operations.',
    ],
  ),
  _PolicySectionData(
    icon: Icons.storage_rounded,
    title: '2. How We Store Your Data',
    titleSecondary: '2. آپ کا ڈیٹا کیسے محفوظ کیا جاتا ہے',
    paragraphs: [
      'All application data is stored locally on your device using Flutter\'s SharedPreferences mechanism. GodownPro is a local-first application — your warehouse data does not leave your device unless you explicitly use a backup or sync feature.',
      'Data is stored as JSON-encoded strings on the device\'s secure storage partition. No data is transmitted to external servers during normal operation.',
      'The Backup & Sync feature (when enabled in a future update) will require explicit user consent before any data is uploaded to cloud services.',
    ],
  ),
  _PolicySectionData(
    icon: Icons.share_rounded,
    title: '3. Data Sharing',
    titleSecondary: '3. ڈیٹا شیئرنگ',
    paragraphs: [
      'GodownPro does not share your data with any third parties. We do not sell, trade, or rent your warehouse information to anyone.',
      'Data may be shared only in the following circumstances: (a) when you explicitly export a report or PDF, (b) when you use the Print Order feature to send data to a printer, or (c) when required by applicable law.',
      'Any future integration with third-party accounting or ERP systems will require explicit user authorization and will be clearly disclosed in the application.',
    ],
  ),
  _PolicySectionData(
    icon: Icons.security_rounded,
    title: '4. Data Security',
    titleSecondary: '4. ڈیٹا کی حفاظت',
    paragraphs: [
      'We implement appropriate security measures to protect your warehouse data. The application uses platform-provided secure storage, and session authentication prevents unauthorized access.',
      'You are responsible for maintaining the security of your device and login credentials. We recommend using a strong password and enabling device-level security (PIN, biometric, etc.).',
      'In the event of a security concern, please contact us immediately at support@godownpro.com.',
    ],
  ),
  _PolicySectionData(
    icon: Icons.tune_rounded,
    title: '5. Your Rights & Controls',
    titleSecondary: '5. آپ کے حقوق اور اختیارات',
    paragraphs: [
      'You have full control over your data within GodownPro. You may view all stored data at any time through the application interface.',
      'You may delete any material, transaction record, or material request from within the application. Logging out of the application will clear your authentication session.',
      'A future update will provide a complete "Export My Data" and "Delete All Data" option in the Settings screen.',
    ],
  ),
  _PolicySectionData(
    icon: Icons.update_rounded,
    title: '6. Policy Updates',
    titleSecondary: '6. پالیسی کی تازہ کاری',
    paragraphs: [
      'We may update this Privacy Policy from time to time to reflect changes in our practices or applicable laws. We will notify users of significant changes through an in-app notification.',
      'The "Last updated" date at the top of this page indicates when this policy was last revised. Continued use of the application after changes constitutes acceptance of the updated policy.',
    ],
  ),
];
