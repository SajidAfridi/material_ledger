import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import 'language_provider.dart';

const _kNotificationsKey = 'notifications_list_v1';

// ─── Filter Enum ─────────────────────────────────────────────────

enum NotificationFilter { all, unread, urgent, last24h }

// ─── Providers ───────────────────────────────────────────────────

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotification>>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return NotificationsNotifier(prefs);
    });

/// Active filter tab.
final notificationFilterProvider = StateProvider<NotificationFilter>(
  (ref) => NotificationFilter.all,
);

/// Search query string.
final notificationSearchProvider = StateProvider<String>((ref) => '');

/// Count of unread notifications.
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).where((n) => !n.isRead).length;
});

/// Count of urgent notifications.
final urgentNotificationCountProvider = Provider<int>((ref) {
  return ref
      .watch(notificationsProvider)
      .where((n) => n.isUrgent && !n.isRead)
      .length;
});

/// Filtered + searched notifications for the current tab.
final filteredNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final all = ref.watch(notificationsProvider);
  final filter = ref.watch(notificationFilterProvider);
  final query = ref.watch(notificationSearchProvider).toLowerCase().trim();

  final now = DateTime.now();

  List<AppNotification> result = all;

  // Apply tab filter
  result = switch (filter) {
    NotificationFilter.all => result,
    NotificationFilter.unread => result.where((n) => !n.isRead).toList(),
    NotificationFilter.urgent => result.where((n) => n.isUrgent).toList(),
    NotificationFilter.last24h =>
      result.where((n) => now.difference(n.timestamp).inHours < 24).toList(),
  };

  // Apply search filter
  if (query.isNotEmpty) {
    result = result
        .where(
          (n) =>
              n.title.toLowerCase().contains(query) ||
              n.titleSecondary.toLowerCase().contains(query) ||
              (n.project?.toLowerCase().contains(query) ?? false) ||
              (n.chipLabel?.toLowerCase().contains(query) ?? false),
        )
        .toList();
  }

  return result;
});

// ─── Notifier ─────────────────────────────────────────────────────

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  NotificationsNotifier(this._prefs) : super(_load(_prefs));

  final dynamic _prefs;

  static List<AppNotification> _load(dynamic prefs) {
    final json = prefs.getString(_kNotificationsKey);
    if (json == null || json.isEmpty) return _seedNotifications;
    return AppNotification.decodeList(json);
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _kNotificationsKey,
      AppNotification.encodeList(state),
    );
  }

  /// Mark a single notification as read.
  Future<void> markRead(String id) async {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
    await _persist();
  }

  /// Mark all notifications as read.
  Future<void> markAllRead() async {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
    await _persist();
  }

  /// Remove a notification.
  Future<void> dismiss(String id) async {
    state = state.where((n) => n.id != id).toList();
    await _persist();
  }
}

// ─── Seed Data ────────────────────────────────────────────────────

final _seedNotifications = [
  // ─── Recent / Unread (within last hour) ──────────────────────
  AppNotification(
    id: 'notif-001',
    type: NotificationType.approved,
    chipLabel: 'APPROVAL REQUIRED',
    title: 'Purchase Order #9921 Pending Authorization',
    titleSecondary: 'پرچیز آرڈر نمبر 9921 کی منظوری زیر التوا ہے',
    body:
        'A new purchase order for Ball Valve 1" (SS 304) has been submitted '
        'and is awaiting warehouse authorization.',
    project: 'Al-Fajr Tower B',
    projectSecondary: 'پروجیکٹ: الفجر ٹاور بی',
    initiatorName: 'Haris Khan',
    initiatorRole: 'Procurement Lead',
    initiatorAction: 'initiated this request.',
    initiatorActionSecondary:
        'حارث خان (پروکیورمنٹ لیڈ) نے اس درخواست کا آغاز کیا ہے',
    timestamp: DateTime.now().subtract(const Duration(minutes: 14)),
    isRead: false,
    isUrgent: false,
  ),
  AppNotification(
    id: 'notif-002',
    type: NotificationType.lowStock,
    chipLabel: 'CRITICAL STOCK ALERT',
    title: 'Cement Grade A inventory below threshold (12 bags left)',
    titleSecondary: 'سیمنٹ گریڈ اے کا اسٹاک حد سے کم ہے (صرف 12 بیگ باقی ہیں)',
    body:
        'Current stock for Cement Grade A has fallen below the safety threshold. '
        'Immediate replenishment is required to avoid site stoppage.',
    project: 'Indus Housing Phase II',
    projectSecondary: 'پروجیکٹ: انڈس ہاؤسنگ فیز II',
    initiatorName: null,
    initiatorRole: null,
    initiatorAction:
        'System generated alert based on nightly audit at Site 04.',
    initiatorActionSecondary:
        'سائٹ 04 پر رات کی آڈٹ کی بنیاد پر سسٹم کا خودکار الرٹ',
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    isRead: false,
    isUrgent: true,
  ),
  AppNotification(
    id: 'notif-003',
    type: NotificationType.dispatched,
    chipLabel: 'LOGISTICS UPDATE',
    title: 'Steel Reinforcement Delivery scheduled for tomorrow 08:00 AM',
    titleSecondary: 'اسٹیل کی ترسیل کل صبح 08:00 بجے شیڈول ہے',
    body:
        'Truck #KT-9928 has been scheduled to deliver GI pipes and structural '
        'steel to the main site entrance tomorrow morning.',
    project: 'Grand Mosque Renovation',
    projectSecondary: 'پروجیکٹ: گرینڈ مسجد کی تزئین و آرائش',
    initiatorName: 'Zia Ahmed',
    initiatorRole: 'Fleet Manager',
    initiatorAction: 'updated the manifest.',
    initiatorActionSecondary:
        'ضیاء احمد (فلیٹ مینیجر) نے مینی فیسٹ اپ ڈیٹ کر دیا ہے',
    timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    isRead: false,
    isUrgent: false,
  ),

  // ─── Weekly Summary Banner ────────────────────────────────────
  AppNotification(
    id: 'notif-banner',
    type: NotificationType.weeklySummary,
    title: 'Weekly Summary',
    titleSecondary: 'ہفتہ وار خلاصہ',
    body: '',
    isBanner: true,
    bannerLabel: 'NOTIFICATION HEALTH',
    bannerHeadline: 'Response rate is up by 12% today',
    timestamp: DateTime.now().subtract(const Duration(hours: 6)),
    isRead: false,
    isUrgent: false,
  ),

  // ─── Read Notifications ───────────────────────────────────────
  AppNotification(
    id: 'notif-004',
    type: NotificationType.approved,
    chipLabel: 'REQUEST APPROVED',
    title: 'Requisition REQ-012 Approved',
    titleSecondary: 'ریکوزیشن REQ-012 منظور ہو گئی',
    body:
        'Gate Valve 2" (Cast Iron) and copper fittings for Al-Burj Tower HVAC '
        'fit-out are now available for pickup at the main godown.',
    project: 'Al-Burj Tower',
    projectSecondary: 'پروجیکٹ: البرج ٹاور',
    initiatorName: 'Omar Farooq',
    initiatorRole: 'Store Supervisor',
    initiatorAction: 'approved and released stock.',
    initiatorActionSecondary: 'عمر فاروق (اسٹور سپروائزر) نے منظوری دے دی ہے',
    timestamp: DateTime.now().subtract(const Duration(hours: 8)),
    isRead: true,
    isUrgent: false,
  ),
  AppNotification(
    id: 'notif-005',
    type: NotificationType.lowStock,
    chipLabel: 'LOW STOCK WARNING',
    title: 'Low Stock: Copper Pipe 3/4" (only 120 ft remaining)',
    titleSecondary: 'کم اسٹاک: تانبے کا پائپ 3/4" (صرف 120 فٹ باقی)',
    body:
        'Copper Pipe 3/4" stock has dropped to 120 feet against a minimum '
        'threshold of 200 feet. Please raise a replenishment request.',
    project: 'Green Valley Hospital',
    projectSecondary: 'پروجیکٹ: گرین ویلی ہسپتال',
    initiatorName: null,
    initiatorRole: null,
    initiatorAction: 'Automated inventory check triggered this alert.',
    initiatorActionSecondary: 'خودکار انوینٹری جانچ نے یہ الرٹ دیا ہے',
    timestamp: DateTime.now().subtract(const Duration(hours: 10)),
    isRead: true,
    isUrgent: true,
  ),
  AppNotification(
    id: 'notif-006',
    type: NotificationType.message,
    chipLabel: 'MESSAGE',
    title: 'New Message from Store Supervisor',
    titleSecondary: 'اسٹور سپروائزر کا نیا پیغام',
    body:
        '"Please verify the Gate Valve delivery count for Plant Room by '
        'end of day. The last batch had a quantity mismatch."',
    project: null,
    projectSecondary: null,
    initiatorName: 'Omar Farooq',
    initiatorRole: 'Store Supervisor',
    initiatorAction: 'sent you a message.',
    initiatorActionSecondary:
        'عمر فاروق (اسٹور سپروائزر) نے آپ کو پیغام بھیجا ہے',
    timestamp: DateTime.now().subtract(const Duration(hours: 14)),
    actionLabel: 'Reply Now',
    isRead: true,
    isUrgent: false,
  ),
  AppNotification(
    id: 'notif-007',
    type: NotificationType.rejected,
    chipLabel: 'REQUEST REJECTED',
    title: 'Requisition REQ-007 Rejected — Quantities Exceed Allocation',
    titleSecondary: 'ریکوزیشن REQ-007 مسترد — مقدار مختص سے زیادہ ہے',
    body:
        'Quantities for thermostats and contactors exceed the project '
        'budget allocation. Please resubmit with revised counts.',
    project: 'Marina Towers HVAC',
    projectSecondary: 'پروجیکٹ: مرینا ٹاورز ایچ وی اے سی',
    initiatorName: 'Asad Ullah',
    initiatorRole: 'Project Manager',
    initiatorAction: 'rejected this requisition.',
    initiatorActionSecondary:
        'اسد اللہ (پروجیکٹ مینیجر) نے ریکوزیشن مسترد کر دی',
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
    isRead: true,
    isUrgent: false,
  ),
  AppNotification(
    id: 'notif-008',
    type: NotificationType.dispatched,
    chipLabel: 'DELIVERY CONFIRMED',
    title: 'PVC Pipes Batch Delivered — Site 07',
    titleSecondary: 'پی وی سی پائپ سائٹ 07 پر پہنچا دیے گئے',
    body:
        'Batch of 4" PVC pipes (200 units) has been successfully received '
        'and signed off at Site 07 by the site engineer.',
    project: 'Indus Housing Phase II',
    projectSecondary: 'پروجیکٹ: انڈس ہاؤسنگ فیز II',
    initiatorName: 'Khalid Mehmood',
    initiatorRole: 'Site Engineer',
    initiatorAction: 'confirmed receipt.',
    initiatorActionSecondary: 'خالد محمود (سائٹ انجینئر) نے وصول کی تصدیق کی',
    timestamp: DateTime.now().subtract(const Duration(days: 2)),
    isRead: true,
    isUrgent: false,
  ),
];
