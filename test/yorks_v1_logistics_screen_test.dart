import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_inventory_screen.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_logistics_screen.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_returns_documents_screen.dart';
import 'package:material_ledger/shared/models/yorks_v1_logistics.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_configuration_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_logistics_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_logistics_repository_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_logistics_repository.dart';
import 'package:material_ledger/shared/services/yorks_v1_logistics_document_service.dart';
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

  testWidgets(
    'dispatch refreshes the Delivery Order workspace before receipt review',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      final repository = _FakeLogisticsRepository();
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _testApp(
          preferences: preferences,
          repository: repository,
          child: const _DispatchDeliveryOrderRefreshHarness(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delivery Order pending'), findsOneWidget);
      expect(repository.returnsWorkspaceCalls, 1);

      await tester.enterText(find.byType(TextField).first, 'DN-REF-001');
      final dispatchButton = find.text('Dispatch now').last;
      await tester.ensureVisible(dispatchButton);
      await tester.tap(dispatchButton);
      await tester.pumpAndSettle();

      expect(find.text('Delivery Order ready'), findsOneWidget);
      expect(repository.returnsWorkspaceCalls, greaterThanOrEqualTo(2));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets('inventory detail renders the protected movement ledger', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _testApp(preferences: preferences, child: const YorksV1InventoryScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Items'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('VAV Damper'));
    await tester.pumpAndSettle();

    expect(find.text('Stock Movements'), findsWidgets);
    expect(find.text('Opening balance'), findsOneWidget);
  });

  testWidgets(
    'Senior Mechanical Engineer inventory workspace is visibly read-only',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _testApp(
          preferences: preferences,
          exactRole: YorksV1Role.seniorMechanicalEngineer,
          child: const YorksV1InventoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add / Receive Stock'), findsNothing);
      expect(find.text('Import Inventory'), findsNothing);
      expect(find.text('Export register'), findsOneWidget);

      await tester.tap(find.text('Items'));
      await tester.pumpAndSettle();
      expect(find.text('Stock'), findsNothing);
      await tester.tap(find.textContaining('VAV Damper'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Details'), findsNothing);
      expect(find.text('Receive / Adjust'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    },
  );

  testWidgets('inventory detail edits metadata through its separate command', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final repository = _FakeLogisticsRepository();
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _testApp(
        preferences: preferences,
        repository: repository,
        child: const YorksV1InventoryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Items'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('VAV Damper'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Details'));
    await tester.pumpAndSettle();
    final descriptionField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller?.text == 'VAV Damper',
      description: 'the inventory item description field',
    );
    await tester.enterText(descriptionField, 'VAV Damper revised');
    await tester.tap(find.text('Save Item Details'));
    await tester.pumpAndSettle();

    expect(repository.metadataInput, isNotNull);
    expect(repository.metadataInput!.description, 'VAV Damper revised');
    expect(
      repository.metadataInput!.toRpcPayload().containsKey('quantity'),
      isFalse,
    );
    expect(tester.takeException(), isNull);
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
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets(
    'stale focused receipt route fails closed without opening another dispatch',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        _testApp(
          preferences: preferences,
          child: const YorksV1LogisticsScreen(
            requestId: 'receipt-focus',
            focusReceiptReview: true,
            // A stale deep link must never silently select a different
            // committed dispatch.
            focusedDispatchId: 'stale-dispatch',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('This record changed. Refresh it before trying again.'),
        findsOneWidget,
      );
      expect(find.text('Review delivered materials'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets(
    'stale focused Delivery Order route fails closed without another dispatch',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        _testApp(
          preferences: preferences,
          child: const YorksV1ReturnsDocumentsScreen(
            requestId: 'delivery-focus',
            focusDeliveryOrder: true,
            // Likewise, a stale focus must not open a different committed
            // dispatch's controlled document.
            focusedDispatchId: 'stale-dispatch',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('This record changed. Refresh it before trying again.'),
        findsOneWidget,
      );
      expect(find.text('Delivery Order reference'), findsNothing);
      expect(find.text('Material returns'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets(
    'Delivery Order output retry reuses the server-confirmed revision',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      final repository = _DeliveryOrderRetryRepository();
      final documents = _LostOutputDocuments();
      final initial = _postDispatchDeliveryWorkspace('delivery-output-retry');
      final dispatch = initial.deliveryOrderDispatches.single;

      await tester.pumpWidget(
        _testApp(
          preferences: preferences,
          repository: repository,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showYorksV1DeliveryOrderGenerationDialog(
                    context,
                    workspace: initial,
                    dispatch: dispatch,
                    documents: documents,
                  ),
                  child: const Text('Open Delivery Order'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Delivery Order'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'DO-RETRY-001');

      await tester.tap(find.text('Download PDF'));
      await tester.pumpAndSettle();
      expect(repository.generationCalls, 1);
      expect(documents.shareAttempts, 1);
      expect(find.text('Delivery Order reference'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));

      await tester.tap(find.text('Download PDF'));
      await tester.pumpAndSettle();
      expect(repository.generationCalls, 1);
      expect(documents.shareAttempts, 2);
      expect(find.text('Delivery Order reference'), findsNothing);
    },
  );
}

Widget _testApp({
  required SharedPreferences preferences,
  required Widget child,
  YorksV1LogisticsRepository? repository,
  YorksV1Role exactRole = YorksV1Role.procurement,
}) => ProviderScope(
  overrides: [
    yorksV1CurrentRoleProvider.overrideWithValue(exactRole),
    sharedPreferencesProvider.overrideWithValue(preferences),
    yorksV1ConfigurationUnitCodesProvider.overrideWith(
      (ref) async => const ['Nos', 'Meter', 'Set', 'Kg', 'Ton', 'Boxes'],
    ),
    yorksV1LogisticsRepositoryProvider.overrideWithValue(
      repository ?? _FakeLogisticsRepository(),
    ),
  ],
  child: MaterialApp(home: child),
);

class _DispatchDeliveryOrderRefreshHarness extends ConsumerWidget {
  const _DispatchDeliveryOrderRefreshHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(
      yorksV1ReturnsDocumentsWorkspaceProvider('request-1'),
    );
    final deliveryOrderReady =
        workspace.valueOrNull?.deliveryOrderDispatches.any(
          (dispatch) => dispatch.canGenerate,
        ) ??
        false;
    return Scaffold(
      body: Column(
        children: [
          Text(
            deliveryOrderReady
                ? 'Delivery Order ready'
                : 'Delivery Order pending',
          ),
          Expanded(child: YorksV1LogisticsScreen(requestId: 'request-1')),
        ],
      ),
    );
  }
}

class _FakeLogisticsRepository
    implements
        YorksV1LogisticsRepository,
        YorksV1InventoryItemMetadataRepository {
  YorksV1InventoryItemMetadataInput? metadataInput;
  bool _dispatchCommitted = false;
  int returnsWorkspaceCalls = 0;

  @override
  Future<List<YorksV1ProjectMaterialMovement>> getProjectMaterialMovements(
    String projectId,
  ) async => const [];

  @override
  Future<YorksV1InventoryWorkspace> getInventory({String? search}) async =>
      YorksV1InventoryWorkspace(
        items: [_item],
        categories: [
          YorksV1InventoryCategory(
            id: 'category-1',
            name: 'Dampers & Fire Control',
            isSystem: true,
            isActive: true,
            recordVersion: 1,
            itemCount: 1,
            aliases: [],
            createdByDisplayName: 'System',
            createdAt: DateTime.utc(2026, 8, 10),
          ),
        ],
      );

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
  Future<YorksV1LogisticsInventoryItem> updateInventoryItemMetadata(
    YorksV1InventoryItemMetadataInput input,
  ) async {
    metadataInput = input;
    return _item;
  }

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
  ) async => _item;

  @override
  Future<YorksV1LogisticsWorkspace> getWorkspace(String requestId) async {
    if (requestId == 'receipt-focus') return _receiptFocusWorkspace;
    if (_dispatchCommitted) return _postDispatchLogisticsWorkspace(requestId);
    return YorksV1LogisticsWorkspace(
      requestId: requestId,
      projectId: 'project-1',
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
  }

  @override
  Future<YorksV1LogisticsWorkspace> dispatch(YorksV1DispatchInput input) async {
    _dispatchCommitted = true;
    return getWorkspace(input.requestId);
  }

  @override
  Future<YorksV1LogisticsWorkspace> confirmReceipt(
    YorksV1ReceiptConfirmationInput input,
  ) => getWorkspace(input.requestId);

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> getReturnsDocumentsWorkspace(
    String requestId,
  ) async {
    returnsWorkspaceCalls++;
    if (requestId == 'delivery-focus') return _deliveryFocusWorkspace;
    return _dispatchCommitted
        ? _postDispatchDeliveryWorkspace(requestId)
        : _returnsWorkspace(requestId);
  }

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> generateDeliveryOrder(
    YorksV1DeliveryOrderGenerationInput input,
  ) async => input.requestId == 'delivery-focus'
      ? _deliveryFocusWorkspace
      : _returnsWorkspace(input.requestId);

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

class _DeliveryOrderRetryRepository extends _FakeLogisticsRepository {
  int generationCalls = 0;

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> generateDeliveryOrder(
    YorksV1DeliveryOrderGenerationInput input,
  ) async {
    generationCalls++;
    return _confirmedDeliveryOrderWorkspace(input.requestId);
  }
}

class _LostOutputDocuments extends YorksV1LogisticsDocumentService {
  int shareAttempts = 0;

  @override
  Future<void> shareDeliveryOrderPdf({
    required YorksV1ReturnsDocumentsWorkspace workspace,
    required YorksV1DeliveryOrderDispatch dispatch,
    required YorksV1DeliveryOrderRevision revision,
  }) async {
    shareAttempts++;
    if (shareAttempts == 1) {
      throw StateError('Local output channel unavailable.');
    }
  }
}

YorksV1ReturnsDocumentsWorkspace _returnsWorkspace(String requestId) =>
    YorksV1ReturnsDocumentsWorkspace(
      requestId: requestId,
      projectId: 'project-1',
      requestNumber: 'Y-001-MR001',
      requestState: 'received',
      requestRecordVersion: 1,
      projectName: 'Yorks Project',
      projectReference: 'Y-001',
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

YorksV1LogisticsWorkspace _postDispatchLogisticsWorkspace(String requestId) =>
    YorksV1LogisticsWorkspace(
      requestId: requestId,
      projectId: 'project-1',
      requestNumber: 'Y-001-MR001',
      requestState: 'dispatched',
      requestRecordVersion: 6,
      projectName: 'Yorks Project',
      scopeName: 'Building A',
      canDispatch: false,
      canConfirmReceipt: true,
      dispatchCandidates: const [],
      dispatches: [
        YorksV1MaterialDispatch(
          id: 'dispatch-after-commit',
          number: 'Y-001-DSP001',
          dispatchDate: DateTime.utc(2026, 8, 10),
          state: YorksV1DispatchState.receiptPending,
          recordVersion: 1,
          dispatchedByDisplayName: 'Procurement User',
          dispatchedAt: DateTime.utc(2026, 8, 10),
          canConfirmReceipt: true,
          lines: const [],
        ),
      ],
    );

YorksV1ReturnsDocumentsWorkspace _postDispatchDeliveryWorkspace(
  String requestId,
) => YorksV1ReturnsDocumentsWorkspace(
  requestId: requestId,
  projectId: 'project-1',
  requestNumber: 'Y-001-MR001',
  requestState: 'dispatched',
  requestRecordVersion: 6,
  projectName: 'Yorks Project',
  projectReference: 'Y-001',
  scopeName: 'Building A',
  canGenerateDeliveryOrder: true,
  canSubmitMaterialReturn: false,
  canConfirmMaterialReturn: false,
  deliveryOrderDispatches: [
    YorksV1DeliveryOrderDispatch(
      dispatchId: 'dispatch-after-commit',
      dispatchNumber: 'Y-001-DSP001',
      dispatchDate: DateTime.utc(2026, 8, 10),
      dispatchRecordVersion: 1,
      canGenerate: true,
    ),
  ],
  returnCandidates: const [],
  materialReturns: const [],
  returnInventoryItems: const [],
);

YorksV1ReturnsDocumentsWorkspace _confirmedDeliveryOrderWorkspace(
  String requestId,
) => YorksV1ReturnsDocumentsWorkspace(
  requestId: requestId,
  projectId: 'project-1',
  requestNumber: 'Y-001-MR001',
  requestState: 'dispatched',
  requestRecordVersion: 6,
  projectName: 'Yorks Project',
  projectReference: 'Y-001',
  scopeName: 'Building A',
  canGenerateDeliveryOrder: true,
  canSubmitMaterialReturn: false,
  canConfirmMaterialReturn: false,
  deliveryOrderDispatches: [
    YorksV1DeliveryOrderDispatch(
      dispatchId: 'dispatch-after-commit',
      dispatchNumber: 'Y-001-DSP001',
      dispatchDate: DateTime.utc(2026, 8, 10),
      dispatchRecordVersion: 1,
      canGenerate: true,
      deliveryOrder: YorksV1DeliveryOrder(
        id: 'delivery-order-1',
        dispatchId: 'dispatch-after-commit',
        reference: 'DO-RETRY-001',
        recordVersion: 1,
        currentRevisionId: 'revision-1',
        revisions: [
          YorksV1DeliveryOrderRevision(
            id: 'revision-1',
            revisionNumber: 1,
            isCurrent: true,
            generatedAt: DateTime.utc(2026, 8, 10),
            generatedByDisplayName: 'Project Engineer',
            lines: const [
              YorksV1DeliveryOrderLine(
                serialNumber: 1,
                description: 'VAV Damper',
                quantity: '4',
                unit: 'Nos',
              ),
            ],
          ),
        ],
      ),
    ),
  ],
  returnCandidates: const [],
  materialReturns: const [],
  returnInventoryItems: const [],
);

const _item = YorksV1LogisticsInventoryItem(
  id: 'inventory-1',
  itemCode: 'VAV-001',
  description: 'VAV Damper',
  categoryId: 'category-1',
  categoryName: 'Dampers & Fire Control',
  brandOrigin: 'UAE',
  unit: 'Nos',
  isActive: true,
  onHandQuantity: '5',
  reservedQuantity: '1',
  availableQuantity: '4',
  recordVersion: 2,
  metadataRecordVersion: 1,
  movementCount: 1,
);

final _receiptFocusWorkspace = YorksV1LogisticsWorkspace(
  requestId: 'receipt-focus',
  projectId: 'project-1',
  requestNumber: 'Y-001-MR001',
  requestState: 'dispatched',
  requestRecordVersion: 5,
  projectName: 'Yorks Project',
  scopeName: 'Building A',
  canDispatch: false,
  canConfirmReceipt: true,
  dispatchCandidates: const [],
  dispatches: [
    YorksV1MaterialDispatch(
      id: 'dispatch-focus',
      number: 'Y-001-DSP001',
      dispatchDate: DateTime.utc(2026, 8, 5),
      state: YorksV1DispatchState.receiptPending,
      recordVersion: 3,
      dispatchedByDisplayName: 'Procurement User',
      dispatchedAt: DateTime.utc(2026, 8, 5),
      canConfirmReceipt: true,
      deliveryReference: 'DN-001',
      lines: const [
        YorksV1DispatchLine(
          id: 'dispatch-line-focus',
          requestLineId: 'request-line-focus',
          description: 'Focus damper',
          unit: 'Nos',
          source: YorksV1LogisticsSource.warehouse,
          dispatchedQuantity: '1',
          approvedQuantity: '1',
        ),
      ],
    ),
  ],
);

final _deliveryFocusWorkspace = YorksV1ReturnsDocumentsWorkspace(
  requestId: 'delivery-focus',
  projectId: 'project-1',
  requestNumber: 'Y-001-MR001',
  requestState: 'received',
  requestRecordVersion: 2,
  projectName: 'Yorks Project',
  projectReference: 'Y-001',
  scopeName: 'Building A',
  canGenerateDeliveryOrder: true,
  canSubmitMaterialReturn: false,
  canConfirmMaterialReturn: false,
  deliveryOrderDispatches: [
    YorksV1DeliveryOrderDispatch(
      dispatchId: 'dispatch-delivery',
      dispatchNumber: 'Y-001-DSP001',
      dispatchDate: DateTime.utc(2026, 8, 5),
      dispatchRecordVersion: 3,
      canGenerate: true,
      receiptReviewedAt: DateTime.utc(2026, 8, 5),
    ),
  ],
  returnCandidates: const [],
  materialReturns: const [],
  returnInventoryItems: const [],
);
