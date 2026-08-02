import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_inventory_screen.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_logistics_screen.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_returns_documents_screen.dart';
import 'package:material_ledger/shared/models/yorks_v1_logistics.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_logistics_repository_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_logistics_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('logistics editor remains usable at a 360px mobile width', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testApp(
        preferences: preferences,
        child: const YorksV1LogisticsScreen(requestId: 'request-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dispatch now'), findsWidgets);
    expect(find.text('VAV Damper'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inventory detail renders the protected movement ledger', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _testApp(preferences: preferences, child: const YorksV1InventoryScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('VAV Damper'));
    await tester.pumpAndSettle();

    expect(find.text('Movement history'), findsOneWidget);
    expect(find.text('Opening balance'), findsOneWidget);
  });

  testWidgets('return quantity uses a focused editor on a 360px mobile width', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testApp(
        preferences: preferences,
        child: const YorksV1ReturnsDocumentsScreen(requestId: 'request-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Copper pipe'), findsOneWidget);
    await tester.tap(find.text('Copper pipe'));
    await tester.pumpAndSettle();

    expect(find.text('Return quantity'), findsOneWidget);
    expect(find.text('Save return draft'), findsWidgets);
  });
}

Widget _testApp({
  required SharedPreferences preferences,
  required Widget child,
}) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(preferences),
    yorksV1LogisticsRepositoryProvider.overrideWithValue(
      _FakeLogisticsRepository(),
    ),
  ],
  child: MaterialApp(home: child),
);

class _FakeLogisticsRepository implements YorksV1LogisticsRepository {
  @override
  Future<YorksV1InventoryWorkspace> getInventory({String? search}) async =>
      YorksV1InventoryWorkspace(items: [_item]);

  @override
  Future<YorksV1InventoryItemDetail> getInventoryItem(
    String inventoryItemId,
  ) async => YorksV1InventoryItemDetail(
    item: _item,
    movements: [
      YorksV1InventoryMovement(
        id: 'movement-1',
        movementType: 'opening_balance',
        quantityDelta: '5',
        onHandAfterQuantity: '5',
        reason: 'Opening balance',
        actorDisplayName: 'Procurement User',
        createdAt: DateTime.utc(2026, 8, 2),
      ),
    ],
  );

  @override
  Future<YorksV1LogisticsInventoryItem> adjustInventory(
    YorksV1InventoryAdjustmentInput input,
  ) async => _item;

  @override
  Future<YorksV1LogisticsInventoryItem> setInventoryItemActive(
    YorksV1InventoryItemStateInput input,
  ) async => _item;

  @override
  Future<YorksV1LogisticsWorkspace> getWorkspace(String requestId) async =>
      YorksV1LogisticsWorkspace(
        requestId: requestId,
        requestNumber: 'Y-001-MR001',
        requestState: 'approved',
        requestRecordVersion: 5,
        projectName: 'Yorks Project',
        scopeName: 'Building A',
        canDispatch: true,
        canConfirmReceipt: false,
        dispatchCandidates: const [
          YorksV1DispatchCandidate(
            requestLineId: 'request-line-1',
            displayOrder: 1,
            description: 'VAV Damper',
            unit: 'Nos',
            approvedQuantity: '4',
            goodReceivedQuantity: '0',
            inTransitQuantity: '0',
            stillNeededQuantity: '4',
            source: YorksV1LogisticsSource.warehouse,
            inventoryItemId: 'inventory-1',
            reservedRemainingQuantity: '4',
            warehouseAvailableQuantity: '4',
          ),
        ],
        dispatches: const [],
      );

  @override
  Future<YorksV1LogisticsWorkspace> dispatch(YorksV1DispatchInput input) =>
      getWorkspace(input.requestId);

  @override
  Future<YorksV1LogisticsWorkspace> confirmReceipt(
    YorksV1ReceiptConfirmationInput input,
  ) => getWorkspace(input.requestId);

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> getReturnsDocumentsWorkspace(
    String requestId,
  ) async => _returnsWorkspace(requestId);

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> generateDeliveryOrder(
    YorksV1DeliveryOrderGenerationInput input,
  ) async => _returnsWorkspace(input.requestId);

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> saveMaterialReturnDraft(
    YorksV1MaterialReturnDraftInput input,
  ) async => _returnsWorkspace(input.requestId);

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> submitMaterialReturn(
    YorksV1MaterialReturnSubmissionInput input,
  ) async => _returnsWorkspace('request-1');

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> confirmMaterialReturn(
    YorksV1MaterialReturnConfirmationInput input,
  ) async => _returnsWorkspace('request-1');

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> rejectMaterialReturn(
    YorksV1MaterialReturnRejectionInput input,
  ) async => _returnsWorkspace('request-1');
}

YorksV1ReturnsDocumentsWorkspace _returnsWorkspace(String requestId) =>
    YorksV1ReturnsDocumentsWorkspace(
      requestId: requestId,
      projectId: 'project-1',
      requestNumber: 'Y-001-MR001',
      requestState: 'received',
      requestRecordVersion: 1,
      projectName: 'Yorks Project',
      scopeName: 'Building A',
      canGenerateDeliveryOrder: false,
      canSubmitMaterialReturn: true,
      canConfirmMaterialReturn: false,
      deliveryOrderDispatches: const [],
      returnCandidates: const [
        YorksV1ReturnCandidate(
          receiptReviewLineId: 'receipt-line-1',
          dispatchNumber: 'Y-001-DSP001',
          displayOrder: 1,
          description: 'Copper pipe',
          unit: 'Mtr',
          source: YorksV1LogisticsSource.warehouse,
          goodReceivedQuantity: '3',
          confirmedReturnQuantity: '0',
          eligibleReturnQuantity: '3',
        ),
      ],
      materialReturns: const [],
      returnInventoryItems: const [],
    );

const _item = YorksV1LogisticsInventoryItem(
  id: 'inventory-1',
  description: 'VAV Damper',
  brandOrigin: 'UAE',
  unit: 'Nos',
  isActive: true,
  onHandQuantity: '5',
  reservedQuantity: '1',
  availableQuantity: '4',
  recordVersion: 2,
  movementCount: 1,
);
