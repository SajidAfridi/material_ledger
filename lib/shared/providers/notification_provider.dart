import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/app_notification.dart';
import '../models/user_role.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';
import 'session_provider.dart';

const _kNotificationsKey = 'notifications_list_v2';
const _uuid = Uuid();

/// All in-app notifications (newest first).
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotification>>((ref) {
      return NotificationsNotifier(
        ref.watch(storageProvider).collection<AppNotification>(
          _kNotificationsKey,
          toJson: (n) => n.toJson(),
          fromJson: AppNotification.fromJson,
        ),
      );
    });

/// True when [n] should reach the signed-in [role]. Empty audience broadcasts
/// to everyone; admin reads all (FR-068); otherwise the audience must match the
/// role's name exactly ('procurement' / 'engineer').
bool notificationVisibleTo(AppNotification n, UserRole role) {
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
  return ref
      .watch(notificationsProvider)
      .where((n) => notificationVisibleTo(n, role))
      .toList();
});

/// Count of unread notifications for the current role (drives the badge dot).
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(visibleNotificationsProvider).where((n) => !n.isRead).length;
});

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  NotificationsNotifier(this._store)
    : super(_store.isSeeded ? _store.readAll() : _seed()) {
    if (!_store.isSeeded) _store.writeAll(state);
  }

  final CollectionStore<AppNotification> _store;

  Future<void> _persist() => _store.writeAll(state);

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
    );
    state = [n, ...state];
    await _persist();
  }

  Future<void> markRead(String id) async {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
    await _persist();
  }

  Future<void> markAllRead() async {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
    await _persist();
  }

  Future<void> dismiss(String id) async {
    state = state.where((n) => n.id != id).toList();
    await _persist();
  }

  // ─── Seed: realistic lifecycle events (SRS §4.6) ────────────────
  static List<AppNotification> _seed() {
    final now = DateTime.now();
    return [
      AppNotification(
        id: 'notif-001',
        type: NotificationType.plan,
        title: 'Procurement marked your plan as Done',
        titleSecondary: 'پروکیورمنٹ نے آپ کا پلان مکمل کر دیا',
        body: 'Villa 12 — Al Reem · ready for your final review.',
        timestamp: now.subtract(const Duration(minutes: 12)),
      ),
      AppNotification(
        id: 'notif-002',
        type: NotificationType.request,
        title: 'Request dispatched to site',
        titleSecondary: 'درخواست سائٹ پر روانہ کر دی گئی',
        body: 'Marina Bay Mall — Chiller Plant · 8 items on the way.',
        timestamp: now.subtract(const Duration(hours: 3)),
      ),
      AppNotification(
        id: 'notif-003',
        type: NotificationType.stock,
        title: 'Low stock: Copper Pipe 3/4"',
        titleSecondary: 'کم اسٹاک: تانبے کا پائپ 3/4"',
        body: '120 ft left, below the 200 ft threshold.',
        timestamp: now.subtract(const Duration(hours: 6)),
      ),
      AppNotification(
        id: 'notif-004',
        type: NotificationType.plan,
        title: 'Procurement commented on an item',
        titleSecondary: 'پروکیورمنٹ نے ایک آئٹم پر تبصرہ کیا',
        body: 'Fire damper 300mm — "Sourcing externally, 2-day lead time."',
        timestamp: now.subtract(const Duration(hours: 9)),
        isRead: true,
      ),
      AppNotification(
        id: 'notif-005',
        type: NotificationType.request,
        title: 'Request received & confirmed on site',
        titleSecondary: 'درخواست موصول اور تصدیق ہو گئی',
        body: 'Green Valley Hospital — AHU Installation.',
        timestamp: now.subtract(const Duration(days: 1)),
        isRead: true,
      ),
    ];
  }
}
