import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/accounts/data/accounts_repository.dart';
import 'package:material_ledger/features/accounts/domain/accounts_decimal.dart';
import 'package:material_ledger/features/accounts/domain/accounts_inputs.dart';
import 'package:material_ledger/features/accounts/domain/accounts_models.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('repository calls exact read RPC and accepts redacted shape', () async {
    final rpc = _RpcClient((functionName, parameters) {
      expect(functionName, 'v1_get_project_commercial_baseline');
      expect(parameters, {'p_project_id': 'project-1'});
      return _baselineResponse();
    });
    final repository = _repository(rpc: rpc);

    final projection = await repository.getBaseline(' project-1 ');

    expect(projection.projectId, 'project-1');
    expect(projection.baseline, isNull);
    expect(projection.capabilities.canViewValues, isFalse);
  });

  test('progress read forwards every server-authoritative filter', () async {
    final rpc = _RpcClient((functionName, parameters) {
      expect(functionName, 'v1_list_billing_progress');
      expect(parameters, {
        'p_project_id': 'project-1',
        'p_building_scope_id': 'building-1',
        'p_stage_key': 'design',
        'p_action_owner': 'project_engineer',
        'p_has_evidence': true,
      });
      return _progressResponse();
    });

    await _repository(rpc: rpc).listProgress(
      'project-1',
      buildingScopeId: ' building-1 ',
      stageKey: ' design ',
      actionOwner: ' project_engineer ',
      hasEvidence: true,
    );
  });

  test(
    'revision history uses the exact cursor RPC and typed projection',
    () async {
      final rpc = _RpcClient((functionName, parameters) {
        expect(functionName, 'v1_list_billing_progress_revisions');
        expect(parameters, {
          'p_project_id': 'project-1',
          'p_progress_entry_id': 'progress-1',
          'p_before_revision_number': 3,
          'p_limit': 25,
        });
        return _revisionResponse();
      });

      final projection = await _repository(rpc: rpc).listProgressRevisions(
        'project-1',
        'progress-1',
        beforeRevisionNumber: 3,
        limit: 25,
      );

      expect(projection.schemaVersion, 2);
      expect(projection.revisions.single.action, 'confirmed');
      expect(
        projection.revisions.single.newConfirmedPercent.canonicalText,
        '35',
      );
      expect(projection.nextCursor, 2);
    },
  );

  test('revision history rejects a non-positive cursor before RPC', () async {
    final rpc = _RpcClient((_, _) => throw StateError('must not call'));

    await expectLater(
      _repository(rpc: rpc).listProgressRevisions(
        'project-1',
        'progress-1',
        beforeRevisionNumber: 0,
      ),
      throwsA(_domainCode(YorksV1DomainErrorCode.invalidInput)),
    );
  });

  test(
    'initialize sends exact decimal strings and explicit VAT snapshot',
    () async {
      final rpc = _RpcClient((functionName, parameters) {
        expect(functionName, 'v1_initialize_project_commercial_baseline');
        expect(parameters['p_contract_value'], '8400000');
        expect(parameters['p_vat_rate'], '5');
        expect(parameters['p_payment_terms_days'], 20);
        expect(parameters['p_idempotency_key'], 'key-1');
        return _commandResponse(includeBaselineIdentity: true);
      });

      final result = await _repository(
        rpc: rpc,
      ).initializeBaseline(_baselineInput(), idempotencyKey: 'key-1');

      expect(result.entityId, 'revision-1');
      expect(result.recordVersion, 1);
    },
  );

  test('feature flag is fail closed before RPC', () async {
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
        accounts: false,
      ),
    );

    await expectLater(
      repository.getBaseline('project-1'),
      throwsA(_domainCode(YorksV1DomainErrorCode.featureDisabled)),
    );
    expect(rpc.calls, isEmpty);
  });

  test('maps denied and stale domain failures', () async {
    final denied = _repository(
      rpc: _ThrowingRpcClient(
        const PostgrestException(
          message: 'R39_ACCOUNTS_ACCESS_DENIED',
          code: '42501',
        ),
      ),
    );
    await expectLater(
      denied.getBaseline('project-1'),
      throwsA(_domainCode(YorksV1DomainErrorCode.unauthorized)),
    );

    final stale = _repository(
      rpc: _ThrowingRpcClient(
        const PostgrestException(
          message: 'R39_ACCOUNTS_STALE_VERSION',
          code: '40001',
        ),
      ),
    );
    await expectLater(
      stale.getBaseline('project-1'),
      throwsA(_domainCode(YorksV1DomainErrorCode.conflict)),
    );
  });

  test('maps idempotency payload reuse to conflict before SQLSTATE', () async {
    final repository = _repository(
      rpc: _ThrowingRpcClient(
        const PostgrestException(
          message: 'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD',
          code: '22023',
        ),
      ),
    );

    await expectLater(
      repository.initializeBaseline(_baselineInput(), idempotencyKey: 'key-1'),
      throwsA(_domainCode(YorksV1DomainErrorCode.conflict)),
    );
  });

  test(
    'suggestion requires evidence while confirmation defers increase policy',
    () async {
      final rpc = _RpcClient((functionName, parameters) {
        expect(functionName, 'v1_confirm_billing_progress');
        expect(parameters['p_evidence_summary'], '');
        expect(parameters['p_evidence_document_ids'], isEmpty);
        return _commandResponse(entityId: 'progress-1');
      });
      final repository = _repository(rpc: rpc);
      final input = _progressInputWithoutEvidence();

      await expectLater(
        repository.suggestProgress(input, idempotencyKey: 'suggest-key'),
        throwsA(_domainCode(YorksV1DomainErrorCode.invalidInput)),
      );
      expect(rpc.calls, isEmpty);

      final result = await repository.confirmProgress(
        input,
        idempotencyKey: 'confirm-key',
      );
      expect(result.entityId, 'progress-1');
      expect(rpc.calls, ['v1_confirm_billing_progress']);
    },
  );

  test('rejects numeric money response instead of rounding it', () async {
    final response = _baselineResponse(canViewValues: true);
    response['baseline'] = {
      'revision_id': 'revision-1',
      'revision_number': 1,
      'record_version': 1,
      'status': 'current',
      'contract_value': 8400000.0,
      'currency_code': 'AED',
      'vat_rate': '5.0000',
      'payment_terms_days': 20,
      'reminder_lead_days': 10,
      'management_review_policy': <String, Object?>{
        'always_required': false,
        'threshold_amount': null,
        'confirming_exact_roles': <String>[],
      },
    };

    await expectLater(
      _repository(rpc: _RpcClient((_, _) => response)).getBaseline('project-1'),
      throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
    );
  });

  test('rejects mismatched read projection identities', () async {
    final baseline = _baselineResponse()..['project_id'] = 'project-2';
    await expectLater(
      _repository(rpc: _RpcClient((_, _) => baseline)).getBaseline('project-1'),
      throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
    );

    final progress = _progressResponse()
      ..['progress'] = [
        {
          ...(_progressResponse()['progress']! as List).single
              as Map<String, dynamic>,
          'project_id': 'project-2',
        },
      ];
    await expectLater(
      _repository(
        rpc: _RpcClient((_, _) => progress),
      ).listProgress('project-1'),
      throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
    );

    final revisions = _revisionResponse()..['progress_entry_id'] = 'progress-2';
    await expectLater(
      _repository(
        rpc: _RpcClient((_, _) => revisions),
      ).listProgressRevisions('project-1', 'progress-1'),
      throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
    );
  });

  test('binds every command result to its requested project', () async {
    final operations =
        <Future<YorksAccountsCommandResult> Function(YorksAccountsRepository)>[
          (repository) => repository.initializeBaseline(
            _baselineInput(),
            idempotencyKey: 'initialize-key',
          ),
          (repository) => repository.reviseBaseline(
            _baselineInput(expectedBaselineVersion: 1),
            idempotencyKey: 'revise-key',
          ),
          (repository) => repository.suggestProgress(
            _progressInputWithEvidence(),
            idempotencyKey: 'suggest-key',
          ),
          (repository) => repository.confirmProgress(
            _progressInputWithoutEvidence(),
            idempotencyKey: 'confirm-key',
          ),
          (repository) => repository.reviewProgress(
            const YorksAccountsReviewInput(
              projectId: 'project-1',
              progressEntryId: 'progress-1',
              expectedVersion: 1,
              decision: YorksAccountsReviewDecision.approved,
              reason: 'Management review complete',
            ),
            idempotencyKey: 'review-key',
          ),
        ];

    for (final operation in operations) {
      final repository = _repository(
        rpc: _RpcClient((functionName, _) {
          final isBaseline = functionName.contains('baseline');
          return _commandResponse(
            projectId: 'project-2',
            entityId: isBaseline ? 'revision-1' : 'progress-1',
            includeBaselineIdentity: isBaseline,
          );
        }),
      );
      await expectLater(
        operation(repository),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );
    }
  });

  test('binds progress and baseline command entity identities', () async {
    await expectLater(
      _repository(
        rpc: _RpcClient((_, _) => _commandResponse(entityId: 'progress-2')),
      ).confirmProgress(
        _progressInputWithoutEvidence(),
        idempotencyKey: 'confirm-key',
      ),
      throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
    );

    await expectLater(
      _repository(
        rpc: _RpcClient(
          (_, _) => _commandResponse(
            entityId: 'revision-1',
            baselineRevisionId: 'revision-2',
            includeBaselineIdentity: true,
          ),
        ),
      ).initializeBaseline(_baselineInput(), idempotencyKey: 'baseline-key'),
      throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
    );
  });
}

YorksSupabaseAccountsRepository _repository({
  required YorksAccountsRpcClient rpc,
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
    accounts: true,
  ),
}) {
  return YorksSupabaseAccountsRepository(
    featureFlags: featureFlags,
    connectivity: DefaultConnectivity(),
    rpcClient: rpc,
  );
}

YorksAccountsBaselineInput _baselineInput({int? expectedBaselineVersion}) =>
    YorksAccountsBaselineInput(
      projectId: 'project-1',
      contractValue: YorksAccountsDecimal.parse('8400000.00'),
      currencyCode: 'AED',
      vatRate: YorksAccountsDecimal.parse('5.0000'),
      paymentTermsDays: 20,
      reminderLeadDays: 10,
      buildingAllocations: [
        YorksAccountsBuildingAllocationInput(
          buildingScopeId: 'building-1',
          allocationPercent: YorksAccountsDecimal.hundred,
          isCommonScope: false,
        ),
      ],
      stageAllocations: [
        YorksAccountsStageAllocationInput(
          stageKey: 'design',
          stageLabel: 'Design',
          position: 1,
          allocationPercent: YorksAccountsDecimal.hundred,
        ),
      ],
      managementReviewPolicy: YorksAccountsManagementReviewPolicy(
        alwaysRequired: false,
        thresholdAmount: null,
        confirmingExactRoles: const [],
      ),
      reason: 'Approved baseline',
      expectedBaselineVersion: expectedBaselineVersion,
    );

YorksAccountsProgressInput _progressInputWithoutEvidence() =>
    YorksAccountsProgressInput(
      projectId: 'project-1',
      progressEntryId: 'progress-1',
      expectedVersion: 2,
      percent: YorksAccountsDecimal.parse('20'),
      evidenceSummary: '',
      evidenceDocumentIds: const [],
      reason: 'Confirm a defensible non-increase',
    );

YorksAccountsProgressInput _progressInputWithEvidence() =>
    YorksAccountsProgressInput(
      projectId: 'project-1',
      progressEntryId: 'progress-1',
      expectedVersion: 2,
      percent: YorksAccountsDecimal.parse('20'),
      evidenceSummary: 'Inspection complete',
      evidenceDocumentIds: const [],
      reason: 'Record site progress',
    );

Map<String, dynamic> _baselineResponse({bool canViewValues = false}) => {
  'schema_version': 2,
  'project_id': 'project-1',
  'baseline': null,
  'physical_buildings': <Object?>[],
  'stage_templates': <Object?>[],
  'building_allocations': <Object?>[],
  'stage_allocations': <Object?>[],
  'capabilities': {
    'can_view': true,
    'can_view_values': canViewValues,
    'can_configure': false,
    'can_suggest': true,
    'can_confirm': false,
    'can_review': false,
  },
  'commands': <String, bool>{},
};

Map<String, dynamic> _commandResponse({
  String projectId = 'project-1',
  String entityId = 'revision-1',
  String? baselineRevisionId,
  bool includeBaselineIdentity = false,
}) => {
  'replayed': false,
  'project_id': projectId,
  'entity_id': entityId,
  if (includeBaselineIdentity)
    'baseline_revision_id': baselineRevisionId ?? entityId,
  'record_version': 1,
  'baseline_revision_number': 1,
  'status': 'current',
  'updated_at': '2026-08-25T12:00:00Z',
};

Map<String, dynamic> _progressResponse() => {
  'schema_version': 2,
  'project_id': 'project-1',
  'baseline_revision_id': 'revision-1',
  'baseline_revision_number': 1,
  'progress': [
    {
      'progress_entry_id': 'progress-1',
      'project_id': 'project-1',
      'baseline_revision_id': 'revision-1',
      'building_scope_id': 'building-1',
      'stage_key': 'design',
      'stage_position': 1,
      'record_version': 1,
      'suggested_percent': '0',
      'confirmed_percent': '0',
      'review_status': 'not_required',
      'evidence_document_ids': <Object?>[],
      'action_owner': 'site_engineer',
      'revisions': <Object?>[],
      'next_actions': <Object?>[],
    },
  ],
  'totals': null,
  'capabilities': {
    'can_view': true,
    'can_view_values': false,
    'can_configure': false,
    'can_suggest': true,
    'can_confirm': false,
    'can_review': false,
  },
  'commands': <String, bool>{},
  'next_actions': <Object?>[],
};

Map<String, dynamic> _revisionResponse() => {
  'schema_version': 2,
  'project_id': 'project-1',
  'progress_entry_id': 'progress-1',
  'revisions': [
    {
      'revision_id': 'progress-revision-1',
      'revision_number': 2,
      'action': 'confirmed',
      'previous_suggested_percent': '40.0000',
      'new_suggested_percent': '40.0000',
      'previous_confirmed_percent': '20.0000',
      'new_confirmed_percent': '35.0000',
      'previous_review_status': 'not_required',
      'new_review_status': 'pending',
      'evidence_summary': 'Inspection report',
      'evidence_document_ids': ['document-1'],
      'reason': 'Confirmed against inspection',
      'actor_auth_user_id': 'actor-1',
      'actor_role': 'engineer',
      'actor_exact_role': 'project_engineer',
      'occurred_at': '2026-08-25T12:00:00Z',
    },
  ],
  'next_cursor': 2,
  'capabilities': {
    'can_view': true,
    'can_view_values': false,
    'can_configure': false,
    'can_suggest': false,
    'can_confirm': true,
    'can_review': false,
  },
};

Matcher _domainCode(YorksV1DomainErrorCode code) =>
    isA<YorksV1DomainException>().having((error) => error.code, 'code', code);

final class _RpcClient implements YorksAccountsRpcClient {
  _RpcClient(this._handler);
  final Map<String, dynamic> Function(
    String functionName,
    Map<String, Object?> parameters,
  )
  _handler;
  final List<String> calls = [];

  @override
  Future<Map<String, dynamic>> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    calls.add(functionName);
    return _handler(functionName, parameters);
  }
}

final class _ThrowingRpcClient implements YorksAccountsRpcClient {
  const _ThrowingRpcClient(this.error);
  final Object error;

  @override
  Future<Map<String, dynamic>> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) => Future.error(error);
}
