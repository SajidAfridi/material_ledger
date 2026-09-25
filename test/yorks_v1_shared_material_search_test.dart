import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_material_request_screens.dart';
import 'package:material_ledger/shared/controllers/yorks_v1_material_line_editor.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';

void main() {
  for (final dismiss in ['short query', 'Escape', 'context']) {
    testWidgets('$dismiss prevents an old catalogue response from reopening', (
      tester,
    ) async {
      final actions = _Lines();
      final pending =
          Completer<List<YorksV1MaterialRequestInventorySuggestion>>();
      final context = ValueNotifier('first');
      addTearDown(context.dispose);
      await _pump(tester, actions, (_) => pending.future, context: context);
      await tester.enterText(find.byType(TextFormField), 'helmet');
      await tester.pump(const Duration(milliseconds: 250));
      if (dismiss == 'short query') {
        await tester.enterText(find.byType(TextFormField), 'h');
      } else if (dismiss == 'Escape') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else {
        context.value = 'second';
        await tester.pump();
      }
      pending.complete([_suggestion('old', 'Old helmet')]);
      await tester.pumpAndSettle();
      expect(find.text('Old helmet'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'keyboard selection preserves entered quantity and fills technical fields',
    (tester) async {
      final actions = _Lines();
      await _pump(
        tester,
        actions,
        (_) async => [
          _suggestion('a', 'First helmet'),
          _suggestion('b', 'Second helmet'),
        ],
      );
      await tester.enterText(find.byType(TextFormField), 'helmet');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(actions.line.description, 'Second helmet');
      expect(actions.line.quantity, '7');
      expect(actions.line.model, 'H700');
      expect(actions.line.size, 'Large');
      expect(actions.line.brandOrigin, 'Yorks');
      expect(find.text('Second helmet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search failure keeps custom text and offers a recoverable status',
    (tester) async {
      final actions = _Lines();
      await _pump(
        tester,
        actions,
        (_) async => throw StateError('private transport data'),
      );
      await tester.enterText(find.byType(TextFormField), 'Custom material');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(
        find.text('Search unavailable. Keep typing or try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('private transport data'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(actions.line.description, 'Custom material');
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Lines actions,
  Future<List<YorksV1MaterialRequestInventorySuggestion>> Function(String)
  search, {
  ValueNotifier<String>? context,
}) async {
  final key = context ?? ValueNotifier('first');
  if (context == null) addTearDown(key.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: ValueListenableBuilder(
              valueListenable: key,
              builder: (_, value, _) => YorksV1MaterialDescriptionField(
                line: actions.line,
                controller: actions,
                enabled: true,
                projectId: null,
                scopeId: null,
                compact: true,
                searchContext: value,
                search: search,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

YorksV1MaterialRequestInventorySuggestion _suggestion(
  String id,
  String description,
) => YorksV1MaterialRequestInventorySuggestion(
  id: id,
  description: description,
  unit: 'Nos',
  size: 'Large',
  model: 'H700',
  brandOrigin: 'Yorks',
);

class _Lines implements YorksV1MaterialLineEditor {
  YorksV1MaterialRequestLine line = const YorksV1MaterialRequestLine(
    id: 'line',
    displayOrder: 1,
    source: YorksV1MaterialRequestLineSource.custom,
    description: '',
    quantity: '7',
    unit: 'Nos',
  );
  @override
  Future<void> updateLine(
    String id,
    YorksV1MaterialRequestLine Function(YorksV1MaterialRequestLine) transform,
  ) async {
    line = transform(line);
  }

  @override
  Future<void> addCustomLine({String? afterLineId}) async {}
  @override
  Future<void> addSimilarLine({String? afterLineId}) async {}
  @override
  Future<void> removeLine(String lineId) async {}
}
