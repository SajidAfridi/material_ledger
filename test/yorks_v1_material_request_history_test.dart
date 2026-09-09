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

    testWidgets(
      'opens request history on demand from the compact information sheet',
      (tester) async {
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
        final historyAction = find.byKey(
          const ValueKey('material-request-history-action'),
        );
        expect(historyAction, findsOneWidget);
        await tester.ensureVisible(historyAction);
        await tester.pump();

        await tester.tap(historyAction);
        await tester.pump();
        await container.read(
          yorksV1MaterialRequestHistoryPageProvider(
            const YorksV1MaterialRequestHistoryQuery(requestId: 'request-1'),
          ).future,
        );
        await tester.pump();

        expect(find.text('Request history'), findsAtLeastNWidgets(2));
        expect(find.text('Submitted for approval'), findsOneWidget);
        expect(find.text('Noor Zaman · Site Engineer'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

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
