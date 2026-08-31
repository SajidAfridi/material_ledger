import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/workforce/data/workforce_repository.dart';
import 'package:material_ledger/features/workforce/domain/workforce_attendance_models.dart';
import 'package:material_ledger/features/workforce/domain/workforce_configuration_models.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'attendance parses retained assignment, authority and schedule',
    () async {
      final rpc = _RpcClient((functionName, parameters) {
        expect(functionName, 'v1_get_workforce_attendance');
        expect(parameters, {
          'p_work_date': '2026-08-29',
          'p_worker_id': _workerId,
        });
        return _attendanceResponse();
      });

      final projection = await _repository(
        rpc: rpc,
      ).getAttendance(workDate: ' 2026-08-29 ', workerId: ' $_workerId ');

      expect(projection.authorizationMode, 'enforced_t03');
      expect(projection.days, hasLength(1));
      expect(
        projection.days.single.status,
        YorksWorkforceAttendanceStatus.present,
      );
      expect(
        projection.days.single.schedule.dayType,
        YorksWorkforceDayType.publicHoliday,
      );
      expect(projection.days.single.schedule.shiftCrossesMidnight, isTrue);
      expect(
        projection.days.single.schedule.shiftWorkDateBasis,
        'shift_start_date',
      );
      expect(projection.days.single.assignment.projectRef, 'WF-T03-A');
      expect(projection.days.single.initialAuthority.scopeKind, 'project');
    },
  );

  test('typed save sends only the accepted T03 payload', () async {
    final rpc = _RpcClient((functionName, parameters) {
      expect(functionName, 'v1_save_workforce_attendance_day');
      expect(parameters, {
        'p_payload': {
          'worker_id': _workerId,
          'work_date': '2026-08-29',
          'attendance_status': 'present',
          'regular_minutes': 480,
          'overtime_minutes': 60,
          'reason': 'Explicit holiday work',
        },
        'p_expected_version': 2,
        'p_idempotency_key': _idempotencyKey,
      });
      return {
        'schema_version': 1,
        'attendance_day_id': _attendanceId,
        'record_version': 3,
      };
    });

    final result = await _repository(rpc: rpc).saveAttendanceDay(
      const YorksWorkforceAttendanceInput(
        workerId: _workerId,
        workDate: '2026-08-29',
        status: YorksWorkforceAttendanceStatus.present,
        regularMinutes: 480,
        overtimeMinutes: 60,
        reason: ' Explicit holiday work ',
      ),
      expectedVersion: 2,
      idempotencyKey: ' $_idempotencyKey ',
    );

    expect(result.entityId, _attendanceId);
    expect(result.recordVersion, 3);
  });

  test('invalid date, UUID, minutes and reason fail before RPC', () async {
    final rpc = _RpcClient((_, _) => throw StateError('must not call'));
    final repository = _repository(rpc: rpc);

    await expectLater(
      repository.getAttendance(workDate: '2026-02-30', workerId: _workerId),
      throwsA(_domainCode(YorksV1DomainErrorCode.invalidInput)),
    );
    await expectLater(
      repository.getAttendance(workDate: '2026-08-29', workerId: 'worker-1'),
      throwsA(_domainCode(YorksV1DomainErrorCode.invalidInput)),
    );
    await expectLater(
      repository.saveAttendanceDay(
        const YorksWorkforceAttendanceInput(
          workerId: _workerId,
          workDate: '2026-08-29',
          status: YorksWorkforceAttendanceStatus.absent,
          regularMinutes: 1,
          overtimeMinutes: 0,
          reason: 'Contradiction',
        ),
        idempotencyKey: _idempotencyKey,
      ),
      throwsA(_domainCode(YorksV1DomainErrorCode.invalidInput)),
    );
    await expectLater(
      repository.saveAttendanceDay(
        const YorksWorkforceAttendanceInput(
          workerId: _workerId,
          workDate: '2026-08-29',
          status: YorksWorkforceAttendanceStatus.present,
          regularMinutes: 1440,
          overtimeMinutes: 1,
          reason: 'Too long',
        ),
        idempotencyKey: _idempotencyKey,
      ),
      throwsA(_domainCode(YorksV1DomainErrorCode.invalidInput)),
    );
    await expectLater(
      repository.saveAttendanceDay(
        const YorksWorkforceAttendanceInput(
          workerId: _workerId,
          workDate: '2026-08-29',
          status: YorksWorkforceAttendanceStatus.present,
          regularMinutes: 480,
          overtimeMinutes: 0,
          reason: '',
        ),
        idempotencyKey: 'not-a-uuid',
      ),
      throwsA(_domainCode(YorksV1DomainErrorCode.invalidInput)),
    );
    expect(rpc.calls, isEmpty);
  });

  test('malformed status and minutes fail closed', () async {
    final statusResponse = _attendanceResponse();
    _firstDay(statusResponse)['attendance_status'] = 'weekly_off';
    await expectLater(
      _repository(
        rpc: _RpcClient((_, _) => statusResponse),
      ).getAttendance(workDate: '2026-08-29', workerId: _workerId),
      throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
    );

    final minutesResponse = _attendanceResponse();
    _firstDay(minutesResponse)['regular_minutes'] = 0;
    _firstDay(minutesResponse)['overtime_minutes'] = 0;
    await expectLater(
      _repository(
        rpc: _RpcClient((_, _) => minutesResponse),
      ).getAttendance(workDate: '2026-08-29', workerId: _workerId),
      throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
    );
  });

  test('malformed retained context fails closed', () async {
    final response = _attendanceResponse();
    final schedule = _firstDay(response)['schedule'] as Map<String, dynamic>;
    schedule['shift_work_date_basis'] = 'shift_end_date';

    await expectLater(
      _repository(
        rpc: _RpcClient((_, _) => response),
      ).getAttendance(workDate: '2026-08-29', workerId: _workerId),
      throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
    );
  });

  test('feature flag fails closed before attendance RPC', () async {
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
      repository.getAttendance(workDate: '2026-08-29', workerId: _workerId),
      throwsA(_domainCode(YorksV1DomainErrorCode.featureDisabled)),
    );
    expect(rpc.calls, isEmpty);
  });

  test('offline and missing backend fail closed', () async {
    final rpc = _RpcClient((_, _) => throw StateError('must not call'));
    await expectLater(
      _repository(
        rpc: rpc,
        connectivity: const _Connectivity(false),
      ).getAttendance(workDate: '2026-08-29', workerId: _workerId),
      throwsA(_domainCode(YorksV1DomainErrorCode.offline)),
    );
    expect(rpc.calls, isEmpty);

    await expectLater(
      _repository().getAttendance(workDate: '2026-08-29', workerId: _workerId),
      throwsA(_domainCode(YorksV1DomainErrorCode.backendUnavailable)),
    );
  });

  test('denied, stale and future attendance failures are mapped', () async {
    final denied = _repository(
      rpc: _ThrowingRpcClient(
        const PostgrestException(
          message: 'V1_WORKFORCE_ATTENDANCE_READ_DENIED',
          code: '42501',
        ),
      ),
    );
    await expectLater(
      denied.getAttendance(workDate: '2026-08-29', workerId: _workerId),
      throwsA(_domainCode(YorksV1DomainErrorCode.unauthorized)),
    );

    final stale = _repository(
      rpc: _ThrowingRpcClient(
        const PostgrestException(
          message: 'V1_WORKFORCE_ATTENDANCE_VERSION_CONFLICT',
          code: '40001',
        ),
      ),
    );
    await expectLater(
      stale.saveAttendanceDay(
        const YorksWorkforceAttendanceInput(
          workerId: _workerId,
          workDate: '2026-08-29',
          status: YorksWorkforceAttendanceStatus.present,
          regularMinutes: 480,
          overtimeMinutes: 0,
          reason: 'Stale correction',
        ),
        expectedVersion: 1,
        idempotencyKey: _idempotencyKey,
      ),
      throwsA(_domainCode(YorksV1DomainErrorCode.conflict)),
    );

    final future = _repository(
      rpc: _ThrowingRpcClient(
        const PostgrestException(
          message: 'V1_WORKFORCE_ATTENDANCE_FUTURE_DATE_FORBIDDEN',
          code: '22023',
        ),
      ),
    );
    await expectLater(
      future.saveAttendanceDay(
        const YorksWorkforceAttendanceInput(
          workerId: _workerId,
          workDate: '2026-08-31',
          status: YorksWorkforceAttendanceStatus.present,
          regularMinutes: 480,
          overtimeMinutes: 0,
          reason: 'Future entry',
        ),
        idempotencyKey: _idempotencyKey,
      ),
      throwsA(_domainCode(YorksV1DomainErrorCode.invalidInput)),
    );
  });
}

const _workerId = '59040000-0000-4000-8000-000000000001';
const _attendanceId = '59130000-0000-4000-8000-000000000001';
const _idempotencyKey = '59120000-0000-4000-8000-000000000001';

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

Map<String, dynamic> _firstDay(Map<String, dynamic> response) =>
    (response['days'] as List).single as Map<String, dynamic>;

Map<String, dynamic> _attendanceResponse() => {
  'schema_version': 1,
  'authorization_mode': 'enforced_t03',
  'actor_auth_user_id': '10000000-0000-4000-8000-000000000001',
  'work_date': '2026-08-29',
  'server_time': '2026-08-29T12:00:00Z',
  'days': [
    {
      'attendance_day_id': _attendanceId,
      'worker_id': _workerId,
      'worker_number': 'WF-T03-WORKER-A',
      'worker_name': 'T03 Authorized Worker',
      'worker_joining_date': '2026-01-01',
      'worker_leaving_date': null,
      'worker_status_at_creation': 'active',
      'work_date': '2026-08-29',
      'attendance_status': 'present',
      'regular_minutes': 480,
      'overtime_minutes': 60,
      'reason': 'Explicit holiday work',
      'record_version': 1,
      'created_at': '2026-08-29T08:00:00Z',
      'updated_at': '2026-08-29T08:00:00Z',
      'assignment': {
        'assignment_id': '59050000-0000-4000-8000-000000000001',
        'assignment_kind': 'primary',
        'team_id': '59030000-0000-4000-8000-000000000001',
        'team_name': 'T03 Authorized Team',
        'supervisor_auth_user_id': '10000000-0000-4000-8000-000000000001',
        'supervisor_name': 'Local Project Engineer',
        'project_id': '59010000-0000-4000-8000-000000000001',
        'project_ref': 'WF-T03-A',
        'project_name': 'Workforce T03 authorized project',
        'project_scope_id': '59020000-0000-4000-8000-000000000001',
        'project_scope_name': 'Common / All Buildings',
        'internal_location_id': null,
        'internal_location_name': null,
        'valid_from': '2026-01-01',
        'valid_to': '2027-12-31',
        'record_version': 1,
      },
      'initial_authority': {
        'authority_kind': 'responsibility',
        'responsibility_assignment_id': '59110000-0000-4000-8000-000000000001',
        'scope_kind': 'project',
        'scope_reference': 'project:59010000-0000-4000-8000-000000000001',
        'record_version': 1,
      },
      'schedule': {
        'team_schedule_link_id': '59080000-0000-4000-8000-000000000001',
        'team_schedule_record_version': 1,
        'calendar_id': '59060000-0000-4000-8000-000000000001',
        'calendar_code': 'WF-T03-CAL',
        'calendar_name': 'T03 Dubai Calendar',
        'calendar_timezone': 'Asia/Dubai',
        'calendar_record_version': 1,
        'calendar_date_override_id': '59090000-0000-4000-8000-000000000001',
        'calendar_date_override_version': 1,
        'calendar_override_kind': 'public_holiday',
        'calendar_exception_name': 'T03 retained public holiday',
        'day_type_source': 'date_override',
        'iso_weekday': 6,
        'day_type': 'public_holiday',
        'scheduled_minutes': 0,
        'break_minutes': 0,
        'shift_template_id': '59070000-0000-4000-8000-000000000001',
        'shift_code': 'WF-T03-NIGHT',
        'shift_name': 'T03 Night Shift',
        'shift_kind': 'night',
        'shift_start_time': '20:00:00',
        'shift_end_time': '04:00:00',
        'shift_scheduled_minutes': 480,
        'shift_break_minutes': 60,
        'shift_crosses_midnight': true,
        'shift_work_date_basis': 'shift_start_date',
        'shift_record_version': 1,
      },
    },
  ],
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
