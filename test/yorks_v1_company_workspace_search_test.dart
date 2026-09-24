import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_company_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_workspace_search.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_project_portfolio.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_workspace_search_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_company_material_request_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_material_request_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_project_portfolio_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_boq_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_documents_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_logistics_repository.dart';

void main() {
  test(
    'Global search queries Company server per query and opens genuine Company records',
    () async {
      final company = _Company();
      final repository = _repository(company);
      final first = await repository.search(
        'CMR-1',
        role: YorksV1Role.siteEngineer,
      );
      expect(company.queries, ['CMR-1']);
      expect(
        first.results.single.kind,
        YorksV1WorkspaceSearchResultKind.companyMaterialRequest,
      );
      expect(first.results.single.projectId, isNull);
      expect(
        first.results.single.route,
        '/yorks/material-requests/company/company-id',
      );
      await repository.search('helmet', role: YorksV1Role.siteEngineer);
      expect(company.queries, ['CMR-1', 'helmet']);
      company.fail = true;
      final failed = await repository.search(
        'CMR-1',
        role: YorksV1Role.siteEngineer,
      );
      expect(
        failed.results,
        isEmpty,
        reason:
            'Never reuse a Company result after authorization or transport failure',
      );
      expect(failed.isPartial, isTrue);
    },
  );
  test(
    'Disabled Company source returns no Company result or artificial project',
    () async {
      final result = await _repository(
        null,
      ).search('helmet', role: YorksV1Role.siteEngineer);
      expect(result.results, isEmpty);
      expect(result.isPartial, isFalse);
    },
  );
}

YorksV1WorkspaceSearchRepository _repository(_Company? company) =>
    YorksV1WorkspaceSearchRepository(
      projects: _Projects(),
      materialRequests: _Requests(),
      boq: _Boq(),
      documents: _Documents(),
      logistics: _Logistics(),
      companySearch: company == null
          ? null
          : (query) async {
              final page = await company.listPage(query: query);
              return [
                for (final item in page.items)
                  YorksV1WorkspaceSearchResult(
                    kind:
                        YorksV1WorkspaceSearchResultKind.companyMaterialRequest,
                    title: item.requestNumber,
                    subtitle: item.purpose,
                    route: "/yorks/material-requests/company/${item.id}",
                    entityId: item.id,
                    searchableText: item.requestNumber,
                  ),
              ];
            },
    );

class _Company implements YorksV1CompanyMaterialRequestPagedRepository {
  final queries = <String>[];
  bool fail = false;
  @override
  Future<YorksV1CompanyMaterialRequestPage> listPage({
    String view = 'requests',
    String query = '',
    int offset = 0,
    int limit = 15,
  }) async {
    queries.add(query);
    if (fail) throw StateError('Unavailable');
    return YorksV1CompanyMaterialRequestPage(
      totalCount: 1,
      items: [
        YorksV1CompanyMaterialRequestApprovalInboxItem.fromRpcJson({
          'id': 'company-id',
          'request_number': 'CMR-1',
          'state': 'awaiting_company_approval',
          'record_version': 2,
          'category_name': 'PPE',
          'responsible_unit_name': 'Workshop',
          'purpose': 'helmet',
          'requester_display_name': 'Engineer',
          'beneficiary_display_name': 'Engineer',
          'submitted_at': '2026-09-25T10:00:00Z',
          'line_count': 1,
        }),
      ],
    );
  }
}

class _Projects implements YorksV1ProjectPortfolioRepository {
  @override
  Future<List<YorksV1ProjectPortfolioItem>> listPortfolio() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Requests implements YorksV1MaterialRequestRepository {
  @override
  Future<List<YorksV1MaterialRequest>> listRequests({
    String? projectId,
  }) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Boq implements YorksV1BoqRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Documents implements YorksV1DocumentsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Logistics implements YorksV1LogisticsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
