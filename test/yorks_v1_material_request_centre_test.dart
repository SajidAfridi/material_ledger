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
    expect(
      find.byKey(const ValueKey('material-request-row-mr-322-closed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('material-request-project-project-322')),
      findsNothing,
    );
    expect(find.text('Total Material Requests'), findsOneWidget);
    expect(find.textContaining('YRA-322'), findsWidgets);
    expect(find.textContaining('YRA-314'), findsWidgets);
    expect(find.textContaining('YRA-313'), findsWidgets);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/mr_centre_desktop.png'),
    );

    await tester.tap(
      find.byKey(const ValueKey('material-request-centre-filter-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Apply filters'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/mr_centre_desktop_filters.png'),
    );
    await tester.tap(
      find.byKey(const ValueKey('material-request-centre-apply-filters')).last,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('material-request-centre-create')),
    );
    expect(created, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('material-request-centre-view-projects')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('material-request-project-arrow-project-322')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('material-request-project-contents-project-322'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('material-request-row-mr-322-closed')),
      findsOneWidget,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/mr_centre_desktop_expanded.png'),
    );
    expect(openedRequestId, isNull);

    await tester.tap(
      find.byKey(const ValueKey('material-request-row-mr-322-closed')),
    );
    expect(openedRequestId, 'mr-322-closed');

    await tester.enterText(
      find.byKey(const ValueKey('material-request-centre-search')),
      'Electrical',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('material-request-project-project-314')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('material-request-project-project-314')),
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

  testWidgets('compact centre keeps filters and closed requests usable', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    String? openedRequestId;
    await _pump(tester, onOpen: (request) => openedRequestId = request.id);

    expect(find.text('Material Request Centre'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('material-request-centre-filter-button')),
      findsOneWidget,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/mr_centre_mobile_390.png'),
    );
    await tester.tap(
      find.byKey(const ValueKey('material-request-centre-filter-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Apply filters'), findsOneWidget);

    final applyFilters = find
        .byKey(const ValueKey('material-request-centre-apply-filters'))
        .at(0);
    await tester.ensureVisible(applyFilters);
    await tester.pumpAndSettle();
    await tester.tap(applyFilters);
    await tester.pumpAndSettle();

    final closedMetric = find
        .byKey(const ValueKey('material-request-metric-closed'))
        .at(0);
    await tester.ensureVisible(closedMetric);
    await tester.pumpAndSettle();
    await tester.tap(closedMetric);
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

  testWidgets('All Requests uses fifteen-row pages', (tester) async {
    await _setViewport(tester, const Size(1280, 3200));
    final requests = List.generate(
      16,
      (index) => _request(
        id: 'mr-page-$index',
        projectId: 'project-page-${index % 3}',
        reference: 'YRA-${320 + index % 3}',
        projectName: 'Project ${index + 1}',
        number: 'YRA-${320 + index % 3}-MR${index + 1}',
        title: 'Material request ${index + 1}',
        scope: 'Common / All Buildings',
        state: YorksV1MaterialRequestState.submitted,
        updatedAt: DateTime.utc(2026, 8, 20).subtract(Duration(minutes: index)),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
          body: YorksV1MaterialRequestCentre(
            requests: requests,
            language: AppLanguage.english,
            canCreate: true,
            onCreate: () {},
            onOpen: (_) {},
            onRefresh: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1–15 / 16'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('material-request-row-mr-page-14')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('material-request-row-mr-page-15')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('material-request-centre-page-next')),
    );
    await tester.pumpAndSettle();
    expect(find.text('16–16 / 16'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('material-request-row-mr-page-15')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary metrics return to latest all-request rows', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1280, 1100));
    await _pump(tester);

    await tester.tap(
      find.byKey(const ValueKey('material-request-centre-view-projects')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('material-request-project-project-322')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('material-request-metric-all')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('material-request-project-project-322')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('material-request-row-mr-322-closed')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('material-request-row-mr-322-closed')),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                const ValueKey('material-request-row-mr-314-dispatched'),
              ),
            )
            .dy,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'attention filter and activity sort update the folder hierarchy',
    (tester) async {
      await _setViewport(tester, const Size(1280, 1100));
      await _pump(tester);

      await tester.tap(
        find.byKey(const ValueKey('material-request-centre-filter-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('material-request-filter-attention')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .byKey(const ValueKey('material-request-centre-apply-filters'))
            .last,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('material-request-centre-view-projects')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('material-request-project-project-322')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('material-request-row-mr-322-approval')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('material-request-row-mr-322-closed')),
        findsNothing,
      );

      await tester.tap(find.text('Latest Activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oldest Activity').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .getTopLeft(
              find.byKey(
                const ValueKey('material-request-project-project-313'),
              ),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(
                  const ValueKey('material-request-project-project-322'),
                ),
              )
              .dy,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow centre defaults to all requests and expands projects', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    await _pump(tester);

    expect(
      find.byKey(const ValueKey('material-request-row-mr-322-closed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('material-request-project-project-322')),
      findsNothing,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/mr_centre_mobile_360.png'),
    );
    await tester.tap(
      find.byKey(const ValueKey('material-request-centre-view-projects')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('material-request-project-project-322')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('material-request-row-mr-322-closed')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('server summary loader pages fifteen rows without full detail', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1280, 3000));
    final queries = <YorksV1MaterialRequestSummaryQuery>[];
    Future<YorksV1MaterialRequestSummaryPage> load(
      YorksV1MaterialRequestSummaryQuery query,
    ) async {
      queries.add(query);
      final remaining = 16 - query.offset;
      final count = remaining.clamp(0, query.limit);
      return YorksV1MaterialRequestSummaryPage(
        items: List.generate(
          count,
          (index) => _summary(
            index: query.offset + index,
            updatedAt: DateTime.utc(
              2026,
              8,
              21,
            ).subtract(Duration(minutes: query.offset + index)),
          ),
        ),
        totalCount: 16,
        limit: query.limit,
        offset: query.offset,
        hasMore: query.offset + count < 16,
        metrics: const YorksV1MaterialRequestSummaryMetrics(
          total: 16,
          open: 16,
          inProgress: 0,
          dispatched: 0,
          received: 0,
          closed: 0,
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
          body: YorksV1MaterialRequestCentre(
            requests: const [],
            language: AppLanguage.english,
            canCreate: true,
            onCreate: () {},
            onOpen: (_) {},
            onRefresh: () {},
            summaryPageLoader: load,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(queries.single.limit, 15);
    expect(queries.single.offset, 0);
    expect(find.text('1–15 / 16'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('material-request-row-server-summary-14')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('material-request-row-server-summary-15')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('material-request-centre-page-next')),
    );
    await tester.pumpAndSettle();
    expect(queries.last.offset, 15);
    expect(find.text('16–16 / 16'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('material-request-row-server-summary-15')),
      findsOneWidget,
    );
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

YorksV1MaterialRequestSummary _summary({
  required int index,
  required DateTime updatedAt,
}) => YorksV1MaterialRequestSummary(
  id: 'server-summary-$index',
  projectId: 'server-project-${index % 2}',
  projectReference: 'YRA-${330 + index % 2}',
  projectName: 'Server project ${index % 2}',
  scopeId: 'server-scope-${index % 2}',
  scopeName: 'Common / All Buildings',
  state: YorksV1MaterialRequestState.submitted,
  recordVersion: 1,
  requestNumber: 'YRA-MR-${index + 1}',
  title: 'Server summary ${index + 1}',
  timing: YorksV1MaterialRequestTiming.normal,
  itemCount: index + 1,
  createdAt: updatedAt,
  updatedAt: updatedAt,
  workAssignment: YorksV1MaterialRequestWorkAssignment(
    requestId: 'server-summary-$index',
    assignmentVersion: 0,
    canManage: true,
  ),
);

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
