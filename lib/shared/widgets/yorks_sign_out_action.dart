import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/constants/constants.dart';
import '../models/app_strings.dart';
import '../providers/language_provider.dart';
import '../providers/session_provider.dart';

/// The one Yorks sign-out command and confirmation used by profile launchers
/// and the canonical My Yorks page. Callers may offer an entry point, but they
/// must not invent a second confirmation or session-clearing path.
Future<void> showYorksSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => YorksSignOutConfirmationDialog(
      onCancel: () => Navigator.pop(dialogContext, false),
      onConfirm: () => Navigator.pop(dialogContext, true),
    ),
  );
  if (confirmed != true) return;
  await ref.read(authControllerProvider).signOut();
  if (context.mounted) context.go(RoutePaths.login);
}

class YorksSignOutConfirmationDialog extends ConsumerWidget {
  const YorksSignOutConfirmationDialog({
    super.key,
    required this.onCancel,
    required this.onConfirm,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      title: Text(AppStrings.signOut.active(language)),
      content: Text(AppStrings.logoutConfirmBody.active(language)),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(AppStrings.cancel.active(language)),
        ),
        FilledButton(
          onPressed: onConfirm,
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: Text(AppStrings.signOut.active(language)),
        ),
      ],
    );
  }
}
