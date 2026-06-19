import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/providers/language_provider.dart';

/// Language selection screen — onboarding gate.
///
/// Matches design: logo, welcome bilingual text, language cards,
/// info banner, and a sticky "Get Started" CTA at the bottom.
class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _headerOpacity;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _cardsOpacity;
  late final Animation<Offset> _cardsSlide;
  late final Animation<double> _footerOpacity;
  late final Animation<Offset> _footerSlide;

  @override
  void initState() {
    super.initState();

    // Restore light status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _headerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
          ),
        );

    _cardsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
      ),
    );
    _cardsSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.2, 0.65, curve: Curves.easeOutCubic),
          ),
        );

    _footerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
      ),
    );
    _footerSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.45, 0.9, curve: Curves.easeOutCubic),
          ),
        );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _onGetStarted() async {
    await ref.read(onboardingCompleteProvider.notifier).complete();
    if (!mounted) return;
    context.go(RoutePaths.login);
  }

  @override
  Widget build(BuildContext context) {
    final selectedLanguage = ref.watch(languageProvider);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // ─── Scrollable Content ──────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: ResponsiveCenter(
                maxWidth: 560,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.huge),

                    // ─── Header: Logo + Welcome ────────────
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) => FractionalTranslation(
                        translation: _headerSlide.value,
                        child: Opacity(
                          opacity: _headerOpacity.value,
                          child: child,
                        ),
                      ),
                      child: _buildHeader(selectedLanguage),
                    ),

                    const SizedBox(height: AppSpacing.xxxl),

                    // ─── Section Label ─────────────────────
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) =>
                          Opacity(opacity: _cardsOpacity.value, child: child),
                      child: _buildSectionLabel(selectedLanguage),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ─── Language Cards ────────────────────
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) => FractionalTranslation(
                        translation: _cardsSlide.value,
                        child: Opacity(
                          opacity: _cardsOpacity.value,
                          child: child,
                        ),
                      ),
                      child: _buildLanguageCards(selectedLanguage),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // ─── Info Banner ───────────────────────
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) => FractionalTranslation(
                        translation: _footerSlide.value,
                        child: Opacity(
                          opacity: _footerOpacity.value,
                          child: child,
                        ),
                      ),
                      child: _buildInfoBanner(selectedLanguage),
                    ),

                    const SizedBox(height: AppSpacing.xxxl),

                    // ─── Footer Branding ──────────────────
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) =>
                          Opacity(opacity: _footerOpacity.value, child: child),
                      child: _buildFooterBranding(),
                    ),

                    // Bottom space for CTA clearance
                    const SizedBox(height: 100),
                  ],
                ),
              ),
              ),
            ),
          ),

          // ─── Sticky CTA ──────────────────────────────────
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) =>
                Opacity(opacity: _footerOpacity.value, child: child),
            child: _buildBottomCTA(bottomPadding, selectedLanguage),
          ),
        ],
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────
  Widget _buildHeader(AppLanguage language) {
    final welcome = AppStrings.welcomeTo;
    final tagline = AppStrings.architecturalLedger;

    return Column(
      children: [
        // App Logo
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primaryFixed.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/logo.png',
                width: 48,
                height: 48,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  Icons.inventory_2_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // App Name
        Text(
          'YORKS GODOWNPRO',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.0,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'THE ARCHITECTURAL LEDGER',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 3.5,
            color: AppColors.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: AppSpacing.xxxl),

        // Welcome text — bilingual
        Text(
          welcome.primary,
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.26,
            color: AppColors.onSurface,
            height: 1.3,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          welcome.secondary(language),
          textDirection: language.isRtl ? TextDirection.rtl : TextDirection.ltr,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: AppColors.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          tagline.secondary(language),
          textDirection: language.isRtl ? TextDirection.rtl : TextDirection.ltr,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ─── Section Label ───────────────────────────────────────────
  Widget _buildSectionLabel(AppLanguage language) {
    final selectLanguage = AppStrings.selectLanguage;

    return Align(
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: selectLanguage.primary,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            TextSpan(
              text: '  /  ',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.outlineVariant,
              ),
            ),
            TextSpan(
              text: selectLanguage.secondary(language),
              style: TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Language Cards ──────────────────────────────────────────
  Widget _buildLanguageCards(AppLanguage selectedLanguage) {
    return Column(
      children: AppLanguage.values.map((lang) {
        final isSelected = lang == selectedLanguage;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _LanguageCard(
            language: lang,
            isSelected: isSelected,
            onTap: () {
              ref.read(languageProvider.notifier).setLanguage(lang);
            },
          ),
        );
      }).toList(),
    );
  }

  // ─── Info Banner ─────────────────────────────────────────────
  Widget _buildInfoBanner(AppLanguage language) {
    final ready = AppStrings.dataSyncReady;
    final description = AppStrings.dataSyncDesc;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready.primary,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  ready.secondary(language),
                  textDirection: language.isRtl
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description.primary,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Footer Branding ─────────────────────────────────────────
  Widget _buildFooterBranding() {
    return Column(
      children: [
        Text(
          'Yorks GodownPro',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _footerLink('PRIVACY POLICY'),
            _footerDot(),
            _footerLink('TERMS OF SERVICE'),
            _footerDot(),
            _footerLink('SUPPORT'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '© 2024 THE ARCHITECTURAL LEDGER. ALL RIGHTS RESERVED.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w400,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _footerLink(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _footerDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ─── Bottom CTA ──────────────────────────────────────────────
  Widget _buildBottomCTA(double bottomPadding, AppLanguage language) {
    final getStarted = AppStrings.getStarted;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        bottomPadding + AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ResponsiveCenter(
        maxWidth: 560,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _onGetStarted,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  getStarted.primary,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '/',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  getStarted.secondary(language),
                  textDirection: language.isRtl
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 20,
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

// ─── Language Card Widget ───────────────────────────────────────
class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.surfaceContainerLowest
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.4)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.xl,
            ),
            child: Row(
              children: [
                // Language info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isSelected
                              ? AppColors.onSurface
                              : AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        language == AppLanguage.english
                            ? language.subtitle
                            : language.nativeName,
                        style: language.isRtl || language == AppLanguage.hindi
                            ? TextStyle(
                                fontSize: 14,
                                color: AppColors.onSurfaceVariant,
                                height: 1.5,
                              )
                            : GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: AppColors.onSurfaceVariant,
                              ),
                        textDirection: language.isRtl
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                      ),
                    ],
                  ),
                ),

                // Trailing icon
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isSelected
                      ? Container(
                          key: const ValueKey('selected'),
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          key: const ValueKey('unselected'),
                          Icons.language_rounded,
                          size: 22,
                          color: AppColors.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
