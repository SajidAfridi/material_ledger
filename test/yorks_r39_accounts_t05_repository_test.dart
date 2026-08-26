import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/accounts/data/accounts_portfolio_repository.dart';
import 'package:material_ledger/features/accounts/data/accounts_repository.dart';
import 'package:material_ledger/features/accounts/domain/accounts_portfolio_models.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('portfolio forwards canonical filters and cursor parameters', () async {
    final rpc = _RpcClient((_, _) => _portfolioJson());
    final repository = _repository(rpc);
    await repository.getPortfolio(
      YorksAccountsPortfolioFilters(
        projectId: ' project-1 ',
        client: ' Client LLC ',
        commercialState: 'active',
        dueState: 'overdue',
        paymentState: 'partially_paid',
        pdcState: 'received',
        supplierMatchState: 'review',
        search: ' YRA ',
        beforeActivityAt: DateTime.parse('2026-08-26T10:00:00+03:00'),
        beforeProjectId: ' project-2 ',
        limit: 15,
      ),
    );

    expect(rpc.names, ['v1_get_accounts_portfolio']);
    expect(rpc.parameters.single, {
      'p_project_id': 'project-1',
      'p_client': 'Client LLC',
      'p_commercial_state': 'active',
      'p_due_state': 'overdue',
      'p_payment_state': 'partially_paid',
      'p_pdc_state': 'received',
      'p_supplier_match_state': 'review',
      'p_search': 'YRA',
      'p_before_activity_at': '2026-08-26T07:00:00.000Z',
      'p_before_project_id': 'project-2',
      'p_limit': 15,
    });
  });

  test(
    'project overview binds project identity and rejects mismatch',
    () async {
      final rpc = _RpcClient((name, parameters) {
        expect(name, 'v1_get_project_accounts_overview');
        expect(parameters, {'p_project_id': 'project-1'});
        return _projectJson();
      });
      final projection = await _repository(
        rpc,
      ).getProjectOverview(' project-1 ');
      expect(projection.projectId, 'project-1');

      final mismatch = _projectJson()..['project_id'] = 'project-2';
      await expectLater(
        _repository(
          _RpcClient((_, _) => mismatch),
        ).getProjectOverview('project-1'),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );
    },
  );

  test('feature, connectivity, authorization and input fail closed', () async {
    final disabled = YorksSupabaseAccountsPortfolioRepository(
      featureFlags: _flags(accounts: false),
      connectivity: DefaultConnectivity(),
      rpcClient: _RpcClient((_, _) => throw StateError('must not call')),
    );
    await expectLater(
      disabled.getPortfolio(const YorksAccountsPortfolioFilters()),
      throwsA(_domainCode(YorksV1DomainErrorCode.featureDisabled)),
    );

    final offline = YorksSupabaseAccountsPortfolioRepository(
      featureFlags: _flags(),
      connectivity: DefaultConnectivity(online: false),
      rpcClient: _RpcClient((_, _) => throw StateError('must not call')),
    );
    await expectLater(
      offline.getProjectOverview('project-1'),
      throwsA(_domainCode(YorksV1DomainErrorCode.offline)),
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
      denied.getPortfolio(const YorksAccountsPortfolioFilters()),
      throwsA(_domainCode(YorksV1DomainErrorCode.unauthorized)),
    );

    await expectLater(
      _repository(
        _RpcClient((_, _) => throw StateError('must not call')),
      ).getPortfolio(const YorksAccountsPortfolioFilters(limit: 101)),
      throwsA(_domainCode(YorksV1DomainErrorCode.invalidInput)),
    );
    await expectLater(
      _repository(
        _RpcClient((_, _) => throw StateError('must not call')),
      ).getProjectOverview(' '),
      throwsA(_domainCode(YorksV1DomainErrorCode.invalidInput)),
    );
  });

  test(
    'malformed protected decimals are rejected before reaching UI',
    () async {
      final malformed = _projectJson();
      (malformed['progress'] as Map<String, dynamic>)['confirmed_eligible'] = 0;
      await expectLater(
        _repository(
          _RpcClient((_, _) => malformed),
        ).getProjectOverview('project-1'),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );
    },
  );
}

YorksSupabaseAccountsPortfolioRepository _repository(
  YorksAccountsRpcClient rpc,
) => YorksSupabaseAccountsPortfolioRepository(
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

Map<String, dynamic> _portfolioJson() => {
  'schema_version': 2,
  'scope': 'portfolio',
  'actor_exact_role': 'accountant',
  'can_export': true,
  'authorized_project_count': 0,
  'filtered_project_count': 0,
  'totals': {
    'project_count': 0,
    'contract_baseline': '0',
    'confirmed_eligible': '0',
    'available_to_claim': '0',
    'claimed': '0',
    'certified': '0',
    'amount_paid_till_date': '0',
    'still_due': '0',
    'pdc_exposure': '0',
    'action_count': 0,
  },
  'projects': <Object?>[],
  'action_queue': <Object?>[],
  'next_cursor': null,
};

Map<String, dynamic> _projectJson() => {
  'schema_version': 2,
  'project_id': 'project-1',
  'project_reference': 'YRA-001',
  'project_name': 'Project One',
  'project_site': 'Abu Dhabi',
  'project_state': 'active',
  'client_name': 'Client LLC',
  'actor_exact_role': 'accountant',
  'capabilities': {
    'view_project_accounts': true,
    'view_project_commercial_values': true,
    'view_supplier_costs': true,
    'suggest_billing_progress': false,
    'confirm_billing_progress': false,
    'prepare_client_claim': false,
    'manage_client_invoices': true,
    'manage_supplier_bills': true,
    'approve_supplier_bill_payment': true,
    'export_accounts_registers': true,
  },
  'baseline': {
    'revision_id': 'baseline-1',
    'revision_number': 1,
    'status': 'current',
    'effective_at': '2026-08-26T09:00:00Z',
    'contract_value': '1000000.00',
    'currency_code': 'AED',
    'payment_terms_days': 20,
    'reminder_lead_days': 10,
  },
  'progress': {
    'confirmed_percent': '0',
    'suggested_percent': '0',
    'pending_review_count': 0,
    'building_position': <Object?>[],
    'confirmed_eligible': '0',
  },
  'receivables': {
    'claimed': '0',
    'certified': '0',
    'amount_paid_till_date': '0',
    'still_due': '0',
    'pdc_exposure': '0',
    'recent_invoices': <Object?>[],
  },
  'supplier': {
    'total_bills': 0,
    'needs_review': 0,
    'commitments': '0',
    'paid': '0',
    'open_amount': '0',
  },
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
