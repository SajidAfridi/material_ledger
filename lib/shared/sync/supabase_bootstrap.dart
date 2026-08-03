import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One-time launch sync between the local stores and Supabase.
///
/// For each write-synced collection: if the cloud table already has rows, the
/// local store is hydrated from it (so every device shows the same data on
/// launch/relaunch); if the cloud is empty but this device holds seeded local
/// data, that seed is pushed up. Ongoing writes during the session flow through
/// the outbox → [SupabaseSyncBackend] as usual, so the two stay in step.
///
/// Only the collections whose writes already go through the sync seam are
/// mapped — reads and writes stay symmetric. (Users/inventory-catalog identity
/// are handled by their own dedicated flows — Supabase Auth + the admin-users
/// Edge Function, and the materials seed respectively — not this bootstrap.)
class SupabaseBootstrap {
  SupabaseBootstrap(this._client, this._prefs);

  final SupabaseClient _client;
  final SharedPreferences _prefs;

  /// Supabase table name → local SharedPreferences key.
  static const _map = <String, String>{
    'projects': 'projects_list_v1',
    'materialPlans': 'material_plans_list_v2',
    'materialRequests': 'material_requests_list_v3',
    'materials': 'materials_list_v3',
    'materialCategories': 'material_categories_v1',
    'materialUnits': 'material_units_v1',
    'stockMovements': 'stock_movements_v2',
    'notifications': 'notifications_list_v3',
    'rentalUnits': 'rental_units_v2',
    'rentPayments': 'rent_payments_v2',
    'goodsReceipts': 'goods_receipts_v2',
    'returns': 'material_returns_list_v2',
    // Employee records are administered through the protected People/HR
    // boundary.  Do not seed the legacy snapshot table at app launch: project
    // engineers are intentionally denied that write by RLS, and attempting it
    // created a noisy 403 alongside otherwise unrelated R35 workflows.
    'attendance': 'attendance_v2',
    'leaveRecords': 'leave_records_v2',
  };

  /// Runs all collections in PARALLEL under one short overall cap, so an
  /// unreachable cloud (offline) delays launch by at most a few seconds and the
  /// app falls back to local data — never a multi-minute hang. Each collection
  /// swallows its own errors so one failure can't abort the rest.
  Future<void> run() async {
    try {
      await Future.wait(
        _map.entries.map((e) => _syncOne(e.key, e.value)),
      ).timeout(const Duration(seconds: 6));
    } on TimeoutException {
      // Offline / slow → proceed with whatever hydrated in time + local data.
    }
  }

  Future<void> _syncOne(String table, String key) async {
    try {
      await _syncOneInner(table, key);
    } catch (_) {
      // Best-effort per collection.
    }
  }

  /// Fields that are held back from a collection's shared cloud payload for
  /// privacy and must be preserved from the local record on hydration (they'll
  /// never be present in the cloud row). Salary/basic-wage are admin-device-local.
  static const _preserveLocalKeys = <String, List<String>>{
    'employees': ['salaryAED', 'basicWageAED'],
    // Reservation state is derived per device and is not a commercial value.
    'materials': ['reservedQty'],
  };

  static const _commercialKeys = {
    'unitPrice',
    'unitCost',
    'unitCostAED',
    'unit_cost',
    'unit_cost_aed',
    'totalCost',
    'totalCostAED',
    'total_cost',
    'total_cost_aed',
    'contractValueAED',
  };

  Future<void> _syncOneInner(String table, String key) async {
    final rows = await _client.from(table).select('id, data');
    if (rows.isNotEmpty) {
      // Merge cloud into local rather than overwrite: cloud wins on a shared id,
      // but a local-only row (e.g. an offline create not yet pushed) is kept, so
      // launch / re-login hydration can never drop unsynced local data.
      final safeRows = [
        for (final rawRow in rows)
          {
            ...rawRow,
            'data': sanitizeForCloud(
              table,
              Map<String, dynamic>.from(rawRow['data'] as Map),
            ),
          },
      ];
      final merged = mergeRows(
        _prefs.getString(key),
        safeRows,
        preserveLocalKeys: _preserveLocalKeys[table] ?? const [],
      );
      await _prefs.setString(key, jsonEncode(merged));
      return;
    }
    // Cloud empty → push this device's seeded data up (first-run seeding).
    final local = _prefs.getString(key);
    if (local == null || local.isEmpty) return;
    final list = (jsonDecode(local) as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = [
      for (final m in list)
        {'id': m['id'], 'data': sanitizeForCloud(table, m), 'updated_at': now},
    ];
    await _client.from(table).upsert(payload, onConflict: 'id');
  }

  /// Removes local-only or commercially restricted fields before any
  /// first-device seed is uploaded. This closes the path that bypassed normal
  /// provider-level payload sanitization when a cloud table was empty.
  static Map<String, dynamic> sanitizeForCloud(
    String table,
    Map<String, dynamic> data,
  ) {
    final sanitized = _stripCommercialValues(data) as Map<String, dynamic>;
    for (final key in _preserveLocalKeys[table] ?? const <String>[]) {
      sanitized.remove(key);
    }
    return sanitized;
  }

  static Object? _stripCommercialValues(Object? value) {
    if (value is List) {
      return [for (final item in value) _stripCommercialValues(item)];
    }
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          if (!_commercialKeys.contains(entry.key.toString()))
            entry.key.toString(): _stripCommercialValues(entry.value),
      };
    }
    return value;
  }

  /// Pure union-merge of cloud rows into the local store (extracted for testing).
  /// [localRaw] is the stored JSON list of model snapshots (or null); [cloudRows]
  /// are the `{id, data}` rows from Supabase. Cloud wins on a shared id; rows that
  /// exist only locally (an unsynced offline create) are preserved. Any
  /// [preserveLocalKeys] the cloud row omits (privacy-held fields like salary)
  /// are copied back from the matching local record so hydration can't wipe them.
  static List<Map<String, dynamic>> mergeRows(
    String? localRaw,
    List<dynamic> cloudRows, {
    List<String> preserveLocalKeys = const [],
  }) {
    final localById = <String, Map<String, dynamic>>{};
    if (localRaw != null && localRaw.isNotEmpty) {
      for (final m
          in (jsonDecode(localRaw) as List).cast<Map<String, dynamic>>()) {
        final id = m['id'];
        if (id is String) localById[id] = m;
      }
    }
    final merged = <String, Map<String, dynamic>>{...localById};
    for (final r in cloudRows) {
      final row = (r as Map).cast<String, dynamic>();
      final data = (row['data'] as Map).cast<String, dynamic>();
      final id = (data['id'] ?? row['id']) as String;
      final localRow = localById[id];
      if (localRow != null) {
        for (final k in preserveLocalKeys) {
          if (!data.containsKey(k) && localRow.containsKey(k)) {
            data[k] = localRow[k];
          }
        }
      }
      merged[id] = data;
    }
    return merged.values.toList();
  }
}
