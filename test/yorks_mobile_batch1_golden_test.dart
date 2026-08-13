import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/yorks_v1_workspace_shell.dart';
import 'package:material_ledger/core/constants/app_colors.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/login/presentation/screens/login_screen.dart';
import 'package:material_ledger/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:material_ledger/features/projects/presentation/screens/yorks_v1_projects_screen.dart';
import 'package:material_ledger/shared/models/app_user.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_portfolio_provider.dart';
import 'package:material_ledger/shared/screens/notifications_screen.dart';
import 'package:material_ledger/shared/services/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _fixtureUser = AppUser(
  id: 'mobile-fixture-user',
  fullName: 'Omar Farooq',
  email: 'omar@yorks.ae',
  role: UserRole.engineer,
  createdAt: DateTime.utc(2026, 1, 1),
  yorksV1RoleCache: YorksV1Role.projectEngineer,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Yorks mobile splash — 390×844', (tester) async {
    await _setViewport(tester, const Size(390, 844));
    final preferences = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await _settleLogo(tester, find.byType(SplashScreen));
    await expectLater(
      find.byType(SplashScreen),
      matchesGoldenFile('goldens/mobile_batch1/splash_390.png'),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Yorks mobile login — 390×844', (tester) async {
    await _pumpLogin(tester, const Size(390, 844));
    expect(find.text('Sign in with SSO'), findsNothing);
    _expectLoginFieldContrast(tester, mobile: true);
    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/mobile_batch1/login_390.png'),
    );
  });

  testWidgets('Yorks mobile login contrast — 360×800', (tester) async {
    await _pumpLogin(tester, const Size(360, 800));
    _expectLoginFieldContrast(tester, mobile: true);
    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/mobile_batch1/login_360.png'),
    );
  });

  testWidgets('Yorks desktop login contrast — 1366×768', (tester) async {
    await _pumpLogin(tester, const Size(1366, 768));
    _expectLoginFieldContrast(tester, mobile: false);
    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/mobile_batch1/login_1366.png'),
    );
  });

  testWidgets('Yorks mobile notifications — 390×844', (tester) async {
    await _setViewport(tester, const Size(390, 844));
    final preferences = await SharedPreferences.getInstance();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const NotificationsScreen()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          pushServiceProvider.overrideWithValue(const NoopPushService()),
          currentUserProvider.overrideWithValue(_fixtureUser),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NotificationsScreen),
      matchesGoldenFile('goldens/mobile_batch1/notifications_390.png'),
    );
  });

  testWidgets('Yorks mobile More hub — 390×844', (tester) async {
    await _setViewport(tester, const Size(390, 844));
    final preferences = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/yorks/more',
      routes: [
        GoRoute(
          path: '/yorks/more',
          builder: (_, _) =>
              const YorksV1WorkspaceShell(child: YorksV1MobileMoreScreen()),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          currentUserProvider.overrideWithValue(_fixtureUser),
          yorksV1CurrentRoleProvider.overrideWithValue(
            YorksV1Role.projectEngineer,
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await _settleLogo(tester, find.byType(YorksV1WorkspaceShell));
    await expectLater(
      find.byType(YorksV1WorkspaceShell),
      matchesGoldenFile('goldens/mobile_batch1/more_390.png'),
    );
  });

  testWidgets('Yorks mobile projects — 390×844', (tester) async {
    await _setViewport(tester, const Size(390, 844));
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          yorksV1CurrentRoleProvider.overrideWithValue(
            YorksV1Role.projectEngineer,
          ),
          yorksV1ProjectPortfolioProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const YorksV1ProjectsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(YorksV1ProjectsScreen),
      matchesGoldenFile('goldens/mobile_batch1/projects_390.png'),
    );
  });
}

Future<void> _pumpLogin(WidgetTester tester, Size size) async {
  await _setViewport(tester, size);
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
  await _settleLogo(tester, find.byType(LoginScreen));
}

void _expectLoginFieldContrast(WidgetTester tester, {required bool mobile}) {
  final editors = tester.widgetList<EditableText>(find.byType(EditableText));
  final decorators = tester.widgetList<InputDecorator>(
    find.byType(InputDecorator),
  );
  expect(editors, hasLength(2));
  expect(decorators, hasLength(2));
  for (final editor in editors) {
    expect(editor.style.color, AppColors.ink);
    expect(editor.cursorColor, AppColors.blue);
  }
  for (final decorator in decorators) {
    expect(
      decorator.decoration.fillColor,
      mobile ? Colors.white : AppColors.surfaceContainerLowest,
    );
    expect(
      decorator.decoration.hintStyle?.color,
      mobile ? AppColors.muted : AppColors.mutedLight,
    );
  }
}

Future<void> _settleLogo(WidgetTester tester, Finder scope) async {
  await tester.runAsync(() async {
    final context = tester.element(scope);
    await precacheImage(const AssetImage('assets/logo.png'), context);
  });
  await tester.pump();
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
