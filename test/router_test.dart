import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/app/router.dart';
import 'package:material_ledger/shared/models/app_user.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';

/// `GoRouter` validates its whole route tree at construction (duplicate paths,
/// malformed nested sub-routes, etc. throw immediately). Building it for every
/// role therefore validates the engineer `StatefulShellRoute` and the top-level
/// create-flows (`/new-request`, `/projects/new`, `/my-projects`) that overlay
/// it — plus the office shell — without a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('project workspace path uses the stable project identifier', () {
    expect(
      RoutePaths.projectWorkspacePath('project-41'),
      '/projects/project-41',
    );
  });

  group('createAppRouter builds a valid tree for every role', () {
    for (final role in UserRole.values) {
      test('role: ${role.name}', () {
        final router = createAppRouter(
          isOnboarded: true,
          isLoggedIn: true,
          role: role,
        );
        addTearDown(router.dispose);
        expect(router.configuration.routes, isNotEmpty);
      });
    }
  });

  testWidgets(
    'V1 Procurement project deep links land on an office-shell safe route',
    (tester) async {
      final router = createAppRouter(
        isOnboarded: true,
        isLoggedIn: true,
        role: UserRole.procurement,
        user: AppUser(
          id: 'procurement-user',
          fullName: 'Procurement User',
          email: 'procurement@yorks.test',
          role: UserRole.procurement,
          createdAt: DateTime.utc(2026, 8, 1),
        ),
        yorksV1ProjectsEnabled: true,
        yorksV1BoqEnabled: true,
        yorksV1RequestsEnabled: true,
        yorksV1ArrangementEnabled: true,
        yorksV1LogisticsEnabled: true,
        yorksV1ReturnsDocumentsEnabled: true,
        yorksV1DocumentsEnabled: true,
        yorksV1Role: YorksV1Role.procurement,
      );
      addTearDown(router.dispose);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      // The retained splash has a chained handoff animation. Let it finish
      // before exercising a V1 deep link so no disposed splash timer remains.
      await tester.pumpAndSettle(const Duration(seconds: 5));

      router.go(RoutePaths.engineerCreateProject);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        RoutePaths.engineerHome,
      );

      router.go(RoutePaths.engineerProjects);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        RoutePaths.engineerHome,
      );

      router.go(RoutePaths.procurement);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        RoutePaths.engineerHome,
      );

      router.go(RoutePaths.adminRequests);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        RoutePaths.engineerHome,
      );

      router.go(RoutePaths.yorksV1ProjectEditPath('project-1'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        RoutePaths.engineerHome,
      );

      router.go(RoutePaths.yorksV1DuctSizer);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        RoutePaths.engineerHome,
      );

      router.go(RoutePaths.activityLog);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        RoutePaths.engineerHome,
      );
    },
  );

  testWidgets(
    'V1 Project and Site Engineers cannot reach retained project routes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      for (final v1Role in [
        YorksV1Role.projectEngineer,
        YorksV1Role.siteEngineer,
        YorksV1Role.seniorMechanicalEngineer,
        YorksV1Role.projectManager,
      ]) {
        final router = createAppRouter(
          isOnboarded: true,
          isLoggedIn: true,
          role: UserRole.engineer,
          user: AppUser(
            id: '${v1Role.name}-user',
            fullName: '${v1Role.name} User',
            email: '${v1Role.name}@yorks.test',
            role: UserRole.engineer,
            createdAt: DateTime.utc(2026, 8, 1),
          ),
          yorksV1ProjectsEnabled: true,
          yorksV1BoqEnabled: true,
          yorksV1RequestsEnabled: true,
          yorksV1ArrangementEnabled: true,
          yorksV1LogisticsEnabled: true,
          yorksV1ReturnsDocumentsEnabled: true,
          yorksV1DocumentsEnabled: true,
          yorksV1Role: v1Role,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 5));

        for (final path in [
          RoutePaths.engineerProjects,
          RoutePaths.engineerProjectsView,
          RoutePaths.projectWorkspacePath('legacy-project'),
          RoutePaths.planReviewPath('legacy-project'),
          RoutePaths.planBuildPath('legacy-project'),
          RoutePaths.planDiffPath('legacy-project'),
          RoutePaths.engineerNewRequest,
          RoutePaths.engineerPickMaterials,
          RoutePaths.requests,
          RoutePaths.requestDetailPath('legacy-request'),
          RoutePaths.confirmReceiptPath('legacy-request'),
          RoutePaths.returnStore,
          RoutePaths.yorksV1Inventory,
          RoutePaths.yorksV1Dispatches,
          RoutePaths.activityLog,
        ]) {
          router.go(path);
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.path,
            RoutePaths.engineerHome,
            reason: '${v1Role.name} must not enter $path while V1 is enabled',
          );
        }

        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
    },
  );

  testWidgets('V1 Admin cannot deep link to deferred Accounts', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final router = createAppRouter(
      isOnboarded: true,
      isLoggedIn: true,
      role: UserRole.admin,
      user: AppUser(
        id: 'admin-user',
        fullName: 'Admin User',
        email: 'admin@yorks.test',
        role: UserRole.admin,
        createdAt: DateTime.utc(2026, 8, 1),
      ),
      yorksV1ProjectsEnabled: true,
      yorksV1Role: YorksV1Role.admin,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));

    router.go(RoutePaths.finance);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      RoutePaths.engineerHome,
    );
  });

  testWidgets(
    'only Senior Mechanical Engineer among engineering roles can open User Management',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      for (final v1Role in [
        YorksV1Role.seniorMechanicalEngineer,
        YorksV1Role.projectManager,
      ]) {
        final router = createAppRouter(
          isOnboarded: true,
          isLoggedIn: true,
          role: UserRole.engineer,
          user: AppUser(
            id: v1Role.claimValue,
            fullName: v1Role.name,
            email: '${v1Role.claimValue}@yorks.test',
            role: UserRole.engineer,
            createdAt: DateTime.utc(2026, 8, 9),
          ),
          yorksV1ProjectsEnabled: true,
          yorksV1Role: v1Role,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        router.go(RoutePaths.users);
        await tester.pumpAndSettle();

        expect(
          router.routeInformationProvider.value.uri.path,
          v1Role == YorksV1Role.seniorMechanicalEngineer
              ? RoutePaths.users
              : RoutePaths.engineerHome,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
    },
  );
}
