import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/workforce/application/workforce_dashboard_controller.dart';
import 'package:material_ledger/features/workforce/data/workforce_repository.dart';
import 'package:material_ledger/features/workforce/domain/workforce_dashboard_models.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/yorks_v1_workforce_dashboard_strings.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';

const _teamId = 'a1000000-0000-4000-8000-000000000001';
const _projectId = 'a1000000-0000-4000-8000-000000000002';
const _periodId = 'a1000000-0000-4000-8000-000000000003';

void main() {
  test('T10 overview and queue status copy covers every app language', () {
    for (final key in const [
      'title',
      'server_confirmed',
      'read_only_mobile',
      'status_under_review',
      'complete_today_attendance',
      'open_review_queue',
      'open_final_approval_queue',
      'open_reopen_queue',
      'active_supervisors',
      'missing_supporting_evidence',
      'policy_typed_validation_issue',
    ]) {
      expect(
        AppLanguage.values
            .map(
              (language) =>
                  YorksV1WorkforceDashboardStrings.text(language, key),
            )
            .toSet(),
        hasLength(AppLanguage.values.length),
        reason: key,
      );
    }
  });

  test('T10 strict projections accept each role shape and reject drift', () {
    for (final kind in YorksWorkforceOverviewKind.values) {
      final projection = YorksWorkforceOverviewProjection.fromRpcJson(
        _overviewJson(kind),
      );
      expect(projection.kind, kind);
      expect(projection.generatedAt.isUtc, isTrue);
      expect(projection.asOf.single.timezone, 'Asia/Dubai');
      if (kind == YorksWorkforceOverviewKind.management) {
        expect(projection.projects.single.projectId, _projectId);
        expect(projection.reviewQueue.single.canVerify, isTrue);
      }
    }

    expect(
      () => YorksWorkforceOverviewProjection.fromRpcJson({
        ..._overviewJson(YorksWorkforceOverviewKind.supervisor),
        'salary': 100,
      }),
      throwsFormatException,
    );
    expect(
      () => YorksWorkforceOverviewProjection.fromRpcJson({
        ..._overviewJson(YorksWorkforceOverviewKind.supervisor),
        'source_version': 'forged',
      }),
      throwsFormatException,
    );
    final unsupportedPolicy = _overviewJson(
      YorksWorkforceOverviewKind.management,
    );
    unsupportedPolicy['policies'] = const {
      'overtime_limit': '12_hours',
      'supporting_evidence_requirement': 'not_configured',
    };
    expect(
      () => YorksWorkforceOverviewProjection.fromRpcJson(unsupportedPolicy),
      throwsFormatException,
    );
    final typedPolicy = _overviewJson(YorksWorkforceOverviewKind.management);
    typedPolicy['policies'] = const {
      'overtime_limit': 'typed_validation_issue',
      'supporting_evidence_requirement': 'typed_validation_issue',
    };
    typedPolicy['review_queue'] = [
      {
        ..._queueJson(),
        'missing_supporting_evidence_count': 1,
        'supporting_evidence_policy': 'typed_validation_issue',
        'high_overtime_exception_count': 1,
        'overtime_limit_policy': 'typed_validation_issue',
      },
    ];
    final typedItem = YorksWorkforceOverviewProjection.fromRpcJson(
      typedPolicy,
    ).reviewQueue.single;
    expect(typedItem.periodId, _periodId);
    expect(typedItem.missingSupportingEvidenceCount, 1);
    expect(typedItem.supportingEvidencePolicy, 'typed_validation_issue');
    expect(typedItem.highOvertimeExceptionCount, 1);
    expect(typedItem.overtimeLimitPolicy, 'typed_validation_issue');
    final contradictoryPolicy = _overviewJson(
      YorksWorkforceOverviewKind.management,
    );
    contradictoryPolicy['review_queue'] = [
      {..._queueJson(), 'high_overtime_exception_count': 1},
    ];
    expect(
      () => YorksWorkforceOverviewProjection.fromRpcJson(contradictoryPolicy),
      throwsFormatException,
    );
    final unsupportedQueue = _overviewJson(
      YorksWorkforceOverviewKind.management,
    );
    unsupportedQueue['review_queue'] = [
      {..._queueJson(), 'status': 'approved'},
    ];
    expect(
      () => YorksWorkforceOverviewProjection.fromRpcJson(unsupportedQueue),
      throwsFormatException,
    );
  });

  test('request shape cannot forge a scope for another overview kind', () {
    expect(
      YorksWorkforceOverviewRequest(
        kind: YorksWorkforceOverviewKind.supervisor,
        teamId: _teamId,
      ).toRpcJson(),
      {'overview_kind': 'supervisor', 'team_id': _teamId},
    );
    expect(
      YorksWorkforceOverviewRequest(
        kind: YorksWorkforceOverviewKind.management,
        projectId: _projectId,
      ).toRpcJson(),
      {'overview_kind': 'management', 'project_id': _projectId},
    );
    expect(
      () => const YorksWorkforceOverviewRequest(
        kind: YorksWorkforceOverviewKind.admin,
        teamId: _teamId,
      ).toRpcJson(),
      throwsFormatException,
    );
    expect(
      () => const YorksWorkforceOverviewRequest(
        kind: YorksWorkforceOverviewKind.supervisor,
        teamId: 'guessed',
      ).toRpcJson(),
      throwsFormatException,
    );
  });

  test(
    'repository fails closed for flag, offline, backend and malformed response',
    () async {
      const request = YorksWorkforceOverviewRequest(
        kind: YorksWorkforceOverviewKind.supervisor,
      );
      final rpc = _RpcClient(
        (_, _) => _overviewJson(YorksWorkforceOverviewKind.supervisor),
      );
      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: const YorksV1FeatureFlags(),
          connectivity: const _Connectivity(false),
          rpcClient: rpc,
        ).getOverview(request),
        throwsA(_domainCode(YorksV1DomainErrorCode.featureDisabled)),
      );
      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: _workforceFlags,
          connectivity: const _Connectivity(false),
          rpcClient: rpc,
        ).getOverview(request),
        throwsA(_domainCode(YorksV1DomainErrorCode.offline)),
      );
      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: _workforceFlags,
          connectivity: const _Connectivity(true),
        ).getOverview(request),
        throwsA(_domainCode(YorksV1DomainErrorCode.backendUnavailable)),
      );
      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: _workforceFlags,
          connectivity: const _Connectivity(true),
          rpcClient: _RpcClient((_, _) => const {}),
        ).getOverview(request),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );
    },
  );

  test(
    'repository calls only the dedicated read RPC and echoes kind',
    () async {
      final rpc = _RpcClient(
        (_, _) => _overviewJson(YorksWorkforceOverviewKind.management),
      );
      final repository = YorksSupabaseWorkforceRepository(
        featureFlags: _workforceFlags,
        connectivity: const _Connectivity(true),
        rpcClient: rpc,
      );
      final result = await repository.getOverview(
        const YorksWorkforceOverviewRequest(
          kind: YorksWorkforceOverviewKind.management,
          projectId: _projectId,
        ),
      );
      expect(result.kind, YorksWorkforceOverviewKind.management);
      expect(rpc.calls.single.$1, 'v1_get_workforce_overview');
      expect(rpc.calls.single.$2, {
        'p_request': {'overview_kind': 'management', 'project_id': _projectId},
      });

      final mismatch = YorksSupabaseWorkforceRepository(
        featureFlags: _workforceFlags,
        connectivity: const _Connectivity(true),
        rpcClient: _RpcClient(
          (_, _) => _overviewJson(YorksWorkforceOverviewKind.admin),
        ),
      );
      await expectLater(
        mismatch.getOverview(
          const YorksWorkforceOverviewRequest(
            kind: YorksWorkforceOverviewKind.supervisor,
          ),
        ),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );
    },
  );

  test(
    'controller preserves last-confirmed evidence offline then purges',
    () async {
      final connectivity = _MutableConnectivity(true);
      final controller = YorksWorkforceDashboardController(
        repository: _DashboardRepository(),
        connectivity: connectivity,
        kind: YorksWorkforceOverviewKind.supervisor,
      );
      addTearDown(controller.dispose);

      expect(await controller.load(), isTrue);
      expect(controller.state.status, YorksWorkforceOverviewStatus.ready);
      final confirmed = controller.state.projection;

      connectivity.setOnline(false);
      expect(await controller.load(), isFalse);
      expect(controller.state.status, YorksWorkforceOverviewStatus.stale);
      expect(identical(controller.state.projection, confirmed), isTrue);

      controller.purgeProtectedState();
      expect(controller.state.status, YorksWorkforceOverviewStatus.forbidden);
      expect(controller.state.projection, isNull);
    },
  );

  test('controller maps denied and ignores an older response', () async {
    final denied = YorksWorkforceDashboardController(
      repository: _DashboardRepository(
        failure: const YorksV1DomainException(
          YorksV1DomainErrorCode.unauthorized,
        ),
      ),
      connectivity: const _Connectivity(true),
      kind: YorksWorkforceOverviewKind.supervisor,
    );
    addTearDown(denied.dispose);
    expect(await denied.load(), isFalse);
    expect(denied.state.status, YorksWorkforceOverviewStatus.forbidden);

    final first = Completer<YorksWorkforceOverviewProjection>();
    final second = Completer<YorksWorkforceOverviewProjection>();
    final racing = YorksWorkforceDashboardController(
      repository: _SequencedRepository([first, second]),
      connectivity: const _Connectivity(true),
      kind: YorksWorkforceOverviewKind.supervisor,
    );
    addTearDown(racing.dispose);
    final olderLoad = racing.load();
    final newerLoad = racing.load();
    second.complete(
      YorksWorkforceOverviewProjection.fromRpcJson(
        _overviewJson(YorksWorkforceOverviewKind.supervisor),
      ),
    );
    expect(await newerLoad, isTrue);
    final accepted = racing.state.projection;
    first.complete(
      YorksWorkforceOverviewProjection.fromRpcJson(
        _overviewJson(YorksWorkforceOverviewKind.supervisor),
      ),
    );
    expect(await olderLoad, isFalse);
    expect(identical(racing.state.projection, accepted), isTrue);
  });
}

Map<String, dynamic> _overviewJson(YorksWorkforceOverviewKind kind) => {
  'schema_version': 1,
  'authorization_mode': 'enforced_t10',
  'source_version': 'workforce_t10_v1',
  'overview_kind': kind.name,
  'generated_at': '2026-08-31T02:30:00Z',
  'as_of_mode': 'calendar_local_by_team',
  'as_of_groups': const [
    {
      'calendar_timezone': 'Asia/Dubai',
      'local_date': '2026-08-31',
      'team_count': 1,
    },
  ],
  'summary': switch (kind) {
    YorksWorkforceOverviewKind.supervisor => _supervisorSummary(),
    YorksWorkforceOverviewKind.management => {
      ..._supervisorSummary(),
      'active_project_count': 1,
      'review_queue_count': 1,
      'approval_queue_count': 0,
      'returned_count': 0,
      'overtime_exception_count': 0,
    },
    YorksWorkforceOverviewKind.admin => const {
      'active_worker_count': 502,
      'active_supervisor_count': 1,
      'missing_today_count': 501,
      'monthly_pending_count': 1,
      'returned_count': 0,
      'awaiting_final_count': 0,
      'locked_count': 0,
      'reopen_request_count': 0,
      'configuration_issue_count': 0,
    },
  },
  'teams': [_teamJson()],
  'projects': kind == YorksWorkforceOverviewKind.management
      ? [_projectJson()]
      : const [],
  'review_queue': kind == YorksWorkforceOverviewKind.management
      ? [_queueJson()]
      : const [],
  'action_flags': switch (kind) {
    YorksWorkforceOverviewKind.supervisor => const {
      'can_complete_today_attendance': true,
    },
    YorksWorkforceOverviewKind.management => const {
      'can_open_review_queue': true,
      'can_open_final_approval_queue': false,
    },
    YorksWorkforceOverviewKind.admin => const {
      'can_open_reopen_queue': true,
      'can_open_final_approval_queue': true,
    },
  },
  'policies': const {
    'overtime_limit': 'not_configured',
    'supporting_evidence_requirement': 'not_configured',
  },
};

Map<String, Object> _supervisorSummary() => const {
  'team_count': 1,
  'worker_count': 502,
  'present_count': 1,
  'absent_count': 0,
  'leave_count': 0,
  'not_entered_count': 501,
  'warning_count': 1,
  'returned_correction_count': 0,
  'today_entered_count': 1,
  'today_completion_percent': 0.2,
  'month_entered_count': 1,
  'month_required_count': 502,
  'month_completion_percent': 0.2,
};

Map<String, dynamic> _teamJson() => {
  'team_id': _teamId,
  'team_code': 'DXB',
  'team_name': 'Dubai Workforce',
  'department': 'Operations',
  'project_id': _projectId,
  'project_ref': 'YRA-322',
  'project_name': 'Nexus 4 Station',
  'project_state': 'active',
  'internal_location_id': null,
  'internal_location_name': null,
  'supervisor_auth_user_id': 'a1000000-0000-4000-8000-000000000004',
  'supervisor_name': 'Supervisor One',
  'calendar_id': 'a1000000-0000-4000-8000-000000000005',
  'calendar_name': 'Dubai Calendar',
  'calendar_timezone': 'Asia/Dubai',
  'local_date': '2026-08-31',
  'period_month': '2026-08-01',
  'schedule_link_id': 'a1000000-0000-4000-8000-000000000006',
  'metrics': const {
    'worker_count': 502,
    'present_count': 1,
    'absent_count': 0,
    'leave_count': 0,
    'not_entered_count': 501,
    'today_entered_count': 1,
    'today_completion_percent': 0.2,
    'month_required_count': 502,
    'month_entered_count': 1,
    'month_completion_percent': 0.2,
    'warning_count': 1,
    'returned_correction_count': 0,
    'can_complete_today_attendance': true,
  },
};

Map<String, Object> _projectJson() => const {
  'project_id': _projectId,
  'project_ref': 'YRA-322',
  'project_name': 'Nexus 4 Station',
  'team_count': 1,
  'worker_count': 502,
  'missing_today_count': 501,
  'warning_count': 1,
};

Map<String, dynamic> _queueJson() => {
  'period_id': _periodId,
  'team_id': _teamId,
  'team_name': 'Dubai Workforce',
  'period_month': '2026-08-01',
  'status': 'under_review',
  'record_version': 2,
  'submitted_by_auth_user_id': 'a1000000-0000-4000-8000-000000000007',
  'submitted_by_name': 'Project Engineer',
  'worker_count': 502,
  'regular_minutes': 241000,
  'overtime_minutes': 0,
  'warning_count': 1,
  'blocking_issue_count': 0,
  'reviewer_correction_count': 0,
  'missing_supporting_evidence_count': 0,
  'supporting_evidence_policy': 'not_configured',
  'high_overtime_exception_count': 0,
  'overtime_limit_policy': 'not_configured',
  'can_return': true,
  'can_correct': true,
  'can_verify': true,
  'can_final_approve': false,
  'updated_at': '2026-08-31T02:00:00Z',
  'exception_priority': 10,
};

final class _RpcClient implements YorksWorkforceRpcClient {
  _RpcClient(this.handler);
  final Map<String, dynamic> Function(
    String name,
    Map<String, Object?> parameters,
  )
  handler;
  final List<(String, Map<String, Object?>)> calls = [];

  @override
  Future<Map<String, dynamic>> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    calls.add((functionName, parameters));
    return handler(functionName, parameters);
  }
}

final class _DashboardRepository implements YorksWorkforceDashboardRepository {
  _DashboardRepository({this.failure});
  final YorksV1DomainException? failure;

  @override
  Future<YorksWorkforceOverviewProjection> getOverview(
    YorksWorkforceOverviewRequest request,
  ) async {
    if (failure case final failure?) throw failure;
    return YorksWorkforceOverviewProjection.fromRpcJson(
      _overviewJson(request.kind),
    );
  }
}

final class _SequencedRepository implements YorksWorkforceDashboardRepository {
  _SequencedRepository(this.responses);
  final List<Completer<YorksWorkforceOverviewProjection>> responses;
  var _index = 0;

  @override
  Future<YorksWorkforceOverviewProjection> getOverview(
    YorksWorkforceOverviewRequest request,
  ) => responses[_index++].future;
}

class _Connectivity implements ConnectivityService {
  const _Connectivity(this.isOnline);
  @override
  final bool isOnline;
  @override
  Stream<bool> get onChange => const Stream.empty();
}

final class _MutableConnectivity implements ConnectivityService {
  _MutableConnectivity(this._online);
  bool _online;
  final _changes = StreamController<bool>.broadcast();
  @override
  bool get isOnline => _online;
  @override
  Stream<bool> get onChange => _changes.stream;
  void setOnline(bool value) {
    _online = value;
    _changes.add(value);
  }
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
