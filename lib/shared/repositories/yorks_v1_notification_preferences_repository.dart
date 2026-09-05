import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_notification_preferences.dart';

abstract interface class YorksV1NotificationPreferencesRepository {
  Future<YorksV1NotificationPreferences> loadMine();

  Future<YorksV1NotificationPreferences> updateMine({
    required YorksV1NotificationPreferences desired,
    required int expectedRevision,
  });
}

class YorksV1SupabaseNotificationPreferencesRepository
    implements YorksV1NotificationPreferencesRepository {
  const YorksV1SupabaseNotificationPreferencesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<YorksV1NotificationPreferences> loadMine() async {
    final response = await _client.rpc('v1_get_my_notification_preferences');
    if (response is! Map) {
      throw const FormatException(
        'Notification preference projection was not an object',
      );
    }
    return YorksV1NotificationPreferences.fromRpcJson(
      Map<String, dynamic>.from(response),
    );
  }

  @override
  Future<YorksV1NotificationPreferences> updateMine({
    required YorksV1NotificationPreferences desired,
    required int expectedRevision,
  }) async {
    final response = await _client.rpc(
      'v1_update_my_notification_preferences',
      params: {
        'p_patch': desired.toPatch(),
        'p_expected_revision': expectedRevision,
      },
    );
    if (response is! Map) {
      throw const FormatException(
        'Updated notification preference projection was not an object',
      );
    }
    return YorksV1NotificationPreferences.fromRpcJson(
      Map<String, dynamic>.from(response),
    );
  }
}
