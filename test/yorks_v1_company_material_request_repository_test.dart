import 'dart:async';
import 'package:material_ledger/shared/models/analytics_event.dart';
import 'package:material_ledger/shared/services/analytics_service.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_company_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_company_material_request_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_material_request_repository.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';

void main() {
  group('Company Material Request repository', () {
    test(
      'Company analytics distinguishes confirmed responses from unknown transport outcomes',
      () async {
        final analytics = _CompanyAnalytics();
        final rpc = _RecordingRpc();
        final repository = YorksV1SupabaseCompanyMaterialRequestRepository(
          featureFlags: _enabledFlags,
          connectivity: const _Connectivity(true),
          rpcClient: rpc,
          analytics: analytics,
        );
        await repository.decide(
          requestId: _requestId,
          expectedVersion: 1,
          decision: YorksV1CompanyMaterialRequestDecisionType.returned,
          idempotencyKey: 'private-key',
          reason: 'Private reason',
        );
        expect(
          analytics.events.single,
          AnalyticsEvent.companyRequestActionConfirmed,
        );
        expect(
          analytics.properties.single[AnalyticsProperty.workflow],
          'company_material_request',
        );
        expect(
          analytics.properties.toString(),
          isNot(contains('Private reason')),
        );
        expect(analytics.properties.toString(), isNot(contains(_requestId)));
        rpc.failTransport = true;
        await expectLater(
          repository.decide(
            requestId: _requestId,
            expectedVersion: 1,
            decision: YorksV1CompanyMaterialRequestDecisionType.returned,
            idempotencyKey: 'private-key',
            reason: 'Private reason',
          ),
          throwsA(isA<YorksV1DomainException>()),
        );
        expect(
          analytics.events.last,
          AnalyticsEvent.companyRequestActionUnconfirmed,
        );
        expect(
          analytics.events,
          isNot(contains(AnalyticsEvent.companyRequestActionFailed)),
        );
      },
    );

    test(
      'workspace search sends a bounded server page and preserves totals',
      () async {
        final rpc = _RecordingRpc();
        final repository = _repository(rpc);
        final page = await repository.listPage(
          view: 'requests',
          query: '  helmet  ',
          offset: 15,
        );
        expect(page.totalCount, 31);
        expect(page.items.single.requestNumber, 'CMR-000001');
        expect(rpc.calls.single.parameters, {
          'p_view': 'requests',
          'p_query': 'helmet',
          'p_offset': 15,
          'p_limit': 15,
        });
      },
    );
    test(
      'fails closed before RPC when rollout is disabled or offline',
      () async {
        final rpc = _RecordingRpc();
        final disabled = YorksV1SupabaseCompanyMaterialRequestRepository(
          featureFlags: const YorksV1FeatureFlags(),
          connectivity: const _Connectivity(true),
          rpcClient: rpc,
        );
        final offline = YorksV1SupabaseCompanyMaterialRequestRepository(
          featureFlags: _enabledFlags,
          connectivity: const _Connectivity(false),
          rpcClient: rpc,
        );

        await expectLater(
          disabled.listDraftOptions(),
          throwsA(
            isA<YorksV1DomainException>().having(
              (error) => error.code,
              'code',
              YorksV1DomainErrorCode.featureDisabled,
            ),
          ),
        );
        await expectLater(
          offline.listDraftOptions(),
          throwsA(
            isA<YorksV1DomainException>().having(
              (error) => error.code,
              'code',
              YorksV1DomainErrorCode.offline,
            ),
          ),
        );
        expect(rpc.calls, isEmpty);
      },
    );

    test(
      'uses only the narrow option and participant preflight RPCs',
      () async {
        final rpc = _RecordingRpc();
        final repository = _repository(rpc);

        final options = await repository.listDraftOptions();
        expect(options, hasLength(1));
        expect(options.single.categoryName, 'Safety and PPE');
        expect(options.single.beneficiaries.single.displayName, 'Amina Hassan');

        final preflight = await repository.preflightApproval(
          categoryId: _categoryId,
          responsibleUnitId: _unitId,
          beneficiaryAuthUserId: _beneficiaryId,
          authorizedReceiverAuthUserId: _beneficiaryId,
        );
        expect(preflight.approver.displayName, 'Nadia Khalid');
        expect(rpc.calls.map((call) => call.functionName), [
          'v1_list_company_material_request_draft_options',
          'v1_company_material_request_approval_choices',
        ]);
        expect(rpc.calls.last.parameters, {
          'p_category_id': _categoryId,
          'p_responsible_unit_id': _unitId,
          'p_beneficiary_auth_user_id': _beneficiaryId,
          'p_authorized_receiver_auth_user_id': _beneficiaryId,
          'p_selected_approver_auth_user_id': null,
        });
      },
    );

    test(
      'searches the Company catalogue without project or stock input',
      () async {
        final rpc = _RecordingRpc();
        final repository = _repository(rpc);

        final results = await repository.searchMaterials(
          categoryId: _categoryId,
          responsibleUnitId: _unitId,
          query: ' helmet ',
        );

        expect(results.single.description, 'Safety helmet');
        expect(results.single.size, 'Adjustable');
        expect(results.single.model, 'H-700');
        expect(
          rpc.calls.single.functionName,
          'v1_search_company_material_request_candidates',
        );
        expect(rpc.calls.single.parameters, {
          'p_category_id': _categoryId,
          'p_responsible_unit_id': _unitId,
          'p_query': 'helmet',
          'p_limit': 18,
        });
      },
    );

    test(
      'atomically saves and submits the exact company-only payload',
      () async {
        final rpc = _RecordingRpc();
        final repository = _repository(rpc);

        final result = await repository.saveAndSubmit(_draft);

        expect(result.state, 'awaiting_company_approval');
        expect(result.requestNumber, 'CMR-000001');
        expect(result.approver?.displayName, 'Nadia Khalid');
        expect(rpc.calls, hasLength(1));
        final call = rpc.calls.single;
        expect(
          call.functionName,
          'v1_save_and_submit_company_material_request',
        );
        expect(call.parameters['p_idempotency_key'], _idempotencyKey);
        final payload = call.parameters['p_payload']! as Map<String, dynamic>;
        expect(payload['expected_version'], 0);
        expect(payload['beneficiary_auth_user_id'], _beneficiaryId);
        expect(payload['authorized_receiver_auth_user_id'], _beneficiaryId);
        expect(payload['lines'], hasLength(1));
        expect(payload, isNot(contains('project_id')));
        expect(payload, isNot(contains('boq_group_id')));
      },
    );

    test(
      'lists assigned approvals and sends one exact decision command',
      () async {
        final rpc = _RecordingRpc();
        final repository = _repository(rpc);

        final inbox = await repository.listApprovalInbox();
        expect(inbox, hasLength(1));
        expect(inbox.single.requestNumber, 'CMR-000001');
        expect(inbox.single.lineCount, 1);

        final request = await repository.getRequest(_requestId);
        expect(request.canDecide, isTrue);

        final result = await repository.decide(
          requestId: _requestId,
          expectedVersion: 2,
          decision: YorksV1CompanyMaterialRequestDecisionType.returned,
          idempotencyKey: _decisionKey,
          reason: ' Confirm the size. ',
        );

        expect(result.state, 'returned_for_changes');
        expect(result.decisions.single.reason, 'Confirm the size.');
        expect(rpc.calls.map((call) => call.functionName), [
          'v1_list_company_material_request_work_inbox',
          'v1_company_material_request_projection',
          'v1_decide_company_material_request',
        ]);
        expect(rpc.calls.last.parameters, {
          'p_payload': {
            'request_id': _requestId,
            'expected_version': 2,
            'decision': 'returned',
            'reason': 'Confirm the size.',
          },
          'p_idempotency_key': _decisionKey,
        });
      },
    );

    test(
      'loads protected company issue history with the issue note identity',
      () async {
        final rpc = _RecordingRpc();
        final repository = _repository(rpc);

        final register = await repository.listRegister(
          YorksV1CompanyMaterialRequestRegisterView.issueHistory,
        );
        expect(register.single.id, _requestId);
        expect(register.single.requestNumber, 'CM-ISS-0000001');
        expect(rpc.calls.first.parameters, {
          'p_view': 'issue_history',
          'p_limit': 100,
        });
        expect(rpc.calls, hasLength(1));
      },
    );

    test('withdraws only an explicitly approved remainder', () async {
      final rpc = _RecordingRpc();
      final repository = _repository(rpc);

      await repository.withdrawRemainder(
        requestId: _requestId,
        expectedVersion: 8,
        reason: 'Demand cancelled by management',
        lines: const [
          {'request_line_id': _lineId, 'quantity': '4'},
        ],
        idempotencyKey: _idempotencyKey,
      );

      expect(
        rpc.calls.single.functionName,
        'v1_withdraw_company_material_request_remainder',
      );
      expect(rpc.calls.single.parameters, {
        'p_payload': {
          'request_id': _requestId,
          'expected_version': 8,
          'reason': 'Demand cancelled by management',
          'lines': const [
            {'request_line_id': _lineId, 'quantity': '4'},
          ],
        },
        'p_idempotency_key': _idempotencyKey,
      });
    });
  });
}

YorksV1SupabaseCompanyMaterialRequestRepository _repository(
  YorksV1MaterialRequestRpcClient rpc,
) => YorksV1SupabaseCompanyMaterialRequestRepository(
  featureFlags: _enabledFlags,
  connectivity: const _Connectivity(true),
  rpcClient: rpc,
);

const _enabledFlags = YorksV1FeatureFlags(
  foundation: true,
  projects: true,
  boq: true,
  excel: true,
  requests: true,
  companyMaterialRequests: true,
);

const _categoryId = 'c1000000-0000-4000-8000-000000000001';
const _unitId = 'c1000000-0000-4000-8000-000000000002';
const _beneficiaryId = '10000000-0000-4000-8000-000000000002';
const _approverId = '10000000-0000-4000-8000-000000000001';
const _requestId = 'c1000000-0000-4000-8000-000000000010';
const _lineId = 'c1000000-0000-4000-8000-000000000011';
const _routeId = 'c1000000-0000-4000-8000-000000000003';
const _idempotencyKey = 'c1000000-0000-4000-8000-000000000012';
const _decisionKey = 'c1000000-0000-4000-8000-000000000013';

const _draft = YorksV1CompanyMaterialRequestDraft(
  id: _requestId,
  recordVersion: 0,
  submissionIdempotencyKey: _idempotencyKey,
  categoryId: _categoryId,
  responsibleUnitId: _unitId,
  purpose: 'Replace worn safety jacket',
  timing: YorksV1MaterialRequestTiming.normal,
  deliveryCollectionPoint: 'Workshop issue desk',
  beneficiaryAuthUserId: _beneficiaryId,
  authorizedReceiverAuthUserId: _beneficiaryId,
  lines: [
    YorksV1CompanyMaterialRequestLine(
      id: _lineId,
      displayOrder: 1,
      description: 'High-visibility jacket, size L',
      quantity: '1',
      unit: 'Nos',
    ),
  ],
);

final class _RecordingRpc implements YorksV1MaterialRequestRpcClient {
  final calls = <_RpcCall>[];
  bool failTransport = false;

  @override
  Future<Object?> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    calls.add(_RpcCall(functionName, parameters));
    if (failTransport) throw TimeoutException('private details');
    return switch (functionName) {
      'v1_list_company_material_request_draft_options' => [_optionJson],
      'v1_company_material_request_workspace_page' => {
        'items': [_inboxJson],
        'total_count': 31,
      },
      'v1_company_material_request_approval_choices' => _preflightJson,
      'v1_search_company_material_request_candidates' => const [
        {
          'id': 'c1000000-0000-4000-8000-000000000099',
          'source_kind': 'inventory',
          'item_code': 'PPE-001',
          'item_description': 'Safety helmet',
          'brand_origin': '3M / USA',
          'size': 'Adjustable',
          'model': 'H-700',
          'unit': 'Nos',
        },
      ],
      'v1_save_and_submit_company_material_request' => _requestJson,
      'v1_list_company_material_request_work_inbox' => [_inboxJson],
      'v1_company_material_request_projection' => {
        ..._requestJson,
        'record_version': 2,
        'can_decide': true,
        'decisions': const [],
      },
      'v1_decide_company_material_request' => _returnedRequestJson,
      'v1_list_company_material_request_register' => [_registerJson],
      'v1_withdraw_company_material_request_remainder' => _returnedRequestJson,
      _ => throw StateError('Unexpected RPC: $functionName'),
    };
  }
}

final class _RpcCall {
  const _RpcCall(this.functionName, this.parameters);
  final String functionName;
  final Map<String, Object?> parameters;
}

final class _Connectivity implements ConnectivityService {
  const _Connectivity(this.isOnline);

  @override
  final bool isOnline;

  @override
  Stream<bool> get onChange => const Stream.empty();
}

const _optionJson = <String, dynamic>{
  'category_id': _categoryId,
  'category_code': 'ppe',
  'category_name': 'Safety and PPE',
  'responsible_unit_id': _unitId,
  'responsible_unit_code': 'WORKSHOP',
  'responsible_unit_name': 'Workshop',
  'beneficiaries': [
    {'auth_user_id': _beneficiaryId, 'display_name': 'Amina Hassan'},
  ],
  'receivers': [
    {'auth_user_id': _beneficiaryId, 'display_name': 'Amina Hassan'},
  ],
};

const _preflightJson = <String, dynamic>{
  'approval_route_id': _routeId,
  'policy_version': 'cmr-test-v1',
  'approver_auth_user_id': _approverId,
  'approver_display_name': 'Nadia Khalid',
};

const _requestJson = <String, dynamic>{
  'id': _requestId,
  'record_version': 1,
  'state': 'awaiting_company_approval',
  'request_number': 'CMR-000001',
  'category_name': 'Safety and PPE',
  'responsible_unit_name': 'Workshop',
  'purpose': 'Replace worn safety jacket',
  'timing': 'normal',
  'scheduled_date': null,
  'delivery_collection_point': 'Workshop issue desk',
  'beneficiary_auth_user_id': _beneficiaryId,
  'beneficiary_display_name': 'Amina Hassan',
  'submitted_at': '2026-09-18T09:00:00Z',
  'authorized_receiver_auth_user_id': _beneficiaryId,
  'authorized_receiver_display_name': 'Amina Hassan',
  'requester_display_name': 'Site Engineer',
  'requester_exact_role': 'site_engineer',
  'approver_auth_user_id': _approverId,
  'approver_display_name': 'Nadia Khalid',
  'approval_policy_version': 'cmr-test-v1',
  'lines': [
    {
      'id': _lineId,
      'display_order': 1,
      'item_description': 'High-visibility jacket, size L',
      'brand_origin': null,
      'requested_qty': '1',
      'unit': 'Nos',
    },
  ],
};

const _inboxJson = <String, dynamic>{
  'id': _requestId,
  'request_number': 'CMR-000001',
  'record_version': 2,
  'state': 'awaiting_company_approval',
  'category_name': 'Safety and PPE',
  'responsible_unit_name': 'Workshop',
  'purpose': 'Replace worn safety jacket',
  'requester_display_name': 'Site Engineer',
  'beneficiary_display_name': 'Amina Hassan',
  'submitted_at': '2026-09-18T09:30:00Z',
  'line_count': 1,
};

const _registerJson = <String, dynamic>{
  'row_id': _requestId,
  'request_id': _requestId,
  'request_number': 'CMR-000001',
  'record_version': 7,
  'state': 'closed',
  'category_name': 'Safety and PPE',
  'responsible_unit_name': 'Workshop',
  'purpose': 'Replace worn safety jacket',
  'requester_display_name': 'Site Engineer',
  'beneficiary_display_name': 'Amina Hassan',
  'submitted_at': '2026-09-18T09:00:00Z',
  'updated_at': '2026-09-18T11:00:00Z',
  'line_count': 1,
  'approved_qty': '1.0000',
  'arranged_qty': '1.0000',
  'good_received_qty': '1.0000',
  'handed_over_qty': '1.0000',
  'latest_issue_note_number': 'CM-ISS-0000001',
};

final _returnedRequestJson = <String, dynamic>{
  ..._requestJson,
  'record_version': 3,
  'state': 'returned_for_changes',
  'can_decide': false,
  'decisions': const [
    {
      'id': _decisionKey,
      'decision': 'returned',
      'reason': 'Confirm the size.',
      'request_record_version': 2,
      'decided_by_display_name': 'Nadia Khalid',
      'decided_by_exact_role': 'project_engineer',
      'decided_at': '2026-09-18T10:00:00Z',
    },
  ],
};

class _CompanyAnalytics extends NoopAnalyticsService {
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
