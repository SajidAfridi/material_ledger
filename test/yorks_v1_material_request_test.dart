import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/controllers/yorks_v1_material_request_draft_controller.dart';
import 'package:material_ledger/shared/models/yorks_v1_boq.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/repositories/collection_store.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_material_request_repository.dart';
import 'package:material_ledger/shared/services/yorks_v1_boq_workbook_service.dart';
import 'package:material_ledger/shared/services/yorks_v1_material_request_document_service.dart';

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

    test('publishes text edits before local persistence completes', () async {
      final controller = YorksV1MaterialRequestDraftController(
        ownerAuthUserId: _siteEngineer,
        draftId: _draftId,
        store: _SlowMemoryStore<YorksV1MaterialRequestDraft>(),
        repository: _FakeRequestRepository(),
        uuidFactory: _Ids().next,
      );
      addTearDown(controller.dispose);

      await controller.addCustomLine();
      final line = controller.state.draft.lines.single;
      final pending = controller.updateLine(
        line.id,
        (current) => current.copyWith(
          description: 'Fast edit',
          quantity: '1',
          unit: 'Nos',
        ),
      );

      expect(controller.state.draft.lines.single.description, 'Fast edit');
      expect(controller.state.draft.canSubmitLocally, isFalse);
      await pending;
    });

    test(
      'copies an entire BOQ folder into an editable private draft',
      () async {
        final controller = YorksV1MaterialRequestDraftController(
          ownerAuthUserId: _siteEngineer,
          draftId: _draftId,
          store: _MemoryStore<YorksV1MaterialRequestDraft>(),
          repository: _FakeRequestRepository(),
          uuidFactory: _Ids().next,
        );
        addTearDown(controller.dispose);

        final worksheet = YorksV1BoqWorksheet(
          group: YorksV1BoqGroup(
            id: _boqGroupId,
            projectId: _projectId,
            name: 'Dampers',
            worksheetTitle: 'Dampers',
            displayOrder: 1,
            isCustom: false,
            isArchived: false,
            version: 1,
            rowCount: 2,
            columnCount: 4,
            updatedAt: DateTime.utc(2026, 8, 2),
          ),
          columns: const [
            YorksV1BoqColumn(
              id: 'description-column',
              heading: 'Description',
              displayOrder: 1,
              canonicalField: YorksV1BoqCanonicalField.description,
            ),
            YorksV1BoqColumn(
              id: 'quantity-column',
              heading: 'Qty',
              displayOrder: 2,
              canonicalField: YorksV1BoqCanonicalField.quantity,
            ),
            YorksV1BoqColumn(
              id: 'unit-column',
              heading: 'Unit',
              displayOrder: 3,
              canonicalField: YorksV1BoqCanonicalField.unit,
            ),
          ],
          rows: [
            YorksV1BoqRow(
              id: 'boq-row-1',
              displayOrder: 1,
              values: const {
                'description-column': 'Damper A',
                'quantity-column': '4',
                'unit-column': 'Nos',
              },
              canonicalValues: const {},
            ),
            YorksV1BoqRow(
              id: 'boq-row-2',
              displayOrder: 2,
              values: const {
                'description-column': 'Damper B',
                'quantity-column': '2',
                'unit-column': 'Nos',
              },
              canonicalValues: const {},
            ),
          ],
        );

        await controller.setProject(_projectId);
        await controller.addBoqRows(
          worksheet: worksheet,
          rowIds: worksheet.rows.map((row) => row.id),
        );

        expect(controller.state.draft.lines, hasLength(2));
        expect(controller.state.draft.lines.first.description, 'Damper A');
        expect(controller.state.draft.lines.first.quantity, '4');
        await controller.removeLine(controller.state.draft.lines.first.id);
        expect(controller.state.draft.lines, hasLength(1));
      },
    );

    test(
      'hydrates a saved server draft into the same editable local model',
      () async {
        final store = _MemoryStore<YorksV1MaterialRequestDraft>();
        final controller = YorksV1MaterialRequestDraftController(
          ownerAuthUserId: _siteEngineer,
          draftId: _draftId,
          store: store,
          repository: _FakeRequestRepository(),
          uuidFactory: _Ids().next,
        );
        addTearDown(controller.dispose);

        await controller.hydrateFromServer(
          _request(
            requestId: _draftId,
            version: 7,
            lines: [
              {
                'id': '73000000-0000-4000-8000-000000000010',
                'display_order': 1,
                'source_kind': 'custom',
                'item_description': 'Saved damper',
                'requested_qty': '2',
                'unit': 'Nos',
              },
            ],
          ),
        );

        expect(controller.state.draft.serverRecordVersion, 7);
        expect(controller.state.draft.lines.single.description, 'Saved damper');
        expect(store.readAll().single.lines.single.quantity, '2');
      },
    );
  });

  test('material request export is accepted by the shared BOQ importer', () {
    final draft = YorksV1MaterialRequestDraft(
      id: _draftId,
      ownerAuthUserId: _siteEngineer,
      submissionIdempotencyKey: 'submission-key',
      projectId: _projectId,
      scopeId: _scopeId,
      updatedAt: DateTime.utc(2026, 8, 2),
      lines: [
        YorksV1MaterialRequestLine(
          id: '73000000-0000-4000-8000-000000000011',
          displayOrder: 1,
          source: YorksV1MaterialRequestLineSource.custom,
          description: 'Motorized Smoke Damper',
          size: '600 x 600',
          planningModelTag: 'MSD-01A',
          brandOrigin: 'Betec UAE',
          quantity: '1',
          unit: 'Nos',
        ),
      ],
    );

    const codec = YorksV1BoqWorkbookCodec();
    final workbook = codec.decode(
      bytes: YorksV1MaterialRequestDocumentService().buildDraftExcel(draft),
      fileName: 'material_request_draft.xlsx',
    );
    final preview = codec.preview(
      workbook: workbook,
      sheet: workbook.sheets.single,
      fallbackTitle: 'Material Request Draft',
    );
    final fields = {
      for (final column in preview.columns)
        if (column.canonicalField != null)
          column.canonicalField!: column.sourceIndex,
    };

    expect(fields[YorksV1BoqCanonicalField.description], isNotNull);
    expect(fields[YorksV1BoqCanonicalField.quantity], isNotNull);
    expect(fields[YorksV1BoqCanonicalField.unit], isNotNull);
    expect(
      preview.rows.single.valueFor(
        fields[YorksV1BoqCanonicalField.description]!,
      ),
      'Motorized Smoke Damper',
    );
    expect(
      preview.rows.single.valueFor(fields[YorksV1BoqCanonicalField.quantity]!),
      '1',
    );
    expect(
      preview.rows.single.valueFor(fields[YorksV1BoqCanonicalField.unit]!),
      'Nos',
    );
  });

  test('round-trip export preserves an incomplete editable line', () {
    final draft = YorksV1MaterialRequestDraft(
      id: _draftId,
      ownerAuthUserId: _siteEngineer,
      submissionIdempotencyKey: 'submission-key',
      updatedAt: DateTime.utc(2026, 8, 2),
      lines: [
        YorksV1MaterialRequestLine(
          id: '73000000-0000-4000-8000-000000000012',
          displayOrder: 1,
          source: YorksV1MaterialRequestLineSource.custom,
          description: 'Line awaiting quantity',
          quantity: '',
          unit: 'Nos',
        ),
      ],
    );
    const codec = YorksV1BoqWorkbookCodec();
    final workbook = codec.decode(
      bytes: YorksV1MaterialRequestDocumentService().buildDraftExcel(draft),
      fileName: 'material_request_draft.xlsx',
    );
    final preview = codec.preview(
      workbook: workbook,
      sheet: workbook.sheets.single,
      fallbackTitle: 'Material Request Draft',
    );

    expect(preview.rows, hasLength(1));
    expect(
      preview.rows.single.valueFor(
        preview.columns
            .firstWhere(
              (column) =>
                  column.canonicalField == YorksV1BoqCanonicalField.description,
            )
            .sourceIndex,
      ),
      'Line awaiting quantity',
    );
  });

  test('accepts legacy BOQ and material-request headings on re-import', () {
    final worksheet = YorksV1BoqWorksheet(
      group: YorksV1BoqGroup(
        id: _boqGroupId,
        projectId: _projectId,
        name: 'Legacy export',
        worksheetTitle: 'Legacy export',
        displayOrder: 1,
        isCustom: false,
        isArchived: false,
        version: 1,
        rowCount: 1,
        columnCount: 7,
        updatedAt: DateTime.utc(2026, 8, 2),
      ),
      columns: const [
        YorksV1BoqColumn(id: 'a', heading: 'S:No', displayOrder: 1),
        YorksV1BoqColumn(
          id: 'b',
          heading: 'Item Description',
          displayOrder: 2,
        ),
        YorksV1BoqColumn(
          id: 'c',
          heading: 'Model/Serial No.',
          displayOrder: 3,
        ),
        YorksV1BoqColumn(id: 'd', heading: 'Make/Origin', displayOrder: 4),
        YorksV1BoqColumn(id: 'e', heading: 'Qty.', displayOrder: 5),
        YorksV1BoqColumn(id: 'f', heading: 'Unit', displayOrder: 6),
        YorksV1BoqColumn(id: 'g', heading: 'Unit Cost', displayOrder: 7),
      ],
      rows: [
        YorksV1BoqRow(
          id: 'legacy-row',
          displayOrder: 1,
          values: const {
            'a': '1',
            'b': 'Fire damper',
            'c': 'MSD-01A',
            'd': 'Betec UAE',
            'e': '2',
            'f': 'Nos',
            'g': '0',
          },
          canonicalValues: const {},
        ),
      ],
    );
    const codec = YorksV1BoqWorkbookCodec();
    final workbook = codec.decode(
      bytes: codec.encodeWorksheet(worksheet),
      fileName: 'legacy_export.xlsx',
    );
    final preview = codec.preview(
      workbook: workbook,
      sheet: workbook.sheets.single,
      fallbackTitle: 'Legacy export',
    );
    final mapped = {
      for (final column in preview.columns)
        if (column.canonicalField != null)
          column.canonicalField!: column.sourceIndex,
    };

    expect(mapped[YorksV1BoqCanonicalField.description], isNotNull);
    expect(mapped[YorksV1BoqCanonicalField.quantity], isNotNull);
    expect(mapped[YorksV1BoqCanonicalField.unit], isNotNull);
    expect(mapped[YorksV1BoqCanonicalField.planningModelTag], isNotNull);
    expect(mapped[YorksV1BoqCanonicalField.brandOrigin], isNotNull);
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

  test(
    'technical planning fields stay separate from commercial and receipt data',
    () {
      final line = YorksV1MaterialRequestLine.fromRpcJson({
        'id': _draftId,
        'display_order': 1,
        'source_kind': 'boq',
        'item_description': 'Fire damper',
        'technical_attributes': {
          'size': '600 x 600',
          'planning_model_tag': 'MSD-01A',
        },
        'requested_qty': '2',
        'unit': 'Nos',
      });

      expect(line.size, '600 x 600');
      expect(line.planningModelTag, 'MSD-01A');
      expect(line.unitCost, isNull);
      expect(line.toRpcJson()['technical_attributes'], {
        'size': '600 x 600',
        'planning_model_tag': 'MSD-01A',
      });
    },
  );
}

const _siteEngineer = '10000000-0000-4000-8000-000000000002';
const _projectId = '71000000-0000-4000-8000-000000000001';
const _scopeId = '72000000-0000-4000-8000-000000000001';
const _draftId = '73000000-0000-4000-8000-000000000001';
const _boqGroupId = '75000000-0000-4000-8000-000000000001';

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

class _SlowMemoryStore<T> extends _MemoryStore<T> {
  @override
  Future<void> writeAll(List<T> items) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await super.writeAll(items);
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
  List<Map<String, dynamic>> lines = const [],
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
  'lines': lines,
});
