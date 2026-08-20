import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';
import '../sync/sync_engine.dart';
import 'language_provider.dart' show supabaseClientProvider;
import 'session_provider.dart';
import 'users_provider.dart';
import 'yorks_v1_feature_flags_provider.dart';
import 'yorks_v1_notification_provider.dart';
import 'yorks_v1_team_chat_provider.dart';

const _kNotificationsKey = 'notifications_list_v3';
const _uuid = Uuid();

/// All in-app notifications (newest first).
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotification>>((ref) {
      return NotificationsNotifier(
        ref,
        ref
            .watch(storageProvider)
            .collection<AppNotification>(
              _kNotificationsKey,
              toJson: (n) => n.toJson(),
              fromJson: AppNotification.fromJson,
            ),
      );
    });

/// True when [n] should reach the signed-in [role]. Empty audience broadcasts
/// to everyone; admin reads all (FR-068); otherwise the audience must match the
/// role's name exactly ('procurement' / 'engineer').
bool notificationVisibleTo(
  AppNotification n,
  UserRole role, {
  String currentUserId = '',
}) {
  // User-targeted (e.g. "your leave was approved") → only that user; admin
  // still reads all (FR-068).
  if (n.userId.isNotEmpty) return role.isAdmin || n.userId == currentUserId;
  if (n.audience.isEmpty) return true;
  if (role.isAdmin) return true;
  return n.audience == role.name;
}

/// Notifications the current role is allowed to see (role-scoped delivery).
/// This is what every screen/badge should read so each role only sees alerts
/// meant for them — procurement gets engineer submissions, engineers get
/// dispatch/plan updates, admin sees everything.
final visibleNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final role = ref.watch(currentRoleProvider);
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  final legacy = ref
      .watch(notificationsProvider)
      .where((n) => notificationVisibleTo(n, role, currentUserId: userId))
      .toList();
  final authoritative = ref.watch(yorksV1AppNotificationsProvider);
  final merged = <AppNotification>[...authoritative, ...legacy]
    ..sort((left, right) => right.timestamp.compareTo(left.timestamp));
  return merged;
});

/// Count of unread notifications for the current role (drives the badge dot).
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(visibleNotificationsProvider).where((n) => !n.isRead).length;
});

/// Combined unresolved attention for surfaces outside Yorks itself (browser
/// title, installed-PWA icon and native desktop badge). Workflow alerts and
/// Team Chat intentionally remain separate inside the app: Team Chat never
/// enters the workflow bell, but an unread conversation should still make the
/// Yorks application visibly ask for the user's attention.
final yorksApplicationUnreadCountProvider = Provider<int>((ref) {
  final workflowUnread = ref.watch(unreadNotificationCountProvider);
  final teamChatEnabled = ref.watch(yorksV1FeatureFlagsProvider).teamChat;
  final chatUnread = teamChatEnabled
      ? ref.watch(yorksV1TeamChatUnreadProvider)
      : 0;
  return workflowUnread + chatUnread;
});

final notificationActionsProvider = Provider<NotificationActions>(
  NotificationActions.new,
);

class NotificationActions {
  const NotificationActions(this._ref);

  final Ref _ref;

  Future<void> markRead(AppNotification notification) {
    if (notification.isServerAuthoritative) {
      return _ref
          .read(yorksV1NotificationsProvider.notifier)
          .markSeen(notification.id);
    }
    return _ref.read(notificationsProvider.notifier).markRead(notification.id);
  }

  Future<void> markAllRead() async {
    // A Yorks workflow acknowledgement is committed to the recipient-owned
    // backend row first. This avoids presenting a device-local success when
    // the authoritative command could not be completed.
    await _ref.read(yorksV1NotificationsProvider.notifier).markAllSeen();
    await _ref.read(notificationsProvider.notifier).markAllRead();
  }

  Future<void> dismiss(AppNotification notification) async {
    if (notification.isServerAuthoritative) {
      await markRead(notification);
      return;
    }
    await _ref.read(notificationsProvider.notifier).dismiss(notification.id);
  }
}

/// Which `AppUser.id`s a push for [n] should reach: a personally-targeted
/// notification goes to just that user; a role-audience one fans out to every
/// ACTIVE user of that role; a pure broadcast (both empty) has no push
/// recipients (nothing to page — everyone already sees it passively). The
/// acting user is always excluded — you don't need a push for your own action.
Set<String> resolvePushTargets(
  AppNotification n,
  List<AppUser> users, {
  required String? currentUserId,
}) {
  final targets = <String>{};
  if (n.userId.isNotEmpty) {
    targets.add(n.userId);
  } else if (n.audience.isNotEmpty) {
    for (final u in users) {
      if (u.active && u.role.name == n.audience) targets.add(u.id);
    }
  }
  targets.remove(currentUserId);
  return targets;
}

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  NotificationsNotifier(this._ref, this._store)
    : super(_store.isSeeded ? _store.readAll() : _seed()) {
    if (!_store.isSeeded) _store.writeAll(state);
  }

  final Ref _ref;
  final CollectionStore<AppNotification> _store;

  Future<void> _persist() => _store.writeAll(state);

  /// Syncs a notification so it reaches the target user's OTHER devices — the
  /// event itself is shared data; only [dismiss] (hiding it from your own view)
  /// stays local-only.
  Future<void> _sync(AppNotification n, {required String kind}) {
    return _ref.enqueueSync(
      collection: 'notifications',
      docId: n.id,
      kind: kind,
      label: 'Notification',
      payload: n.toJson(),
    );
  }

  /// Best-effort push fan-out to [n]'s target audience/user. Push is pure
  /// transport for waking a device + deep-linking on tap — the notification
  /// ROW above already reached (or will reach, via sync/realtime) every
  /// device on its own, so a push failure here must never break the in-app
  /// notification. A no-op when Supabase isn't configured (tests/offline).
  Future<void> _triggerPush(AppNotification n) async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) return;

    final targets = resolvePushTargets(
      n,
      _ref.read(usersProvider),
      currentUserId: _ref.read(currentUserProvider)?.id,
    );
    if (targets.isEmpty) return;

    try {
      await client.functions.invoke(
        'send-push',
        body: {
          'targetAppUserIds': targets.toList(),
          'title': n.title,
          'body': n.body,
          'data': {
            if (n.route.isNotEmpty) 'route': n.route,
            'type': n.type.key,
            if (n.refId.isNotEmpty) 'refId': n.refId,
          },
        },
      );
    } catch (_) {
      // Best-effort — never let a push failure surface to the caller.
    }
  }

  /// Append a notification (newest first). The seam for event-driven alerts.
  /// [refId] + [route] make the alert deep-linkable (tap → that screen);
  /// [audience] scopes delivery to a role ('procurement' / 'engineer'), or ''
  /// to broadcast. All three default to empty so existing callers are unchanged.
  Future<void> add({
    required NotificationType type,
    required String title,
    required String titleSecondary,
    String body = '',
    String refId = '',
    String route = '',
    String audience = '',
    String userId = '',
  }) async {
    final n = AppNotification(
      id: 'notif-${_uuid.v4().substring(0, 8)}',
      type: type,
      title: title,
      titleSecondary: titleSecondary,
      body: body,
      timestamp: DateTime.now(),
      refId: refId,
      route: route,
      audience: audience,
      userId: userId,
    );
    state = [n, ...state];
    await _persist();
    await _sync(n, kind: 'notification.create');
    await _triggerPush(n);
  }

  Future<void> markRead(String id) async {
    AppNotification? updated;
    state = [
      for (final n in state)
        if (n.id == id) updated = n.copyWith(isRead: true) else n,
    ];
    if (updated == null) return;
    await _persist();
    await _sync(updated, kind: 'notification.read');
  }

  Future<void> markAllRead() async {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
    await _persist();
    // Best-effort fan-out; each is independently idempotent (upsert by id).
    for (final n in state) {
      await _sync(n, kind: 'notification.read');
    }
  }

  /// Hide a notification from THIS device's view only — never synced, so
  /// dismissing it on your phone doesn't remove it from anyone else's.
  Future<void> dismiss(String id) async {
    state = state.where((n) => n.id != id).toList();
    await _persist();
  }

  // No canned demo notifications — real alerts accrue as the app is used.
  static List<AppNotification> _seed() => [];
}
