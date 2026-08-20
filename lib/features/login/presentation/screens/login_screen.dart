import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/security/session_lock.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_shell_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/session_provider.dart';

const _displayVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0',
);

/// Secure Yorks authentication in the approved R35 access composition.
///
/// The visual model follows the HTML prototype exactly; credentials still go
/// through [AuthController], so no prototype localStorage authorization or
/// session behavior leaks into the production path.
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
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF000E26),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return YorksV1ShellStrings.emailRequired.primary;
    if (!text.contains('@') || !text.contains('.')) {
      return YorksV1ShellStrings.emailInvalid.primary;
    }
    return null;
  }

  String? _validatePassword(String? value) => (value ?? '').isEmpty
      ? YorksV1ShellStrings.passwordRequired.primary
      : null;

  Future<void> _handleLogin() async {
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    SignInResult result;
    try {
      result = await ref
          .read(authControllerProvider)
          .signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
    } catch (_) {
      // AuthController classifies expected backend failures. This final guard
      // keeps an unexpected post-auth exception from leaving the form blocked.
      result = SignInResult.networkError;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    final language = ref.read(languageProvider);

    switch (result) {
      case SignInResult.ok:
      case SignInResult.mustChangePassword:
        ref.read(sessionLockedProvider.notifier).unlock();
        context.go(RoutePaths.engineerHome);
      case SignInResult.invalidCredentials:
        _showLoginError(
          YorksV1ShellStrings.invalidCredentials.secondary(language),
        );
      case SignInResult.deactivated:
        _showLoginError(
          YorksV1ShellStrings.accountDeactivated.secondary(language),
        );
      case SignInResult.emailNotConfirmed:
        _showLoginError(
          YorksV1ShellStrings.emailNotConfirmed.secondary(language),
        );
      case SignInResult.rateLimited:
        _showLoginError(YorksV1ShellStrings.rateLimited.secondary(language));
      case SignInResult.accountSetupRequired:
        _showLoginError(
          YorksV1ShellStrings.accountSetupRequired.secondary(language),
        );
      case SignInResult.networkError:
        _showLoginError(
          YorksV1ShellStrings.serverUnreachable.secondary(language),
        );
    }
  }

  void _showLoginError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
    );
  }

  void _toggleObscurePassword() {
    setState(() => _obscurePassword = !_obscurePassword);
  }

  void _setRememberMe(bool value) {
    setState(() => _rememberMe = value);
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final phone = YorksMobileUi.isActive(context);
    final desktop = MediaQuery.sizeOf(context).width > 900;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: desktop
          ? Row(
              children: [
                const Expanded(flex: 9, child: _AuthBrandPanel()),
                Expanded(
                  flex: 11,
                  child: _AuthFormPanel(owner: this, language: language),
                ),
              ],
            )
          : phone
          ? _AuthPhoneLayout(owner: this, language: language)
          : _AuthTabletLayout(owner: this, language: language),
    );
  }
}

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF081D36), AppColors.navy, AppColors.navyHover],
        stops: [0, 0.65, 1],
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(
          child: CustomPaint(painter: _AuthPerspectiveGridPainter()),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.massive,
              AppSpacing.huge,
              AppSpacing.massive,
              AppSpacing.massive,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AuthBrandMark(),
                const Spacer(flex: 3),
                const _AuthHero(),
                const Spacer(flex: 4),
                Text(
                  YorksV1ShellStrings.authorisedPersonnelOnly.primary,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.52),
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

class _AuthBrandMark extends StatelessWidget {
  const _AuthBrandMark();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const BrandLogo(size: 58, shadow: true),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              YorksV1ShellStrings.companyName.primary,
              style: AppTypography.titleLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              YorksV1ShellStrings.companyLegalName.primary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.66),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _AuthHero extends StatelessWidget {
  const _AuthHero();

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 500),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          YorksV1ShellStrings.operationalWorkspace.primary.toUpperCase(),
          style: AppTypography.eyebrow.copyWith(
            color: const Color(0xFF82BCFF),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          YorksV1ShellStrings.signInHero.primary,
          style: AppTypography.displayMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.05,
            letterSpacing: -1.25,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          YorksV1ShellStrings.signInHeroDescription.primary,
          style: AppTypography.bodyLarge.copyWith(
            color: const Color(0xFFC8D9EC),
            height: 1.6,
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        const Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _AuthCapability(
              label: YorksV1ShellStrings.projects,
              icon: Icons.folder_outlined,
            ),
            _AuthCapability(
              label: YorksV1ShellStrings.documentControl,
              icon: Icons.description_outlined,
            ),
            _AuthCapability(
              label: YorksV1ShellStrings.procurement,
              icon: Icons.inventory_2_outlined,
            ),
          ],
        ),
      ],
    ),
  );
}

class _AuthCapability extends StatelessWidget {
  const _AuthCapability({required this.label, required this.icon});

  final TranslatableString label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    height: AppSpacing.minTapTarget,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.09),
      border: Border.all(color: Colors.white.withValues(alpha: 0.19)),
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: const Color(0xFFC8D9EC)),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label.primary,
          style: AppTypography.labelLarge.copyWith(
            color: const Color(0xFFE5EFFA),
          ),
        ),
      ],
    ),
  );
}

class _AuthFormPanel extends StatelessWidget {
  const _AuthFormPanel({required this.owner, required this.language});

  final _LoginScreenState owner;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.surface,
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.huge),
          child: _AuthCard(owner: owner, language: language),
        ),
      ),
    ),
  );
}

class _AuthPhoneLayout extends StatelessWidget {
  const _AuthPhoneLayout({required this.owner, required this.language});

  final _LoginScreenState owner;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF041E42), Color(0xFF00183A), Color(0xFF000E26)],
          stops: [0, .54, 1],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shortViewport = constraints.maxHeight < 720;
            final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
            final topPadding = shortViewport ? 24.0 : 44.0;
            final bottomPadding = keyboardInset > 0 ? 16.0 : 24.0;
            final minimumContentHeight =
                (constraints.maxHeight - topPadding - bottomPadding)
                    .clamp(0.0, double.infinity)
                    .toDouble();
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                28,
                topPadding,
                28,
                bottomPadding + keyboardInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minimumContentHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      BrandLogo(size: shortViewport ? 72 : 84, shadow: true),
                      SizedBox(height: shortViewport ? 12 : 16),
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            YorksV1ShellStrings.companyName.primary,
                            textAlign: TextAlign.center,
                            style: AppTypography.headlineMedium.copyWith(
                              color: Colors.white,
                              fontSize: shortViewport ? 25 : 27,
                              fontWeight: FontWeight.w800,
                              height: 1.18,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        YorksV1ShellStrings.companyLegalNameCompact.primary,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyLarge.copyWith(
                          color: Colors.white.withValues(alpha: .72),
                          fontSize: shortViewport ? 14 : 15,
                          height: 1.42,
                        ),
                      ),
                      SizedBox(height: shortViewport ? 22 : 30),
                      _AuthForm(owner: owner, language: language, mobile: true),
                      SizedBox(height: shortViewport ? 28 : 40),
                      const Spacer(),
                      _MobileAuthFooter(compact: shortViewport),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

/// Keeps the established intermediate 721–900px composition intact. The new
/// immersive access UI is deliberately limited to the phone breakpoint.
class _AuthTabletLayout extends StatelessWidget {
  const _AuthTabletLayout({required this.owner, required this.language});

  final _LoginScreenState owner;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.mobileSurface,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 34, 18, 24),
        child: Column(
          children: [
            const BrandLogo(size: 72, shadow: true),
            const SizedBox(height: 14),
            Text(
              YorksV1ShellStrings.companyName.primary,
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              YorksV1ShellStrings.secureProjectWorkspace.primary,
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 26),
            _AuthCard(owner: owner, language: language, compact: true),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    YorksV1ShellStrings.authorisedPersonnelOnly.primary,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _MobileAuthFooter extends StatelessWidget {
  const _MobileAuthFooter({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        YorksV1ShellStrings.byContinuingYouAgreeToOur.primary,
        textAlign: TextAlign.center,
        style: AppTypography.bodyMedium.copyWith(
          color: Colors.white.withValues(alpha: .58),
          fontSize: compact ? 12 : 13,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '${AppStrings.termsOfService.primary} '
        '${YorksV1ShellStrings.and.primary} '
        '${AppStrings.privacyPolicy.primary}',
        textAlign: TextAlign.center,
        style: AppTypography.bodyMedium.copyWith(
          color: const Color(0xFF478EFF),
          fontSize: compact ? 12 : 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      SizedBox(height: compact ? 14 : 20),
      Text(
        'v$_displayVersion',
        style: AppTypography.bodyMedium.copyWith(
          color: Colors.white.withValues(alpha: .58),
          fontSize: compact ? 12 : 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.owner,
    required this.language,
    this.compact = false,
  });

  final _LoginScreenState owner;
  final AppLanguage language;
  final bool compact;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 455),
    child: Container(
      padding: EdgeInsets.all(compact ? 18 : AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(compact ? 15 : 20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 36,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              YorksV1ShellStrings.secureAccess.primary.toUpperCase(),
              style: AppTypography.eyebrow.copyWith(
                color: AppColors.blue,
                letterSpacing: 1.25,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.signIn.primary,
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              YorksV1ShellStrings.signInDescription.primary,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.muted,
                height: 1.55,
              ),
            ),
            SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xxl),
            _AuthForm(owner: owner, language: language),
            const SizedBox(height: AppSpacing.lg),
            const Divider(color: AppColors.line, height: 1),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 17,
                  color: Color(0xFF456785),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    YorksV1ShellStrings.accountabilityNotice.primary,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.muted,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.owner,
    required this.language,
    this.mobile = false,
  });

  final _LoginScreenState owner;
  final AppLanguage language;
  final bool mobile;

  @override
  Widget build(BuildContext context) => Form(
    key: owner._formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AuthFieldLabel(
          label: YorksV1ShellStrings.companyEmail,
          mobile: mobile,
        ),
        SizedBox(height: mobile ? 6 : AppSpacing.sm),
        TextFormField(
          controller: owner._emailController,
          focusNode: owner._emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.ink,
            fontSize: mobile ? 16 : null,
          ),
          cursorColor: AppColors.blue,
          decoration: _inputDecoration(
            hintText: YorksV1ShellStrings.companyEmailHint.primary,
            prefixIcon: mobile
                ? const Icon(Icons.mail_outline_rounded, color: AppColors.muted)
                : null,
            mobile: mobile,
          ),
          onFieldSubmitted: (_) => owner._passwordFocusNode.requestFocus(),
          validator: owner._validateEmail,
        ),
        SizedBox(height: mobile ? 15 : AppSpacing.lg),
        _AuthFieldLabel(label: AppStrings.password, mobile: mobile),
        SizedBox(height: mobile ? 6 : AppSpacing.sm),
        TextFormField(
          controller: owner._passwordController,
          focusNode: owner._passwordFocusNode,
          obscureText: owner._obscurePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.ink,
            fontSize: mobile ? 16 : null,
          ),
          cursorColor: AppColors.blue,
          decoration: _inputDecoration(
            hintText: YorksV1ShellStrings.passwordHint.primary,
            prefixIcon: mobile
                ? const Icon(Icons.lock_outline_rounded, color: AppColors.muted)
                : null,
            mobile: mobile,
            suffixIcon: IconButton(
              tooltip:
                  (owner._obscurePassword
                          ? YorksV1ShellStrings.showPassword
                          : YorksV1ShellStrings.hidePassword)
                      .secondary(language),
              onPressed: owner._toggleObscurePassword,
              icon: Icon(
                owner._obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: mobile ? AppColors.muted : null,
              ),
            ),
          ),
          onFieldSubmitted: (_) => owner._handleLogin(),
          validator: owner._validatePassword,
        ),
        SizedBox(height: mobile ? 8 : AppSpacing.sm),
        Row(
          children: [
            SizedBox(
              width: AppSpacing.minTapTarget,
              height: AppSpacing.minTapTarget,
              child: Checkbox(
                value: owner._rememberMe,
                onChanged: (value) => owner._setRememberMe(value ?? false),
                fillColor: mobile
                    ? WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? const Color(0xFF1677FF)
                            : Colors.transparent,
                      )
                    : null,
                checkColor: Colors.white,
                side: mobile
                    ? BorderSide(color: Colors.white.withValues(alpha: .68))
                    : null,
              ),
            ),
            Expanded(
              child: Text(
                AppStrings.rememberMe.primary,
                style: AppTypography.labelMedium.copyWith(
                  color: mobile
                      ? Colors.white.withValues(alpha: .9)
                      : AppColors.muted,
                  fontSize: mobile ? 13 : null,
                  fontWeight: mobile ? FontWeight.w600 : null,
                ),
              ),
            ),
            Text(
              YorksV1ShellStrings.protectedSessionStatus.primary,
              style: AppTypography.labelMedium.copyWith(
                color: mobile ? const Color(0xFF478EFF) : AppColors.muted,
                fontSize: mobile ? 13 : null,
                fontWeight: mobile ? FontWeight.w700 : null,
              ),
            ),
          ],
        ),
        SizedBox(height: mobile ? 10 : AppSpacing.sm),
        SizedBox(
          height: mobile ? 52 : 48,
          child: mobile
              ? _MobileSignInButton(owner: owner)
              : FilledButton(
                  onPressed: owner._isLoading ? null : owner._handleLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: owner._isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppStrings.signIn.primary,
                              style: AppTypography.labelLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                ),
        ),
      ],
    ),
  );
}

class _MobileSignInButton extends StatelessWidget {
  const _MobileSignInButton({required this.owner});

  final _LoginScreenState owner;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF247DFF), Color(0xFF0E5DEB)],
      ),
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(
          color: Color(0x40175FC6),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: owner._isLoading ? null : owner._handleLogin,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: owner._isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  AppStrings.signIn.primary,
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    ),
  );
}

InputDecoration _inputDecoration({
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool mobile = false,
}) => InputDecoration(
  hintText: hintText,
  hintStyle: AppTypography.bodyMedium.copyWith(
    color: mobile ? AppColors.muted : AppColors.mutedLight,
    fontSize: mobile ? 16 : null,
  ),
  fillColor: mobile ? Colors.white : null,
  isDense: mobile,
  contentPadding: EdgeInsets.symmetric(
    horizontal: mobile ? 16 : AppSpacing.lg,
    vertical: mobile ? 12 : AppSpacing.md,
  ),
  prefixIcon: prefixIcon,
  suffixIcon: suffixIcon,
  enabledBorder: OutlineInputBorder(
    borderSide: BorderSide(
      color: mobile ? Colors.white.withValues(alpha: .35) : AppColors.line,
    ),
    borderRadius: BorderRadius.circular(mobile ? 12 : AppSpacing.radiusMd),
  ),
  focusedBorder: OutlineInputBorder(
    borderSide: BorderSide(
      color: mobile ? const Color(0xFF5A9DFF) : AppColors.blue,
      width: 1.5,
    ),
    borderRadius: BorderRadius.circular(mobile ? 12 : AppSpacing.radiusMd),
  ),
  errorBorder: OutlineInputBorder(
    borderSide: const BorderSide(color: AppColors.error),
    borderRadius: BorderRadius.circular(mobile ? 12 : AppSpacing.radiusMd),
  ),
);

class _AuthFieldLabel extends StatelessWidget {
  const _AuthFieldLabel({required this.label, this.mobile = false});

  final TranslatableString label;
  final bool mobile;

  @override
  Widget build(BuildContext context) => Text(
    label.primary,
    style: AppTypography.labelLarge.copyWith(
      color: mobile
          ? Colors.white.withValues(alpha: .78)
          : AppColors.inkSecondary,
      fontSize: mobile ? 13 : null,
      fontWeight: mobile ? FontWeight.w600 : FontWeight.w700,
    ),
  );
}

class _AuthPerspectiveGridPainter extends CustomPainter {
  const _AuthPerspectiveGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF78BAFF).withValues(alpha: 0.13)
      ..strokeWidth = 1;
    const horizon = 0.68;
    final horizonY = size.height * horizon;
    for (var x = -size.width * 0.2; x <= size.width * 1.2; x += 42) {
      canvas.drawLine(
        Offset(size.width / 2, horizonY),
        Offset(x, size.height),
        paint,
      );
    }
    for (var index = 1; index < 9; index++) {
      final t = index / 9;
      final y = horizonY + ((size.height - horizonY) * t * t);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuthPerspectiveGridPainter oldDelegate) =>
      false;
}
