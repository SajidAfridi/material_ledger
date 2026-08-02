import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/yorks_v1_workspace_shell.dart';
import 'package:material_ledger/features/engineering_tools/presentation/screens/yorks_v1_engineering_calculator_screens.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_material_request_screens.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_provider.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final entry in <({String name, Widget child, String expected})>[
    (
      name: 'material requests',
      child: YorksV1MaterialRequestsScreen(),
      expected: 'Material Requests',
    ),
    (
      name: 'duct sizer',
      child: YorksV1DuctSizerScreen(),
      expected: 'Duct Sizer',
    ),
    (
      name: 'ESP calculator',
      child: YorksV1EspCalculatorScreen(),
      expected: 'ESP Calculator',
    ),
  ]) {
    testWidgets(
      'R35 ${entry.name} route stays laid out at desktop and mobile widths',
      (tester) async {
        final preferences = await SharedPreferences.getInstance();
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => YorksV1WorkspaceShell(child: entry.child),
            ),
          ],
        );

        for (final size in [
          const Size(1366, 768),
          const Size(1024, 768),
          const Size(360, 800),
        ]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(preferences),
                yorksV1CurrentRoleProvider.overrideWithValue(
                  YorksV1Role.projectEngineer,
                ),
                yorksV1MaterialRequestListProvider(
                  null,
                ).overrideWith((ref) async => []),
              ],
              child: MaterialApp.router(routerConfig: router),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(entry.expected), findsWidgets);
          expect(tester.takeException(), isNull, reason: 'viewport $size');
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  }

  testWidgets(
    'R35 material requests shows a recoverable state without backend',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final preferences = await SharedPreferences.getInstance();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const YorksV1WorkspaceShell(
              child: YorksV1MaterialRequestsScreen(),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            yorksV1CurrentRoleProvider.overrideWithValue(
              YorksV1Role.projectEngineer,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Material Requests'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'R35 new material request draft stays laid out at desktop and mobile widths',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const YorksV1WorkspaceShell(
              child: YorksV1MaterialRequestDraftScreen(
                draftId: 'layout-test-draft',
              ),
            ),
          ),
        ],
      );

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final size in [
        const Size(1366, 768),
        const Size(1024, 768),
        const Size(360, 800),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
              yorksV1AuthUserIdProvider.overrideWithValue('layout-test-user'),
              yorksV1CurrentRoleProvider.overrideWithValue(
                YorksV1Role.projectEngineer,
              ),
              yorksV1MaterialRequestDraftProjectsProvider.overrideWith(
                (ref) async => [],
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Request Information'), findsWidgets);
        expect(tester.takeException(), isNull, reason: 'viewport $size');
      }
    },
  );
}
