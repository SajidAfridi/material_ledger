import 'dart:async';

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

  test(
    'a read started before saving cannot restore old enabled delivery',
    () async {
      final repository = _ControlledPreferencesRepository();
      final notifier = YorksV1NotificationPreferencesNotifier(
        repository: repository,
      );
      addTearDown(notifier.dispose);
      await notifier.refresh();
      final oldRead = Completer<YorksV1NotificationPreferences>();
      repository.read = () => oldRead.future;
      final refresh = notifier.refresh();
      await notifier.save(
        notifier.state.requireValue.copyWith(pushEnabled: false),
      );
      oldRead.complete(_enabledPreferences);
      await refresh;
      expect(notifier.state.requireValue.revision, 4);
      expect(notifier.state.requireValue.pushEnabled, isFalse);
    },
  );

  test('an obsolete read failure cannot replace a confirmed save', () async {
    final repository = _ControlledPreferencesRepository();
    final notifier = YorksV1NotificationPreferencesNotifier(
      repository: repository,
    );
    addTearDown(notifier.dispose);
    await notifier.refresh();
    final oldRead = Completer<YorksV1NotificationPreferences>();
    repository.read = () => oldRead.future;
    final refresh = notifier.refresh();
    await notifier.save(
      notifier.state.requireValue.copyWith(pushEnabled: false),
    );
    oldRead.completeError(StateError('old network request failed'));
    await refresh;
    expect(notifier.state.hasError, isFalse);
    expect(notifier.state.requireValue.pushEnabled, isFalse);
  });

  test('refreshes coalesce and wait for the same protected read', () async {
    final repository = _ControlledPreferencesRepository();
    final read = Completer<YorksV1NotificationPreferences>();
    repository.read = () => read.future;
    final notifier = YorksV1NotificationPreferencesNotifier(
      repository: repository,
    );
    addTearDown(notifier.dispose);
    final first = notifier.refresh();
    final second = notifier.refresh();
    expect(identical(first, second), isTrue);
    expect(repository.readCalls, 1);
    read.complete(_enabledPreferences);
    await Future.wait([first, second]);
    expect(notifier.state.requireValue.revision, 3);
  });

  test(
    'polling cannot read during a save or adopt a lower revision afterward',
    () async {
      final repository = _ControlledPreferencesRepository();
      final notifier = YorksV1NotificationPreferencesNotifier(
        repository: repository,
      );
      addTearDown(notifier.dispose);
      await notifier.refresh();
      final response = Completer<YorksV1NotificationPreferences>();
      repository.write = (desired, _) => response.future;
      final saving = notifier.save(
        notifier.state.requireValue.copyWith(pushEnabled: false),
      );
      await notifier.refresh();
      expect(repository.readCalls, 1);
      response.complete(
        _enabledPreferences.copyWith(revision: 4, pushEnabled: false),
      );
      await saving;
      await notifier.refresh();
      expect(repository.readCalls, 2);
      expect(notifier.state.requireValue.revision, 4);
      expect(notifier.state.requireValue.pushEnabled, isFalse);
    },
  );

  test(
    'late save completion after account disposal is rejected without a state write',
    () async {
      final repository = _ControlledPreferencesRepository();
      final notifier = YorksV1NotificationPreferencesNotifier(
        repository: repository,
      );
      await notifier.refresh();
      final response = Completer<YorksV1NotificationPreferences>();
      repository.write = (desired, _) => response.future;
      final saving = notifier.save(
        notifier.state.requireValue.copyWith(pushEnabled: false),
      );
      final rejected = expectLater(
        saving,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'reason',
            'NOTIFICATION_PREFERENCES_UNAVAILABLE',
          ),
        ),
      );
      notifier.dispose();
      response.complete(
        _enabledPreferences.copyWith(revision: 4, pushEnabled: false),
      );
      await rejected;
    },
  );

  test('a disposed pending save preserves its original server error', () async {
    final repository = _ControlledPreferencesRepository();
    final notifier = YorksV1NotificationPreferencesNotifier(
      repository: repository,
    );
    await notifier.refresh();
    final response = Completer<YorksV1NotificationPreferences>();
    repository.write = (desired, _) => response.future;
    final saving = notifier.save(
      notifier.state.requireValue.copyWith(pushEnabled: false),
    );
    final serverError = StateError('server rejected the old account choice');
    final rejected = expectLater(saving, throwsA(same(serverError)));
    notifier.dispose();
    response.completeError(serverError);
    await rejected;
  });

  test(
    'an obsolete read finishing cannot release a newer coalesced read',
    () async {
      final repository = _ControlledPreferencesRepository();
      final notifier = YorksV1NotificationPreferencesNotifier(
        repository: repository,
      );
      addTearDown(notifier.dispose);
      await notifier.refresh();
      final oldRead = Completer<YorksV1NotificationPreferences>();
      repository.read = () => oldRead.future;
      final obsolete = notifier.refresh();
      await notifier.save(
        notifier.state.requireValue.copyWith(pushEnabled: false),
      );
      final newRead = Completer<YorksV1NotificationPreferences>();
      repository.read = () => newRead.future;
      final current = notifier.refresh();
      oldRead.complete(_enabledPreferences);
      await obsolete;
      final duplicate = notifier.refresh();
      expect(identical(current, duplicate), isTrue);
      expect(repository.readCalls, 3);
      newRead.complete(
        _enabledPreferences.copyWith(revision: 4, pushEnabled: false),
      );
      await Future.wait([current, duplicate]);
      expect(notifier.state.requireValue.pushEnabled, isFalse);
    },
  );

  test(
    'late read failure after account disposal does not write state or escape',
    () async {
      final repository = _ControlledPreferencesRepository();
      final read = Completer<YorksV1NotificationPreferences>();
      repository.read = () => read.future;
      final notifier = YorksV1NotificationPreferencesNotifier(
        repository: repository,
      );
      final refreshing = notifier.refresh();
      notifier.dispose();
      read.completeError(StateError('old account read failed'));
      await refreshing;
    },
  );

  testWidgets('a stalled read times out and a retry can replace it', (
    tester,
  ) async {
    final repository = _ControlledPreferencesRepository();
    final oldRead = Completer<YorksV1NotificationPreferences>();
    repository.read = () => oldRead.future;
    final notifier = YorksV1NotificationPreferencesNotifier(
      repository: repository,
      requestTimeout: const Duration(seconds: 1),
    );
    addTearDown(notifier.dispose);
    final refreshing = notifier.refresh();
    await tester.pump(const Duration(seconds: 1));
    await refreshing;
    expect(notifier.state.error, isA<TimeoutException>());
    repository.read = null;
    await notifier.refresh();
    oldRead.complete(
      _enabledPreferences.copyWith(revision: 99, pushEnabled: false),
    );
    await tester.pump();
    expect(repository.readCalls, 2);
    expect(notifier.state.requireValue.revision, 3);
    expect(notifier.state.requireValue.pushEnabled, isTrue);
  });

  testWidgets('a stalled save times out without blocking a later choice', (
    tester,
  ) async {
    final repository = _ControlledPreferencesRepository();
    final notifier = YorksV1NotificationPreferencesNotifier(
      repository: repository,
      requestTimeout: const Duration(seconds: 1),
    );
    addTearDown(notifier.dispose);
    await notifier.refresh();
    final oldWrite = Completer<YorksV1NotificationPreferences>();
    repository.write = (desired, _) => oldWrite.future;
    final saving = notifier.save(
      notifier.state.requireValue.copyWith(pushEnabled: false),
    );
    final failed = expectLater(saving, throwsA(isA<TimeoutException>()));
    await tester.pump(const Duration(seconds: 1));
    await failed;
    expect(notifier.state.valueOrNull?.revision, 3);
    repository.write = null;
    await notifier.save(
      notifier.state.valueOrNull!.copyWith(pushEnabled: false),
    );
    oldWrite.complete(_enabledPreferences.copyWith(revision: 99));
    await tester.pump();
    expect(repository.writeCalls, 2);
    expect(notifier.state.requireValue.revision, 4);
    expect(notifier.state.requireValue.pushEnabled, isFalse);
  });

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

const _enabledPreferences = YorksV1NotificationPreferences(
  revision: 3,
  pushEnabled: true,
  workflowPushEnabled: true,
  teamChatPushEnabled: true,
  foregroundAlertsEnabled: true,
  soundEnabled: true,
);

class _ControlledPreferencesRepository
    implements YorksV1NotificationPreferencesRepository {
  int readCalls = 0;
  int writeCalls = 0;
  Future<YorksV1NotificationPreferences> Function()? read;
  Future<YorksV1NotificationPreferences> Function(
    YorksV1NotificationPreferences,
    int,
  )?
  write;

  @override
  Future<YorksV1NotificationPreferences> loadMine() {
    readCalls++;
    return read?.call() ?? Future.value(_enabledPreferences);
  }

  @override
  Future<YorksV1NotificationPreferences> updateMine({
    required YorksV1NotificationPreferences desired,
    required int expectedRevision,
  }) {
    writeCalls++;
    return write?.call(desired, expectedRevision) ??
        Future.value(desired.copyWith(revision: expectedRevision + 1));
  }
}
