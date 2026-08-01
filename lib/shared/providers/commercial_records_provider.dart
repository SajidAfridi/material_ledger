import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/commercial_record.dart';
import '../models/yorks_v1_commercial_capability.dart';
import 'language_provider.dart';
import 'permissions_provider.dart';
import 'session_provider.dart';
import 'yorks_v1_current_commercial_capability_provider.dart';
import 'yorks_v1_feature_flags_provider.dart';
import 'yorks_v1_identity_provider.dart';

const commercialLocalDevelopmentCacheKey =
    'commercial_records_local_development_v1';

class CommercialAccessDenied implements Exception {
  const CommercialAccessDenied();

  @override
  String toString() => 'Commercial access is not permitted for this session.';
}

final commercialRecordsProvider =
    StateNotifierProvider<
      CommercialRecordsNotifier,
      Map<String, CommercialRecord>
    >((ref) {
      final user = ref.watch(currentUserProvider);
      final client = ref.watch(supabaseClientProvider);
      final allowed = user != null && ref.watch(canViewCommercialsProvider);
      final notifier = CommercialRecordsNotifier(
        client: client,
        preferences: ref.watch(sharedPreferencesProvider),
        allowed: allowed,
        canWrite:
            user != null &&
            ref.watch(canReceiveGoodsProvider) &&
            ref.watch(canManageCommercialsProvider),
        actorAppUserId: user?.id,
      );

      final usesV1CommercialAuthority =
          ref.watch(yorksV1FeatureFlagsProvider).foundation &&
          client != null &&
          ref.watch(yorksV1CurrentRoleProvider) != null;
      if (usesV1CommercialAuthority) {
        // Rebuilding this provider is not enough: long-lived legacy providers
        // may retain this notifier reference. Purge this exact object as soon
        // as a capability/profile signal makes the current session denied or
        // unknown, before an authorized refresh could expose stale costs.
        ref.listen<AsyncValue<YorksV1CommercialCapabilities?>>(
          yorksV1CurrentCommercialCapabilitiesProvider,
          (_, next) {
            final stillAllowed =
                next
                    .valueOrNull?[YorksV1CommercialCapability.viewCommercials]
                    .effective ??
                false;
            if (!stillAllowed) {
              unawaited(notifier.purgeProtectedState());
            }
          },
          fireImmediately: true,
        );
      }
      return notifier;
    });

class CommercialRecordsNotifier
    extends StateNotifier<Map<String, CommercialRecord>> {
  CommercialRecordsNotifier({
    required SupabaseClient? client,
    required SharedPreferences preferences,
    required bool allowed,
    required bool canWrite,
    required String? actorAppUserId,
  }) : _client = client,
       _preferences = preferences,
       _allowed = allowed,
       _canWrite = allowed && canWrite,
       _actorAppUserId = actorAppUserId,
       super(_loadLocal(client, preferences, allowed)) {
    if (!_allowed) {
      // A denied session must not inherit protected data left by an authorised
      // local-development session on the same device.
      unawaited(_preferences.remove(commercialLocalDevelopmentCacheKey));
    } else if (_client != null) {
      // Connected mode never persists commercial records locally. Supabase RLS
      // is the authority and a failed refresh remains fail-closed.
      state = const {};
      unawaited(refresh());
    }
  }

  final SupabaseClient? _client;
  final SharedPreferences _preferences;
  final bool _allowed;
  final bool _canWrite;
  final String? _actorAppUserId;

  bool get isAllowed => _allowed;

  static Map<String, CommercialRecord> _loadLocal(
    SupabaseClient? client,
    SharedPreferences preferences,
    bool allowed,
  ) {
    if (!allowed || client != null) return const {};
    final raw = preferences.getString(commercialLocalDevelopmentCacheKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final records = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map(
            (item) =>
                CommercialRecord.fromLocalJson(Map<String, dynamic>.from(item)),
          )
          .where((record) => record.subjectId.isNotEmpty);
      return {for (final record in records) record.key: record};
    } catch (_) {
      return const {};
    }
  }

  Future<void> refresh() async {
    final client = _client;
    if (!_allowed || client == null) {
      state = const {};
      return;
    }
    try {
      final rows = await client
          .from('commercial_records')
          .select(
            'subject_type, subject_id, unit_cost_aed, total_cost_aed, '
            'currency_code, updated_at, updated_by_app_user_id',
          );
      final records = rows
          .map(
            (row) => CommercialRecord.fromDatabaseJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .where((record) => record.subjectId.isNotEmpty);
      state = {for (final record in records) record.key: record};
    } catch (_) {
      state = const {};
    }
  }

  /// Removes every protected projection held by this notifier and the
  /// local-development cache. This is intentionally callable by the V1
  /// current-session capability listener even when another provider retained a
  /// reference to this notifier before a server-side revocation.
  Future<void> purgeProtectedState() async {
    if (mounted) state = const {};
    await _preferences.remove(commercialLocalDevelopmentCacheKey);
  }

  CommercialRecord? record(
    CommercialSubjectType subjectType,
    String subjectId,
  ) => state['${subjectType.databaseValue}:$subjectId'];

  double materialUnitCost(String materialId) =>
      record(CommercialSubjectType.material, materialId)?.unitCostAED ?? 0;

  double projectTotalCost(String projectId) =>
      record(CommercialSubjectType.project, projectId)?.totalCostAED ?? 0;

  /// Imports old local values only in explicit local-development mode.
  /// Connected environments use the server migration and RLS-protected table.
  Future<void> importLegacyForLocalDevelopment(
    Iterable<CommercialRecord> records,
  ) async {
    if (!_allowed || _client != null) return;
    // Constructors for operational providers call this migration while they
    // are being built. Yield first so changing this provider never mutates
    // another Riverpod provider during its initialization.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final next = {...state};
    var changed = false;
    for (final record in records) {
      if (record.subjectId.isEmpty ||
          (record.unitCostAED ?? record.totalCostAED ?? 0) <= 0 ||
          next.containsKey(record.key)) {
        continue;
      }
      next[record.key] = record;
      changed = true;
    }
    if (!changed) return;
    state = next;
    await _persistLocal();
  }

  Future<void> setMaterialUnitCost(String materialId, double unitCostAED) {
    return _upsert(
      CommercialRecord(
        subjectType: CommercialSubjectType.material,
        subjectId: materialId,
        unitCostAED: _validMoney(unitCostAED),
        updatedAt: DateTime.now().toUtc(),
        updatedByAppUserId: _actorAppUserId,
      ),
    );
  }

  Future<void> setGoodsReceiptCosts({
    required String receiptId,
    required double unitCostAED,
    required double quantity,
  }) {
    final unitCost = _validMoney(unitCostAED);
    return _upsert(
      CommercialRecord(
        subjectType: CommercialSubjectType.goodsReceipt,
        subjectId: receiptId,
        unitCostAED: unitCost,
        totalCostAED: _validMoney(unitCost * quantity),
        updatedAt: DateTime.now().toUtc(),
        updatedByAppUserId: _actorAppUserId,
      ),
    );
  }

  Future<void> setProjectTotalCost(String projectId, double totalCostAED) {
    return _upsert(
      CommercialRecord(
        subjectType: CommercialSubjectType.project,
        subjectId: projectId,
        totalCostAED: _validMoney(totalCostAED),
        updatedAt: DateTime.now().toUtc(),
        updatedByAppUserId: _actorAppUserId,
      ),
    );
  }

  Future<void> _upsert(CommercialRecord record) async {
    if (!_canWrite) throw const CommercialAccessDenied();
    final client = _client;
    if (client != null) {
      await client
          .from('commercial_records')
          .upsert(
            record.toDatabaseJson(),
            onConflict: 'subject_type,subject_id',
          );
    }
    state = {...state, record.key: record};
    if (client == null) await _persistLocal();
  }

  Future<void> _persistLocal() {
    return _preferences.setString(
      commercialLocalDevelopmentCacheKey,
      jsonEncode(state.values.map((record) => record.toLocalJson()).toList()),
    );
  }

  static double _validMoney(double value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
        value,
        'value',
        'Must be finite and non-negative',
      );
    }
    return value;
  }
}
