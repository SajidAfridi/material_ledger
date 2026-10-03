import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app.dart' show appRouterProvider;
import '../../app/router.dart' show RoutePaths;
import '../../core/widgets/yorks_app_toast.dart';
import '../models/app_notification.dart';
import '../models/app_strings.dart';
import '../models/yorks_v1_notification.dart';
import '../providers/language_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/yorks_v1_feature_flags_provider.dart';
import '../providers/yorks_v1_notification_provider.dart';
import '../providers/yorks_v1_notification_preferences_provider.dart';
import '../providers/yorks_v1_team_chat_provider.dart';
import '../services/notification_alert_sound.dart';
import '../services/push_service.dart';
import '../services/notification_visibility.dart';
import '../providers/session_provider.dart';
import '../models/notification_experience_strings.dart';
import '../models/yorks_v1_team_chat_strings.dart';

// Read browser focus at presentation time, including after asynchronous audio
// preparation. Keeping the operations injectable makes those races testable.
final notificationPresentationAllowedProvider = Provider<bool Function()>(
  (_) =>
      () => mayPresentNotification,
);
final notificationAlertSoundDriverProvider =
    Provider<({Future<bool> Function() prepare, Future<void> Function() play})>(
      (_) => (
        prepare: prepareNotificationAlertSound,
        play: playNotificationAlertSound,
      ),
    );

/// Turns authorized notification records into immediate foreground feedback.
///
/// Realtime remains only a refresh signal: this host alerts from the protected
/// notification projection, never from an untrusted client-side workflow
/// mutation. FCM only requests an authorized refresh; its text never becomes
/// a standalone notification outside that feed.
class NotificationAlertHost extends ConsumerStatefulWidget {
  const NotificationAlertHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationAlertHost> createState() =>
      _NotificationAlertHostState();
}

class _NotificationAlertHostState extends ConsumerState<NotificationAlertHost>
    with WidgetsBindingObserver {
  final Set<String> _knownServerIds = <String>{};
  final Set<String> _knownLegacyIds = <String>{};
  final Set<String> _alertedIds = <String>{};
  ProviderSubscription<AsyncValue<List<YorksV1NotificationRecord>>>?
  _serverSubscription;
  ProviderSubscription<List<AppNotification>>? _legacySubscription;
  StreamSubscription<PushMessage>? _pushSubscription;
  ProviderSubscription<Object?>? _accountSubscription;
  ProviderSubscription<bool>? _foregroundSubscription;
  final _toastOwner = Object();
  int _accountGeneration = 0;
  bool _foreground = true;
  bool _serverPrimed = false;
  bool _legacyPrimed = false;
  Future<bool>? _soundPreparation;
  DateTime? _lastSoundAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _accountSubscription = ref.listenManual(
      currentUserProvider.select((user) => user?.id),
      (_, next) {
        _accountGeneration++;
        YorksAppToast.dismiss(owner: _toastOwner);
        _serverPrimed = false;
        _legacyPrimed = false;
        _knownServerIds.clear();
        _knownLegacyIds.clear();
        _alertedIds.clear();
        _lastSoundAt = null;
      },
    );
    _foregroundSubscription = ref.listenManual(
      yorksV1ForegroundAlertsEnabledProvider,
      (_, enabled) {
        if (!enabled) YorksAppToast.dismiss(owner: _toastOwner);
      },
    );
    _serverSubscription = ref.listenManual(notificationAttentionFeedProvider, (
      _,
      next,
    ) {
      final records = next.valueOrNull;
      if (records == null) {
        if (next.isLoading) _serverPrimed = false;
        return;
      }
      if (!_serverPrimed) {
        _serverPrimed = true;
        _knownServerIds.addAll(records.map((record) => record.id));
        return;
      }
      final language = ref.read(languageProvider);
      final newRecords = records
          .where(
            (record) =>
                record.seenAt == null &&
                !_knownServerIds.contains(record.id) &&
                clock.now().difference(record.createdAt) <
                    const Duration(minutes: 1),
          )
          .where(
            (record) =>
                !_isOpenChatThread(record.toAppNotification(language).route),
          )
          .toList(growable: false);
      _knownServerIds
        ..clear()
        ..addAll(records.map((record) => record.id));
      final chatOnly = newRecords.every((record) => record.isChatTransport);
      final sameSurface =
          chatOnly || newRecords.every((record) => !record.isChatTransport);
      if (newRecords.length > 1 && sameSurface) {
        _show(
          AppNotification(
            id: 'burst-${newRecords.first.id}',
            type: NotificationType.info,
            title: NotificationExperienceStrings.updatesWaiting.active(
              language,
            ),
            titleSecondary: '',
            body: NotificationExperienceStrings.updateCount(
              newRecords.length,
              language,
            ),
            timestamp: clock.now(),
            route: chatOnly
                ? RoutePaths.yorksV1TeamChat
                : RoutePaths.notifications,
          ),
        );
        return;
      }
      if (newRecords.length > 1) {
        final chatCount = newRecords.where((n) => n.isChatTransport).length;
        _show(
          AppNotification(
            id: 'burst-${newRecords.first.id}',
            type: NotificationType.info,
            title: NotificationExperienceStrings.updatesWaiting.active(
              language,
            ),
            titleSecondary: '',
            body: NotificationExperienceStrings.mixedUpdateCount(
              newRecords.length - chatCount,
              chatCount,
              language,
            ),
            timestamp: clock.now(),
            route: RoutePaths.notifications,
          ),
          actionLabel: AppStrings.notifications.active(language),
          secondaryRoute: RoutePaths.yorksV1TeamChat,
          secondaryActionLabel: YorksV1TeamChatStrings.teamChat.active(
            language,
          ),
        );
        return;
      }
      for (final record in newRecords.reversed) {
        _show(
          record.toAppNotification(language),
          icon: record.isChatTransport
              ? Icons.chat_bubble_rounded
              : Icons.notifications_active_rounded,
        );
      }
    }, fireImmediately: true);
    _legacySubscription = ref.listenManual(notificationsProvider, (_, next) {
      if (!_legacyPrimed) {
        _legacyPrimed = true;
        _knownLegacyIds
          ..clear()
          ..addAll(next.map((notification) => notification.id));
        return;
      }
      final visibleIds = ref
          .read(visibleNotificationsProvider)
          .map((notification) => notification.id)
          .toSet();
      final additions = next
          .where(
            (notification) =>
                !notification.isRead &&
                visibleIds.contains(notification.id) &&
                !_knownLegacyIds.contains(notification.id),
          )
          .toList(growable: false);
      _knownLegacyIds
        ..clear()
        ..addAll(next.map((notification) => notification.id));
      for (final notification in additions.reversed) {
        _show(notification);
      }
    }, fireImmediately: true);
    _pushSubscription = ref.read(pushServiceProvider).onMessage.listen((push) {
      // Push is only a refresh signal. Test/console messages and stale payloads
      // cannot create an alert absent from the recipient's authorized feed.
      unawaited(ref.read(yorksV1NotificationsProvider.notifier).refresh());
      if (push.isTeamChat) _refreshChat();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) YorksAppToast.dismiss(owner: _toastOwner);
    if (_foreground) {
      // Baseline the first resumed fetch so returning does not replay backlog.
      _serverPrimed = false;
      _legacyPrimed = false;
      unawaited(
        ref.read(yorksV1NotificationPreferencesProvider.notifier).refresh(),
      );
      // Web Audio contexts and native audio sessions can be suspended while
      // the app is backgrounded. Re-prepare on resume and on the next pointer
      // gesture so a successful first alert does not make later alerts silent.
      unawaited(_prepareSound());
      unawaited(ref.read(yorksV1NotificationsProvider.notifier).refresh());
      _refreshChat();
      if (ref
              .read(yorksV1NotificationPreferencesProvider)
              .valueOrNull
              ?.pushEnabled ==
          true) {
        unawaited(ref.read(pushServiceProvider).register());
      }
    }
  }

  Future<bool> _prepareSound() {
    final inFlight = _soundPreparation;
    if (inFlight != null) return inFlight;
    late final Future<bool> attempt;
    attempt =
        Future<bool>.sync(
              ref.read(notificationAlertSoundDriverProvider).prepare,
            )
            .timeout(const Duration(seconds: 2), onTimeout: () => false)
            .catchError((_) => false)
            .whenComplete(() {
              if (identical(_soundPreparation, attempt)) {
                _soundPreparation = null;
              }
            });
    _soundPreparation = attempt;
    return attempt;
  }

  Future<void> _playSound(int generation, String? owner) async {
    try {
      if (await _prepareSound() &&
          _canPresent(generation, owner) &&
          ref.read(yorksV1NotificationSoundEnabledProvider)) {
        await ref.read(notificationAlertSoundDriverProvider).play();
      }
    } catch (_) {
      // Sound policy/failure never blocks the durable or visible notification.
    }
  }

  bool _canPresent(int generation, String? owner) =>
      mounted &&
      generation == _accountGeneration &&
      owner == ref.read(currentUserProvider)?.id &&
      _foreground &&
      ref.read(notificationPresentationAllowedProvider)() &&
      ref.read(yorksV1ForegroundAlertsEnabledProvider);

  bool _isOpenChatThread(String route) {
    final path = Uri.tryParse(route)?.path ?? '';
    return path.startsWith('${RoutePaths.yorksV1TeamChat}/') &&
        _activeRoutePath() == path;
  }

  void _refreshChat() {
    if (!ref.read(yorksV1FeatureFlagsProvider).teamChat) return;
    unawaited(ref.read(yorksV1TeamChatProvider.notifier).refresh());
  }

  String? _activeRoutePath() {
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      try {
        return ref
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path;
      } catch (_) {
        // This host is also reusable in embedded MaterialApp trees that do
        // not have a GoRouter ancestor. Those trees must still receive alerts.
        return null;
      }
    }
  }

  void _show(
    AppNotification notification, {
    IconData icon = Icons.notifications_active_rounded,
    String? actionLabel,
    String? secondaryRoute,
    String? secondaryActionLabel,
  }) {
    final generation = _accountGeneration;
    final owner = ref.read(currentUserProvider)?.id;
    if (!mounted ||
        !_foreground ||
        !ref.read(notificationPresentationAllowedProvider)() ||
        notification.title.trim().isEmpty) {
      return;
    }
    // Only the protected Chat loader/read cursor may acknowledge a thread.
    // Suppressing a redundant toast must not acknowledge a loading/error URL.
    if (_isOpenChatThread(notification.route)) return;
    if (!ref.read(yorksV1ForegroundAlertsEnabledProvider)) return;
    if (notification.id.isNotEmpty) {
      if (_alertedIds.contains(notification.id)) return;
      _alertedIds.add(notification.id);
      while (_alertedIds.length > 500) {
        _alertedIds.remove(_alertedIds.first);
      }
    }
    final now = clock.now();
    if (ref.read(yorksV1NotificationSoundEnabledProvider) &&
        (_lastSoundAt == null ||
            now.difference(_lastSoundAt!) >
                const Duration(milliseconds: 700))) {
      _lastSoundAt = now;
      unawaited(_playSound(generation, owner));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canPresent(generation, owner)) return;
      final localNavigator = Navigator.maybeOf(context, rootNavigator: true);
      final routerNavigator = localNavigator == null
          ? ref.read(appRouterProvider).routerDelegate.navigatorKey.currentState
          : null;
      final alertContext =
          (localNavigator ?? routerNavigator)?.overlay?.context;
      if (alertContext == null) return;
      YorksAppToast.show(
        alertContext,
        title: notification.title,
        message: notification.body,
        duration: const Duration(seconds: 4),
        maxWidth: 560,
        icon: icon,
        actionLabel: notification.route.isEmpty
            ? null
            : actionLabel ??
                  AppStrings.viewDetails.active(ref.read(languageProvider)),
        onAction: notification.route.isEmpty
            ? null
            : () {
                if (!_canPresent(generation, owner)) return;
                try {
                  final router = ref.read(appRouterProvider);
                  if (!notification.isServerAuthoritative &&
                      notification.route.startsWith(
                        RoutePaths.yorksV1TeamChat,
                      )) {
                    router.push(notification.route);
                  } else {
                    unawaited(
                      ref
                          .read(notificationActionsProvider)
                          .open(
                            notification,
                            navigate: (location) => router.push(location),
                          )
                          .catchError((Object _) {}),
                    );
                  }
                } catch (_) {
                  // A stale deep link must not make the alert action fatal.
                }
              },
        secondaryActionLabel: secondaryActionLabel,
        onSecondaryAction: secondaryRoute == null
            ? null
            : () {
                if (!_canPresent(generation, owner)) return;
                try {
                  ref.read(appRouterProvider).push(secondaryRoute);
                } catch (_) {
                  // Keep the authorized history available if a link is stale.
                }
              },
        dismissible: true,
        owner: _toastOwner,
      );
    });
  }

  @override
  void dispose() {
    _accountGeneration++;
    YorksAppToast.dismiss(owner: _toastOwner);
    WidgetsBinding.instance.removeObserver(this);
    _accountSubscription?.close();
    _foregroundSubscription?.close();
    _serverSubscription?.close();
    _legacySubscription?.close();
    _pushSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => unawaited(_prepareSound()),
      child: widget.child,
    );
  }
}
