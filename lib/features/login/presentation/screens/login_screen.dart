import 'package:flutter/material.dart';
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
    final result = await ref
        .read(authControllerProvider)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (result) {
      case SignInResult.ok:
      case SignInResult.mustChangePassword:
        ref.read(sessionLockedProvider.notifier).unlock();
        context.go(RoutePaths.engineerHome);
      case SignInResult.invalidCredentials:
        _showLoginError(YorksV1ShellStrings.invalidCredentials.primary);
      case SignInResult.deactivated:
        _showLoginError(YorksV1ShellStrings.accountDeactivated.primary);
      case SignInResult.networkError:
        _showLoginError(YorksV1ShellStrings.serverUnreachable.primary);
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
          : _AuthMobileLayout(owner: this, language: language),
    );
  }
}

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel({this.compact = false});

  final bool compact;

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
              compact ? AppSpacing.xl : AppSpacing.massive,
              compact ? AppSpacing.lg : AppSpacing.huge,
              compact ? AppSpacing.xl : AppSpacing.massive,
              compact ? AppSpacing.xl : AppSpacing.massive,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AuthBrandMark(),
                if (compact) ...[
                  const Spacer(),
                  Text(
                    YorksV1ShellStrings.operationalWorkspace.primary
                        .toUpperCase(),
                    style: AppTypography.eyebrow.copyWith(
                      color: const Color(0xFF82BCFF),
                      letterSpacing: 1.5,
                    ),
                  ),
                ] else ...[
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

class _AuthMobileLayout extends StatelessWidget {
  const _AuthMobileLayout({required this.owner, required this.language});

  final _LoginScreenState owner;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.surface,
    child: SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 280, child: const _AuthBrandPanel(compact: true)),
          Transform.translate(
            offset: const Offset(0, -22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _AuthCard(owner: owner, language: language, compact: true),
            ),
          ),
        ],
      ),
    ),
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
      padding: EdgeInsets.all(compact ? AppSpacing.xl : AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(20),
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
            const SizedBox(height: AppSpacing.xxl),
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
  const _AuthForm({required this.owner, required this.language});

  final _LoginScreenState owner;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Form(
    key: owner._formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AuthFieldLabel(label: YorksV1ShellStrings.companyEmail),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: owner._emailController,
          focusNode: owner._emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          style: AppTypography.bodyMedium.copyWith(color: AppColors.ink),
          decoration: _inputDecoration(
            hintText: YorksV1ShellStrings.companyEmailHint.primary,
          ),
          onFieldSubmitted: (_) => owner._passwordFocusNode.requestFocus(),
          validator: owner._validateEmail,
        ),
        const SizedBox(height: AppSpacing.lg),
        _AuthFieldLabel(label: AppStrings.password),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: owner._passwordController,
          focusNode: owner._passwordFocusNode,
          obscureText: owner._obscurePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          style: AppTypography.bodyMedium.copyWith(color: AppColors.ink),
          decoration: _inputDecoration(
            hintText: YorksV1ShellStrings.passwordHint.primary,
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
              ),
            ),
          ),
          onFieldSubmitted: (_) => owner._handleLogin(),
          validator: owner._validatePassword,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            SizedBox(
              width: AppSpacing.minTapTarget,
              height: AppSpacing.minTapTarget,
              child: Checkbox(
                value: owner._rememberMe,
                onChanged: (value) => owner._setRememberMe(value ?? false),
              ),
            ),
            Expanded(
              child: Text(
                AppStrings.rememberMe.primary,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ),
            Text(
              YorksV1ShellStrings.protectedSessionStatus.primary,
              style: AppTypography.labelMedium.copyWith(color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 48,
          child: FilledButton(
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

InputDecoration _inputDecoration({String? hintText, Widget? suffixIcon}) =>
    InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.mutedLight),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.error),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
    );

class _AuthFieldLabel extends StatelessWidget {
  const _AuthFieldLabel({required this.label});

  final TranslatableString label;

  @override
  Widget build(BuildContext context) => Text(
    label.primary,
    style: AppTypography.labelLarge.copyWith(
      color: AppColors.inkSecondary,
      fontWeight: FontWeight.w700,
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
