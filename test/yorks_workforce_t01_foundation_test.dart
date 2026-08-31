import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/workforce/data/workforce_repository.dart';
import 'package:material_ledger/features/workforce/domain/workforce_foundation_models.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_permission_management.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('client recognizes exactly the twelve Workforce capability keys', () {
    expect(YorksV1CapabilityKeys.workforce, {
      'workforce.view',
      'workforce.attendance.maintain',
      'workforce.timesheets.maintain',
      'workforce.timesheets.review',
      'workforce.timesheets.correct_during_review',
      'workforce.timesheets.verify',
      'workforce.timesheets.final_approve',
      'workforce.periods.reopen',
      'workforce.reports.export',
      'workforce.workers.manage',
      'workforce.teams.manage',
      'workforce.configuration.manage',
    });
    expect(
      YorksV1CapabilityKeys.workforce.every(
        YorksV1CapabilityKeys.isValidWireKey,
      ),
      isTrue,
    );
  });

  test('foundation parses a worker without an Auth identity', () async {
    final rpc = _RpcClient((functionName, parameters) {
      expect(functionName, 'v1_get_workforce_foundation');
      expect(parameters, {
        'p_query': 'duct',
        'p_status': 'active',
        'p_limit': 25,
        'p_offset': 0,
        'p_on_date': '2026-08-30',
      });
      return _foundationResponse();
    });

    final projection = await _repository(rpc: rpc).getFoundation(
      query: ' duct ',
      status: YorksWorkforceWorkerStatus.active,
      limit: 25,
      onDate: '2026-08-30',
    );

    expect(projection.authorizationMode, 'admin_legacy_t01');
    expect(projection.workers.single.number, 'W-001');
    expect(projection.workers.single.linkedAuthUserId, isNull);
    expect(
      projection.workers.single.effectiveAssignment?.projectRef,
      'YRA-313',
    );
  });

  test('malformed server shape fails closed', () async {
    final response = _foundationResponse()..['schema_version'] = 2;
    final repository = _repository(rpc: _RpcClient((_, _) => response));

    await expectLater(
      repository.getFoundation(),
      throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
    );
  });

  test('feature flag fails closed before RPC', () async {
    final rpc = _RpcClient((_, _) => throw StateError('must not call'));
    final repository = _repository(
      rpc: rpc,
      featureFlags: const YorksV1FeatureFlags(
        foundation: true,
        projects: true,
        boq: true,
        excel: true,
        requests: true,
        arrangement: true,
        logistics: true,
        returnsDocuments: true,
        documents: true,
      ),
    );

    await expectLater(
      repository.getFoundation(),
      throwsA(_domainCode(YorksV1DomainErrorCode.featureDisabled)),
    );
    expect(rpc.calls, isEmpty);
  });

  test('offline state fails before RPC', () async {
    final rpc = _RpcClient((_, _) => throw StateError('must not call'));
    final repository = _repository(
      rpc: rpc,
      connectivity: _Connectivity(false),
    );

    await expectLater(
      repository.getFoundation(),
      throwsA(_domainCode(YorksV1DomainErrorCode.offline)),
    );
    expect(rpc.calls, isEmpty);
  });

  test('save worker sends optimistic version and idempotency key', () async {
    final rpc = _RpcClient((functionName, parameters) {
      expect(functionName, 'v1_save_workforce_worker');
      expect(parameters, {
        'p_payload': {'worker_number': 'W-002'},
        'p_expected_version': null,
        'p_idempotency_key': 'key-1',
      });
      return {
        'schema_version': 1,
        'worker_id': 'worker-2',
        'record_version': 1,
      };
    });

    final result = await _repository(
      rpc: rpc,
    ).saveWorker(const {'worker_number': 'W-002'}, idempotencyKey: ' key-1 ');

    expect(result.entityId, 'worker-2');
    expect(result.recordVersion, 1);
  });

  test('denied and stale server failures are mapped', () async {
    final denied = _repository(
      rpc: _ThrowingRpcClient(
        const PostgrestException(
          message: 'V1_WORKFORCE_ADMIN_REQUIRED',
          code: '42501',
        ),
      ),
    );
    await expectLater(
      denied.getFoundation(),
      throwsA(_domainCode(YorksV1DomainErrorCode.unauthorized)),
    );

    final stale = _repository(
      rpc: _ThrowingRpcClient(
        const PostgrestException(
          message: 'V1_WORKFORCE_WORKER_STALE_VERSION',
          code: '40001',
        ),
      ),
    );
    await expectLater(
      stale.saveWorker(
        const {'worker_number': 'W-002'},
        expectedVersion: 1,
        idempotencyKey: 'key-2',
      ),
      throwsA(_domainCode(YorksV1DomainErrorCode.conflict)),
    );
  });
}

YorksSupabaseWorkforceRepository _repository({
  required YorksWorkforceRpcClient rpc,
  YorksV1FeatureFlags featureFlags = const YorksV1FeatureFlags(
    foundation: true,
    projects: true,
    boq: true,
    excel: true,
    requests: true,
    arrangement: true,
    logistics: true,
    returnsDocuments: true,
    documents: true,
    workforce: true,
  ),
  ConnectivityService connectivity = const _Connectivity(true),
}) => YorksSupabaseWorkforceRepository(
  featureFlags: featureFlags,
  connectivity: connectivity,
  rpcClient: rpc,
);

Matcher _domainCode(YorksV1DomainErrorCode code) =>
    isA<YorksV1DomainException>().having((error) => error.code, 'code', code);

Map<String, dynamic> _foundationResponse() => {
  'schema_version': 1,
  'authorization_mode': 'admin_legacy_t01',
  'actor_auth_user_id': 'admin-1',
  'on_date': '2026-08-30',
  'server_time': '2026-08-30T12:00:00Z',
  'trades': [
    {
      'trade_id': 'trade-1',
      'trade_code': 'DUCT',
      'trade_name': 'Ductman',
      'description': null,
      'is_active': true,
      'record_version': 1,
    },
  ],
  'teams': [
    {
      'team_id': 'team-1',
      'team_code': 'T-01',
      'team_name': 'Duct Team',
      'department': 'Projects',
      'default_supervisor_auth_user_id': 'supervisor-1',
      'default_project_id': 'project-1',
      'default_project_scope_id': 'scope-1',
      'default_internal_location_id': null,
      'valid_from': '2026-01-01',
      'valid_to': null,
      'is_active': true,
      'record_version': 1,
    },
  ],
  'internal_locations': <Object?>[],
  'workers': [
    {
      'worker_id': 'worker-1',
      'worker_number': 'W-001',
      'full_name': 'Ahmed Khan',
      'preferred_display_name': null,
      'designation': 'Ductman',
      'trade_id': 'trade-1',
      'trade_name': 'Ductman',
      'department': 'Projects',
      'employer_company': 'Yorks AC & Ref.',
      'worker_type': 'yorks_employee',
      'mobile_number': null,
      'joining_date': '2026-01-01',
      'leaving_date': null,
      'current_status': 'active',
      'linked_auth_user_id': null,
      'notes': null,
      'record_version': 1,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
      'effective_assignment': {
        'assignment_id': 'assignment-1',
        'assignment_kind': 'primary',
        'team_id': 'team-1',
        'team_name': 'Duct Team',
        'supervisor_auth_user_id': 'supervisor-1',
        'supervisor_name': 'Site Supervisor',
        'project_id': 'project-1',
        'project_ref': 'YRA-313',
        'project_name': 'Substation',
        'project_scope_id': 'scope-1',
        'project_scope_name': 'Common / All Buildings',
        'internal_location_id': null,
        'internal_location_name': null,
        'valid_from': '2026-01-01',
        'valid_to': null,
        'record_version': 1,
      },
    },
  ],
  'worker_count': 1,
};

final class _RpcClient implements YorksWorkforceRpcClient {
  _RpcClient(this.handler);

  final Map<String, dynamic> Function(
    String functionName,
    Map<String, Object?> parameters,
  )
  handler;
  final List<String> calls = [];

  @override
  Future<Map<String, dynamic>> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    calls.add(functionName);
    return handler(functionName, parameters);
  }
}

final class _ThrowingRpcClient implements YorksWorkforceRpcClient {
  const _ThrowingRpcClient(this.error);
  final Object error;

  @override
  Future<Map<String, dynamic>> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) => Future.error(error);
}

final class _Connectivity implements ConnectivityService {
  const _Connectivity(this.isOnline);

  @override
  final bool isOnline;

  @override
  Stream<bool> get onChange => const Stream.empty();
}
