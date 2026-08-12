import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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

  test(
    'inventory item payloads normalize descriptions and retain Ton and Boxes',
    () {
      const create = YorksV1InventoryAdjustmentInput(
        description: 'duct insulation',
        itemCode: 'INSUL-25',
        categoryId: 'supports-insulation',
        brandOrigin: 'k-Flex / italy',
        sizeText: 'large roll',
        modelReference: 'model-x remains mixed',
        unit: 'Ton',
        quantityDelta: '0',
        reason: 'Master item',
        idempotencyKey: '92000000-0000-4000-8000-000000000010',
      );
      const metadata = YorksV1InventoryItemMetadataInput(
        inventoryItemId: '93000000-0000-4000-8000-000000000010',
        expectedMetadataVersion: 1,
        itemCode: 'FITT-01',
        description: 'box of fittings',
        categoryId: 'general',
        brandOrigin: null,
        sizeText: null,
        modelReference: null,
        unit: 'Boxes',
        minimumStock: null,
        locationBin: null,
        notes: null,
        idempotencyKey: '93000000-0000-4000-8000-000000000011',
      );
      const imported = YorksV1InventoryImportRowInput(
        sourceRowNumber: 2,
        description: 'ton of sealant',
        unit: 'Ton',
        stockAction: 'opening_balance',
        quantity: '1',
        reason: 'Opening count',
      );

      expect(
        create.toCreateItemRpcPayload(),
        containsPair('item_description', 'Duct insulation'),
      );
      expect(create.toCreateItemRpcPayload(), containsPair('unit', 'Ton'));
      expect(
        create.toCreateItemRpcPayload(),
        containsPair('brand_origin', 'K-Flex / italy'),
      );
      expect(
        create.toCreateItemRpcPayload(),
        containsPair('size_text', 'Large roll'),
      );
      expect(
        create.toCreateItemRpcPayload(),
        containsPair('model_reference', 'Model-x remains mixed'),
      );
      expect(
        metadata.toRpcPayload(),
        containsPair('item_description', 'Box of fittings'),
      );
      expect(metadata.toRpcPayload(), containsPair('unit', 'Boxes'));
      expect(
        imported.toRpcJson(),
        containsPair('item_description', 'Ton of sealant'),
      );
    },
  );

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

  test('metadata edit payload cannot include stock or reservation fields', () {
    const input = YorksV1InventoryItemMetadataInput(
      inventoryItemId: '93000000-0000-4000-8000-000000000001',
      expectedMetadataVersion: 4,
      itemCode: 'INSUL-25',
      description: 'Duct insulation',
      categoryId: 'supports-insulation',
      brandOrigin: 'K-Flex / Italy',
      sizeText: '25 mm',
      modelReference: 'K-Flex ST',
      unit: 'Roll',
      minimumStock: '5',
      locationBin: 'G-02',
      notes: 'Keep dry',
      idempotencyKey: '93000000-0000-4000-8000-000000000002',
    );

    final payload = input.toRpcPayload();
    expect(payload, containsPair('expected_metadata_version', 4));
    expect(payload, containsPair('size_text', '25 mm'));
    expect(payload, isNot(contains('quantity')));
    expect(payload, isNot(contains('on_hand_qty')));
    expect(payload, isNot(contains('reserved_qty')));
    expect(payload, isNot(contains('expected_version')));
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
    'an unknown category stays pending until Procurement explicitly maps it',
    () {
      const codec = YorksV1InventoryWorkbookCodec();
      final preview = codec.previewFromMatrix(
        fileName: 'new-category.csv',
        matrix: const [
          [
            'Item Code',
            'Item Description',
            'Category',
            'Unit',
            'Stock Action',
            'Quantity',
            'Reason',
          ],
          [
            'MFD-002',
            'motorized fire damper',
            'MFD',
            'Nos',
            'Opening Balance',
            '100',
            'Opening count',
          ],
        ],
        categories: _categories,
        inventoryItems: const [],
      );

      expect(preview.canCommit, isFalse);
      expect(preview.errorCount, 1);
      expect(preview.rows.single.requiresCategoryDecision, isTrue);
      expect(preview.rows.single.categoryId, isNull);
      expect(preview.rows.single.newCategoryName, isNull);

      final existing = codec.applyCategoryDecision(
        preview: preview,
        sourceCategory: 'MFD',
        categoryId: 'general',
      );
      expect(existing.canCommit, isTrue);
      expect(existing.rows.single.categoryId, 'general');
      expect(existing.rows.single.newCategoryName, isNull);

      final newParent = codec.applyCategoryDecision(
        preview: preview,
        sourceCategory: 'MFD',
        createNew: true,
      );
      expect(newParent.canCommit, isTrue);
      expect(newParent.rows.single.categoryId, isNull);
      expect(newParent.rows.single.newCategoryName, 'MFD');
      expect(newParent.rows.single.requiresCategoryDecision, isTrue);
    },
  );

  test('hierarchical category paths from the import template map exactly', () {
    final categories = [
      YorksV1InventoryCategory(
        id: 'round',
        name: 'Round',
        parentCategoryId: 'air-terminals',
        parentName: 'Air Terminals',
        displayPath: 'Air Terminals › Round',
        isSystem: true,
        isActive: true,
        recordVersion: 2,
        itemCount: 0,
        aliases: const ['Round Air Terminal'],
        createdByDisplayName: 'Yorks standard',
        createdAt: DateTime.utc(2026, 8, 9),
      ),
      YorksV1InventoryCategory(
        id: 'linear-grille',
        name: 'Linear Grille',
        parentCategoryId: 'air-terminals',
        parentName: 'Air Terminals',
        displayPath: 'Air Terminals › Linear Grille',
        isSystem: true,
        isActive: true,
        recordVersion: 2,
        itemCount: 0,
        aliases: const ['Linear Grill'],
        createdByDisplayName: 'Yorks standard',
        createdAt: DateTime.utc(2026, 8, 9),
      ),
    ];
    const codec = YorksV1InventoryWorkbookCodec();
    final preview = codec.previewFromMatrix(
      fileName: 'test123.xlsx',
      matrix: const [
        [
          'Item Code',
          'Item Description',
          'Category',
          'Unit',
          'Stock Action',
          'Quantity',
          'Reason',
        ],
        [
          'AT-RND-001',
          'Round Air Terminal 300 mm',
          'Air Terminals - Round',
          'Nos',
          'Opening Balance',
          '12',
          'Initial warehouse count',
        ],
        [
          'AT-LG-001',
          'Linear Grille 1200 × 150 mm',
          'Air Terminals - Linear Grille',
          'Nos',
          'Add Stock',
          '18',
          'Stock received against supplier delivery',
        ],
      ],
      categories: categories,
      inventoryItems: const [],
    );

    expect(preview.canCommit, isTrue);
    expect(preview.errorCount, 0);
    expect(
      preview.rows.map((row) => row.categoryId),
      orderedEquals(const ['round', 'linear-grille']),
    );
    expect(
      preview.rows.map((row) => row.requiresCategoryDecision),
      everyElement(isFalse),
    );
  });

  test(
    'duplicate item codes remain blocking after a category is confirmed',
    () {
      const codec = YorksV1InventoryWorkbookCodec();
      final preview = codec.previewFromMatrix(
        fileName: 'duplicate-code.csv',
        matrix: const [
          [
            'Item Code',
            'Item Description',
            'Category',
            'Unit',
            'Stock Action',
            'Quantity',
            'Reason',
          ],
          [
            'MFD-001',
            'motorized fire damper',
            'MFD',
            'Nos',
            'Opening Balance',
            '100',
            'Opening count',
          ],
          [
            'MFD-001',
            'another motorized fire damper',
            'MFD',
            'Nos',
            'Opening Balance',
            '100',
            'Opening count',
          ],
        ],
        categories: _categories,
        inventoryItems: const [],
      );

      final reviewed = codec.applyCategoryDecision(
        preview: preview,
        sourceCategory: 'MFD',
        createNew: true,
      );
      expect(reviewed.rows.map((row) => row.hasErrors), everyElement(isTrue));
      expect(reviewed.canCommit, isFalse);
      expect(reviewed.errorCount, 2);
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

  test('stock register export is a readable operational XLSX snapshot', () {
    final generatedAt = DateTime(2026, 8, 9, 15, 5);
    final workspace = YorksV1InventoryWorkspace(
      items: [
        YorksV1LogisticsInventoryItem(
          id: 'register-item',
          itemCode: 'SAR-500',
          description: 'Supply Air Register',
          categoryId: 'category-linear',
          categoryName: 'Linear Grille',
          categoryPath: 'Air Terminals › Linear Grille',
          brandOrigin: 'Betec CAD / UAE',
          unit: 'Nos',
          minimumStock: '5.0000',
          locationBin: 'A-01',
          isActive: true,
          onHandQuantity: '64.0000',
          reservedQuantity: '6.0000',
          availableQuantity: '58.0000',
          recordVersion: 1,
          updatedAt: generatedAt,
        ),
      ],
    );

    final bytes =
        YorksV1PlatformInventoryWorkbookFileService.buildStockRegisterWorkbook(
          workspace: workspace,
          generatedAt: generatedAt,
        );
    final workbook = const YorksV1BoqWorkbookCodec().decode(
      fileName:
          YorksV1PlatformInventoryWorkbookFileService.stockRegisterSuggestedName(
            generatedAt,
          ),
      bytes: bytes,
    );
    final archive = ZipDecoder().decodeBytes(bytes);

    expect(workbook.sheets, hasLength(1));
    expect(
      workbook.sheets.single.rows[1],
      equals(const [
        'Item Code',
        'Item Description',
        'Category',
        'Brand / Origin',
        'Unit',
        'On Hand',
        'Reserved',
        'Available',
        'Minimum Stock',
        'Location / Bin',
        'Status',
        'Last Updated',
      ]),
    );
    expect(
      workbook.sheets.single.rows[2],
      equals(const [
        'SAR-500',
        'Supply Air Register',
        'Air Terminals',
        'Betec CAD / UAE',
        'Nos',
        '64',
        '6',
        '58',
        '5',
        'A-01',
        'In Stock',
        '09 Aug 2026, 03:05 PM',
      ]),
    );
    expect(archive.findFile('xl/styles.xml'), isNotNull);
    final sheetXml = utf8.decode(
      archive.findFile('xl/worksheets/sheet1.xml')!.readBytes()!,
    );
    expect(sheetXml, contains('state="frozen"'));
    expect(sheetXml, contains('<autoFilter ref="A2:L3"/>'));
  });

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
