import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/services/app_config_service.dart';

/// Full-screen blocking gate (force-update / maintenance). Mirrors the splash
/// layout so it feels native, and there is intentionally no way past it.
class _GateScaffold extends StatelessWidget {
  const _GateScaffold({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.huge),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
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
                    child: Icon(icon, size: 40, color: AppColors.primary),
                  ),
                  const Gap(AppSpacing.xl),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (action != null) ...[
                    const Gap(AppSpacing.xxl),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hard version block — the user must update via the store before continuing.
class UpdateRequiredScreen extends ConsumerWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeUrl = ref.watch(appConfigProvider).storeUrl;
    return _GateScaffold(
      icon: Icons.system_update_rounded,
      title: 'Update required',
      message:
          'A newer version of Yorks GodownPro is required to continue. Please '
          'update to the latest version to keep working.',
      action: SizedBox(
        width: double.infinity,
        child: PrimaryButton(
          label: 'Update now',
          icon: Icons.open_in_new_rounded,
          onPressed: () => launchUrl(
            Uri.parse(storeUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ),
    );
  }
}

/// Remote kill-switch / maintenance window.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return _GateScaffold(
      icon: Icons.engineering_rounded,
      title: 'Temporarily unavailable',
      message: config.maintenanceMessage.isNotEmpty
          ? config.maintenanceMessage
          : "We're carrying out maintenance and will be back shortly. Thanks "
                'for your patience.',
    );
  }
}
