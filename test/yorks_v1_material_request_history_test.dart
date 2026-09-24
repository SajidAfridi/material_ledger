import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/core/widgets/yorks_panel_toggle_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/materials/presentation/widgets/yorks_v1_material_request_history.dart';
import 'package:material_ledger/features/materials/presentation/widgets/yorks_v1_request_information.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request_history.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_history_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_permission_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_material_request_history_repository.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';

import 'support/yorks_v1_permission_test_support.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('NexusSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    var directory = File(Platform.resolvedExecutable).parent;
    while (!directory.path.endsWith('${Platform.pathSeparator}cache') &&
        directory.path != directory.parent.path) {
      directory = directory.parent;
    }
    final bytes = await File(
      '${directory.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await Future.wait([font.load(), icons.load()]);
  });

  testWidgets(
    'workflow information stays bounded during resize and preserves working input',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final input = TextEditingController(text: 'Unsaved arrangement quantity');
      addTearDown(input.dispose);
      final repository = _CountingHistoryRepository();
      final container = ProviderContainer(
        overrides: [
          yorksV1MaterialRequestHistoryRepositoryProvider.overrideWithValue(
            repository,
          ),
          yorksV1MaterialRequestDetailProvider(
            'request-1',
          ).overrideWith((ref) async => _historyRequest),
          yorksV1CurrentPermissionSnapshotProvider.overrideWith(
            (ref) => YorksV1TestPermissionController(
              yorksV1TrustedFeaturePermissionState(
                role: YorksV1Role.projectEngineer,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: Scaffold(
              body: Column(
                children: [
                  TextField(controller: input),
                  YorksV1RequestInformationToolbar(
                    request: _historyRequest,
                    language: AppLanguage.english,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<YorksPanelToggleIcon>(find.byType(YorksPanelToggleIcon))
            .expanded,
        isFalse,
      );
      await tester.tap(
        find.byKey(const ValueKey('material-request-information-action')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<YorksPanelToggleIcon>(find.byType(YorksPanelToggleIcon))
            .expanded,
        isTrue,
      );
      expect(repository.calls, 1);
      for (final width in [1440.0, 820.0, 360.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        final panel = tester.getRect(
          find.byKey(const ValueKey('material-request-information-panel')),
        );
        expect(panel.right, closeTo(width, 1));
        expect(panel.height, 900);
        expect(panel.width, lessThanOrEqualTo(width * .92 + 1));
        expect(repository.calls, 1);
        expect(tester.takeException(), isNull);
        if (width == 1440 || width == 360) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/r35/mr_flow_information_${width.toInt()}.png',
            ),
          );
        }
      }
      tester.view.physicalSize = const Size(1440, 500);
      await tester.pumpAndSettle();
      final scroll = find.byKey(
        const PageStorageKey('material-request-information-scroll'),
      );
      await tester.drag(scroll, const Offset(0, -120));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(of: scroll, matching: find.byType(Scrollable))
          .first;
      final offset = tester.state<ScrollableState>(scrollable).position.pixels;
      expect(offset, greaterThan(0));
      tester.view.physicalSize = const Size(820, 500);
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        closeTo(offset, 1),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('material-request-information-panel')),
        findsNothing,
      );
      expect(
        tester
            .widget<YorksPanelToggleIcon>(find.byType(YorksPanelToggleIcon))
            .expanded,
        isFalse,
      );
      expect(input.text, 'Unsaved arrangement quantity');
      await tester.tap(
        find.byKey(const ValueKey('material-request-information-action')),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 200));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('material-request-information-panel')),
        findsNothing,
      );
      expect(input.text, 'Unsaved arrangement quantity');
    },
  );

  testWidgets(
    'information panel follows RTL and reduced motion on a scaled phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              disableAnimations: true,
              textScaler: TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showYorksV1RequestInformationPanel(
                  context,
                  language: AppLanguage.arabic,
                  builder: (context) => YorksV1RequestInformationSurface(
                    language: AppLanguage.arabic,
                    onClose: () => Navigator.of(context).pop(),
                    children: const [Text('Request context')],
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final panel = tester.getRect(
        find.byKey(const ValueKey('material-request-information-panel')),
      );
      expect(panel.left, 0);
      expect(panel.width, closeTo(331.2, 1));
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(const ValueKey('material-request-inspector-close')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('material-request-information-panel')),
        findsNothing,
      );
    },
  );

  group('Material Request history', () {
    test(
      'maps the bounded server response without reconstructing audit data',
      () {
        final page = YorksV1MaterialRequestHistoryPage.fromRpcJson({
          'items': [
            {
              'id': 'event-1',
              'event_type': 'material_request_submitted',
              'entity_type': 'material_request',
              'occurred_at': '2026-09-08T09:15:00Z',
              'actor_display_name': 'Noor Zaman',
              'actor_exact_role': 'site_engineer',
              'reference': 'YRA-322-MR017',
              'reason': null,
              'facts': {'state': 'submitted', 'record_version': '2'},
            },
          ],
          'has_more': true,
          'next_before_occurred_at': '2026-09-08T09:15:00Z',
          'next_before_id': 'event-1',
        });

        expect(page.items.single.actorDisplayName, 'Noor Zaman');
        expect(page.items.single.actorExactRole, 'site_engineer');
        expect(page.items.single.facts, {
          'state': 'submitted',
          'record_version': '2',
        });
        expect(page.hasMore, isTrue);
        expect(page.nextBeforeId, 'event-1');
      },
    );

    test(
      'uses only the request-scoped protected RPC and cursor parameters',
      () async {
        final rpc = _RecordingHistoryRpc(_historyFixture());
        final repository = YorksV1SupabaseMaterialRequestHistoryRepository(
          featureFlags: const YorksV1FeatureFlags(
            foundation: true,
            projects: true,
            boq: true,
            excel: true,
            requests: true,
          ),
          connectivity: DefaultConnectivity(),
          rpcClient: rpc,
        );

        await repository.getHistory(
          YorksV1MaterialRequestHistoryQuery(
            requestId: 'request-1',
            beforeOccurredAt: DateTime.utc(2026, 9, 8, 9, 15),
            beforeId: 'event-1',
            limit: 20,
          ),
        );

        expect(rpc.functionName, 'v1_get_material_request_history');
        expect(rpc.parameters, {
          'p_request_id': 'request-1',
          'p_before_occurred_at': '2026-09-08T09:15:00.000Z',
          'p_before_id': 'event-1',
          'p_limit': 20,
        });
      },
    );

    test('fails closed offline before invoking request history', () async {
      final rpc = _RecordingHistoryRpc(_historyFixture());
      final repository = YorksV1SupabaseMaterialRequestHistoryRepository(
        featureFlags: const YorksV1FeatureFlags(
          foundation: true,
          projects: true,
          boq: true,
          excel: true,
          requests: true,
        ),
        connectivity: DefaultConnectivity(online: false),
        rpcClient: rpc,
      );

      await expectLater(
        repository.getHistory(
          const YorksV1MaterialRequestHistoryQuery(requestId: 'request-1'),
        ),
        throwsA(
          isA<YorksV1DomainException>().having(
            (error) => error.code,
            'code',
            YorksV1DomainErrorCode.offline,
          ),
        ),
      );
      expect(rpc.functionName, isNull);
    });

    testWidgets(
      'history keeps its geometry through detail refresh and clears on explicit invalidation',
      (tester) async {
        final detailRevision = StateProvider((ref) => 0);
        var detail = Completer<YorksV1MaterialRequest>();
        final repository = _CountingHistoryRepository();
        final container = ProviderContainer(
          overrides: [
            yorksV1MaterialRequestDetailProvider('request-1').overrideWith((
              ref,
            ) {
              ref.watch(detailRevision);
              return detail.future;
            }),
            yorksV1MaterialRequestHistoryRepositoryProvider.overrideWithValue(
              repository,
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: YorksV1MaterialRequestHistorySection(
                  requestId: 'request-1',
                  language: AppLanguage.english,
                ),
              ),
            ),
          ),
        );
        detail.complete(_historyRequest);
        await tester.pumpAndSettle();
        expect(repository.calls, 1);
        final surface = find.byKey(const ValueKey('material-request-history'));
        final height = tester.getSize(surface).height;
        expect(find.text('Submitted for approval'), findsOneWidget);
        detail = Completer<YorksV1MaterialRequest>();
        container.read(detailRevision.notifier).state++;
        await tester.pump();
        expect(find.text('Submitted for approval'), findsOneWidget);
        expect(tester.getSize(surface).height, height);
        expect(repository.calls, 1);
        detail.complete(_historyRequest);
        await tester.pumpAndSettle();
        expect(repository.calls, 2);
        expect(tester.getSize(surface).height, height);
        // Explicit permission invalidation does not show previously authorized data.
        repository.pending = Completer<YorksV1MaterialRequestHistoryPage>();
        container.invalidate(
          yorksV1MaterialRequestHistoryPageProvider(
            const YorksV1MaterialRequestHistoryQuery(requestId: 'request-1'),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('Submitted for approval'), findsNothing);
        repository.pending!.completeError(
          const YorksV1DomainException(YorksV1DomainErrorCode.unauthorized),
        );
        await tester.pumpAndSettle();
        expect(find.text('Submitted for approval'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders only the server-supplied request event in the inspector',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            yorksV1MaterialRequestHistoryRepositoryProvider.overrideWithValue(
              _FixtureHistoryRepository(),
            ),
            yorksV1MaterialRequestDetailProvider(
              'request-1',
            ).overrideWith((ref) async => _historyRequest),
            yorksV1CurrentPermissionSnapshotProvider.overrideWith(
              (ref) => YorksV1TestPermissionController(
                yorksV1TrustedFeaturePermissionState(
                  role: YorksV1Role.projectEngineer,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: YorksV1MaterialRequestHistorySection(
                  requestId: 'request-1',
                  language: AppLanguage.english,
                ),
              ),
            ),
          ),
        );
        await container.read(
          yorksV1MaterialRequestHistoryPageProvider(
            const YorksV1MaterialRequestHistoryQuery(requestId: 'request-1'),
          ).future,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));

        final history = container.read(
          yorksV1MaterialRequestHistoryPageProvider(
            const YorksV1MaterialRequestHistoryQuery(requestId: 'request-1'),
          ),
        );
        expect(
          history.hasError,
          isFalse,
          reason: '${history.error}\n${history.stackTrace}',
        );

        expect(
          find.byType(YorksV1MaterialRequestHistorySection),
          findsOneWidget,
        );
        expect(find.text('Request history'), findsOneWidget);
        expect(find.text('Submitted for approval'), findsOneWidget);
        expect(find.text('Noor Zaman · Site Engineer'), findsOneWidget);
        expect(find.text('Supplier price AED 12345'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('opens history immediately in the shared information panel', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          yorksV1MaterialRequestHistoryRepositoryProvider.overrideWithValue(
            _FixtureHistoryRepository(),
          ),
          yorksV1MaterialRequestDetailProvider(
            'request-1',
          ).overrideWith((ref) async => _historyRequest),
          yorksV1CurrentPermissionSnapshotProvider.overrideWith(
            (ref) => YorksV1TestPermissionController(
              yorksV1TrustedFeaturePermissionState(
                role: YorksV1Role.projectEngineer,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showYorksV1RequestInformation(
                    context,
                    request: _historyRequest,
                    language: AppLanguage.english,
                  ),
                  child: const Text('Open request information'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open request information'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await container.read(
        yorksV1MaterialRequestHistoryPageProvider(
          const YorksV1MaterialRequestHistoryQuery(requestId: 'request-1'),
        ).future,
      );
      await tester.pump();

      expect(find.text('Request history'), findsOneWidget);
      expect(find.text('Submitted for approval'), findsOneWidget);
      expect(find.text('Noor Zaman · Site Engineer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('labels a returned decision from its allowlisted facts', (
      tester,
    ) async {
      final repository = _FixtureHistoryRepository(
        page: YorksV1MaterialRequestHistoryPage(
          items: [
            YorksV1MaterialRequestHistoryEvent(
              id: 'decision-returned',
              eventType: 'material_request_decided',
              entityType: 'material_request',
              occurredAt: DateTime.utc(2026, 9, 8, 9, 20),
              actorDisplayName: 'Ali Raza',
              actorExactRole: 'project_engineer',
              reference: 'YRA-322-MR017',
              facts: const {'decision': 'returned_for_changes'},
            ),
          ],
          hasMore: false,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            yorksV1MaterialRequestDetailProvider(
              'request-1',
            ).overrideWith((ref) async => _historyRequest),
            yorksV1MaterialRequestHistoryRepositoryProvider.overrideWithValue(
              repository,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: YorksV1MaterialRequestHistorySection(
                requestId: 'request-1',
                language: AppLanguage.english,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Returned for changes'), findsOneWidget);
      expect(find.text('Request approved'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps earlier-history failure inline and retryable', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            yorksV1MaterialRequestDetailProvider(
              'request-1',
            ).overrideWith((ref) async => _historyRequest),
            yorksV1MaterialRequestHistoryRepositoryProvider.overrideWithValue(
              _PagingFailureHistoryRepository(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: YorksV1MaterialRequestHistorySection(
                requestId: 'request-1',
                language: AppLanguage.english,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View full audit trail'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load earlier history'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Earlier history could not be loaded. Try again when the connection is available.',
        ),
        findsOneWidget,
      );
      expect(find.text('Load earlier history'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _FixtureHistoryRepository
    implements YorksV1MaterialRequestHistoryRepository {
  _FixtureHistoryRepository({this.page});

  final YorksV1MaterialRequestHistoryPage? page;

  @override
  Future<YorksV1MaterialRequestHistoryPage> getHistory(
    YorksV1MaterialRequestHistoryQuery query,
  ) async =>
      page ??
      YorksV1MaterialRequestHistoryPage(
        items: [
          YorksV1MaterialRequestHistoryEvent(
            id: 'event-1',
            eventType: 'material_request_submitted',
            entityType: 'material_request',
            occurredAt: DateTime.utc(2026, 9, 8, 9, 15),
            actorDisplayName: 'Noor Zaman',
            actorExactRole: 'site_engineer',
            reference: 'YRA-322-MR017',
            facts: const {'state': 'submitted'},
          ),
        ],
        hasMore: false,
      );
}

class _PagingFailureHistoryRepository
    implements YorksV1MaterialRequestHistoryRepository {
  @override
  Future<YorksV1MaterialRequestHistoryPage> getHistory(
    YorksV1MaterialRequestHistoryQuery query,
  ) async {
    if (query.beforeId != null) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        serverMessage: 'history unavailable',
      );
    }
    return YorksV1MaterialRequestHistoryPage(
      items: [
        YorksV1MaterialRequestHistoryEvent(
          id: 'event-page-1',
          eventType: 'material_request_submitted',
          entityType: 'material_request',
          occurredAt: DateTime.utc(2026, 9, 8, 9, 15),
          actorDisplayName: 'Noor Zaman',
          actorExactRole: 'site_engineer',
          reference: 'YRA-322-MR017',
          facts: const {'state': 'submitted'},
        ),
      ],
      hasMore: true,
      nextBeforeOccurredAt: DateTime.utc(2026, 9, 8, 9, 15),
      nextBeforeId: 'event-page-1',
    );
  }
}

final _historyRequest = YorksV1MaterialRequest(
  id: 'request-1',
  projectId: 'project-1',
  projectReference: 'YRA-322',
  projectName: 'Marina Retail Fit-out',
  scopeId: 'scope-1',
  scopeName: 'Building A',
  state: YorksV1MaterialRequestState.submitted,
  recordVersion: 1,
  createdAt: DateTime.utc(2026, 9, 8, 9),
  updatedAt: DateTime.utc(2026, 9, 8, 9, 15),
  timing: YorksV1MaterialRequestTiming.normal,
  requestNumber: 'YRA-322-MR017',
  requesterDisplayName: 'Noor Zaman',
  requesterProjectRole: 'site_engineer',
  currentActionOwnerRole: 'procurement',
  lines: const [],
);

class _RecordingHistoryRpc implements YorksV1MaterialRequestHistoryRpcClient {
  _RecordingHistoryRpc(this.response);

  final Object? response;
  String? functionName;
  Map<String, Object?>? parameters;

  @override
  Future<Object?> invoke(
    String functionName, {
    required Map<String, Object?> parameters,
  }) async {
    this.functionName = functionName;
    this.parameters = parameters;
    return response;
  }
}

Map<String, dynamic> _historyFixture() => {
  'items': const [],
  'has_more': false,
  'next_before_occurred_at': null,
  'next_before_id': null,
};

class _CountingHistoryRepository extends _FixtureHistoryRepository {
  int calls = 0;
  Completer<YorksV1MaterialRequestHistoryPage>? pending;
  @override
  Future<YorksV1MaterialRequestHistoryPage> getHistory(
    YorksV1MaterialRequestHistoryQuery query,
  ) {
    calls++;
    return pending?.future ?? super.getHistory(query);
  }
}
