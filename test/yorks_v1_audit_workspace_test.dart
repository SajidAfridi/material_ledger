import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'package:material_ledger/shared/services/yorks_v1_audit_export.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('NexusSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final arabic = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    await font.load();
    await arabic.load();
    var cache = File(Platform.resolvedExecutable).parent;
    while (!cache.path.endsWith('${Platform.pathSeparator}cache') &&
        cache.parent.path != cache.path) {
      cache = cache.parent;
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            await File(
              '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes(),
          ),
        ),
      );
    await icons.load();
  });
  test('CSV keeps spreadsheet formulas and multiline evidence as text', () {
    for (final value in [
      '=SUM(A1:A2)',
      '+cmd',
      '-1+2',
      '@SUM(1)',
      '  =1',
      '\t=1',
      '\r=1',
    ]) {
      expect(yorksV1AuditCsvCell(value), startsWith('"\''));
    }
    expect(yorksV1AuditCsvCell('A,"B"\nC'), '"A,""B""\nC"');
    final csv = yorksV1AuditCsv(
      _fixtureWorkspace(),
      const YorksV1AuditFilter(search: 'MR001'),
    );
    expect(csv, contains('Event ID'));
    expect(csv, contains('p_search'));
    expect(csv, contains('UTC'));
    expect(csv, contains('YRA313-MR001'));
  });
  test('denied refresh purges evidence and disables exports', () async {
    final repository = _DeferredRepository();
    final controller = YorksV1AuditController(repository);
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);
    repository.completers.single.complete(_fixtureWorkspace());
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.canExport, isTrue);
    final refresh = controller.refresh();
    expect(controller.state.canExport, isFalse);
    repository.completers.last.completeError(
      const YorksV1DomainException(YorksV1DomainErrorCode.unauthorized),
    );
    await refresh;
    expect(controller.state.workspace, isNull);
    expect(controller.state.loadedFilter, isNull);
    expect(controller.state.canExport, isFalse);
  });
  test(
    'failed filter keeps last successful scope separate and blocks export',
    () async {
      final repository = _DeferredRepository();
      final controller = YorksV1AuditController(repository);
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);
      repository.completers.single.complete(_fixtureWorkspace());
      await Future<void>.delayed(Duration.zero);
      final request = controller.setSearch('different');
      repository.completers.last.completeError(
        const YorksV1DomainException(YorksV1DomainErrorCode.offline),
      );
      await request;
      expect(controller.state.workspace, isNotNull);
      expect(controller.state.loadedFilter!.search, isEmpty);
      expect(controller.state.filter.search, 'different');
      expect(controller.state.canExport, isFalse);
    },
  );
  for (final size in [const Size(1366, 768), const Size(360, 800)]) {
    testWidgets('inspect event facts and history at ${size.width}', (
      tester,
    ) async {
      await _pumpAuditShell(tester, size);
      await tester.scrollUntilVisible(
        find.text('Arrangement approved').first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Arrangement approved').first),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arrangement approved').first);
      await tester.pumpAndSettle();
      expect(find.text('Event details'), findsOneWidget);
      expect(find.text('Same-record history'), findsOneWidget);
      expect(find.textContaining('(UTC)'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/r35/audit_details_${size.width.toInt()}.png',
        ),
      );
      await tester.tap(find.byTooltip('Close').last);
      await tester.pumpAndSettle();
      expect(find.text('Event details'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  group('trusted Audit Workspace repository', () {
    test(
      'export rejects a truncated response and binds idempotency identity',
      () async {
        final json = _fixtureJson();
        json['filtered_count'] = 2;
        final rpc = _RecordingRpc(json);
        final repository = YorksV1SupabaseAuditRepository(
          featureFlags: const YorksV1FeatureFlags(foundation: true),
          connectivity: DefaultConnectivity(),
          rpcClient: rpc,
        );
        await expectLater(
          repository.exportWorkspace(
            const YorksV1AuditFilter(search: 'MR001'),
            'export-1',
          ),
          throwsA(
            isA<YorksV1DomainException>().having(
              (e) => e.code,
              'code',
              YorksV1DomainErrorCode.unexpectedResponse,
            ),
          ),
        );
        expect(rpc.functionName, 'v1_export_audit_workspace');
        expect(rpc.parameters!['p_id'], 'export-1');
        expect((rpc.parameters!['p_filters'] as Map)['p_search'], 'MR001');
      },
    );
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

        expect(rpc.functionName, 'v1_get_audit_workspace_v2');
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
        expect(find.textContaining('12,480'), findsWidgets);
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
  for (final locale in ['ar', 'ur']) {
    testWidgets('RTL $locale supports filters and enlarged text', (
      tester,
    ) async {
      await _pumpAuditShell(
        tester,
        const Size(390, 844),
        locale: locale,
        textScale: 1.4,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/r35/audit_workspace_${locale}_large.png'),
      );
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -450),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('tablet supports details and filter controls', (tester) async {
    await _pumpAuditShell(tester, const Size(820, 1180));
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Apply filters'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/r35/audit_filters_tablet.png'),
    );
  });
}

Future<void> _pumpAuditShell(
  WidgetTester tester,
  Size size, {
  String locale = 'en',
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({'selected_language': locale});
  final preferences = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/activity',
    routes: [
      GoRoute(
        path: '/activity',
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
        yorksV1AuditNowProvider.overrideWithValue(DateTime(2026, 9, 18)),
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
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        locale: Locale(locale),
        supportedLocales: const [
          Locale('en'),
          Locale('ar'),
          Locale('ur'),
          Locale('hi'),
        ],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
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
  Future<YorksV1AuditWorkspace> exportWorkspace(
    YorksV1AuditFilter filter,
    String id,
  ) async => workspace;

  @override
  Future<YorksV1AuditWorkspace> getWorkspace(YorksV1AuditFilter filter) async =>
      workspace;
}

class _DeferredRepository implements YorksV1AuditRepository {
  @override
  Future<YorksV1AuditWorkspace> exportWorkspace(
    YorksV1AuditFilter filter,
    String id,
  ) => getWorkspace(filter);
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
