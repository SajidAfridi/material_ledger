import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_material_request_screens.dart';
import 'package:material_ledger/shared/models/yorks_v1_logistics.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request_document.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_logistics_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    final fontLoader = FontLoader('NexusSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    await fontLoader.load();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final evidence in <({String name, Size size})>[
    (
      name: 'assigned_engineer_delivery_order_desktop.png',
      size: const Size(1366, 768),
    ),
    (
      name: 'assigned_engineer_delivery_order_mobile.png',
      size: const Size(360, 800),
    ),
  ]) {
    testWidgets('assigned Engineer Delivery Order action — ${evidence.size}', (
      tester,
    ) async {
      tester.view.physicalSize = evidence.size;
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
            yorksV1CurrentRoleProvider.overrideWithValue(
              YorksV1Role.seniorMechanicalEngineer,
            ),
            yorksV1MaterialRequestDetailProvider(
              _request.id,
            ).overrideWith((ref) async => _request),
            yorksV1MaterialRequestDocumentProvider(_request.id).overrideWith(
              (ref) async =>
                  YorksV1MaterialRequestDocumentModel.fromRequest(_request),
            ),
            yorksV1ReturnsDocumentsWorkspaceProvider(
              _request.id,
            ).overrideWith((ref) async => _workspace),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const YorksV1MaterialRequestDetailScreen(
              requestId: 'delivery-order-evidence',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Generate Delivery Order'), findsAtLeastNWidgets(1));
      expect(
        find.text('Generate Delivery Order').hitTestable(),
        findsOneWidget,
        reason:
            'The post-dispatch Delivery Order action must be immediately usable.',
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/r35/${evidence.name}'),
      );
    });
  }
}

final _request = YorksV1MaterialRequest(
  id: 'delivery-order-evidence',
  projectId: 'project-evidence',
  projectReference: 'YRA-322',
  projectName: 'Yorks Tower HVAC',
  jobContractReference: 'N-19957.2',
  scopeId: 'common',
  scopeName: 'Common / All Buildings',
  state: YorksV1MaterialRequestState.dispatched,
  recordVersion: 7,
  createdAt: DateTime.utc(2026, 8, 6),
  updatedAt: DateTime.utc(2026, 8, 6),
  timing: YorksV1MaterialRequestTiming.normal,
  requestNumber: 'YRA322-MR001',
  title: 'Site delivery materials',
  requesterDisplayName: 'Assigned Project Engineer',
  requesterProjectRole: 'Project Engineer',
  currentActionOwnerRole: 'Project Engineer',
  currentActionCode: 'receipt_review',
  lines: const [
    YorksV1MaterialRequestLine(
      id: 'line-evidence',
      displayOrder: 1,
      source: YorksV1MaterialRequestLineSource.custom,
      description: 'Insulated ductwork',
      brandOrigin: 'Yorks',
      quantity: '21',
      unit: 'Nos',
    ),
  ],
);

final _workspace = YorksV1ReturnsDocumentsWorkspace(
  requestId: _request.id,
  projectId: _request.projectId,
  requestNumber: _request.requestNumber!,
  requestState: 'dispatched',
  requestRecordVersion: _request.recordVersion,
  projectName: _request.projectName,
  projectReference: _request.projectReference,
  jobContractReference: _request.jobContractReference,
  scopeName: _request.scopeName,
  scopeCode: 'B-01',
  canGenerateDeliveryOrder: true,
  canSubmitMaterialReturn: false,
  canConfirmMaterialReturn: false,
  deliveryOrderDispatches: [
    YorksV1DeliveryOrderDispatch(
      dispatchId: 'dispatch-evidence',
      dispatchNumber: 'YRA322-DSP001',
      dispatchDate: DateTime.utc(2026, 8, 6),
      dispatchRecordVersion: 3,
      canGenerate: true,
    ),
  ],
  returnCandidates: const [],
  materialReturns: const [],
  returnInventoryItems: const [],
);
