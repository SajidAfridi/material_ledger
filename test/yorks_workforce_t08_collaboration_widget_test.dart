import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/workforce/application/workforce_collaboration_controller.dart';
import 'package:material_ledger/features/workforce/application/workforce_monthly_period_controller.dart';
import 'package:material_ledger/features/workforce/domain/workforce_collaboration_models.dart';
import 'package:material_ledger/features/workforce/domain/workforce_monthly_period_models.dart';
import 'package:material_ledger/features/workforce/presentation/screens/yorks_workforce_timesheets_screen.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_team_chat.dart';
import 'package:material_ledger/shared/models/yorks_v1_workforce_strings.dart';

const _actorId = '10000000-0000-4000-8000-000000000001';
const _periodId = '81000000-0000-4000-8000-000000000001';
const _teamId = '82000000-0000-4000-8000-000000000001';
const _runId = '83000000-0000-4000-8000-000000000001';
const _conversationId = '84000000-0000-4000-8000-000000000001';
const _messageId = '85000000-0000-4000-8000-000000000001';
const _fingerprint =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  testWidgets(
    'T08 collaboration is interactive on desktop and read-only on compact RTL',
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
        String? sent;
        await tester.pumpWidget(
          MaterialApp(
            home: YorksWorkforceMonthlyView(
              language: fixture.$2,
              state: _monthlyState(),
              collaborationState: YorksWorkforceCollaborationState(
                status: YorksWorkforceCollaborationStatus.ready,
                projection: _collaboration(),
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
              onCollaborationRetry: () {},
              onOpenDiscussion: () {},
              onSendDiscussionMessage: (value) async {
                sent = value;
                return true;
              },
              onUploadEvidence: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${fixture.$1}');
        expect(
          find.text(
            YorksV1WorkforceStrings.text(
              fixture.$2,
              'monthly_collaboration_title',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('workforce-add-evidence')),
          fixture.$3 ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const Key('workforce-discussion-message')),
          fixture.$3 ? findsOneWidget : findsNothing,
        );
        if (fixture.$1.width >= 1200) {
          for (final key in const [
            'monthly_collaboration_event_corrected',
            'monthly_collaboration_notice_final_approval',
            'monthly_collaboration_event_reopen_requested',
            'monthly_collaboration_event_reopened',
          ]) {
            expect(
              find.text(YorksV1WorkforceStrings.text(fixture.$2, key)),
              findsOneWidget,
            );
          }
        }
        if (fixture.$3 && fixture.$1.width == 1440) {
          await tester.enterText(
            find.byKey(const Key('workforce-discussion-message')),
            'Scoped reply',
          );
          await tester.tap(find.byIcon(Icons.send_outlined));
          await tester.pump();
          expect(sent, 'Scoped reply');
        }
        if (!fixture.$3) {
          expect(
            find.text(
              YorksV1WorkforceStrings.text(
                fixture.$2,
                'monthly_collaboration_mobile_read_only',
              ),
            ),
            findsOneWidget,
          );
        }
        search.dispose();
      }
    },
  );
}

YorksWorkforceMonthlyState _monthlyState() {
  final period = YorksWorkforceMonthlyPeriod(
    id: _periodId,
    teamId: _teamId,
    teamName: 'Nexus 4 Station',
    periodMonth: '2026-08-01',
    storedStatus: YorksWorkforceMonthlyPeriodStatus.readyForReview,
    effectiveStatus: YorksWorkforceMonthlyPeriodStatus.readyForReview,
    isStale: false,
    recordVersion: 1,
    currentValidationRunId: _runId,
    currentValidationNumber: 1,
    sourceFingerprint: _fingerprint,
    currentSourceFingerprint: _fingerprint,
    validatedAt: '2026-08-30T09:00:00Z',
    validatedByAuthUserId: _actorId,
  );
  final projection = YorksWorkforceMonthlyProjection(
    schemaVersion: 1,
    authorizationMode: 'enforced_t06',
    actorAuthUserId: _actorId,
    serverTime: '2026-08-30T10:00:00Z',
    filters: const YorksWorkforceMonthlyFilters(
      teamId: _teamId,
      periodMonth: '2026-08-01',
    ),
    capabilities: const YorksWorkforceMonthlyCapabilities(
      canView: true,
      canValidate: false,
    ),
    period: period,
    summary: const YorksWorkforceMonthlySummary(
      workerCount: 0,
      dateCount: 31,
      scheduledDayCount: 0,
      futureDayCount: 0,
      presentDayCount: 0,
      absentDayCount: 0,
      leaveDayCount: 0,
      weeklyOffDayCount: 0,
      publicHolidayDayCount: 0,
      siteClosureDayCount: 0,
      missingDayCount: 0,
      regularMinutes: 0,
      overtimeMinutes: 0,
      allocationMinutes: 0,
      blockingIssueCount: 0,
      warningIssueCount: 0,
      projectCount: 0,
      locationCount: 0,
    ),
    issueCounts: const [],
    totalCount: 0,
    workers: const [],
  );
  return YorksWorkforceMonthlyState(
    status: YorksWorkforceMonthlyStatus.ready,
    periodMonth: '2026-08-01',
    selectedTeamId: _teamId,
    filters: projection.filters,
    projection: projection,
  );
}

YorksWorkforceCollaborationProjection _collaboration() {
  final message = YorksV1ChatMessage(
    id: _messageId,
    conversationId: _conversationId,
    kind: 'message',
    createdAt: DateTime.utc(2026, 8, 30, 10),
    isMine: false,
    isPinned: false,
    acknowledgementCount: 0,
    acknowledgedByMe: false,
    attachments: const [],
    mentionedAuthUserIds: const [],
    body: 'Please review this period',
    senderAuthUserId: _actorId,
    senderDisplayName: 'Faisal Ahmed',
    senderExactRole: YorksV1Role.admin,
  );
  return YorksWorkforceCollaborationProjection(
    periodId: _periodId,
    discussion: YorksV1ChatThread(
      conversation: YorksV1ChatConversation(
        id: _conversationId,
        kind: YorksV1ChatKind.group,
        title: 'Nexus 4 · Aug 2026',
        createdAt: DateTime.utc(2026, 8, 30, 9),
        updatedAt: DateTime.utc(2026, 8, 30, 10),
        isPinned: false,
        isMuted: false,
        isArchived: false,
        unreadCount: 0,
        participantCount: 1,
        lastMessage: message,
      ),
      participants: const [
        YorksV1ChatParticipant(
          authUserId: _actorId,
          displayName: 'Faisal Ahmed',
          exactRole: YorksV1Role.admin,
          isOwner: true,
        ),
      ],
      messages: [message],
    ),
    documents: const [],
    notifications: [
      YorksWorkforceNotificationItem(
        id: '86000000-0000-4000-8000-000000000001',
        eventCode: 'workforce_correction_completed',
        createdAt: DateTime.utc(2026, 8, 30, 10),
        itemCount: 1,
      ),
      YorksWorkforceNotificationItem(
        id: '86000000-0000-4000-8000-000000000002',
        eventCode: 'workforce_final_approval_required',
        createdAt: DateTime.utc(2026, 8, 30, 10, 1),
        itemCount: 1,
      ),
      YorksWorkforceNotificationItem(
        id: '86000000-0000-4000-8000-000000000003',
        eventCode: 'workforce_reopen_requested',
        createdAt: DateTime.utc(2026, 8, 30, 10, 2),
        itemCount: 1,
      ),
      YorksWorkforceNotificationItem(
        id: '86000000-0000-4000-8000-000000000004',
        eventCode: 'workforce_reopen_approved',
        createdAt: DateTime.utc(2026, 8, 30, 10, 3),
        itemCount: 1,
      ),
    ],
  );
}
