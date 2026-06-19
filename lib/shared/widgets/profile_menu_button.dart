import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/constants/constants.dart';
import '../models/app_strings.dart';

/// Top-right account avatar shown on the Home dashboards. Office roles
/// (procurement / admin) have no dedicated Profile tab, so this is their way in.
/// Tapping opens the account/settings screen directly — the same one engineers
/// get as their Profile tab, and Sign out already lives there, so there's no
/// intermediate popup to step through.
class ProfileMenuButton extends ConsumerWidget {
  const ProfileMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: AppStrings.profile.primary,
      child: InkWell(
        onTap: () => context.push(RoutePaths.engineerProfile),
        customBorder: const CircleBorder(),
        child: Container(
          width: AppSpacing.minTapTarget,
          height: AppSpacing.minTapTarget,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            size: 22,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
