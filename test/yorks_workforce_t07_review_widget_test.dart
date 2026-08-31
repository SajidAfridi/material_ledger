import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/workforce/application/workforce_monthly_period_controller.dart';
import 'package:material_ledger/features/workforce/application/workforce_review_controller.dart';
import 'package:material_ledger/features/workforce/domain/workforce_monthly_period_models.dart';
import 'package:material_ledger/features/workforce/domain/workforce_review_models.dart';
import 'package:material_ledger/features/workforce/presentation/screens/yorks_workforce_timesheets_screen.dart';
import 'package:material_ledger/shared/models/app_language.dart';

const _periodId = '71000000-0000-4000-8000-000000000001';
const _teamId = '72000000-0000-4000-8000-000000000001';
const _runId = '73000000-0000-4000-8000-000000000001';
const _fingerprint =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  testWidgets(
    'T07 lifecycle is actionable on desktop and deliberately read-only on compact RTL',
    (tester) async {
      for (final fixture in const [
        (Size(1440, 900), AppLanguage.english, true),
        (Size(1366, 768), AppLanguage.english, true),
        (Size(1180, 820), AppLanguage.english, true),
        (Size(1024, 768), AppLanguage.arabic, true),
        (Size(820, 1180), AppLanguage.arabic, true),
        (Size(768, 1024), AppLanguage.urdu, true),
        (Size(430, 932), AppLanguage.hindi, false),
        (Size(390, 844), AppLanguage.arabic, false),
        (Size(360, 800), AppLanguage.arabic, false),
      ]) {
        tester.view.physicalSize = fixture.$1;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final search = TextEditingController();
        await tester.pumpWidget(
          MaterialApp(
            home: YorksWorkforceMonthlyView(
              language: fixture.$2,
              state: const YorksWorkforceMonthlyState(
                status: YorksWorkforceMonthlyStatus.ready,
                periodMonth: '2026-08-01',
              ),
              reviewState: YorksWorkforceReviewState(
                status: YorksWorkforceReviewStatus.ready,
                lifecycle: _lifecycle(),
                queue: _queue(),
              ),
              searchController: search,
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
              onReviewRetry: () {},
              onReviewQueueSelect: (_) {},
              onReviewAction: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('monthly-review-queue-$_periodId')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('monthly-review-submit')),
          fixture.$3 ? findsOneWidget : findsNothing,
        );
        expect(
          find.byIcon(Icons.desktop_windows_outlined),
          fixture.$3 ? findsNothing : findsOneWidget,
        );
        search.dispose();
      }
    },
  );

  testWidgets('tablet review renders only server-returned T07 actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final search = TextEditingController();
    addTearDown(search.dispose);
    final invoked = <YorksWorkforceMonthlyReviewAction>[];
    await tester.pumpWidget(
      MaterialApp(
        home: YorksWorkforceMonthlyView(
          language: AppLanguage.english,
          state: const YorksWorkforceMonthlyState(
            status: YorksWorkforceMonthlyStatus.ready,
            periodMonth: '2026-08-01',
          ),
          reviewState: YorksWorkforceReviewState(
            status: YorksWorkforceReviewStatus.ready,
            lifecycle: _lifecycle(
              actions: const YorksWorkforceReviewActions(
                canSubmit: false,
                canReturn: true,
                canCorrect: false,
                canVerify: true,
                canFinalApprove: false,
                canRequestReopen: false,
                canAuthorizeReopen: false,
              ),
            ),
            queue: _queue(),
          ),
          searchController: search,
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
          onReviewRetry: () {},
          onReviewQueueSelect: (_) {},
          onReviewAction: invoked.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('monthly-review-submit')), findsNothing);
    expect(
      find.byKey(const Key('monthly-review-returnForCorrection')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('monthly-review-verify')), findsOneWidget);
    expect(
      find.byKey(const Key('monthly-review-approveAndLock')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('monthly-review-verify')));
    await tester.pump();
    expect(invoked, [YorksWorkforceMonthlyReviewAction.verify]);
    expect(tester.takeException(), isNull);
  });
}

YorksWorkforceReviewLifecycle _lifecycle({
  YorksWorkforceReviewActions actions = const YorksWorkforceReviewActions(
    canSubmit: true,
    canReturn: false,
    canCorrect: false,
    canVerify: false,
    canFinalApprove: false,
    canRequestReopen: false,
    canAuthorizeReopen: false,
  ),
}) => YorksWorkforceReviewLifecycle(
  schemaVersion: 1,
  authorizationMode: 'enforced_t07',
  periodId: _periodId,
  teamId: _teamId,
  periodMonth: '2026-08-01',
  status: YorksWorkforceMonthlyPeriodStatus.readyForReview,
  recordVersion: 1,
  approvalRevisionNumber: 0,
  validationRunId: _runId,
  validationNumber: 1,
  sourceFingerprint: _fingerprint,
  currentSourceFingerprint: _fingerprint,
  isStale: false,
  blockingIssueCount: 0,
  warningIssueCount: 0,
  submitterAuthUserId: null,
  actions: actions,
  transitions: const [],
  corrections: const [],
  approvedSnapshots: const [],
  reopenRequests: const [],
);

YorksWorkforceReviewQueue _queue() => YorksWorkforceReviewQueue(
  schemaVersion: 1,
  authorizationMode: 'enforced_t07',
  statusFilter: null,
  limit: 50,
  offset: 0,
  totalCount: 1,
  items: [
    YorksWorkforceReviewQueueItem(
      periodId: _periodId,
      teamName: 'T07 Review Team',
      periodMonth: '2026-08-01',
      status: YorksWorkforceMonthlyPeriodStatus.readyForReview,
      updatedAt: '2026-08-30T10:00:00Z',
      lifecycle: _lifecycle(),
    ),
  ],
);
