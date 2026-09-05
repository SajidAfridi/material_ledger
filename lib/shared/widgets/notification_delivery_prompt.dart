import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/push_bridge.dart';
import '../../core/constants/constants.dart';
import '../models/app_language.dart';
import '../models/app_strings.dart';
import '../providers/language_provider.dart';
import '../providers/session_provider.dart';
import '../providers/yorks_v1_notification_preferences_provider.dart';
import '../services/notification_alert_sound.dart';
import '../services/push_service.dart';

/// A session-scoped, global enrollment prompt for system notifications.
///
/// Browser and OS permission dialogs must be initiated by a user gesture. The
/// previous notification-centre-only control was too easy to miss, leaving the
/// production device registry empty. This prompt appears after sign-in on
/// every unregistered supported installation, without opening a permission
/// dialog automatically. Dismissal lasts only for this app session.
class NotificationDeliveryPrompt extends ConsumerStatefulWidget {
  const NotificationDeliveryPrompt({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationDeliveryPrompt> createState() =>
      _NotificationDeliveryPromptState();
}

class _NotificationDeliveryPromptState
    extends ConsumerState<NotificationDeliveryPrompt> {
  bool _dismissed = false;
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final asyncStatus = ref.watch(pushDeliveryStatusProvider);
    final status =
        asyncStatus.valueOrNull ?? ref.watch(pushServiceProvider).status;
    final pushEnabled = ref
        .watch(yorksV1NotificationPreferencesProvider)
        .valueOrNull
        ?.pushEnabled;
    final shouldShow =
        currentUser != null &&
        pushEnabled == true &&
        !_dismissed &&
        status.authorization != PushAuthorizationState.checking &&
        status.authorization != PushAuthorizationState.unsupported &&
        !(status.isAllowed && status.deviceRegistered);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (shouldShow)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              minimum: const EdgeInsets.all(AppSpacing.md),
              child: _EnrollmentBanner(
                status: status,
                working: _working,
                language: ref.watch(languageProvider),
                onEnable: _enable,
                onDismiss: () => setState(() => _dismissed = true),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _enable() async {
    if (_working) return;
    setState(() => _working = true);
    final soundReady = await prepareNotificationAlertSound();
    final status = await ref.read(pushServiceProvider).enable();
    if (soundReady && status.isAllowed) {
      await playNotificationAlertSound();
    }
    if (mounted) setState(() => _working = false);
  }
}

class _EnrollmentBanner extends StatelessWidget {
  const _EnrollmentBanner({
    required this.status,
    required this.working,
    required this.language,
    required this.onEnable,
    required this.onDismiss,
  });

  final PushDeliveryStatus status;
  final bool working;
  final AppLanguage language;
  final VoidCallback onEnable;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation(status, language);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Material(
          color: AppColors.navy,
          elevation: 12,
          shadowColor: AppColors.scrim.withValues(alpha: .24),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            liveRegion: true,
            container: true,
            label: '${presentation.title}. ${presentation.body}',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final copy = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.onPrimary.withValues(alpha: .12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        presentation.icon,
                        color: AppColors.onPrimary,
                        size: 23,
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
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            presentation.body,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.onPrimary.withValues(alpha: .82),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: onDismiss,
                      color: AppColors.onPrimary,
                      constraints: const BoxConstraints.tightFor(
                        width: AppSpacing.minTapTarget,
                        height: AppSpacing.minTapTarget,
                      ),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                );
                final action = FilledButton.icon(
                  onPressed: working ? null : onEnable,
                  style: FilledButton.styleFrom(
                    minimumSize: Size(
                      compact ? double.infinity : 172,
                      AppSpacing.minTapTarget,
                    ),
                    backgroundColor: AppColors.onPrimary,
                    foregroundColor: AppColors.blue,
                    disabledBackgroundColor: AppColors.onPrimary.withValues(
                      alpha: .72,
                    ),
                  ),
                  icon: working
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.notifications_active_rounded),
                  label: Text(presentation.actionLabel),
                );
                if (compact) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        copy,
                        const SizedBox(height: AppSpacing.md),
                        action,
                      ],
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(child: copy),
                      const SizedBox(width: AppSpacing.md),
                      action,
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  _PromptPresentation _presentation(
    PushDeliveryStatus status,
    AppLanguage language,
  ) {
    if (status.authorization == PushAuthorizationState.denied) {
      return _PromptPresentation(
        icon: Icons.notifications_off_rounded,
        title: AppStrings.alertsBlocked.active(language),
        body: AppStrings.alertsBlockedBody.active(language),
        actionLabel: AppStrings.checkAgain.active(language),
      );
    }
    if (status.authorization == PushAuthorizationState.error ||
        (status.isAllowed && !status.deviceRegistered)) {
      return _PromptPresentation(
        icon: Icons.sync_problem_rounded,
        title: AppStrings.alertSetupNeedsAttention.active(language),
        body: AppStrings.alertSetupNeedsAttentionBody.active(language),
        actionLabel: AppStrings.checkAgain.active(language),
      );
    }
    return _PromptPresentation(
      icon: Icons.notifications_active_rounded,
      title: AppStrings.enableAlerts.active(language),
      body: AppStrings.enableAlertsBody.active(language),
      actionLabel: AppStrings.enableAlerts.active(language),
    );
  }
}

class _PromptPresentation {
  const _PromptPresentation({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
}
