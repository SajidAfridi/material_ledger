import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/accounts/domain/accounts_decimal.dart';
import 'package:material_ledger/features/accounts/domain/accounts_receivables_inputs.dart';
import 'package:material_ledger/features/accounts/domain/accounts_supplier_inputs.dart';
import 'package:material_ledger/features/accounts/domain/accounts_supplier_models.dart';

void main() {
  test('supplier bill input preserves exact values and trusted receipt id', () {
    final input = _draft();
    expect(input.isValid, isTrue);
    expect(input.idempotencyPayload()['ex_vat_amount'], '1000');
    expect(input.idempotencyPayload()['vat_rate_percent'], '5');
    expect(
      input.idempotencyPayload()['accepted_receipt_review_id'],
      'receipt-1',
    );
    expect(input.idempotencyPayload(), isNot(contains('accepted_quantity')));
    expect(input.idempotencyPayload(), isNot(contains('delivery_reference')));
  });

  test('supplier bill validation rejects rounding and incomplete identity', () {
    expect(_draft(exVat: '1.001').isValid, isFalse);
    expect(_draft(vatRate: '100.0001').isValid, isFalse);
    expect(_draft(supplierName: null).isValid, isFalse);
    expect(
      _draft(dueDate: YorksAccountsDate.parse('2026-07-31')).isValid,
      isFalse,
    );
  });

  test('bill projection parses trusted evidence and exact money strings', () {
    final bill = YorksAccountsSupplierBill.fromRpcJson(_billJson());
    expect(bill.matchStatus, YorksAccountsSupplierMatchStatus.matched);
    expect(bill.paymentStatus, YorksAccountsSupplierPaymentStatus.approved);
    expect(bill.totalInclVat.canonicalText, '1050');
    expect(bill.acceptedDelivery!.acceptedGoodQuantity.canonicalText, '5');
    expect(bill.acceptedDeliveryReference, 'DN-001');
  });

  test('numeric commercial values and unzoned timestamps fail closed', () {
    final numeric = _billJson()..['total_incl_vat'] = 1050.0;
    expect(
      () => YorksAccountsSupplierBill.fromRpcJson(numeric),
      throwsFormatException,
    );
    final unzoned = _billJson()..['updated_at'] = '2026-08-26T09:15:00';
    expect(
      () => YorksAccountsSupplierBill.fromRpcJson(unzoned),
      throwsFormatException,
    );
  });

  test('detail validates reversal linkage and command entity identity', () {
    final detail = YorksAccountsSupplierBillDetailProjection.fromRpcJson({
      'schema_version': 4,
      'project_id': 'project-1',
      'supplier_bill': _billJson(),
      'payments': [
        {
          'payment_id': 'payment-1',
          'entry_kind': 'payment',
          'original_payment_id': null,
          'payment_date': '2026-08-26',
          'payment_method': 'bank_transfer',
          'payment_reference': 'PAY-001',
          'amount': '500.00',
          'reason': null,
          'admin_exception_reason': null,
          'actor_auth_user_id': 'actor-1',
          'actor_exact_role': 'accountant',
          'created_at': '2026-08-26T09:15:00Z',
        },
        {
          'payment_id': 'reversal-1',
          'entry_kind': 'reversal',
          'original_payment_id': 'payment-1',
          'payment_date': '2026-08-27',
          'payment_method': 'reversal',
          'payment_reference': 'REV-001',
          'amount': '500.00',
          'reason': 'Bank recall',
          'admin_exception_reason': null,
          'actor_auth_user_id': 'actor-1',
          'actor_exact_role': 'accountant',
          'created_at': '2026-08-27T09:15:00Z',
        },
      ],
      'capabilities': _capabilities(),
      'commands': _commands(),
    });
    expect(detail.payments.last.originalPaymentId, 'payment-1');

    expect(
      () => YorksAccountsSupplierCommandResult.fromRpcJson({
        'schema_version': 4,
        'replayed': false,
        'project_id': 'project-1',
        'entity_id': 'wrong-id',
        'payment_id': 'payment-1',
        'supplier_bill_id': 'bill-1',
        'supplier_bill_record_version': 3,
        'amount': '500.00',
        'payment_status': 'partially_paid',
        'updated_at': '2026-08-26T09:15:00Z',
      }),
      throwsFormatException,
    );
  });
}

YorksAccountsSupplierBillDraftInput _draft({
  String exVat = '1000.00',
  String vatRate = '5.0000',
  String? supplierName = 'Yorks Supplier LLC',
  YorksAccountsDate? dueDate,
}) => YorksAccountsSupplierBillDraftInput(
  projectId: 'project-1',
  supplierName: supplierName,
  supplierInvoiceReference: 'SUP-001',
  invoiceDate: YorksAccountsDate.parse('2026-08-01'),
  dueDate: dueDate ?? YorksAccountsDate.parse('2026-08-31'),
  exVatAmount: YorksAccountsDecimal.parse(exVat),
  vatRatePercent: YorksAccountsDecimal.parse(vatRate),
  poLpoReference: 'PO-001',
  poLpoDocumentId: 'po-doc-1',
  acceptedReceiptReviewId: 'receipt-1',
  supplierInvoiceDocumentId: 'invoice-doc-1',
  explicitMismatchReason: null,
  notes: null,
);

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
