import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/app/app.dart';
import 'package:material_ledger/app/router.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/main.dart' show YorksStartupPage;
import 'package:material_ledger/shared/models/app_user.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/notification_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/services/app_config_service.dart';
import 'package:material_ledger/shared/services/push_service.dart';

const _notificationTarget =
    '/notifications?notificationId=11000000-0000-4000-8000-000000000001';
const _commentTarget =
    '/yorks/material-requests/12000000-0000-4000-8000-000000000001'
    '?comment=13000000-0000-4000-8000-000000000001'
    '&notificationId=11000000-0000-4000-8000-000000000001';
final _hydratedUserProvider = StateProvider<AppUser?>((ref) => null);

AppUser _user({bool mustChangePassword = false, bool active = true}) => AppUser(
  id: 'test-owner',
  fullName: 'Test Owner',
  email: 'owner@yorks.test',
  role: UserRole.admin,
  active: active,
  mustChangePassword: mustChangePassword,
  createdAt: DateTime.utc(2026, 9, 30),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'cold browser hash wins over a root platform fallback and retains metadata',
    () {
      expect(
        initialAppLocation(
          browserUri: Uri.parse('https://staging.yorks.test/#$_commentTarget'),
          platformLocation: '/',
        ),
        _commentTarget,
      );
      expect(
        initialAppLocation(
          browserUri: Uri.parse(
            'https://staging.yorks.test$_notificationTarget',
          ),
          platformLocation: '/',
        ),
        _notificationTarget,
      );
      expect(
        initialAppLocation(platformLocation: _commentTarget),
        _commentTarget,
      );
      expect(initialAppLocation(platformLocation: '/'), isNull);
    },
  );

  test(
    'startup validates internal locations and permits gates with a safe return intent',
    () {
      final gate = guardedReturnLocation('/login', Uri.parse(_commentTarget));
      expect(
        initialAppLocation(browserUri: Uri.parse('https://yorks.test/#$gate')),
        gate,
      );
      for (final unsafe in [
        'https://evil.test',
        '//evil.test',
        '/\\evil.test',
        '/bad\npath',
      ]) {
        expect(
          initialAppLocation(platformLocation: unsafe),
          isNull,
          reason: unsafe,
        );
      }
    },
  );

  testWidgets(
    'captured notification survives bootstrap root publication and restored-session hydration',
    (tester) async {
      tester.platformDispatcher.defaultRouteNameTestValue = _notificationTarget;
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      final captured = captureAppLaunchLocation();
      // The runtime's temporary home Navigator can replace the browser route
      // while preferences / Supabase initialize. The captured launch intent is
      // injected only after those dependencies become ready.
      await tester.pumpWidget(
        YorksStartupPage(
          initialLocation: captured,
          child: const Scaffold(body: Text('Preparing Yorks')),
        ),
      );
      final bootstrapContext = tester.element(find.text('Preparing Yorks'));
      expect(
        ModalRoute.of(bootstrapContext)?.settings.name,
        _notificationTarget,
      );
      expect(tester.takeException(), isNull);
      tester.platformDispatcher.defaultRouteNameTestValue = '/';
      final harness = await _mount(
        tester,
        captured: captured,
        retainedSession: true,
      );
      expect(harness.uri.path, RoutePaths.login);
      expect(harness.uri.queryParameters['returnTo'], _notificationTarget);

      harness.hydrate(_user());
      await tester.pumpAndSettle();
      expect(harness.uri.toString(), _notificationTarget);
      expect(tester.takeException(), isNull);
      await harness.dispose(tester);
    },
  );

  testWidgets(
    'first-run compatibility handoff and fresh sign-in preserve a cold target',
    (tester) async {
      final harness = await _mount(
        tester,
        captured: _notificationTarget,
        onboarded: false,
      );
      expect(harness.container.read(onboardingCompleteProvider), isTrue);
      expect(harness.uri.path, RoutePaths.login);
      expect(harness.uri.queryParameters['returnTo'], _notificationTarget);

      harness.hydrate(_user());
      await harness.container
          .read(authSessionProvider.notifier)
          .setUser('test-owner');
      await tester.pumpAndSettle();
      expect(harness.uri.toString(), _notificationTarget);
      expect(tester.takeException(), isNull);
      await harness.dispose(tester);
    },
  );

  testWidgets(
    'maintenance, mandatory update and password change retain the same cold intent',
    (tester) async {
      final harness = await _mount(
        tester,
        captured: _notificationTarget,
        retainedSession: true,
        maintenance: true,
      );
      expect(harness.uri.path, RoutePaths.maintenance);
      expect(harness.uri.queryParameters['returnTo'], _notificationTarget);

      harness.container
          .read(appConfigProvider.notifier)
          .setMinSupportedBuild(100);
      await tester.pumpAndSettle();
      expect(harness.uri.path, RoutePaths.updateRequired);
      expect(harness.uri.queryParameters['returnTo'], _notificationTarget);
      harness.hydrate(_user(mustChangePassword: true));
      await tester.pumpAndSettle();
      expect(harness.uri.path, RoutePaths.updateRequired);

      harness.container
          .read(appConfigProvider.notifier)
          .setMinSupportedBuild(1);
      await tester.pumpAndSettle();
      expect(harness.uri.path, RoutePaths.maintenance);
      harness.container.read(appConfigProvider.notifier).setMaintenance(false);
      await tester.pumpAndSettle();
      expect(harness.uri.path, RoutePaths.changePassword);
      expect(harness.uri.queryParameters['returnTo'], _notificationTarget);

      harness.hydrate(_user());
      await tester.pumpAndSettle();
      expect(harness.uri.toString(), _notificationTarget);
      expect(tester.takeException(), isNull);
      await harness.dispose(tester);
    },
  );

  testWidgets(
    'hydration and later gate refresh retain exact request, comment and notification identifiers',
    (tester) async {
      final harness = await _mount(
        tester,
        captured: _commentTarget,
        retainedSession: true,
      );
      expect(harness.uri.queryParameters['returnTo'], _commentTarget);
      harness.hydrate(_user());
      await tester.pumpAndSettle();
      expect(harness.uri.toString(), _commentTarget);

      harness.container.read(appConfigProvider.notifier).setMaintenance(true);
      await tester.pumpAndSettle();
      expect(harness.uri.queryParameters['returnTo'], _commentTarget);
      harness.container.read(appConfigProvider.notifier).setMaintenance(false);
      await tester.pumpAndSettle();
      expect(harness.uri.toString(), _commentTarget);
      await harness.dispose(tester);
    },
  );

  testWidgets('capturing a target never bypasses an inactive account guard', (
    tester,
  ) async {
    final harness = await _mount(
      tester,
      captured: _notificationTarget,
      retainedSession: true,
    );
    harness.hydrate(_user(active: false));
    await tester.pumpAndSettle();
    expect(harness.uri.path, RoutePaths.login);
    expect(harness.uri.queryParameters['returnTo'], _notificationTarget);
    expect(tester.takeException(), isNull);
    await harness.dispose(tester);
  });
}

Future<_Harness> _mount(
  WidgetTester tester, {
  required String? captured,
  bool retainedSession = false,
  bool onboarded = true,
  bool maintenance = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_complete': onboarded,
    if (retainedSession) kAuthUserIdPrefKey: 'test-owner',
  });
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      appLaunchLocationProvider.overrideWithValue(captured),
      appVersionProvider.overrideWithValue(
        const AppVersionInfo(version: '1.0.0', build: 35),
      ),
      currentUserProvider.overrideWith(
        (ref) => ref.watch(_hydratedUserProvider),
      ),
      yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.admin),
      pushServiceProvider.overrideWithValue(const NoopPushService()),
      visibleNotificationsProvider.overrideWithValue(const []),
      unreadNotificationCountProvider.overrideWithValue(0),
    ],
  );
  if (maintenance) {
    container.read(appConfigProvider.notifier).setMaintenance(true);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: ref.watch(appRouterProvider),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(container);
}

class _Harness {
  const _Harness(this.container);
  final ProviderContainer container;
  Uri get uri =>
      container.read(appRouterProvider).routeInformationProvider.value.uri;
  void hydrate(AppUser user) =>
      container.read(_hydratedUserProvider.notifier).state = user;
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  }
}
