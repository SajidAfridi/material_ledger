import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/controllers/yorks_v1_boq_controller.dart';
import 'package:material_ledger/shared/models/yorks_v1_boq.dart';
import 'package:material_ledger/shared/models/yorks_v1_boq_workbook.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_boq_repository.dart';
import 'package:material_ledger/shared/services/yorks_v1_boq_workbook_service.dart';

void main() {
  test(
    'suggests only exact canonical cost headings as commercial mappings',
    () {
      const codec = YorksV1BoqWorkbookCodec();
      final workbook = YorksV1BoqParsedWorkbook(
        fileName: 'commercial.xlsx',
        sheets: [
          YorksV1BoqWorkbookSheet(
            name: 'BOQ',
            rows: const [
              [
                'Unit Cost',
                'Total Cost',
                'Unit Price',
                'Total Amount',
                'Operating Cost Index',
              ],
              ['125.50', '251.00', '125.50', '251.00', 'OCI-7'],
            ],
          ),
        ],
      );

      final preview = codec.preview(
        workbook: workbook,
        sheet: workbook.sheets.single,
        fallbackTitle: 'BOQ',
        headerRowIndex: 0,
      );

      expect(
        preview.columns[0].canonicalField,
        YorksV1BoqCanonicalField.unitCost,
      );
      expect(
        preview.columns[1].canonicalField,
        YorksV1BoqCanonicalField.totalCost,
      );
      expect(
        preview.columns[2].canonicalField,
        YorksV1BoqCanonicalField.unitCost,
      );
      expect(
        preview.columns[3].canonicalField,
        YorksV1BoqCanonicalField.totalCost,
      );
      expect(preview.columns[4].canonicalField, isNull);
    },
  );

  test(
    'classifies imported costs and reuses command identity after an uncertain failure',
    () async {
      final repository = _RetryImportRepository(_worksheet());
      final controller = YorksV1BoqWorksheetController(
        groupId: _groupId,
        repository: repository,
        uuidFactory: _Ids().next,
        canManageCommercials: true,
      );
      addTearDown(controller.dispose);
      await controller.load();

      YorksV1BoqImportPreview preview({bool reverseValueOrder = false}) =>
          YorksV1BoqImportPreview(
            fileName: 'commercial.xlsx',
            worksheetName: 'BOQ',
            title: 'Commercial BOQ',
            headerRowIndex: 0,
            columns: const [
              YorksV1BoqImportColumn(
                sourceIndex: 0,
                heading: 'Description',
                canonicalField: YorksV1BoqCanonicalField.description,
              ),
              YorksV1BoqImportColumn(
                sourceIndex: 1,
                heading: 'Unit Cost',
                canonicalField: YorksV1BoqCanonicalField.unitCost,
              ),
              YorksV1BoqImportColumn(
                sourceIndex: 2,
                heading: 'Total Cost',
                canonicalField: YorksV1BoqCanonicalField.totalCost,
              ),
              YorksV1BoqImportColumn(
                sourceIndex: 3,
                heading: 'Operating Cost Index',
              ),
            ],
            rows: [
              YorksV1BoqImportRow(
                sourceRowNumber: 2,
                values: reverseValueOrder
                    ? const {
                        3: 'OCI-7',
                        2: '251.00',
                        1: '125.50',
                        0: 'Imported fan',
                      }
                    : const {
                        0: 'Imported fan',
                        1: '125.50',
                        2: '251.00',
                        3: 'OCI-7',
                      },
              ),
            ],
            validationIssues: const [],
          );

      expect(await controller.importWorkbook(preview()), isFalse);
      expect(controller.state.status, YorksV1BoqSyncStatus.failed);
      expect(
        controller.state.errorCode,
        YorksV1DomainErrorCode.backendUnavailable,
      );
      expect(
        await controller.importWorkbook(preview(reverseValueOrder: true)),
        isTrue,
      );

      expect(repository.inputs, hasLength(2));
      final first = repository.inputs.first;
      final retry = repository.inputs.last;
      expect(retry.idempotencyKey, first.idempotencyKey);
      expect(retry.toRpcPayload(), equals(first.toRpcPayload()));
      expect(first.worksheet.columns.map((column) => column.isCommercial), [
        false,
        true,
        true,
        false,
      ]);
      expect(first.worksheet.rows.single.canonicalValues, {
        'description': 'Imported fan',
      });
    },
  );

  test('manual canonical cost columns are classified before save', () async {
    final repository = _RetryImportRepository(_worksheet(), failFirst: false);
    final controller = YorksV1BoqWorksheetController(
      groupId: _groupId,
      repository: repository,
      uuidFactory: _Ids().next,
      canManageCommercials: true,
    );
    addTearDown(controller.dispose);
    await controller.load();

    controller.addColumn(
      heading: 'Unit Cost',
      canonicalField: YorksV1BoqCanonicalField.unitCost,
    );
    final costColumn = controller.state.worksheet!.columns.last;
    final row = controller.addBlankRow();
    controller.updateCell(
      rowId: row.id,
      columnId: costColumn.id,
      value: '125.50',
    );

    expect(costColumn.isCommercial, isTrue);
    expect(controller.state.worksheet!.rows.single.canonicalValues, isEmpty);
  });

  test('commercial canonical wire values remain round-trip safe', () {
    expect(
      YorksV1BoqCanonicalField.fromWireValue('unit_cost'),
      YorksV1BoqCanonicalField.unitCost,
    );
    expect(
      YorksV1BoqCanonicalField.fromWireValue('total_cost'),
      YorksV1BoqCanonicalField.totalCost,
    );
  });
}

const _projectId = '10000000-0000-4000-8000-000000000010';
const _groupId = '10000000-0000-4000-8000-000000000011';

YorksV1BoqWorksheet _worksheet() => YorksV1BoqWorksheet(
  group: YorksV1BoqGroup(
    id: _groupId,
    projectId: _projectId,
    name: 'Imported BOQ',
    worksheetTitle: 'Imported BOQ',
    displayOrder: 1,
    isCustom: true,
    isArchived: false,
    version: 1,
    rowCount: 0,
    columnCount: 0,
    updatedAt: DateTime.utc(2026, 8, 9),
    scopeId: '10000000-0000-4000-8000-000000000099',
    scopeKind: 'common',
    scopeName: 'Common',
  ),
  columns: const [],
  rows: const [],
);

class _RetryImportRepository implements YorksV1BoqRepository {
  _RetryImportRepository(this.worksheet, {this.failFirst = true});

  final YorksV1BoqWorksheet worksheet;
  final bool failFirst;
  final List<YorksV1ImportBoqWorksheetInput> inputs = [];

  @override
  Future<YorksV1BoqWorksheet> importWorksheet(
    YorksV1ImportBoqWorksheetInput input,
  ) async {
    inputs.add(input);
    if (failFirst && inputs.length == 1) {
      throw StateError('response lost after request was sent');
    }
    return input.worksheet.copyWith(
      group: input.worksheet.group.copyForTest(
        version: input.expectedVersion + 1,
      ),
    );
  }

  @override
  Future<YorksV1BoqWorksheet> getWorksheet(String groupId) async => worksheet;

  @override
  Future<YorksV1BoqGroup> archiveGroup(
    YorksV1ArchiveBoqGroupInput input,
  ) async => worksheet.group;

  @override
  Future<YorksV1BoqGroup> assignLegacyGroupScope(
    YorksV1AssignLegacyBoqGroupScopeInput input,
  ) async => worksheet.group;

  @override
  Future<YorksV1BoqGroup> createCustomGroup(
    YorksV1CreateBoqGroupInput input,
  ) async => worksheet.group;

  @override
  Future<YorksV1BoqGroup> renameGroup(YorksV1RenameBoqGroupInput input) async =>
      worksheet.group;

  @override
  Future<YorksV1BoqGroup> restoreGroup(
    YorksV1RestoreBoqGroupInput input,
  ) async => worksheet.group;

  @override
  Future<List<YorksV1BoqGroup>> listGroups(String projectId) async => [
    worksheet.group,
  ];

  @override
  Future<List<YorksV1BoqGroup>> listGroupsForScope(
    String projectId, {
    String? scopeId,
  }) async => [worksheet.group];

  @override
  Future<List<YorksV1BoqFolderManagementItem>> listFolderManagement(
    String projectId, {
    required String scopeId,
    bool includeArchived = true,
  }) async => [
    YorksV1BoqFolderManagementItem(
      group: worksheet.group,
      isSystemDefault: !worksheet.group.isCustom,
      canRename: true,
      canArchive: worksheet.group.isCustom,
      canRestore: false,
    ),
  ];

  @override
  Future<YorksV1BoqWorksheet> saveWorksheet(
    YorksV1SaveBoqWorksheetInput input,
  ) async => input.worksheet;
}

extension on YorksV1BoqGroup {
  YorksV1BoqGroup copyForTest({required int version}) => YorksV1BoqGroup(
    id: id,
    projectId: projectId,
    name: name,
    worksheetTitle: worksheetTitle,
    displayOrder: displayOrder,
    isCustom: isCustom,
    isArchived: isArchived,
    version: version,
    rowCount: rowCount,
    columnCount: columnCount,
    updatedAt: updatedAt,
    scopeId: scopeId,
    scopeKind: scopeKind,
    scopeCode: scopeCode,
    scopeName: scopeName,
    isLegacyUnassigned: isLegacyUnassigned,
  );
}

class _Ids {
  var _value = 20;

  String next() =>
      '10000000-0000-4000-8000-${(_value++).toString().padLeft(12, '0')}';
}
