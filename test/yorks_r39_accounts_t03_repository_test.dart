import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/accounts/data/accounts_receivables_repository.dart';
import 'package:material_ledger/features/accounts/data/accounts_repository.dart';
import 'package:material_ledger/features/accounts/domain/accounts_decimal.dart';
import 'package:material_ledger/features/accounts/domain/accounts_receivables_inputs.dart';
import 'package:material_ledger/features/accounts/domain/accounts_receivables_models.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'wires all five frozen T03 projections with composite cursors',
    () async {
      final rpc = _RpcClient((name, parameters) {
        return switch (name) {
          'v1_list_client_claims' => _claimsProjection(),
          'v1_get_client_claim' => _claimDetail(),
          'v1_list_client_invoices' => _invoicesProjection(),
          'v1_get_client_invoice' => _invoiceDetail(),
          'v1_list_client_receipts_pdc' => _ledgerProjection(),
          _ => throw StateError(name),
        };
      });
      final repository = _repository(rpc);
      final cursor = YorksAccountsCompositeCursor(
        timestamp: DateTime.parse('2026-08-25T10:00:00Z'),
        id: 'cursor-id',
      );

      await repository.listClaims(
        ' project-1 ',
        status: YorksAccountsClaimStatus.draft,
        before: cursor,
        limit: 25,
      );
      await repository.getClaim('project-1', 'claim-1');
      await repository.listInvoices(
        'project-1',
        status: YorksAccountsInvoiceStatus.submitted,
        dueState: YorksAccountsDueState.dueSoon,
        before: cursor,
        limit: 30,
      );
      await repository.getInvoice('project-1', 'invoice-1');
      await repository.listReceiptsAndPdc(
        'project-1',
        invoiceId: 'invoice-1',
        before: cursor,
        limit: 35,
      );

      expect(rpc.names, [
        'v1_list_client_claims',
        'v1_get_client_claim',
        'v1_list_client_invoices',
        'v1_get_client_invoice',
        'v1_list_client_receipts_pdc',
      ]);
      expect(rpc.parameters[0], {
        'p_project_id': 'project-1',
        'p_status': 'draft',
        'p_before_updated_at': '2026-08-25T10:00:00.000Z',
        'p_before_id': 'cursor-id',
        'p_limit': 25,
      });
      expect(rpc.parameters[2]['p_due_state'], 'due_soon');
      expect(rpc.parameters[4]['p_before_occurred_at'], isNotNull);
      expect(rpc.parameters[4]['p_invoice_id'], 'invoice-1');
    },
  );

  test('wires every frozen T03 command name and exact money strings', () async {
    final rpc = _RpcClient(_commandResponse);
    final repository = _repository(rpc);
    final action = const YorksAccountsEntityActionInput(
      projectId: 'project-1',
      entityId: 'claim-1',
      expectedVersion: 1,
      reason: 'Audited reason',
    );
    final invoiceAction = const YorksAccountsEntityActionInput(
      projectId: 'project-1',
      entityId: 'invoice-1',
      expectedVersion: 2,
      reason: 'Audited reason',
    );

    await repository.createClaimDraft(_claim(), idempotencyKey: 'key-1');
    await repository.updateClaimDraft(
      _claim(claimId: 'claim-1', version: 1),
      idempotencyKey: 'key-2',
    );
    await repository.deleteClaimDraft(action, idempotencyKey: 'key-3');
    await repository.submitClaimToAccounts(action, idempotencyKey: 'key-4');
    await repository.cancelClaim(action, idempotencyKey: 'key-5');
    await repository.createInvoiceDraft(
      _invoiceDraft(),
      idempotencyKey: 'key-6',
    );
    await repository.updateInvoiceDraft(
      _invoiceDraft(invoiceId: 'invoice-1', version: 1),
      idempotencyKey: 'key-7',
    );
    await repository.submitInvoice(
      YorksAccountsInvoiceSubmitInput(
        projectId: 'project-1',
        invoiceId: 'invoice-1',
        expectedVersion: 2,
        submissionDate: YorksAccountsDate.parse('2026-08-26'),
        adminExceptionReason: null,
      ),
      idempotencyKey: 'key-8',
    );
    await repository.markInvoiceUnderCertification(
      invoiceAction,
      idempotencyKey: 'key-9',
    );
    await repository.returnInvoice(invoiceAction, idempotencyKey: 'key-10');
    await repository.cancelInvoice(invoiceAction, idempotencyKey: 'key-11');
    await repository.recordCertification(
      _certification(),
      idempotencyKey: 'key-12',
    );
    await repository.recordPayment(_payment(), idempotencyKey: 'key-13');
    await repository.reversePayment(_reversal(), idempotencyKey: 'key-14');
    await repository.createPdc(_pdc(), idempotencyKey: 'key-15');
    await repository.transitionPdc(_pdcTransition(), idempotencyKey: 'key-16');
    await repository.replacePdc(_pdcReplacement(), idempotencyKey: 'key-17');

    expect(rpc.names, [
      'v1_create_client_claim_draft',
      'v1_update_client_claim_draft',
      'v1_delete_client_claim_draft',
      'v1_submit_client_claim_to_accounts',
      'v1_cancel_client_claim',
      'v1_create_client_invoice_draft',
      'v1_update_client_invoice_draft',
      'v1_submit_client_invoice',
      'v1_mark_client_invoice_under_certification',
      'v1_return_client_invoice',
      'v1_cancel_client_invoice',
      'v1_record_client_certification',
      'v1_record_client_payment',
      'v1_reverse_client_payment',
      'v1_create_client_pdc',
      'v1_transition_client_pdc',
      'v1_replace_client_pdc',
    ]);
    expect(rpc.parameters[0]['p_lines'], [
      {
        'progress_entry_id': 'progress-1',
        'claimed_amount': '1250.5',
        'evidence_reference': 'DO-001',
      },
    ]);
    expect(rpc.parameters[0]['p_admin_exception_reason'], isNull);
    expect(rpc.parameters[1]['p_admin_exception_reason'], isNull);
    expect(rpc.parameters[11]['p_certified_ex_vat'], '1000');
    expect(rpc.parameters[12]['p_amount'], '500');
    expect(rpc.parameters[14]['p_expected_invoice_version'], 2);
    expect(rpc.parameters[15]['p_new_status'], 'received');
    expect(rpc.parameters[16]['p_new_amount'], '500');
  });

  test(
    'feature, authorization and response-shape failures are fail closed',
    () async {
      final disabled = YorksSupabaseAccountsReceivablesRepository(
        featureFlags: _flags(accounts: false),
        connectivity: DefaultConnectivity(),
        rpcClient: _RpcClient((_, _) => throw StateError('must not call')),
      );
      await expectLater(
        disabled.listClaims('project-1'),
        throwsA(_domainCode(YorksV1DomainErrorCode.featureDisabled)),
      );

      final denied = _repository(
        _ThrowingRpcClient(
          const PostgrestException(
            message: 'R39_ACCOUNTS_ACCESS_DENIED',
            code: '42501',
          ),
        ),
      );
      await expectLater(
        denied.listClaims('project-1'),
        throwsA(_domainCode(YorksV1DomainErrorCode.unauthorized)),
      );

      final redacted = _claimsProjection();
      (redacted['capabilities'] as Map)['view_project_commercial_values'] =
          false;
      await expectLater(
        _repository(_RpcClient((_, _) => redacted)).listClaims('project-1'),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );
    },
  );

  test('cross-project response and invalid cursor are rejected', () async {
    final mismatched = _claimsProjection()..['project_id'] = 'project-2';
    await expectLater(
      _repository(_RpcClient((_, _) => mismatched)).listClaims('project-1'),
      throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
    );

    await expectLater(
      _repository(
        _RpcClient((_, _) => throw StateError('must not call')),
      ).listClaims(
        'project-1',
        before: YorksAccountsCompositeCursor(
          timestamp: DateTime.utc(2026),
          id: ' ',
        ),
      ),
      throwsA(_domainCode(YorksV1DomainErrorCode.invalidInput)),
    );
  });
}

YorksSupabaseAccountsReceivablesRepository _repository(
  YorksAccountsRpcClient rpc,
) => YorksSupabaseAccountsReceivablesRepository(
  featureFlags: _flags(),
  connectivity: DefaultConnectivity(),
  rpcClient: rpc,
);

YorksV1FeatureFlags _flags({bool accounts = true}) => YorksV1FeatureFlags(
  foundation: true,
  projects: true,
  boq: true,
  excel: true,
  requests: true,
  arrangement: true,
  logistics: true,
  returnsDocuments: true,
  documents: true,
  accounts: accounts,
);

YorksAccountsClaimDraftInput _claim({String? claimId, int? version}) =>
    YorksAccountsClaimDraftInput(
      projectId: 'project-1',
      claimId: claimId,
      expectedVersion: version,
      claimReference: 'CLAIM-001',
      periodStart: YorksAccountsDate.parse('2026-08-01'),
      periodEnd: YorksAccountsDate.parse('2026-08-31'),
      lines: [
        YorksAccountsClaimLineInput(
          progressEntryId: 'progress-1',
          claimedAmount: YorksAccountsDecimal.parse('1250.50'),
          evidenceReference: 'DO-001',
        ),
      ],
      notes: '',
    );

YorksAccountsInvoiceDraftInput _invoiceDraft({
  String? invoiceId,
  int? version,
}) => YorksAccountsInvoiceDraftInput(
  projectId: 'project-1',
  claimId: invoiceId == null ? 'claim-1' : null,
  invoiceId: invoiceId,
  expectedVersion: version,
  invoiceReference: 'INV-001',
  notes: '',
);

YorksAccountsCertificationInput _certification() =>
    YorksAccountsCertificationInput(
      projectId: 'project-1',
      invoiceId: 'invoice-1',
      expectedVersion: 2,
      certifiedExVat: YorksAccountsDecimal.parse('1000.00'),
      certificationDate: YorksAccountsDate.parse('2026-08-26'),
      certificationReference: 'CERT-001',
      differenceReason: 'Client deduction',
    );

YorksAccountsPaymentInput _payment() => YorksAccountsPaymentInput(
  projectId: 'project-1',
  invoiceId: 'invoice-1',
  expectedVersion: 3,
  paymentDate: YorksAccountsDate.parse('2026-08-26'),
  amount: YorksAccountsDecimal.parse('500.00'),
  paymentMethod: 'bank_transfer',
  paymentReference: 'PAY-001',
  reason: 'Bank advice received',
);

YorksAccountsPaymentReversalInput _reversal() =>
    YorksAccountsPaymentReversalInput(
      projectId: 'project-1',
      invoiceId: 'invoice-1',
      expectedVersion: 4,
      originalPaymentId: 'payment-original',
      reversalDate: YorksAccountsDate.parse('2026-08-26'),
      reversalReference: 'REV-001',
      reason: 'Bank reversal',
    );

YorksAccountsPdcCreateInput _pdc() => YorksAccountsPdcCreateInput(
  projectId: 'project-1',
  invoiceId: 'invoice-1',
  expectedVersion: 2,
  chequeNumber: 'PDC-001',
  chequeDate: YorksAccountsDate.parse('2026-09-20'),
  amount: YorksAccountsDecimal.parse('500.00'),
  bankName: 'Yorks Bank',
);

YorksAccountsPdcTransitionInput _pdcTransition() =>
    YorksAccountsPdcTransitionInput(
      projectId: 'project-1',
      pdcId: 'pdc-1',
      expectedVersion: 1,
      targetStatus: YorksAccountsPdcStatus.received,
      actionDate: YorksAccountsDate.parse('2026-08-26'),
      clearanceReference: null,
      reason: null,
    );

YorksAccountsPdcReplacementInput _pdcReplacement() =>
    YorksAccountsPdcReplacementInput(
      projectId: 'project-1',
      originalPdcId: 'pdc-1',
      expectedVersion: 2,
      chequeNumber: 'PDC-002',
      chequeDate: YorksAccountsDate.parse('2026-09-25'),
      amount: YorksAccountsDecimal.parse('500.00'),
      bankName: 'Yorks Bank',
      reason: 'Replacement requested',
    );

Map<String, dynamic> _commandResponse(
  String name,
  Map<String, Object?> parameters,
) {
  late final String entityId;
  late final String idKey;
  if (name == 'v1_record_client_certification') {
    entityId = 'certification-1';
    idKey = 'certification_id';
  } else if (name.contains('payment')) {
    entityId = 'payment-1';
    idKey = 'payment_id';
  } else if (name.contains('pdc')) {
    entityId = name == 'v1_transition_client_pdc' ? 'pdc-1' : 'pdc-new';
    idKey = 'pdc_id';
  } else if (name.contains('invoice')) {
    entityId = name == 'v1_create_client_invoice_draft'
        ? 'invoice-new'
        : 'invoice-1';
    idKey = 'invoice_id';
  } else {
    entityId = name == 'v1_create_client_claim_draft' ? 'claim-new' : 'claim-1';
    idKey = 'claim_id';
  }
  return {
    'schema_version': 3,
    'replayed': false,
    'project_id': 'project-1',
    'entity_id': entityId,
    idKey: entityId,
    'record_version': 1,
    'status': name == 'v1_delete_client_claim_draft' ? 'deleted' : 'draft',
    'updated_at': '2026-08-26T09:15:00Z',
  };
}

Map<String, dynamic> _claimsProjection() => {
  'schema_version': 3,
  'project_id': 'project-1',
  'claims': const [],
  'next_cursor': null,
  'capabilities': _capabilities(),
  'commands': _commands(),
};

Map<String, dynamic> _claimDetail() => {
  'schema_version': 3,
  'project_id': 'project-1',
  'claim': _claimJson(),
  'capabilities': _capabilities(),
  'commands': _commands(),
};

Map<String, dynamic> _invoicesProjection() => {
  'schema_version': 3,
  'project_id': 'project-1',
  'invoices': const [],
  'next_cursor': null,
  'capabilities': _capabilities(),
  'commands': _commands(),
};

Map<String, dynamic> _invoiceDetail() => {
  'schema_version': 3,
  'project_id': 'project-1',
  'invoice': {
    'invoice_id': 'invoice-1',
    'project_id': 'project-1',
    'claim_id': 'claim-1',
    'invoice_reference': 'INV-001',
    'status': 'submitted',
    'claimed_ex_vat': '1250.50',
    'vat_rate_percent_snapshot': '5.0000',
    'vat_amount_snapshot': '62.53',
    'total_incl_vat_snapshot': '1313.03',
    'payment_terms_days_snapshot': 20,
    'reminder_lead_days_snapshot': 10,
    'submission_date': '2026-08-26',
    'due_date': '2026-09-15',
    'admin_exception_reason': null,
    'notes': null,
    'record_version': 2,
    'certified_ex_vat': '0.00',
    'certified_incl_vat': '0.00',
    'paid_amount': '0.00',
    'amount_paid_till_date': '0.00',
    'still_due': '0.00',
    'pdc_exposure': '0.00',
    'created_by_auth_user_id': 'actor-1',
    'created_by_exact_role': 'accountant',
    'created_at': '2026-08-26T09:00:00Z',
    'updated_at': '2026-08-26T09:15:00Z',
  },
  'claim': _claimJson(),
  'certifications': const [],
  'payments': const [],
  'pdcs': const [],
  'due_state': 'on_track',
  'capabilities': _capabilities(),
  'commands': _commands(),
};

Map<String, dynamic> _ledgerProjection() => {
  'schema_version': 3,
  'project_id': 'project-1',
  'invoice_id': 'invoice-1',
  'entries': const [],
  'next_cursor': null,
  'capabilities': _capabilities(),
  'commands': _commands(),
};

Map<String, dynamic> _claimJson() => {
  'claim_id': 'claim-1',
  'project_id': 'project-1',
  'baseline_revision_id': 'baseline-1',
  'claim_reference': 'CLAIM-001',
  'claim_period_start': '2026-08-01',
  'claim_period_end': '2026-08-31',
  'status': 'draft',
  'notes': null,
  'is_stale': false,
  'stale_reason': null,
  'record_version': 1,
  'created_by_auth_user_id': 'actor-1',
  'created_by_exact_role': 'project_engineer',
  'ready_for_accounts_at': null,
  'cancelled_at': null,
  'cancellation_reason': null,
  'claimed_ex_vat': '1250.50',
  'lines': [
    {
      'line_id': 'line-1',
      'progress_entry_id': 'progress-1',
      'progress_revision_id': 'progress-revision-1',
      'progress_record_version': 2,
      'building_scope_id': 'building-1',
      'stage_key': 'material_supply',
      'stage_value_snapshot': '10000.00',
      'confirmed_percent_snapshot': '25.0000',
      'eligible_amount_snapshot': '2500.00',
      'previously_claimed_amount_snapshot': '0.00',
      'claimed_amount': '1250.50',
      'evidence_reference': 'DO-001',
    },
  ],
  'created_at': '2026-08-26T09:00:00Z',
  'updated_at': '2026-08-26T09:15:00Z',
};

Map<String, dynamic> _capabilities() => {
  'view_project_commercial_values': true,
  'prepare_client_claim': true,
  'manage_client_invoices': true,
  'record_client_certification': true,
  'record_client_payment': true,
  'manage_pdc': true,
};

Map<String, dynamic> _commands() => {
  'create_claim_draft': true,
  'edit_claim_draft': true,
  'submit_claim_to_accounts': true,
  'cancel_claim': true,
  'create_invoice_draft': true,
  'submit_invoice': true,
  'return_invoice': true,
  'cancel_invoice': true,
  'record_certification': true,
  'record_payment': true,
  'reverse_payment': true,
  'create_pdc': true,
  'transition_pdc': true,
  'replace_pdc': true,
};

Matcher _domainCode(YorksV1DomainErrorCode code) =>
    isA<YorksV1DomainException>().having((error) => error.code, 'code', code);

final class _RpcClient implements YorksAccountsRpcClient {
  _RpcClient(this.handler);

  final Map<String, dynamic> Function(
    String name,
    Map<String, Object?> parameters,
  )
  handler;
  final List<String> names = [];
  final List<Map<String, Object?>> parameters = [];

  @override
  Future<Map<String, dynamic>> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    names.add(functionName);
    this.parameters.add(parameters);
    return handler(functionName, parameters);
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
