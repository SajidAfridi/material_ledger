import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_arrangement_screen.dart';
import 'package:material_ledger/shared/models/yorks_v1_arrangement.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_arrangement_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_arrangement_repository_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_arrangement_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'embedded arrangement opens the direct editor and closes after a saved hand-off',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _ArrangementRepository();
      final preferences = await SharedPreferences.getInstance();
      var completed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            yorksV1ArrangementRepositoryProvider.overrideWithValue(repository),
            yorksV1ArrangementWorkspaceProvider(
              'request-1',
            ).overrideWith((ref) async => _workingWorkspace),
            yorksV1ArrangementInventoryProvider.overrideWith(
              (ref) async => const [
                YorksV1InventoryItem(
                  id: 'inventory-1',
                  description: 'Motorized smoke damper',
                  unit: 'Nos',
                  onHandQuantity: '12',
                  reservedQuantity: '0',
                  availableQuantity: '12',
                  recordVersion: 1,
                ),
              ],
            ),
          ],
          child: MaterialApp(
            home: SizedBox(
              width: 1320,
              height: 760,
              child: YorksV1ArrangementScreen(
                requestId: 'request-1',
                embedded: true,
                onCompleted: () => completed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Arrange Material Request'), findsOneWidget);
      expect(find.text('Start arrangement'), findsNothing);
      expect(find.text('REQUESTED ITEM'), findsOneWidget);
      expect(find.text('Send to Project Engineer'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/r35/arrange_material_request_desktop.png'),
      );

      await tester.tap(find.text('Send to Project Engineer'));
      await tester.pumpAndSettle();

      expect(repository.saveInputs, hasLength(1));
      expect(completed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('direct arrangement editor remains usable at 360px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          yorksV1ArrangementRepositoryProvider.overrideWithValue(
            _ArrangementRepository(),
          ),
          yorksV1ArrangementWorkspaceProvider(
            'request-1',
          ).overrideWith((ref) async => _workingWorkspace),
          yorksV1ArrangementInventoryProvider.overrideWith(
            (ref) async => const [
              YorksV1InventoryItem(
                id: 'inventory-1',
                description: 'Motorized smoke damper',
                unit: 'Nos',
                onHandQuantity: '12',
                reservedQuantity: '0',
                availableQuantity: '12',
                recordVersion: 1,
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: YorksV1ArrangementScreen(requestId: 'request-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Arrange Material Request'), findsOneWidget);
    expect(find.text('Start arrangement'), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/arrange_material_request_mobile.png'),
    );
  });
}

final _workingWorkspace = YorksV1ArrangementWorkspace(
  requestId: 'request-1',
  requestNumber: 'YRAASDF12-MR101',
  requestState: 'arranging',
  requestRecordVersion: 2,
  canBegin: false,
  canSave: true,
  canDecide: false,
  arrangements: [
    YorksV1ProcurementArrangement(
      id: 'arrangement-1',
      version: 1,
      status: YorksV1ArrangementStatus.working,
      isCurrent: true,
      recordVersion: 1,
      startedByDisplayName: 'Procurement User',
      startedAt: DateTime.utc(2026, 8, 8),
      lines: const [
        YorksV1ArrangementLine(
          id: 'arrangement-line-1',
          requestLineId: 'request-line-1',
          displayOrder: 1,
          description: 'Motorized smoke damper',
          requestedQuantity: '11.0000',
          unit: 'Nos',
          source: YorksV1ArrangementSource.warehouse,
          inventoryItemId: 'inventory-1',
          decision: YorksV1ArrangementDecision.full,
          arrangedQuantity: '11.0000',
          unitCost: '110.29',
        ),
      ],
    ),
  ],
);

class _ArrangementRepository implements YorksV1ArrangementRepository {
  final List<YorksV1SaveArrangementInput> saveInputs = [];

  @override
  Future<YorksV1ArrangementWorkspace> begin(
    YorksV1BeginArrangementInput input,
  ) async => _workingWorkspace;

  @override
  Future<YorksV1ArrangementWorkspace> decide(
    YorksV1DecideArrangementInput input,
  ) async => _workingWorkspace;

  @override
  Future<YorksV1ArrangementWorkspace> getWorkspace(String requestId) async =>
      _workingWorkspace;

  @override
  Future<List<YorksV1InventoryItem>> listInventoryItems() async => const [
    YorksV1InventoryItem(
      id: 'inventory-1',
      description: 'Motorized smoke damper',
      unit: 'Nos',
      onHandQuantity: '12',
      reservedQuantity: '0',
      availableQuantity: '12',
      recordVersion: 1,
    ),
  ];

  @override
  Future<YorksV1ArrangementWorkspace> save(
    YorksV1SaveArrangementInput input,
  ) async {
    saveInputs.add(input);
    return _workingWorkspace;
  }
}
