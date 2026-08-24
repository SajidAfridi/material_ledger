import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/yorks_v1_workspace_shell.dart';
import 'package:material_ledger/features/login/presentation/screens/login_screen.dart';
import 'package:material_ledger/shared/models/app_strings.dart';
import 'package:material_ledger/shared/models/yorks_v1_permission_management.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_shell_strings.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_permission_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_permission_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('R35 procurement workspace shell renders desktop navigation', (
    tester,
  ) async {
    _setViewport(tester, const Size(1366, 768));
    addTearDown(() => _resetViewport(tester));

    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _ShellTestApp(role: YorksV1Role.procurement, preferences: preferences),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(YorksV1ShellStrings.companyName.primary),
      findsAtLeastNWidgets(2),
    );
    expect(
      find.text(YorksV1ShellStrings.browseInventory.primary),
      findsOneWidget,
    );
    expect(find.text(YorksV1ShellStrings.viewOnly.primary), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('R35 workspace shell retains a safe mobile operational nav', (
    tester,
  ) async {
    _setViewport(tester, const Size(360, 800));
    addTearDown(() => _resetViewport(tester));
    final semantics = tester.ensureSemantics();

    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _ShellTestApp(
        role: YorksV1Role.projectEngineer,
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    final destinations = [
      AppStrings.home.primary,
      YorksV1ShellStrings.projects.primary,
      YorksV1ShellStrings.materialRequests.primary,
      AppStrings.more.primary,
    ];
    final bounds = <Rect>[];
    for (final destination in destinations) {
      final item = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == destination,
      );
      expect(item, findsOneWidget);
      bounds.add(tester.getRect(item));
    }
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == AppStrings.more.primary,
      ),
      findsOneWidget,
    );
    expect(bounds.map((rect) => rect.top).toSet(), hasLength(1));
    expect(bounds.map((rect) => rect.bottom).toSet(), hasLength(1));
    for (final rect in bounds) {
      expect(rect.width, greaterThanOrEqualTo(44));
      expect(rect.height, greaterThanOrEqualTo(44));
      expect(rect.bottom, lessThanOrEqualTo(800));
    }
    for (var index = 1; index < bounds.length; index++) {
      expect((bounds[index].width - bounds.first.width).abs(), lessThan(0.1));
    }
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
    'connected shell verifies first snapshot without painting child or nav',
    (tester) async {
      _setViewport(tester, const Size(360, 800));
      addTearDown(() => _resetViewport(tester));
      final preferences = await SharedPreferences.getInstance();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final controller = YorksV1CurrentPermissionSnapshotController(
        enabled: true,
        authUserId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        client: null,
        repository: _PendingPermissionRepository(),
        revisionSignalSubscription:
            ({required onSignal, required onUnavailable}) async => false,
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const YorksV1WorkspaceShell(
              child: SizedBox(key: ValueKey('protected-workspace-child')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            supabaseClientProvider.overrideWithValue(client),
            yorksV1CurrentRoleProvider.overrideWithValue(
              YorksV1Role.projectEngineer,
            ),
            yorksV1CurrentPermissionSnapshotProvider.overrideWith(
              (ref) => controller,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('yorks-permission-verification-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('protected-workspace-child')),
        findsNothing,
      );
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Senior Mechanical Engineer sees approved user configuration and read-only inventory destinations',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      for (final size in [const Size(1366, 768), const Size(360, 800)]) {
        _setViewport(tester, size);
        await tester.pumpWidget(
          _ShellTestApp(
            role: YorksV1Role.seniorMechanicalEngineer,
            preferences: preferences,
          ),
        );
        await tester.pumpAndSettle();

        if (size.width <= 1000) {
          await tester.tap(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label == AppStrings.more.primary,
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(
          find.text(YorksV1ShellStrings.userManagement.primary),
          findsOneWidget,
        );
        expect(
          find.text(YorksV1ShellStrings.browseInventory.primary),
          findsOneWidget,
        );
        expect(
          find.text(YorksV1ShellStrings.viewOnly.primary),
          size.width > 1000 ? findsOneWidget : findsNothing,
        );
        expect(
          find.text(YorksV1ShellStrings.configuration.primary),
          findsNothing,
        );
        expect(find.text(YorksV1ShellStrings.auditTrail.primary), findsNothing);
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/logo.png'),
            tester.element(find.byType(YorksV1WorkspaceShell)),
          ),
        );
        await tester.pump();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            size.width > 1000
                ? 'goldens/r35/senior_user_management_nav_desktop.png'
                : 'goldens/r35/senior_user_management_nav_mobile.png',
          ),
        );
        expect(tester.takeException(), isNull);
      }
      addTearDown(() => _resetViewport(tester));
    },
  );

  testWidgets(
    'Workshop In-Charge and Document Controller use the global engineering workspace',
    (tester) async {
      _setViewport(tester, const Size(1366, 768));
      addTearDown(() => _resetViewport(tester));
      final preferences = await SharedPreferences.getInstance();

      for (final role in [
        YorksV1Role.workshopInCharge,
        YorksV1Role.documentController,
      ]) {
        await tester.pumpWidget(
          _ShellTestApp(role: role, preferences: preferences),
        );
        await tester.pumpAndSettle();

        expect(find.text(YorksV1ShellStrings.projects.primary), findsOneWidget);
        expect(
          find.text(YorksV1ShellStrings.materialRequests.primary),
          findsOneWidget,
        );
        expect(
          find.text(YorksV1ShellStrings.browseInventory.primary),
          findsNothing,
        );
        expect(
          find.text(YorksV1ShellStrings.userManagement.primary),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('R35 workspace search opens a navigable command palette', (
    tester,
  ) async {
    _setViewport(tester, const Size(1366, 768));
    addTearDown(() => _resetViewport(tester));

    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _ShellTestApp(
        role: YorksV1Role.projectEngineer,
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(YorksV1ShellStrings.searchOrJump.primary));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(YorksV1ShellStrings.searchHint.primary), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Projects');
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text(YorksV1ShellStrings.projects.primary), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop sidebar contracts immediately and can be reopened', (
    tester,
  ) async {
    _setViewport(tester, const Size(1366, 768));
    addTearDown(() => _resetViewport(tester));

    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _ShellTestApp(role: YorksV1Role.procurement, preferences: preferences),
    );
    await tester.pumpAndSettle();

    expect(
      find.byTooltip(YorksV1ShellStrings.collapsePanel.primary),
      findsOneWidget,
    );
    expect(
      find.text(YorksV1ShellStrings.browseInventory.primary),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip(YorksV1ShellStrings.collapsePanel.primary));
    await tester.pump();

    expect(
      find.byTooltip(YorksV1ShellStrings.expandPanel.primary),
      findsOneWidget,
    );
    expect(
      find.text(YorksV1ShellStrings.browseInventory.primary),
      findsNothing,
    );

    await tester.tap(find.byTooltip(YorksV1ShellStrings.expandPanel.primary));
    await tester.pump();
    expect(
      find.text(YorksV1ShellStrings.browseInventory.primary),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Yorks R35 sign-in remains usable at mobile and desktop widths', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    for (final size in [const Size(360, 800), const Size(1366, 768)]) {
      _setViewport(tester, size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          size.width <= 720
              ? AppStrings.signIn.primary
              : YorksV1ShellStrings.secureAccess.primary.toUpperCase(),
        ),
        findsOneWidget,
      );
      expect(
        find.text(YorksV1ShellStrings.companyEmail.primary),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    addTearDown(() => _resetViewport(tester));
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
}

void _resetViewport(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

class _ShellTestApp extends StatelessWidget {
  const _ShellTestApp({required this.role, required this.preferences});

  final YorksV1Role role;
  final SharedPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const YorksV1WorkspaceShell(
            child: Scaffold(body: SizedBox.expand()),
          ),
        ),
        GoRoute(
          path: '/yorks/more',
          builder: (_, _) =>
              const YorksV1WorkspaceShell(child: YorksV1MobileMoreScreen()),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        yorksV1CurrentRoleProvider.overrideWithValue(role),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }
}

class _PendingPermissionRepository implements YorksV1PermissionRepository {
  @override
  Future<YorksV1CurrentPermissionSnapshot> getCurrentSnapshot() =>
      Completer<YorksV1CurrentPermissionSnapshot>().future;

  @override
  Future<YorksV1UserAdminOptions> getUserAdminOptions({
    String? targetAppUserId,
  }) => throw UnimplementedError();

  @override
  Future<YorksV1UserPermissionWorkspace> getUserWorkspace({
    required String targetAppUserId,
  }) => throw UnimplementedError();

  @override
  Future<YorksV1UserPermissionWorkspace> setAssignment(
    YorksV1SetPermissionAssignmentInput input,
  ) => throw UnimplementedError();

  @override
  Future<YorksV1UserPermissionWorkspace> clearAssignment(
    YorksV1ClearPermissionAssignmentInput input,
  ) => throw UnimplementedError();

  @override
  Future<YorksV1UserPermissionWorkspace> applyChanges(
    YorksV1ApplyPermissionChangesInput input,
  ) => throw UnimplementedError();

  @override
  Future<YorksV1PermissionHistoryPage> listHistory(
    YorksV1PermissionHistoryQuery query,
  ) => throw UnimplementedError();
}
