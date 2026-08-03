import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/yorks_v1_workspace_shell.dart';
import 'package:material_ledger/features/login/presentation/screens/login_screen.dart';
import 'package:material_ledger/shared/models/app_strings.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_shell_strings.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _ShellTestApp(
        role: YorksV1Role.projectEngineer,
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(AppStrings.more.primary), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
        find.text(YorksV1ShellStrings.secureAccess.primary.toUpperCase()),
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
