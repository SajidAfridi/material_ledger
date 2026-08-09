import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_notification.dart';

abstract interface class YorksV1NotificationRepository {
  Future<List<YorksV1NotificationRecord>> listMine({int limit = 100});

  Future<void> markSeen(String notificationId);
}

class YorksV1SupabaseNotificationRepository
    implements YorksV1NotificationRepository {
  const YorksV1SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<YorksV1NotificationRecord>> listMine({int limit = 100}) async {
    final response = await _client.rpc(
      'v1_list_my_notifications',
      params: {'p_limit': limit},
    );
    if (response is! List) return const [];
    return response
        .whereType<Map>()
        .map(
          (row) => YorksV1NotificationRecord.fromRpcJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> markSeen(String notificationId) async {
    await _client.rpc(
      'v1_mark_notification_seen',
      params: {'p_notification_id': notificationId},
    );
  }
}
