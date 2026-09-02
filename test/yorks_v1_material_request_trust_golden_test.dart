import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_material_request_screens.dart';
import 'package:material_ledger/shared/models/yorks_v1_arrangement.dart';
import 'package:material_ledger/shared/models/yorks_v1_logistics.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request_document.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_arrangement_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_logistics_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_permission_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/yorks_v1_permission_test_support.dart';

late SharedPreferences _preferences;

void main() {
  setUpAll(() async {
    final nexusFontLoader = FontLoader('NexusSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final arabicFontLoader = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    final flutterCache = _flutterCacheDirectory();
    final iconBytes = await File(
      '${flutterCache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final iconFontLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(iconBytes)));
    await Future.wait([
      nexusFontLoader.load(),
      arabicFontLoader.load(),
      iconFontLoader.load(),
    ]);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _preferences = await SharedPreferences.getInstance();
  });

  for (final evidence in [
    (suffix: '1366x768', size: const Size(1366, 768)),
    (suffix: '390x844', size: const Size(390, 844)),
    (suffix: '360x800', size: const Size(360, 800)),
  ]) {
    testWidgets('partial dispatch trust evidence ${evidence.suffix}', (
      tester,
    ) async {
      await _pump(
        tester,
        size: evidence.size,
        request: _partialDispatchRequest,
        document: _partialDispatchDocument,
      );

      if (evidence.size.width < 600) {
        expect(find.textContaining('Awaiting receipt review'), findsWidgets);
        expect(find.text('Dispatched'), findsWidgets);
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/r35/trust/mr_partial_dispatch_${evidence.suffix}.png',
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing receipt trust evidence ${evidence.suffix}', (
      tester,
    ) async {
      await _pump(
        tester,
        size: evidence.size,
        request: _reviewedRequest,
        document: _reviewedDocument,
      );

      if (evidence.size.width < 600) {
        expect(find.textContaining('Replacement required'), findsWidgets);
        expect(find.text('Good received'), findsWidgets);
        expect(find.text('Replacement remains eligible'), findsWidgets);
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/r35/trust/mr_missing_review_${evidence.suffix}.png',
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required YorksV1MaterialRequest request,
  required YorksV1MaterialRequestDocumentModel document,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: size.width < 600 ? 26 : 0);
  tester.view.viewPadding = FakeViewPadding(top: size.width < 600 ? 26 : 0);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewPadding();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_preferences),
        yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.procurement),
        yorksV1CurrentPermissionSnapshotProvider.overrideWith(
          (ref) => YorksV1TestPermissionController(
            yorksV1TrustedFeaturePermissionState(role: YorksV1Role.procurement),
          ),
        ),
        yorksV1MaterialRequestDetailProvider(
          request.id,
        ).overrideWith((ref) async => request),
        yorksV1MaterialRequestDocumentProvider(
          request.id,
        ).overrideWith((ref) async => document),
        yorksV1ArrangementWorkspaceProvider(
          request.id,
        ).overrideWith((ref) async => _arrangementWorkspace(request)),
        yorksV1LogisticsWorkspaceProvider(
          request.id,
        ).overrideWith((ref) async => _logisticsWorkspace(request)),
        yorksV1ReturnsDocumentsWorkspaceProvider(
          request.id,
        ).overrideWith((ref) async => _returnsWorkspace(request)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: YorksV1MaterialRequestDetailScreen(requestId: request.id),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  if (size.width < 600) {
    await tester.tap(find.text('Full details'));
    await tester.pumpAndSettle();
  }
}

YorksV1ArrangementWorkspace _arrangementWorkspace(
  YorksV1MaterialRequest request,
) => YorksV1ArrangementWorkspace(
  requestId: request.id,
  requestNumber: request.requestNumber ?? '',
  requestState: request.state.wireValue,
  requestRecordVersion: request.recordVersion,
  canBegin: false,
  canSave: false,
  canDecide: false,
  arrangements: const [],
);

YorksV1LogisticsWorkspace _logisticsWorkspace(YorksV1MaterialRequest request) =>
    YorksV1LogisticsWorkspace(
      requestId: request.id,
      projectId: request.projectId,
      requestNumber: request.requestNumber ?? '',
      requestState: request.state.wireValue,
      requestRecordVersion: request.recordVersion,
      projectName: request.projectName,
      scopeName: request.scopeName,
      canDispatch:
          request.state == YorksV1MaterialRequestState.partiallyReceived,
      canConfirmReceipt:
          request.state == YorksV1MaterialRequestState.partiallyDispatched,
      dispatchCandidates: const [],
      dispatches: const [],
    );

YorksV1ReturnsDocumentsWorkspace _returnsWorkspace(
  YorksV1MaterialRequest request,
) => YorksV1ReturnsDocumentsWorkspace(
  requestId: request.id,
  projectId: request.projectId,
  requestNumber: request.requestNumber ?? '',
  requestState: request.state.wireValue,
  requestRecordVersion: request.recordVersion,
  projectName: request.projectName,
  projectReference: request.projectReference,
  scopeName: request.scopeName,
  canGenerateDeliveryOrder: true,
  canSubmitMaterialReturn: false,
  canConfirmMaterialReturn: false,
  deliveryOrderDispatches: const [],
  returnCandidates: const [],
  materialReturns: const [],
  returnInventoryItems: const [],
);

YorksV1MaterialRequest _request({
  required String id,
  required YorksV1MaterialRequestState state,
  required String action,
}) => YorksV1MaterialRequest(
  id: id,
  projectId: 'project-trust',
  projectReference: 'YRA-322',
  projectName: 'Al Dhafra Grid Substation HVAC Works',
  jobContractReference: 'N-19957.2',
  scopeId: 'scope-common',
  scopeName: 'Common / All Buildings',
  state: state,
  recordVersion: 8,
  createdAt: DateTime.utc(2026, 8, 9),
  updatedAt: DateTime.utc(2026, 8, 11, 9, 30),
  submittedAt: DateTime.utc(2026, 8, 9, 8),
  timing: YorksV1MaterialRequestTiming.normal,
  requestNumber: 'YRA-322-MR101',
  title: 'Level 2 FCU materials',
  requesterDisplayName: 'Noor Zaman',
  requesterProjectRole: 'Project Engineer',
  requesterExactRole: 'senior_mechanical_engineer',
  currentActionOwnerRole: state == YorksV1MaterialRequestState.partiallyReceived
      ? 'procurement'
      : 'site_engineer',
  currentActionCode: action,
  documentIdentityVerified: true,
  lines: const [
    YorksV1MaterialRequestLine(
      id: 'line-trust',
      displayOrder: 1,
      source: YorksV1MaterialRequestLineSource.boq,
      sourceBoqGroupId: 'group-1',
      sourceBoqRowId: 'row-1',
      description: 'Motorized smoke damper',
      quantity: '10',
      unit: 'Nos',
      brandOrigin: 'Beteccad UAE',
    ),
  ],
);

final _partialDispatchRequest = _request(
  id: 'mr-partial-dispatch',
  state: YorksV1MaterialRequestState.partiallyDispatched,
  action: 'receipt_review_required',
);

final _reviewedRequest = _request(
  id: 'mr-missing-review',
  state: YorksV1MaterialRequestState.partiallyReceived,
  action: 'replacement_dispatch_required',
);

const _arrangementActor = YorksV1MaterialRequestDocumentActor(
  displayName: 'Ali Raza',
  role: 'procurement',
  reference: 'Arrangement v1',
  actedAt: null,
);

final _approvalActor = YorksV1MaterialRequestDocumentActor(
  displayName: 'Noor Zaman',
  role: 'senior_mechanical_engineer',
  reference: 'Arrangement v1',
  actedAt: DateTime.utc(2026, 8, 9, 10),
);

final _dispatchActor = YorksV1MaterialRequestDocumentActor(
  displayName: 'Ali Raza',
  role: 'procurement',
  reference: 'DN-100',
  actedAt: DateTime.utc(2026, 8, 10, 9),
);

final _partialDispatchDocument = YorksV1MaterialRequestDocumentModel(
  request: _partialDispatchRequest,
  arrangement: _arrangementActor,
  approval: _approvalActor,
  dispatch: _dispatchActor,
  showLineStatus: true,
  receiptStatuses: const {
    'line-trust':
        '10 requested · 10 arranged · 10 approved · 5 / 10 dispatched · 5 in transit · Awaiting receipt review',
  },
  lineLifecycles: const {
    'line-trust': YorksV1MaterialRequestLineLifecycle(
      requestLineId: 'line-trust',
      requestedQuantity: '10',
      arrangedQuantity: '10',
      cannotProvideQuantity: '0',
      approvedQuantity: '10',
      reservedQuantity: '5',
      dispatchedQuantity: '5',
      inTransitQuantity: '5',
      goodQuantity: '0',
      missingQuantity: '0',
      damagedQuantity: '0',
      returnedQuantity: '0',
      stillNeededQuantity: '5',
      remainingApprovedQuantity: '5',
      replacementEligibleQuantity: '0',
      ordinaryOutstandingQuantity: '5',
      status: 'Awaiting receipt review',
      arrangementDecision: 'full',
      arrangementStatus: 'approved',
      sourceKind: 'warehouse',
    ),
  },
);

final _reviewedDocument = YorksV1MaterialRequestDocumentModel(
  request: _reviewedRequest,
  arrangement: _arrangementActor,
  approval: _approvalActor,
  dispatch: _dispatchActor,
  showLineStatus: true,
  receiptStatuses: const {
    'line-trust':
        '10 requested · 10 arranged · 10 approved · 5 dispatched · 3 good · 2 missing · 7 remaining · 2 replacement · Replacement required',
  },
  lineLifecycles: const {
    'line-trust': YorksV1MaterialRequestLineLifecycle(
      requestLineId: 'line-trust',
      requestedQuantity: '10',
      arrangedQuantity: '10',
      cannotProvideQuantity: '0',
      approvedQuantity: '10',
      reservedQuantity: '5',
      dispatchedQuantity: '5',
      inTransitQuantity: '0',
      goodQuantity: '3',
      missingQuantity: '2',
      damagedQuantity: '0',
      returnedQuantity: '0',
      stillNeededQuantity: '7',
      remainingApprovedQuantity: '7',
      replacementEligibleQuantity: '2',
      ordinaryOutstandingQuantity: '5',
      status: 'Replacement required',
      arrangementDecision: 'full',
      arrangementStatus: 'approved',
      sourceKind: 'warehouse',
      arrangementReason: 'Full approved supply',
    ),
  },
);

Directory _flutterCacheDirectory() {
  var directory = File(Platform.resolvedExecutable).parent;
  for (var level = 0; level < 8; level++) {
    if (directory.path.endsWith('${Platform.pathSeparator}cache')) {
      return directory;
    }
    directory = directory.parent;
  }
  throw StateError('Could not locate the Flutter cache from the test runner');
}
