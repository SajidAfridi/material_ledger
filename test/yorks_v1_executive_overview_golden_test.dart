import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/projects/presentation/screens/yorks_v1_executive_overview.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/yorks_v1_audit_workspace.dart';
import 'package:material_ledger/shared/models/yorks_v1_configuration.dart';
import 'package:material_ledger/shared/models/yorks_v1_logistics.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_project.dart';
import 'package:material_ledger/shared/models/yorks_v1_project_portfolio.dart';
import 'package:material_ledger/shared/models/yorks_v1_rental.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/yorks_v1_audit_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadGoldenFonts);

  for (final evidence in <({String name, Size size, YorksV1Role role})>[
    (
      name: 'admin_command_centre_desktop.png',
      size: const Size(1440, 900),
      role: YorksV1Role.admin,
    ),
    (
      name: 'leadership_portfolio_mobile.png',
      size: const Size(390, 844),
      role: YorksV1Role.seniorMechanicalEngineer,
    ),
  ]) {
    testWidgets('executive overview visual evidence ${evidence.name}', (
      tester,
    ) async {
      tester.view.physicalSize = evidence.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: Scaffold(
              body: YorksV1ExecutiveOverview(
                language: AppLanguage.english,
                role: evidence.role,
                displayName: evidence.role == YorksV1Role.admin
                    ? 'Owner'
                    : 'Khaled S. Sleiman',
                projects: AsyncData(_projects),
                requests: AsyncData(_requests),
                inventory: AsyncData(
                  YorksV1InventoryWorkspace(
                    items: [],
                    summary: YorksV1InventorySummary(
                      totalActiveItems: 1240,
                      lowStockCount: 6,
                      outOfStockCount: 2,
                      reservedCount: 18,
                      incomingCount: 0,
                    ),
                  ),
                ),
                configuration: AsyncData(_configuration),
                rentals: AsyncData(_rentals),
                audit: _audit,
                activeUsers: 18,
                canBrowseInventory: true,
                canAccessRentals: true,
                onRefresh: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(YorksV1ExecutiveOverview),
        matchesGoldenFile('goldens/r38_10/${evidence.name}'),
      );
    });
  }
}

final _projects = <YorksV1ProjectPortfolioItem>[
  _project(
    'p-1',
    'YRA-322',
    'Nexus Power Bulk Transmission',
    YorksV1ProjectLifecycle.active,
    0,
  ),
  _project(
    'p-2',
    'YRA-314',
    'Independent Subsea HVDC System',
    YorksV1ProjectLifecycle.active,
    1,
  ),
  _project(
    'p-3',
    'YRA-324',
    'Nexus Interconnection Phase One',
    YorksV1ProjectLifecycle.onHold,
    2,
  ),
  _project(
    'p-4',
    'YRA-319',
    'Taiz Ruwais Derivative Park',
    YorksV1ProjectLifecycle.completed,
    3,
  ),
];

YorksV1ProjectPortfolioItem _project(
  String id,
  String reference,
  String name,
  YorksV1ProjectLifecycle state,
  int daysAgo,
) => YorksV1ProjectPortfolioItem(
  project: YorksV1Project(
    id: id,
    reference: reference,
    name: name,
    state: state,
    version: 1,
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 21).subtract(Duration(days: daysAgo)),
    siteLocation: 'Abu Dhabi, UAE',
  ),
  activeBuildingCount: 3,
  activeProjectEngineerCount: 2,
  activeSiteEngineerCount: 2,
);

final _requests = <YorksV1MaterialRequest>[
  _request('01', YorksV1MaterialRequestState.awaitingRequestApproval),
  _request('02', YorksV1MaterialRequestState.awaitingApproval),
  _request('03', YorksV1MaterialRequestState.changesRequested),
  _request('04', YorksV1MaterialRequestState.approved),
  _request('05', YorksV1MaterialRequestState.partiallyDispatched),
  _request('06', YorksV1MaterialRequestState.dispatched),
  _request('07', YorksV1MaterialRequestState.partiallyReceived),
  _request('08', YorksV1MaterialRequestState.received),
  _request('09', YorksV1MaterialRequestState.closed),
];

YorksV1MaterialRequest _request(String id, YorksV1MaterialRequestState state) =>
    YorksV1MaterialRequest(
      id: id,
      projectId: 'p-1',
      projectReference: 'YRA-322',
      projectName: 'Nexus Power Bulk Transmission',
      scopeId: 'scope-1',
      scopeName: 'DF6W 132/33kV Substation',
      state: state,
      recordVersion: 1,
      createdAt: DateTime.utc(2026, 8, 20),
      updatedAt: DateTime.utc(
        2026,
        8,
        21,
      ).subtract(Duration(minutes: int.parse(id) * 7)),
      lines: const [
        YorksV1MaterialRequestLine(
          id: 'line-1',
          displayOrder: 1,
          source: YorksV1MaterialRequestLineSource.custom,
          description: 'Controlled material package',
          quantity: '12',
          unit: 'Nos',
        ),
      ],
      timing: YorksV1MaterialRequestTiming.normal,
      requestNumber: 'YRA322-MR$id',
      title: 'Controlled material package',
      currentActionOwnerRole: 'project_engineer',
    );

final _configuration = YorksV1ConfigurationCentre(
  schemaVersion: 'r38',
  environment: 'production',
  publishedVersion: 13,
  publishedLabel: 'v1.3.0',
  publishedAt: DateTime.utc(2026, 8, 20),
  publishedBy: 'Owner',
  draftRevision: 2,
  draftBaseVersion: 13,
  draftUpdatedAt: DateTime.utc(2026, 8, 21),
  settings: const [],
  masterActions: const [],
  categories: const [],
  units: const [],
  boqTemplates: const [],
  history: const [],
  validation: const YorksV1ConfigurationValidation(
    status: YorksV1ConfigurationValidationStatus.recommendations,
    blocking: [],
    recommendations: [
      YorksV1ConfigurationIssue(
        code: 'review',
        area: YorksV1ConfigurationArea.securityAudit,
        message: 'Review access policy',
      ),
    ],
  ),
);

final _rentals = YorksV1RentalPortfolio(
  asOf: DateTime.utc(2026, 8, 21),
  summary: const YorksV1RentalSummary(
    totalProperties: 8,
    occupied: 7,
    monthlyRentRoll: 95000,
    collectedThisMonth: 88000,
    outstanding: 7000,
    securityDeposits: 120000,
    expiringWithin90: 1,
    chequeAttention: 1,
  ),
  properties: const [],
  recentPayments: const [],
  cheques: const [],
);

final _audit = YorksV1AuditViewState(
  isLoading: false,
  workspace: YorksV1AuditWorkspace(
    generatedAt: DateTime.utc(2026, 8, 21),
    summary: const YorksV1AuditSummary(
      totalActivities: 214,
      criticalActivities: 1,
      activeUsers: 18,
      entitiesMonitored: 64,
      auditAlerts: 1,
      dataIntegrityPercent: 100,
      currentPeriodActivities: 39,
      previousPeriodActivities: 35,
    ),
    filteredCount: 1,
    limit: 12,
    offset: 0,
    events: [
      YorksV1AuditEvent(
        id: 'audit-1',
        eventType: 'configuration_published',
        entityType: 'configuration',
        entityId: 'config-13',
        module: YorksV1AuditModule.system,
        severity: YorksV1AuditSeverity.warning,
        actorAuthUserId: 'owner',
        actorDisplayName: 'Owner',
        actorExactRole: 'admin',
        occurredAt: DateTime.utc(2026, 8, 21, 8, 30),
        reference: 'Configuration v1.3.0',
        facts: const {},
        attributionVerified: true,
      ),
    ],
    topEntities: const [],
    moduleActivity: const [],
    trend: const [],
    quickFilterCounts: const {},
    alerts: const [],
  ),
);

Future<void> _loadGoldenFonts() async {
  final nexus = FontLoader('NexusSans')
    ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
  final arabic = FontLoader('NotoSansArabic')
    ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
  final cache = _flutterCacheDirectory();
  final icons = await File(
    '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytes();
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(icons)));
  await Future.wait([nexus.load(), arabic.load(), materialIcons.load()]);
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
