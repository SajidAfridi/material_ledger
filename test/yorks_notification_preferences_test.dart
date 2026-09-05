import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/engineer/presentation/screens/notification_preferences_screen.dart';
import 'package:material_ledger/shared/models/yorks_v1_notification_preferences.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_notification_preferences_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_notification_preferences_repository.dart';
import 'package:material_ledger/shared/services/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('projection parser is strict and category-aware', () {
    final preferences = YorksV1NotificationPreferences.fromRpcJson({
      'schema_version': 1,
      'revision': 4,
      'push_enabled': true,
      'workflow_push_enabled': false,
      'team_chat_push_enabled': true,
      'foreground_alerts_enabled': true,
      'sound_enabled': false,
      'updated_at': '2026-09-05T17:00:00Z',
    });

    expect(preferences.revision, 4);
    expect(preferences.allowsPushFor(teamChat: false), isFalse);
    expect(preferences.allowsPushFor(teamChat: true), isTrue);
    expect(
      () => YorksV1NotificationPreferences.fromRpcJson({
        ...preferences.toPatch(),
        'schema_version': 1,
        'revision': 4,
        'updated_at': null,
        'unexpected': true,
      }),
      throwsFormatException,
    );
  });

  test(
    'controller saves against the observed revision and adopts the server',
    () async {
      final repository = _NotificationPreferencesRepository();
      final notifier = YorksV1NotificationPreferencesNotifier(
        repository: repository,
      );
      await notifier.refresh();

      final desired = notifier.state.requireValue.copyWith(
        workflowPushEnabled: false,
      );
      final saved = await notifier.save(desired);

      expect(repository.expectedRevision, 3);
      expect(repository.desired?.workflowPushEnabled, isFalse);
      expect(saved.revision, 4);
      expect(notifier.state.requireValue.revision, 4);
    },
  );

  testWidgets(
    'screen separates permanent history from optional delivery controls',
    (tester) async {
      await _pumpScreen(tester);

      expect(find.text('Notification controls'), findsOneWidget);
      expect(find.text('In-app workflow history'), findsOneWidget);
      expect(find.textContaining('Always on.'), findsAtLeastNWidgets(1));
      expect(find.text('Push notifications'), findsOneWidget);
      expect(find.text('Workflow action alerts'), findsOneWidget);
      expect(find.text('Team Chat alerts'), findsOneWidget);
      expect(find.text('Foreground pop-ups'), findsOneWidget);
      expect(find.text('Alert sound'), findsOneWidget);
      expect(find.textContaining('App lock'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('notification-workflow-enabled')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Notification preferences saved.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selected language localizes the controls and direction', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'selected_language': 'ar'});
    await _pumpScreen(tester);

    expect(find.text('عناصر التحكم في الإشعارات'), findsOneWidget);
    expect(find.text('سجل سير العمل داخل التطبيق'), findsOneWidget);
    final directionality = tester.widgetList<Directionality>(
      find.descendant(
        of: find.byType(NotificationPreferencesScreen),
        matching: find.byType(Directionality),
      ),
    );
    expect(
      directionality.any((widget) => widget.textDirection == TextDirection.rtl),
      isTrue,
    );
  });
}

Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        pushServiceProvider.overrideWithValue(const NoopPushService()),
        yorksV1NotificationPreferencesProvider.overrideWith((ref) {
          final notifier = YorksV1NotificationPreferencesNotifier(
            repository: _NotificationPreferencesRepository(),
          );
          notifier.refresh();
          return notifier;
        }),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const NotificationPreferencesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _NotificationPreferencesRepository
    implements YorksV1NotificationPreferencesRepository {
  int? expectedRevision;
  YorksV1NotificationPreferences? desired;

  @override
  Future<YorksV1NotificationPreferences> loadMine() async =>
      const YorksV1NotificationPreferences(
        revision: 3,
        pushEnabled: true,
        workflowPushEnabled: true,
        teamChatPushEnabled: true,
        foregroundAlertsEnabled: true,
        soundEnabled: true,
      );

  @override
  Future<YorksV1NotificationPreferences> updateMine({
    required YorksV1NotificationPreferences desired,
    required int expectedRevision,
  }) async {
    this.desired = desired;
    this.expectedRevision = expectedRevision;
    return desired.copyWith(revision: expectedRevision + 1);
  }
}
