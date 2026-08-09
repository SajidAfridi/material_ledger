import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/controllers/yorks_v1_inventory_import_controller.dart';
import 'package:material_ledger/shared/models/yorks_v1_inventory_workbook.dart';
import 'package:material_ledger/shared/models/yorks_v1_logistics.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_logistics_repository.dart';
import 'package:material_ledger/shared/services/yorks_v1_boq_workbook_service.dart';
import 'package:material_ledger/shared/services/yorks_v1_inventory_workbook_service.dart';
import 'package:material_ledger/shared/services/yorks_v1_inventory_workbook_template.dart';

void main() {
  test('approved category casing preserves Yorks acronyms', () {
    expect(
      yorksV1InventoryCategoryDisplayName('air terminals - sed'),
      'Air Terminals - SED',
    );
    expect(
      yorksV1InventoryCategoryDisplayName('hvac gi pvc red'),
      'HVAC GI PVC RED',
    );
  });

  test('create-item payload keeps metadata separate from opening stock', () {
    const input = YorksV1InventoryAdjustmentInput(
      description: 'Round air diffuser',
      itemCode: 'RAD-300',
      categoryId: 'round',
      brandOrigin: 'Yorks / UAE',
      sizeText: '300 mm',
      modelReference: 'RAD-300-A',
      unit: 'Nos',
      minimumStock: '4',
      locationBin: 'B-03',
      notes: 'Keep dry',
      quantityDelta: '12',
      reference: 'GRN-104',
      reason: 'Opening warehouse count',
      idempotencyKey: '92000000-0000-4000-8000-000000000002',
    );

    expect(input.createsItem, isTrue);
    expect(
      input.toCreateItemRpcPayload(),
      containsPair('opening_quantity', '12'),
    );
    expect(input.toCreateItemRpcPayload(), containsPair('size_text', '300 mm'));
    expect(
      input.toCreateItemRpcPayload(),
      containsPair('model_reference', 'RAD-300-A'),
    );
    expect(input.toCreateItemRpcPayload(), isNot(contains('quantity_delta')));
    expect(input.toCreateItemRpcPayload(), isNot(contains('expected_version')));
  });

  test('existing-item movement carries action and optimistic version only', () {
    const input = YorksV1InventoryAdjustmentInput(
      inventoryItemId: '93000000-0000-4000-8000-000000000001',
      expectedVersion: 7,
      action: 'remove',
      quantityDelta: '3',
      reference: 'COUNT-22',
      reason: 'Approved count correction',
      idempotencyKey: '92000000-0000-4000-8000-000000000003',
    );

    expect(input.createsItem, isFalse);
    expect(input.toStockMovementRpcPayload(), containsPair('action', 'remove'));
    expect(
      input.toStockMovementRpcPayload(),
      containsPair('expected_version', 7),
    );
    expect(
      input.toStockMovementRpcPayload(),
      isNot(contains('item_description')),
    );
    expect(input.toStockMovementRpcPayload(), isNot(contains('category_id')));
  });

  test(
    'category matcher applies exact aliases but only suggests close text',
    () {
      const matcher = YorksV1InventoryCategoryMatcher();
      expect(matcher.exact('Round AC Terminal', _categories)?.id, 'round');
      expect(matcher.exact('Round air terminal', _categories)?.id, 'round');
      expect(matcher.exact('Round air outlet', _categories), isNull);
      expect(
        matcher.rank('Round air outlet', _categories).first.category.id,
        'round',
      );
    },
  );

  test(
    'one confirmed category decision propagates to identical source text',
    () {
      const codec = YorksV1InventoryWorkbookCodec();
      final preview = codec.previewFromMatrix(
        fileName: 'close-match.csv',
        matrix: const [
          [
            'Item Description',
            'Category',
            'Brand / Origin',
            'Unit',
            'Stock Action',
            'Quantity',
            'Reason',
          ],
          [
            'Round diffuser 250',
            'Round air termnial',
            'Yorks',
            'Nos',
            'Add Stock',
            '2',
            'Receipt 1',
          ],
          [
            'Round diffuser 300',
            'Round air termnial',
            'Yorks',
            'Nos',
            'Add Stock',
            '3',
            'Receipt 2',
          ],
        ],
        categories: _categories,
        inventoryItems: const [],
      );
      expect(preview.errorCount, 2);
      final reviewed = codec.applyCategoryDecision(
        preview: preview,
        sourceCategory: 'Round air termnial',
        categoryId: 'round',
      );
      expect(reviewed.canCommit, isTrue);
      expect(reviewed.rows.map((row) => row.categoryId), everyElement('round'));
      expect(
        reviewed.rows.map((row) => row.toRpcInput().sourceCategoryText),
        everyElement('Round air termnial'),
      );
    },
  );

  test(
    'the embedded download is the exact readable five-sheet client workbook',
    () {
      final bytes = Uint8List.fromList(
        base64Decode(yorksV1InventoryWorkbookTemplateBase64),
      );
      expect(bytes.lengthInBytes, 18055);
      final workbook = const YorksV1BoqWorkbookCodec().decode(
        fileName: 'Yorks_Warehouse_Inventory_Import_Template.xlsx',
        bytes: bytes,
      );
      expect(workbook.sheets, hasLength(5));
      expect(workbook.sheets.first.name, 'Inventory Import');
      expect(workbook.sheets.first.rows.first, contains('Item Description *'));
    },
  );

  test(
    'failed import retains preview and reuses the same command identity',
    () async {
      final repository = _ImportRepository()..failures = 1;
      final controller = YorksV1InventoryImportController(
        repository: repository,
        fileService: const _UnusedFileService(),
        uuidFactory: () => '92000000-0000-4000-8000-000000000001',
      );
      controller.prepareSelected(
        YorksV1InventorySelectedWorkbook(
          fileName: 'stock.csv',
          bytes: Uint8List.fromList(
            utf8.encode(
              'Item Description,Category,Brand / Origin,Unit,Stock Action,Quantity,Reason\r\n'
              'Access panel,General & Custom,UAE,Nos,Add Stock,2,Checked receipt',
            ),
          ),
        ),
        YorksV1InventoryWorkspace(items: const [], categories: _categories),
      );

      expect(await controller.commit(), isNull);
      expect(controller.state.preview, isNotNull);
      expect(controller.state.status, YorksV1InventoryImportStatus.failed);

      final result = await controller.commit();
      expect(result?.rowCount, 1);
      expect(repository.inputs, hasLength(2));
      expect(
        repository.inputs[0].idempotencyKey,
        repository.inputs[1].idempotencyKey,
      );
      expect(
        repository.inputs[0].toRpcPayload(),
        repository.inputs[1].toRpcPayload(),
      );
    },
  );
}

final _categories = [
  YorksV1InventoryCategory(
    id: 'round',
    name: 'Air Terminals - Round',
    isSystem: true,
    isActive: true,
    recordVersion: 1,
    itemCount: 0,
    aliases: const ['Round AC Terminal', 'Round Air Terminal'],
    createdByDisplayName: 'Yorks standard',
    createdAt: DateTime.utc(2026, 8, 9),
  ),
  YorksV1InventoryCategory(
    id: 'general',
    name: 'General & Custom',
    isSystem: true,
    isActive: true,
    recordVersion: 1,
    itemCount: 0,
    aliases: const ['General', 'Other'],
    createdByDisplayName: 'Yorks standard',
    createdAt: DateTime.utc(2026, 8, 9),
  ),
];

class _ImportRepository implements YorksV1LogisticsRepository {
  int failures = 0;
  final inputs = <YorksV1InventoryImportInput>[];

  @override
  Future<YorksV1InventoryImportResult> importInventory(
    YorksV1InventoryImportInput input,
  ) async {
    inputs.add(input);
    if (failures-- > 0) throw StateError('lost response');
    return const YorksV1InventoryImportResult(
      importBatchId: 'batch',
      rowCount: 1,
      createdItems: 1,
      updatedItems: 0,
      createdCategories: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedFileService implements YorksV1InventoryWorkbookFileService {
  const _UnusedFileService();

  @override
  Future<YorksV1InventorySelectedWorkbook?> selectWorkbook() =>
      throw UnimplementedError();

  @override
  Future<bool> saveImportTemplate() => throw UnimplementedError();

  @override
  Future<bool> saveStockRegister({
    required YorksV1InventoryWorkspace workspace,
    required String suggestedName,
  }) => throw UnimplementedError();
}
