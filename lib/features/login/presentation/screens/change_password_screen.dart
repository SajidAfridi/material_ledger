import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/feedback/feedback_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/providers/session_provider.dart';

/// Forced on first sign-in for admin-created / password-reset accounts — the
/// user must set their own password before using the app (see the router gate).
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _busy = true);
    try {
      // Self-service update against the user's OWN session — works for a
      // non-admin changing an admin-set temporary password (the admin-only
      // provisioning function would 403 here).
      await ref
          .read(authControllerProvider)
          .changeOwnPassword(_newController.text);
    } catch (_) {
      // Surface the failure and let them retry — never strand them on a spinner
      // with the password silently unchanged.
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.passwordChangeFailed.primary)),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    AppFeedback.confirm();
    context.go(RoutePaths.engineerHome);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_reset_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
                    const Gap(AppSpacing.lg),
                    Text(
                      AppStrings.setNewPassword.primary,
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Gap(AppSpacing.xs),
                    Text(
                      user != null
                          ? '${user.fullName} — ${AppStrings.setNewPasswordBody.primary}'
                          : AppStrings.setNewPasswordBody.primary,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const Gap(AppSpacing.xxl),
                    LedgerTextField(
                      controller: _newController,
                      label: AppStrings.newPasswordLabel.primary,
                      obscureText: true,
                      validator: (v) => (v ?? '').length < 6
                          ? AppStrings.passwordTooShort.primary
                          : null,
                    ),
                    const Gap(AppSpacing.lg),
                    LedgerTextField(
                      controller: _confirmController,
                      label: AppStrings.confirmPasswordLabel.primary,
                      obscureText: true,
                      validator: (v) => v != _newController.text
                          ? AppStrings.passwordsDoNotMatch.primary
                          : null,
                      onSubmitted: (_) => _save(),
                    ),
                    const Gap(AppSpacing.xxl),
                    PrimaryButton(
                      label: AppStrings.saveAndContinue.primary,
                      icon: Icons.check_rounded,
                      isLoading: _busy,
                      onPressed: _busy ? null : _save,
                    ),
                    const Gap(AppSpacing.md),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          await ref.read(authControllerProvider).signOut();
                          if (!context.mounted) return;
                          context.go(RoutePaths.login);
                        },
                        child: Text(AppStrings.signOut.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
