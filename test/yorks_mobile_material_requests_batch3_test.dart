import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/router.dart';
import 'package:material_ledger/app/yorks_v1_workspace_shell.dart';
import 'package:material_ledger/core/constants/constants.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_material_request_screens.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request_document.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_boq.dart';
import 'package:material_ledger/shared/models/yorks_v1_boq_workbook.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_boq_repository_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_repository_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_boq_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_material_request_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _draftId = 'mobile-mr-draft';
const _projectId = 'mobile-mr-project';
late SharedPreferences _preferences;

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _preferences = await SharedPreferences.getInstance();
  });

  testWidgets('desktop MR draft keeps source actions and row tools distinct', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    await _pumpDraft(tester, boqRepository: _DesktopBoqRepositoryFixture());

    expect(find.text('Add Custom Item'), findsOneWidget);
    expect(find.text('Add from BOQ'), findsOneWidget);
    expect(find.text('Import Excel'), findsOneWidget);
    expect(find.text('Row tools'), findsOneWidget);
    expect(find.text('Add Blank Row'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/mr_draft_boq_actions_desktop.png'),
    );
  });

  testWidgets('desktop MR BOQ picker selects scoped rows without duplicates', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    await _pumpDraft(tester, boqRepository: _DesktopBoqRepositoryFixture());

    await tester.tap(find.text('Add from BOQ'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('desktop-mr-boq-picker')), findsOneWidget);
    expect(
      find.text('Add Items from Common / All Buildings BOQ'),
      findsOneWidget,
    );
    expect(find.textContaining('Air outlets'), findsOneWidget);
    final addButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('desktop-mr-add-selected-boq-items')),
    );
    expect(addButton.onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey('desktop-mr-boq-row-mobile-mr-boq-row')),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/mr_boq_picker_populated_desktop.png'),
    );

    await tester.tap(
      find.byKey(const ValueKey('desktop-mr-add-selected-boq-items')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Flexible duct'), findsOneWidget);

    await tester.tap(find.text('Add from BOQ'));
    await tester.pumpAndSettle();
    expect(find.text('Already added'), findsOneWidget);
    final rowCheckbox = tester.widget<Checkbox>(
      find.byKey(const ValueKey('desktop-mr-boq-row-mobile-mr-boq-row')),
    );
    expect(rowCheckbox.onChanged, isNull);
  });

  testWidgets('BOQ folder route seeds project scope before copying rows', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    await _pumpDraft(
      tester,
      boqRepository: _DesktopBoqRepositoryFixture(),
      boqGroupId: 'mobile-mr-boq-group',
    );

    expect(find.text('Flexible duct'), findsOneWidget);
    expect(find.text('Common / All Buildings'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop MR BOQ picker has a truthful empty state', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    await _pumpDraft(tester, boqRepository: _EmptyBoqRepositoryFixture());

    await tester.tap(find.text('Add from BOQ'));
    await tester.pumpAndSettle();

    expect(
      find.text('No materials in Common / All Buildings BOQ'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Add or import materials into this scope'),
      findsOneWidget,
    );
    final addButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('desktop-mr-add-selected-boq-items')),
    );
    expect(addButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/mr_boq_picker_empty_desktop.png'),
    );
  });

  for (final size in [const Size(390, 844), const Size(360, 800)]) {
    final suffix = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('mobile Batch 3 MR register $suffix', (tester) async {
      await _setViewport(tester, size);
      await tester.pumpWidget(
        _scope(
          overrides: [
            yorksV1CurrentRoleProvider.overrideWithValue(
              YorksV1Role.projectEngineer,
            ),
            yorksV1MaterialRequestListProvider(
              null,
            ).overrideWith((ref) async => [_submittedRequest, _draftRequest]),
          ],
          child: const YorksV1MaterialRequestsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('mobile-material-request-register')),
        findsOneWidget,
      );
      expect(find.text('All'), findsOneWidget);
      expect(find.text('YRA-322-MR101'), findsOneWidget);
      expect(find.text('Draft'), findsWidgets);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_batch3/mr_register_$suffix.png'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile Batch 3 MR information $suffix', (tester) async {
      await _setViewport(tester, size);
      await _pumpDraft(tester);

      expect(
        find.byKey(const ValueKey('mobile-mr-information')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('mobile-mr-project')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile-mr-scope')), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_batch3/mr_information_$suffix.png'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile Batch 3 MR BOQ folders $suffix', (tester) async {
      await _setViewport(tester, size);
      await _pumpDraft(tester, boqRepository: _BoqRepositoryFixture());
      await _continueToMaterials(tester);

      await tester.tap(find.text('Add from BOQ'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('mobile-mr-boq-folders')),
        findsOneWidget,
      );
      expect(find.text('Air outlets'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_batch3/mr_boq_folders_$suffix.png'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile Batch 3 MR custom material $suffix', (tester) async {
      await _setViewport(tester, size);
      await _pumpDraft(tester);
      await _continueToMaterials(tester);

      await tester.tap(find.text('Add Custom Item'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('mobile-mr-custom-material')),
        findsOneWidget,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/mobile_batch3/mr_custom_material_$suffix.png',
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile Batch 3 MR review $suffix', (tester) async {
      await _setViewport(tester, size);
      await _pumpDraft(tester);
      await _addCustomMaterial(tester);
      await _openReview(tester);

      expect(find.byKey(const ValueKey('mobile-mr-review')), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_batch3/mr_review_$suffix.png'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile Batch 3 MR submitted $suffix', (tester) async {
      await _setViewport(tester, size);
      final repository = await _pumpDraft(tester);
      await _addCustomMaterial(tester);
      await _openReview(tester);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('mobile-mr-primary-action')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(
        find
            .byKey(const ValueKey('mobile-mr-primary-action'))
            .hitTestable()
            .first,
      );
      await tester.pumpAndSettle();

      expect(repository.saveAndSubmitCount, 1);
      expect(
        find.text(
          'Your request has been submitted and is now with Procurement.',
        ),
        findsOneWidget,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_batch3/mr_submitted_$suffix.png'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile Batch 3 MR lifecycle $suffix', (tester) async {
      await _setViewport(tester, size);
      await _pumpLifecycle(tester);

      expect(find.byKey(const ValueKey('mobile-mr-lifecycle')), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_batch3/mr_lifecycle_$suffix.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'mobile MR uses the existing draft controller through custom material',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));
      await _pumpDraft(tester);
      await _addCustomMaterial(tester);
      expect(find.text('Flexible duct'), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile MR adds only a row from the selected real BOQ scope', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    await _pumpDraft(tester, boqRepository: _BoqRepositoryFixture());
    await _continueToMaterials(tester);

    await tester.tap(find.text('Add from BOQ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Air outlets'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mobile-mr-boq-rows')), findsOneWidget);
    expect(find.text('Flexible duct'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .byKey(const ValueKey('mobile-mr-primary-action'))
          .hitTestable()
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mobile-mr-materials')), findsOneWidget);
    expect(find.text('Flexible duct'), findsOneWidget);
    // The root-overlay success notice deliberately remains visible across a
    // route/state change. Let its bounded lifetime finish before the widget
    // test tears down the navigator.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile MR lifecycle exposes only the real resolved primary action',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));
      await _pumpLifecycle(tester);

      expect(find.byKey(const ValueKey('mobile-mr-lifecycle')), findsOneWidget);
      expect(find.text('Arrange Items'), findsNothing);
      expect(find.text('Current owner'), findsOneWidget);
      expect(find.textContaining('Unit Cost'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile MR routes use one feature header with shell navigation', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    final router = GoRouter(
      initialLocation: RoutePaths.yorksV1MaterialRequests,
      routes: [
        GoRoute(
          path: RoutePaths.yorksV1MaterialRequests,
          builder: (_, _) => const YorksV1WorkspaceShell(
            child: YorksV1MaterialRequestsScreen(),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      _scope(
        overrides: [
          yorksV1CurrentRoleProvider.overrideWithValue(
            YorksV1Role.projectEngineer,
          ),
          yorksV1MaterialRequestListProvider(
            null,
          ).overrideWith((ref) async => [_submittedRequest]),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: router,
        ),
        materialApp: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(YorksV1WorkspaceShell), findsOneWidget);
    expect(find.text('Material Requests'), findsNWidgets(2));
    expect(find.text('Requests'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile MR filters remain one touch-safe scroll rail', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    await tester.pumpWidget(
      _scope(
        overrides: [
          yorksV1CurrentRoleProvider.overrideWithValue(
            YorksV1Role.projectEngineer,
          ),
          yorksV1MaterialRequestListProvider(
            null,
          ).overrideWith((ref) async => [_submittedRequest, _draftRequest]),
        ],
        child: const YorksV1MaterialRequestsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final rail = find.byKey(
      const ValueKey('mobile-material-request-filter-rail'),
    );
    expect(rail, findsOneWidget);
    expect(tester.getSize(rail).height, AppSpacing.minTapTarget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(1366, 768), const Size(360, 800)]) {
    final suffix = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('MR register exposes owner-local draft recovery $suffix', (
      tester,
    ) async {
      await _setViewport(tester, size);
      const ownerAuthUserId = 'recoverable-draft-owner';
      final repository = _MaterialRequestRepositoryFixture();
      final recoveryContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(_preferences),
          yorksV1MaterialRequestRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(recoveryContainer.dispose);
      final draftController = recoveryContainer.read(
        yorksV1MaterialRequestDraftControllerProvider(
          const YorksV1MaterialRequestDraftKey(
            ownerAuthUserId: ownerAuthUserId,
            draftId: 'recoverable-local-draft',
          ),
        ).notifier,
      );
      await draftController.setTitle('Plant room materials');
      await draftController.setProject(_projectId);

      await tester.pumpWidget(
        _scope(
          overrides: [
            yorksV1AuthUserIdProvider.overrideWithValue(ownerAuthUserId),
            yorksV1CurrentRoleProvider.overrideWithValue(
              YorksV1Role.projectEngineer,
            ),
            yorksV1MaterialRequestRepositoryProvider.overrideWithValue(
              repository,
            ),
            yorksV1MaterialRequestListProvider(
              null,
            ).overrideWith((ref) async => [_submittedRequest]),
          ],
          child: const YorksV1MaterialRequestsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 saved local draft'), findsOneWidget);
      expect(find.text('Plant room materials'), findsOneWidget);
      expect(find.text('Resume saved draft'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/r35/mr_local_recovery_$suffix.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _scope({
  required List<Override> overrides,
  required Widget child,
  bool materialApp = true,
}) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(_preferences),
    ...overrides,
  ],
  child: materialApp
      ? MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: child,
        )
      : child,
);

Future<_MaterialRequestRepositoryFixture> _pumpDraft(
  WidgetTester tester, {
  YorksV1BoqRepository? boqRepository,
  String? boqGroupId,
}) async {
  final repository = _MaterialRequestRepositoryFixture();
  await tester.pumpWidget(
    _scope(
      overrides: [
        yorksV1AuthUserIdProvider.overrideWithValue('mobile-mr-user'),
        yorksV1CurrentRoleProvider.overrideWithValue(
          YorksV1Role.projectEngineer,
        ),
        yorksV1MaterialRequestRepositoryProvider.overrideWithValue(repository),
        if (boqRepository != null)
          yorksV1BoqRepositoryProvider.overrideWithValue(boqRepository),
        yorksV1MaterialRequestDraftProjectsProvider.overrideWith(
          (ref) async => const [
            YorksV1MaterialRequestProjectOption(
              id: _projectId,
              reference: 'YRA-322',
              name: 'Al Dhafra Grid Substation HVAC Works',
              state: 'active',
            ),
          ],
        ),
        yorksV1MaterialRequestScopesProvider(_projectId).overrideWith(
          (ref) async => const [
            YorksV1MaterialRequestScopeOption(
              id: 'scope-common',
              projectId: _projectId,
              name: 'Common / All Buildings',
              kind: 'common',
            ),
          ],
        ),
      ],
      child: YorksV1MaterialRequestDraftScreen(
        draftId: _draftId,
        projectId: _projectId,
        boqGroupId: boqGroupId,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _continueToMaterials(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey('mobile-mr-primary-action')).hitTestable().first,
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('mobile-mr-materials')), findsOneWidget);
}

Future<void> _addCustomMaterial(WidgetTester tester) async {
  await _continueToMaterials(tester);
  await tester.tap(find.text('Add Custom Item'));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('mobile-mr-custom-material')),
    findsOneWidget,
  );

  await tester.enterText(find.byType(TextFormField).at(0), 'Flexible duct');
  await tester.enterText(find.byType(TextFormField).at(4), '2');
  await tester.tap(find.text('Add Custom Item'));
  await tester.pumpAndSettle();
  // The honest success toast is intentionally visible before returning to the
  // material list. Let it finish so the fixed action bar is hit-testable.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Future<void> _openReview(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey('mobile-mr-primary-action')).hitTestable().first,
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('mobile-mr-review')), findsOneWidget);
}

Future<void> _pumpLifecycle(WidgetTester tester) async {
  await tester.pumpWidget(
    _scope(
      overrides: [
        yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.procurement),
        yorksV1MaterialRequestDetailProvider(
          _submittedRequest.id,
        ).overrideWith((ref) async => _submittedRequest),
        yorksV1MaterialRequestDocumentProvider(
          _submittedRequest.id,
        ).overrideWith(
          (ref) async => YorksV1MaterialRequestDocumentModel.fromRequest(
            _submittedRequest,
          ),
        ),
      ],
      child: const YorksV1MaterialRequestDetailScreen(
        requestId: _submittedRequestId,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 26);
  tester.view.viewPadding = const FakeViewPadding(top: 26);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewPadding();
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

const _submittedRequestId = 'mobile-mr-submitted';

final _submittedRequest = YorksV1MaterialRequest(
  id: _submittedRequestId,
  projectId: _projectId,
  projectReference: 'YRA-322',
  projectName: 'Al Dhafra Grid Substation HVAC Works',
  scopeId: 'scope-common',
  scopeName: 'Common / All Buildings',
  state: YorksV1MaterialRequestState.submitted,
  recordVersion: 2,
  createdAt: DateTime.utc(2026, 8, 9),
  updatedAt: DateTime.utc(2026, 8, 9),
  timing: YorksV1MaterialRequestTiming.normal,
  requestNumber: 'YRA-322-MR101',
  title: 'Level 2 FCU materials',
  requesterDisplayName: 'Omar Farooq',
  requesterProjectRole: 'Project Engineer',
  currentActionOwnerRole: 'procurement',
  lines: const [
    YorksV1MaterialRequestLine(
      id: 'submitted-line',
      displayOrder: 1,
      source: YorksV1MaterialRequestLineSource.boq,
      sourceBoqGroupId: 'group-1',
      sourceBoqRowId: 'row-1',
      description: 'Flexible duct',
      quantity: '2',
      unit: 'Nos',
      brandOrigin: 'Yorks',
    ),
  ],
);

final _draftRequest = YorksV1MaterialRequest(
  id: 'mobile-mr-draft-record',
  projectId: _projectId,
  projectReference: 'YRA-322',
  projectName: 'Al Dhafra Grid Substation HVAC Works',
  scopeId: 'scope-common',
  scopeName: 'Common / All Buildings',
  state: YorksV1MaterialRequestState.draft,
  recordVersion: 1,
  createdAt: DateTime.utc(2026, 8, 9),
  updatedAt: DateTime.utc(2026, 8, 9),
  timing: YorksV1MaterialRequestTiming.normal,
  title: 'Private draft',
  lines: const [],
);

class _MaterialRequestRepositoryFixture
    implements YorksV1MaterialRequestRepository {
  int saveAndSubmitCount = 0;
  @override
  Future<YorksV1MaterialRequest> cancel(
    YorksV1CancelMaterialRequestInput input,
  ) async => _submittedRequest;

  @override
  Future<YorksV1MaterialRequest> close(
    YorksV1CloseMaterialRequestInput input,
  ) async => _submittedRequest;

  @override
  Future<void> deleteDraft(String requestId) async {}

  @override
  Future<YorksV1MaterialRequest> getRequest(String requestId) async =>
      throw StateError('draft has not been saved to the server');

  @override
  Future<YorksV1MaterialRequestDocumentModel> getDocumentModel(
    String requestId,
  ) async => YorksV1MaterialRequestDocumentModel.fromRequest(_submittedRequest);

  @override
  Future<List<YorksV1MaterialRequestProjectOption>> listDraftProjects() async =>
      const [];

  @override
  Future<List<YorksV1MaterialRequest>> listRequests({
    String? projectId,
  }) async => const [];

  @override
  Future<List<YorksV1MaterialRequestScopeOption>> listScopes(
    String projectId,
  ) async => const [];

  @override
  Future<YorksV1MaterialRequest> saveAndSubmit(
    YorksV1MaterialRequestDraft draft,
  ) async {
    saveAndSubmitCount++;
    return _submittedRequest;
  }

  @override
  Future<YorksV1MaterialRequest> saveDraft(
    YorksV1SaveMaterialRequestDraftInput input,
  ) async => _draftRequest;

  @override
  Future<YorksV1MaterialRequest> submit(
    YorksV1SubmitMaterialRequestInput input,
  ) async => _submittedRequest;
}

class _BoqRepositoryFixture implements YorksV1BoqRepository {
  static final _group = YorksV1BoqGroup(
    id: 'mobile-mr-boq-group',
    projectId: _projectId,
    name: 'Air outlets',
    worksheetTitle: 'Air outlets',
    displayOrder: 1,
    isCustom: false,
    isArchived: false,
    version: 1,
    rowCount: 12,
    columnCount: 3,
    updatedAt: DateTime.utc(2026, 8, 9),
    scopeId: 'scope-common',
    scopeKind: 'common',
    scopeName: 'Common / All Buildings',
  );

  static final _groups = [
    _group,
    for (final entry in <({String name, int rows})>[
      (name: 'Ventilation Fans', rows: 8),
      (name: 'MFD, MSFD, MSD, MVCD & VCD', rows: 15),
      (name: 'Air Inlet & Outlet', rows: 18),
      (name: 'Cable Tray', rows: 0),
    ])
      YorksV1BoqGroup(
        id: 'mobile-mr-boq-${entry.rows}-${entry.name.length}',
        projectId: _projectId,
        name: entry.name,
        worksheetTitle: entry.name,
        displayOrder: _groupsDisplayOrder(entry.name),
        isCustom: false,
        isArchived: false,
        version: 1,
        rowCount: entry.rows,
        columnCount: 3,
        updatedAt: DateTime.utc(2026, 8, 9),
        scopeId: 'scope-common',
        scopeKind: 'common',
        scopeName: 'Common / All Buildings',
      ),
  ];

  static final _worksheet = YorksV1BoqWorksheet(
    group: _group,
    columns: const [
      YorksV1BoqColumn(
        id: 'description',
        heading: 'Item description',
        displayOrder: 1,
        canonicalField: YorksV1BoqCanonicalField.description,
      ),
      YorksV1BoqColumn(
        id: 'quantity',
        heading: 'Qty.',
        displayOrder: 2,
        canonicalField: YorksV1BoqCanonicalField.quantity,
      ),
      YorksV1BoqColumn(
        id: 'unit',
        heading: 'Unit',
        displayOrder: 3,
        canonicalField: YorksV1BoqCanonicalField.unit,
      ),
    ],
    rows: [
      YorksV1BoqRow(
        id: 'mobile-mr-boq-row',
        displayOrder: 1,
        values: const {
          'description': 'Flexible duct',
          'quantity': '2',
          'unit': 'Nos',
        },
        canonicalValues: const {
          'description': 'Flexible duct',
          'quantity': '2',
          'unit': 'Nos',
        },
      ),
    ],
  );

  @override
  Future<void> archiveGroup({
    required String groupId,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {}

  @override
  Future<YorksV1BoqGroup> assignLegacyGroupScope(
    YorksV1AssignLegacyBoqGroupScopeInput input,
  ) async => _group;

  @override
  Future<YorksV1BoqGroup> createCustomGroup(
    YorksV1CreateBoqGroupInput input,
  ) async => _group;

  @override
  Future<YorksV1BoqWorksheet> getWorksheet(String groupId) async => _worksheet;

  @override
  Future<YorksV1BoqWorksheet> importWorksheet(
    YorksV1ImportBoqWorksheetInput input,
  ) async => _worksheet;

  @override
  Future<List<YorksV1BoqGroup>> listGroups(String projectId) async => _groups;

  @override
  Future<List<YorksV1BoqGroup>> listGroupsForScope(
    String projectId, {
    String? scopeId,
  }) async => _groups;

  @override
  Future<YorksV1BoqWorksheet> saveWorksheet(
    YorksV1SaveBoqWorksheetInput input,
  ) async => _worksheet;
}

class _DesktopBoqRepositoryFixture extends _BoqRepositoryFixture {
  @override
  Future<List<YorksV1BoqGroup>> listGroups(String projectId) async => [
    _BoqRepositoryFixture._group,
  ];

  @override
  Future<List<YorksV1BoqGroup>> listGroupsForScope(
    String projectId, {
    String? scopeId,
  }) async => [_BoqRepositoryFixture._group];
}

class _EmptyBoqRepositoryFixture extends _BoqRepositoryFixture {
  @override
  Future<List<YorksV1BoqGroup>> listGroups(String projectId) async => const [];

  @override
  Future<List<YorksV1BoqGroup>> listGroupsForScope(
    String projectId, {
    String? scopeId,
  }) async => const [];
}

int _groupsDisplayOrder(String name) => switch (name) {
  'Ventilation Fans' => 2,
  'MFD, MSFD, MSD, MVCD & VCD' => 3,
  'Air Inlet & Outlet' => 4,
  _ => 5,
};
