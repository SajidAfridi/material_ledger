import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/engineering_tools/presentation/widgets/yorks_calculator_controls.dart';

void main() {
  testWidgets(
    'typing an unfinished picker search invalidates its old selection',
    (tester) async {
      var valid = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: YorksCalculatorSelect<String>(
                label: 'Project',
                value: 'one',
                searchable: true,
                entries: const [
                  DropdownMenuEntry(value: 'one', label: 'Project One'),
                  DropdownMenuEntry(value: 'two', label: 'Project Two'),
                ],
                onValidityChanged: (v) => valid = v,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(valid, isTrue);
      await tester.enterText(find.byType(TextField), 'unfinished search');
      await tester.pumpAndSettle();
      expect(valid, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('picker text undo does not undo calculator inputs', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var calculatorUndos = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Actions(
            actions: {
              UndoTextIntent: YorksCalculatorHistoryAction<UndoTextIntent>(
                () => calculatorUndos++,
              ),
            },
            child: SizedBox(
              width: 400,
              child: YorksCalculatorSelect<String>(
                label: 'Fitting',
                value: 'one',
                searchable: true,
                entries: const [
                  DropdownMenuEntry(value: 'one', label: 'Straight Duct'),
                ],
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.enterText(find.byType(TextField), 'query');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(calculatorUndos, 0);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Straight Duct',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('select-only dropdown exposes its label and selected value', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: YorksCalculatorSelect<String>(
              label: 'Sizing method',
              value: 'check',
              entries: const [
                DropdownMenuEntry(value: 'check', label: 'Check size'),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Sizing method: Check size'), findsOneWidget);
    semantics.dispose();
  });
  test('shortcut hints follow Mac and Windows modifier conventions', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(YorksCalculatorShortcuts.addRow, '⇧⌘↵');
    expect(YorksCalculatorShortcuts.undo, '⌘Z');
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(YorksCalculatorShortcuts.addRow, 'Ctrl+Shift+Enter');
    expect(YorksCalculatorShortcuts.undo, 'Ctrl+Z');
    debugDefaultTargetPlatformOverride = null;
  });
}
