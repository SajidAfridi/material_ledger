import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/goods_receipt_provider.dart';
import '../providers/hr_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/language_provider.dart';
import '../providers/material_request_provider.dart';
import '../providers/material_return_provider.dart';
import '../providers/rentals_provider.dart';
import '../providers/stock_movement_provider.dart';

/// One write-synced collection: its Supabase table, the local store key that
/// backs its provider, and the provider to refresh when a realtime change lands.
class _Synced {
  const _Synced(this.table, this.storeKey, this.provider,
      [this.preserveKeys = const []]);
  final String table;
  final String storeKey;
  final ProviderOrFamily provider;

  /// Privacy-held fields the cloud row never carries (e.g. salary), preserved
  /// from the existing local record so a realtime merge can't wipe them.
  final List<String> preserveKeys;
}

/// The collections mirrored live. Table ↔ store-key must match SupabaseBootstrap.
List<_Synced> _synced() => [
  _Synced('materialRequests', 'material_requests_list_v2', materialRequestsProvider),
  _Synced('materials', 'materials_list_v3', materialsProvider, ['reservedQty']),
  _Synced('stockMovements', 'stock_movements_v1', stockMovementsProvider),
  _Synced('goodsReceipts', 'goods_receipts_v1', goodsReceiptsProvider),
  _Synced('returns', 'material_returns_list_v1', returnsProvider),
  _Synced('rentalUnits', 'rental_units_v1', rentalUnitsProvider),
  _Synced('rentPayments', 'rent_payments_v1', rentPaymentsProvider),
  _Synced('employees', 'employees_v2', employeesProvider, ['salaryAED']),
  _Synced('attendance', 'attendance_v1', attendanceProvider),
  _Synced('leaveRecords', 'leave_records_v1', leaveRecordsProvider),
];

/// Live sync: subscribes to Postgres changes on each synced table and applies
/// them to the local store, so a write on another device shows up here without a
/// relaunch. RLS is enforced by the realtime server against the subscriber's JWT
/// — an engineer only receives changes to rows they're allowed to see.
///
/// Runs only while signed in against a Supabase backend (see
/// [realtimeSyncProvider]); it's a best-effort overlay on top of the launch /
/// post-login hydration + the write-through outbox, never a replacement.
class RealtimeSync {
  RealtimeSync(this._client, this._ref);

  final SupabaseClient _client;
  final Ref _ref;
  final List<RealtimeChannel> _channels = [];
  StreamSubscription<AuthState>? _authSub;
  bool _stopped = false;

  Future<void> start() async {
    final prefs = _ref.read(sharedPreferencesProvider);

    // RLS is evaluated against the socket's JWT — without this the realtime
    // server treats the connection as anonymous and (under strict RLS) delivers
    // nothing. Set the current token first, and re-set it whenever it refreshes.
    final token = _client.auth.currentSession?.accessToken;
    if (token != null) await _client.realtime.setAuth(token);
    _authSub = _client.auth.onAuthStateChange.listen((s) {
      final t = s.session?.accessToken;
      if (t != null) _client.realtime.setAuth(t);
    });
    if (_stopped) return; // logged out again while awaiting setAuth

    for (final c in _synced()) {
      final channel = _client
          .channel('sync:${c.table}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: c.table,
            callback: (payload) => _apply(prefs, c, payload),
          )
          .subscribe();
      _channels.add(channel);
    }
  }

  Future<void> stop() async {
    _stopped = true;
    await _authSub?.cancel();
    for (final channel in _channels) {
      await _client.removeChannel(channel);
    }
    _channels.clear();
  }

  /// Apply one change to the local store, then rebuild the collection's provider
  /// so listeners refresh. Fully synchronous through the store write (the plugin
  /// updates its in-memory cache immediately) so back-to-back events for the same
  /// collection can't interleave. Any malformed payload is swallowed.
  void _apply(SharedPreferences prefs, _Synced c, PostgresChangePayload payload) {
    try {
      final raw = prefs.getString(c.storeKey);
      final list = (raw == null || raw.isEmpty)
          ? <Map<String, dynamic>>[]
          : (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

      if (payload.eventType == PostgresChangeEvent.delete) {
        final id = payload.oldRecord['id'];
        if (id == null) return; // delete with no PK (RLS-limited) — ignore
        list.removeWhere((m) => m['id'] == id);
      } else {
        // insert / update: the row is {id, data, updated_at}; data is the model.
        final data = payload.newRecord['data'];
        if (data is! Map) return;
        final model = Map<String, dynamic>.from(data);
        final id = model['id'] ?? payload.newRecord['id'];
        // Preserve privacy-held local-only fields (e.g. salary) the cloud row
        // omits, so a realtime echo can't erase them from this device.
        if (c.preserveKeys.isNotEmpty) {
          for (final m in list) {
            if (m['id'] == id) {
              for (final k in c.preserveKeys) {
                if (!model.containsKey(k) && m.containsKey(k)) model[k] = m[k];
              }
              break;
            }
          }
        }
        list.removeWhere((m) => m['id'] == id);
        list.insert(0, model);
      }

      prefs.setString(c.storeKey, jsonEncode(list));
      _ref.invalidate(c.provider);
    } catch (_) {
      // Best-effort — a bad event never breaks the running app.
    }
  }
}

/// Keeps live sync running exactly while a user is signed in against Supabase.
/// Watched once at the app root; it (re)subscribes on login and tears down on
/// logout (or when there's no backend / no session). No-op in tests.
final realtimeSyncProvider = Provider<void>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId = ref.watch(authSessionProvider);
  if (client == null || userId == null) return;
  final sync = RealtimeSync(client, ref);
  unawaited(sync.start());
  ref.onDispose(sync.stop);
});
