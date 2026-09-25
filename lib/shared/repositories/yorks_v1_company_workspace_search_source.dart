import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/yorks_v1_workspace_search.dart';
import '../providers/yorks_v1_company_material_request_provider.dart';
import 'yorks_v1_company_material_request_repository.dart';

/// Loaded on search intent. Company decoding and RPC code do not join the
/// initial web shell merely because Company search is enabled.
Future<List<YorksV1WorkspaceSearchResult>> searchCompanyWorkspace(
  Ref ref,
  String query,
) async {
  final repository = ref.read(yorksV1CompanyMaterialRequestRepositoryProvider);
  if (repository is! YorksV1CompanyMaterialRequestPagedRepository) {
    return const [];
  }
  final page =
      await (repository as YorksV1CompanyMaterialRequestPagedRepository)
          .listPage(query: query, limit: 60);
  return [
    for (final item in page.items)
      YorksV1WorkspaceSearchResult(
        kind: YorksV1WorkspaceSearchResultKind.companyMaterialRequest,
        title: item.requestNumber.isEmpty ? item.purpose : item.requestNumber,
        subtitle: '${item.purpose} · ${item.responsibleUnitName}',
        route: item.state == 'draft'
            ? '/yorks/material-requests/company/new?draft=${Uri.encodeQueryComponent(item.id)}'
            : '/yorks/material-requests/company/${Uri.encodeComponent(item.id)}',
        entityId: item.id,
        searchableText:
            '${item.requestNumber} ${item.purpose} ${item.responsibleUnitName} ${item.requesterDisplayName}',
      ),
  ];
}
