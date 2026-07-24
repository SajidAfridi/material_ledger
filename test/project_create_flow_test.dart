import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/core/widgets/app_buttons.dart';
import 'package:material_ledger/features/engineer/presentation/screens/engineer_create_project_screen.dart';
import 'package:material_ledger/features/projects/presentation/screens/project_create_flow_screen.dart';
import 'package:material_ledger/shared/models/nexus_feature_flags.dart';
import 'package:material_ledger/shared/models/project.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/nexus_feature_flags_provider.dart';
import 'package:material_ledger/shared/providers/project_creation_draft_provider.dart';
import 'package:material_ledger/shared/providers/project_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/users_provider.dart';
import 'package:material_ledger/shared/services/observability_service.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:material_ledger/shared/sync/outbox.dart';
import 'package:material_ledger/shared/sync/sync_backend.dart';
import 'package:material_ledger/shared/sync/sync_engine.dart';

const _password = 'test-only-local-password';

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

  Future<ProviderContainer> createContainer({
    bool projectsEnabled = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        localDemoPasswordProvider.overrideWithValue(_password),
        nexusFeatureFlagsProvider.overrideWithValue(
          NexusFeatureFlags(projects: projectsEnabled),
        ),
        observabilityProvider.overrideWithValue(const NoopObservability()),
        syncEngineProvider.overrideWith((ref) {
          final engine = SyncEngine(
            backend: ref.watch(syncBackendProvider),
            outbox: ref.watch(outboxProvider.notifier),
            connectivity: ref.watch(connectivityProvider),
          );
          ref.onDispose(engine.dispose);
          return engine;
        }),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(authControllerProvider)
        .signIn(email: 'imrankhan@gmail.com', password: _password);
    return container;
  }

  testWidgets('feature flag preserves the legacy form when disabled', (
    tester,
  ) async {
    final container = await createContainer(projectsEnabled: false);
    await _pumpHome(
      tester,
      container,
      const EngineerCreateProjectScreen(),
      const Size(900, 900),
    );

    expect(find.text('Job register'), findsOneWidget);
    expect(find.text('Essentials & responsibility'), findsNothing);
  });

  testWidgets('enabled flag exposes exactly the three frozen stages', (
    tester,
  ) async {
    final container = await createContainer();
    await _pumpHome(
      tester,
      container,
      const EngineerCreateProjectScreen(),
      const Size(1280, 900),
    );

    expect(find.text('Essentials & responsibility'), findsNWidgets(2));
    expect(find.text('Buildings'), findsOneWidget);
    expect(find.text('Review & create'), findsOneWidget);
    expect(find.text('Attachments'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('field changes autosave into the signed-in user draft', (
    tester,
  ) async {
    final container = await createContainer();
    await _pumpHome(
      tester,
      container,
      const ProjectCreateFlowScreen(),
      const Size(900, 900),
    );

    await tester.enterText(
      find.byKey(const ValueKey('project-yorks-reference')),
      'YRA-AUTOSAVE',
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      container.read(projectCreationDraftProvider('usr-eng')).yorksReference,
      'YRA-AUTOSAVE',
    );
  });

  testWidgets('building validation blocks duplicate codes', (tester) async {
    final container = await createContainer();
    final notifier = container.read(
      projectCreationDraftProvider('usr-eng').notifier,
    );
    await notifier.save(
      container
          .read(projectCreationDraftProvider('usr-eng'))
          .copyWith(
            currentStep: 1,
            buildings: const [
              ProjectBuilding(
                id: 'duplicate-1',
                code: 'B01',
                name: 'First Building',
              ),
              ProjectBuilding(
                id: 'duplicate-2',
                code: 'b01',
                name: 'Second Building',
              ),
            ],
          ),
    );
    await _pumpHome(
      tester,
      container,
      const ProjectCreateFlowScreen(),
      const Size(1000, 900),
    );

    final continueButton = find.widgetWithText(PrimaryButton, 'Continue');
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Building codes must be unique.'), findsOneWidget);
    expect(find.text('Review & create'), findsOneWidget);
    expect(find.text('Project identity'), findsNothing);
  });

  testWidgets('optional document metadata remains linked to its building', (
    tester,
  ) async {
    final container = await createContainer();
    final notifier = container.read(
      projectCreationDraftProvider('usr-eng').notifier,
    );
    await notifier.save(
      container
          .read(projectCreationDraftProvider('usr-eng'))
          .copyWith(
            currentStep: 1,
            buildings: const [
              ProjectBuilding(
                id: 'building-doc',
                code: 'B01',
                name: 'Main Building',
              ),
            ],
          ),
    );
    await _pumpHome(
      tester,
      container,
      const ProjectCreateFlowScreen(),
      const Size(1000, 900),
    );

    final addDocument = find.text('Add document reference');
    await tester.ensureVisible(addDocument);
    await tester.tap(addDocument);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('attachment-file-name')),
      'approved-drawing.pdf',
    );
    await tester.enterText(
      find.byKey(const ValueKey('attachment-document-type')),
      'Approved drawing',
    );
    await tester.tap(find.text('Project-wide / Common'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B01 · Main Building').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));

    final attachment = container
        .read(projectCreationDraftProvider('usr-eng'))
        .attachments
        .single;
    expect(attachment.fileName, 'approved-drawing.pdf');
    expect(attachment.documentType, 'Approved drawing');
    expect(attachment.buildingId, 'building-doc');
    expect(
      find.byKey(const ValueKey('attachment-file-name')),
      findsNothing,
    );
    expect(find.text('approved-drawing.pdf'), findsOneWidget);
  });

  testWidgets('restored input reaches review and creates a connected project', (
    tester,
  ) async {
    final container = await createContainer();
    final draftNotifier = container.read(
      projectCreationDraftProvider('usr-eng').notifier,
    );
    final draft = container
        .read(projectCreationDraftProvider('usr-eng'))
        .copyWith(
          yorksReference: 'YRA-B4-001',
          name: 'Hospital HVAC Upgrade',
          clientName: 'Yorks Client',
          siteLocation: 'Abu Dhabi',
          startDate: DateTime.utc(2026, 8, 1),
          designEngineerUserIds: const ['usr-eng'],
          otherContractorNames: const ['Civil Works LLC'],
          buildings: const [
            ProjectBuilding(
              id: 'building-b4',
              code: 'H01',
              name: 'Hospital Main Block',
              floorsOrLevels: ['Basement', 'GF', 'Roof'],
              hasFrpRoom: true,
            ),
          ],
        );
    await draftNotifier.save(draft);

    final router = GoRouter(
      initialLocation: '/projects/new',
      routes: [
        GoRoute(
          path: '/projects/new',
          builder: (_, _) => const ProjectCreateFlowScreen(),
        ),
        GoRoute(
          path: '/projects',
          builder: (_, _) =>
              const Scaffold(body: Text('Project register reached')),
        ),
        GoRoute(
          path: '/admin/procurement',
          builder: (_, _) => const Scaffold(body: Text('Procurement reached')),
        ),
        GoRoute(
          path: '/admin/projects',
          builder: (_, _) => const Scaffold(body: Text('Admin reached')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pumpRouter(tester, container, router, const Size(1280, 900));

    final firstContinue = find.widgetWithText(PrimaryButton, 'Continue');
    await tester.ensureVisible(firstContinue);
    await tester.tap(firstContinue);
    await tester.pumpAndSettle();
    expect(find.text('Add building'), findsOneWidget);

    final secondContinue = find.widgetWithText(PrimaryButton, 'Continue');
    await tester.ensureVisible(secondContinue);
    await tester.tap(secondContinue);
    await tester.pumpAndSettle();
    expect(find.text('Project identity'), findsOneWidget);
    expect(find.text('YRA-B4-001'), findsOneWidget);
    expect(find.textContaining('Hospital Main Block'), findsOneWidget);
    expect(find.text('Civil Works LLC'), findsOneWidget);

    final createButton = find.widgetWithText(PrimaryButton, 'Create project');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(find.text('Project register reached'), findsOneWidget);
    final created = container
        .read(projectsProvider)
        .firstWhere((project) => project.yorksReference == 'YRA-B4-001');
    expect(created.authorityRef, isNull);
    expect(created.createdByUserId, 'usr-eng');
    expect(created.createdByRole, 'engineer');
    expect(created.acceptedByProcurement, isFalse);
    expect(created.buildings.first.scope, ProjectBuildingScope.common);
    expect(created.buildings.last.name, 'Hospital Main Block');
    expect(created.otherContractors.single.name, 'Civil Works LLC');
    expect(
      container.read(projectCreationDraftProvider('usr-eng')).yorksReference,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile and tablet layouts render without overflow', (
    tester,
  ) async {
    for (final size in [const Size(390, 844), const Size(820, 1000)]) {
      final container = await createContainer();
      await _pumpHome(tester, container, const ProjectCreateFlowScreen(), size);

      expect(find.text('Create project'), findsWidgets);
      final exception = tester.takeException();
      if (exception is FlutterError) {
        fail(exception.toStringDeep());
      }
      expect(exception, isNull);
    }
  });

  testWidgets('desktop project creation golden', (tester) async {
    final container = await createContainer();
    await _pumpHome(
      tester,
      container,
      const ProjectCreateFlowScreen(),
      const Size(1280, 900),
    );

    await expectLater(
      find.byType(ProjectCreateFlowScreen),
      matchesGoldenFile('goldens/v7_project_create_desktop.png'),
    );
  });

  testWidgets('mobile project creation golden', (tester) async {
    final container = await createContainer();
    await _pumpHome(
      tester,
      container,
      const ProjectCreateFlowScreen(),
      const Size(390, 844),
    );

    await expectLater(
      find.byType(ProjectCreateFlowScreen),
      matchesGoldenFile('goldens/v7_project_create_mobile.png'),
    );
  });
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

Future<void> _pumpHome(
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
