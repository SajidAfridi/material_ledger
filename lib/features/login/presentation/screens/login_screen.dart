import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/providers/language_provider.dart';

/// Common login screen for Engineer, Office Management, and Admin roles.
/// Responsive: mobile shows a single-column layout;
/// iPad / desktop shows a branded side panel + sign-in card.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // ─── Validators ─────────────────────────────────────────────────
  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required';
    if (!text.contains('@') || !text.contains('.')) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'Password is required';
    return null;
  }

  // ─── Login Handler ──────────────────────────────────────────────
  Future<void> _handleLogin() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authSessionProvider.notifier).login();
      if (!mounted) return;
      context.go(RoutePaths.engineerHome);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 768;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: isWide ? _buildWideLayout(language) : _buildMobileLayout(language),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  MOBILE LAYOUT — Original single-column design
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMobileLayout(AppLanguage language) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.huge),
                  _buildMobileBrandHeader(),
                  const SizedBox(height: AppSpacing.massive),
                  BilingualText(
                    english: AppStrings.login.primary,
                    secondary: AppStrings.login.secondary(language),
                    englishStyle: AppTypography.displaySmall,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildMobileForm(language),
                  const SizedBox(height: AppSpacing.xxxl),
                  _buildMobileHeroBanner(),
                  const SizedBox(height: AppSpacing.colossal),
                  _buildMobileFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBrandHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.inventory_2_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Yorks GodownPro',
            style: AppTypography.headlineLarge.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'WAREHOUSE MANAGEMENT',
            style: AppTypography.labelMedium.copyWith(letterSpacing: 2.0),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeroBanner() {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x55DDE3ED), Color(0x99F1F4F8)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.precision_manufacturing_rounded,
          size: 64,
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _buildMobileFooter() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_user_rounded,
            size: 14,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            AppStrings.secureIndustrialEnvironment.primary,
            style: AppTypography.labelMedium.copyWith(
              letterSpacing: 1.8,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  WIDE LAYOUT — Branded left panel + Sign-in card on right
  // ═══════════════════════════════════════════════════════════════
  Widget _buildWideLayout(AppLanguage language) {
    return Row(
      children: [
        // ─── Left: Branded Panel ──────────────────────────────
        Expanded(child: _buildBrandedPanel()),

        // ─── Right: Sign-In Area ──────────────────────────────
        Expanded(child: _buildSignInPanel(language)),
      ],
    );
  }

  // ─── Left Branded Panel ────────────────────────────────────────
  Widget _buildBrandedPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A56DB), Color(0xFF003FB1), Color(0xFF002D7A)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Warehouse image overlay
          Positioned.fill(
            child: Image.asset(
              'assets/images/warehouse_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          // Dark overlay for text legibility
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF003FB1).withValues(alpha: 0.85),
                    const Color(0xFF002D7A).withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.huge,
                vertical: AppSpacing.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo + brand
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.inventory_2_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Text(
                        'Yorks GodownPro',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 3),

                  // Headline
                  Text(
                    'The Architectural\nLedger.',
                    style: GoogleFonts.inter(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.15,
                      letterSpacing: -0.96,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Description
                  Text(
                    'Precision-engineered inventory management\nfor the modern construction site.',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.75),
                      height: 1.6,
                    ),
                  ),

                  const Spacer(flex: 4),

                  // Stats row
                  Row(
                    children: [
                      _buildStat('12k+', 'ACTIVE PROJECTS'),
                      const SizedBox(width: AppSpacing.huge),
                      _buildStat('99.9%', 'UPTIME PRECISION'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.6),
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Right Sign-In Panel ───────────────────────────────────────
  Widget _buildSignInPanel(AppLanguage language) {
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.huge,
              vertical: AppSpacing.xxxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sign-in card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xxxl),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    ),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BilingualText(
                            english: AppStrings.signIn.primary,
                            secondary: AppStrings.signIn.secondary(language),
                            englishStyle: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          _buildWideForm(language),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Contact support
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.help_outline_rounded,
                          size: 18,
                          color: AppColors.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        BilingualText(
                          english: AppStrings.contactSupport.primary,
                          secondary: AppStrings.contactSupport.secondary(
                            language,
                          ),
                          englishStyle: AppTypography.bodyMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                          crossAxisAlignment: CrossAxisAlignment.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Version footer
                  Center(
                    child: Text(
                      'POWERED BY YORKS GODOWNPRO SYSTEMS V2.4',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  // Trust badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTrustBadge(Icons.verified_user_outlined),
                      const SizedBox(width: AppSpacing.xxl),
                      _buildTrustBadge(Icons.shield_outlined),
                      const SizedBox(width: AppSpacing.xxl),
                      _buildTrustBadge(Icons.security_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon) {
    return Icon(
      icon,
      size: 24,
      color: AppColors.onSurfaceVariant.withValues(alpha: 0.25),
    );
  }

  // ─── Wide form (inside card) ───────────────────────────────────
  Widget _buildWideForm(AppLanguage language) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email
          _buildBilingualLabel(
            AppStrings.emailAddress.primary,
            AppStrings.emailAddress.secondary(language),
            language,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            style: AppTypography.bodyLarge,
            decoration: InputDecoration(
              hintText: 'your@company.com',
              hintStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
            validator: _validateEmail,
          ),
          const SizedBox(height: AppSpacing.xl),

          // Password
          _buildBilingualLabel(
            AppStrings.password.primary,
            AppStrings.password.secondary(language),
            language,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            style: AppTypography.bodyLarge,
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
              ),
            ),
            onFieldSubmitted: (_) => _handleLogin(),
            validator: _validatePassword,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Remember me
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: BilingualText(
                    english: AppStrings.rememberMe.primary,
                    secondary: AppStrings.rememberMe.secondary(language),
                    englishStyle: AppTypography.bodyMedium,
                    gap: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Login button
          _buildWideLoginButton(language),
        ],
      ),
    );
  }

  Widget _buildBilingualLabel(
    String english,
    String secondary,
    AppLanguage language,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(english, style: AppTypography.titleSmall),
        Text(
          secondary,
          style: AppTypography.bodySmall,
          textDirection: language.isRtl ? TextDirection.rtl : TextDirection.ltr,
        ),
      ],
    );
  }

  Widget _buildWideLoginButton(AppLanguage language) {
    return IgnorePointer(
      ignoring: _isLoading,
      child: AnimatedOpacity(
        opacity: _isLoading ? 0.7 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleLogin,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Ink(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppStrings.login.primary,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.login.secondary(language),
                          textDirection: language.isRtl
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Mobile form ───────────────────────────────────────────────
  Widget _buildMobileForm(AppLanguage language) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          LedgerTextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            label: AppStrings.emailAddress.primary,
            urduHint: AppStrings.emailAddress.secondary(language),
            keyboardType: TextInputType.emailAddress,
            suffixIcon: const Icon(Icons.email_outlined),
            validator: _validateEmail,
            onSubmitted: (_) => _passwordFocusNode.requestFocus(),
          ),
          const SizedBox(height: AppSpacing.xl),
          LedgerTextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            label: AppStrings.password.primary,
            urduHint: AppStrings.password.secondary(language),
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
            validator: _validatePassword,
            onSubmitted: (_) => _handleLogin(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(
            label: AppStrings.accessSystem.primary,
            icon: _isLoading ? null : Icons.arrow_forward_rounded,
            isTrailingIcon: true,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _handleLogin,
          ),
        ],
      ),
    );
  }
}
