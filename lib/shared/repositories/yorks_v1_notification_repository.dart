import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_notification.dart';

abstract interface class YorksV1NotificationRepository {
  Future<List<YorksV1NotificationRecord>> listMine({int limit = 100});

  Future<void> markSeen(String notificationId);

  Future<int> markAllSeen();
}

class NotificationPage {
  const NotificationPage({
    required this.records,
    required this.attention,
    required this.unreadCount,
    required this.hasMore,
    this.servicePaused,
  });
  final List<YorksV1NotificationRecord> records;
  final List<YorksV1NotificationRecord> attention;
  final int unreadCount;
  final bool hasMore;
  final bool? servicePaused;
}

abstract interface class PagedNotificationRepository {
  Future<NotificationPage> page({
    int limit = 100,
    YorksV1NotificationRecord? before,
    bool unreadOnly = false,
    bool urgentOnly = false,
    String? search,
  });
}

class YorksV1SupabaseNotificationRepository
    implements YorksV1NotificationRepository, PagedNotificationRepository {
  const YorksV1SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<YorksV1NotificationRecord>> listMine({int limit = 100}) async {
    final result = await page(limit: limit);
    return [
      ...result.records,
      ...result.attention.where((n) => n.isChatTransport),
    ];
  }

  @override
  Future<NotificationPage> page({
    int limit = 100,
    YorksV1NotificationRecord? before,
    bool unreadOnly = false,
    bool urgentOnly = false,
    String? search,
  }) async {
    final size = limit.clamp(1, 200);
    final response = await _client.rpc(
      'v1_notification_page',
      params: {
        'p_limit': size,
        'p_before_created_at': before?.createdAt.toUtc().toIso8601String(),
        'p_before_id': before?.id,
        'p_unread_only': unreadOnly,
        'p_urgent_only': urgentOnly,
        'p_search': search,
      },
    );
    if (response is! Map ||
        response['records'] is! List ||
        response['attention'] is! List ||
        response['unreadCount'] is! num) {
      throw const FormatException('Invalid notification page');
    }
    List<YorksV1NotificationRecord> decode(Object? value) => (value as List)
        .map(
          (row) => YorksV1NotificationRecord.fromRpcJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
    final records = decode(response['records']);
    return NotificationPage(
      records: records.take(size).toList(),
      attention: decode(response['attention']),
      unreadCount: (response['unreadCount'] as num).toInt(),
      hasMore: records.length > size,
      servicePaused: response['servicePaused'] as bool?,
    );
  }

  @override
  Future<void> markSeen(String notificationId) async {
    await _client.rpc(
      'v1_mark_notification_seen',
      params: {'p_notification_id': notificationId},
    );
  }

  @override
  Future<int> markAllSeen() async {
    final response = await _client.rpc('v1_mark_all_notifications_seen');
    return switch (response) {
      int value => value,
      num value => value.toInt(),
      _ => 0,
    };
  }
}
