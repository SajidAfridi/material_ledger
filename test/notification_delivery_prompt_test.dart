import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/shared/models/app_user.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_notification_preferences_provider.dart';
import 'package:material_ledger/shared/services/push_service.dart';
import 'package:material_ledger/shared/widgets/notification_delivery_prompt.dart';
import 'package:material_ledger/shared/widgets/notification_delivery_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadGoldenFonts);

  testWidgets(
    'signed-in unregistered installation receives global enrollment action',
    (tester) async {
      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final push = _FakePushService();
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      addTearDown(push.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(_signedInUser),
            pushServiceProvider.overrideWithValue(push),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: const MaterialApp(
            home: NotificationDeliveryPrompt(
              child: Scaffold(body: Center(child: Text('Workspace'))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enable device alerts'), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(push.enableCalls, 1);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Workspace'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('prompt is absent while signed out', (tester) async {
    final push = _FakePushService();
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    addTearDown(push.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushServiceProvider.overrideWithValue(push),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(
          home: NotificationDeliveryPrompt(
            child: Scaffold(body: Text('Signed out')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Enable device alerts'), findsNothing);
    expect(find.text('Signed out'), findsOneWidget);
  });

  for (final useBanner in [false, true]) {
    testWidgets(
      '${useBanner ? 'optional banner' : 'delivery card'} tolerates removal during enrollment',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final completion = Completer<PushDeliveryStatus>();
        final push = _FakePushService()..enableCompletion = completion;
        addTearDown(push.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWithValue(_signedInUser),
              pushServiceProvider.overrideWithValue(push),
              sharedPreferencesProvider.overrideWithValue(preferences),
              yorksV1NotificationSoundEnabledProvider.overrideWithValue(false),
            ],
            child: MaterialApp(
              home: useBanner
                  ? const NotificationDeliveryPrompt(child: Scaffold())
                  : const Scaffold(body: NotificationDeliveryCard()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          useBanner ? find.byType(FilledButton) : find.byType(OutlinedButton),
        );
        await tester.pump();
        expect(push.enableCalls, 1);
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        completion.complete(
          const PushDeliveryStatus(
            authorization: PushAuthorizationState.authorized,
            deviceRegistered: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('blocked permission has a working recovery action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final push = _FakePushService(
      const PushDeliveryStatus(authorization: PushAuthorizationState.denied),
    );
    addTearDown(push.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_signedInUser),
          pushServiceProvider.overrideWithValue(push),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(
          home: NotificationDeliveryPrompt(child: Scaffold()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Device alerts are blocked'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(push.enableCalls, 1);
    expect(find.text('Device alerts are blocked'), findsNothing);
  });

  testWidgets('authorized but unregistered installation remains recoverable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final push = _FakePushService(
      const PushDeliveryStatus(
        authorization: PushAuthorizationState.authorized,
      ),
    );
    addTearDown(push.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_signedInUser),
          pushServiceProvider.overrideWithValue(push),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(
          home: NotificationDeliveryPrompt(child: Scaffold()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alert setup needs attention'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
  });

  testWidgets('unsupported installation keeps in-app UI unobstructed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final push = _FakePushService(const PushDeliveryStatus.unsupported());
    addTearDown(push.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_signedInUser),
          pushServiceProvider.overrideWithValue(push),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(
          home: NotificationDeliveryPrompt(
            child: Scaffold(body: Text('Native workspace')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Native workspace'), findsOneWidget);
  });

  testWidgets(
    'preview explains its enrollment boundary without iOS instructions',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final push = _FakePushService(
        const PushDeliveryStatus.unsupported('WEB_ORIGIN_NOT_ENROLLED'),
      );
      addTearDown(push.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(_signedInUser),
            pushServiceProvider.overrideWithValue(push),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: const MaterialApp(
            home: Scaffold(body: NotificationDeliveryCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Device alerts are available on the main Yorks site. Your notification history remains available here.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('On iPhone or iPad'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final evidence in <({String name, Size size})>[
    (
      name: 'notification_enrollment_mobile_360.png',
      size: const Size(360, 800),
    ),
    (name: 'notification_enrollment_desktop.png', size: const Size(1366, 768)),
  ]) {
    testWidgets('global alert enrollment evidence — ${evidence.size}', (
      tester,
    ) async {
      tester.view.physicalSize = evidence.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final push = _FakePushService();
      addTearDown(push.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(_signedInUser),
            pushServiceProvider.overrideWithValue(push),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const NotificationDeliveryPrompt(
              child: Scaffold(
                body: Center(child: Text('Authorized workspace content')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enable device alerts'), findsNWidgets(2));
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(44),
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(NotificationDeliveryPrompt),
        matchesGoldenFile('goldens/r35/${evidence.name}'),
      );
    });
  }
}

Future<void> _loadGoldenFonts() async {
  final nexus = FontLoader('NexusSans')
    ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
  final cache = _flutterCacheDirectory();
  final icons = await File(
    '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytes();
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(icons)));
  await Future.wait([nexus.load(), materialIcons.load()]);
}

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

final _signedInUser = AppUser(
  id: 'user-1',
  fullName: 'Test User',
  email: 'test@yorks.invalid',
  role: UserRole.admin,
  createdAt: DateTime(2026, 8, 20),
);

class _FakePushService implements PushService {
  _FakePushService([
    this._status = const PushDeliveryStatus(
      authorization: PushAuthorizationState.notDetermined,
    ),
  ]);

  final _statusController = StreamController<PushDeliveryStatus>.broadcast();
  PushDeliveryStatus _status;
  int enableCalls = 0;
  Completer<PushDeliveryStatus>? enableCompletion;

  @override
  Stream<PushMessage> get onMessage => const Stream.empty();

  @override
  Stream<PushDeliveryStatus> get onStatus => _statusController.stream;

  @override
  PushDeliveryStatus get status => _status;

  @override
  Future<PushDeliveryStatus> enable() async {
    enableCalls += 1;
    if (enableCompletion case final completion?) return completion.future;
    _status = const PushDeliveryStatus(
      authorization: PushAuthorizationState.authorized,
      deviceRegistered: true,
    );
    _statusController.add(_status);
    return _status;
  }

  @override
  Future<String?> register() async => null;

  void dispose() => _statusController.close();
}
