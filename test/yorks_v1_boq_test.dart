import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/projects/presentation/screens/yorks_v1_boq_screens.dart';
import 'package:material_ledger/shared/controllers/yorks_v1_boq_controller.dart';
import 'package:material_ledger/shared/models/yorks_v1_boq.dart';
import 'package:material_ledger/shared/models/yorks_v1_boq_workbook.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_boq_repository.dart';
import 'package:material_ledger/shared/services/yorks_v1_boq_workbook_service.dart';

void main() {
  group('Yorks V1 BOQ worksheet controller', () {
    test(
      'inserts blank and similar rows directly below the active row',
      () async {
        final repository = _FakeBoqRepository(_worksheet());
        final controller = YorksV1BoqWorksheetController(
          groupId: _groupId,
          repository: repository,
          uuidFactory: _Ids().next,
        );
        addTearDown(controller.dispose);

        await controller.load();
        final similar = controller.addSimilarRow(sourceRowId: _rowId);
        final blank = controller.addBlankRow(afterRowId: similar.id);

        final rows = controller.state.worksheet!.rows;
        expect(rows.map((row) => row.id), [_rowId, similar.id, blank.id]);
        expect(similar.valueFor(_columnId), 'Motorized Smoke Damper');
        expect(blank.values, isEmpty);
        expect(rows.map((row) => row.displayOrder), [1, 2, 3]);
        expect(controller.state.hasUnsavedChanges, isTrue);
      },
    );

    test(
      'keeps raw arbitrary values while saving a version-checked snapshot',
      () async {
        final repository = _FakeBoqRepository(_worksheet());
        final controller = YorksV1BoqWorksheetController(
          groupId: _groupId,
          repository: repository,
          uuidFactory: _Ids().next,
        );
        addTearDown(controller.dispose);

        await controller.load();
        controller.addColumn(heading: 'Air flow (L/s)');
        final newColumn = controller.state.worksheet!.columns.last;
        controller.updateCell(
          rowId: _rowId,
          columnId: newColumn.id,
          value: '708',
        );

        expect(await controller.save(), isTrue);
        final submitted = repository.saved.single;
        expect(submitted.expectedVersion, 1);
        expect(submitted.worksheet.rows.single.valueFor(newColumn.id), '708');
        expect(controller.state.status, YorksV1BoqSyncStatus.saved);
      },
    );

    test(
      'edits canonical cells and archives omitted rows and columns on save',
      () async {
        final repository = _FakeBoqRepository(_worksheet());
        final controller = YorksV1BoqWorksheetController(
          groupId: _groupId,
          repository: repository,
          uuidFactory: _Ids().next,
        );
        addTearDown(controller.dispose);

        await controller.load();
        controller.updateCell(
          rowId: _rowId,
          columnId: _columnId,
          value: 'Updated damper',
        );
        final extra = controller.addBlankRow(afterRowId: _rowId);
        controller.removeRow(extra.id);
        controller.removeColumn(_columnId);

        expect(controller.state.worksheet!.rows.single.canonicalValues, {
          'description': 'Updated damper',
        });
        expect(await controller.save(), isTrue);
        expect(repository.saved.single.worksheet.rows, hasLength(1));
        expect(repository.saved.single.worksheet.columns, isEmpty);
      },
    );

    test(
      'keeps local edits visible when the server reports a conflict',
      () async {
        final repository = _FakeBoqRepository(
          _worksheet(),
          conflictOnSave: true,
        );
        final controller = YorksV1BoqWorksheetController(
          groupId: _groupId,
          repository: repository,
          uuidFactory: _Ids().next,
        );
        addTearDown(controller.dispose);

        await controller.load();
        controller.updateTitle('Changed by this editor');

        expect(await controller.save(), isFalse);
        expect(controller.state.status, YorksV1BoqSyncStatus.conflict);
        expect(
          controller.state.worksheet!.group.worksheetTitle,
          'Changed by this editor',
        );
      },
    );

    test(
      'commits a reviewed workbook preview as a new worksheet revision',
      () async {
        final repository = _FakeBoqRepository(_worksheet());
        final controller = YorksV1BoqWorksheetController(
          groupId: _groupId,
          repository: repository,
          uuidFactory: _Ids().next,
        );
        addTearDown(controller.dispose);

        await controller.load();
        final preview = YorksV1BoqImportPreview(
          fileName: 'MSD Equipment Schedule.xlsx',
          worksheetName: 'MSD Schedule',
          title: 'Imported MSD Equipment Schedule',
          headerRowIndex: 2,
          columns: const [
            YorksV1BoqImportColumn(
              sourceIndex: 0,
              heading: 'Item Description',
              canonicalField: YorksV1BoqCanonicalField.description,
            ),
            YorksV1BoqImportColumn(sourceIndex: 1, heading: 'Air flow (L/s)'),
          ],
          rows: [
            YorksV1BoqImportRow(
              sourceRowNumber: 4,
              values: const {0: 'Motorized Smoke Damper', 1: '708'},
            ),
          ],
          validationIssues: const [],
        );

        expect(await controller.importWorkbook(preview), isTrue);
        final imported = repository.saved.last.worksheet;
        expect(
          imported.group.worksheetTitle,
          'Imported MSD Equipment Schedule',
        );
        expect(imported.columns.map((column) => column.heading), [
          'Item Description',
          'Air flow (L/s)',
        ]);
        expect(imported.rows.single.valueFor(imported.columns.last.id), '708');
      },
    );
  });

  group('Yorks V1 BOQ XLSX codec', () {
    const codec = YorksV1BoqWorkbookCodec();

    test('exports, imports and previews arbitrary headings and row values', () {
      final original = _worksheet().copyWith(
        columns: const [
          YorksV1BoqColumn(
            id: _columnId,
            heading: 'Item Description',
            displayOrder: 1,
            canonicalField: YorksV1BoqCanonicalField.description,
          ),
          YorksV1BoqColumn(
            id: '10000000-0000-4000-8000-000000000014',
            heading: 'Air flow (L/s)',
            displayOrder: 2,
          ),
        ],
        rows: [
          YorksV1BoqRow(
            id: _rowId,
            displayOrder: 1,
            values: const {
              _columnId: 'Motorized Smoke Damper',
              '10000000-0000-4000-8000-000000000014': '708',
            },
            canonicalValues: const {'description': 'Motorized Smoke Damper'},
          ),
        ],
      );

      final workbook = codec.decode(
        bytes: codec.encodeWorksheet(original),
        fileName: 'MSD Equipment Schedule.xlsx',
      );
      final preview = codec.preview(
        workbook: workbook,
        sheet: workbook.sheets.single,
        fallbackTitle: 'Fallback',
      );

      expect(preview.title, 'Damper Schedule');
      expect(preview.headerRowNumber, 2);
      expect(preview.columns.map((column) => column.heading), [
        'Item Description',
        'Air flow (L/s)',
      ]);
      expect(preview.rows.single.valueFor(1), '708');
      expect(preview.isValid, isTrue);
    });

    test('exports a project workbook with one worksheet per BOQ group', () {
      final first = _worksheet();
      final second = _worksheet().copyWith(
        group: YorksV1BoqGroup(
          id: '10000000-0000-4000-8000-000000000099',
          projectId: first.group.projectId,
          name: 'Ventilation Fans',
          worksheetTitle: 'Ventilation Fans',
          displayOrder: 2,
          isCustom: false,
          isArchived: false,
          version: 1,
          rowCount: first.group.rowCount,
          columnCount: first.group.columnCount,
          updatedAt: first.group.updatedAt,
        ),
      );

      final workbook = codec.decode(
        bytes: codec.encodeWorksheets([first, second]),
        fileName: 'Yorks_BOQ.xlsx',
      );

      expect(workbook.sheets.map((sheet) => sheet.name), [
        'Damper Schedule',
        'Ventilation Fans',
      ]);
      expect(workbook.sheets.first.rows, isNotEmpty);
      expect(workbook.sheets.last.rows, isNotEmpty);
    });

    test('flags blank and duplicate headings before an import command', () {
      final workbook = YorksV1BoqParsedWorkbook(
        fileName: 'invalid.xlsx',
        sheets: [
          YorksV1BoqWorkbookSheet(
            name: 'BOQ',
            rows: const [
              ['Damper Schedule'],
              ['Description', '', 'description'],
              ['MSD', '708', 'MSD-01'],
            ],
          ),
        ],
      );
      final preview = codec.preview(
        workbook: workbook,
        sheet: workbook.sheets.single,
        fallbackTitle: 'Fallback',
        headerRowIndex: 1,
      );

      expect(preview.isValid, isFalse);
      expect(
        preview.validationIssues.map((issue) => issue.code),
        containsAll([
          YorksV1BoqImportValidationCode.blankHeading,
          YorksV1BoqImportValidationCode.duplicateHeading,
        ]),
      );
    });

    test('imports a two-level Package Unit header without blank headings', () {
      final workbook = YorksV1BoqParsedWorkbook(
        fileName: 'Equipment Schedule.xlsx',
        sheets: [
          YorksV1BoqWorkbookSheet(
            name: 'Package Unit',
            rows: [
              List<String>.filled(21, ''),
              [
                '',
                'PACKAGE UNIT SCHEDULE',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
              ],
              [
                '',
                'S: No',
                'Unit Refrence',
                'PU-TAG',
                'Model',
                'T. Cooling Capacity (KW)',
                '',
                'S. Cooling Capacity (KW)',
                '',
                'Air Flow (L/s)',
                '',
                'ESP',
                '',
                'Electrical Details',
                'Total Power Input (Kw)',
                'Dimension (LxWxH)',
                'QTY',
                'Make',
                'Mass No',
                'Material Status',
                '',
              ],
              [
                '',
                '',
                '',
                '',
                '',
                'Calculated',
                'Selected',
                'Calculated',
                'Selected',
                'Calculated',
                'Selected',
                'Calculated',
                'Selected',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
              ],
              [
                '',
                '1',
                'SYSTEM-01',
                'PU-01A',
                'AMPR52052AM',
                '148.8',
                '148.8',
                '106.9',
                '108.3',
                '4972',
                '4972',
                '500',
                '500',
                '415/3/50',
                '75.4',
                '4406 x 2235 x 3630',
                '3',
                'SKM/UAE',
                'MTS-CS-0220',
                'AP',
                '',
              ],
            ],
          ),
        ],
      );

      final preview = codec.preview(
        workbook: workbook,
        sheet: workbook.sheets.single,
        fallbackTitle: 'Fallback',
      );

      expect(preview.title, 'PACKAGE UNIT SCHEDULE');
      expect(preview.headerRowIndexes, [2, 3]);
      expect(preview.headerRowNumber, 3);
      expect(preview.headerRowNumbers, [3, 4]);
      expect(preview.columns, hasLength(19));
      expect(
        preview.columns.map((column) => column.heading),
        containsAll([
          'T. Cooling Capacity (KW) — Calculated',
          'T. Cooling Capacity (KW) — Selected',
          'Air Flow (L/s) — Calculated',
          'Air Flow (L/s) — Selected',
        ]),
      );
      expect(
        preview.columns.map((column) => column.heading),
        isNot(contains('')),
      );
      expect(preview.headerHierarchy, hasLength(preview.columns.length));
      expect(preview.rows.single.sourceRowNumber, 5);
      expect(preview.rows.single.valueFor(6), '148.8');
      expect(preview.isValid, isTrue);
    });

    test('rejects malformed non-XLSX bytes', () {
      expect(
        () => codec.decode(
          bytes: Uint8List.fromList(const [1, 2, 3]),
          fileName: 'not-a-workbook.xlsx',
        ),
        throwsA(isA<YorksV1DomainException>()),
      );
    });
  });

  group('Yorks V1 responsive BOQ spreadsheet', () {
    testWidgets('uses a focused mobile row editor at 360px', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_spreadsheetHarness(size: const Size(360, 700)));

      expect(
        find.byKey(const ValueKey('yorks-v1-boq-mobile-list')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('mobile-boq-row-$_rowId')));
      await tester.pumpAndSettle();

      expect(find.text('Edit row 1'), findsOneWidget);
      expect(find.text('Item Description'), findsWidgets);
      expect(find.text('Previous'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps a virtualized desktop grid usable with 500 rows', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final base = _worksheet();
      final worksheet = base.copyWith(
        rows: List.generate(
          500,
          (index) => YorksV1BoqRow(
            id: 'row-$index',
            displayOrder: index + 1,
            values: {_columnId: 'Damper ${index + 1}'},
            canonicalValues: const {},
          ),
        ),
      );
      await tester.pumpWidget(_spreadsheetHarness(worksheet: worksheet));

      expect(
        find.byKey(const ValueKey('yorks-v1-boq-desktop-grid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('boq-cell-row-0-$_columnId')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('boq-cell-row-499-$_columnId')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('boq-cell-row-0-$_columnId')));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'row-1:$_columnId',
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'row-0:$_columnId',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('commits a desktop cell only after blur or Enter', (
      tester,
    ) async {
      final updates = <String>[];
      await tester.binding.setSurfaceSize(const Size(1200, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _spreadsheetHarness(
          onUpdateCell: ({required rowId, required columnId, required value}) {
            updates.add('$rowId:$columnId:$value');
          },
        ),
      );

      final cell = find.byKey(const ValueKey('boq-cell-$_rowId-$_columnId'));
      await tester.tap(cell);
      await tester.enterText(cell, 'Edited smoke damper');
      await tester.pump();
      expect(updates, isEmpty);

      await tester.tap(find.byKey(const ValueKey('boq-column-$_columnId')));
      await tester.pump();
      expect(updates, ['$_rowId:$_columnId:Edited smoke damper']);
    });
  });
}

const _projectId = '10000000-0000-4000-8000-000000000010';
const _groupId = '10000000-0000-4000-8000-000000000011';
const _rowId = '10000000-0000-4000-8000-000000000012';
const _columnId = '10000000-0000-4000-8000-000000000013';

YorksV1BoqWorksheet _worksheet() {
  return YorksV1BoqWorksheet(
    group: YorksV1BoqGroup(
      id: _groupId,
      projectId: _projectId,
      name: 'MFD, MSFD, MSD, MVCD & VCD',
      worksheetTitle: 'Damper Schedule',
      displayOrder: 3,
      isCustom: false,
      isArchived: false,
      version: 1,
      rowCount: 1,
      columnCount: 1,
      updatedAt: DateTime.utc(2026, 8, 2),
    ),
    columns: const [
      YorksV1BoqColumn(
        id: _columnId,
        heading: 'Item Description',
        displayOrder: 1,
        canonicalField: YorksV1BoqCanonicalField.description,
      ),
    ],
    rows: [
      YorksV1BoqRow(
        id: _rowId,
        displayOrder: 1,
        values: const {_columnId: 'Motorized Smoke Damper'},
        canonicalValues: const {'description': 'Motorized Smoke Damper'},
      ),
    ],
  );
}

Widget _spreadsheetHarness({
  YorksV1BoqWorksheet? worksheet,
  Size size = const Size(1200, 700),
  void Function({
    required String rowId,
    required String columnId,
    required String value,
  })?
  onUpdateCell,
}) {
  final effective = worksheet ?? _worksheet();
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: YorksV1BoqSpreadsheet(
          worksheet: effective,
          editable: true,
          onUpdateCell:
              onUpdateCell ??
              ({required rowId, required columnId, required value}) {},
          onAddBlankRow: ({afterRowId}) => effective.rows.first,
          onAddSimilarRow: ({required sourceRowId}) => effective.rows.first,
          onRemoveRow: (_) {},
          onAddColumn: ({required heading, canonicalField}) {},
          onRenameColumn: (_, _) {},
          onRemoveColumn: (_) {},
        ),
      ),
    ),
  );
}

class _FakeBoqRepository implements YorksV1BoqRepository {
  _FakeBoqRepository(this.worksheet, {this.conflictOnSave = false});

  final YorksV1BoqWorksheet worksheet;
  final bool conflictOnSave;
  final List<YorksV1SaveBoqWorksheetInput> saved = [];

  @override
  Future<void> archiveGroup({
    required String groupId,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {}

  @override
  Future<YorksV1BoqGroup> createCustomGroup(
    YorksV1CreateBoqGroupInput input,
  ) async => worksheet.group;

  @override
  Future<YorksV1BoqWorksheet> getWorksheet(String groupId) async => worksheet;

  @override
  Future<YorksV1BoqWorksheet> importWorksheet(
    YorksV1ImportBoqWorksheetInput input,
  ) async => saveWorksheet(
    YorksV1SaveBoqWorksheetInput(
      worksheet: input.worksheet,
      worksheetTitle: input.worksheetTitle,
      expectedVersion: input.expectedVersion,
      idempotencyKey: input.idempotencyKey,
    ),
  );

  @override
  Future<List<YorksV1BoqGroup>> listGroups(String projectId) async => [
    worksheet.group,
  ];

  @override
  Future<YorksV1BoqWorksheet> saveWorksheet(
    YorksV1SaveBoqWorksheetInput input,
  ) async {
    saved.add(input);
    if (conflictOnSave) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.conflict);
    }
    return input.worksheet.copyWith(
      group: YorksV1BoqGroup(
        id: input.worksheet.group.id,
        projectId: input.worksheet.group.projectId,
        name: input.worksheet.group.name,
        worksheetTitle: input.worksheetTitle,
        displayOrder: input.worksheet.group.displayOrder,
        isCustom: input.worksheet.group.isCustom,
        isArchived: input.worksheet.group.isArchived,
        version: input.expectedVersion + 1,
        rowCount: input.worksheet.rows.length,
        columnCount: input.worksheet.columns.length,
        updatedAt: DateTime.utc(2026, 8, 2),
      ),
    );
  }
}

class _Ids {
  var _value = 20;
  String next() =>
      '10000000-0000-4000-8000-${(_value++).toString().padLeft(12, '0')}';
}
