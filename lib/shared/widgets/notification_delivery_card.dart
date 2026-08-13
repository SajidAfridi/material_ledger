import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/push_bridge.dart';
import '../../core/constants/constants.dart';
import '../models/app_language.dart';
import '../models/app_strings.dart';
import '../providers/language_provider.dart';
import '../services/notification_alert_sound.dart';
import '../services/push_service.dart';

class NotificationDeliveryCard extends ConsumerStatefulWidget {
  const NotificationDeliveryCard({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<NotificationDeliveryCard> createState() =>
      _NotificationDeliveryCardState();
}

class _NotificationDeliveryCardState
    extends ConsumerState<NotificationDeliveryCard> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final asyncStatus = ref.watch(pushDeliveryStatusProvider);
    final status =
        asyncStatus.valueOrNull ?? ref.watch(pushServiceProvider).status;
    final presentation = _presentation(status, language);
    return Semantics(
      liveRegion: true,
      label: '${presentation.title}. ${presentation.body}',
      child: Container(
        padding: EdgeInsets.all(widget.compact ? AppSpacing.md : AppSpacing.lg),
        decoration: BoxDecoration(
          color: presentation.color.withValues(alpha: .08),
          border: Border.all(color: presentation.color.withValues(alpha: .28)),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: presentation.color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: _working
                  ? Padding(
                      padding: const EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: presentation.color,
                      ),
                    )
                  : Icon(
                      presentation.icon,
                      color: presentation.color,
                      size: 21,
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    presentation.title,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    presentation.body,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  if (presentation.actionLabel != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _working ? null : _enable,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: Text(presentation.actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enable() async {
    setState(() => _working = true);
    await prepareNotificationAlertSound();
    await ref.read(pushServiceProvider).enable();
    if (mounted) setState(() => _working = false);
  }

  _DeliveryPresentation _presentation(
    PushDeliveryStatus status,
    AppLanguage language,
  ) {
    switch (status.authorization) {
      case PushAuthorizationState.authorized:
      case PushAuthorizationState.provisional:
        if (status.deviceRegistered) {
          return _DeliveryPresentation(
            icon: Icons.notifications_active_rounded,
            color: AppColors.success,
            title: AppStrings.alertsOn.active(language),
            body: AppStrings.alertsOnBody.active(language),
          );
        }
        return _DeliveryPresentation(
          icon: Icons.sync_rounded,
          color: AppColors.warning,
          title: AppStrings.alertSetupNeedsAttention.active(language),
          body: AppStrings.alertSetupNeedsAttentionBody.active(language),
          actionLabel: AppStrings.checkAgain.active(language),
        );
      case PushAuthorizationState.notDetermined:
        return _DeliveryPresentation(
          icon: Icons.notifications_none_rounded,
          color: AppColors.blue,
          title: AppStrings.enableAlerts.active(language),
          body: AppStrings.enableAlertsBody.active(language),
          actionLabel: AppStrings.enableAlerts.active(language),
        );
      case PushAuthorizationState.denied:
        return _DeliveryPresentation(
          icon: Icons.notifications_off_outlined,
          color: AppColors.error,
          title: AppStrings.alertsBlocked.active(language),
          body: AppStrings.alertsBlockedBody.active(language),
        );
      case PushAuthorizationState.unsupported:
        return _DeliveryPresentation(
          icon: Icons.notifications_outlined,
          color: AppColors.muted,
          title: AppStrings.alertsUnavailable.active(language),
          body: AppStrings.alertsUnavailableBody.active(language),
        );
      case PushAuthorizationState.error:
        return _DeliveryPresentation(
          icon: Icons.sync_problem_rounded,
          color: AppColors.warning,
          title: AppStrings.alertSetupNeedsAttention.active(language),
          body: AppStrings.alertSetupNeedsAttentionBody.active(language),
          actionLabel: AppStrings.checkAgain.active(language),
        );
      case PushAuthorizationState.checking:
        return _DeliveryPresentation(
          icon: Icons.sync_rounded,
          color: AppColors.blue,
          title: AppStrings.checkingAlertDelivery.active(language),
          body: AppStrings.enableAlertsBody.active(language),
        );
    }
  }
}

class _DeliveryPresentation {
  const _DeliveryPresentation({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.actionLabel,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String? actionLabel;
}
