import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/app.dart' show appRouterProvider;
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/core/widgets/yorks_app_toast.dart';
import 'package:material_ledger/shared/models/app_user.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_notification.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_notification_preferences_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_notification_provider.dart';
import 'package:material_ledger/shared/services/push_service.dart';
import 'package:material_ledger/shared/widgets/notification_alert_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _userProvider = StateProvider<AppUser?>((_) => _user('owner'));
final _hostEnabledProvider = StateProvider((_) => true);

void main() {
  setUpAll(_loadFonts);
  tearDown(YorksAppToast.dismiss);

  for (final target in ['Notifications', 'Team Chat']) {
    testWidgets('mixed burst offers a direct $target action', (tester) async {
      final harness = await _Harness.start(tester);
      harness.server.publish([_workflow('workflow'), _chat('chat')]);
      await tester.pump();
      harness.audio.complete(true);
      await tester.pump();

      expect(find.text('New updates are waiting'), findsOneWidget);
      expect(
        find.text('Workflow updates: 1 · Team Chat updates: 1.'),
        findsOneWidget,
      );
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Team Chat'), findsOneWidget);
      expect(harness.audio.plays, 1);
      await tester.tap(find.text(target));
      await tester.pumpAndSettle();
      expect(
        find.text(target == 'Team Chat' ? 'Chat inbox' : 'Workflow inbox'),
        findsOneWidget,
      );
      expect(harness.server.markedIds, isEmpty);
      await harness.close(tester);
    });
  }

  for (final evidence in <({String name, Size size})>[
    (name: 'mixed_updates_desktop.png', size: const Size(1366, 768)),
    (name: 'mixed_updates_mobile.png', size: const Size(360, 800)),
  ]) {
    testWidgets('mixed burst responsive evidence ${evidence.name}', (
      tester,
    ) async {
      tester.view.physicalSize = evidence.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await _Harness.start(tester);
      harness.server.publish([_workflow('workflow'), _chat('chat')]);
      await tester.pump();
      await tester.pump();
      for (final label in ['Notifications', 'Team Chat']) {
        final button = find.widgetWithText(TextButton, label);
        expect(button, findsOneWidget);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/push_p0/${evidence.name}'),
      );
      await harness.close(tester);
    });
  }

  testWidgets('current Chat URL suppresses toast without marking seen', (
    tester,
  ) async {
    final harness = await _Harness.start(
      tester,
      initialLocation: '/yorks/team-chat/conversation-1',
    );
    // This route deliberately represents a still-loading/denied protected
    // thread. Presence at its URL is not evidence that a message was read.
    harness.server.publish([_chat('chat', conversation: 'conversation-1')]);
    await tester.pump();
    expect(find.text('New Team Chat message'), findsNothing);
    expect(harness.server.markedIds, isEmpty);
    expect(harness.audio.prepares, 0);
    await harness.close(tester);
  });

  testWidgets('Chat toast navigation leaves acknowledgement to its loader', (
    tester,
  ) async {
    final harness = await _Harness.start(tester);
    harness.server.publish([_chat('chat')]);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('VIEW DETAILS'));
    await tester.pumpAndSettle();
    expect(find.text('Protected Chat destination'), findsOneWidget);
    expect(harness.server.markedIds, isEmpty);
    await harness.close(tester);
  });

  testWidgets('an open thread is excluded from a different Chat alert', (
    tester,
  ) async {
    final harness = await _Harness.start(
      tester,
      initialLocation: '/yorks/team-chat/conversation-1',
    );
    harness.server.publish([
      _chat('open', conversation: 'conversation-1'),
      _chat('other', conversation: 'conversation-2'),
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.text('New Team Chat message'), findsOneWidget);
    expect(find.text('New updates are waiting'), findsNothing);
    expect(harness.server.markedIds, isEmpty);
    await harness.close(tester);
  });

  for (final condition in ['focus', 'sound', 'foreground', 'account']) {
    testWidgets('delayed audio rechecks $condition before playing', (
      tester,
    ) async {
      final harness = await _Harness.start(tester);
      harness.server.publish([_workflow('workflow')]);
      await tester.pump();
      expect(harness.audio.prepares, 1);
      expect(harness.audio.plays, 0);
      switch (condition) {
        case 'focus':
          harness.visible = false;
        case 'sound':
          harness.preferences.update(sound: false);
        case 'foreground':
          harness.preferences.update(foreground: false);
        case 'account':
          harness.container.read(_userProvider.notifier).state = _user('other');
      }
      harness.audio.complete(true);
      await tester.pump();
      expect(harness.audio.plays, 0);
      await harness.close(tester);
    });
  }

  for (final condition in ['focus', 'foreground', 'account']) {
    testWidgets('queued toast rechecks $condition before insertion', (
      tester,
    ) async {
      final harness = await _Harness.start(tester);
      harness.server.publish([_workflow('workflow')]);
      // Force notification delivery while leaving its post-frame presentation
      // pending, then change the condition before the next frame.
      harness.container.read(notificationAttentionFeedProvider);
      expect(harness.audio.prepares, 1);
      switch (condition) {
        case 'focus':
          harness.visible = false;
        case 'foreground':
          harness.preferences.update(foreground: false);
        case 'account':
          harness.container.read(_userProvider.notifier).state = _user('other');
      }
      await tester.pump();
      expect(find.text('Material request approval required'), findsNothing);
      harness.audio.complete(true);
      await tester.pump();
      expect(harness.audio.plays, 0);
      await harness.close(tester);
    });
  }

  testWidgets('restoring the same account cannot revive an old chime', (
    tester,
  ) async {
    final harness = await _Harness.start(tester);
    harness.server.publish([_workflow('workflow')]);
    await tester.pump();
    harness.container.read(_userProvider.notifier).state = null;
    await tester.pump();
    harness.container.read(_userProvider.notifier).state = _user('owner');
    await tester.pump();
    harness.audio.complete(true);
    await tester.pump();
    expect(harness.audio.plays, 0);
    await harness.close(tester);
  });

  testWidgets('an old toast action cannot navigate or mark read after logout', (
    tester,
  ) async {
    final harness = await _Harness.start(tester);
    harness.server.publish([_chat('chat')]);
    await tester.pump();
    await tester.pump();
    final action = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'VIEW DETAILS'))
        .onPressed!;
    harness.container.read(_userProvider.notifier).state = null;
    await tester.pump();
    action();
    await tester.pump();
    expect(harness.router.routeInformationProvider.value.uri.path, '/');
    expect(harness.server.markedIds, isEmpty);
    await harness.close(tester);
  });

  testWidgets('unknown preferences cause no popup or sound', (tester) async {
    final harness = await _Harness.start(tester);
    harness.preferences.loading();
    harness.server.publish([_workflow('workflow')]);
    await tester.pump();
    expect(find.text('Material request approval required'), findsNothing);
    expect(harness.audio.prepares, 0);
    await harness.close(tester);
  });

  testWidgets(
    'audio preparation timeout allows the next alert to recover',
    (tester) async =>
        withClock(Clock(() => tester.binding.clock.now()), () async {
          final harness = await _Harness.start(tester);
          harness.server.publish([_workflow('first')]);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 2100));
          expect(harness.audio.plays, 0);
          harness.audio.useImmediatePreparation = true;
          harness.server.publish([_workflow('second')]);
          await tester.pump();
          await tester.pump();
          expect(harness.audio.prepares, 2);
          expect(harness.audio.plays, 1);
          expect(tester.takeException(), isNull);
          await harness.close(tester);
        }),
  );

  for (final nextOwner in <String?>['other', null]) {
    testWidgets('visible owned toast is removed on ${nextOwner ?? 'logout'}', (
      tester,
    ) async {
      final harness = await _Harness.start(tester);
      harness.server.publish([_workflow('workflow')]);
      await tester.pump();
      await tester.pump();
      expect(find.text('Material request approval required'), findsOneWidget);
      harness.container.read(_userProvider.notifier).state = nextOwner == null
          ? null
          : _user(nextOwner);
      await tester.pump();
      await tester.pump();
      expect(find.text('Material request approval required'), findsNothing);
      harness.audio.complete(true);
      await tester.pump();
      expect(harness.audio.plays, 0);
      await harness.close(tester);
    });
  }

  testWidgets('disposing the host removes its own visible toast', (
    tester,
  ) async {
    final harness = await _Harness.start(tester);
    harness.server.publish([_workflow('workflow')]);
    await tester.pump();
    await tester.pump();
    harness.container.read(_hostEnabledProvider.notifier).state = false;
    await tester.pump();
    await tester.pump();
    expect(find.text('Material request approval required'), findsNothing);
    harness.audio.complete(true);
    await tester.pump();
    expect(harness.audio.plays, 0);
    await harness.close(tester);
  });

  testWidgets('disposing the host preserves an unrelated confirmation toast', (
    tester,
  ) async {
    final harness = await _Harness.start(tester);
    harness.server.publish([_workflow('workflow')]);
    await tester.pump();
    await tester.pump();
    YorksAppToast.show(
      tester.element(find.text('Workspace')),
      title: 'Unrelated confirmed save',
      owner: Object(),
    );
    await tester.pump();
    await tester.pump();
    harness.container.read(_hostEnabledProvider.notifier).state = false;
    await tester.pump();
    expect(find.text('Unrelated confirmed save'), findsOneWidget);
    await harness.close(tester);
  });
}

class _Harness {
  final server = _ServerNotifications();
  final preferences = _Preferences();
  final audio = _Audio();
  late ProviderContainer container;
  late GoRouter router;
  bool visible = true;

  static Future<_Harness> start(
    WidgetTester tester, {
    String initialLocation = '/',
  }) async {
    SharedPreferences.setMockInitialValues({});
    final localPreferences = await SharedPreferences.getInstance();
    final harness = _Harness();
    harness.router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Workspace')),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const Scaffold(body: Text('Workflow inbox')),
        ),
        GoRoute(
          path: '/yorks/team-chat',
          builder: (_, _) => const Scaffold(body: Text('Chat inbox')),
        ),
        GoRoute(
          path: '/yorks/team-chat/:conversationId',
          builder: (_, _) =>
              const Scaffold(body: Text('Protected Chat destination')),
        ),
      ],
    );
    harness.container = ProviderContainer(
      overrides: [
        appRouterProvider.overrideWithValue(harness.router),
        currentUserProvider.overrideWith((ref) => ref.watch(_userProvider)),
        sharedPreferencesProvider.overrideWithValue(localPreferences),
        pushServiceProvider.overrideWithValue(const NoopPushService()),
        yorksV1NotificationsProvider.overrideWith((_) => harness.server),
        yorksV1NotificationPreferencesProvider.overrideWith(
          (_) => harness.preferences,
        ),
        notificationPresentationAllowedProvider.overrideWithValue(
          () => harness.visible,
        ),
        notificationAlertSoundDriverProvider.overrideWithValue((
          prepare: harness.audio.prepare,
          play: harness.audio.play,
        )),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: harness.router,
          builder: (_, child) => Consumer(
            builder: (_, ref, _) => ref.watch(_hostEnabledProvider)
                ? NotificationAlertHost(child: child!)
                : child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return harness;
  }

  Future<void> close(WidgetTester tester) async {
    audio.cancelPreparation();
    YorksAppToast.dismiss();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    router.dispose();
  }
}

class _ServerNotifications extends YorksV1NotificationsNotifier {
  _ServerNotifications()
    : super(client: null, repository: null, authUserId: 'owner') {
    state = const AsyncData([]);
  }
  final markedIds = <String>[];
  void publish(List<YorksV1NotificationRecord> records) {
    state = AsyncData([...records, ...?state.valueOrNull]);
  }

  @override
  Future<void> markSeen(String notificationId) async {
    markedIds.add(notificationId);
  }
}

class _Preferences extends YorksV1NotificationPreferencesNotifier {
  _Preferences() : super(repository: null);
  void loading() => state = const AsyncLoading();
  void update({bool? foreground, bool? sound}) => state = AsyncData(
    state.requireValue.copyWith(
      foregroundAlertsEnabled: foreground,
      soundEnabled: sound,
    ),
  );
}

class _Audio {
  final _preparation = Completer<bool>();
  int prepares = 0;
  int plays = 0;
  bool useImmediatePreparation = false;

  Future<bool> prepare() {
    prepares++;
    return useImmediatePreparation ? Future.value(true) : _preparation.future;
  }

  Future<void> play() async => plays++;
  void complete(bool prepared) => _preparation.complete(prepared);
  void cancelPreparation() {
    if (!_preparation.isCompleted) _preparation.complete(false);
  }
}

YorksV1NotificationRecord _workflow(String id) => YorksV1NotificationRecord(
  id: id,
  eventCode: 'material_request_approval_required',
  entityType: 'material_request',
  entityId: 'request-$id',
  requestId: 'request-$id',
  createdAt: clock.now(),
);

YorksV1NotificationRecord _chat(
  String id, {
  String conversation = 'conversation-2',
}) => YorksV1NotificationRecord(
  id: id,
  eventCode: 'team_chat_message',
  entityType: 'chat_message',
  entityId: 'message-$id',
  chatConversationId: conversation,
  createdAt: clock.now(),
);

AppUser _user(String id) => AppUser(
  id: id,
  fullName: 'Owner',
  email: '$id@example.invalid',
  role: UserRole.admin,
  createdAt: DateTime(2026, 10, 1),
);

Future<void> _loadFonts() async {
  final font = FontLoader('NexusSans')
    ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
  var directory = File(Platform.resolvedExecutable).parent;
  for (var level = 0; level < 8; level++) {
    if (directory.path.endsWith('${Platform.pathSeparator}cache')) {
      final bytes = await File(
        '${directory.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes();
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await Future.wait([font.load(), icons.load()]);
      return;
    }
    directory = directory.parent;
  }
  throw StateError('Could not locate Flutter material fonts');
}
