import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/constants.dart';
import '../../shared/models/app_user.dart';
import '../../shared/models/user_role.dart';
import '../../shared/providers/language_provider.dart';
import '../../shared/providers/session_provider.dart';
import '../../shared/providers/users_provider.dart';

/// Dev-only quick sign-in. Real auth now drives the role from the signed-in
/// user, so this just signs in as the first active seed account of the chosen
/// role — a testing shortcut. Shown only in debug builds.
class RolePickerSheet extends ConsumerWidget {
  const RolePickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (_) => const RolePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentRoleProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Text(
                'Sign in as (development)',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            for (final r in UserRole.values)
              InkWell(
                onTap: () {
                  // Dev shortcut: open a session as the first active account
                  // with this role (bypasses the password screen).
                  AppUser? target;
                  for (final u in ref.read(usersProvider)) {
                    if (u.role == r && u.active) {
                      target = u;
                      break;
                    }
                  }
                  if (target != null) {
                    ref.read(authSessionProvider.notifier).setUser(target.id);
                  }
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.lg,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        r == current
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 22,
                        color: r == current
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      ),
                      const Gap(AppSpacing.lg),
                      Text(
                        r.label,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: r == current
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: r == current ? AppColors.primary : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
