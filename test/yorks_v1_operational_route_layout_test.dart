import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/yorks_v1_workspace_shell.dart';
import 'package:material_ledger/features/engineering_tools/presentation/screens/yorks_v1_engineering_calculator_screens.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_material_request_screens.dart';
import 'package:material_ledger/features/projects/presentation/screens/yorks_v1_projects_screen.dart';
import 'package:material_ledger/shared/models/yorks_v1_boq.dart';
import 'package:material_ledger/shared/models/yorks_v1_document.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_project.dart';
import 'package:material_ledger/shared/models/yorks_v1_project_portfolio.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_boq_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_documents_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_portfolio_provider.dart';
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

  testWidgets(
    'R35 submitted material request record stays laid out at desktop and mobile widths',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      final request = YorksV1MaterialRequest(
        id: 'layout-detail',
        projectId: 'project-layout',
        projectReference: 'YRA-123',
        projectName: 'Yorks Tower',
        scopeId: 'common',
        scopeName: 'Common / All Buildings',
        state: YorksV1MaterialRequestState.submitted,
        recordVersion: 1,
        createdAt: DateTime.utc(2026, 8, 3),
        updatedAt: DateTime.utc(2026, 8, 3),
        timing: YorksV1MaterialRequestTiming.normal,
        requestNumber: 'YRA123-MR101',
        title: 'HVAC materials',
        requesterDisplayName: 'Masaud Khan',
        requesterProjectRole: 'Project Engineer',
        currentActionOwnerRole: 'Procurement',
        lines: const [
          YorksV1MaterialRequestLine(
            id: 'line-layout',
            displayOrder: 1,
            source: YorksV1MaterialRequestLineSource.custom,
            description: 'Insulated ductwork',
            brandOrigin: 'Yorks',
            size: '500 x 300 mm',
            planningModelTag: 'DX-01',
            quantity: '21',
            unit: 'Nos',
          ),
        ],
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const YorksV1WorkspaceShell(
              child: YorksV1MaterialRequestDetailScreen(
                requestId: 'layout-detail',
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
              yorksV1CurrentRoleProvider.overrideWithValue(
                YorksV1Role.projectEngineer,
              ),
              yorksV1MaterialRequestDetailProvider(
                'layout-detail',
              ).overrideWith((ref) async => request),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Request Status'), findsOneWidget);
        expect(
          find.byKey(
            const ValueKey('yorks-v1-controlled-material-request-preview'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: 'viewport $size');
      }
    },
  );

  testWidgets(
    'R35 project workspace overview stays laid out at desktop and mobile widths',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      final portfolioItem = YorksV1ProjectPortfolioItem(
        project: YorksV1Project(
          id: 'project-layout',
          reference: 'YRA-123',
          name: 'Yorks Tower HVAC',
          state: YorksV1ProjectLifecycle.active,
          version: 1,
          createdAt: DateTime.utc(2026, 8, 3),
          updatedAt: DateTime.utc(2026, 8, 3),
          siteLocation: 'Dubai',
        ),
        activeBuildingCount: 1,
        activeProjectEngineerCount: 1,
        activeSiteEngineerCount: 1,
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const YorksV1WorkspaceShell(
              child: YorksV1ProjectWorkspaceScreen(projectId: 'project-layout'),
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
              yorksV1CurrentRoleProvider.overrideWithValue(
                YorksV1Role.projectEngineer,
              ),
              yorksV1ProjectPortfolioProvider.overrideWith(
                (ref) async => [portfolioItem],
              ),
              yorksV1BoqGroupsProvider(
                'project-layout',
              ).overrideWith((ref) async => const <YorksV1BoqGroup>[]),
              yorksV1MaterialRequestListProvider(
                'project-layout',
              ).overrideWith((ref) async => const <YorksV1MaterialRequest>[]),
              yorksV1DocumentWorkspaceProvider('project-layout').overrideWith(
                (ref) async => const YorksV1DocumentWorkspace(
                  projectId: 'project-layout',
                  documents: [],
                  auditEntries: [],
                ),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Yorks Tower HVAC'), findsOneWidget);
        expect(find.text('BOQ GROUPS'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'viewport $size');
      }
    },
  );

  testWidgets(
    'ESP row editor keeps focus while recalculating after each keystroke',
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
              child: YorksV1EspCalculatorScreen(),
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

      final flowField = find.byType(TextFormField).first;
      await tester.ensureVisible(flowField);
      await tester.tap(flowField);
      await tester.pump();
      final focusNode = FocusManager.instance.primaryFocus;
      expect(focusNode, isNotNull);

      await tester.enterText(flowField, '120');
      await tester.pump();

      expect(FocusManager.instance.primaryFocus, same(focusNode));
      expect(tester.widget<TextFormField>(flowField).controller?.text, '120');
      expect(tester.takeException(), isNull);
    },
  );
}
