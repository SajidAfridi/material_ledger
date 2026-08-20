import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/yorks_v1_workspace_shell.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/projects/presentation/screens/yorks_v1_projects_screen.dart';
import 'package:material_ledger/shared/models/yorks_v1_logistics.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_workspace_status.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_logistics_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_portfolio_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_workspace_status_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deterministic first R35 visual-parity fixtures. These intentionally use
/// empty, role-safe server projections: visual tests must not depend on a live
/// Supabase project or a developer's local draft cache.
void main() {
  setUpAll(() async {
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
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('R35 engineer shell and overview — 1366×768', (tester) async {
    await _pumpOverview(
      tester,
      size: const Size(1366, 768),
      role: YorksV1Role.projectEngineer,
    );

    await expectLater(
      find.byType(YorksV1WorkspaceShell),
      matchesGoldenFile('goldens/r35/engineer_overview_desktop.png'),
    );
  });

  testWidgets('R35 engineer shell and overview — 360×800', (tester) async {
    await _pumpOverview(
      tester,
      size: const Size(360, 800),
      role: YorksV1Role.projectEngineer,
    );

    await expectLater(
      find.byType(YorksV1WorkspaceShell),
      matchesGoldenFile('goldens/r35/engineer_overview_mobile.png'),
    );
  });

  testWidgets('Yorks mobile engineer overview — 390×844', (tester) async {
    await _pumpOverview(
      tester,
      size: const Size(390, 844),
      role: YorksV1Role.projectEngineer,
    );

    await expectLater(
      find.byType(YorksV1WorkspaceShell),
      matchesGoldenFile('goldens/mobile_batch1/engineer_overview_390.png'),
    );
  });

  testWidgets('Yorks mobile procurement overview — 390×844', (tester) async {
    await _pumpOverview(
      tester,
      size: const Size(390, 844),
      role: YorksV1Role.procurement,
    );

    await expectLater(
      find.byType(YorksV1WorkspaceShell),
      matchesGoldenFile('goldens/mobile_batch1/procurement_overview_390.png'),
    );
  });

  testWidgets('R35 procurement shell and overview — 1366×768', (tester) async {
    await _pumpOverview(
      tester,
      size: const Size(1366, 768),
      role: YorksV1Role.procurement,
    );

    await expectLater(
      find.byType(YorksV1WorkspaceShell),
      matchesGoldenFile('goldens/r35/procurement_overview_desktop.png'),
    );
  });

  testWidgets('R35 administrator command centre — 1366×768', (tester) async {
    await _pumpOverview(
      tester,
      size: const Size(1366, 768),
      role: YorksV1Role.admin,
    );

    await expectLater(
      find.byType(YorksV1WorkspaceShell),
      matchesGoldenFile('goldens/r35/admin_overview_desktop.png'),
    );
  });

  testWidgets('R35 senior engineering portfolio — 1366×768', (tester) async {
    await _pumpOverview(
      tester,
      size: const Size(1366, 768),
      role: YorksV1Role.seniorMechanicalEngineer,
    );

    await expectLater(
      find.byType(YorksV1WorkspaceShell),
      matchesGoldenFile('goldens/r35/senior_mechanical_overview_desktop.png'),
    );
  });

  testWidgets('R35 site operations overview — 360×800', (tester) async {
    await _pumpOverview(
      tester,
      size: const Size(360, 800),
      role: YorksV1Role.siteEngineer,
    );

    await expectLater(
      find.byType(YorksV1WorkspaceShell),
      matchesGoldenFile('goldens/r35/site_engineer_overview_mobile_360.png'),
    );
  });
}

Future<void> _pumpOverview(
  WidgetTester tester, {
  required Size size,
  required YorksV1Role role,
}) async {
  tester.view.physicalSize = size;
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
        builder: (_, _) =>
            const YorksV1WorkspaceShell(child: YorksV1OverviewScreen()),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        yorksV1CurrentRoleProvider.overrideWithValue(role),
        yorksV1WorkspaceStatusProvider.overrideWithValue(
          const YorksV1WorkspaceStatus(
            state: YorksV1WorkspaceConnectionState.connected,
          ),
        ),
        yorksV1ProjectPortfolioProvider.overrideWith((ref) async => []),
        yorksV1MaterialRequestListProvider(
          null,
        ).overrideWith((ref) async => []),
        yorksV1InventoryWorkspaceProvider(null).overrideWith(
          (ref) async => YorksV1InventoryWorkspace(items: const []),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
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
