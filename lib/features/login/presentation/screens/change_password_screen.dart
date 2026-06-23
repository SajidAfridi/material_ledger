import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/providers/session_provider.dart';
import '../../../../shared/providers/users_provider.dart';

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
    await ref
        .read(usersProvider.notifier)
        .setPassword(user.id, _newController.text, temporary: false);
    if (!mounted) return;
    setState(() => _busy = false);
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
                      'Set a new password',
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Gap(AppSpacing.xs),
                    Text(
                      'Welcome${user != null ? ', ${user.fullName}' : ''}. '
                      'Choose a password only you know before continuing.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const Gap(AppSpacing.xxl),
                    LedgerTextField(
                      controller: _newController,
                      label: 'New password',
                      obscureText: true,
                      validator: (v) => (v ?? '').length < 6
                          ? 'Use at least 6 characters'
                          : null,
                    ),
                    const Gap(AppSpacing.lg),
                    LedgerTextField(
                      controller: _confirmController,
                      label: 'Confirm password',
                      obscureText: true,
                      validator: (v) =>
                          v != _newController.text ? 'Passwords do not match' : null,
                      onSubmitted: (_) => _save(),
                    ),
                    const Gap(AppSpacing.xxl),
                    PrimaryButton(
                      label: 'Save & continue',
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
