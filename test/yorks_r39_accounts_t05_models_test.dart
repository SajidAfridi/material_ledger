import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/accounts/domain/accounts_portfolio_models.dart';

void main() {
  test('portfolio parses string decimals and a stable keyset cursor', () {
    final projection = YorksAccountsPortfolioProjection.fromRpcJson(
      _portfolioJson(),
    );

    expect(projection.actorExactRole, 'accountant');
    expect(projection.totals.contractBaseline.canonicalText, '1000000');
    expect(projection.projects.single.projectReference, 'YRA-001');
    expect(projection.projects.single.supplierOpenAmount!.canonicalText, '250');
    expect(projection.nextProjectId, 'project-1');
    expect(projection.nextActivityAt, DateTime.parse('2026-08-26T10:00:00Z'));
  });

  test('portfolio rejects numeric money and unsupported schema shape', () {
    final numeric = _portfolioJson();
    (numeric['totals'] as Map<String, dynamic>)['contract_baseline'] = 1000000;
    expect(
      () => YorksAccountsPortfolioProjection.fromRpcJson(numeric),
      throwsFormatException,
    );

    final unsupported = _portfolioJson()..['schema_version'] = 1;
    expect(
      () => YorksAccountsPortfolioProjection.fromRpcJson(unsupported),
      throwsFormatException,
    );
  });

  test('project overview accepts operational and supplier-only shapes', () {
    final site = YorksAccountsProjectOverviewProjection.fromRpcJson(
      _projectJson(
        capabilities: _capabilities(viewProject: true),
        sections: {
          'baseline': {
            'revision_id': 'baseline-1',
            'revision_number': 1,
            'status': 'current',
            'effective_at': '2026-08-26T09:00:00Z',
          },
          'progress': {
            'confirmed_percent': '10',
            'suggested_percent': '15',
            'pending_review_count': 1,
            'building_position': <Object?>[],
          },
        },
      ),
    );
    expect(site.progress, isNotNull);
    expect(site.receivables, isNull);
    expect(site.supplier, isNull);

    final procurement = YorksAccountsProjectOverviewProjection.fromRpcJson(
      _projectJson(
        capabilities: _capabilities(viewSupplier: true),
        sections: {
          'supplier': {
            'total_bills': 2,
            'needs_review': 1,
            'commitments': '1000.00',
            'paid': '250.00',
            'open_amount': '750.00',
          },
        },
      ),
    );
    expect(procurement.progress, isNull);
    expect(procurement.baseline, isNull);
    expect(procurement.supplier, isNotNull);
  });

  test('project overview fails closed when a protected domain leaks', () {
    expect(
      () => YorksAccountsProjectOverviewProjection.fromRpcJson(
        _projectJson(
          capabilities: _capabilities(viewProject: true),
          sections: {
            'progress': {
              'confirmed_percent': '0',
              'suggested_percent': '0',
              'pending_review_count': 0,
              'building_position': <Object?>[],
            },
            'baseline': {'contract_value': '1000000.00'},
          },
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => YorksAccountsProjectOverviewProjection.fromRpcJson(
        _projectJson(
          capabilities: _capabilities(),
          sections: {'supplier': null},
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => YorksAccountsProjectOverviewProjection.fromRpcJson(
        _projectJson(
          capabilities: _capabilities(viewSupplier: true),
          sections: {
            'progress': {
              'confirmed_percent': '0',
              'suggested_percent': '0',
              'pending_review_count': 0,
              'building_position': <Object?>[],
            },
          },
        ),
      ),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _portfolioJson() => {
  'schema_version': 2,
  'scope': 'portfolio',
  'actor_exact_role': 'accountant',
  'can_export': true,
  'authorized_project_count': 1,
  'filtered_project_count': 1,
  'totals': {
    'project_count': 1,
    'contract_baseline': '1000000.00',
    'confirmed_eligible': '100000.00',
    'available_to_claim': '75000.00',
    'claimed': '25000.00',
    'certified': '20000.00',
    'amount_paid_till_date': '10000.00',
    'still_due': '10000.00',
    'pdc_exposure': '5000.00',
    'action_count': 1,
  },
  'projects': [
    {
      'project_id': 'project-1',
      'project_reference': 'YRA-001',
      'project_name': 'Project One',
      'project_site': 'Abu Dhabi',
      'project_state': 'active',
      'client_name': 'Client LLC',
      'baseline_revision_number': 1,
      'currency_code': 'AED',
      'contract_baseline': '1000000.00',
      'confirmed_eligible': '100000.00',
      'available_to_claim': '75000.00',
      'claimed': '25000.00',
      'certified': '20000.00',
      'amount_paid_till_date': '10000.00',
      'still_due': '10000.00',
      'pdc_exposure': '5000.00',
      'confirmed_percent': '10.00',
      'due_state': 'current',
      'payment_state': 'partially_paid',
      'action_count': 1,
      'latest_activity_at': '2026-08-26T10:00:00Z',
      'supplier_review_count': 1,
      'supplier_open_amount': '250.00',
    },
  ],
  'action_queue': [
    {
      'project_id': 'project-1',
      'project_reference': 'YRA-001',
      'project_name': 'Project One',
      'code': 'supplier_match_review',
      'owner_role': 'procurement',
      'severity': 'high',
      'count': 1,
      'occurred_at': '2026-08-26T10:00:00Z',
    },
  ],
  'next_cursor': {
    'before_activity_at': '2026-08-26T10:00:00Z',
    'before_project_id': 'project-1',
  },
};

Map<String, dynamic> _projectJson({
  required Map<String, dynamic> capabilities,
  required Map<String, dynamic> sections,
}) => {
  'schema_version': 2,
  'project_id': 'project-1',
  'project_reference': 'YRA-001',
  'project_name': 'Project One',
  'project_site': 'Abu Dhabi',
  'project_state': 'active',
  'client_name': 'Client LLC',
  'actor_exact_role': 'site_engineer',
  'capabilities': capabilities,
  ...sections,
};

Map<String, dynamic> _capabilities({
  bool viewProject = false,
  bool viewValues = false,
  bool viewSupplier = false,
}) => {
  'view_project_accounts': viewProject,
  'view_project_commercial_values': viewValues,
  'view_supplier_costs': viewSupplier,
  'suggest_billing_progress': viewProject,
  'confirm_billing_progress': false,
  'prepare_client_claim': false,
  'manage_client_invoices': false,
  'manage_supplier_bills': viewSupplier,
  'approve_supplier_bill_payment': false,
  'export_accounts_registers': true,
};
