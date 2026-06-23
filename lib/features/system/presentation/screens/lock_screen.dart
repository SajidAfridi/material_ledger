import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/security/session_lock.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/providers/session_provider.dart';

/// Full-screen lock overlay. The OS biometric prompt (Face ID on iPhone,
/// fingerprint on Android) fires automatically as soon as this appears and again
/// on resume — the user doesn't have to tap anything. Device passcode is the
/// built-in fallback; if the device has no secure method at all, locking is
/// meaningless so we let the user through rather than trap them.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _auth = LocalAuthentication();
  bool _authing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Prompt immediately on appear.
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_authing || !mounted) return;
    final controller = ref.read(sessionLockedProvider.notifier);
    setState(() {
      _authing = true;
      _failed = false;
    });
    // Tell the controller the sheet is up so the lifecycle bounce it causes
    // doesn't re-lock us after a successful unlock.
    controller.setAuthenticating(true);
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock Yorks GodownPro',
        biometricOnly: false, // allow device passcode fallback
        persistAcrossBackgrounding: true,
      );
      if (!mounted) return;
      if (ok) {
        controller.unlock();
      } else {
        setState(() => _failed = true); // user cancelled / no match
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      // No biometric AND no device passcode set → nothing to authenticate
      // against, so don't strand the user behind a lock they can't open.
      // (Platform error-code strings are stable across local_auth versions.)
      const noSecureMethod = {'NotAvailable', 'NotEnrolled', 'PasscodeNotSet'};
      if (noSecureMethod.contains(e.code)) {
        controller.unlock();
        return;
      }
      setState(() => _failed = true);
    } finally {
      controller.setAuthenticating(false);
      if (mounted) setState(() => _authing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.huge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
                const Gap(AppSpacing.xl),
                Text(
                  'Locked',
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Gap(AppSpacing.sm),
                Text(
                  _failed
                      ? 'Authentication needed to continue.'
                      : 'Verifying…',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const Gap(AppSpacing.xxl),
                // Retry affordance — only needed if the auto-prompt was
                // dismissed or failed.
                if (_failed)
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: 'Unlock',
                      icon: Icons.lock_open_rounded,
                      isLoading: _authing,
                      onPressed: _authing ? null : _authenticate,
                    ),
                  ),
                const Gap(AppSpacing.md),
                TextButton(
                  onPressed: () async {
                    ref.read(sessionLockedProvider.notifier).unlock();
                    await ref.read(authControllerProvider).signOut();
                    if (!context.mounted) return;
                    context.go(RoutePaths.login);
                  },
                  child: Text(AppStrings.signOut.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
