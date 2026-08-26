import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/accounts/data/accounts_repository.dart';
import 'package:material_ledger/features/accounts/data/accounts_supplier_repository.dart';
import 'package:material_ledger/features/accounts/domain/accounts_decimal.dart';
import 'package:material_ledger/features/accounts/domain/accounts_receivables_inputs.dart';
import 'package:material_ledger/features/accounts/domain/accounts_supplier_inputs.dart';
import 'package:material_ledger/features/accounts/domain/accounts_supplier_models.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('wires protected supplier list/detail filters and cursor', () async {
    final rpc = _RpcClient(
      (name, _) => switch (name) {
        'v1_list_supplier_bills' => _listProjection(),
        'v1_get_supplier_bill' => _detailProjection(),
        _ => throw StateError(name),
      },
    );
    final repository = _repository(rpc);
    await repository.listBills(
      ' project-1 ',
      search: ' SUP ',
      matchStatus: YorksAccountsSupplierMatchStatus.matched,
      paymentStatus: YorksAccountsSupplierPaymentStatus.approved,
      before: YorksAccountsSupplierBillCursor(
        updatedAt: DateTime.parse('2026-08-26T09:15:00Z'),
        supplierBillId: 'bill-2',
      ),
      limit: 15,
    );
    await repository.getBill('project-1', 'bill-1');

    expect(rpc.names, ['v1_list_supplier_bills', 'v1_get_supplier_bill']);
    expect(rpc.parameters.first, {
      'p_project_id': 'project-1',
      'p_search': 'SUP',
      'p_match_status': 'matched',
      'p_payment_status': 'approved',
      'p_cursor_updated_at': '2026-08-26T09:15:00.000Z',
      'p_cursor_id': 'bill-2',
      'p_limit': 15,
    });
  });

  test('wires every T04 command without manual receipt quantity', () async {
    final rpc = _RpcClient(_commandResponse);
    final repository = _repository(rpc);
    await repository.createBillDraft(_draft(), idempotencyKey: 'key-1');
    await repository.updateBillDraft(
      _draft(billId: 'bill-1', version: 1),
      idempotencyKey: 'key-2',
    );
    await repository.approveBill(
      const YorksAccountsSupplierBillApprovalInput(
        projectId: 'project-1',
        supplierBillId: 'bill-1',
        expectedVersion: 2,
      ),
      idempotencyKey: 'key-3',
    );
    await repository.recordPayment(_payment(), idempotencyKey: 'key-4');
    await repository.reversePayment(_reversal(), idempotencyKey: 'key-5');
    await repository.cancelBill(
      const YorksAccountsSupplierBillCancelInput(
        projectId: 'project-1',
        supplierBillId: 'bill-1',
        expectedVersion: 5,
        reason: 'Duplicate supplier invoice',
      ),
      idempotencyKey: 'key-6',
    );

    expect(rpc.names, [
      'v1_create_supplier_bill_draft',
      'v1_update_supplier_bill_draft',
      'v1_approve_supplier_bill',
      'v1_record_supplier_payment',
      'v1_reverse_supplier_payment',
      'v1_cancel_supplier_bill',
    ]);
    expect(rpc.parameters[0]['p_ex_vat_amount'], '1000');
    expect(rpc.parameters[0]['p_vat_rate_percent'], '5');
    expect(rpc.parameters[0]['p_accepted_receipt_review_id'], 'receipt-1');
    expect(rpc.parameters[0], isNot(contains('p_accepted_quantity')));
    expect(rpc.parameters[0], isNot(contains('p_delivery_reference')));
    expect(rpc.parameters[3]['p_amount'], '500');
    expect(rpc.parameters[3]['p_admin_exception_reason'], isNull);
    expect(rpc.parameters[4]['p_original_payment_id'], 'payment-1');
  });

  test('feature, authorization and response shape fail closed', () async {
    final disabled = YorksSupabaseAccountsSupplierRepository(
      featureFlags: _flags(accounts: false),
      connectivity: DefaultConnectivity(),
      rpcClient: _RpcClient((_, _) => throw StateError('must not call')),
    );
    await expectLater(
      disabled.listBills('project-1'),
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
      denied.listBills('project-1'),
      throwsA(_domainCode(YorksV1DomainErrorCode.unauthorized)),
    );

    final numeric = _listProjection();
    ((numeric['items'] as List).single as Map)['total_incl_vat'] = 1050.0;
    await expectLater(
      _repository(_RpcClient((_, _) => numeric)).listBills('project-1'),
      throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
    );
  });

  test('cross-project response and invalid cursor are rejected', () async {
    final mismatched = _listProjection()..['project_id'] = 'project-2';
    await expectLater(
      _repository(_RpcClient((_, _) => mismatched)).listBills('project-1'),
      throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
    );
    await expectLater(
      _repository(
        _RpcClient((_, _) => throw StateError('must not call')),
      ).listBills(
        'project-1',
        before: YorksAccountsSupplierBillCursor(
          updatedAt: DateTime.utc(2026),
          supplierBillId: ' ',
        ),
      ),
      throwsA(_domainCode(YorksV1DomainErrorCode.invalidInput)),
    );
  });
}

YorksSupabaseAccountsSupplierRepository _repository(
  YorksAccountsRpcClient rpc,
) => YorksSupabaseAccountsSupplierRepository(
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

YorksAccountsSupplierBillDraftInput _draft({String? billId, int? version}) =>
    YorksAccountsSupplierBillDraftInput(
      projectId: 'project-1',
      supplierBillId: billId,
      expectedVersion: version,
      supplierName: 'Yorks Supplier LLC',
      supplierInvoiceReference: 'SUP-001',
      invoiceDate: YorksAccountsDate.parse('2026-08-01'),
      dueDate: YorksAccountsDate.parse('2026-08-31'),
      exVatAmount: YorksAccountsDecimal.parse('1000.00'),
      vatRatePercent: YorksAccountsDecimal.parse('5.0000'),
      poLpoReference: 'PO-001',
      poLpoDocumentId: 'po-doc-1',
      acceptedReceiptReviewId: 'receipt-1',
      supplierInvoiceDocumentId: 'invoice-doc-1',
      explicitMismatchReason: null,
      notes: null,
    );

YorksAccountsSupplierPaymentInput _payment() =>
    YorksAccountsSupplierPaymentInput(
      projectId: 'project-1',
      supplierBillId: 'bill-1',
      expectedVersion: 3,
      paymentDate: YorksAccountsDate.parse('2026-08-26'),
      paymentMethod: 'bank_transfer',
      paymentReference: 'PAY-001',
      amount: YorksAccountsDecimal.parse('500.00'),
      reason: 'First instalment',
    );

YorksAccountsSupplierPaymentReversalInput _reversal() =>
    YorksAccountsSupplierPaymentReversalInput(
      projectId: 'project-1',
      supplierBillId: 'bill-1',
      expectedVersion: 4,
      originalPaymentId: 'payment-1',
      reversalDate: YorksAccountsDate.parse('2026-08-27'),
      reversalReference: 'REV-001',
      reason: 'Bank recall',
    );

Map<String, dynamic> _commandResponse(
  String name,
  Map<String, Object?> parameters,
) {
  if (name == 'v1_record_supplier_payment') {
    return {
      'schema_version': 4,
      'replayed': false,
      'project_id': 'project-1',
      'entity_id': 'payment-1',
      'payment_id': 'payment-1',
      'supplier_bill_id': 'bill-1',
      'supplier_bill_record_version': 4,
      'amount': '500.00',
      'payment_status': 'partially_paid',
      'updated_at': '2026-08-26T09:15:00Z',
    };
  }
  if (name == 'v1_reverse_supplier_payment') {
    return {
      'schema_version': 4,
      'replayed': false,
      'project_id': 'project-1',
      'entity_id': 'reversal-1',
      'reversal_id': 'reversal-1',
      'original_payment_id': 'payment-1',
      'supplier_bill_id': 'bill-1',
      'supplier_bill_record_version': 5,
      'amount': '500.00',
      'payment_status': 'approved',
      'updated_at': '2026-08-27T09:15:00Z',
    };
  }
  final isCreate = name == 'v1_create_supplier_bill_draft';
  return {
    'schema_version': 4,
    'replayed': false,
    'project_id': 'project-1',
    'entity_id': 'bill-1',
    'supplier_bill_id': 'bill-1',
    'record_version': isCreate
        ? 1
        : (parameters['p_expected_version'] as int) + 1,
    'status': name == 'v1_cancel_supplier_bill'
        ? 'cancelled'
        : name == 'v1_approve_supplier_bill'
        ? 'approved'
        : 'draft',
    'match_status': 'matched',
    'payment_status': name == 'v1_cancel_supplier_bill'
        ? 'cancelled'
        : name == 'v1_approve_supplier_bill'
        ? 'approved'
        : 'pending',
    'updated_at': '2026-08-26T09:15:00Z',
  };
}

Map<String, dynamic> _listProjection() => {
  'schema_version': 4,
  'project_id': 'project-1',
  'items': [_billJson()],
  'next_cursor': null,
  'capabilities': _capabilities(),
  'commands': _commands(),
};

Map<String, dynamic> _detailProjection() => {
  'schema_version': 4,
  'project_id': 'project-1',
  'supplier_bill': _billJson(),
  'payments': const [],
  'capabilities': _capabilities(),
  'commands': _commands(),
};

Map<String, dynamic> _billJson() => {
  'supplier_bill_id': 'bill-1',
  'project_id': 'project-1',
  'supplier_id': null,
  'supplier_name': 'Yorks Supplier LLC',
  'supplier_invoice_reference': 'SUP-001',
  'invoice_date': '2026-08-01',
  'due_date': '2026-08-31',
  'ex_vat_amount': '1000.00',
  'vat_rate_percent': '5.0000',
  'vat_amount': '50.00',
  'total_incl_vat': '1050.00',
  'po_lpo_reference': 'PO-001',
  'po_lpo_document_id': 'po-doc-1',
  'accepted_receipt_review_id': 'receipt-1',
  'accepted_delivery_reference': 'DN-001',
  'accepted_delivery': {
    'receipt_review_id': 'receipt-1',
    'delivery_reference': 'DN-001',
    'dispatch_id': 'dispatch-1',
    'dispatch_number': 'DSP-001',
    'reviewed_at': '2026-08-20T09:00:00Z',
    'accepted_good_quantity': '5.0000',
  },
  'supplier_invoice_document_id': 'invoice-doc-1',
  'explicit_mismatch_reason': null,
  'match_status': 'matched',
  'status': 'approved',
  'payment_status': 'approved',
  'paid_amount': '0.00',
  'outstanding_amount': '1050.00',
  'approval_admin_exception_reason': null,
  'approved_at': '2026-08-26T09:00:00Z',
  'approved_by_auth_user_id': 'accountant-1',
  'approved_by_exact_role': 'accountant',
  'cancelled_at': null,
  'cancellation_reason': null,
  'notes': null,
  'record_version': 2,
  'created_by_auth_user_id': 'procurement-1',
  'created_by_exact_role': 'procurement',
  'created_at': '2026-08-25T09:00:00Z',
  'updated_at': '2026-08-26T09:15:00Z',
};

Map<String, dynamic> _capabilities() => {
  'manage_supplier_bills': true,
  'approve_supplier_bill_payment': true,
  'view_supplier_costs': true,
};

Map<String, dynamic> _commands() => {
  'create_bill': true,
  'edit_bill': false,
  'approve_bill': true,
  'record_payment': true,
  'reverse_payment': true,
  'cancel_bill': true,
};

Matcher _domainCode(YorksV1DomainErrorCode code) =>
    isA<YorksV1DomainException>().having((error) => error.code, 'code', code);

final class _RpcClient implements YorksAccountsRpcClient {
  _RpcClient(this.handler);
  final Map<String, dynamic> Function(String, Map<String, Object?>) handler;
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
  }) async => throw error;
}
