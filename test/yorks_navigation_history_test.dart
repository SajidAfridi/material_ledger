import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/router.dart';
import 'package:material_ledger/app/yorks_navigation_history.dart';
import 'package:material_ledger/app/yorks_v1_workspace_shell.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/app_strings.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_shell_strings.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_feature_flags_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('root workspace destinations have predictable Back history', () {
    final history = YorksNavigationHistoryNotifier();
    history.record('/yorks/overview');
    history.record('/yorks/rentals');

    expect(history.state.canGoBack('/yorks/rentals'), isTrue);
    expect(history.takePrevious('/yorks/rentals'), '/yorks/overview');
    expect(history.state.locations, ['/yorks/overview']);
    expect(history.state.canGoBack('/yorks/overview'), isFalse);
    expect(history.state.canGoForward('/yorks/overview'), isTrue);
    expect(history.takeNext('/yorks/overview'), '/yorks/rentals');
    expect(history.state.locations, ['/yorks/overview', '/yorks/rentals']);
    expect(history.state.forwardLocations, isEmpty);
  });

  test('Back skips duplicates and strips transient notification metadata', () {
    final history = YorksNavigationHistoryNotifier();
    history.record('/yorks/overview');
    history.record('/yorks/projects?notificationId=temporary&filter=open');
    history.record('/yorks/projects?filter=open');

    expect(history.state.locations, [
      '/yorks/overview',
      '/yorks/projects?filter=open',
    ]);
    expect(
      history.takePrevious('/yorks/projects?filter=open'),
      '/yorks/overview',
    );
  });

  test('history remains bounded during a long session', () {
    final history = YorksNavigationHistoryNotifier();
    for (var index = 0; index < 40; index += 1) {
      history.record('/yorks/projects/$index');
    }

    expect(history.state.locations, hasLength(30));
    expect(history.state.locations.first, '/yorks/projects/10');
    expect(history.state.locations.last, '/yorks/projects/39');
  });

  test('repeated Back and Forward keep a coherent two-way history', () {
    final history = YorksNavigationHistoryNotifier();
    history.record('/yorks/overview');
    history.record('/yorks/projects');
    history.record('/yorks/projects/project-1/accounts/overview');

    expect(
      history.takePrevious('/yorks/projects/project-1/accounts/overview'),
      '/yorks/projects',
    );
    expect(history.state.locations, ['/yorks/overview', '/yorks/projects']);
    expect(history.state.forwardLocations, [
      '/yorks/projects/project-1/accounts/overview',
    ]);

    expect(history.takePrevious('/yorks/projects'), '/yorks/overview');
    expect(history.state.locations, ['/yorks/overview']);
    expect(history.state.forwardLocations, [
      '/yorks/projects/project-1/accounts/overview',
      '/yorks/projects',
    ]);

    expect(history.takeNext('/yorks/overview'), '/yorks/projects');
    expect(history.state.locations, ['/yorks/overview', '/yorks/projects']);
    expect(history.state.forwardLocations, [
      '/yorks/projects/project-1/accounts/overview',
    ]);

    expect(
      history.takeNext('/yorks/projects'),
      '/yorks/projects/project-1/accounts/overview',
    );
    expect(history.state.forwardLocations, isEmpty);
  });

  test('a new navigation after Back clears the stale Forward branch', () {
    final history = YorksNavigationHistoryNotifier();
    history.record('/yorks/overview');
    history.record('/yorks/rentals');
    expect(history.takePrevious('/yorks/rentals'), '/yorks/overview');

    history.record('/yorks/projects');

    expect(history.state.locations, ['/yorks/overview', '/yorks/projects']);
    expect(history.state.forwardLocations, isEmpty);
  });

  testWidgets(
    'desktop Back, Forward and system Back preserve the workspace journey',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final router = GoRouter(
        initialLocation: RoutePaths.engineerHome,
        routes: [
          GoRoute(
            path: RoutePaths.engineerHome,
            builder: (_, _) => const YorksV1WorkspaceShell(
              child: Scaffold(body: Text('Overview content')),
            ),
          ),
          GoRoute(
            path: RoutePaths.rentals,
            builder: (_, _) => const YorksV1WorkspaceShell(
              child: Scaffold(body: Text('Rentals content')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.admin),
            yorksV1FeatureFlagsProvider.overrideWithValue(
              const YorksV1FeatureFlags(
                foundation: true,
                projects: true,
                boq: true,
                excel: true,
                requests: true,
                arrangement: true,
                logistics: true,
                returnsDocuments: true,
                documents: true,
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      router.go(RoutePaths.rentals);
      await tester.pumpAndSettle();
      expect(find.text('Rentals content'), findsOneWidget);
      final back = find.byKey(const ValueKey('yorks-workspace-back'));
      expect(tester.widget<IconButton>(back).onPressed, isNotNull);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');

      final forward = find.byKey(const ValueKey('yorks-workspace-forward'));
      expect(tester.widget<IconButton>(forward).onPressed, isNotNull);
      await tester.tap(forward);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        RoutePaths.rentals,
      );

      await tester.pumpAndSettle();
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(tester.widget<IconButton>(forward).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'project Accounts keeps Projects selected and supports Back and Forward',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      const projectId = 'project-1';
      final projectPath = RoutePaths.yorksV1ProjectPath(projectId);
      final accountsPath = RoutePaths.yorksV1ProjectAccountsOverviewPath(
        projectId,
      );
      final router = GoRouter(
        initialLocation: projectPath,
        routes: [
          GoRoute(
            path: projectPath,
            builder: (_, _) => const YorksV1WorkspaceShell(
              child: Scaffold(body: Text('Project overview content')),
            ),
          ),
          GoRoute(
            path: accountsPath,
            builder: (_, _) => const YorksV1WorkspaceShell(
              child: Scaffold(body: Text('Project Accounts content')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.admin),
            yorksV1FeatureFlagsProvider.overrideWithValue(
              const YorksV1FeatureFlags(
                foundation: true,
                projects: true,
                boq: true,
                excel: true,
                requests: true,
                arrangement: true,
                logistics: true,
                returnsDocuments: true,
                documents: true,
                accounts: true,
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      router.go(accountsPath);
      await tester.pumpAndSettle();
      expect(find.text('Project Accounts content'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  YorksV1ShellStrings.projects.active(AppLanguage.english) &&
              widget.properties.selected == true,
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('yorks-workspace-back')));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, projectPath);

      await tester.tap(find.byKey(const ValueKey('yorks-workspace-forward')));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, accountsPath);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected language reaches desktop chrome and mobile navigation',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'selected_language': 'ar'});
      final preferences = await SharedPreferences.getInstance();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const YorksV1WorkspaceShell(
              child: Scaffold(body: Text('Overview content')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.admin),
            yorksV1FeatureFlagsProvider.overrideWithValue(
              const YorksV1FeatureFlags(
                foundation: true,
                projects: true,
                boq: true,
                excel: true,
                requests: true,
                arrangement: true,
                logistics: true,
                returnsDocuments: true,
                documents: true,
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(YorksV1ShellStrings.companyName.active(AppLanguage.arabic)),
        findsWidgets,
      );
      expect(
        find.text(
          YorksV1ShellStrings.rentalProperties.active(AppLanguage.arabic),
        ),
        findsOneWidget,
      );

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.home.active(AppLanguage.arabic)),
        findsWidgets,
      );
      expect(
        find.text(AppStrings.more.active(AppLanguage.arabic)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
