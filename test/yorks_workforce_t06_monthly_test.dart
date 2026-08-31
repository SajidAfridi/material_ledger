import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/workforce/application/workforce_monthly_period_controller.dart';
import 'package:material_ledger/features/workforce/data/workforce_repository.dart';
import 'package:material_ledger/features/workforce/domain/workforce_monthly_period_models.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/services/yorks_v1_critical_command_key_store.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _actorId = '10000000-0000-4000-8000-000000000001';
const _teamId = '60000000-0000-4000-8000-000000000001';
const _periodId = '61000000-0000-4000-8000-000000000001';
const _runId = '62000000-0000-4000-8000-000000000001';
const _idempotencyKey = '69000000-0000-4000-8000-000000000001';
const _fingerprint =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _month = '2026-08-01';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('T06 strict filters and response envelopes fail closed', () {
    expect(
      const YorksWorkforceMonthlyFilters(
        teamId: _teamId,
        periodMonth: '2026-08-02',
      ).isValid,
      isFalse,
    );
    expect(
      const YorksWorkforceMonthlyFilters(
        teamId: _teamId,
        periodMonth: _month,
        workerLimit: 501,
      ).isValid,
      isFalse,
    );
    expect(
      () => YorksWorkforceMonthlyTeamProjection.fromRpcJson({
        'schema_version': 1,
        'authorization_mode': 'enforced_t06',
        'actor_auth_user_id': _actorId,
        'server_time': '2026-08-30T09:00:00Z',
        'filters': {
          'period_month': _month,
          'query': null,
          'limit': 50,
          'offset': 0,
        },
        'total_count': 0,
        'teams': const [],
        'commercial_value': 1,
      }),
      throwsFormatException,
    );
  });

  test(
    'flag-off, offline, missing backend and malformed RPC fail closed',
    () async {
      final rpc = _RpcClient((_, _) => const {});
      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: const YorksV1FeatureFlags(),
          connectivity: const _Connectivity(false),
          rpcClient: rpc,
        ).listMonthlyTeams(
          const YorksWorkforceMonthlyTeamFilters(periodMonth: _month),
        ),
        throwsA(_domainCode(YorksV1DomainErrorCode.featureDisabled)),
      );
      expect(rpc.calls, isEmpty);

      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: _workforceFlags,
          connectivity: const _Connectivity(false),
          rpcClient: rpc,
        ).listMonthlyTeams(
          const YorksWorkforceMonthlyTeamFilters(periodMonth: _month),
        ),
        throwsA(_domainCode(YorksV1DomainErrorCode.offline)),
      );
      expect(rpc.calls, isEmpty);

      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: _workforceFlags,
          connectivity: const _Connectivity(true),
        ).listMonthlyTeams(
          const YorksWorkforceMonthlyTeamFilters(periodMonth: _month),
        ),
        throwsA(_domainCode(YorksV1DomainErrorCode.backendUnavailable)),
      );

      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: _workforceFlags,
          connectivity: const _Connectivity(true),
          rpcClient: rpc,
        ).listMonthlyTeams(
          const YorksWorkforceMonthlyTeamFilters(periodMonth: _month),
        ),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );
      expect(rpc.calls, ['v1_list_workforce_monthly_teams']);
    },
  );

  test(
    'controller pages all 500 workers without dropping or duplicating rows',
    () async {
      final repository = _MonthlyRepository(totalWorkers: 500);
      final controller = await _controller(repository);
      addTearDown(controller.dispose);

      expect(await controller.initialize(), isTrue);
      expect(controller.state.projection?.workers, hasLength(50));
      while (controller.state.canLoadMore) {
        expect(await controller.loadMoreWorkers(), isTrue);
      }

      final workers = controller.state.projection!.workers;
      expect(workers, hasLength(500));
      expect(workers.map((worker) => worker.workerId).toSet(), hasLength(500));
      expect(repository.periodOffsets, [
        0,
        50,
        100,
        150,
        200,
        250,
        300,
        350,
        400,
        450,
      ]);
      expect(controller.state.status, YorksWorkforceMonthlyStatus.ready);
    },
  );

  test('denied load purges protected monthly state', () async {
    final repository = _MonthlyRepository(
      totalWorkers: 1,
      getFailure: const YorksV1DomainException(
        YorksV1DomainErrorCode.unauthorized,
      ),
    );
    final controller = await _controller(repository);
    addTearDown(controller.dispose);

    expect(await controller.initialize(), isFalse);
    expect(controller.state.status, YorksWorkforceMonthlyStatus.forbidden);
    expect(controller.state.teamProjection, isNull);
    expect(controller.state.projection, isNull);
    expect(controller.state.selectedTeamId, isNull);
    expect(controller.state.filters, isNull);
  });

  test('uncertain validation retry reuses its stable command key', () async {
    final repository = _MonthlyRepository(
      totalWorkers: 1,
      validateFailure: const YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
      ),
    );
    final controller = await _controller(repository);
    addTearDown(controller.dispose);

    expect(await controller.initialize(), isTrue);
    expect(await controller.validatePeriod(), isNull);
    expect(controller.state.status, YorksWorkforceMonthlyStatus.uncertain);
    expect(await controller.validatePeriod(), isNull);
    expect(repository.validationKeys, [_idempotencyKey, _idempotencyKey]);
    expect(repository.validationExpectedVersions, [1, 1]);
  });

  test(
    'connectivity loss keeps the projection visible but disables validation',
    () async {
      final connectivity = _MutableConnectivity(true);
      addTearDown(connectivity.dispose);
      final controller = await _controller(
        _MonthlyRepository(totalWorkers: 1),
        connectivity: connectivity,
      );
      addTearDown(controller.dispose);

      expect(await controller.initialize(), isTrue);
      final retained = controller.state.projection;
      connectivity.setOnline(false);
      expect(controller.state.status, YorksWorkforceMonthlyStatus.offline);
      expect(controller.state.projection, same(retained));
      expect(controller.state.canValidate, isFalse);
    },
  );

  test(
    'retained historical assignment and closed-target drill-down shapes decode strictly',
    () {
      final projectDay = YorksWorkforceMonthlyDay.fromRpcJson(
        _historicalDayJson(
          workDate: '2025-06-10',
          workerSuffix: '1',
          assignment: {
            'assignment_id': '59a60000-0000-4000-8000-000000000001',
            'assignment_kind': 'primary',
            'team_id': '59a40000-0000-4000-8000-000000000001',
            'team_name': 'T06 Historical Team A',
            'supervisor_auth_user_id': '10000000-0000-4000-8000-000000000004',
            'supervisor_name': 'Local Admin',
            'project_id': '59a10000-0000-4000-8000-000000000001',
            'project_ref': 'WF-T06-HIST-A',
            'project_name': 'T06 Historical Project A',
            'project_scope_id': '59a20000-0000-4000-8000-000000000001',
            'project_scope_name': 'Historical Building A',
            'internal_location_id': null,
            'internal_location_name': null,
            'valid_from': '2025-06-10',
            'valid_to': '2025-06-10',
            'record_version': 1,
            'source': 'attendance_snapshot',
          },
          target: {
            'line_number': 1,
            'target_kind': 'project_work',
            'project_id': '59a10000-0000-4000-8000-000000000001',
            'project_ref': 'WF-T06-HIST-A',
            'project_name': 'T06 Historical Project A',
            'project_scope_id': '59a20000-0000-4000-8000-000000000001',
            'project_scope_kind': 'building',
            'project_scope_code': 'B01',
            'project_scope_name': 'Historical Building A',
            'internal_location_id': null,
            'internal_location_code': null,
            'internal_location_name': null,
            'activity_task': 'Historical project task',
            'notes': null,
            'regular_minutes': 480,
            'overtime_minutes': 0,
            'start_time_local': null,
            'end_time_local': null,
            'interval_start_at': null,
            'interval_end_at': null,
            'crosses_midnight': null,
          },
        ),
      );
      final internalDay = YorksWorkforceMonthlyDay.fromRpcJson(
        _historicalDayJson(
          workDate: '2025-06-11',
          workerSuffix: '2',
          assignment: {
            'assignment_id': '59a60000-0000-4000-8000-000000000002',
            'assignment_kind': 'primary',
            'team_id': '59a40000-0000-4000-8000-000000000001',
            'team_name': 'T06 Historical Team A',
            'supervisor_auth_user_id': '10000000-0000-4000-8000-000000000004',
            'supervisor_name': 'Local Admin',
            'project_id': null,
            'project_ref': null,
            'project_name': null,
            'project_scope_id': null,
            'project_scope_name': null,
            'internal_location_id': '59a30000-0000-4000-8000-000000000001',
            'internal_location_name': 'Historical Workshop',
            'valid_from': '2025-06-11',
            'valid_to': '2025-06-11',
            'record_version': 1,
            'source': 'attendance_snapshot',
          },
          target: {
            'line_number': 1,
            'target_kind': 'internal_work',
            'project_id': null,
            'project_ref': null,
            'project_name': null,
            'project_scope_id': null,
            'project_scope_kind': null,
            'project_scope_code': null,
            'project_scope_name': null,
            'internal_location_id': '59a30000-0000-4000-8000-000000000001',
            'internal_location_code': 'WF-T06-HIST-INT',
            'internal_location_name': 'Historical Workshop',
            'activity_task': 'Historical internal task',
            'notes': null,
            'regular_minutes': 480,
            'overtime_minutes': 0,
            'start_time_local': null,
            'end_time_local': null,
            'interval_start_at': null,
            'interval_end_at': null,
            'crosses_midnight': null,
          },
        ),
      );

      expect(projectDay.assignment['source'], 'attendance_snapshot');
      expect(
        projectDay.assignment['team_id'],
        '59a40000-0000-4000-8000-000000000001',
      );
      expect(projectDay.schedule?['source'], 'attendance_snapshot');
      expect(projectDay.allocation?['has_invalid_target'], isFalse);
      expect(internalDay.assignment['source'], 'attendance_snapshot');
      expect(internalDay.allocation?['has_invalid_target'], isFalse);
      expect(
        (internalDay.allocation?['targets'] as List).single['target_kind'],
        'internal_work',
      );
    },
  );
}

Map<String, dynamic> _historicalDayJson({
  required String workDate,
  required String workerSuffix,
  required Map<String, dynamic> assignment,
  required Map<String, dynamic> target,
}) => {
  'work_date': workDate,
  'is_future': false,
  'is_required': true,
  'day_type': 'regular_working_day',
  'daily_status': 'complete',
  'assignment': assignment,
  'schedule': {
    'team_schedule_link_id': '59a80000-0000-4000-8000-000000000001',
    'team_schedule_record_version': 1,
    'calendar_id': '59a70000-0000-4000-8000-000000000001',
    'calendar_code': 'WF-T06-HISTORY',
    'calendar_name': 'T06 Historical Calendar',
    'calendar_timezone': 'Asia/Dubai',
    'calendar_record_version': 1,
    'calendar_date_override_id': null,
    'calendar_date_override_version': null,
    'calendar_override_kind': null,
    'calendar_exception_name': null,
    'day_type_source': 'weekday',
    'iso_weekday': 2,
    'day_type': 'regular_working_day',
    'scheduled_minutes': 480,
    'break_minutes': 60,
    'shift_template_id': null,
    'shift_code': null,
    'shift_name': null,
    'shift_kind': null,
    'shift_start_time': null,
    'shift_end_time': null,
    'shift_scheduled_minutes': null,
    'shift_break_minutes': null,
    'shift_crosses_midnight': null,
    'shift_work_date_basis': null,
    'shift_record_version': null,
    'source': 'attendance_snapshot',
  },
  'attendance': {
    'attendance_day_id': '59aa0000-0000-4000-8000-00000000000$workerSuffix',
    'record_version': 1,
    'attendance_status': 'present',
    'regular_minutes': 480,
    'overtime_minutes': 0,
    'overtime_reason': null,
    'reason': 'Accepted retained history',
    'created_by_auth_user_id': _actorId,
    'created_at': '2025-06-12T08:00:00Z',
    'updated_by_auth_user_id': _actorId,
    'updated_at': '2025-06-12T08:00:00Z',
  },
  'allocation': {
    'allocation_set_id': '59ab0000-0000-4000-8000-00000000000$workerSuffix',
    'allocation_set_version': 1,
    'allocation_state': 'active',
    'allocation_revision_id':
        '59ac0000-0000-4000-8000-00000000000$workerSuffix',
    'allocation_revision_number': 1,
    'attendance_record_version_basis': 1,
    'total_regular_minutes': 480,
    'total_overtime_minutes': 0,
    'line_count': 1,
    'has_interval_overlap': false,
    'has_missing_activity': false,
    'has_off_assignment_target': false,
    'has_invalid_target': false,
    'targets_restricted': false,
    'targets': [target],
  },
  'scheduled_minutes': 480,
  'regular_minutes': 480,
  'overtime_minutes': 0,
  'allocation_minutes': 480,
  'blocking_issue_count': 0,
  'warning_issue_count': 0,
  'issues': const [],
};

Future<YorksWorkforceMonthlyController> _controller(
  YorksWorkforceRepository repository, {
  ConnectivityService connectivity = const _Connectivity(true),
}) async {
  final preferences = await SharedPreferences.getInstance();
  return YorksWorkforceMonthlyController(
    repository: repository,
    commandKeys: YorksV1CriticalCommandKeyStore(
      preferences: preferences,
      actorAuthUserId: _actorId,
      uuidFactory: () => _idempotencyKey,
    ),
    connectivity: connectivity,
    clock: () => DateTime.utc(2026, 8, 30, 12),
  );
}

final class _MonthlyRepository implements YorksWorkforceRepository {
  _MonthlyRepository({
    required this.totalWorkers,
    this.getFailure,
    this.validateFailure,
  });

  final int totalWorkers;
  final YorksV1DomainException? getFailure;
  final YorksV1DomainException? validateFailure;
  final List<int> periodOffsets = [];
  final List<String> validationKeys = [];
  final List<int?> validationExpectedVersions = [];

  @override
  Future<YorksWorkforceMonthlyTeamProjection> listMonthlyTeams(
    YorksWorkforceMonthlyTeamFilters filters,
  ) async => YorksWorkforceMonthlyTeamProjection(
    schemaVersion: 1,
    authorizationMode: 'enforced_t06',
    actorAuthUserId: _actorId,
    serverTime: '2026-08-30T09:00:00Z',
    filters: filters,
    totalCount: 1,
    teams: const [
      YorksWorkforceMonthlyTeam(
        id: _teamId,
        code: 'YRA-322',
        name: 'Nexus 4 Station',
        department: 'Projects',
        periodExists: true,
        periodId: _periodId,
        storedStatus: YorksWorkforceMonthlyPeriodStatus.readyForReview,
        recordVersion: 1,
        currentValidationNumber: 1,
      ),
    ],
  );

  @override
  Future<YorksWorkforceMonthlyProjection> getMonthlyPeriod(
    YorksWorkforceMonthlyFilters filters,
  ) async {
    final failure = getFailure;
    if (failure != null) throw failure;
    periodOffsets.add(filters.workerOffset);
    return _projection(filters, totalWorkers: totalWorkers);
  }

  @override
  Future<YorksWorkforceMonthlyValidationResult> validateMonthlyPeriod({
    required String teamId,
    required String periodMonth,
    required int? expectedPeriodVersion,
    required String idempotencyKey,
  }) async {
    validationKeys.add(idempotencyKey);
    validationExpectedVersions.add(expectedPeriodVersion);
    final failure = validateFailure;
    if (failure != null) throw failure;
    return YorksWorkforceMonthlyValidationResult(
      projection: _projection(
        const YorksWorkforceMonthlyFilters(
          teamId: _teamId,
          periodMonth: _month,
        ),
        totalWorkers: totalWorkers,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

YorksWorkforceMonthlyProjection _projection(
  YorksWorkforceMonthlyFilters filters, {
  required int totalWorkers,
}) {
  final available = totalWorkers - filters.workerOffset;
  final count = available <= 0
      ? 0
      : available < filters.workerLimit
      ? available
      : filters.workerLimit;
  final workers = List.generate(
    count,
    (index) => _worker(filters.workerOffset + index + 1),
    growable: false,
  );
  return YorksWorkforceMonthlyProjection(
    schemaVersion: 1,
    authorizationMode: 'enforced_t06',
    actorAuthUserId: _actorId,
    serverTime: '2026-08-30T09:00:00Z',
    filters: filters,
    capabilities: const YorksWorkforceMonthlyCapabilities(
      canView: true,
      canValidate: true,
    ),
    period: const YorksWorkforceMonthlyPeriod(
      id: _periodId,
      teamId: _teamId,
      teamName: 'YRA-322 · Nexus 4 Station',
      periodMonth: _month,
      storedStatus: YorksWorkforceMonthlyPeriodStatus.readyForReview,
      effectiveStatus: YorksWorkforceMonthlyPeriodStatus.readyForReview,
      isStale: false,
      recordVersion: 1,
      currentValidationRunId: _runId,
      currentValidationNumber: 1,
      sourceFingerprint: _fingerprint,
      currentSourceFingerprint: _fingerprint,
      validatedAt: '2026-08-30T09:00:00Z',
      validatedByAuthUserId: _actorId,
    ),
    summary: YorksWorkforceMonthlySummary(
      workerCount: totalWorkers,
      dateCount: totalWorkers * 31,
      scheduledDayCount: 0,
      futureDayCount: 0,
      presentDayCount: 0,
      absentDayCount: 0,
      leaveDayCount: 0,
      weeklyOffDayCount: 0,
      publicHolidayDayCount: 0,
      siteClosureDayCount: 0,
      missingDayCount: 0,
      regularMinutes: 0,
      overtimeMinutes: 0,
      allocationMinutes: 0,
      blockingIssueCount: 0,
      warningIssueCount: 0,
      projectCount: 0,
      locationCount: 0,
    ),
    issueCounts: const [],
    totalCount: totalWorkers,
    workers: workers,
  );
}

YorksWorkforceMonthlyWorkerSummary _worker(int index) {
  final suffix = index.toRadixString(16).padLeft(12, '0');
  return YorksWorkforceMonthlyWorkerSummary(
    workerId: '63000000-0000-4000-8000-$suffix',
    workerNumber: 'WF-${index.toString().padLeft(4, '0')}',
    workerName: 'Worker $index',
    tradeName: 'Technician',
    employerName: 'Yorks AC & Ref.',
    firstApplicableDate: _month,
    lastApplicableDate: '2026-08-30',
    supervisors: const [],
    projects: const [],
    locations: const [],
    scheduledDayCount: 0,
    presentDayCount: 0,
    absentDayCount: 0,
    leaveDayCount: 0,
    weeklyOffDayCount: 0,
    publicHolidayDayCount: 0,
    regularMinutes: 0,
    overtimeMinutes: 0,
    missingDayCount: 0,
    blockingIssueCount: 0,
    warningIssueCount: 0,
    status: YorksWorkforceMonthlyWorkerStatus.complete,
  );
}

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

final class _Connectivity implements ConnectivityService {
  const _Connectivity(this.isOnline);

  @override
  final bool isOnline;

  @override
  Stream<bool> get onChange => const Stream.empty();
}

final class _MutableConnectivity implements ConnectivityService {
  _MutableConnectivity(this.isOnline);

  @override
  bool isOnline;

  final _changes = StreamController<bool>.broadcast(sync: true);

  @override
  Stream<bool> get onChange => _changes.stream;

  void setOnline(bool value) {
    isOnline = value;
    _changes.add(value);
  }

  Future<void> dispose() => _changes.close();
}

const _workforceFlags = YorksV1FeatureFlags(
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
);

Matcher _domainCode(YorksV1DomainErrorCode code) =>
    isA<YorksV1DomainException>().having((error) => error.code, 'code', code);
