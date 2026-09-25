import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/analytics_event.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_material_request_repository.dart';
import 'package:material_ledger/shared/services/analytics_service.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';

void main() {
  for (final succeeds in [true, false]) {
    test('editing access telemetry follows server result: $succeeds', () async {
      final rpc = _Rpc();
      final analytics = _Analytics();
      final repository = YorksV1SupabaseMaterialRequestRepository(
        featureFlags: const YorksV1FeatureFlags.fromEnvironment(),
        connectivity: _Online(),
        rpcClient: rpc,
        analytics: analytics,
      );
      final result = repository.setPostApprovalEdit(
        requestId: 'private-request-id',
        expectedVersion: 3,
        enabled: true,
        procurementRoleEditEnabled: true,
        idempotencyKey: 'private-retry-id',
      );
      expect(analytics.events, isEmpty);
      expect(
        (rpc.parameters!['p_payload'] as Map)['procurement_role_edit_enabled'],
        isTrue,
      );
      if (succeeds) {
        rpc.pending.complete({
          'id': 'private-request-id',
          'project_id': 'private-project',
          'project_ref': 'REF',
          'project_name': 'Private name',
          'scope_id': 'scope',
          'scope_name': 'Common',
          'state': 'approved_for_arrangement',
          'record_version': 4,
          'created_at': '2026-09-25T00:00:00Z',
          'updated_at': '2026-09-25T00:00:00Z',
          'timing': 'normal',
          'post_approval_edit_enabled': true,
          'procurement_role_edit_enabled': true,
          'lines': [],
        });
        expect((await result).procurementRoleEditEnabled, isTrue);
        expect(
          analytics.events.single,
          AnalyticsEvent.materialRequestEditingAccessChanged,
        );
      } else {
        final assertion = expectLater(
          result,
          throwsA(isA<YorksV1DomainException>()),
        );
        rpc.pending.completeError(
          const YorksV1DomainException(YorksV1DomainErrorCode.conflict),
        );
        await assertion;
        expect(
          analytics.events.single,
          AnalyticsEvent.materialRequestEditingAccessFailed,
        );
        expect(
          analytics.properties.single[AnalyticsProperty.errorCategory],
          AnalyticsErrorCategory.conflict,
        );
      }
      expect(
        analytics.properties.single[AnalyticsProperty.actionType],
        'grant_procurement_role_editing',
      );
      expect(
        analytics.properties.single.toString(),
        isNot(contains('private-')),
      );
    });
  }
}

class _Rpc implements YorksV1MaterialRequestRpcClient {
  final pending = Completer<Object?>();
  Map<String, Object?>? parameters;
  @override
  Future<Object?> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) {
    this.parameters = parameters;
    return pending.future;
  }
}

class _Analytics extends NoopAnalyticsService {
  final events = <AnalyticsEvent>[];
  final properties = <AnalyticsProperties>[];
  @override
  void capture(
    AnalyticsEvent event, {
    AnalyticsProperties properties = const {},
  }) {
    events.add(event);
    this.properties.add(properties);
  }
}

class _Online implements ConnectivityService {
  @override
  bool get isOnline => true;
  @override
  Stream<bool> get onChange => const Stream.empty();
}
