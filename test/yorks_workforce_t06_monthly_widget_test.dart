import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/workforce/application/workforce_monthly_period_controller.dart';
import 'package:material_ledger/features/workforce/domain/workforce_monthly_period_models.dart';
import 'package:material_ledger/features/workforce/presentation/screens/yorks_workforce_timesheets_screen.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/yorks_v1_workforce_strings.dart';

const _actorId = '10000000-0000-4000-8000-000000000001';
const _teamId = '60000000-0000-4000-8000-000000000001';
const _periodId = '61000000-0000-4000-8000-000000000001';
const _runId = '62000000-0000-4000-8000-000000000001';
const _workerId = '63000000-0000-4000-8000-000000000001';
const _fingerprint =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final nexus = FontLoader('NexusSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final arabic = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    final cache = _flutterCacheDirectory();
    final icons = await File(
      '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons)));
    await Future.wait([nexus.load(), arabic.load(), materialIcons.load()]);
  });

  testWidgets(
    'Monthly view is overflow-free at desktop and compact boundaries in English and Arabic RTL',
    (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      const viewports = <Size>[
        Size(1440, 900),
        Size(1366, 768),
        Size(1180, 820),
        Size(1024, 768),
        Size(820, 1180),
        Size(768, 1024),
        Size(430, 932),
        Size(390, 844),
        Size(360, 800),
      ];

      for (final language in const [AppLanguage.english, AppLanguage.arabic]) {
        for (final viewport in viewports) {
          await _pumpMonthly(tester, viewport: viewport, language: language);

          expect(
            find.text(
              YorksV1WorkforceStrings.text(language, 'monthly_timesheets'),
            ),
            findsOneWidget,
            reason: '${language.code} at $viewport',
          );
          final viewContext = tester.element(
            find.text(
              YorksV1WorkforceStrings.text(language, 'monthly_timesheets'),
            ),
          );
          expect(
            Directionality.of(viewContext),
            language.isRtl ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(
            find.textContaining('Submit', findRichText: true),
            findsNothing,
          );
          expect(
            find.textContaining('Approve', findRichText: true),
            findsNothing,
          );
          if (viewport.width < 720) {
            expect(
              find.text(
                YorksV1WorkforceStrings.text(
                  language,
                  'monthly_read_only_title',
                ),
              ),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('monthly-validate-button')),
              findsNothing,
            );
            expect(find.byType(DataTable), findsNothing);
            expect(
              find.byKey(const Key('workforce-tablet-monthly-worker-list')),
              findsNothing,
            );
          } else if (viewport.width < 1200) {
            expect(
              find.byKey(const Key('monthly-validate-button')),
              findsOneWidget,
            );
            expect(find.byType(DataTable), findsNothing);
            expect(
              find.byKey(const Key('workforce-tablet-monthly-worker-list')),
              findsOneWidget,
            );
            expect(
              find.byKey(
                Key(
                  viewport.width > viewport.height
                      ? 'workforce-tablet-monthly-landscape'
                      : 'workforce-tablet-monthly-portrait',
                ),
              ),
              findsOneWidget,
            );
          } else {
            expect(
              find.byKey(const Key('monthly-validate-button')),
              findsOneWidget,
            );
            expect(find.byType(DataTable), findsWidgets);
          }
          expect(
            tester.takeException(),
            isNull,
            reason: 'No Flutter overflow or render exception at $viewport',
          );
        }
      }
    },
  );

  testWidgets('Monthly acceptance viewports match deterministic goldens', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const cases = <(AppLanguage, Size, String)>[
      (AppLanguage.english, Size(1440, 900), 'en_1440x900'),
      (AppLanguage.english, Size(1366, 768), 'en_1366x768'),
      (AppLanguage.english, Size(1180, 820), 't11_en_1180x820'),
      (AppLanguage.english, Size(1024, 768), 't11_en_1024x768'),
      (AppLanguage.english, Size(820, 1180), 't11_en_820x1180'),
      (AppLanguage.english, Size(768, 1024), 't11_en_768x1024'),
      (AppLanguage.english, Size(360, 800), 'en_360x800'),
      (AppLanguage.arabic, Size(1024, 768), 't11_ar_1024x768'),
    ];

    for (final (language, viewport, suffix) in cases) {
      await _pumpMonthly(tester, viewport: viewport, language: language);
      await expectLater(
        find.byType(YorksWorkforceMonthlyView),
        matchesGoldenFile('goldens/yorks_workforce_t06_monthly_$suffix.png'),
      );
    }
  });

  testWidgets('Monthly state uses explicit icon and text status semantics', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final semantics = tester.ensureSemantics();
    await _pumpMonthly(
      tester,
      viewport: const Size(1366, 768),
      language: AppLanguage.english,
    );
    await tester.scrollUntilVisible(
      find.text('Has blocking issues'),
      420,
      scrollable: find
          .descendant(
            of: find.byKey(
              const PageStorageKey<String>('workforce-monthly-view'),
            ),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(find.byIcon(Icons.error_outline), findsWidgets);
    expect(find.text('Has blocking issues'), findsOneWidget);
    expect(find.text('Required attendance missing'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

Future<void> _pumpMonthly(
  WidgetTester tester, {
  required Size viewport,
  required AppLanguage language,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  final searchController = TextEditingController();
  addTearDown(searchController.dispose);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: YorksWorkforceMonthlyView(
        language: language,
        state: _state(),
        searchController: searchController,
        onSearchChanged: (_) {},
        onRetry: () {},
        onMonthChanged: (_) {},
        onTeamChanged: (_) {},
        onValidate: () {},
        onWorkerChanged: (_) {},
        onCloseWorker: () {},
        onDateChanged: (_) {},
        onLoadMoreWorkers: () {},
        onIssueFilter: ({severity, issueCode, workerId}) {},
        onLoadMoreIssues: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

YorksWorkforceMonthlyState _state() {
  final projection = _projection();
  return YorksWorkforceMonthlyState(
    status: YorksWorkforceMonthlyStatus.ready,
    periodMonth: '2026-08-01',
    selectedTeamId: _teamId,
    teamProjection: YorksWorkforceMonthlyTeamProjection(
      schemaVersion: 1,
      authorizationMode: 'enforced_t06',
      actorAuthUserId: _actorId,
      serverTime: '2026-08-30T09:00:00Z',
      filters: const YorksWorkforceMonthlyTeamFilters(
        periodMonth: '2026-08-01',
      ),
      totalCount: 1,
      teams: const [
        YorksWorkforceMonthlyTeam(
          id: _teamId,
          code: 'YRA-322',
          name: 'Nexus 4 Station',
          department: 'Projects',
          periodExists: true,
          periodId: _periodId,
          storedStatus: YorksWorkforceMonthlyPeriodStatus.draft,
          recordVersion: 2,
          currentValidationNumber: 2,
        ),
      ],
    ),
    filters: projection.filters,
    projection: projection,
    workerDetail: _workerDetail(projection.period!, projection.workers.single),
    selectedDate: '2026-08-20',
  );
}

YorksWorkforceMonthlyProjection _projection() {
  final period = YorksWorkforceMonthlyPeriod(
    id: _periodId,
    teamId: _teamId,
    teamName: 'YRA-322 · Nexus 4 Station',
    periodMonth: '2026-08-01',
    storedStatus: YorksWorkforceMonthlyPeriodStatus.draft,
    effectiveStatus: YorksWorkforceMonthlyPeriodStatus.draft,
    isStale: false,
    recordVersion: 2,
    currentValidationRunId: _runId,
    currentValidationNumber: 2,
    sourceFingerprint: _fingerprint,
    currentSourceFingerprint: _fingerprint,
    validatedAt: '2026-08-30T09:00:00Z',
    validatedByAuthUserId: _actorId,
  );
  final worker = YorksWorkforceMonthlyWorkerSummary(
    workerId: _workerId,
    workerNumber: 'WF-0322',
    workerName: 'Ahmed Khan',
    tradeName: 'Ductman',
    employerName: 'Yorks AC & Ref.',
    firstApplicableDate: '2026-08-01',
    lastApplicableDate: '2026-08-30',
    supervisors: const [
      YorksWorkforceMonthlySupervisor(authUserId: _actorId, name: 'Omar Khan'),
    ],
    projects: const [
      YorksWorkforceMonthlyProject(
        id: '64000000-0000-4000-8000-000000000001',
        reference: 'YRA-322',
        name: 'Nexus 4 Station',
        scopeId: '65000000-0000-4000-8000-000000000001',
        scopeName: 'Common / All Buildings',
      ),
    ],
    locations: const [],
    scheduledDayCount: 22,
    presentDayCount: 18,
    absentDayCount: 1,
    leaveDayCount: 1,
    weeklyOffDayCount: 4,
    publicHolidayDayCount: 0,
    regularMinutes: 8640,
    overtimeMinutes: 180,
    missingDayCount: 2,
    blockingIssueCount: 1,
    warningIssueCount: 1,
    status: YorksWorkforceMonthlyWorkerStatus.hasErrors,
  );
  return YorksWorkforceMonthlyProjection(
    schemaVersion: 1,
    authorizationMode: 'enforced_t06',
    actorAuthUserId: _actorId,
    serverTime: '2026-08-30T09:00:00Z',
    filters: const YorksWorkforceMonthlyFilters(
      teamId: _teamId,
      periodMonth: '2026-08-01',
    ),
    capabilities: const YorksWorkforceMonthlyCapabilities(
      canView: true,
      canValidate: true,
    ),
    period: period,
    summary: const YorksWorkforceMonthlySummary(
      workerCount: 1,
      dateCount: 30,
      scheduledDayCount: 22,
      futureDayCount: 0,
      presentDayCount: 18,
      absentDayCount: 1,
      leaveDayCount: 1,
      weeklyOffDayCount: 4,
      publicHolidayDayCount: 0,
      siteClosureDayCount: 0,
      missingDayCount: 2,
      regularMinutes: 8640,
      overtimeMinutes: 180,
      allocationMinutes: 8820,
      blockingIssueCount: 1,
      warningIssueCount: 1,
      projectCount: 1,
      locationCount: 0,
    ),
    issueCounts: const [
      YorksWorkforceMonthlyIssueCount(
        severity: YorksWorkforceMonthlyIssueSeverity.blocking,
        issueCode: 'required_attendance_missing',
        count: 1,
      ),
      YorksWorkforceMonthlyIssueCount(
        severity: YorksWorkforceMonthlyIssueSeverity.warning,
        issueCode: 'below_standard_minutes',
        count: 1,
      ),
    ],
    totalCount: 1,
    workers: [worker],
  );
}

YorksWorkforceMonthlyWorkerDetail _workerDetail(
  YorksWorkforceMonthlyPeriod period,
  YorksWorkforceMonthlyWorkerSummary worker,
) => YorksWorkforceMonthlyWorkerDetail(
  schemaVersion: 1,
  authorizationMode: 'enforced_t06',
  actorAuthUserId: _actorId,
  serverTime: '2026-08-30T09:00:00Z',
  period: period,
  validationRun: const YorksWorkforceMonthlyValidationRun(
    id: _runId,
    number: 2,
    status: YorksWorkforceMonthlyPeriodStatus.draft,
    sourceFingerprint: _fingerprint,
    isCurrent: true,
    validatedAt: '2026-08-30T09:00:00Z',
    validatedByAuthUserId: _actorId,
  ),
  worker: worker,
  days: [
    YorksWorkforceMonthlyDay(
      workDate: '2026-08-20',
      isFuture: false,
      isRequired: true,
      dayType: 'regular_working_day',
      dailyStatus: YorksWorkforceMonthlyDailyStatus.hasErrors,
      assignment: const {'team_name': 'Nexus 4 Station'},
      schedule: const {'calendar_timezone': 'Asia/Dubai'},
      attendance: null,
      allocation: null,
      scheduledMinutes: 480,
      regularMinutes: 0,
      overtimeMinutes: 0,
      allocationMinutes: 0,
      blockingIssueCount: 1,
      warningIssueCount: 0,
      issues: [
        YorksWorkforceMonthlyDayIssue(
          id: '66000000-0000-4000-8000-000000000001',
          severity: YorksWorkforceMonthlyIssueSeverity.blocking,
          issueCode: 'required_attendance_missing',
          messageKey: 'monthly_issue_required_attendance_missing',
          context: {},
        ),
      ],
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
