import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/constants.dart';
import '../../shared/models/user_role.dart';
import '../../shared/providers/session_provider.dart';

/// Dev-only role switcher. Stands in for real auth: pick the role to operate as.
/// Reachable from both the engineer profile and the office settings so any role
/// can switch to any other while testing.
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
                'Switch role (development)',
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
                  ref.read(currentRoleProvider.notifier).setRole(r);
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
