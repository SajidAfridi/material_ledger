import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/workforce/application/workforce_review_controller.dart';
import 'package:material_ledger/features/workforce/data/workforce_repository.dart';
import 'package:material_ledger/features/workforce/domain/workforce_daily_roster_models.dart';
import 'package:material_ledger/features/workforce/domain/workforce_monthly_period_models.dart';
import 'package:material_ledger/features/workforce/domain/workforce_review_models.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/services/yorks_v1_critical_command_key_store.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _actorId = '10000000-0000-4000-8000-000000000001';
const _periodId = '71000000-0000-4000-8000-000000000001';
const _teamId = '72000000-0000-4000-8000-000000000001';
const _runId = '73000000-0000-4000-8000-000000000001';
const _key = '79000000-0000-4000-8000-000000000001';
const _fingerprint =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('T07 lifecycle and queue decode strictly and reject contradictions', () {
    final lifecycle = YorksWorkforceReviewLifecycle.fromRpcJson(
      _lifecycleJson(),
    );
    expect(lifecycle.actions.canSubmit, isTrue);
    expect(lifecycle.status, YorksWorkforceMonthlyPeriodStatus.readyForReview);

    final queue = YorksWorkforceReviewQueue.fromRpcJson(_queueJson());
    expect(queue.items.single.lifecycle.periodId, _periodId);

    expect(
      () => YorksWorkforceReviewLifecycle.fromRpcJson({
        ..._lifecycleJson(),
        'unexpected': true,
      }),
      throwsFormatException,
    );
    expect(
      () => YorksWorkforceReviewLifecycle.fromRpcJson(
        _lifecycleJson(status: 'locked', canSubmit: false),
      ),
      throwsFormatException,
    );
  });

  test(
    'repository fails closed for flag, offline, backend and malformed data',
    () async {
      final rpc = _RpcClient((name, parameters) => const {});
      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: const YorksV1FeatureFlags(),
          connectivity: const _Connectivity(true),
          rpcClient: rpc,
        ).getMonthlyLifecycle(_periodId),
        throwsA(_domainCode(YorksV1DomainErrorCode.featureDisabled)),
      );
      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: _workforceFlags,
          connectivity: const _Connectivity(false),
          rpcClient: rpc,
        ).getMonthlyLifecycle(_periodId),
        throwsA(_domainCode(YorksV1DomainErrorCode.offline)),
      );
      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: _workforceFlags,
          connectivity: const _Connectivity(true),
        ).getMonthlyLifecycle(_periodId),
        throwsA(_domainCode(YorksV1DomainErrorCode.backendUnavailable)),
      );
      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: _workforceFlags,
          connectivity: const _Connectivity(true),
          rpcClient: rpc,
        ).getMonthlyLifecycle(_periodId),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );
    },
  );

  test('repository maps strict queue and submit RPC parameters', () async {
    final rpc = _RpcClient((name, parameters) {
      if (name == 'v1_list_workforce_monthly_approval_queue') {
        return _queueJson();
      }
      return _lifecycleJson(
        status: 'submitted',
        canSubmit: false,
        recordVersion: 2,
        approvalRevision: 1,
        submitter: _actorId,
      );
    });
    final repository = YorksSupabaseWorkforceRepository(
      featureFlags: _workforceFlags,
      connectivity: const _Connectivity(true),
      rpcClient: rpc,
    );
    final queue = await repository.listMonthlyApprovalQueue(limit: 50);
    expect(queue.totalCount, 1);
    final result = await repository.submitMonthlyPeriod(
      periodId: _periodId,
      warningIssueIds: const [],
      reason: 'Submit current month',
      expectedVersion: 1,
      idempotencyKey: _key,
    );
    expect(result.status, YorksWorkforceMonthlyPeriodStatus.submitted);
    expect(rpc.calls, [
      'v1_list_workforce_monthly_approval_queue',
      'v1_submit_workforce_monthly_period',
    ]);
    expect(rpc.parameters.last['p_expected_period_version'], 1);
    expect(rpc.parameters.last['p_idempotency_key'], _key);
  });

  test('uncertain command retry reuses one stable idempotency key', () async {
    final repository = _ReviewRepository(
      submitFailure: const YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
      ),
    );
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    expect(await controller.load(periodId: _periodId), isTrue);
    expect(
      await controller.submit(
        warningIssueIds: const [],
        reason: 'Submit current month',
      ),
      isNull,
    );
    expect(controller.state.status, YorksWorkforceReviewStatus.uncertain);
    expect(
      await controller.submit(
        warningIssueIds: const [],
        reason: 'Submit current month',
      ),
      isNull,
    );
    expect(repository.submitKeys, [_key, _key]);
  });

  test(
    'authorization loss purges lifecycle, queue and protected error state',
    () async {
      final controller = await _controller(_ReviewRepository());
      addTearDown(controller.dispose);
      expect(await controller.load(periodId: _periodId), isTrue);
      expect(controller.state.lifecycle, isNotNull);
      expect(controller.state.queue, isNotNull);
      controller.purgeProtectedState();
      expect(controller.state.status, YorksWorkforceReviewStatus.forbidden);
      expect(controller.state.lifecycle, isNull);
      expect(controller.state.queue, isNull);
    },
  );
}

Future<YorksWorkforceReviewController> _controller(
  YorksWorkforceReviewRepository repository,
) async {
  final preferences = await SharedPreferences.getInstance();
  return YorksWorkforceReviewController(
    repository: repository,
    commandKeys: YorksV1CriticalCommandKeyStore(
      preferences: preferences,
      actorAuthUserId: _actorId,
      uuidFactory: () => _key,
    ),
    connectivity: const _Connectivity(true),
  );
}

Map<String, dynamic> _lifecycleJson({
  String status = 'ready_for_review',
  bool canSubmit = true,
  int recordVersion = 1,
  int approvalRevision = 0,
  String? submitter,
}) => {
  'schema_version': 1,
  'authorization_mode': 'enforced_t07',
  'period_id': _periodId,
  'team_id': _teamId,
  'period_month': '2026-08-01',
  'status': status,
  'record_version': recordVersion,
  'approval_revision_number': approvalRevision,
  'validation_run_id': _runId,
  'validation_number': 1,
  'source_fingerprint': _fingerprint,
  'current_source_fingerprint': _fingerprint,
  'is_stale': false,
  'blocking_issue_count': 0,
  'warning_issue_count': 0,
  'submitter_auth_user_id': submitter,
  'can_submit': canSubmit,
  'can_return': false,
  'can_correct': false,
  'can_verify': false,
  'can_final_approve': false,
  'can_request_reopen': false,
  'can_authorize_reopen': false,
  'transitions': const [],
  'corrections': const [],
  'approved_snapshots': const [],
  'reopen_requests': const [],
};

Map<String, dynamic> _queueJson() => {
  'schema_version': 1,
  'authorization_mode': 'enforced_t07',
  'status_filter': null,
  'limit': 50,
  'offset': 0,
  'total_count': 1,
  'items': [
    {
      'period_id': _periodId,
      'team_name': 'T07 Review Team',
      'period_month': '2026-08-01',
      'status': 'ready_for_review',
      'updated_at': '2026-08-30T10:00:00Z',
      'lifecycle': _lifecycleJson(),
    },
  ],
};

final class _RpcClient implements YorksWorkforceRpcClient {
  _RpcClient(this.handler);

  final Map<String, dynamic> Function(
    String name,
    Map<String, Object?> parameters,
  )
  handler;
  final List<String> calls = [];
  final List<Map<String, Object?>> parameters = [];

  @override
  Future<Map<String, dynamic>> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    calls.add(functionName);
    this.parameters.add(parameters);
    return handler(functionName, parameters);
  }
}

final class _ReviewRepository implements YorksWorkforceReviewRepository {
  _ReviewRepository({this.submitFailure});

  final YorksV1DomainException? submitFailure;
  final List<String> submitKeys = [];
  YorksWorkforceReviewLifecycle get lifecycle =>
      YorksWorkforceReviewLifecycle.fromRpcJson(_lifecycleJson());

  @override
  Future<YorksWorkforceReviewQueue> listMonthlyApprovalQueue({
    YorksWorkforceMonthlyPeriodStatus? status,
    int limit = 50,
    int offset = 0,
  }) async => YorksWorkforceReviewQueue.fromRpcJson(_queueJson());

  @override
  Future<YorksWorkforceReviewLifecycle> getMonthlyLifecycle(
    String periodId,
  ) async => lifecycle;

  @override
  Future<YorksWorkforceReviewLifecycle> submitMonthlyPeriod({
    required String periodId,
    required Iterable<String> warningIssueIds,
    required String reason,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    submitKeys.add(idempotencyKey);
    if (submitFailure case final failure?) throw failure;
    return lifecycle;
  }

  @override
  Future<YorksWorkforceReviewLifecycle> returnMonthlyPeriod({
    required String periodId,
    required Iterable<YorksWorkforceAffectedEntry> affectedEntries,
    required String reason,
    String? attachmentReference,
    required int expectedVersion,
    required String idempotencyKey,
  }) async => lifecycle;

  @override
  Future<YorksWorkforceReviewLifecycle> correctMonthlyEntryDuringReview({
    required String periodId,
    required String workDate,
    required YorksWorkforceDailyRosterSaveRow row,
    required String reason,
    required int expectedVersion,
    required String idempotencyKey,
  }) async => lifecycle;

  @override
  Future<YorksWorkforceReviewLifecycle> verifyMonthlyPeriod({
    required String periodId,
    required String reason,
    required int expectedVersion,
    required String idempotencyKey,
  }) async => lifecycle;

  @override
  Future<YorksWorkforceReviewLifecycle> approveAndLockMonthlyPeriod({
    required String periodId,
    required String reason,
    required int expectedVersion,
    required String idempotencyKey,
  }) async => lifecycle;

  @override
  Future<YorksWorkforceReviewLifecycle> requestMonthlyReopen({
    required String periodId,
    required Iterable<YorksWorkforceAffectedEntry> affectedEntries,
    required String reason,
    String? attachmentReference,
    required int expectedVersion,
    required String idempotencyKey,
  }) async => lifecycle;

  @override
  Future<YorksWorkforceReviewLifecycle> authorizeMonthlyReopen({
    required String periodId,
    required String requestId,
    required String reason,
    required int expectedVersion,
    required String idempotencyKey,
  }) async => lifecycle;
}

final class _Connectivity implements ConnectivityService {
  const _Connectivity(this.isOnline);
  @override
  final bool isOnline;
  @override
  Stream<bool> get onChange => const Stream.empty();
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
