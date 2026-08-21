import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/controllers/yorks_v1_inventory_import_controller.dart';
import 'package:material_ledger/shared/models/yorks_v1_boq.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_inventory_supplier.dart';
import 'package:material_ledger/shared/models/yorks_v1_inventory_workbook.dart';
import 'package:material_ledger/shared/models/yorks_v1_logistics.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_logistics_repository.dart';
import 'package:material_ledger/shared/services/yorks_v1_boq_workbook_service.dart';
import 'package:material_ledger/shared/services/yorks_v1_inventory_workbook_service.dart';

const _packRoot =
    '/Users/eapple/Downloads/'
    'Yorks_R38_9_Inventory_Supplier_Folders_Client_Review_Pack/excel';
const _perfectWorkbookPath =
    '/Users/eapple/Downloads/'
    'Yorks_Warehouse_Inventory_Master_Import_PERFECT (1).xlsx';

void main() {
  group('R38.9 controlled mapping', () {
    test('maps normalized headers by source position and exposes samples', () {
      const codec = YorksV1InventoryWorkbookCodec();
      final matrix = <List<String>>[
        const ['Yorks inventory receipt'],
        const [
          'Supplier Ref.',
          'QTY',
          'ITEM NAME',
          'SOURCE TYPE',
          'CATEGORY',
          'UNIT OF MEASURE',
          'ACTION',
          'REASON',
          'RECEIVED ON',
          'VENDOR NAME',
        ],
        const [
          'DN-001',
          '10',
          'Linear grille',
          'External Supplier',
          'Air Terminals',
          'Nos',
          'Add Stock',
          'Receipt',
          '2026-08-20',
          'TROX Middle East LLC',
        ],
      ];

      final source = codec.sourceFromMatrix(
        fileName: 'shuffled.csv',
        matrix: matrix,
      );
      final mapping = codec.proposeMapping(source);

      expect(mapping.canContinue, isTrue);
      expect(
        mapping.sourceIndex(YorksV1InventoryControlledField.description),
        2,
      );
      expect(
        mapping.sourceIndex(
          YorksV1InventoryControlledField.externalSupplierName,
        ),
        9,
      );
      expect(
        mapping.samplesFor(
          YorksV1InventoryControlledField.externalSupplierName,
        ),
        ['TROX Middle East LLC'],
      );
      expect(source.sourceRowNumbers, [3]);
      expect(source.fileSha256, matches(RegExp(r'^[a-f0-9]{64}$')));
    });

    test('blocks missing required and duplicate source mappings', () {
      const codec = YorksV1InventoryWorkbookCodec();
      final source = codec.sourceFromMatrix(
        fileName: 'mapping.csv',
        matrix: [_officialHeaders, _validExternalRow],
      );
      var mapping = codec.proposeMapping(source);
      expect(mapping.canContinue, isTrue);

      mapping = codec.updateMapping(
        mapping: mapping,
        field: YorksV1InventoryControlledField.description,
        sourceColumnIndex: null,
      );
      expect(mapping.canContinue, isFalse);
      expect(
        mapping.issues.map((issue) => issue.code),
        contains(YorksV1InventoryColumnMappingIssueCode.missingRequiredField),
      );

      mapping = codec.proposeMapping(source);
      mapping = codec.updateMapping(
        mapping: mapping,
        field: YorksV1InventoryControlledField.itemCode,
        sourceColumnIndex: mapping.sourceIndex(
          YorksV1InventoryControlledField.description,
        ),
      );
      expect(mapping.canContinue, isFalse);
      expect(
        mapping.issues.map((issue) => issue.code),
        contains(YorksV1InventoryColumnMappingIssueCode.duplicateSourceColumn),
      );
    });

    test('accepts the streamlined template without Source Type or Reason', () {
      const codec = YorksV1InventoryWorkbookCodec();
      const headers = <String>[
        'S:No',
        'Category *',
        'Item Code *',
        'Item Description *',
        'External Supplier Name',
        'Stock Action *',
        'Quantity *',
        'Unit *',
        'Notes',
      ];
      const row = <String>[
        '1',
        'AC Unit',
        'ACU-001',
        'Split AC Unit',
        '',
        'Opening Balance',
        '2',
        'Cartridge',
        '',
      ];
      final source = codec.sourceFromMatrix(
        fileName: 'streamlined.csv',
        matrix: const [headers, row],
      );
      final preview = codec.previewFromSource(
        mapping: codec.proposeMapping(source, requireR38_9Fields: true),
        categories: [
          YorksV1InventoryCategory(
            id: 'ac-unit',
            name: 'AC Unit',
            isSystem: true,
            isActive: true,
            recordVersion: 1,
            itemCount: 0,
            aliases: [],
            createdByDisplayName: 'Yorks',
            createdAt: DateTime(2026, 8, 20),
          ),
        ],
        inventoryItems: const [],
        suppliers: _suppliers,
      );

      expect(
        preview.rows.single.stockAction,
        YorksV1InventoryStockAction.openingBalance,
      );
      expect(
        preview.rows.single.sourceType,
        YorksV1InventorySourceType.openingBalance,
      );
      expect(preview.rows.single.usesUnknownSupplier, isTrue);
      expect(preview.rows.single.reason, 'Inventory import: Opening Balance');
      expect(preview.rows.single.unit, 'Cartridge');
      expect(preview.rows.single.hasErrors, isFalse);
    });

    test('rejects files above 25 MiB and sources above 20,000 rows', () {
      const codec = YorksV1InventoryWorkbookCodec();
      expect(
        () => codec.read(
          YorksV1InventorySelectedWorkbook(
            fileName: 'oversize.csv',
            bytes: Uint8List(25 * 1024 * 1024 + 1),
          ),
        ),
        throwsA(isA<YorksV1DomainException>()),
      );
      expect(
        () => codec.sourceFromMatrix(
          fileName: 'too-many.csv',
          matrix: [
            _officialHeaders,
            for (var index = 0; index < 20001; index++) _validExternalRow,
          ],
        ),
        throwsA(isA<YorksV1DomainException>()),
      );
      expect(
        codec
            .sourceFromMatrix(
              fileName: 'maximum.csv',
              matrix: [
                _officialHeaders,
                for (var index = 0; index < 20000; index++) _validExternalRow,
              ],
            )
            .rowCount,
        20000,
      );
    });

    test('XLSX exceeds the inherited BOQ row cap safely', () {
      const codec = YorksV1InventoryWorkbookCodec();
      final bytes = const YorksV1BoqWorkbookCodec().encodeWorksheet(
        _inventoryWorksheet(name: 'Inventory Import', rowCount: 10001),
      );

      final source = codec.read(
        YorksV1InventorySelectedWorkbook(
          fileName: 'controlled.xlsx',
          bytes: bytes,
        ),
      );

      expect(source.rowCount, 10001);
      expect(source.worksheetName, 'Inventory Import');
      expect(source.availableWorksheetNames, ['Inventory Import']);
    });

    test('ambiguous multi-sheet XLSX fails closed instead of using first', () {
      const codec = YorksV1InventoryWorkbookCodec();
      final bytes = const YorksV1BoqWorkbookCodec().encodeWorksheets([
        _inventoryWorksheet(name: 'Sheet A', rowCount: 1),
        _inventoryWorksheet(name: 'Sheet B', rowCount: 1),
      ]);
      final workbook = YorksV1InventorySelectedWorkbook(
        fileName: 'ambiguous.xlsx',
        bytes: bytes,
      );

      expect(
        () => codec.read(workbook),
        throwsA(isA<YorksV1DomainException>()),
      );
      expect(codec.availableWorksheetNames(workbook), ['Sheet A', 'Sheet B']);

      final selected = codec.read(workbook.selectWorksheet('Sheet B'));
      expect(selected.worksheetName, 'Sheet B');
      expect(selected.availableWorksheetNames, ['Sheet A', 'Sheet B']);
      expect(selected.rowCount, 1);

      final hiddenOptions = codec.availableWorksheets(
        YorksV1InventorySelectedWorkbook(
          fileName: 'hidden.xlsx',
          bytes: _markWorksheetHidden(bytes, 'Sheet B'),
        ),
      );
      expect(hiddenOptions.map((option) => option.name), [
        'Sheet A',
        'Sheet B',
      ]);
      expect(hiddenOptions.first.isHidden, isFalse);
      expect(hiddenOptions.last.isHidden, isTrue);
    });

    test(
      '20,000-row validation stays bounded with indexed master matching',
      () {
        const codec = YorksV1InventoryWorkbookCodec();
        final matrix = <List<String>>[
          _officialHeaders,
          for (var index = 0; index < 20000; index++)
            [
              for (var column = 0; column < _validExternalRow.length; column++)
                column == 1
                    ? 'PERF-${index.toString().padLeft(5, '0')}'
                    : _validExternalRow[column],
            ],
        ];
        final stopwatch = Stopwatch()..start();
        final source = codec.sourceFromMatrix(
          fileName: 'maximum.csv',
          matrix: matrix,
        );
        final preview = codec.previewFromSource(
          mapping: codec.proposeMapping(source),
          categories: _categories,
          inventoryItems: const [],
          suppliers: _suppliers,
        );
        stopwatch.stop();

        expect(preview.rowCount, 20000);
        expect(preview.canCommit, isTrue);
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 8)));
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );
  });

  group('R38.9 supplier and receipt validation', () {
    test('normalizes Excel date serials while retaining raw evidence', () {
      const codec = YorksV1InventoryWorkbookCodec();
      final row = List<String>.from(_validExternalRow);
      row[_officialHeaders.indexOf('Received Date')] = '45524';
      final source = codec.sourceFromMatrix(
        fileName: 'numeric-date.csv',
        matrix: [_officialHeaders, row],
        worksheetName: 'Inventory Import',
        availableWorksheetNames: const ['Inventory Import', 'Instructions'],
      );
      final preview = codec.previewFromSource(
        mapping: codec.proposeMapping(source),
        categories: _categories,
        inventoryItems: const [],
        suppliers: _suppliers,
      );

      expect(preview.rows.single.receivedDate, '2024-08-20');
      expect(preview.rows.single.rawReceivedDate, '45524');
      expect(
        preview.rows.single.toR38_9RpcJson()['raw_source_values'],
        containsPair('worksheet_name', 'Inventory Import'),
      );
    });

    test('same item code remains valid across distinct serialized units', () {
      const codec = YorksV1InventoryWorkbookCodec();
      final first = List<String>.from(_validExternalRow);
      final second = List<String>.from(_validExternalRow);
      final serialIndex = _officialHeaders.indexOf('Serial No');
      final quantityIndex = _officialHeaders.indexOf('Quantity *');
      final totalIndex = _officialHeaders.indexOf('Total Price');
      first[serialIndex] = 'SERIAL-A';
      second[serialIndex] = 'SERIAL-B';
      first[quantityIndex] = second[quantityIndex] = '1';
      first[totalIndex] = second[totalIndex] = '45';
      final source = codec.sourceFromMatrix(
        fileName: 'serialized.csv',
        matrix: [_officialHeaders, first, second],
      );
      final preview = codec.previewFromSource(
        mapping: codec.proposeMapping(source),
        categories: _categories,
        inventoryItems: const [],
        suppliers: _suppliers,
      );

      expect(preview.rows, hasLength(2));
      expect(preview.rows.every((row) => !row.hasErrors), isTrue);
      expect(
        preview.rows.expand((row) => row.issues).map((issue) => issue.code),
        isNot(contains(YorksV1InventoryImportIssueCode.duplicateItemCode)),
      );
    });

    test('duplicate serial and exact receipt line are blocked in Review', () {
      const codec = YorksV1InventoryWorkbookCodec();
      final first = List<String>.from(_validExternalRow);
      final second = List<String>.from(_validExternalRow);
      final serialIndex = _officialHeaders.indexOf('Serial No');
      final quantityIndex = _officialHeaders.indexOf('Quantity *');
      final totalIndex = _officialHeaders.indexOf('Total Price');
      first[serialIndex] = second[serialIndex] = 'SERIAL-DUPLICATE';
      first[quantityIndex] = second[quantityIndex] = '1';
      first[totalIndex] = second[totalIndex] = '45';
      final source = codec.sourceFromMatrix(
        fileName: 'duplicate-serial.csv',
        matrix: [_officialHeaders, first, second],
      );
      final preview = codec.previewFromSource(
        mapping: codec.proposeMapping(source),
        categories: _categories,
        inventoryItems: const [],
        suppliers: _suppliers,
      );

      expect(preview.canCommit, isFalse);
      expect(
        preview.rows.expand((row) => row.issues).map((issue) => issue.code),
        containsAll(const [
          YorksV1InventoryImportIssueCode.duplicateSerialNumber,
          YorksV1InventoryImportIssueCode.duplicateReceiptLine,
        ]),
      );
    });

    test('serial absence placeholders are treated as bulk stock', () {
      const codec = YorksV1InventoryWorkbookCodec();
      final placeholders = ['N/A', 'NA', 'Not Applicable', 'Unknown', '-', ''];

      for (final placeholder in placeholders) {
        final row = List<String>.from(_validExternalRow);
        row[_officialHeaders.indexOf('Serial No')] = placeholder;
        row[_officialHeaders.indexOf('Quantity *')] = '12';
        row[_officialHeaders.indexOf('Total Price')] = '540';
        final source = codec.sourceFromMatrix(
          fileName: 'serial-placeholder.csv',
          matrix: [_officialHeaders, row],
        );
        final preview = codec.previewFromSource(
          mapping: codec.proposeMapping(source),
          categories: _categories,
          inventoryItems: const [],
          suppliers: _suppliers,
        );

        expect(preview.rows.single.serialNumber, isEmpty);
        expect(preview.rows.single.trackingMode, 'bulk');
        expect(
          preview.rows.single.issues.map((issue) => issue.code),
          isNot(
            contains(YorksV1InventoryImportIssueCode.duplicateSerialNumber),
          ),
        );
        expect(
          preview.rows.single.issues.map((issue) => issue.code),
          isNot(contains(YorksV1InventoryImportIssueCode.trackingModeInvalid)),
        );
        expect(
          preview.rows.single.rawSourceValues[_officialHeaders.indexOf(
            'Serial No',
          )],
          placeholder,
        );
      }
    });

    test('same catalogue item is allowed in separate receipt batches', () {
      const codec = YorksV1InventoryWorkbookCodec();
      final first = List<String>.from(_validExternalRow);
      final second = List<String>.from(_validExternalRow);
      second[_officialHeaders.indexOf('Supplier Reference / Delivery Note')] =
          'DN-002';
      final source = codec.sourceFromMatrix(
        fileName: 'two-batches.csv',
        matrix: [_officialHeaders, first, second],
      );
      final preview = codec.previewFromSource(
        mapping: codec.proposeMapping(source),
        categories: _categories,
        inventoryItems: const [],
        suppliers: _suppliers,
      );

      expect(preview.rows.every((row) => !row.hasErrors), isTrue);
    });

    test(
      'parses the 13-row QA workbook and preserves controlled evidence',
      () {
        const codec = YorksV1InventoryWorkbookCodec();
        final file = File(
          '$_packRoot/'
          'Yorks_Warehouse_Inventory_Supplier_QA_Test_Cases_R38_9.xlsx',
        );
        final preview = codec.decode(
          workbook: YorksV1InventorySelectedWorkbook(
            fileName: file.uri.pathSegments.last,
            bytes: file.readAsBytesSync(),
          ),
          categories: _categories,
          inventoryItems: const [],
          suppliers: _suppliers,
          requireR38_9Columns: true,
        );

        expect(preview.rowCount, 13);
        expect(preview.fileSha256, matches(RegExp(r'^[a-f0-9]{64}$')));
        expect(
          preview.rows[2].issues.map((issue) => issue.code),
          contains(YorksV1InventoryImportIssueCode.totalPriceMismatch),
        );
        expect(preview.rows[2].calculatedTotalPrice, '620');
        expect(
          preview.rows[3].issues.map((issue) => issue.code),
          contains(YorksV1InventoryImportIssueCode.supplierReferenceRequired),
        );
        expect(
          preview.rows[4].issues.map((issue) => issue.code),
          contains(YorksV1InventoryImportIssueCode.receivedDateRequired),
        );
        expect(preview.rows[5].requiresSupplierDecision, isTrue);
        expect(preview.rows[6].requiresSupplierDecision, isTrue);
        expect(preview.rows[9].usesUnknownSupplier, isTrue);
        expect(
          preview.rows[9].issues.map((issue) => issue.code),
          isNot(
            contains(YorksV1InventoryImportIssueCode.supplierReferenceRequired),
          ),
        );
        expect(
          preview.rows[10].issues.map((issue) => issue.code),
          contains(YorksV1InventoryImportIssueCode.supplierUnexpectedForSource),
        );
        expect(
          preview.rows[10].issues.map((issue) => issue.code),
          contains(YorksV1InventoryImportIssueCode.sourceTypeInvalid),
        );
        expect(preview.rows[12].description, '=This is plain text');
        expect(
          yorksV1InventorySafeSpreadsheetText(preview.rows[12].description),
          "'=This is plain text",
        );
        expect(preview.rows.first.rawSourceValues, hasLength(22));
        expect(preview.rows.first.rawSupplierName, 'TROX Middle East LLC');
        expect(preview.rows.first.rawSourceType, 'External Supplier');
        expect(preview.rows.first.rawSupplierReference, 'DN-TROX-QA-001');
        expect(preview.rows.first.rawReceivedDate, '2026-08-18');
      },
      skip:
          !File(
            '$_packRoot/'
            'Yorks_Warehouse_Inventory_Supplier_QA_Test_Cases_R38_9.xlsx',
          ).existsSync()
          ? 'R38.9 client review pack is not installed.'
          : false,
    );

    test(
      'missing supplier resolves to the stable Unknown Supplier warning',
      () {
        const codec = YorksV1InventoryWorkbookCodec();
        final row = List<String>.from(_validExternalRow)..[16] = '';
        final preview = codec.previewFromMatrix(
          fileName: 'unknown-supplier.csv',
          matrix: [_officialHeaders, row],
          categories: _categories,
          inventoryItems: const [],
          suppliers: _suppliers,
          requireR38_9Columns: true,
        );

        expect(preview.canCommit, isTrue);
        expect(preview.rows.single.supplierId, yorksV1UnknownSupplierId);
        expect(preview.rows.single.usesUnknownSupplier, isTrue);
        expect(
          preview.rows.single.issues.map((issue) => issue.code),
          contains(YorksV1InventoryImportIssueCode.supplierMissingUsesUnknown),
        );
      },
    );

    test(
      'opening balance uses import as-of date instead of row receipt fields',
      () {
        const codec = YorksV1InventoryWorkbookCodec();
        final row = List<String>.from(_validExternalRow)
          ..[9] = 'Opening Balance'
          ..[10] = 'Opening Balance'
          ..[16] = ''
          ..[17] = ''
          ..[18] = '';
        final preview = codec.previewFromMatrix(
          fileName: 'opening.csv',
          matrix: [_officialHeaders, row],
          categories: _categories,
          inventoryItems: const [],
          suppliers: _suppliers,
          requireR38_9Columns: true,
        );

        expect(preview.canCommit, isTrue);
        expect(preview.requiresOpeningBalanceAsOfDate, isTrue);
        expect(
          preview.noticeCodes,
          contains(
            YorksV1InventoryImportNoticeCode.openingBalanceAsOfDateRequired,
          ),
        );
        expect(preview.rows.single.usesUnknownSupplier, isTrue);
        expect(
          preview.rows.single.issues.map((issue) => issue.code),
          isNot(
            contains(YorksV1InventoryImportIssueCode.supplierReferenceRequired),
          ),
        );
        expect(
          preview.rows.single.issues.map((issue) => issue.code),
          isNot(contains(YorksV1InventoryImportIssueCode.receivedDateRequired)),
        );
        expect(() => preview.toR38_9RpcPayload(), throwsStateError);
        expect(
          () => preview.toR38_9RpcPayload(openingBalanceAsOfDate: '2026-02-30'),
          throwsStateError,
        );
        expect(
          preview.toR38_9RpcPayload(
            openingBalanceAsOfDate: '2026-08-19',
          )['opening_balance_as_of_date'],
          '2026-08-19',
        );
      },
    );

    test('supplier missing-identity sentinels always resolve Unknown', () {
      const codec = YorksV1InventoryWorkbookCodec();
      for (final sentinel in const [
        '',
        'Unknown',
        'Unknown Supplier',
        'N/A',
        'NA',
      ]) {
        final row = List<String>.from(_validExternalRow)..[16] = sentinel;
        final preview = codec.previewFromMatrix(
          fileName: 'unknown-sentinel.csv',
          matrix: [_officialHeaders, row],
          categories: _categories,
          inventoryItems: const [],
          suppliers: _suppliers,
          requireR38_9Columns: true,
        );
        expect(preview.rows.single.supplierId, yorksV1UnknownSupplierId);
        expect(preview.rows.single.usesUnknownSupplier, isTrue);
        expect(preview.rows.single.requiresSupplierDecision, isFalse);
      }
    });

    test(
      'one explicit supplier decision resolves equivalent repeated text',
      () {
        const codec = YorksV1InventoryWorkbookCodec();
        final first = List<String>.from(_validExternalRow)
          ..[1] = 'GEN-001'
          ..[16] = 'New Gulf HVAC Trading LLC';
        final second = List<String>.from(_validExternalRow)
          ..[1] = 'GEN-002'
          ..[16] = ' new gulf hvac trading, llc ';
        final preview = codec.previewFromMatrix(
          fileName: 'new-supplier.csv',
          matrix: [_officialHeaders, first, second],
          categories: _categories,
          inventoryItems: const [],
          suppliers: _suppliers,
          requireR38_9Columns: true,
        );

        expect(
          preview.rows.map((row) => row.requiresSupplierDecision),
          everyElement(isTrue),
        );
        final resolved = codec.applySupplierDecision(
          preview: preview,
          sourceSupplierText: 'New Gulf HVAC Trading LLC',
          createNew: true,
        );
        expect(resolved.canCommit, isTrue);
        expect(
          resolved.rows.map((row) => row.supplierResolution),
          everyElement(YorksV1InventorySupplierResolution.createNew),
        );
        expect(
          resolved.rows.map((row) => row.newSupplierName),
          everyElement('New Gulf HVAC Trading LLC'),
        );
      },
    );

    test('fuzzy supplier remains a suggestion until explicitly selected', () {
      const codec = YorksV1InventoryWorkbookCodec();
      final row = List<String>.from(_validExternalRow)
        ..[16] = 'Trox UAE Trading';
      final preview = codec.previewFromMatrix(
        fileName: 'fuzzy.csv',
        matrix: [_officialHeaders, row],
        categories: _categories,
        inventoryItems: const [],
        suppliers: _suppliers,
        requireR38_9Columns: true,
      );

      expect(preview.canCommit, isFalse);
      expect(preview.rows.single.supplierId, isNull);
      expect(preview.rows.single.supplierSuggestions, isNotEmpty);
      expect(
        preview.rows.single.supplierSuggestions.first.supplier.name,
        'TROX Middle East LLC',
      );
    });

    test('Unicode supplier identity is preserved and grouped safely', () {
      const matcher = YorksV1InventorySupplierMatcher();
      final supplier = YorksV1InventorySupplierMaster(
        id: 'supplier-arabic',
        name: 'شركة الخليج للتكييف',
      );
      expect(
        matcher.exactMatches('شركة الخليج للتكييف', [supplier]).single.id,
        'supplier-arabic',
      );
      expect(
        yorksV1InventorySearchKey(' شركة-الخليج للتكييف '),
        yorksV1InventorySearchKey('شركة الخليج للتكييف'),
      );
    });

    test(
      'condition quantities reconcile delivered and shape the RPC payload',
      () {
        const codec = YorksV1InventoryWorkbookCodec();
        final preview = codec.previewFromMatrix(
          fileName: 'conditions.csv',
          matrix: [_officialHeaders, _validExternalRow],
          categories: _categories,
          inventoryItems: const [],
          suppliers: _suppliers,
          requireR38_9Columns: true,
        );
        final reviewed = codec.applyReceiptQuantities(
          preview: preview,
          sourceRowNumber: 2,
          accepted: '8',
          damaged: '1',
          rejected: '1',
        );

        expect(reviewed.canCommit, isTrue);
        final rowPayload = reviewed.rows.single.toR38_9RpcJson();
        expect(
          rowPayload.keys,
          unorderedEquals(const [
            'source_row_number',
            'inventory_item_id',
            'item_code',
            'item_description',
            'category_id',
            'new_category_name',
            'source_category_text',
            'brand_origin',
            'unit',
            'stock_action',
            'quantity',
            'reason',
            'minimum_stock',
            'location_bin',
            'notes',
            'source_type',
            'source_type_text',
            'size_text',
            'model_tag',
            'serial_number',
            'ral_colour',
            'supplier_id',
            'new_supplier_name',
            'external_supplier_name',
            'supplier_name_snapshot',
            'source_supplier_text',
            'supplier_reference',
            'received_date',
            'supplier_resolution',
            'delivered_quantity',
            'accepted_quantity',
            'damaged_quantity',
            'rejected_quantity',
            'tracking_mode',
            'batch_lot_number',
            'unit_price',
            'total_price',
            'currency_code',
            'calculated_total_price',
            'imported_total_price',
            'raw_source_values',
          ]),
        );
        expect(rowPayload['quantity'], '8');
        expect(rowPayload['accepted_quantity'], '8');
        expect(rowPayload['damaged_quantity'], '1');
        expect(rowPayload['rejected_quantity'], '1');
        expect(rowPayload['delivered_quantity'], '10');
        expect(rowPayload['total_price'], '450');
        expect(rowPayload['raw_source_values'], isA<Map<String, Object?>>());

        final invalid = codec.applyReceiptQuantities(
          preview: preview,
          sourceRowNumber: 2,
          accepted: '8',
          damaged: '2',
          rejected: '1',
        );
        expect(invalid.canCommit, isFalse);
        expect(
          invalid.rows.single.issues.map((issue) => issue.code),
          contains(YorksV1InventoryImportIssueCode.receiptQuantityMismatch),
        );
      },
    );
  });

  test(
    'the complete 1,240-row opening balance parses within the row limit',
    () {
      const codec = YorksV1InventoryWorkbookCodec();
      final file = File(
        '$_packRoot/'
        'Yorks_Warehouse_Inventory_Master_Opening_Balance_R38_9.xlsx',
      );
      final source = codec.read(
        YorksV1InventorySelectedWorkbook(
          fileName: file.uri.pathSegments.last,
          bytes: file.readAsBytesSync(),
        ),
      );
      final mapping = codec.proposeMapping(source);

      expect(source.rowCount, 1240);
      expect(mapping.canContinue, isTrue);
      expect(source.fileSha256, matches(RegExp(r'^[a-f0-9]{64}$')));
      final preview = codec.previewFromSource(
        mapping: mapping,
        categories: _approvedWorkbookCategories,
        inventoryItems: const [],
        suppliers: _suppliers,
      );
      final unresolvedCategories = preview.rows
          .where((row) => row.requiresCategoryDecision)
          .map((row) => row.sourceCategory)
          .toSet();
      expect(
        unresolvedCategories,
        isEmpty,
        reason:
            'Every pack category must already resolve: $unresolvedCategories',
      );
      expect(preview.unresolvedUnitGroups, isEmpty);
    },
    skip:
        !File(
          '$_packRoot/Yorks_Warehouse_Inventory_Master_Opening_Balance_R38_9.xlsx',
        ).existsSync()
        ? 'R38.9 client review pack is not installed.'
        : false,
  );

  test(
    'the attached legacy workbook can explicitly be treated as Opening Balance',
    () {
      const codec = YorksV1InventoryWorkbookCodec();
      final file = File(_perfectWorkbookPath);
      final source = codec.read(
        YorksV1InventorySelectedWorkbook(
          fileName: file.uri.pathSegments.last,
          bytes: file.readAsBytesSync(),
        ),
      );
      var mapping = codec.proposeMapping(source, requireR38_9Fields: true);

      expect(mapping.canContinue, isTrue);
      mapping = codec.applyOpeningBalanceDefault(
        mapping: mapping,
        enabled: true,
      );
      expect(mapping.canContinue, isTrue);

      var preview = codec.previewFromSource(
        mapping: mapping,
        categories: _approvedWorkbookCategories,
        inventoryItems: const [],
        suppliers: _suppliers,
      );
      expect(preview.rowCount, greaterThan(1000));
      expect(preview.treatsWorkbookAsOpeningBalance, isTrue);
      expect(preview.requiresOpeningBalanceAsOfDate, isTrue);
      expect(preview.rows.map((row) => row.sourceType).toSet(), {
        YorksV1InventorySourceType.openingBalance,
      });
      expect(preview.rows.map((row) => row.stockAction).toSet(), {
        YorksV1InventoryStockAction.openingBalance,
      });
      final unresolvedCategories = preview.rows
          .where((row) => row.requiresCategoryDecision)
          .map((row) => row.sourceCategory)
          .toSet();
      expect(
        unresolvedCategories,
        isEmpty,
        reason:
            'Every supplied workbook category must resolve: '
            '$unresolvedCategories',
      );
      expect(preview.unresolvedUnitGroups, isEmpty);
      final mapped = preview.rows.firstWhere(
        (row) => yorksV1InventorySearchKey(row.rawUnit) == 'pack',
      );
      expect(mapped.unit, 'Pack');
      expect(mapped.unitWasMapped, isFalse);
      expect(mapped.rawSourceHeaders, hasLength(20));
      expect(mapping.controlledUnitFor('Pack'), isNull);
    },
    skip: !File(_perfectWorkbookPath).existsSync()
        ? 'The attached PERFECT workbook is not installed.'
        : false,
  );

  test('R38.9 payload fails closed when strict mode is disabled', () {
    const codec = YorksV1InventoryWorkbookCodec();
    final valid = codec.previewFromMatrix(
      fileName: 'strict.csv',
      matrix: [_officialHeaders, _validExternalRow],
      categories: _categories,
      inventoryItems: const [],
      suppliers: _suppliers,
      requireR38_9Columns: true,
    );
    final nonStrict = YorksV1InventoryImportPreview(
      fileName: valid.fileName,
      fileSha256: valid.fileSha256,
      mapping: valid.mapping,
      strictImport: false,
      rows: valid.rows,
    );

    expect(() => nonStrict.toR38_9RpcPayload(), throwsStateError);
  });

  test('supplier register pins Unknown and keeps totals separated by unit', () {
    final generatedAt = DateTime.utc(2026, 8, 20, 9, 30);
    final bytes =
        YorksV1PlatformInventoryWorkbookFileService.buildSupplierRegisterWorkbook(
          suppliers: [
            YorksV1InventorySupplierDirectoryEntry(
              id: 'trox-id',
              code: 'SUP-0001',
              name: 'TROX Middle East LLC',
              description: 'Air-side equipment',
              status: YorksV1InventorySupplierStatus.active,
              isSystemUnknown: false,
              receiptBatchCount: 4,
              distinctItemCount: 7,
              missingDocumentCount: 1,
              reconciliationCount: 0,
              lastReceiptAt: generatedAt,
              aliases: const ['TROX Middle East'],
              recordVersion: 2,
            ),
            YorksV1InventorySupplierDirectoryEntry(
              id: yorksV1UnknownSupplierId,
              code: 'SUP-UNKNOWN',
              name: yorksV1UnknownSupplierName,
              description: 'Missing supplier identity',
              status: YorksV1InventorySupplierStatus.identityMissing,
              isSystemUnknown: true,
              receiptBatchCount: 2,
              distinctItemCount: 3,
              missingDocumentCount: 2,
              reconciliationCount: 2,
              lastReceiptAt: null,
              aliases: const ['Unknown', 'N/A'],
              recordVersion: 1,
            ),
          ],
          unitTotals: const [
            YorksV1InventorySupplierUnitTotal(
              unit: 'Nos',
              acceptedQuantity: '1.25',
              damagedQuantity: '0',
              rejectedQuantity: '0.5',
            ),
            YorksV1InventorySupplierUnitTotal(
              unit: 'Nos',
              acceptedQuantity: '2.75',
              damagedQuantity: '1',
              rejectedQuantity: '0.5',
            ),
            YorksV1InventorySupplierUnitTotal(
              unit: 'Meter',
              acceptedQuantity: '12',
              damagedQuantity: '0',
              rejectedQuantity: '0',
            ),
          ],
          generatedAt: generatedAt,
        );
    final workbook = const YorksV1BoqWorkbookCodec().decode(
      bytes: bytes,
      fileName: 'supplier-register.xlsx',
    );
    final archive = ZipDecoder().decodeBytes(bytes);

    expect(workbook.sheets.map((sheet) => sheet.name), [
      'Supplier Register',
      'Unit Totals',
    ]);
    expect(
      workbook.sheets.first.rows[2],
      containsAll(const [
        'Supplier Code',
        'Supplier Name',
        'Aliases',
        'Receipt Batches',
        'Missing Documents',
      ]),
    );
    expect(workbook.sheets.first.rows[3][1], yorksV1UnknownSupplierName);
    expect(workbook.sheets.first.rows[3][10], 'Yes — pinned system folder');
    final nosRow = workbook.sheets[1].rows.firstWhere(
      (row) => row.isNotEmpty && row.first == 'Nos',
    );
    expect(nosRow, ['Nos', '4', '1', '1']);
    final meterRow = workbook.sheets[1].rows.firstWhere(
      (row) => row.isNotEmpty && row.first == 'Meter',
    );
    expect(meterRow, ['Meter', '12', '0', '0']);
    final directoryXml = utf8.decode(
      archive.findFile('xl/worksheets/sheet1.xml')!.readBytes()!,
    );
    expect(directoryXml, contains('state="frozen"'));
    expect(directoryXml, contains('<autoFilter ref="A3:K5"/>'));
    expect(directoryXml, contains('<c r="A4" s="6"'));
  });

  test(
    'review edits revalidate, preserve raw evidence, and reject quantity edits',
    () {
      const codec = YorksV1InventoryWorkbookCodec();
      final source = codec.sourceFromMatrix(
        fileName: 'review.csv',
        matrix: [_officialHeaders, _validExternalRow],
      );
      final mapping = codec.proposeMapping(source);
      final edited = codec.applyCellEdit(
        mapping: mapping,
        sourceRowNumber: 2,
        field: YorksV1InventoryControlledField.description,
        value: '',
      );
      final preview = codec.previewFromSource(
        mapping: edited,
        categories: _categories,
        inventoryItems: const [],
        suppliers: _suppliers,
      );

      expect(preview.rows.single.hasErrors, isTrue);
      expect(
        preview.rows.single.issues.map((issue) => issue.code),
        containsAll(const [
          YorksV1InventoryImportIssueCode.descriptionRequired,
          YorksV1InventoryImportIssueCode.reviewEditApplied,
        ]),
      );
      expect(preview.rows.single.rawSourceValues[3], _validExternalRow[3]);
      final validEdit = codec.applyCellEdit(
        mapping: mapping,
        sourceRowNumber: 2,
        field: YorksV1InventoryControlledField.description,
        value: 'Reviewed Linear Supply Grille',
      );
      final reviewed = codec.previewFromSource(
        mapping: validEdit,
        categories: _categories,
        inventoryItems: const [],
        suppliers: _suppliers,
      );
      final evidence = reviewed.rows.single.toR38_9RpcJson();
      final raw = evidence['raw_source_values']! as Map<String, Object?>;
      final decisions = raw['decisions']! as Map<String, Object?>;
      expect(decisions['safe_cell_edits'], isNotNull);
      expect(
        () => codec.applyCellEdit(
          mapping: mapping,
          sourceRowNumber: 2,
          field: YorksV1InventoryControlledField.quantity,
          value: '99',
        ),
        throwsA(isA<YorksV1DomainException>()),
      );
    },
  );

  test('exact Search & Replace is grouped and Safe Fixes are idempotent', () {
    const codec = YorksV1InventoryWorkbookCodec();
    final second = [..._validExternalRow]
      ..[0] = '2'
      ..[1] = 'AIR-LIGR-002'
      ..[3] = '  Linear   Grille  ';
    final first = [..._validExternalRow]
      ..[3] = '  Linear   Grille  '
      ..[17] = 'DN-002';
    final source = codec.sourceFromMatrix(
      fileName: 'bulk-review.csv',
      matrix: [_officialHeaders, first, second],
    );
    var mapping = codec.proposeMapping(source);
    final fixes = codec.applySafeFixes(mapping);
    expect(fixes.affectedRows, 2);
    mapping = fixes.mapping;
    expect(codec.applySafeFixes(mapping).affectedRows, 0);

    final replacement = codec.applyExactSearchAndReplace(
      mapping: mapping,
      field: YorksV1InventoryControlledField.description,
      sourceText: 'Linear Grille',
      replacementText: 'Linear Supply Grille',
    );
    expect(replacement.affectedRows, 2);
    final preview = codec.previewFromSource(
      mapping: replacement.mapping,
      categories: _categories,
      inventoryItems: const [],
      suppliers: _suppliers,
    );
    expect(
      preview.rows.map((row) => row.description),
      everyElement('Linear Supply Grille'),
    );
    expect(preview.rows.every((row) => row.quantity == '10'), isTrue);
    expect(preview.rows.every((row) => row.unitPrice == '45'), isTrue);
  });

  test('Issues, Cleaned Preview, and strict Result workbooks retain evidence', () {
    const codec = YorksV1InventoryWorkbookCodec();
    final row = [..._validExternalRow]
      ..[3] = '=FORMULA-LIKE DESCRIPTION'
      ..[9] = 'Correction'
      ..[10] = 'Correction (-)'
      ..[13] = ''
      ..[19] = '';
    final preview = codec.previewFromMatrix(
      fileName: '../unsafe receipt.xlsx',
      matrix: [_officialHeaders, row],
      categories: _categories,
      inventoryItems: const [],
      suppliers: _suppliers,
      requireR38_9Columns: true,
    );

    final issues = const YorksV1BoqWorkbookCodec().decode(
      bytes:
          YorksV1PlatformInventoryWorkbookFileService.buildImportIssuesWorkbook(
            preview: preview,
          ),
      fileName: 'issues.xlsx',
    );
    expect(issues.sheets.single.name, 'Issues');
    expect(
      issues.sheets.single.rows.expand((row) => row),
      contains(YorksV1InventoryImportIssueCode.reasonRequired.name),
    );

    final cleaned = const YorksV1BoqWorkbookCodec().decode(
      bytes:
          YorksV1PlatformInventoryWorkbookFileService.buildCleanedImportPreviewWorkbook(
            preview: preview,
          ),
      fileName: 'cleaned.xlsx',
    );
    expect(cleaned.sheets.single.name, 'Cleaned Preview');
    final cleanedData = cleaned.sheets.single.rows.firstWhere(
      (values) => values.contains("'=FORMULA-LIKE DESCRIPTION"),
    );
    expect(cleanedData, contains('Error'));
    expect(
      YorksV1PlatformInventoryWorkbookFileService.cleanedImportPreviewSuggestedName(
        '../unsafe receipt.xlsx',
      ),
      'unsafe_receipt_Cleaned_Preview.xlsx',
    );

    final ready = codec.previewFromMatrix(
      fileName: 'receipt.xlsx',
      matrix: [_officialHeaders, _validExternalRow],
      categories: _categories,
      inventoryItems: const [],
      suppliers: _suppliers,
      requireR38_9Columns: true,
    );
    const result = YorksV1InventoryImportResult(
      importBatchId: 'batch/one',
      rowCount: 1,
      createdItems: 1,
      updatedItems: 0,
      createdCategories: 0,
      createdSuppliers: 0,
      receiptBatches: 1,
      movements: 1,
      warningCount: 0,
      excludedCount: 0,
      unknownSupplierRows: 0,
      unitTotals: [
        YorksV1InventoryImportUnitTotal(
          unit: 'Nos',
          acceptedQuantity: '10',
          damagedQuantity: '0',
          rejectedQuantity: '0',
        ),
      ],
    );
    final resultWorkbook = const YorksV1BoqWorkbookCodec().decode(
      bytes:
          YorksV1PlatformInventoryWorkbookFileService.buildImportResultWorkbook(
            preview: ready,
            result: result,
          ),
      fileName: 'result.xlsx',
    );
    expect(resultWorkbook.sheets.map((sheet) => sheet.name), [
      'Import Summary',
      'Committed Rows',
      'Unit Totals',
    ]);
    expect(
      resultWorkbook.sheets[1].rows.expand((row) => row),
      contains('Committed'),
    );
    expect(
      resultWorkbook.sheets[2].rows.expand((row) => row),
      containsAll(const ['Nos', '10']),
    );
    expect(
      () =>
          YorksV1PlatformInventoryWorkbookFileService.buildImportResultWorkbook(
            preview: ready,
            result: const YorksV1InventoryImportResult(
              importBatchId: 'partial',
              rowCount: 1,
              createdItems: 1,
              updatedItems: 0,
              createdCategories: 0,
              excludedCount: 1,
            ),
          ),
      throwsA(isA<YorksV1DomainException>()),
    );
  });

  test(
    'controller requires reviewed legacy Opening Balance, unit, and as-of date',
    () async {
      final payloads = <Map<String, Object?>>[];
      final controller = YorksV1InventoryImportController(
        repository: _ImportRepository(),
        fileService: const _UnusedFileService(),
        uuidFactory: () => '93000000-0000-4000-8000-000000000002',
        r38_9Commit: ({required payload, required idempotencyKey}) async {
          payloads.add(payload);
          return const YorksV1InventoryImportResult(
            importBatchId: 'opening-batch',
            rowCount: 1,
            createdItems: 1,
            updatedItems: 0,
            createdCategories: 0,
          );
        },
      );
      const omittedColumns = {9, 16, 17, 18};
      final legacyHeaders = [
        for (var index = 0; index < _officialHeaders.length; index++)
          if (!omittedColumns.contains(index)) _officialHeaders[index],
      ];
      final legacyRow = [
        for (var index = 0; index < _validExternalRow.length; index++)
          if (!omittedColumns.contains(index))
            index == 12 ? 'Pack' : _validExternalRow[index],
      ];
      controller.prepareSelected(
        YorksV1InventorySelectedWorkbook(
          fileName: 'legacy-opening.csv',
          bytes: Uint8List.fromList(
            utf8.encode('${legacyHeaders.join(',')}\r\n${legacyRow.join(',')}'),
          ),
        ),
        YorksV1InventoryWorkspace(items: const [], categories: _categories),
      );

      expect(controller.state.mapping?.canContinue, isTrue);
      expect(controller.state.preview, isNotNull);
      expect(controller.state.canTreatWorkbookAsOpeningBalance, isTrue);

      controller.setTreatWorkbookAsOpeningBalance(true);
      expect(controller.state.mapping?.canContinue, isTrue);
      expect(controller.state.treatsWorkbookAsOpeningBalance, isTrue);
      expect(controller.confirmMapping(), isTrue);
      expect(controller.state.unresolvedUnitGroups, isEmpty);
      expect(controller.state.requiresOpeningBalanceAsOfDate, isTrue);
      expect(controller.state.hasValidOpeningBalanceAsOfDate, isFalse);
      expect(controller.continueToSupplierReceipt(), isFalse);

      controller.setOpeningBalanceAsOfDate('2026-02-30');
      expect(controller.state.hasValidOpeningBalanceAsOfDate, isFalse);
      expect(controller.continueToSupplierReceipt(), isFalse);
      controller.setOpeningBalanceAsOfDate('2026-08-19');
      expect(controller.state.hasValidOpeningBalanceAsOfDate, isTrue);
      expect(controller.continueToSupplierReceipt(), isTrue);
      controller.confirmSupplierAndReceipt();
      expect(controller.state.canCommit, isTrue);

      await controller.commit();
      expect(payloads, hasLength(1));
      expect(payloads.single['opening_balance_as_of_date'], '2026-08-19');
      final rowPayload = (payloads.single['rows']! as List).single as Map;
      expect(rowPayload['source_type'], 'opening_balance');
      expect(rowPayload['stock_action'], 'opening_balance');
      expect(rowPayload['unit'], 'Pack');
      final evidence = rowPayload['raw_source_values']! as Map;
      expect((evidence['headers']! as List), hasLength(18));
      expect(evidence['decisions'], {
        'source_type_default': 'opening_balance',
        'stock_action_normalized_from': 'add_stock',
      });
    },
  );

  test(
    'controller review edits, bulk replacement, and Safe Fix undo revalidate',
    () {
      final row = [..._validExternalRow]..[19] = '  Checked   by procurement  ';
      final controller = YorksV1InventoryImportController(
        repository: _ImportRepository(),
        fileService: const _UnusedFileService(),
        r38_9Commit: ({required payload, required idempotencyKey}) async =>
            const YorksV1InventoryImportResult(
              importBatchId: 'unused',
              rowCount: 1,
              createdItems: 1,
              updatedItems: 0,
              createdCategories: 0,
            ),
      );
      controller.prepareSelected(
        YorksV1InventorySelectedWorkbook(
          fileName: 'review.csv',
          bytes: Uint8List.fromList(
            utf8.encode('${_officialHeaders.join(',')}\r\n${row.join(',')}'),
          ),
        ),
        YorksV1InventoryWorkspace(items: const [], categories: _categories),
        suppliers: _suppliers,
      );
      expect(
        controller.editReviewCell(
          sourceRowNumber: 2,
          field: YorksV1InventoryControlledField.description,
          value: 'Reviewed Grille',
        ),
        isFalse,
      );
      expect(controller.confirmMapping(), isTrue);
      expect(
        controller.editReviewCell(
          sourceRowNumber: 2,
          field: YorksV1InventoryControlledField.description,
          value: 'Reviewed Grille',
        ),
        isTrue,
      );
      expect(
        controller.state.preview!.rows.single.description,
        'Reviewed Grille',
      );
      expect(
        controller.searchAndReplaceReviewCells(
          field: YorksV1InventoryControlledField.description,
          sourceText: 'Reviewed Grille',
          replacementText: 'Reviewed Supply Grille',
        ),
        1,
      );
      expect(
        controller.state.preview!.rows.single.description,
        'Reviewed Supply Grille',
      );
      expect(controller.applySafeFixes(), 1);
      expect(controller.canUndoSafeFixes, isTrue);
      expect(
        controller.state.preview!.rows.single.notes,
        'Checked by procurement',
      );
      expect(controller.undoSafeFixes(), isTrue);
      expect(controller.canUndoSafeFixes, isFalse);
      expect(
        controller.state.preview!.rows.single.description,
        'Reviewed Supply Grille',
      );
    },
  );

  test(
    'unit review retains prior category, supplier, and condition decisions',
    () {
      final row = List<String>.from(_validExternalRow)
        ..[2] = 'new custom category'
        ..[12] = 'Pack'
        ..[16] = 'Trox UAE Trading';
      final controller = YorksV1InventoryImportController(
        repository: _ImportRepository(),
        fileService: const _UnusedFileService(),
        r38_9Commit: ({required payload, required idempotencyKey}) async =>
            const YorksV1InventoryImportResult(
              importBatchId: 'unused',
              rowCount: 1,
              createdItems: 1,
              updatedItems: 0,
              createdCategories: 1,
            ),
      );
      controller.prepareSelected(
        YorksV1InventorySelectedWorkbook(
          fileName: 'decisions.csv',
          bytes: Uint8List.fromList(
            utf8.encode('${_officialHeaders.join(',')}\r\n${row.join(',')}'),
          ),
        ),
        YorksV1InventoryWorkspace(items: const [], categories: _categories),
        suppliers: _suppliers,
      );
      expect(controller.confirmMapping(), isTrue);
      controller.createNewCategory('new custom category');
      controller.resolveSupplier(
        sourceSupplierText: 'Trox UAE Trading',
        supplierId: 'supplier-trox',
        canonicalSupplierName: 'TROX Middle East LLC',
      );
      controller.setReceiptQuantities(
        sourceRowNumber: 2,
        accepted: '8',
        damaged: '1',
        rejected: '1',
      );
      controller.resolveUnit(sourceUnitText: 'Pack', controlledUnit: 'Box');

      final reviewed = controller.state.preview!.rows.single;
      expect(reviewed.newCategoryName, 'New Custom Category');
      expect(reviewed.supplierId, 'supplier-trox');
      expect(reviewed.canonicalSupplierName, 'TROX Middle East LLC');
      expect(reviewed.acceptedQuantity, '8');
      expect(reviewed.damagedQuantity, '1');
      expect(reviewed.rejectedQuantity, '1');
      expect(reviewed.unit, 'Box');
      expect(controller.state.preview!.canCommit, isTrue);
    },
  );

  test('controller cannot mutate before stage four confirmation', () async {
    final repository = _ImportRepository();
    final payloads = <Map<String, Object?>>[];
    final controller = YorksV1InventoryImportController(
      repository: repository,
      fileService: const _UnusedFileService(),
      uuidFactory: () => '93000000-0000-4000-8000-000000000001',
      r38_9Commit: ({required payload, required idempotencyKey}) async {
        payloads.add(payload);
        expect(idempotencyKey, '93000000-0000-4000-8000-000000000001');
        return const YorksV1InventoryImportResult(
          importBatchId: 'batch-r38-9',
          rowCount: 1,
          createdItems: 1,
          updatedItems: 0,
          createdCategories: 0,
        );
      },
    );
    controller.prepareSelected(
      YorksV1InventorySelectedWorkbook(
        fileName: 'receipt.csv',
        bytes: Uint8List.fromList(
          utf8.encode(
            '${_officialHeaders.join(',')}\r\n'
            '${_validExternalRow.join(',')}',
          ),
        ),
      ),
      YorksV1InventoryWorkspace(items: const [], categories: _categories),
      suppliers: _suppliers,
    );

    expect(controller.state.stage, YorksV1InventoryImportStage.mapColumns);
    expect(await controller.commit(), isNull);
    expect(payloads, isEmpty);
    expect(repository.inputs, isEmpty);

    expect(controller.confirmMapping(), isTrue);
    expect(controller.state.stage, YorksV1InventoryImportStage.reviewValidate);
    expect(await controller.commit(), isNull);
    expect(payloads, isEmpty);

    expect(controller.continueToSupplierReceipt(), isTrue);
    expect(controller.state.stage, YorksV1InventoryImportStage.supplierReceipt);
    expect(await controller.commit(), isNull);
    expect(payloads, isEmpty);

    controller.confirmSupplierAndReceipt();
    expect(controller.state.canCommit, isTrue);
    final result = await controller.commit();
    expect(result?.importBatchId, 'batch-r38-9');
    expect(payloads, hasLength(1));
    expect(
      payloads.single.keys,
      unorderedEquals(const [
        'file_name',
        'file_sha256',
        'import_mode',
        'opening_balance_as_of_date',
        'rows',
      ]),
    );
    expect(payloads.single['import_mode'], 'strict');
    expect(payloads.single['file_sha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(controller.state.stage, YorksV1InventoryImportStage.importSummary);
    expect(repository.inputs, isEmpty);
  });

  test('controller prepares a workbook off the native UI isolate', () async {
    final controller = YorksV1InventoryImportController(
      repository: _ImportRepository(),
      fileService: const _UnusedFileService(),
      r38_9Commit: ({required payload, required idempotencyKey}) async =>
          throw UnimplementedError(),
    );

    final prepared = await controller.prepareSelectedAsync(
      YorksV1InventorySelectedWorkbook(
        fileName: 'offloaded.csv',
        bytes: Uint8List.fromList(
          utf8.encode(
            '${_officialHeaders.join(',')}\r\n'
            '${_validExternalRow.join(',')}',
          ),
        ),
      ),
      YorksV1InventoryWorkspace(items: const [], categories: _categories),
      suppliers: _suppliers,
    );

    expect(prepared, isTrue);
    expect(controller.state.stage, YorksV1InventoryImportStage.mapColumns);
    expect(controller.state.preview?.rows, hasLength(1));
  });

  test(
    'controller exposes ambiguous worksheet names for explicit choice',
    () async {
      final controller = YorksV1InventoryImportController(
        repository: _ImportRepository(),
        fileService: const _UnusedFileService(),
      );
      final workbook = YorksV1InventorySelectedWorkbook(
        fileName: 'multiple.xlsx',
        bytes: const YorksV1BoqWorkbookCodec().encodeWorksheets([
          _inventoryWorksheet(name: 'Warehouse A', rowCount: 1),
          _inventoryWorksheet(name: 'Warehouse B', rowCount: 1),
        ]),
      );

      expect(await controller.availableWorksheetNames(workbook), [
        'Warehouse A',
        'Warehouse B',
      ]);
      expect(
        await controller.prepareSelectedAsync(
          workbook.selectWorksheet('Warehouse B'),
          YorksV1InventoryWorkspace(items: const [], categories: _categories),
        ),
        isTrue,
      );
      expect(controller.state.source?.worksheetName, 'Warehouse B');
    },
  );
}

Uint8List _markWorksheetHidden(Uint8List bytes, String worksheetName) {
  final source = ZipDecoder().decodeBytes(bytes, verify: true);
  final updated = Archive();
  for (final file in source) {
    if (file.name == 'xl/workbook.xml') {
      final xml = utf8
          .decode(file.content)
          .replaceFirst(
            'name="$worksheetName"',
            'name="$worksheetName" state="hidden"',
          );
      updated.addFile(ArchiveFile.string(file.name, xml));
    } else {
      updated.addFile(ArchiveFile.bytes(file.name, file.content));
    }
  }
  return Uint8List.fromList(ZipEncoder().encode(updated));
}

const _officialHeaders = <String>[
  'S:No',
  'Item Code *',
  'Category *',
  'Item Description *',
  'Size (If Any)',
  'Model / Tag',
  'Serial No',
  'Brand / Origin',
  'RAL Colour',
  'Source Type *',
  'Stock Action *',
  'Quantity *',
  'Unit *',
  'Reason *',
  'Minimum Stock',
  'Location / Shelf',
  'External Supplier Name',
  'Supplier Reference / Delivery Note',
  'Received Date',
  'Notes',
  'Unit Price',
  'Total Price',
];

const _validExternalRow = <String>[
  '1',
  'AIR-LIGR-001',
  'Air Terminals',
  'Linear Supply Air Grille',
  '600 x 600 mm',
  '',
  '',
  'TROX / UAE',
  'RAL 9010',
  'External Supplier',
  'Add Stock',
  '10',
  'Nos',
  'Supplier receipt',
  '2',
  'Main Warehouse / A-01',
  'TROX Middle East LLC',
  'DN-001',
  '2026-08-20',
  'Checked',
  '45',
  '450',
];

final _categories = [
  for (final entry in const {
    'air': 'Air Terminals',
    'pipe': 'Piping & Drain',
    'electrical': 'Electrical & Controls',
    'ac': 'AC Unit Parts',
    'general': 'General Items',
  }.entries)
    YorksV1InventoryCategory(
      id: entry.key,
      name: entry.value,
      isSystem: true,
      isActive: true,
      recordVersion: 1,
      itemCount: 0,
      aliases: const [],
      createdByDisplayName: 'Yorks standard',
      createdAt: DateTime.utc(2026, 8, 20),
    ),
];

final _approvedWorkbookCategories = [
  _workbookCategory('air', 'Air Terminals', ['Air Inlet & Outlet']),
  _workbookCategory('round', 'Round', ['Air Terminals - Round']),
  _workbookCategory('red', 'RED', ['Air Terminals - Red']),
  _workbookCategory('ac-units', 'AC Units', ['AC Unit']),
  _workbookCategory('ac-parts', 'AC Unit Parts'),
  _workbookCategory('access', 'Access Doors', ['Acces Door']),
  _workbookCategory('damper', 'Dampers & Fire Control'),
  _workbookCategory('duct', 'Ductwork & Accessories', ['Ducting Materials']),
  _workbookCategory('electrical', 'Electrical & Controls', [
    'Electrical & Cable Management',
  ]),
  _workbookCategory('fans', 'Fans & Equipment', ['Fans & Ventilation']),
  _workbookCategory('fixings', 'Fasteners & Fixings'),
  _workbookCategory('filters', 'Filters'),
  _workbookCategory('piping', 'Piping & Drain'),
  _workbookCategory('pipe-fittings', 'Pipe Fittings'),
  _workbookCategory('pipes', 'Pipes & Tubes'),
  _workbookCategory('chemicals', 'Refrigerants & Chemicals'),
  _workbookCategory('supports', 'Supports & Insulation'),
  _workbookCategory('tools', 'Tools & Consumables', ['Tools & Equipment']),
  _workbookCategory('valves', 'Valves & Strainers'),
  _workbookCategory('general', 'General Items'),
  _workbookCategory('general-custom', 'General & Custom'),
];

YorksV1InventoryCategory _workbookCategory(
  String id,
  String name, [
  List<String> aliases = const [],
]) => YorksV1InventoryCategory(
  id: id,
  name: name,
  isSystem: true,
  isActive: true,
  recordVersion: 1,
  itemCount: 0,
  aliases: aliases,
  createdByDisplayName: 'Yorks standard',
  createdAt: DateTime.utc(2026, 8, 20),
);

final _suppliers = [
  YorksV1InventorySupplierMaster(
    id: 'supplier-trox',
    name: 'TROX Middle East LLC',
    aliases: const ['TROX Middle East'],
  ),
  YorksV1InventorySupplierMaster(
    id: 'supplier-kitz',
    name: 'KITZ Gulf FZE',
    aliases: const ['KITZ'],
  ),
  YorksV1InventorySupplierMaster(
    id: 'supplier-dubai-cable',
    name: 'Dubai Cable Company',
  ),
  YorksV1InventorySupplierMaster(
    id: 'supplier-copeland',
    name: 'Copeland Gulf',
  ),
  YorksV1InventorySupplierMaster(id: 'supplier-betec', name: 'Betec CAD UAE'),
];

YorksV1BoqWorksheet _inventoryWorksheet({
  required String name,
  required int rowCount,
}) {
  final columns = [
    for (var index = 0; index < _officialHeaders.length; index++)
      YorksV1BoqColumn(
        id: 'column-$index',
        heading: _officialHeaders[index],
        displayOrder: index + 1,
      ),
  ];
  return YorksV1BoqWorksheet(
    group: YorksV1BoqGroup(
      id: 'group-$name',
      projectId: 'project-r38-9',
      name: name,
      worksheetTitle: name,
      displayOrder: 1,
      isCustom: true,
      isArchived: false,
      version: 1,
      rowCount: rowCount,
      columnCount: columns.length,
      updatedAt: DateTime.utc(2026, 8, 20),
    ),
    columns: columns,
    rows: [
      for (var rowIndex = 0; rowIndex < rowCount; rowIndex++)
        YorksV1BoqRow(
          id: 'row-$rowIndex',
          displayOrder: rowIndex + 1,
          values: {
            for (
              var columnIndex = 0;
              columnIndex < columns.length;
              columnIndex++
            )
              columns[columnIndex].id: columnIndex == 1
                  ? 'ITEM-${rowIndex + 1}'
                  : _validExternalRow[columnIndex],
          },
          canonicalValues: const {},
        ),
    ],
  );
}

class _ImportRepository implements YorksV1LogisticsRepository {
  final inputs = <YorksV1InventoryImportInput>[];

  @override
  Future<YorksV1InventoryImportResult> importInventory(
    YorksV1InventoryImportInput input,
  ) async {
    inputs.add(input);
    return const YorksV1InventoryImportResult(
      importBatchId: 'legacy-batch',
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
