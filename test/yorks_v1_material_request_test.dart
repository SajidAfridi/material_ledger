import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/controllers/yorks_v1_material_request_draft_controller.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/repositories/collection_store.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_material_request_repository.dart';

void main() {
  group('Yorks V1 Material Request draft controller', () {
    test(
      'keeps draft recovery private and submits one versioned command',
      () async {
        final store = _MemoryStore<YorksV1MaterialRequestDraft>();
        final repository = _FakeRequestRepository();
        final controller = YorksV1MaterialRequestDraftController(
          ownerAuthUserId: _siteEngineer,
          draftId: _draftId,
          store: store,
          repository: repository,
          uuidFactory: _Ids().next,
        );
        addTearDown(controller.dispose);

        await controller.setProject(_projectId);
        await controller.setScope(_scopeId);
        await controller.addCustomLine();
        final line = controller.state.draft.lines.single;
        await controller.updateLine(
          line.id,
          (current) => current.copyWith(
            description: 'Motorized Smoke Damper',
            brandOrigin: 'UAE',
            quantity: '4',
            unit: 'Nos',
          ),
        );

        final submitted = await controller.submit();

        expect(submitted?.requestNumber, 'B5-TEST-MR001');
        expect(repository.saveInputs, hasLength(1));
        expect(repository.submitInputs.single.expectedVersion, 1);
        expect(repository.submitInputs.single.requestId, _draftId);
        expect(store.readAll(), isEmpty);
        expect(
          controller.state.status,
          YorksV1MaterialRequestDraftSyncStatus.submitted,
        );
      },
    );

    test(
      'uses a one-pass Excel iterable without losing imported lines',
      () async {
        final controller = YorksV1MaterialRequestDraftController(
          ownerAuthUserId: _siteEngineer,
          draftId: _draftId,
          store: _MemoryStore<YorksV1MaterialRequestDraft>(),
          repository: _FakeRequestRepository(),
          uuidFactory: _Ids().next,
        );
        addTearDown(controller.dispose);

        Iterable<YorksV1MaterialRequestLine> imported() sync* {
          yield _line('external-1', 'First import');
          yield _line('external-2', 'Second import');
        }

        await controller.addExcelLines(imported());

        expect(controller.state.draft.lines.map((line) => line.description), [
          'First import',
          'Second import',
        ]);
        expect(controller.state.draft.lines.map((line) => line.displayOrder), [
          1,
          2,
        ]);
        expect(
          controller.state.draft.lines.every(
            (line) => line.source == YorksV1MaterialRequestLineSource.excel,
          ),
          isTrue,
        );
      },
    );
  });

  test('non-commercial response has no commercial client state', () {
    final request = YorksV1MaterialRequest.fromRpcJson({
      'id': _draftId,
      'project_id': _projectId,
      'project_ref': 'B5-TEST',
      'project_name': 'Test Project',
      'scope_id': _scopeId,
      'scope_name': 'Common',
      'state': 'submitted',
      'record_version': 1,
      'created_at': '2026-08-02T00:00:00Z',
      'updated_at': '2026-08-02T00:00:00Z',
      'timing': 'normal',
      'lines': [
        {
          'id': '73000000-0000-4000-8000-000000000001',
          'display_order': 1,
          'source_kind': 'custom',
          'item_description': 'Duct tape',
          'requested_qty': '2',
          'unit': 'Roll',
        },
      ],
    });

    expect(request.lines.single.unitCost, isNull);
    expect(request.lines.single.totalCost, isNull);
    expect(request.lines.single.currencyCode, isNull);
  });
}

const _siteEngineer = '10000000-0000-4000-8000-000000000002';
const _projectId = '71000000-0000-4000-8000-000000000001';
const _scopeId = '72000000-0000-4000-8000-000000000001';
const _draftId = '73000000-0000-4000-8000-000000000001';

YorksV1MaterialRequestLine _line(String id, String description) =>
    YorksV1MaterialRequestLine(
      id: id,
      displayOrder: 1,
      source: YorksV1MaterialRequestLineSource.custom,
      description: description,
      quantity: '1',
      unit: 'Nos',
    );

class _MemoryStore<T> implements CollectionStore<T> {
  final List<T> _items = [];

  @override
  bool get isSeeded => true;

  @override
  List<T> readAll() => List<T>.of(_items);

  @override
  Future<void> writeAll(List<T> items) async {
    _items
      ..clear()
      ..addAll(items);
  }
}

class _Ids {
  int _value = 0;
  String next() =>
      '74000000-0000-4000-8000-${(_value++).toString().padLeft(12, '0')}';
}

class _FakeRequestRepository implements YorksV1MaterialRequestRepository {
  final List<YorksV1SaveMaterialRequestDraftInput> saveInputs = [];
  final List<YorksV1SubmitMaterialRequestInput> submitInputs = [];

  @override
  Future<YorksV1MaterialRequest> cancel(
    YorksV1CancelMaterialRequestInput input,
  ) async => _request(
    requestId: input.requestId,
    version: input.expectedVersion + 1,
    number: 'B5-TEST-MR001',
  );

  @override
  Future<void> deleteDraft(String requestId) async {}

  @override
  Future<YorksV1MaterialRequest> getRequest(String requestId) async =>
      _request(requestId: requestId, version: 2, number: 'B5-TEST-MR001');

  @override
  Future<List<YorksV1MaterialRequestProjectOption>> listDraftProjects() async =>
      const [];

  @override
  Future<List<YorksV1MaterialRequest>> listRequests({
    String? projectId,
  }) async => const [];

  @override
  Future<List<YorksV1MaterialRequestScopeOption>> listScopes(
    String projectId,
  ) async => const [];

  @override
  Future<YorksV1MaterialRequest> saveDraft(
    YorksV1SaveMaterialRequestDraftInput input,
  ) async {
    saveInputs.add(input);
    return _request(requestId: input.draft.id, version: 1);
  }

  @override
  Future<YorksV1MaterialRequest> submit(
    YorksV1SubmitMaterialRequestInput input,
  ) async {
    submitInputs.add(input);
    return _request(
      requestId: input.requestId,
      version: 2,
      number: 'B5-TEST-MR001',
    );
  }
}

YorksV1MaterialRequest _request({
  required String requestId,
  required int version,
  String? number,
}) => YorksV1MaterialRequest.fromRpcJson({
  'id': requestId,
  'project_id': _projectId,
  'project_ref': 'B5-TEST',
  'project_name': 'Test Project',
  'scope_id': _scopeId,
  'scope_name': 'Common',
  'state': number == null ? 'draft' : 'submitted',
  'record_version': version,
  'created_at': '2026-08-02T00:00:00Z',
  'updated_at': '2026-08-02T00:00:00Z',
  'timing': 'normal',
  'request_number': number,
  'lines': const [],
});
