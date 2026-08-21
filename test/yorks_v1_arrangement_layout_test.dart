import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_arrangement_screen.dart';
import 'package:material_ledger/shared/models/yorks_v1_arrangement.dart';
import 'package:material_ledger/shared/models/yorks_v1_logistics.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/permissions_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_arrangement_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_arrangement_repository_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_logistics_repository_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_arrangement_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_logistics_repository.dart';
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
            canManageCommercialsProvider.overrideWithValue(true),
            canViewCommercialsProvider.overrideWithValue(true),
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
      expect(
        find.text('Linked to BOQ · Building A · Dampers & Fire Control'),
        findsOneWidget,
      );
      expect(find.text('Save arrangement'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/r35/arrange_material_request_desktop.png'),
      );

      await tester.tap(find.text('Save arrangement'));
      await tester.pumpAndSettle();

      expect(repository.saveInputs, hasLength(1));
      expect(completed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'revoked commercial capability hides cost and omits protected writes',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _ArrangementRepository();
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            canManageCommercialsProvider.overrideWithValue(false),
            canViewCommercialsProvider.overrideWithValue(false),
            yorksV1ArrangementRepositoryProvider.overrideWithValue(repository),
            yorksV1ArrangementWorkspaceProvider(
              'request-1',
            ).overrideWith((ref) async => _workingWorkspace),
            yorksV1ArrangementInventoryProvider.overrideWith(
              (ref) async => _inventoryItems,
            ),
          ],
          child: const MaterialApp(
            home: YorksV1ArrangementScreen(
              requestId: 'request-1',
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unit Cost'), findsNothing);
      expect(find.text('110.29'), findsNothing);
      await tester.tap(find.text('Save arrangement'));
      await tester.pumpAndSettle();

      expect(repository.saveInputs, hasLength(1));
      expect(repository.saveInputs.single.lines.single.unitCost, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Full external supplier saves without supplier name or reason', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _ArrangementRepository();
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          canManageCommercialsProvider.overrideWithValue(false),
          canViewCommercialsProvider.overrideWithValue(false),
          yorksV1ArrangementRepositoryProvider.overrideWithValue(repository),
          yorksV1ArrangementWorkspaceProvider(
            'request-1',
          ).overrideWith((ref) async => _externalSupplierWorkspace),
          yorksV1ArrangementInventoryProvider.overrideWith(
            (ref) async => const [],
          ),
        ],
        child: const MaterialApp(
          home: YorksV1ArrangementScreen(
            requestId: 'request-1',
            embedded: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add supplier details (optional)'), findsOneWidget);
    expect(find.text('Supplier name optional'), findsNothing);
    expect(
      find.byKey(const ValueKey('reason-arrangement-line-2-full')),
      findsNothing,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/r35/arrange_external_supplier_optional_desktop.png',
      ),
    );
    await tester.tap(find.text('Save arrangement'));
    await tester.pumpAndSettle();

    expect(repository.saveInputs, hasLength(1));
    final line = repository.saveInputs.single.lines.single;
    expect(line.source, YorksV1ArrangementSource.externalSupplier);
    expect(line.decision, YorksV1ArrangementDecision.full);
    expect(line.externalSupplier, isNull);
    expect(line.reason, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('external readiness remains complete and usable at 360px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _ArrangementRepository();
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          canManageCommercialsProvider.overrideWithValue(false),
          canViewCommercialsProvider.overrideWithValue(false),
          yorksV1ArrangementRepositoryProvider.overrideWithValue(repository),
          yorksV1ArrangementWorkspaceProvider(
            'request-1',
          ).overrideWith((ref) async => _externalSupplierWorkspace),
          yorksV1ArrangementInventoryProvider.overrideWith(
            (ref) async => const [],
          ),
        ],
        child: const MaterialApp(
          home: YorksV1ArrangementScreen(
            requestId: 'request-1',
            embedded: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ready = find.byKey(
      const ValueKey('external-ready-arrangement-line-2'),
    );
    final expectedDate = find.byKey(
      const ValueKey('external-expected-arrangement-line-2'),
    );
    final reference = find.byKey(
      const ValueKey('external-reference-arrangement-line-2'),
    );
    expect(ready, findsOneWidget);
    expect(expectedDate, findsOneWidget);
    expect(reference, findsOneWidget);

    await tester.ensureVisible(ready);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/r35/arrange_external_readiness_mobile_360.png',
      ),
    );
    await tester.tap(ready);
    await tester.ensureVisible(expectedDate);
    await tester.enterText(expectedDate, '2026-09-01');
    await tester.ensureVisible(reference);
    await tester.enterText(reference, 'QUOTE-2026-91');
    final save = find.text('Save arrangement');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.saveInputs, hasLength(1));
    final line = repository.saveInputs.single.lines.single;
    expect(line.externalSourceReady, isTrue);
    expect(line.externalExpectedDate, '2026-09-01');
    expect(line.externalReference, 'QUOTE-2026-91');
    expect(tester.takeException(), isNull);
  });

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
          canManageCommercialsProvider.overrideWithValue(true),
          canViewCommercialsProvider.overrideWithValue(true),
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

    expect(find.text('Arrange requested items'), findsOneWidget);
    expect(find.text('Start arrangement'), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/arrange_material_request_mobile.png'),
    );
  });

  testWidgets(
    'warehouse source ranks inventory matches and retains the selected item',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _ArrangementRepository();
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            canManageCommercialsProvider.overrideWithValue(true),
            canViewCommercialsProvider.overrideWithValue(true),
            yorksV1ArrangementRepositoryProvider.overrideWithValue(repository),
            yorksV1ArrangementWorkspaceProvider(
              'request-1',
            ).overrideWith((ref) async => _workingWorkspace),
            yorksV1ArrangementInventoryProvider.overrideWith(
              (ref) async => _inventoryItems,
            ),
          ],
          child: const MaterialApp(
            home: YorksV1ArrangementScreen(
              requestId: 'request-1',
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final search = find.byKey(
        const ValueKey('warehouse-search-arrangement-line-1'),
      );
      expect(search, findsOneWidget);
      expect(find.text('Create inventory item'), findsOneWidget);

      await tester.tap(search);
      await tester.enterText(search, 'MSD-ALT');
      await tester.pumpAndSettle();
      await tester.tap(find.text('MSD-ALT · Motorized smoke damper alternate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save arrangement'));
      await tester.pumpAndSettle();

      expect(repository.saveInputs, hasLength(1));
      expect(
        repository.saveInputs.single.lines.single.inventoryItemId,
        'inventory-2',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'zero warehouse availability blocks save with an actionable message',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _ArrangementRepository();
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            canManageCommercialsProvider.overrideWithValue(true),
            canViewCommercialsProvider.overrideWithValue(true),
            yorksV1ArrangementRepositoryProvider.overrideWithValue(repository),
            yorksV1ArrangementWorkspaceProvider(
              'request-1',
            ).overrideWith((ref) async => _workingWorkspace),
            yorksV1ArrangementInventoryProvider.overrideWith(
              (ref) async => const [
                YorksV1InventoryItem(
                  id: 'inventory-1',
                  itemCode: 'MSD-600',
                  description: 'Motorized smoke damper',
                  unit: 'Nos',
                  onHandQuantity: '0',
                  reservedQuantity: '0',
                  availableQuantity: '0',
                  recordVersion: 2,
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: YorksV1ArrangementScreen(
              requestId: 'request-1',
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
      await tester.tap(find.text('Save arrangement'));
      await tester.pumpAndSettle();

      expect(repository.saveInputs, isEmpty);
      expect(
        find.byKey(const ValueKey('arrangement-validation-summary')),
        findsOneWidget,
      );
      expect(find.text('1 row needs attention before saving.'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(
        find.textContaining('11 Nos is arranged but only 0 Nos is available'),
        findsOneWidget,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/r35/arrange_inline_validation_desktop.png'),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a retained request reservation remains available to its replacement',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _ArrangementRepository();
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            yorksV1ArrangementRepositoryProvider.overrideWithValue(repository),
            yorksV1ArrangementWorkspaceProvider(
              'request-1',
            ).overrideWith((ref) async => _replacementWorkspace),
            yorksV1ArrangementInventoryProvider.overrideWith(
              (ref) async => const [
                YorksV1InventoryItem(
                  id: 'inventory-1',
                  description: 'Motorized smoke damper',
                  unit: 'Nos',
                  onHandQuantity: '11',
                  reservedQuantity: '11',
                  availableQuantity: '0',
                  recordVersion: 2,
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: YorksV1ArrangementScreen(
              requestId: 'request-1',
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save arrangement'));
      await tester.pumpAndSettle();

      expect(repository.saveInputs, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Procurement can create a zero-stock item from a request line without inventing a reservation',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final preferences = await SharedPreferences.getInstance();
      final inventory = _ArrangementCreationInventoryRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            canManageCommercialsProvider.overrideWithValue(true),
            canViewCommercialsProvider.overrideWithValue(true),
            yorksV1ArrangementRepositoryProvider.overrideWithValue(
              _ArrangementRepository(),
            ),
            yorksV1LogisticsRepositoryProvider.overrideWithValue(inventory),
            yorksV1ArrangementWorkspaceProvider(
              'request-1',
            ).overrideWith((ref) async => _workingWorkspace),
            yorksV1ArrangementInventoryProvider.overrideWith(
              (ref) async => _inventoryItems,
            ),
          ],
          child: const MaterialApp(
            home: YorksV1ArrangementScreen(
              requestId: 'request-1',
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('arrangement-create-inventory-arrangement-line-1'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('arrangement-new-inventory-description')),
        findsOneWidget,
      );

      final category = find.byKey(
        const ValueKey('arrangement-new-inventory-category'),
      );
      await tester.tap(category);
      await tester.enterText(category, 'Custom dampers');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create as a new parent category'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('arrangement-create-inventory-confirm')),
      );
      await tester.pumpAndSettle();

      expect(inventory.createInput, isNotNull);
      expect(inventory.createInput!.createsItem, isTrue);
      expect(inventory.createInput!.unit, 'Nos');
      expect(inventory.createInput!.newCategoryName, 'Custom Dampers');
      expect(inventory.createInput!.quantityDelta, '0');
      expect(find.text('Inventory item created'), findsOneWidget);
      expect(
        find.text(
          'The new item has no available stock. Receive physical stock before using it from Warehouse, or choose External supplier.',
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Procurement may leave category empty during catalogue reconciliation',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final preferences = await SharedPreferences.getInstance();
      final inventory = _ArrangementCreationInventoryRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            yorksV1ArrangementRepositoryProvider.overrideWithValue(
              _ArrangementRepository(),
            ),
            yorksV1LogisticsRepositoryProvider.overrideWithValue(inventory),
            yorksV1ArrangementWorkspaceProvider(
              'request-1',
            ).overrideWith((ref) async => _workingWorkspace),
            yorksV1ArrangementInventoryProvider.overrideWith(
              (ref) async => _inventoryItems,
            ),
          ],
          child: const MaterialApp(
            home: YorksV1ArrangementScreen(
              requestId: 'request-1',
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('arrangement-create-inventory-arrangement-line-1'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('arrangement-create-inventory-confirm')),
      );
      await tester.pumpAndSettle();

      expect(inventory.createInput, isNotNull);
      expect(inventory.createInput!.categoryId, isNull);
      expect(inventory.createInput!.newCategoryName, isNull);
      expect(inventory.createInput!.quantityDelta, '0');
      expect(find.text('Inventory item created'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile arrangement line keeps warehouse search usable at 360px',
    (tester) async {
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
            canManageCommercialsProvider.overrideWithValue(true),
            canViewCommercialsProvider.overrideWithValue(true),
            yorksV1ArrangementRepositoryProvider.overrideWithValue(
              _ArrangementRepository(),
            ),
            yorksV1ArrangementWorkspaceProvider(
              'request-1',
            ).overrideWith((ref) async => _workingWorkspace),
            yorksV1ArrangementInventoryProvider.overrideWith(
              (ref) async => _inventoryItems,
            ),
          ],
          child: const MaterialApp(
            home: YorksV1ArrangementScreen(requestId: 'request-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Motorized smoke damper'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('warehouse-search-arrangement-line-1')),
        findsOneWidget,
      );
      expect(find.text('Create inventory item'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/r35/arrange_material_request_mobile_line.png',
        ),
      );
    },
  );
}

const _inventoryItems = [
  YorksV1InventoryItem(
    id: 'inventory-1',
    itemCode: 'MSD-600',
    description: 'Motorized smoke damper',
    unit: 'Nos',
    onHandQuantity: '12',
    reservedQuantity: '0',
    availableQuantity: '12',
    recordVersion: 1,
  ),
  YorksV1InventoryItem(
    id: 'inventory-2',
    itemCode: 'MSD-ALT',
    description: 'Motorized smoke damper alternate',
    unit: 'Nos',
    onHandQuantity: '20',
    reservedQuantity: '0',
    availableQuantity: '20',
    recordVersion: 1,
  ),
];

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
          requestSourceKind: 'boq',
          sourceBoqGroupId: 'boq-group-1',
          sourceBoqRowId: 'boq-row-1',
          sourceBoqGroupName: 'Dampers & Fire Control',
          sourceScopeName: 'Building A',
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

final _externalSupplierWorkspace = YorksV1ArrangementWorkspace(
  requestId: 'request-1',
  requestNumber: 'YRAASDF12-MR102',
  requestState: 'arranging',
  requestRecordVersion: 2,
  canBegin: false,
  canSave: true,
  canDecide: false,
  arrangements: [
    YorksV1ProcurementArrangement(
      id: 'arrangement-2',
      version: 1,
      status: YorksV1ArrangementStatus.working,
      isCurrent: true,
      recordVersion: 1,
      startedByDisplayName: 'Procurement User',
      startedAt: DateTime.utc(2026, 8, 12),
      lines: const [
        YorksV1ArrangementLine(
          id: 'arrangement-line-2',
          requestLineId: 'request-line-2',
          displayOrder: 1,
          description: 'Cable tray hanging clamp',
          requestedQuantity: '50.0000',
          unit: 'Nos',
          source: YorksV1ArrangementSource.externalSupplier,
          decision: YorksV1ArrangementDecision.full,
          arrangedQuantity: '50.0000',
        ),
      ],
    ),
  ],
);

final _replacementWorkspace = YorksV1ArrangementWorkspace(
  requestId: 'request-1',
  requestNumber: 'YRAASDF12-MR103',
  requestState: 'arranging',
  requestRecordVersion: 4,
  canBegin: false,
  canSave: true,
  canDecide: false,
  arrangements: [
    YorksV1ProcurementArrangement(
      id: 'arrangement-3',
      version: 2,
      status: YorksV1ArrangementStatus.working,
      isCurrent: false,
      recordVersion: 1,
      startedByDisplayName: 'Procurement User',
      startedAt: DateTime.utc(2026, 8, 13),
      lines: const [
        YorksV1ArrangementLine(
          id: 'arrangement-line-3',
          requestLineId: 'request-line-1',
          displayOrder: 1,
          description: 'Motorized smoke damper',
          requestedQuantity: '11',
          unit: 'Nos',
          source: YorksV1ArrangementSource.warehouse,
          inventoryItemId: 'inventory-1',
          decision: YorksV1ArrangementDecision.full,
          arrangedQuantity: '11',
        ),
      ],
    ),
    YorksV1ProcurementArrangement(
      id: 'arrangement-1',
      version: 1,
      status: YorksV1ArrangementStatus.returned,
      isCurrent: true,
      recordVersion: 2,
      startedByDisplayName: 'Procurement User',
      startedAt: DateTime.utc(2026, 8, 12),
      lines: const [
        YorksV1ArrangementLine(
          id: 'arrangement-line-1',
          requestLineId: 'request-line-1',
          displayOrder: 1,
          description: 'Motorized smoke damper',
          requestedQuantity: '11',
          unit: 'Nos',
          source: YorksV1ArrangementSource.warehouse,
          inventoryItemId: 'inventory-1',
          decision: YorksV1ArrangementDecision.full,
          arrangedQuantity: '11',
          reservationState: 'active',
          reservedQuantity: '11',
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
      itemCode: 'MSD-600',
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

class _ArrangementCreationInventoryRepository
    implements YorksV1LogisticsRepository {
  YorksV1InventoryAdjustmentInput? createInput;

  @override
  Future<YorksV1InventoryWorkspace> getInventory({String? search}) async =>
      YorksV1InventoryWorkspace(
        items: const [],
        categories: [
          YorksV1InventoryCategory(
            id: 'category-1',
            name: 'Dampers & Fire Control',
            isSystem: true,
            isActive: true,
            recordVersion: 1,
            itemCount: 2,
            aliases: const [],
            createdByDisplayName: 'System',
            createdAt: DateTime.utc(2026, 8, 10),
          ),
        ],
      );

  @override
  Future<YorksV1LogisticsInventoryItem> adjustInventory(
    YorksV1InventoryAdjustmentInput input,
  ) async {
    createInput = input;
    return YorksV1LogisticsInventoryItem(
      id: 'created-item-1',
      itemCode: 'INV-001',
      description: input.description ?? '',
      unit: input.unit ?? 'Nos',
      isActive: true,
      onHandQuantity: '0',
      reservedQuantity: '0',
      availableQuantity: '0',
      recordVersion: 1,
    );
  }

  @override
  Future<YorksV1InventoryItemDetail> getInventoryItem(String inventoryItemId) =>
      throw UnimplementedError();

  @override
  Future<YorksV1InventoryCategory> createInventoryCategory(
    YorksV1InventoryCategoryCreationInput input,
  ) => throw UnimplementedError();

  @override
  Future<YorksV1InventoryImportResult> importInventory(
    YorksV1InventoryImportInput input,
  ) => throw UnimplementedError();

  @override
  Future<YorksV1LogisticsInventoryItem> setInventoryItemActive(
    YorksV1InventoryItemStateInput input,
  ) => throw UnimplementedError();

  @override
  Future<YorksV1LogisticsWorkspace> getWorkspace(String requestId) =>
      throw UnimplementedError();

  @override
  Future<YorksV1LogisticsWorkspace> dispatch(YorksV1DispatchInput input) =>
      throw UnimplementedError();

  @override
  Future<YorksV1LogisticsWorkspace> confirmReceipt(
    YorksV1ReceiptConfirmationInput input,
  ) => throw UnimplementedError();

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> getReturnsDocumentsWorkspace(
    String requestId,
  ) => throw UnimplementedError();

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> generateDeliveryOrder(
    YorksV1DeliveryOrderGenerationInput input,
  ) => throw UnimplementedError();

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> saveMaterialReturnDraft(
    YorksV1MaterialReturnDraftInput input,
  ) => throw UnimplementedError();

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> submitMaterialReturn(
    YorksV1MaterialReturnSubmissionInput input,
  ) => throw UnimplementedError();

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> confirmMaterialReturn(
    YorksV1MaterialReturnConfirmationInput input,
  ) => throw UnimplementedError();

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> rejectMaterialReturn(
    YorksV1MaterialReturnRejectionInput input,
  ) => throw UnimplementedError();
}
