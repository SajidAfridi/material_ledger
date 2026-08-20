import 'dart:async';

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
import '../providers/yorks_v1_team_chat_provider.dart';
import '../services/notification_alert_sound.dart';
import '../services/push_service.dart';

/// Turns authorized notification records into immediate foreground feedback.
///
/// Realtime remains only a refresh signal: this host alerts from the protected
/// notification projection, never from an untrusted client-side workflow
/// mutation. FCM is also observed to reduce latency, with notification IDs
/// de-duplicating the later authoritative refresh.
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
  bool _serverPrimed = false;
  bool _legacyPrimed = false;
  bool _soundPrepared = false;
  Future<bool>? _soundPreparation;
  DateTime? _lastSoundAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _serverSubscription = ref.listenManual(yorksV1NotificationsProvider, (
      _,
      next,
    ) {
      final records = next.valueOrNull;
      if (records == null) return;
      if (!_serverPrimed) {
        _serverPrimed = true;
        _knownServerIds.addAll(records.map((record) => record.id));
        return;
      }
      final newRecords = records
          .where(
            (record) =>
                record.seenAt == null && !_knownServerIds.contains(record.id),
          )
          .toList(growable: false);
      _knownServerIds.addAll(records.map((record) => record.id));
      final language = ref.read(languageProvider);
      for (final record in newRecords.reversed) {
        _show(record.toAppNotification(language));
      }
    }, fireImmediately: true);
    _legacySubscription = ref.listenManual(notificationsProvider, (_, next) {
      if (!_legacyPrimed) {
        _legacyPrimed = true;
        _knownLegacyIds.addAll(next.map((notification) => notification.id));
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
      _knownLegacyIds.addAll(next.map((notification) => notification.id));
      for (final notification in additions.reversed) {
        _show(notification);
      }
    }, fireImmediately: true);
    _pushSubscription = ref.read(pushServiceProvider).onMessage.listen((push) {
      if (push.notificationId.isNotEmpty) {
        if (_alertedIds.contains(push.notificationId)) return;
      }
      _show(
        AppNotification(
          id: push.notificationId.isEmpty
              ? 'foreground-${DateTime.now().microsecondsSinceEpoch}'
              : push.notificationId,
          type: push.type,
          title: push.title,
          titleSecondary: push.titleSecondary,
          body: push.body,
          timestamp: DateTime.now(),
          refId: push.refId,
          route: push.route,
          origin: NotificationOrigin.yorksV1,
        ),
        icon: push.isTeamChat
            ? Icons.chat_bubble_rounded
            : Icons.notifications_active_rounded,
      );
      if (push.isTeamChat) {
        _refreshChat();
      } else {
        unawaited(ref.read(yorksV1NotificationsProvider.notifier).refresh());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(yorksV1NotificationsProvider.notifier).refresh());
      _refreshChat();
      unawaited(ref.read(pushServiceProvider).register());
    }
  }

  Future<bool> _prepareSound() {
    if (_soundPrepared) return Future<bool>.value(true);
    final inFlight = _soundPreparation;
    if (inFlight != null) return inFlight;
    late final Future<bool> attempt;
    attempt = prepareNotificationAlertSound()
        .then((prepared) {
          _soundPrepared = prepared;
          return prepared;
        })
        .whenComplete(() {
          if (identical(_soundPreparation, attempt)) _soundPreparation = null;
        });
    _soundPreparation = attempt;
    return attempt;
  }

  Future<void> _playSound() async {
    if (await _prepareSound()) await playNotificationAlertSound();
  }

  Future<void> _markRead(AppNotification notification) async {
    try {
      await ref.read(notificationActionsProvider).markRead(notification);
    } catch (_) {
      // The optimistic server state rolls back and Realtime/polling retries.
    }
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
  }) {
    if (!mounted || notification.title.trim().isEmpty) return;
    final notificationPath = notification.route.isEmpty
        ? ''
        : Uri.tryParse(notification.route)?.path ?? '';
    if (notificationPath.startsWith(RoutePaths.yorksV1TeamChat) &&
        _activeRoutePath() == notificationPath) {
      unawaited(_markRead(notification));
      return;
    }
    if (notification.id.isNotEmpty) {
      if (_alertedIds.contains(notification.id)) return;
      _alertedIds.add(notification.id);
    }
    final now = DateTime.now();
    if (_lastSoundAt == null ||
        now.difference(_lastSoundAt!) > const Duration(milliseconds: 700)) {
      _lastSoundAt = now;
      unawaited(_playSound());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
            : AppStrings.viewDetails.active(ref.read(languageProvider)),
        onAction: notification.route.isEmpty
            ? null
            : () {
                unawaited(_markRead(notification));
                try {
                  ref.read(appRouterProvider).push(notification.route);
                } catch (_) {
                  // A stale deep link must not make the alert action fatal.
                }
              },
        dismissible: true,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
