import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/yorks_v1_workspace_shell.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/shared/models/yorks_v1_audit_workspace.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_workspace_status.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_audit_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_workspace_status_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_audit_repository.dart';
import 'package:material_ledger/shared/screens/activity_log_screen.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('trusted Audit Workspace repository', () {
    test(
      'uses the trusted RPC and maps exact server actor attribution',
      () async {
        final rpc = _RecordingRpc(_fixtureJson());
        final repository = YorksV1SupabaseAuditRepository(
          featureFlags: const YorksV1FeatureFlags(foundation: true),
          connectivity: DefaultConnectivity(),
          rpcClient: rpc,
        );

        final workspace = await repository.getWorkspace(
          const YorksV1AuditFilter(
            search: 'MR001',
            module: YorksV1AuditModule.materialRequests,
            quickFilter: YorksV1AuditQuickFilter.approvals,
            page: 2,
            pageSize: 12,
          ),
        );

        expect(rpc.functionName, 'v1_get_audit_workspace');
        expect(rpc.parameters?['p_search'], 'MR001');
        expect(rpc.parameters?['p_module'], 'material_requests');
        expect(rpc.parameters?['p_quick_filter'], 'approvals');
        expect(rpc.parameters?['p_offset'], 24);
        expect(workspace.events.single.actorExactRole, 'project_manager');
        expect(workspace.events.single.actorDisplayName, 'Mariam Khan');
        expect(workspace.events.single.facts, {'state': 'approved'});
      },
    );

    test('stops safely when offline without invoking the server', () async {
      final rpc = _RecordingRpc(_fixtureJson());
      final repository = YorksV1SupabaseAuditRepository(
        featureFlags: const YorksV1FeatureFlags(foundation: true),
        connectivity: DefaultConnectivity(online: false),
        rpcClient: rpc,
      );

      await expectLater(
        repository.getWorkspace(const YorksV1AuditFilter()),
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
  });

  test(
    'controller ignores an older response after a newer filter wins',
    () async {
      final repository = _DeferredRepository();
      final controller = YorksV1AuditController(repository);
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(repository.requests, hasLength(1));

      final newer = controller.setSearch('latest');
      expect(repository.requests, hasLength(2));
      repository.completers[1].complete(_fixtureWorkspace(reference: 'LATEST'));
      await newer;
      repository.completers[0].complete(_fixtureWorkspace(reference: 'STALE'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.workspace?.events.single.reference, 'LATEST');
      expect(controller.state.filter.search, 'latest');
    },
  );

  group('responsive Audit Workspace', () {
    for (final size in [const Size(1366, 768), const Size(390, 844)]) {
      testWidgets('renders trusted data without overflow at ${size.width}', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
              yorksV1AuditRepositoryProvider.overrideWithValue(
                _StaticRepository(_fixtureWorkspace()),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: const Scaffold(body: ActivityLogScreen()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));

        expect(find.text('System audit & integrity'), findsOneWidget);
        expect(find.text('Recent activity feed'), findsOneWidget);
        expect(
          find.textContaining('Mariam Khan', skipOffstage: false),
          findsWidgets,
        );
        expect(
          find.textContaining('Project Manager', skipOffstage: false),
          findsWidgets,
        );
        expect(
          find.text('Arrangement approved', skipOffstage: false),
          findsWidgets,
        );
        expect(find.text('12,480'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('deterministic Audit Workspace visual evidence', () {
    final fixtures = <(Size, String)>[
      (const Size(1366, 768), 'goldens/r35/audit_workspace_desktop.png'),
      (const Size(390, 844), 'goldens/r35/audit_workspace_mobile_390.png'),
      (const Size(360, 800), 'goldens/r35/audit_workspace_mobile_360.png'),
    ];
    for (final fixture in fixtures) {
      testWidgets('Admin Audit Workspace — ${fixture.$1}', (tester) async {
        await _pumpAuditShell(tester, fixture.$1);
        await expectLater(
          find.byType(YorksV1WorkspaceShell),
          matchesGoldenFile(fixture.$2),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}

Future<void> _pumpAuditShell(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const YorksV1WorkspaceShell(child: ActivityLogScreen()),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.admin),
        yorksV1WorkspaceStatusProvider.overrideWithValue(
          const YorksV1WorkspaceStatus(
            state: YorksV1WorkspaceConnectionState.connected,
          ),
        ),
        yorksV1AuditRepositoryProvider.overrideWithValue(
          _StaticRepository(_fixtureWorkspace()),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/logo.png'),
      tester.element(find.byType(YorksV1WorkspaceShell)),
    ),
  );
  await tester.pump();
}

class _RecordingRpc implements YorksV1AuditRpcClient {
  _RecordingRpc(this.response);
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

class _StaticRepository implements YorksV1AuditRepository {
  const _StaticRepository(this.workspace);
  final YorksV1AuditWorkspace workspace;

  @override
  Future<YorksV1AuditWorkspace> getWorkspace(YorksV1AuditFilter filter) async =>
      workspace;
}

class _DeferredRepository implements YorksV1AuditRepository {
  final requests = <YorksV1AuditFilter>[];
  final completers = <Completer<YorksV1AuditWorkspace>>[];

  @override
  Future<YorksV1AuditWorkspace> getWorkspace(YorksV1AuditFilter filter) {
    requests.add(filter);
    final completer = Completer<YorksV1AuditWorkspace>();
    completers.add(completer);
    return completer.future;
  }
}

YorksV1AuditWorkspace _fixtureWorkspace({String reference = 'YRA313-MR001'}) =>
    YorksV1AuditWorkspace.fromRpcJson(_fixtureJson(reference: reference));

Map<String, dynamic> _fixtureJson({String reference = 'YRA313-MR001'}) => {
  'generated_at': '2026-08-13T08:30:00Z',
  'summary': {
    'total_activities': 12480,
    'critical_activities': 36,
    'active_users': 48,
    'entities_monitored': 12760,
    'audit_alerts': 14,
    'data_integrity_percent': 98.7,
    'current_period_activities': 342,
    'previous_period_activities': 296,
  },
  'filtered_count': 1,
  'limit': 12,
  'offset': 0,
  'events': [
    {
      'id': 'a0000000-0000-4000-8000-000000000001',
      'event_type': 'arrangement_approved',
      'entity_type': 'procurement_arrangement',
      'entity_id': 'a1000000-0000-4000-8000-000000000001',
      'project_id': 'a2000000-0000-4000-8000-000000000001',
      'module': 'material_requests',
      'severity': 'normal',
      'actor_auth_user_id': 'a3000000-0000-4000-8000-000000000001',
      'actor_display_name': 'Mariam Khan',
      'actor_exact_role': 'project_manager',
      'occurred_at': '2026-08-13T08:25:00Z',
      'reference': reference,
      'project_ref': 'YRA313',
      'project_name': 'Yorks Tower',
      'reason': 'Approved arranged items for delivery',
      'facts': {'state': 'approved'},
      'attribution_verified': true,
    },
  ],
  'top_entities': [
    {'entity_type': 'material_request', 'activity_count': 342, 'percent': 27.0},
    {'entity_type': 'project', 'activity_count': 296, 'percent': 24.0},
  ],
  'module_activity': [
    {'module': 'material_requests', 'activity_count': 342, 'percent': 42.0},
    {'module': 'projects', 'activity_count': 296, 'percent': 36.0},
    {'module': 'inventory', 'activity_count': 180, 'percent': 22.0},
  ],
  'trend': [
    {'date': '2026-08-07', 'activity_count': 200},
    {'date': '2026-08-08', 'activity_count': 230},
    {'date': '2026-08-09', 'activity_count': 400},
    {'date': '2026-08-10', 'activity_count': 150},
    {'date': '2026-08-11', 'activity_count': 290},
    {'date': '2026-08-12', 'activity_count': 210},
    {'date': '2026-08-13', 'activity_count': 520},
  ],
  'quick_filters': {
    'critical': 36,
    'exceptions': 8,
    'data_changes': 128,
    'approvals': 94,
    'access': 72,
  },
  'alerts': [
    {
      'id': 'a4000000-0000-4000-8000-000000000001',
      'event_type': 'material_request_cancelled',
      'entity_type': 'material_request',
      'severity': 'critical',
      'reference': 'YRA313-MR009',
      'reason': 'Cancelled by Admin after review',
      'occurred_at': '2026-08-13T08:20:00Z',
    },
  ],
};
