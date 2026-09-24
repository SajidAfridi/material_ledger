import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_company_material_request_screen.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/yorks_v1_company_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/providers/yorks_v1_company_material_request_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_company_material_request_repository.dart';

void main() {
  testWidgets('shortened query discards an older in-flight catalogue result', (
    tester,
  ) async {
    final repo = _SearchRepo();
    await _pump(tester, repo);
    await tester.enterText(find.byType(TextFormField), 'helmet');
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.pending.length, 1);
    await tester.enterText(find.byType(TextFormField), 'h');
    repo.pending.single.complete([_suggestion('old', 'Old helmet')]);
    await tester.pumpAndSettle();
    expect(find.text('Old helmet'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'keyboard selects descriptive fields and preserves deliberate quantity',
    (tester) async {
      final repo = _SearchRepo();
      YorksV1CompanyMaterialRequestLine? selected;
      await _pump(tester, repo, onChanged: (line) => selected = line);
      await tester.enterText(find.byType(TextFormField), 'helmet');
      await tester.pump(const Duration(milliseconds: 300));
      repo.pending.single.complete([
        _suggestion('first', 'First helmet'),
        _suggestion('second', 'Second helmet'),
      ]);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected!.description, 'Second helmet');
      expect(selected!.quantity, '7');
      expect(selected!.model, 'H700');
      expect(
        find.byKey(const ValueKey('company-material-suggestion-second')),
        findsNothing,
      );
    },
  );
  testWidgets(
    'failed search explains recovery while keeping custom description',
    (tester) async {
      final repo = _SearchRepo();
      await _pump(tester, repo);
      await tester.enterText(find.byType(TextFormField), 'custom item');
      await tester.pump(const Duration(milliseconds: 300));
      repo.pending.single.completeError(Exception('private transport details'));
      await tester.pumpAndSettle();
      expect(
        find.text('Search unavailable. Keep typing or try again.'),
        findsOneWidget,
      );
      expect(find.text('custom item'), findsOneWidget);
      expect(find.textContaining('private transport'), findsNothing);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  _SearchRepo repo, {
  ValueChanged<YorksV1CompanyMaterialRequestLine>? onChanged,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        yorksV1CompanyMaterialRequestRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CompanyMaterialDescriptionSearch(
            language: AppLanguage.english,
            line: const YorksV1CompanyMaterialRequestLine(
              id: 'line',
              displayOrder: 1,
              description: '',
              quantity: '7',
              unit: 'pcs',
            ),
            categoryId: 'category',
            responsibleUnitId: 'unit',
            compact: true,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

YorksV1MaterialRequestInventorySuggestion _suggestion(
  String id,
  String description,
) => YorksV1MaterialRequestInventorySuggestion(
  id: id,
  itemCode: id,
  description: description,
  unit: 'pcs',
  model: 'H700',
);

class _SearchRepo implements YorksV1CompanyMaterialRequestRepository {
  final pending =
      <Completer<List<YorksV1MaterialRequestInventorySuggestion>>>[];
  @override
  Future<List<YorksV1MaterialRequestInventorySuggestion>> searchMaterials({
    required String categoryId,
    required String responsibleUnitId,
    required String query,
  }) {
    final next = Completer<List<YorksV1MaterialRequestInventorySuggestion>>();
    pending.add(next);
    return next.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
