import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_material_request_centre.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';

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

  testWidgets('desktop centre groups, searches and opens server requests', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 1024));
    String? openedRequestId;
    var created = false;
    await _pump(
      tester,
      onOpen: (request) => openedRequestId = request.id,
      onCreate: () => created = true,
    );

    expect(
      find.byKey(const ValueKey('material-request-centre')),
      findsOneWidget,
    );
    expect(find.text('Material Request Centre'), findsOneWidget);
    expect(find.text('Project Folders'), findsOneWidget);
    expect(find.text('Total Requests'), findsWidgets);
    expect(find.text('YRA-322'), findsOneWidget);
    expect(find.text('YRA-314'), findsOneWidget);
    expect(find.text('YRA-313'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/mr_centre_desktop.png'),
    );

    await tester.tap(
      find.byKey(const ValueKey('material-request-centre-create')),
    );
    expect(created, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('material-request-project-project-322')),
    );
    expect(openedRequestId, 'mr-322-closed');

    await tester.tap(find.text('All Requests'));
    await tester.pumpAndSettle();
    expect(find.text('YRA-322-MR004'), findsWidgets);
    expect(find.text('YRA-314-MR006'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('material-request-centre-search')),
      'Electrical',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('material-request-row-mr-314-dispatched')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('material-request-row-mr-322-closed')),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('compact centre keeps filters, archive and actions usable', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    String? openedRequestId;
    await _pump(tester, onOpen: (request) => openedRequestId = request.id);

    expect(find.text('Material Request Centre'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('material-request-centre-filter-expansion')),
      findsOneWidget,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/mr_centre_mobile_390.png'),
    );
    await tester.tap(
      find.byKey(const ValueKey('material-request-centre-filter-expansion')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Apply filters'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Closed Archive'), 260);
    await tester.tap(find.text('Closed Archive'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('material-request-row-mr-322-closed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('material-request-row-mr-314-dispatched')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('material-request-row-mr-322-closed')),
    );
    expect(openedRequestId, 'mr-322-closed');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  ValueChanged<YorksV1MaterialRequest>? onOpen,
  VoidCallback? onCreate,
}) => tester.pumpWidget(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: Scaffold(
      body: YorksV1MaterialRequestCentre(
        requests: _requests,
        language: AppLanguage.english,
        canCreate: true,
        onCreate: onCreate ?? () {},
        onRefresh: () {},
        onOpen: onOpen ?? (_) {},
      ),
    ),
  ),
);

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

final _requests = <YorksV1MaterialRequest>[
  _request(
    id: 'mr-322-closed',
    projectId: 'project-322',
    reference: 'YRA-322',
    projectName: 'N-19957.2 Project Nexus (Power)',
    number: 'YRA-322-MR004',
    title: 'Bulk transmission materials',
    scope: 'DF6W · 132/33kV Substation',
    state: YorksV1MaterialRequestState.closed,
    updatedAt: DateTime.utc(2026, 8, 20, 9),
  ),
  _request(
    id: 'mr-322-approval',
    projectId: 'project-322',
    reference: 'YRA-322',
    projectName: 'N-19957.2 Project Nexus (Power)',
    number: 'YRA-322-MR005',
    title: 'Chilled water accessories',
    scope: 'Common / All Buildings',
    state: YorksV1MaterialRequestState.awaitingRequestApproval,
    updatedAt: DateTime.utc(2026, 8, 20, 8),
    action: 'engineering_approval_required',
  ),
  _request(
    id: 'mr-314-dispatched',
    projectId: 'project-314',
    reference: 'YRA-314',
    projectName: 'Independent Subsea HVDC System Project',
    number: 'YRA-314-MR006',
    title: 'Electrical',
    scope: 'Common / All Buildings',
    state: YorksV1MaterialRequestState.dispatched,
    updatedAt: DateTime.utc(2026, 8, 19, 9),
    action: 'receipt_review_required',
  ),
  _request(
    id: 'mr-313-received',
    projectId: 'project-313',
    reference: 'YRA-313',
    projectName: 'Duct work',
    number: 'YRA-313-MR016',
    title: 'Duct work',
    scope: 'Common / All Buildings',
    state: YorksV1MaterialRequestState.received,
    updatedAt: DateTime.utc(2026, 8, 18, 9),
    action: 'close_request',
  ),
];

YorksV1MaterialRequest _request({
  required String id,
  required String projectId,
  required String reference,
  required String projectName,
  required String number,
  required String title,
  required String scope,
  required YorksV1MaterialRequestState state,
  required DateTime updatedAt,
  String? action,
}) => YorksV1MaterialRequest(
  id: id,
  projectId: projectId,
  projectReference: reference,
  projectName: projectName,
  scopeId: '$projectId-$scope',
  scopeName: scope,
  state: state,
  recordVersion: 1,
  createdAt: updatedAt.subtract(const Duration(days: 1)),
  updatedAt: updatedAt,
  timing: YorksV1MaterialRequestTiming.normal,
  requestNumber: number,
  title: title,
  requesterDisplayName: 'Faisal Ahmed',
  requesterProjectRole: 'Project Engineer',
  currentActionCode: action,
  lines: const [
    YorksV1MaterialRequestLine(
      id: 'line',
      displayOrder: 1,
      source: YorksV1MaterialRequestLineSource.custom,
      description: 'Controlled material',
      quantity: '1',
      unit: 'Nos',
    ),
  ],
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
