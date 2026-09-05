import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/yorks_navigation_history.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/yorks_v1_notification_preferences.dart';
import '../../../../shared/models/yorks_v1_notification_preferences_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_notification_preferences_provider.dart';
import '../../../../shared/services/push_service.dart';
import '../../../../shared/widgets/notification_delivery_card.dart';
import '../widgets/yorks_my_profile_components.dart';

/// Personal delivery controls for the one Yorks notification system.
///
/// This screen never filters or deletes the protected notification centre.
/// It writes only the current actor's optional transport/presentation choices.
class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final state = ref.watch(yorksV1NotificationPreferencesProvider);
    final compact =
        MediaQuery.sizeOf(context).width <= YorksMobileUi.breakpoint;
    return Directionality(
      textDirection: language.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: compact ? AppColors.mobileSurface : AppColors.surface,
        appBar: compact
            ? PreferredSize(
                preferredSize: const Size.fromHeight(
                  YorksMobileUi.appBarHeight,
                ),
                child: YorksMobileAppBar(
                  title: YorksV1NotificationPreferenceStrings.title.active(
                    language,
                  ),
                  leading: YorksMobileIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: () => yorksNavigateBack(
                      context,
                      ref,
                      RoutePaths.notificationPreferences,
                      fallback: RoutePaths.engineerProfile,
                    ),
                  ),
                ),
              )
            : null,
        body: SafeArea(
          top: !compact,
          child: RefreshIndicator(
            onRefresh: () => ref
                .read(yorksV1NotificationPreferencesProvider.notifier)
                .refresh(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                compact ? AppSpacing.mobileScreenHorizontal : AppSpacing.xxl,
                compact ? AppSpacing.lg : AppSpacing.screenVertical,
                compact ? AppSpacing.mobileScreenHorizontal : AppSpacing.xxl,
                compact ? 96 : AppSpacing.xxxl,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!compact) ...[
                          Semantics(
                            header: true,
                            child: Text(
                              YorksV1NotificationPreferenceStrings.title.active(
                                language,
                              ),
                              style: AppTypography.headlineLarge,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        Text(
                          YorksV1NotificationPreferenceStrings.introduction
                              .active(language),
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _MandatoryHistoryCard(language: language),
                        const SizedBox(height: AppSpacing.xl),
                        state.when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.xxxl),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (_, _) => _UnavailableCard(
                            language: language,
                            onRetry: () => ref
                                .read(
                                  yorksV1NotificationPreferencesProvider
                                      .notifier,
                                )
                                .refresh(),
                          ),
                          data: (preferences) =>
                              _controls(language, preferences),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        OutlinedButton.icon(
                          onPressed: () =>
                              context.push(RoutePaths.notifications),
                          icon: const Icon(Icons.notifications_outlined),
                          label: Text(
                            YorksV1NotificationPreferenceStrings
                                .openNotificationCentre
                                .active(language),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(
                              AppSpacing.minTapTarget,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls(
    AppLanguage language,
    YorksV1NotificationPreferences preferences,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        YorksProfileSectionCard(
          title: YorksV1NotificationPreferenceStrings.delivery.active(language),
          description: YorksV1NotificationPreferenceStrings.deliveryBody.active(
            language,
          ),
          icon: Icons.notifications_active_outlined,
          children: [
            _PreferenceSwitch(
              key: const ValueKey('notification-push-enabled'),
              icon: Icons.send_to_mobile_outlined,
              title: YorksV1NotificationPreferenceStrings.pushNotifications
                  .active(language),
              description: YorksV1NotificationPreferenceStrings
                  .pushNotificationsBody
                  .active(language),
              value: preferences.pushEnabled,
              enabled: !_saving,
              onChanged: (value) => _save(
                preferences.copyWith(pushEnabled: value),
                pushChanged: value,
              ),
            ),
            _PreferenceSwitch(
              key: const ValueKey('notification-workflow-enabled'),
              icon: Icons.fact_check_outlined,
              title: YorksV1NotificationPreferenceStrings.workflowAlerts.active(
                language,
              ),
              description: YorksV1NotificationPreferenceStrings
                  .workflowAlertsBody
                  .active(language),
              value: preferences.workflowPushEnabled,
              enabled: !_saving && preferences.pushEnabled,
              onChanged: (value) =>
                  _save(preferences.copyWith(workflowPushEnabled: value)),
            ),
            _PreferenceSwitch(
              key: const ValueKey('notification-chat-enabled'),
              icon: Icons.forum_outlined,
              title: YorksV1NotificationPreferenceStrings.teamChatAlerts.active(
                language,
              ),
              description: YorksV1NotificationPreferenceStrings
                  .teamChatAlertsBody
                  .active(language),
              value: preferences.teamChatPushEnabled,
              enabled: !_saving && preferences.pushEnabled,
              onChanged: (value) =>
                  _save(preferences.copyWith(teamChatPushEnabled: value)),
            ),
          ],
        ),
        if (preferences.pushEnabled) ...[
          const SizedBox(height: AppSpacing.md),
          const NotificationDeliveryCard(),
        ],
        const SizedBox(height: AppSpacing.xl),
        YorksProfileSectionCard(
          title: YorksV1NotificationPreferenceStrings.whileUsingYorks.active(
            language,
          ),
          description: YorksV1NotificationPreferenceStrings.inAppHistoryBody
              .active(language),
          icon: Icons.web_asset_outlined,
          children: [
            _PreferenceSwitch(
              key: const ValueKey('notification-foreground-enabled'),
              icon: Icons.view_agenda_outlined,
              title: YorksV1NotificationPreferenceStrings.foregroundAlerts
                  .active(language),
              description: YorksV1NotificationPreferenceStrings
                  .foregroundAlertsBody
                  .active(language),
              value: preferences.foregroundAlertsEnabled,
              enabled: !_saving,
              onChanged: (value) =>
                  _save(preferences.copyWith(foregroundAlertsEnabled: value)),
            ),
            _PreferenceSwitch(
              key: const ValueKey('notification-sound-enabled'),
              icon: Icons.volume_up_outlined,
              title: YorksV1NotificationPreferenceStrings.sound.active(
                language,
              ),
              description: YorksV1NotificationPreferenceStrings.soundBody
                  .active(language),
              value: preferences.soundEnabled,
              enabled: !_saving && preferences.foregroundAlertsEnabled,
              onChanged: (value) =>
                  _save(preferences.copyWith(soundEnabled: value)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _save(
    YorksV1NotificationPreferences desired, {
    bool? pushChanged,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    final language = ref.read(languageProvider);
    try {
      await ref
          .read(yorksV1NotificationPreferencesProvider.notifier)
          .save(desired);
      if (pushChanged == false) {
        final service = ref.read(pushServiceProvider);
        if (service is FcmPushService) await service.unregisterToken();
      } else if (pushChanged == true) {
        final service = ref.read(pushServiceProvider);
        if (service.status.isAllowed) {
          await service.register();
        } else {
          await service.enable();
        }
      }
      if (!mounted) return;
      _message(YorksV1NotificationPreferenceStrings.saved.active(language));
    } catch (_) {
      if (!mounted) return;
      _message(
        YorksV1NotificationPreferenceStrings.saveFailed.active(language),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? AppColors.error : AppColors.success,
        ),
      );
  }
}

class _MandatoryHistoryCard extends StatelessWidget {
  const _MandatoryHistoryCard({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.blueContainer,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      border: Border.all(color: AppColors.blue.withValues(alpha: .24)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.verified_user_outlined, color: AppColors.blue),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                YorksV1NotificationPreferenceStrings.inAppHistory.active(
                  language,
                ),
                style: AppTypography.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                YorksV1NotificationPreferenceStrings.inAppHistoryBody.active(
                  language,
                ),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({required this.language, required this.onRetry});

  final AppLanguage language;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      YorksMobileCallout(
        icon: Icons.sync_problem_outlined,
        title: YorksV1NotificationPreferenceStrings.unavailable.active(
          language,
        ),
        message: YorksV1NotificationPreferenceStrings.saveFailed.active(
          language,
        ),
        warning: true,
      ),
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(
          YorksV1NotificationPreferenceStrings.tryAgain.active(language),
        ),
      ),
    ],
  );
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    toggled: value,
    enabled: enabled,
    label: title,
    value: description,
    child: ExcludeSemantics(
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile.adaptive(
          secondary: Icon(icon, color: AppColors.inkSecondary),
          title: Text(title, style: AppTypography.titleSmall),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              description,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.inkSecondary,
              ),
            ),
          ),
          value: value,
          onChanged: enabled ? onChanged : null,
          activeThumbColor: AppColors.primary,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
        ),
      ),
    ),
  );
}
