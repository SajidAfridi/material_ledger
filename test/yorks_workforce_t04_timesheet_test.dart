import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/workforce/application/workforce_timesheet_controller.dart';
import 'package:material_ledger/features/workforce/data/workforce_repository.dart';
import 'package:material_ledger/features/workforce/domain/workforce_timesheet_models.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/services/yorks_v1_critical_command_key_store.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'strict T04 projection retains project and internal target meaning',
    () async {
      final rpc = _RpcClient((functionName, parameters) {
        expect(functionName, 'v1_get_workforce_timesheet_allocations');
        expect(parameters, {
          'p_work_date': '2026-08-30',
          'p_worker_id': _workerId,
        });
        return _projectionResponse();
      });

      final projection = await _repository(rpc: rpc).getTimesheetAllocations(
        workDate: ' 2026-08-30 ',
        workerId: ' $_workerId ',
      );

      expect(projection.authorizationMode, 'enforced_t04');
      expect(projection.days, hasLength(1));
      expect(projection.days.single.allocations, hasLength(2));
      expect(
        projection.days.single.allocations.first.target.projectRef,
        'WF-T04-A',
      );
      expect(
        projection.days.single.allocations.last.target.departmentCostCentre,
        'Workshop / CC-100',
      );
      expect(projection.days.single.allocations.first.crossesMidnight, isTrue);
    },
  );

  test('typed save sends only accepted target and minute fields', () async {
    final rpc = _RpcClient((functionName, parameters) {
      expect(functionName, 'v1_save_workforce_timesheet_allocations');
      expect(parameters, {
        'p_payload': {
          'attendance_day_id': _attendanceId,
          'attendance_record_version': 1,
          'allocations': [
            {
              'target_kind': 'project_work',
              'regular_minutes': 480,
              'overtime_minutes': 60,
              'project_id': _projectId,
              'project_scope_id': _scopeId,
              'activity_task': 'Duct installation',
              'start_time': '20:00',
              'end_time': '04:00',
            },
          ],
          'reason': 'Reviewed allocation',
        },
        'p_expected_version': 2,
        'p_idempotency_key': _idempotencyKey,
      });
      return _commandResponse(singleProject: true);
    });

    final result = await _repository(rpc: rpc).saveTimesheetAllocations(
      _projectInput(),
      expectedVersion: 2,
      idempotencyKey: ' $_idempotencyKey ',
    );

    expect(result.day.id, _setId);
    expect(result.day.recordVersion, 2);
    expect(result.day.allocations.single.regularMinutes, 480);
  });

  test('typed withdrawal uses the dedicated non-attendance RPC', () async {
    final rpc = _RpcClient((functionName, parameters) {
      expect(functionName, 'v1_withdraw_workforce_timesheet_allocations');
      expect(parameters, {
        'p_attendance_day_id': _attendanceId,
        'p_reason': 'Release parent for correction',
        'p_expected_version': 2,
        'p_idempotency_key': _idempotencyKey,
      });
      return _withdrawnCommandResponse();
    });

    final result = await _repository(rpc: rpc).withdrawTimesheetAllocations(
      attendanceDayId: ' $_attendanceId ',
      reason: ' Release parent for correction ',
      expectedVersion: 2,
      idempotencyKey: _idempotencyKey,
    );

    expect(result.day.state, 'withdrawn');
    expect(result.day.allocations, isEmpty);
  });

  test(
    'invalid shape, time pair, minutes and identifiers fail before RPC',
    () async {
      final rpc = _RpcClient((_, _) => throw StateError('must not call'));
      final repository = _repository(rpc: rpc);

      await expectLater(
        repository.saveTimesheetAllocations(
          YorksWorkforceTimesheetAllocationInput(
            attendanceDayId: _attendanceId,
            attendanceRecordVersion: 1,
            allocations: const [
              YorksWorkforceAllocationInput(
                targetKind: YorksWorkforceAllocationTargetKind.projectWork,
                projectId: _projectId,
                projectScopeId: _scopeId,
                internalLocationId: _internalId,
                regularMinutes: 480,
                overtimeMinutes: 60,
              ),
            ],
            reason: 'Mixed target',
          ),
          idempotencyKey: _idempotencyKey,
        ),
        throwsA(_domainCode(YorksV1DomainErrorCode.invalidInput)),
      );
      await expectLater(
        repository.saveTimesheetAllocations(
          YorksWorkforceTimesheetAllocationInput(
            attendanceDayId: _attendanceId,
            attendanceRecordVersion: 1,
            allocations: const [
              YorksWorkforceAllocationInput(
                targetKind: YorksWorkforceAllocationTargetKind.internalWork,
                internalLocationId: _internalId,
                regularMinutes: 1440,
                overtimeMinutes: 1,
                startTime: '20:00',
              ),
            ],
            reason: 'Invalid minute/time pair',
          ),
          idempotencyKey: _idempotencyKey,
        ),
        throwsA(_domainCode(YorksV1DomainErrorCode.invalidInput)),
      );
      await expectLater(
        repository.getTimesheetAllocations(
          workDate: '2026-02-30',
          workerId: 'worker',
        ),
        throwsA(_domainCode(YorksV1DomainErrorCode.invalidInput)),
      );
      expect(rpc.calls, isEmpty);
    },
  );

  test(
    'malformed schema, target and minute reconciliation fail closed',
    () async {
      final malformedSchema = _projectionResponse()
        ..['authorization_mode'] = 'shadow';
      await expectLater(
        _repository(
          rpc: _RpcClient((_, _) => malformedSchema),
        ).getTimesheetAllocations(workDate: '2026-08-30', workerId: _workerId),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );

      final malformedTarget = _projectionResponse();
      final first = _firstAllocation(malformedTarget);
      first['internal_location'] = {
        'internal_location_id': _internalId,
        'location_code': 'WORKSHOP',
        'location_name': 'Main Workshop',
        'department_cost_centre': 'Workshop / CC-100',
        'record_version': 1,
      };
      await expectLater(
        _repository(
          rpc: _RpcClient((_, _) => malformedTarget),
        ).getTimesheetAllocations(workDate: '2026-08-30', workerId: _workerId),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );

      final malformedTotals = _projectionResponse();
      _firstAllocation(malformedTotals)['regular_minutes'] = 299;
      await expectLater(
        _repository(
          rpc: _RpcClient((_, _) => malformedTotals),
        ).getTimesheetAllocations(workDate: '2026-08-30', workerId: _workerId),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );
    },
  );

  test('flag-off, offline and missing backend fail closed', () async {
    final rpc = _RpcClient((_, _) => throw StateError('must not call'));
    await expectLater(
      _repository(
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
      ).getTimesheetAllocations(workDate: '2026-08-30'),
      throwsA(_domainCode(YorksV1DomainErrorCode.featureDisabled)),
    );
    await expectLater(
      _repository(
        rpc: rpc,
        connectivity: const _Connectivity(false),
      ).getTimesheetAllocations(workDate: '2026-08-30'),
      throwsA(_domainCode(YorksV1DomainErrorCode.offline)),
    );
    await expectLater(
      _repository().getTimesheetAllocations(workDate: '2026-08-30'),
      throwsA(_domainCode(YorksV1DomainErrorCode.backendUnavailable)),
    );
    expect(rpc.calls, isEmpty);
  });

  test(
    'denied and stale server failures map to stable domain errors',
    () async {
      await expectLater(
        _repository(
          rpc: _ThrowingRpcClient(
            const PostgrestException(
              message: 'V1_WORKFORCE_TIMESHEET_TARGET_DENIED',
              code: '42501',
            ),
          ),
        ).saveTimesheetAllocations(
          _projectInput(),
          idempotencyKey: _idempotencyKey,
        ),
        throwsA(_domainCode(YorksV1DomainErrorCode.unauthorized)),
      );
      await expectLater(
        _repository(
          rpc: _ThrowingRpcClient(
            const PostgrestException(
              message: 'V1_WORKFORCE_TIMESHEET_VERSION_CONFLICT',
              code: '40001',
            ),
          ),
        ).saveTimesheetAllocations(
          _projectInput(),
          expectedVersion: 1,
          idempotencyKey: _idempotencyKey,
        ),
        throwsA(_domainCode(YorksV1DomainErrorCode.conflict)),
      );
    },
  );

  test('controller retains one command key across uncertain retry', () async {
    final keys = <String>[];
    var attempt = 0;
    final rpc = _RpcClient((functionName, parameters) {
      expect(functionName, 'v1_save_workforce_timesheet_allocations');
      keys.add(parameters['p_idempotency_key']! as String);
      attempt += 1;
      if (attempt == 1) throw TimeoutException('lost response');
      return _commandResponse(singleProject: true);
    });
    final preferences = await SharedPreferences.getInstance();
    final controller = YorksWorkforceTimesheetController(
      repository: _repository(rpc: rpc),
      commandKeys: YorksV1CriticalCommandKeyStore(
        preferences: preferences,
        actorAuthUserId: _actorId,
        uuidFactory: () => _idempotencyKey,
      ),
    );

    expect(await controller.save(_projectInput(), expectedVersion: 2), isNull);
    expect(controller.state.status, YorksWorkforceTimesheetStatus.uncertain);
    expect(
      await controller.save(_projectInput(), expectedVersion: 2),
      isNotNull,
    );
    expect(controller.state.status, YorksWorkforceTimesheetStatus.success);
    expect(keys, [_idempotencyKey, _idempotencyKey]);
  });
}

const _actorId = '10000000-0000-4000-8000-000000000004';
const _workerId = '59240000-0000-4000-8000-000000000001';
const _attendanceId = '59290000-0000-4000-8000-000000000001';
const _setId = '59292000-0000-4000-8000-000000000001';
const _revisionId = '59293000-0000-4000-8000-000000000001';
const _projectId = '59210000-0000-4000-8000-000000000001';
const _scopeId = '59220000-0000-4000-8000-000000000001';
const _internalId = '59225000-0000-4000-8000-000000000001';
const _idempotencyKey = '59291000-0000-4000-8000-000000000001';

YorksWorkforceTimesheetAllocationInput _projectInput() =>
    YorksWorkforceTimesheetAllocationInput(
      attendanceDayId: _attendanceId,
      attendanceRecordVersion: 1,
      allocations: const [
        YorksWorkforceAllocationInput(
          targetKind: YorksWorkforceAllocationTargetKind.projectWork,
          projectId: _projectId,
          projectScopeId: _scopeId,
          activityTask: ' Duct installation ',
          regularMinutes: 480,
          overtimeMinutes: 60,
          startTime: '20:00',
          endTime: '04:00',
        ),
      ],
      reason: ' Reviewed allocation ',
    );

YorksSupabaseWorkforceRepository _repository({
  YorksWorkforceRpcClient? rpc,
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

Map<String, dynamic> _projectionResponse() => {
  'schema_version': 1,
  'authorization_mode': 'enforced_t04',
  'actor_auth_user_id': _actorId,
  'work_date': '2026-08-30',
  'server_time': '2026-08-30T12:00:00Z',
  'timesheet_days': [_activeDay()],
};

Map<String, dynamic> _commandResponse({required bool singleProject}) => {
  'schema_version': 1,
  'authorization_mode': 'enforced_t04',
  'timesheet_day': singleProject ? _projectOnlyDay() : _activeDay(),
};

Map<String, dynamic> _withdrawnCommandResponse() => {
  'schema_version': 1,
  'authorization_mode': 'enforced_t04',
  'timesheet_day': {
    ..._activeDay(),
    'state': 'withdrawn',
    'record_version': 3,
    'current_revision': {
      ...(_activeDay()['current_revision']! as Map<String, dynamic>),
      'revision_number': 2,
      'state': 'withdrawn',
      'total_regular_minutes': 0,
      'total_overtime_minutes': 0,
      'reason': 'Release parent for correction',
    },
    'allocations': <Object?>[],
  },
};

Map<String, dynamic> _projectOnlyDay() => {
  ..._activeDay(),
  'allocations': [_projectAllocation(480, 60)],
};

Map<String, dynamic> _activeDay() => {
  'allocation_set_id': _setId,
  'attendance_day_id': _attendanceId,
  'worker_id': _workerId,
  'work_date': '2026-08-30',
  'state': 'active',
  'record_version': 2,
  'current_revision': {
    'revision_id': _revisionId,
    'revision_number': 1,
    'state': 'active',
    'attendance_record_version_basis': 1,
    'total_regular_minutes': 480,
    'total_overtime_minutes': 60,
    'reason': 'Reviewed allocation',
    'created_by_auth_user_id': _actorId,
    'created_at': '2026-08-30T08:00:00Z',
  },
  'attendance': {
    'status': 'present',
    'regular_minutes': 480,
    'overtime_minutes': 60,
    'record_version': 1,
    'calendar_timezone': 'Asia/Dubai',
  },
  'allocations': [
    _projectAllocation(300, 30),
    {
      'allocation_id': '59294000-0000-4000-8000-000000000002',
      'line_number': 2,
      'target_kind': 'internal_work',
      'project': null,
      'internal_location': {
        'internal_location_id': _internalId,
        'location_code': 'T04-WORKSHOP',
        'location_name': 'Main Workshop',
        'department_cost_centre': 'Workshop / CC-100',
        'record_version': 1,
      },
      'activity_task': 'Workshop fabrication',
      'notes': null,
      'regular_minutes': 180,
      'overtime_minutes': 30,
      'start_time': '01:00:00',
      'end_time': '04:00:00',
      'crosses_midnight': false,
    },
  ],
  'created_at': '2026-08-30T08:00:00Z',
  'updated_at': '2026-08-30T08:00:00Z',
};

Map<String, dynamic> _projectAllocation(int regular, int overtime) => {
  'allocation_id': '59294000-0000-4000-8000-000000000001',
  'line_number': 1,
  'target_kind': 'project_work',
  'project': {
    'project_id': _projectId,
    'project_ref': 'WF-T04-A',
    'project_name': 'Workforce T04 authorized project',
    'project_record_version': 1,
    'project_scope_id': _scopeId,
    'project_scope_kind': 'common',
    'project_scope_code': 'common',
    'project_scope_name': 'Common / All Buildings',
    'project_scope_record_version': 1,
  },
  'internal_location': null,
  'activity_task': 'Duct installation',
  'notes': null,
  'regular_minutes': regular,
  'overtime_minutes': overtime,
  'start_time': '20:00:00',
  'end_time': '04:00:00',
  'crosses_midnight': true,
};

Map<String, dynamic> _firstAllocation(Map<String, dynamic> response) =>
    ((((response['timesheet_days']! as List).single
                    as Map<String, dynamic>)['allocations']!
                as List)
            .first
        as Map<String, dynamic>);

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
