import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/accounts/domain/accounts_decimal.dart';
import 'package:material_ledger/features/accounts/domain/accounts_receivables_inputs.dart';
import 'package:material_ledger/features/accounts/domain/accounts_receivables_models.dart';

void main() {
  group('T03 exact boundaries', () {
    test('calendar dates are strict and timezone independent', () {
      expect(YorksAccountsDate.parse('2026-02-28').postgresText, '2026-02-28');
      expect(YorksAccountsDate.tryParse('2026-02-29'), isNull);
      expect(YorksAccountsDate.tryParse('26-02-28'), isNull);
      expect(YorksAccountsDate.tryParse('2026-02-28T00:00:00Z'), isNull);
    });

    test(
      'claim inputs keep exact money strings and draft evidence optional',
      () {
        final input = _claimDraft();
        expect(input.isValid, isTrue);
        final line =
            (input.idempotencyPayload()['lines'] as List).single as Map;
        expect(line['claimed_amount'], '1250.5');
        expect(line['evidence_reference'], isNull);
        expect(input.idempotencyPayload()['admin_exception_reason'], isNull);

        final exceptionInput = _claimDraft(
          adminExceptionReason: 'Approved adoption exception',
        );
        expect(exceptionInput.isValid, isTrue);
        expect(
          exceptionInput.idempotencyPayload()['admin_exception_reason'],
          'Approved adoption exception',
        );

        expect(
          _claimDraft(amount: '1.001').isValid,
          isFalse,
          reason: 'money cannot be silently rounded',
        );
      },
    );

    test('certification validates cumulative claimed cap and reason', () {
      final full = _certification('100', null);
      expect(
        full.isValidAgainstClaimed(YorksAccountsDecimal.parse('100')),
        isTrue,
      );
      expect(
        _certification(
          '90',
          null,
        ).isValidAgainstClaimed(YorksAccountsDecimal.parse('100')),
        isFalse,
      );
      expect(
        _certification(
          '90',
          'Client deduction',
        ).isValidAgainstClaimed(YorksAccountsDecimal.parse('100')),
        isTrue,
      );
      expect(
        _certification(
          '101',
          'Too high',
        ).isValidAgainstClaimed(YorksAccountsDecimal.parse('100')),
        isFalse,
      );
    });
  });

  group('T03 protected projections', () {
    test('claim detail contextualizes the parent baseline revision', () {
      final projection = YorksAccountsClaimDetailProjection.fromRpcJson({
        'schema_version': 3,
        'project_id': 'project-1',
        'claim': _claimJson(),
        'capabilities': _capabilities(),
        'commands': _commands(),
      });

      expect(projection.claim.claimedExVat!.canonicalText, '1250.5');
      expect(projection.claim.adminExceptionReason, isNull);
      expect(projection.claim.lines.single.baselineRevisionId, 'baseline-1');
      expect(
        projection.claim.lines.single.claimedAmount!.canonicalText,
        '1250.5',
      );
    });

    test('projection is rejected when commercial authority is absent', () {
      final capabilities = _capabilities()
        ..['view_project_commercial_values'] = false;
      expect(
        () => YorksAccountsClaimsProjection.fromRpcJson({
          'schema_version': 3,
          'project_id': 'project-1',
          'claims': const [],
          'next_cursor': null,
          'capabilities': capabilities,
          'commands': _commands(),
        }),
        throwsFormatException,
      );
    });

    test('numeric money and unknown enum values fail closed', () {
      final invoice = _invoiceSummaryJson()..['claimed_ex_vat'] = 100.0;
      expect(
        () => YorksAccountsInvoicesProjection.fromRpcJson({
          'schema_version': 3,
          'project_id': 'project-1',
          'invoices': [invoice],
          'next_cursor': null,
          'capabilities': _capabilities(),
          'commands': _commands(),
        }),
        throwsFormatException,
      );

      invoice['claimed_ex_vat'] = '100.00';
      invoice['status'] = 'approved';
      expect(
        () => YorksAccountsClientInvoiceSummary.fromRpcJson(invoice),
        throwsFormatException,
      );
    });

    test('timestamps require an explicit offset', () {
      final invoice = _invoiceSummaryJson()
        ..['updated_at'] = '2026-08-26T09:15:00';
      expect(
        () => YorksAccountsClientInvoiceSummary.fromRpcJson(invoice),
        throwsFormatException,
      );
    });

    test('ledger discriminates payment and PDC event entries', () {
      final projection = YorksAccountsReceivablesLedgerProjection.fromRpcJson({
        'schema_version': 3,
        'project_id': 'project-1',
        'invoice_id': 'invoice-1',
        'entries': [
          {
            'ledger_entry_id': 'payment-1',
            'occurred_at': '2026-08-26T09:15:00Z',
            'entry_type': 'payment',
            'invoice_id': 'invoice-1',
            'data': {
              'payment_id': 'payment-1',
              'entry_kind': 'receipt',
              'payment_date': '2026-08-26',
              'payment_method': 'bank_transfer',
              'payment_reference': 'PAY-001',
              'amount': '105.00',
              'original_payment_id': null,
              'pdc_id': null,
              'actor_auth_user_id': 'actor-1',
              'actor_exact_role': 'accountant',
            },
          },
          {
            'ledger_entry_id': 'event-1',
            'occurred_at': '2026-08-25T09:15:00+00:00',
            'entry_type': 'pdc_event',
            'invoice_id': 'invoice-1',
            'data': {
              'pdc_event_id': 'event-1',
              'pdc_id': 'pdc-1',
              'sequence_number': 1,
              'from_status': null,
              'to_status': 'expected',
              'action_date': '2026-08-25',
              'reason': null,
              'linked_payment_id': null,
              'actor_auth_user_id': 'actor-1',
              'actor_exact_role': 'accountant',
            },
          },
        ],
        'next_cursor': null,
        'capabilities': _capabilities(),
        'commands': _commands(),
      });

      expect(projection.entries.first.payment!.amount.canonicalText, '105');
      expect(
        projection.entries.last.pdcEvent!.toStatus,
        YorksAccountsPdcStatus.expected,
      );
    });

    test('command result accepts authoritative invoice version key', () {
      final result = YorksAccountsReceivablesCommandResult.fromRpcJson({
        'schema_version': 3,
        'replayed': false,
        'project_id': 'project-1',
        'entity_id': 'payment-1',
        'payment_id': 'payment-1',
        'invoice_id': 'invoice-1',
        'invoice_record_version': 4,
        'status': 'partially_paid',
        'updated_at': '2026-08-26T09:15:00Z',
      });
      expect(result.recordVersion, 4);
    });
  });
}

YorksAccountsClaimDraftInput _claimDraft({
  String amount = '1250.50',
  String? adminExceptionReason,
}) => YorksAccountsClaimDraftInput(
  projectId: 'project-1',
  claimReference: 'CLAIM-001',
  periodStart: YorksAccountsDate.parse('2026-08-01'),
  periodEnd: YorksAccountsDate.parse('2026-08-31'),
  lines: [
    YorksAccountsClaimLineInput(
      progressEntryId: 'progress-1',
      claimedAmount: YorksAccountsDecimal.parse(amount),
      evidenceReference: null,
    ),
  ],
  notes: '',
  adminExceptionReason: adminExceptionReason,
);

YorksAccountsCertificationInput _certification(String amount, String? reason) =>
    YorksAccountsCertificationInput(
      projectId: 'project-1',
      invoiceId: 'invoice-1',
      expectedVersion: 1,
      certifiedExVat: YorksAccountsDecimal.parse(amount),
      certificationDate: YorksAccountsDate.parse('2026-08-26'),
      certificationReference: 'CERT-001',
      differenceReason: reason,
    );

Map<String, dynamic> _claimJson() => {
  'claim_id': 'claim-1',
  'project_id': 'project-1',
  'baseline_revision_id': 'baseline-1',
  'claim_reference': 'CLAIM-001',
  'claim_period_start': '2026-08-01',
  'claim_period_end': '2026-08-31',
  'status': 'draft',
  'admin_exception_reason': null,
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
      'evidence_reference': null,
    },
  ],
  'created_at': '2026-08-26T09:00:00Z',
  'updated_at': '2026-08-26T09:15:00Z',
};

Map<String, dynamic> _invoiceSummaryJson() => {
  'invoice_id': 'invoice-1',
  'claim_id': 'claim-1',
  'invoice_reference': 'INV-001',
  'status': 'submitted',
  'claimed_ex_vat': '100.00',
  'certified_ex_vat': '0.00',
  'total_incl_vat': '105.00',
  'amount_paid_till_date': '0.00',
  'still_due': '0.00',
  'pdc_exposure': '0.00',
  'submission_date': '2026-08-26',
  'due_date': '2026-09-15',
  'due_state': 'on_track',
  'record_version': 2,
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
