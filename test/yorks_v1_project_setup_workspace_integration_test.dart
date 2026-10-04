import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/router.dart';
import 'package:material_ledger/app/yorks_navigation_history.dart';
import 'package:material_ledger/app/yorks_v1_workspace_search.dart';
import 'package:material_ledger/app/yorks_v1_workspace_shell.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/projects/presentation/screens/yorks_v1_project_create_flow_screen.dart';
import 'package:material_ledger/features/projects/presentation/screens/yorks_v1_projects_screen.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_permission_management.dart';
import 'package:material_ledger/shared/models/yorks_v1_project_creation_draft.dart';
import 'package:material_ledger/shared/models/yorks_v1_project_strings.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_shell_strings.dart';
import 'package:material_ledger/shared/models/yorks_v1_workspace_search.dart';
import 'package:material_ledger/shared/models/yorks_v1_workspace_status.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/notification_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_feature_flags_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_permission_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_creation_draft_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_portfolio_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_reference_advisory_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_repository_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_setup_navigation_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_team_directory_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_workspace_search_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_workspace_status_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_project_draft_storage_native.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_project_repository.dart';
import 'package:material_ledger/shared/widgets/notification_bell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/yorks_v1_permission_test_support.dart';

const _owner = 'workspace-setup-test-owner';
const _navigationKey = ValueKey('project-setup-workspace-navigation');
const _searchKey = ValueKey('project-setup-workspace-search');
const _drawerKey = ValueKey('yorks-workspace-navigation-drawer');
const _engineerCapabilities = <String>{
  YorksV1CapabilityKeys.projectsView,
  YorksV1CapabilityKeys.projectsCreate,
  YorksV1CapabilityKeys.projectsEdit,
  YorksV1CapabilityKeys.materialRequestsView,
};
const _canonicalEngineerPaths = <String>{
  RoutePaths.engineerHome,
  RoutePaths.yorksV1Projects,
  RoutePaths.yorksV1MaterialRequests,
  RoutePaths.yorksV1DuctSizer,
  RoutePaths.yorksV1EspCalculator,
};

void main() {
  setUpAll(() async {
    final font = FontLoader('NexusSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    await font.load();
  });

  for (final size in [const Size(1536, 1024), const Size(431, 863)]) {
    final platform = size.width >= 1100 ? 'desktop' : 'phone';

    testWidgets(
      '$platform setup retains its geometry and opens real navigation',
      (tester) async {
        final fixture = await _pumpWorkspace(tester, size: size);
        final shell = find.byKey(
          ValueKey(
            'project-setup-${platform == 'desktop' ? 'desktop' : 'mobile'}-shell',
          ),
        );
        expect(tester.getRect(shell), Offset.zero & size);
        expect(find.byKey(_navigationKey), findsOneWidget);
        expect(find.byKey(_searchKey), findsOneWidget);
        expect(find.byType(NotificationBell), findsOneWidget);
        expect(
          find.text(YorksV1ShellStrings.companyName.primary),
          findsOneWidget,
        );
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(NavigationRail), findsNothing);
        expect(
          find.byKey(const ValueKey('yorks-workspace-sidebar-toggle')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('yorks-mobile-navigation')),
          findsNothing,
        );
        expect(
          fixture.container.read(yorksNavigationHistoryProvider).locations,
          [RoutePaths.engineerCreateProject],
        );
        if (platform == 'desktop') {
          final rail = tester.getRect(
            find.byKey(const ValueKey('project-setup-desktop-rail')),
          );
          expect(rail.left, 0);
          expect(rail.top, 56);
        } else {
          final header = tester.getRect(
            find.byKey(const ValueKey('project-setup-mobile-header')),
          );
          expect(header.top, 0);
          expect(header.height, 48);
        }

        await tester.tap(find.byKey(_navigationKey));
        await tester.pumpAndSettle();
        expect(find.byKey(_drawerKey), findsOneWidget);
        expect(
          tester.widget<Drawer>(find.byKey(_drawerKey)).semanticLabel,
          YorksV1ShellStrings.quickNavigation.primary,
        );
        _expectEngineerNavigation(find.byKey(_drawerKey));
        expect(fixture.commands.calls, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$platform header search uses the same permitted canonical destinations',
      (tester) async {
        final fixture = await _pumpWorkspace(tester, size: size);
        await tester.tap(find.byKey(_navigationKey));
        await tester.pumpAndSettle();
        _expectEngineerNavigation(find.byKey(_drawerKey));
        await tester.tapAt(Offset(size.width - 8, 100));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_searchKey));
        await tester.pumpAndSettle();
        final dialog = tester.widget<YorksV1WorkspaceSearchDialog>(
          find.byType(YorksV1WorkspaceSearchDialog),
        );
        expect(
          dialog.targets.map((target) => target.path).toSet(),
          _canonicalEngineerPaths,
        );
        expect(
          dialog.targets.map((target) => target.path),
          isNot(contains(RoutePaths.users)),
        );
        _expectEngineerNavigation(find.byType(YorksV1WorkspaceSearchDialog));
        expect(fixture.commands.calls, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$platform canonical navigation awaits draft acknowledgement and the leave decision',
      (tester) async {
        final fixture = await _pumpWorkspace(tester, size: size);
        final originalDraftId = fixture.container
            .read(yorksV1ProjectSetupCreationDraftProvider(_owner))
            .draftId;
        const proposedName =
            'Unpublished proposal preserved through navigation';
        await tester.enterText(
          find.byKey(const ValueKey('yorks-v1-project-name')),
          proposedName,
        );
        await tester.tap(find.byKey(_navigationKey));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byKey(_drawerKey),
            matching: find.text(YorksV1ShellStrings.projects.primary),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(YorksV1ProjectStrings.leaveSetupTitle.primary),
          findsOneWidget,
        );
        expect(
          fixture.router.routerDelegate.currentConfiguration.uri.path,
          RoutePaths.engineerCreateProject,
        );
        await tester.tap(find.text(YorksV1ProjectStrings.keepWorking.primary));
        await tester.pumpAndSettle();
        expect(find.byType(YorksV1ProjectCreateFlowScreen), findsOneWidget);
        expect(
          fixture.router.routerDelegate.currentConfiguration.uri.path,
          RoutePaths.engineerCreateProject,
        );

        // A declined exit keeps the real drawer available for another deliberate
        // destination selection. The GoRouter onExit invokes the mounted editor.
        await tester.tap(
          find.descendant(
            of: find.byKey(_drawerKey),
            matching: find.text(YorksV1ShellStrings.projects.primary),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(YorksV1ProjectStrings.leaveWithSavedDraft.primary),
        );
        await tester.pumpAndSettle();
        expect(
          fixture.router.routeInformationProvider.value.uri.path,
          RoutePaths.yorksV1Projects,
        );
        expect(find.byType(YorksV1ProjectsScreen), findsOneWidget);
        expect(find.byType(YorksV1ProjectCreateFlowScreen), findsNothing);
        final draft = fixture.container.read(
          yorksV1ProjectSetupCreationDraftProvider(_owner),
        );
        expect(draft.name, proposedName);
        expect(draft.storageState, YorksV1ProjectDraftStorageState.saved);
        expect(draft.acknowledgedRevision, draft.revision);
        expect(
          fixture.container.read(yorksNavigationHistoryProvider).locations,
          [RoutePaths.engineerCreateProject, RoutePaths.yorksV1Projects],
        );

        // Re-enter through the real portfolio action, rather than sending the
        // router a test-only location. Both layouts must resume this draft.
        final create = find
            .descendant(
              of: find.byType(YorksV1ProjectsScreen),
              matching: find.text(YorksV1ProjectStrings.createProject.primary),
            )
            .first;
        await tester.ensureVisible(create);
        await tester.tap(create);
        await tester.pumpAndSettle();
        expect(
          fixture
              .router
              .routerDelegate
              .currentConfiguration
              .last
              .matchedLocation,
          RoutePaths.engineerCreateProject,
        );
        expect(find.byType(YorksV1ProjectCreateFlowScreen), findsOneWidget);
        expect(find.byKey(_navigationKey), findsOneWidget);
        expect(find.byKey(_searchKey), findsOneWidget);
        final name = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const ValueKey('yorks-v1-project-name')),
            matching: find.byType(EditableText),
          ),
        );
        expect(name.controller.text, proposedName);
        final resumed = fixture.container.read(
          yorksV1ProjectSetupCreationDraftProvider(_owner),
        );
        expect(resumed.draftId, originalDraftId);
        expect(resumed.name, proposedName);
        expect(resumed.acknowledgedRevision, resumed.revision);
        expect(
          fixture.container.read(yorksNavigationHistoryProvider).locations,
          [
            RoutePaths.engineerCreateProject,
            RoutePaths.yorksV1Projects,
            RoutePaths.engineerCreateProject,
          ],
        );
        expect(fixture.commands.calls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'connected loading permissions expose only verification, never the setup feature',
    (tester) async {
      final fixture = await _pumpWorkspace(
        tester,
        permission: const YorksV1CurrentPermissionSnapshotState(
          isInitialLoading: true,
        ),
        settle: false,
      );
      expect(
        find.byKey(const ValueKey('yorks-permission-verification-shell')),
        findsOneWidget,
      );
      expect(find.byType(YorksV1ProjectCreateFlowScreen), findsNothing);
      expect(find.byKey(const ValueKey('yorks-v1-project-name')), findsNothing);
      expect(find.byKey(_navigationKey), findsNothing);
      expect(find.byKey(_searchKey), findsNothing);
      expect(find.byKey(_drawerKey), findsNothing);
      expect(fixture.commands.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmed create denial cannot expose an editor through focused workspace chrome',
    (tester) async {
      final fixture = await _pumpWorkspace(
        tester,
        permission: yorksV1TrustedFeaturePermissionState(
          role: YorksV1Role.projectEngineer,
          capabilities: const {YorksV1CapabilityKeys.projectsView},
        ),
      );
      expect(
        find.text(YorksV1ProjectStrings.noPermission.primary),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('yorks-v1-project-name')), findsNothing);
      expect(
        find.byKey(const ValueKey('yorks-v1-project-create')),
        findsNothing,
      );
      expect(find.byKey(_navigationKey), findsNothing);
      expect(find.byKey(_searchKey), findsNothing);
      expect(fixture.commands.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

void _expectEngineerNavigation(Finder surface) {
  for (final label in [
    YorksV1ShellStrings.overview,
    YorksV1ShellStrings.projects,
    YorksV1ShellStrings.materialRequests,
    YorksV1ShellStrings.ductSizer,
    YorksV1ShellStrings.espCalculator,
  ]) {
    expect(
      find.descendant(of: surface, matching: find.text(label.primary)),
      findsOneWidget,
    );
  }
  for (final label in [
    YorksV1ShellStrings.configuration,
    YorksV1ShellStrings.userManagement,
    YorksV1ShellStrings.auditTrail,
  ]) {
    expect(
      find.descendant(of: surface, matching: find.text(label.primary)),
      findsNothing,
    );
  }
}

Future<_WorkspaceFixture> _pumpWorkspace(
  WidgetTester tester, {
  Size size = const Size(1536, 1024),
  YorksV1CurrentPermissionSnapshotState? permission,
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final client = _NoNetworkSupabaseClient();
  final commands = _NoProjectCommands();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      supabaseClientProvider.overrideWithValue(client),
      currentUserProvider.overrideWithValue(null),
      unreadNotificationCountProvider.overrideWithValue(0),
      yorksV1WorkspaceStatusProvider.overrideWithValue(
        const YorksV1WorkspaceStatus(
          state: YorksV1WorkspaceConnectionState.connected,
        ),
      ),
      yorksV1FeatureFlagsProvider.overrideWithValue(
        const YorksV1FeatureFlags(
          foundation: true,
          projects: true,
          projectSetup: true,
          boq: true,
          excel: true,
          requests: true,
          arrangement: true,
          logistics: true,
          returnsDocuments: true,
          documents: true,
        ),
      ),
      yorksV1AuthUserIdProvider.overrideWithValue(_owner),
      yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.projectEngineer),
      yorksV1CurrentPermissionSnapshotProvider.overrideWith(
        (ref) => YorksV1TestPermissionController(
          permission ??
              yorksV1TrustedFeaturePermissionState(
                role: YorksV1Role.projectEngineer,
                capabilities: _engineerCapabilities,
              ),
        ),
      ),
      yorksV1ProjectRepositoryProvider.overrideWithValue(commands),
      yorksV1ProjectDraftAtomicStorageProvider.overrideWithValue(
        _SupportedDraftStorage(preferences),
      ),
      yorksV1ProjectReferenceAdvisoryProvider.overrideWith(
        (ref, query) async => YorksV1ProjectReferenceAdvisory.unavailable,
      ),
      yorksV1ActiveProjectTeamDirectoryProvider.overrideWith((ref) async => []),
      yorksV1ProjectPortfolioProvider.overrideWith((ref) async => []),
      yorksV1WorkspaceSearchResultsProvider.overrideWith(
        (ref, query) async => const YorksV1WorkspaceSearchResponse(results: []),
      ),
    ],
  );
  addTearDown(container.dispose);

  // The browser-only rollout choice is tested separately. This VM integration
  // uses the same route components, canonical paths and mounted onExit guard
  // without changing kIsWeb or substituting a fake feature/navigation widget.
  final router = GoRouter(
    initialLocation: RoutePaths.engineerCreateProject,
    routes: [
      GoRoute(
        path: RoutePaths.engineerCreateProject,
        onExit: (_, _) => container
            .read(yorksV1ProjectSetupNavigationGuardProvider)
            .canLeave(),
        builder: (_, _) => const YorksV1WorkspaceShell(
          featureOwnsChrome: true,
          child: YorksV1ProjectCreateFlowScreen(),
        ),
      ),
      GoRoute(
        path: RoutePaths.yorksV1Projects,
        builder: (_, _) =>
            const YorksV1WorkspaceShell(child: YorksV1ProjectsScreen()),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  addTearDown(() => expect(client.calls, 0));
  return _WorkspaceFixture(container, router, commands);
}

class _WorkspaceFixture {
  const _WorkspaceFixture(this.container, this.router, this.commands);
  final ProviderContainer container;
  final GoRouter router;
  final _NoProjectCommands commands;
}

class _NoProjectCommands
    implements
        YorksV1ProjectRepository,
        YorksV1ProjectReviewedCommandRepository {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('Navigation must not dispatch a project command');
  }
}

/// A configured client activates the real connected permission gate, while
/// every transport access fails loudly. These UI tests override only reads
/// and local storage; navigation must never contact a shared backend.
class _NoNetworkSupabaseClient extends Fake implements SupabaseClient {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('Workspace navigation must not access remote transport');
  }
}

class _SupportedDraftStorage extends SharedPreferencesProjectDraftStorage {
  _SupportedDraftStorage(super.preferences);
  @override
  bool get supportsAtomicOwnership => true;
}
