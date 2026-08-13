import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/constants.dart';
import '../models/app_notification.dart';
import '../models/app_strings.dart';
import '../models/yorks_v1_notification.dart';
import '../providers/language_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/yorks_v1_notification_provider.dart';
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
      );
      unawaited(ref.read(yorksV1NotificationsProvider.notifier).refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(yorksV1NotificationsProvider.notifier).refresh());
      unawaited(ref.read(pushServiceProvider).register());
    }
  }

  Future<void> _prepareSound() async {
    if (_soundPrepared) return;
    _soundPrepared = true;
    await prepareNotificationAlertSound();
  }

  void _show(AppNotification notification) {
    if (!mounted || notification.title.trim().isEmpty) return;
    if (notification.id.isNotEmpty) {
      if (_alertedIds.contains(notification.id)) return;
      _alertedIds.add(notification.id);
    }
    final now = DateTime.now();
    if (_lastSoundAt == null ||
        now.difference(_lastSoundAt!) > const Duration(milliseconds: 700)) {
      _lastSoundAt = now;
      unawaited(playNotificationAlertSound());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          backgroundColor: AppColors.navy,
          margin: const EdgeInsets.all(AppSpacing.md),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.onPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (notification.body.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onPrimary.withValues(alpha: .86),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          action: notification.route.isEmpty
              ? null
              : SnackBarAction(
                  label: AppStrings.viewDetails.active(
                    ref.read(languageProvider),
                  ),
                  textColor: AppColors.onPrimary,
                  onPressed: () {
                    unawaited(
                      ref
                          .read(notificationActionsProvider)
                          .markRead(notification),
                    );
                    if (mounted) context.push(notification.route);
                  },
                ),
        ),
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
