import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/core/widgets/nexus_page_shell.dart';
import 'package:material_ledger/features/admin/presentation/screens/admin_projects_screen.dart';
import 'package:material_ledger/features/engineer/presentation/screens/engineer_projects_screen.dart';
import 'package:material_ledger/features/projects/presentation/screens/project_workspace_screen.dart';
import 'package:material_ledger/shared/models/audit_log.dart';
import 'package:material_ledger/shared/models/material_plan.dart';
import 'package:material_ledger/shared/models/material_request.dart';
import 'package:material_ledger/shared/models/nexus_feature_flags.dart';
import 'package:material_ledger/shared/models/project.dart';
import 'package:material_ledger/shared/models/project_workspace_snapshot.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/nexus_feature_flags_provider.dart';
import 'package:material_ledger/shared/providers/project_workspace_provider.dart';

void main() {
  setUpAll(() async {
    final nexusFontLoader = FontLoader('NexusSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final arabicFontLoader = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    final flutterCache = _flutterCacheDirectory();
    final iconBytes = await File(
      '${flutterCache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final iconFontLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(iconBytes)));
    await Future.wait([
      nexusFontLoader.load(),
      arabicFontLoader.load(),
      iconFontLoader.load(),
    ]);
  });

  test(
    'workspace fails closed for a project outside engineer assignment',
    () async {
      final project = _project(
        assignedEngineerId: 'usr-other',
        designEngineerUserIds: const ['usr-other'],
      );
      final container = await _container(project: project);
      addTearDown(container.dispose);

      expect(container.read(projectWorkspaceProvider(project.id)), isNull);
    },
  );

  test('unaccepted project names Procurement as owner and blocker', () async {
    final project = _project(acceptedByProcurement: false);
    final container = await _container(project: project);
    addTearDown(container.dispose);

    final snapshot = container.read(projectWorkspaceProvider(project.id))!;
    expect(snapshot.currentAction, ProjectWorkspaceAction.acceptProject);
    expect(snapshot.currentOwnerRole, UserRole.procurement);
    expect(
      snapshot.blockers,
      contains(ProjectWorkspaceBlocker.procurementAcceptance),
    );
    expect(snapshot.readiness, hasLength(5));
  });

  test('submitted plan routes the current action to Procurement', () async {
    final project = _project();
    final plan = MaterialPlan(
      id: 'plan-workspace',
      projectId: project.id,
      status: MaterialPlanStatus.submitted,
      version: 2,
      submittedAt: DateTime.utc(2026, 7, 1),
    );
    final container = await _container(project: project, plan: plan);
    addTearDown(container.dispose);

    final snapshot = container.read(projectWorkspaceProvider(project.id))!;
    expect(snapshot.currentAction, ProjectWorkspaceAction.reviewMaterialPlan);
    expect(snapshot.currentOwnerRole, UserRole.procurement);
    expect(
      snapshot.readiness
          .singleWhere(
            (item) => item.kind == ProjectWorkspaceReadinessKind.materialPlan,
          )
          .state,
      ProjectWorkspaceReadinessState.inProgress,
    );
  });

  test(
    'approved plan and dispatched request route receipt to Engineer',
    () async {
      final project = _project();
      final plan = MaterialPlan(
        id: 'plan-workspace',
        projectId: project.id,
        status: MaterialPlanStatus.approved,
        approvedAt: DateTime.utc(2026, 7, 2),
      );
      final request = _request(
        projectId: project.id,
        status: RequestStatus.dispatched,
      );
      final container = await _container(
        project: project,
        plan: plan,
        requests: [request],
      );
      addTearDown(container.dispose);

      final snapshot = container.read(projectWorkspaceProvider(project.id))!;
      expect(snapshot.currentAction, ProjectWorkspaceAction.confirmSiteReceipt);
      expect(snapshot.currentOwnerRole, UserRole.engineer);
      expect(snapshot.currentOwnerUserIds, contains('usr-eng'));
    },
  );

  test(
    'stable project ID wins; project name is legacy fallback only',
    () async {
      final project = _project();
      final matchingLegacy = _request(projectId: null, id: 'req-legacy');
      final sameNameWrongId = _request(
        projectId: 'another-project',
        id: 'req-wrong-id',
      );
      final matchingId = _request(projectId: project.id, id: 'req-stable');
      final container = await _container(
        project: project,
        requests: [matchingLegacy, sameNameWrongId, matchingId],
      );
      addTearDown(container.dispose);

      final ids = container
          .read(projectWorkspaceProvider(project.id))!
          .requests
          .map((request) => request.id);
      expect(ids, containsAll(['req-legacy', 'req-stable']));
      expect(ids, isNot(contains('req-wrong-id')));
    },
  );

  test(
    'legacy active project prioritizes execution over a missing plan',
    () async {
      final project = _project(
        lifecycleStatus: ProjectLifecycleStatus.active,
        phaseState: ProjectState.active,
      );
      final container = await _container(
        project: project,
        requests: [_request(projectId: project.id)],
      );
      addTearDown(container.dispose);

      final snapshot = container.read(projectWorkspaceProvider(project.id))!;
      expect(
        snapshot.currentAction,
        ProjectWorkspaceAction.processMaterialRequests,
      );
      expect(snapshot.currentOwnerRole, UserRole.procurement);
    },
  );

  testWidgets('desktop renders all registers and the operational inspector', (
    tester,
  ) async {
    final project = _project(attachments: [_attachment()]);
    final container = await _container(project: project);
    addTearDown(container.dispose);
    await _pump(
      tester,
      container,
      ProjectWorkspaceScreen(projectId: project.id),
      const Size(1280, 900),
    );

    for (final label in const [
      'Overview',
      'Material Plan',
      'Requests',
      'Procurement',
      'Documents',
      'Activity',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.byKey(NexusPageShell.inspectorKey), findsOneWidget);
    expect(
      find.byKey(const ValueKey('project-workspace-desktop-tabs')),
      findsOneWidget,
    );
    expect(find.text('Prepare Phase 1 material plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('documents retain building scope and visible audit metadata', (
    tester,
  ) async {
    final project = _project(attachments: [_attachment()]);
    final container = await _container(project: project);
    addTearDown(container.dispose);
    await _pump(
      tester,
      container,
      ProjectWorkspaceScreen(projectId: project.id),
      const Size(1280, 900),
    );

    await tester.tap(find.text('Documents').first);
    await tester.pumpAndSettle();

    expect(find.text('approved-drawing.pdf'), findsOneWidget);
    expect(find.textContaining('B01 · Main Building'), findsOneWidget);
    expect(find.text('Imran Khan'), findsWidgets);
    expect(find.text('engineer'), findsWidgets);
  });

  testWidgets('mobile uses its own section selector without overflow', (
    tester,
  ) async {
    final project = _project();
    final container = await _container(project: project);
    addTearDown(container.dispose);
    await _pump(
      tester,
      container,
      ProjectWorkspaceScreen(projectId: project.id),
      const Size(390, 844),
    );

    expect(
      find.byKey(const ValueKey('project-workspace-mobile-section-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('project-workspace-desktop-tabs')),
      findsNothing,
    );
    final exception = tester.takeException();
    if (exception is FlutterError) fail(exception.toStringDeep());
    expect(exception, isNull);
  });

  testWidgets('disabled project flag fails closed on a deep link', (
    tester,
  ) async {
    final project = _project();
    final container = await _container(
      project: project,
      projectsEnabled: false,
    );
    addTearDown(container.dispose);
    await _pump(
      tester,
      container,
      ProjectWorkspaceScreen(projectId: project.id),
      const Size(900, 700),
    );

    expect(find.text('Project workspace unavailable'), findsOneWidget);
    expect(find.text(project.name), findsNothing);
  });

  testWidgets('enabled flag routes an Engineer project card to the workspace', (
    tester,
  ) async {
    final project = _project();
    final container = await _container(project: project);
    addTearDown(container.dispose);
    final router = _projectCardRouter();
    addTearDown(router.dispose);
    await _pumpRouter(tester, container, router, const Size(900, 800));

    await tester.tap(find.text(project.name));
    await tester.pumpAndSettle();

    expect(find.text('Workspace reached'), findsOneWidget);
  });

  testWidgets('disabled flag preserves legacy Engineer project navigation', (
    tester,
  ) async {
    final project = _project();
    final container = await _container(
      project: project,
      projectsEnabled: false,
    );
    addTearDown(container.dispose);
    final router = _projectCardRouter();
    addTearDown(router.dispose);
    await _pumpRouter(tester, container, router, const Size(900, 800));

    await tester.tap(find.text(project.name));
    await tester.pumpAndSettle();

    expect(find.text('Legacy plan reached'), findsOneWidget);
  });

  testWidgets('Procurement project register does not expose Admin delete', (
    tester,
  ) async {
    final project = _project();
    final container = await _container(project: project, userId: 'usr-proc');
    addTearDown(container.dispose);
    await _pump(
      tester,
      container,
      const AdminProjectsScreen(),
      const Size(1000, 800),
    );

    expect(find.text(project.name), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop project workspace golden', (tester) async {
    final project = _project(attachments: [_attachment()]);
    final container = await _container(project: project);
    addTearDown(container.dispose);
    await _pump(
      tester,
      container,
      ProjectWorkspaceScreen(projectId: project.id),
      const Size(1280, 900),
    );

    await expectLater(
      find.byType(ProjectWorkspaceScreen),
      matchesGoldenFile('goldens/v7_project_workspace_desktop.png'),
    );
  });

  testWidgets('mobile project workspace golden', (tester) async {
    final project = _project(attachments: [_attachment()]);
    final container = await _container(project: project);
    addTearDown(container.dispose);
    await _pump(
      tester,
      container,
      ProjectWorkspaceScreen(projectId: project.id),
      const Size(390, 844),
    );

    await expectLater(
      find.byType(ProjectWorkspaceScreen),
      matchesGoldenFile('goldens/v7_project_workspace_mobile.png'),
    );
  });
}

Project _project({
  bool acceptedByProcurement = true,
  String assignedEngineerId = 'usr-eng',
  List<String> designEngineerUserIds = const ['usr-eng'],
  List<ProjectAttachment> attachments = const [],
  ProjectLifecycleStatus lifecycleStatus = ProjectLifecycleStatus.planning,
  ProjectState phaseState = ProjectState.planning,
}) {
  return Project(
    id: 'project-workspace',
    yorksReference: 'YRA-2026-041',
    name: 'Al Noor Hospital HVAC',
    secondaryName: 'مشروع تكييف مستشفى النور',
    clientName: 'Al Noor Healthcare',
    siteLocation: 'Abu Dhabi',
    contractOrJobNumber: 'JOB-041',
    startDate: DateTime.utc(2026, 7, 1),
    expectedEndDate: DateTime.utc(2027, 2, 28),
    acceptedByProcurement: acceptedByProcurement,
    acceptedAt: acceptedByProcurement ? DateTime.utc(2026, 7, 1, 9) : null,
    acceptedBy: acceptedByProcurement ? 'usr-proc' : null,
    assignedEngineerId: assignedEngineerId,
    projectManagerUserId: 'usr-admin',
    designEngineerUserIds: designEngineerUserIds,
    buildings: const [
      ProjectBuilding(
        id: 'common',
        code: 'COMMON',
        name: 'Project-wide / Common',
        scope: ProjectBuildingScope.common,
      ),
      ProjectBuilding(
        id: 'building-1',
        code: 'B01',
        name: 'Main Building',
        floorsOrLevels: ['Basement', 'GF', 'Roof'],
        hasFrpRoom: true,
      ),
    ],
    attachments: attachments,
    lifecycleStatus: lifecycleStatus,
    phase: ProjectPhase(
      number: 1,
      name: 'Material Planning',
      nameSecondary: 'تخطيط المواد',
      state: phaseState,
    ),
    createdAt: DateTime.utc(2026, 7, 1, 8, 30),
    createdByUserId: 'usr-eng',
    createdByRole: 'engineer',
    updatedAt: DateTime.utc(2026, 7, 1, 9),
    updatedByUserId: 'usr-proc',
    updatedByRole: 'procurement',
  );
}

ProjectAttachment _attachment() => ProjectAttachment(
  id: 'attachment-1',
  fileName: 'approved-drawing.pdf',
  documentType: 'Approved drawing',
  reference: 'M-201',
  buildingId: 'building-1',
  addedAt: DateTime.utc(2026, 7, 1, 8, 45),
  addedByUserId: 'usr-eng',
  addedByRole: 'engineer',
);

MaterialRequest _request({
  String? projectId,
  String id = 'req-workspace',
  RequestStatus status = RequestStatus.pending,
}) {
  return MaterialRequest(
    id: id,
    projectId: projectId,
    projectName: 'Al Noor Hospital HVAC',
    projectNameSecondary: 'مشروع تكييف مستشفى النور',
    status: status,
    requestDate: DateTime.utc(2026, 7, 3),
    itemCount: 3,
  );
}

Future<ProviderContainer> _container({
  required Project project,
  MaterialPlan? plan,
  List<MaterialRequest> requests = const [],
  bool projectsEnabled = true,
  String userId = 'usr-eng',
}) async {
  SharedPreferences.setMockInitialValues({
    'auth_user_id': userId,
    'projects_list_v1': jsonEncode([project.toOperationalJson()]),
    'material_plans_list_v2': jsonEncode([if (plan != null) plan.toJson()]),
    'material_requests_list_v3': jsonEncode(
      requests.map((request) => request.toJson()).toList(),
    ),
    'activity_log_v2': jsonEncode([
      AuditEntry(
        id: 'audit-workspace',
        action: 'Project accepted by procurement',
        actorName: 'Al Asad',
        actorRole: UserRole.procurement,
        module: AuditModule.materials,
        timestamp: DateTime.utc(2026, 7, 1, 9),
        refId: project.id,
        detail: project.name,
      ).toJson(),
    ]),
  });
  final preferences = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      nexusFeatureFlagsProvider.overrideWithValue(
        NexusFeatureFlags(projects: projectsEnabled),
      ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget home,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

GoRouter _projectCardRouter() => GoRouter(
  initialLocation: '/projects',
  routes: [
    GoRoute(
      path: '/projects',
      builder: (_, _) => const Scaffold(body: EngineerProjectsScreen()),
    ),
    GoRoute(
      path: '/projects/:id',
      builder: (_, _) => const Scaffold(body: Text('Workspace reached')),
    ),
    GoRoute(
      path: '/plan-build/:id',
      builder: (_, _) => const Scaffold(body: Text('Legacy plan reached')),
    ),
  ],
);

Future<void> _pumpRouter(
  WidgetTester tester,
  ProviderContainer container,
  GoRouter router,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
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
