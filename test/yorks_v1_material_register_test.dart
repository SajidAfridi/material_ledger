import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_register.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_material_request_repository.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Company register row has no Project command aggregate or identity', () {
    final row = YorksV1MaterialRegisterPage.fromRpcJson(_page()).items.single;
    expect(row.isCompany, true);
    expect(row.projectId, isNull);
    expect(row.scopeId, isNull);
    expect(row.projectRequest, isNull);
    expect(row.state, 'rejected');
    expect(row.stateCopy.primary, 'Rejected');
    expect(row.descriptions, isEmpty);
  });
  test(
    'unknown record kinds and fabricated Company project identity fail closed',
    () {
      final unknown = _page();
      (unknown['items'] as List).single['request_kind'] = 'other';
      expect(
        () => YorksV1MaterialRegisterPage.fromRpcJson(unknown),
        throwsA(isA<YorksV1DomainException>()),
      );
      expect(
        () => YorksV1MaterialRegisterEntry.company({
          ..._row(),
          'project_id': 'fake',
        }),
        throwsA(isA<YorksV1DomainException>()),
      );
      expect(
        () => YorksV1MaterialRegisterEntry.company({
          ..._row(),
          'state': 'unknown',
        }),
        throwsA(isA<YorksV1DomainException>()),
      );
    },
  );
  test(
    'native Company filters survive paging and participate in stale-query detection',
    () {
      final filter = YorksV1MaterialRequestSummaryQuery(
        search: 'helmet',
        limit: 15,
      );
      final query = YorksV1MaterialRegisterQuery(
        filter,
        nativeState: 'awaiting_company_approval',
        requestKind: 'company',
      );
      expect(query.copyWith(offset: 15).toRpcParameters()['p_states'], [
        'awaiting_company_approval',
      ]);
      expect(query.copyWith(offset: 15).toRpcParameters()['p_offset'], 15);
      expect(
        query.copyWith(offset: 15).toRpcParameters()['p_request_kind'],
        'company',
      );
      expect(
        query,
        isNot(YorksV1MaterialRegisterQuery(filter, nativeState: 'cancelled')),
      );
    },
  );
  for (final enabled in [false, true]) {
    test(
      'Company flag $enabled selects only its intended register endpoint',
      () async {
        final connection = DefaultConnectivity();
        addTearDown(connection.dispose);
        final rpc = _Rpc();
        final repository = YorksV1SupabaseMaterialRequestRepository(
          featureFlags: YorksV1FeatureFlags(
            foundation: true,
            projects: true,
            boq: true,
            excel: true,
            requests: true,
            companyMaterialRequests: enabled,
          ),
          connectivity: connection,
          rpcClient: rpc,
        );
        await repository.listMaterialRegister(
          YorksV1MaterialRegisterQuery(YorksV1MaterialRequestSummaryQuery()),
        );
        expect(
          rpc.function,
          enabled
              ? 'v1_list_unified_material_request_summaries'
              : 'v1_list_material_request_summaries',
        );
        await repository.listMaterialRegister(
          YorksV1MaterialRegisterQuery(
            YorksV1MaterialRequestSummaryQuery(projectId: 'project-id'),
          ),
        );
        expect(rpc.function, 'v1_list_material_request_summaries');
      },
    );
  }
}

Map<String, dynamic> _row() => {
  'id': 'company',
  'request_kind': 'company',
  'state': 'rejected',
  'category_name': 'Safety',
  'responsible_unit_name': 'Workshop',
  'item_count': 2,
  'created_at': '2026-09-25T08:00:00Z',
  'updated_at': '2026-09-25T08:00:00Z',
};
Map<String, dynamic> _page() => {
  'items': [_row()],
  'total_count': 1,
  'limit': 15,
  'offset': 0,
  'has_more': false,
  'metrics': {
    'total': 1,
    'open': 0,
    'in_progress': 0,
    'dispatched': 0,
    'received': 0,
    'closed': 1,
  },
};

class _Rpc implements YorksV1MaterialRequestRpcClient {
  String? function;
  @override
  Future<Object?> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    function = functionName;
    final result = _page();
    if (functionName == 'v1_list_material_request_summaries') {
      result['items'] = [];
    }
    return result;
  }
}
