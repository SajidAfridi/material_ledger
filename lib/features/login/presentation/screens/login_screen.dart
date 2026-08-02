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

/// Yorks R35 sign-in experience.
///
/// The screen is deliberately a presentation layer over [AuthController]:
/// Supabase remains authoritative when configured and explicitly enabled local
/// development remains the only local-auth path. No auth state is stored here.
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
    final wide =
        MediaQuery.sizeOf(context).width >= AppSpacing.stackedBreakpoint;
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      body: wide
          ? Row(
              children: [
                const Expanded(child: _AuthBrandPanel()),
                Expanded(
                  child: _AuthFormPanel(owner: this, language: language),
                ),
              ],
            )
          : _AuthFormPanel(owner: this, language: language, compact: true),
    );
  }
}

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.navy,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.massive),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const BrandLogo(size: 46, shadow: false),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        YorksV1ShellStrings.companyName.primary,
                        style: AppTypography.titleLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        YorksV1ShellStrings.companyLegalName.primary,
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(flex: 3),
            Text(
              YorksV1ShellStrings.operationalWorkspace.primary.toUpperCase(),
              style: AppTypography.eyebrow.copyWith(
                color: AppColors.blueContainerStrong,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              YorksV1ShellStrings.projectCloseoutControl.primary,
              style: AppTypography.displayMedium.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.lg),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: Text(
                YorksV1ShellStrings.projectCloseoutDescription.primary,
                style: AppTypography.bodyLarge.copyWith(
                  color: Colors.white.withValues(alpha: 0.74),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            const Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _AuthCapability(label: YorksV1ShellStrings.projects),
                _AuthCapability(label: YorksV1ShellStrings.documentControl),
                _AuthCapability(label: YorksV1ShellStrings.procurement),
              ],
            ),
            const Spacer(flex: 4),
            Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: AppColors.blueContainerStrong,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    YorksV1ShellStrings.accountabilityNotice.primary,
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
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

class _AuthCapability extends StatelessWidget {
  const _AuthCapability({required this.label});

  final TranslatableString label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.11),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
    ),
    child: Text(
      label.primary,
      style: AppTypography.labelLarge.copyWith(color: Colors.white),
    ),
  );
}

class _AuthFormPanel extends StatelessWidget {
  const _AuthFormPanel({
    required this.owner,
    required this.language,
    this.compact = false,
  });

  final _LoginScreenState owner;
  final AppLanguage language;
  final bool compact;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? AppSpacing.xl : AppSpacing.huge),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact) ...[
                const _AuthCompactBrand(),
                const SizedBox(height: AppSpacing.xxxl),
              ],
              Container(
                padding: EdgeInsets.all(
                  compact ? AppSpacing.xl : AppSpacing.xxxl,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 28,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        YorksV1ShellStrings.secureAccess.primary.toUpperCase(),
                        style: AppTypography.eyebrow,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      BilingualText(
                        english: AppStrings.signIn.primary,
                        secondary: AppStrings.signIn.secondary(language),
                        englishStyle: AppTypography.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        YorksV1ShellStrings.protectedSession.primary,
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      _AuthForm(owner: owner, language: language),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      YorksV1ShellStrings.companyLegalName.primary,
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
    ),
  );
}

class _AuthCompactBrand extends StatelessWidget {
  const _AuthCompactBrand();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const BrandLogo(size: 62, shadow: false),
      const SizedBox(height: AppSpacing.md),
      Text(
        YorksV1ShellStrings.companyName.primary,
        style: AppTypography.titleLarge.copyWith(color: AppColors.navy),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        YorksV1ShellStrings.operationalWorkspace.primary,
        style: AppTypography.bodySmall,
      ),
    ],
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
        _AuthFieldLabel(
          label: YorksV1ShellStrings.companyEmail,
          language: language,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: owner._emailController,
          focusNode: owner._emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          style: AppTypography.bodyLarge,
          decoration: InputDecoration(
            hintText: YorksV1ShellStrings.companyEmailHint.primary,
            prefixIcon: const Icon(Icons.mail_outline_rounded),
          ),
          onFieldSubmitted: (_) => owner._passwordFocusNode.requestFocus(),
          validator: owner._validateEmail,
        ),
        const SizedBox(height: AppSpacing.lg),
        _AuthFieldLabel(label: AppStrings.password, language: language),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: owner._passwordController,
          focusNode: owner._passwordFocusNode,
          obscureText: owner._obscurePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          style: AppTypography.bodyLarge,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline_rounded),
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
              ),
            ),
          ),
          onFieldSubmitted: (_) => owner._handleLogin(),
          validator: owner._validatePassword,
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          checked: owner._rememberMe,
          button: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              onTap: () => owner._setRememberMe(!owner._rememberMe),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.minTapTarget,
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: owner._rememberMe,
                      onChanged: (value) =>
                          owner._setRememberMe(value ?? false),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: BilingualText(
                        english: AppStrings.rememberMe.primary,
                        secondary: AppStrings.rememberMe.secondary(language),
                        englishStyle: AppTypography.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: owner._isLoading ? null : owner._handleLogin,
            icon: owner._isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.login_rounded),
            label: Text(AppStrings.signIn.primary),
          ),
        ),
      ],
    ),
  );
}

class _AuthFieldLabel extends StatelessWidget {
  const _AuthFieldLabel({required this.label, required this.language});

  final TranslatableString label;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => BilingualText(
    english: label.primary,
    secondary: label.secondary(language),
    englishStyle: AppTypography.titleSmall,
  );
}
