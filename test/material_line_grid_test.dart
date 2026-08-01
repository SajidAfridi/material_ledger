import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/shared/controllers/material_line_grid_controller.dart';
import 'package:material_ledger/shared/models/material_line_draft.dart';
import 'package:material_ledger/shared/services/material_line_csv_export.dart';
import 'package:material_ledger/shared/widgets/material_line_grid.dart';

void main() {
  group('material line security and smart rows', () {
    test('operational JSON contains no commercial fields', () {
      const line = MaterialLineDraft(
        id: 'line-1',
        description: 'Supply Air Grille',
        quantity: 4,
      );

      expect(line.toJson(), isNot(contains('unitCost')));
      expect(line.toJson(), isNot(contains('totalCost')));
      expect(line.toJson(), isNot(contains('unitCostAED')));
    });

    test('denied controller drops a supplied commercial payload', () {
      final controller = MaterialLineGridController(
        lines: const [MaterialLineDraft(id: 'line-1')],
        commercials: const {
          'line-1': MaterialLineCommercial(lineId: 'line-1', unitCostAED: 99),
        },
        commercialsEnabled: false,
      );
      addTearDown(controller.dispose);

      expect(controller.commercials, isEmpty);
      expect(controller.commercialFor('line-1'), isNull);
    });

    test('Similar Row carries only the approved five fields', () {
      final controller = MaterialLineGridController(
        lines: const [
          MaterialLineDraft(
            id: 'source',
            description: 'Volume Control Damper',
            size: '500 x 500 mm',
            modelSerial: 'VCD-001',
            makeOrigin: 'Yorks / UAE',
            quantity: 8,
            unitSymbol: 'Nos',
            remarks: 'Approved drawing',
          ),
        ],
        commercials: const {
          'source': MaterialLineCommercial(lineId: 'source', unitCostAED: 125),
        },
        commercialsEnabled: true,
        idFactory: () => 'similar',
      );
      addTearDown(controller.dispose);

      final similar = controller.addSimilarRow(sourceLineId: 'source');

      expect(similar.description, 'Volume Control Damper');
      expect(similar.size, '500 x 500 mm');
      expect(similar.makeOrigin, 'Yorks / UAE');
      expect(similar.unitSymbol, 'Nos');
      expect(similar.remarks, 'Approved drawing');
      expect(similar.modelSerial, isEmpty);
      expect(similar.quantity, isNull);
      expect(controller.commercialFor(similar.id), isNull);
    });

    test('undo and redo restore complete isolated snapshots', () {
      var next = 0;
      final controller = MaterialLineGridController(
        commercialsEnabled: false,
        idFactory: () => 'line-${next++}',
      );
      addTearDown(controller.dispose);

      controller.addBlankRow();
      controller.updateField(
        'line-0',
        MaterialLineField.description,
        'Copper Pipe',
      );
      controller.undo();
      expect(controller.lines.single.description, isEmpty);
      controller.redo();
      expect(controller.lines.single.description, 'Copper Pipe');
    });
  });

  group('paste, validation and autosave', () {
    test('Excel TSV paste creates rows and authorised commercial values', () {
      var next = 0;
      final controller = MaterialLineGridController(
        commercialsEnabled: true,
        idFactory: () => 'paste-${next++}',
      );
      addTearDown(controller.dispose);

      controller.pasteTsv(
        'Supply Grille\t500 x 500 mm\tSG-01\tYorks\t4\tNos\tLevel 1\t25.50\n'
        'Copper Pipe\t22 mm\t\tUAE\t12\tm\tRiser\t8',
      );

      expect(controller.lines, hasLength(2));
      expect(controller.lines.first.description, 'Supply Grille');
      expect(controller.lines.last.quantity, 12);
      expect(controller.commercialFor('paste-0')?.unitCostAED, 25.5);
      expect(controller.commercialFor('paste-0')?.totalCostAED(4), 102);
    });

    test('denied paste cannot retain an eighth commercial column', () {
      final controller = MaterialLineGridController(
        commercialsEnabled: false,
        idFactory: () => 'denied',
      );
      addTearDown(controller.dispose);

      controller.pasteTsv(
        'Supply Grille\t500 x 500 mm\tSG-01\tYorks\t4\tNos\tLevel 1\t999',
      );

      expect(controller.lines.single.remarks, 'Level 1');
      expect(controller.commercials, isEmpty);
      expect(
        controller.lines.single.toJson().toString(),
        isNot(contains('999')),
      );
    });

    test('validation preserves incomplete draft values', () {
      final controller = MaterialLineGridController(
        lines: const [MaterialLineDraft(id: 'draft', unitSymbol: '')],
        commercialsEnabled: false,
      );
      addTearDown(controller.dispose);

      final errors = controller.validateLine(controller.lines.single);

      expect(errors.keys, {
        MaterialLineField.description,
        MaterialLineField.quantity,
        MaterialLineField.unit,
      });
      expect(controller.lines.single.id, 'draft');
    });

    test(
      'debounced autosave receives operational and allowed payloads',
      () async {
        final saved = Completer<void>();
        late List<MaterialLineDraft> lines;
        late Map<String, MaterialLineCommercial> commercials;
        final controller = MaterialLineGridController(
          lines: const [MaterialLineDraft(id: 'line-1')],
          commercialsEnabled: true,
          autosaveDelay: Duration.zero,
          onAutosave: (nextLines, nextCommercials) {
            lines = nextLines;
            commercials = nextCommercials;
            if (!saved.isCompleted) saved.complete();
          },
        );
        addTearDown(controller.dispose);

        controller.updateField(
          'line-1',
          MaterialLineField.description,
          'Duct Sealant',
        );
        await saved.future;

        expect(lines.single.description, 'Duct Sealant');
        expect(commercials, isEmpty);
      },
    );

    test('a 500-row edit remains comfortably below the spike budget', () {
      final controller = MaterialLineGridController(
        lines: List.generate(
          500,
          (index) => MaterialLineDraft(id: 'line-$index', quantity: 1),
        ),
        commercialsEnabled: false,
      );
      addTearDown(controller.dispose);
      final stopwatch = Stopwatch()..start();

      controller.updateField(
        'line-499',
        MaterialLineField.description,
        'Final row',
      );
      stopwatch.stop();

      expect(controller.lines.last.description, 'Final row');
      expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 200)));
    });
  });

  group('size and CSV contracts', () {
    test('formats common HVAC sizes deterministically', () {
      expect(
        MaterialSizeFormatter.rectangular(width: 500, height: 400),
        '500 x 400 mm',
      );
      expect(MaterialSizeFormatter.circular(diameter: 315), 'Ø315 mm');
      expect(MaterialSizeFormatter.linear(length: 6), '6 m');
      expect(MaterialSizeFormatter.nominalPipe(' DN50 '), 'DN50');
    });

    test('CSV escapes Excel-sensitive text and omits denied costs', () {
      const line = MaterialLineDraft(
        id: 'line-1',
        description: 'Grille, "double deflection"',
        quantity: 2,
        remarks: 'Level 1\nNorth',
      );
      const commercial = MaterialLineCommercial(
        lineId: 'line-1',
        unitCostAED: 50,
      );

      final denied = MaterialLineCsvExport.build(
        lines: const [line],
        commercials: const {'line-1': commercial},
        includeCommercials: false,
      );
      final allowed = MaterialLineCsvExport.build(
        lines: const [line],
        commercials: const {'line-1': commercial},
        includeCommercials: true,
      );

      expect(denied, contains('"Grille, ""double deflection"""'));
      expect(denied, isNot(contains('Unit Cost')));
      expect(denied, isNot(contains('"50.00"')));
      expect(allowed, contains('"Unit Cost","Total Cost"'));
      expect(allowed, contains('"50.00","100.00"'));
    });
  });

  group('responsive material line grid', () {
    testWidgets('desktop renders exactly eight denied columns', (tester) async {
      final controller = MaterialLineGridController(
        lines: const [
          MaterialLineDraft(
            id: 'line-1',
            description: 'Supply Air Grille',
            quantity: 4,
          ),
        ],
        commercialsEnabled: false,
      );
      addTearDown(controller.dispose);

      await _pumpGrid(tester, controller, const Size(1400, 820));

      expect(
        find.byKey(const ValueKey('material-line-grid-desktop')),
        findsOneWidget,
      );
      for (final header in MaterialLineCsvExport.operationalHeaders) {
        expect(find.text(header), findsOneWidget);
      }
      expect(find.text('Unit Cost'), findsNothing);
      expect(find.text('Total Cost'), findsNothing);
      expect(find.byKey(const ValueKey('grid-serial-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('grid-body-list')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('authorised desktop renders all ten approved columns', (
      tester,
    ) async {
      final controller = MaterialLineGridController(
        lines: const [
          MaterialLineDraft(
            id: 'line-1',
            description: 'Supply Air Grille',
            quantity: 4,
          ),
        ],
        commercials: const {
          'line-1': MaterialLineCommercial(lineId: 'line-1', unitCostAED: 25),
        },
        commercialsEnabled: true,
      );
      addTearDown(controller.dispose);

      await _pumpGrid(tester, controller, const Size(1500, 820));

      expect(find.text('Unit Cost'), findsOneWidget);
      expect(find.text('Total Cost'), findsOneWidget);
      expect(find.text('AED 100.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('500 rows stay virtualised on desktop', (tester) async {
      final controller = MaterialLineGridController(
        lines: List.generate(
          500,
          (index) => MaterialLineDraft(
            id: 'line-$index',
            description: 'Material $index',
            quantity: 1,
          ),
        ),
        commercialsEnabled: false,
      );
      addTearDown(controller.dispose);

      await _pumpGrid(tester, controller, const Size(1400, 820));

      expect(find.text('500 rows'), findsOneWidget);
      expect(find.byKey(const ValueKey('grid-row-line-499')), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith('grid-row-'),
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Enter moves down the same desktop column', (tester) async {
      final controller = MaterialLineGridController(
        lines: const [
          MaterialLineDraft(id: 'line-1', description: 'First', quantity: 1),
          MaterialLineDraft(id: 'line-2', description: 'Second', quantity: 1),
        ],
        commercialsEnabled: false,
      );
      addTearDown(controller.dispose);

      await _pumpGrid(tester, controller, const Size(1400, 820));
      await tester.tap(find.byKey(const ValueKey('cell-line-1-description')));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'line-2:description',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile uses cards and a focused editor', (tester) async {
      final controller = MaterialLineGridController(
        lines: const [
          MaterialLineDraft(
            id: 'line-1',
            description: 'Copper Pipe',
            size: '22 mm',
            quantity: 12,
            unitSymbol: 'm',
          ),
        ],
        commercialsEnabled: false,
      );
      addTearDown(controller.dispose);

      await _pumpGrid(tester, controller, const Size(390, 844));
      expect(
        find.byKey(const ValueKey('material-line-grid-mobile')),
        findsOneWidget,
      );
      expect(find.text('Copper Pipe'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('mobile-line-line-1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit material line'), findsOneWidget);
      expect(find.byKey(const ValueKey('focused-description')), findsOneWidget);
      expect(find.text('Unit Cost'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.byKey(const ValueKey('focused-description')),
        'Copper Pipe Type L',
      );
      await tester.tap(find.byKey(const ValueKey('focused-editor-save')));
      await tester.pumpAndSettle();

      expect(controller.lines.single.description, 'Copper Pipe Type L');
      expect(tester.takeException(), isNull);
    });

    testWidgets('size builder applies a formatted rectangular value', (
      tester,
    ) async {
      final controller = MaterialLineGridController(
        lines: const [
          MaterialLineDraft(id: 'line-1', description: 'Grille', quantity: 1),
        ],
        commercialsEnabled: false,
      );
      addTearDown(controller.dispose);

      await _pumpGrid(tester, controller, const Size(1400, 820));
      await tester.tap(find.byKey(const ValueKey('cell-line-1-size')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('size-first')), '600');
      await tester.enterText(find.byKey(const ValueKey('size-second')), '400');
      await tester.tap(find.byKey(const ValueKey('size-apply')));
      await tester.pumpAndSettle();

      expect(controller.lines.single.size, '600 x 400 mm');
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpGrid(
  WidgetTester tester,
  MaterialLineGridController controller,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: MaterialLineGrid(
            controller: controller,
            units: const ['Nos', 'm', 'cm', 'Set', 'Box'],
            onExport: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
