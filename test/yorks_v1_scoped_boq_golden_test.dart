import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/projects/presentation/screens/yorks_v1_boq_screens.dart';
import 'package:material_ledger/shared/models/yorks_v1_boq.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_boq_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deterministic R38 evidence: All is a project overview, while each actual
/// Common/building BOQ remains an independent workspace behind its own scope.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final evidence in <({String name, Size size})>[
    (name: 'scoped_boq_overview_desktop.png', size: const Size(1366, 768)),
    (name: 'scoped_boq_overview_mobile.png', size: const Size(360, 800)),
  ]) {
    testWidgets('R38 scoped BOQ All overview — ${evidence.size}', (
      tester,
    ) async {
      tester.view.physicalSize = evidence.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            yorksV1CurrentRoleProvider.overrideWithValue(
              YorksV1Role.projectEngineer,
            ),
            yorksV1MaterialRequestScopesProvider(
              _projectId,
            ).overrideWith((ref) async => _scopes),
            yorksV1ScopedBoqGroupsProvider(
              const YorksV1BoqScopeQuery(projectId: _projectId),
            ).overrideWith((ref) async => _groups),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const YorksV1BoqGroupsScreen(projectId: _projectId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Common / All Buildings'), findsOneWidget);
      expect(find.text('DF3W'), findsOneWidget);
      expect(find.text('DF4W'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/r35/${evidence.name}'),
      );
    });
  }
}

const _projectId = 'f1000000-0000-4000-8000-000000000001';

const _scopes = [
  YorksV1MaterialRequestScopeOption(
    id: 'f2000000-0000-4000-8000-000000000001',
    projectId: _projectId,
    name: 'Common / All Buildings',
    kind: 'common',
  ),
  YorksV1MaterialRequestScopeOption(
    id: 'f2000000-0000-4000-8000-000000000002',
    projectId: _projectId,
    name: 'DF3W',
    kind: 'building',
  ),
  YorksV1MaterialRequestScopeOption(
    id: 'f2000000-0000-4000-8000-000000000003',
    projectId: _projectId,
    name: 'DF4W',
    kind: 'building',
  ),
];

final _groups = [
  _group(
    id: 'f3000000-0000-4000-8000-000000000001',
    scope: _scopes[0],
    title: 'AC Units',
    rowCount: 4,
  ),
  _group(
    id: 'f3000000-0000-4000-8000-000000000002',
    scope: _scopes[0],
    title: 'Ventilation Fans',
  ),
  _group(
    id: 'f3000000-0000-4000-8000-000000000003',
    scope: _scopes[1],
    title: 'AC Units',
    rowCount: 12,
  ),
  _group(
    id: 'f3000000-0000-4000-8000-000000000004',
    scope: _scopes[1],
    title: 'Ventilation Fans',
    rowCount: 3,
  ),
  _group(
    id: 'f3000000-0000-4000-8000-000000000005',
    scope: _scopes[2],
    title: 'AC Units',
  ),
  _group(
    id: 'f3000000-0000-4000-8000-000000000006',
    scope: _scopes[2],
    title: 'Ventilation Fans',
    rowCount: 7,
  ),
];

YorksV1BoqGroup _group({
  required String id,
  required YorksV1MaterialRequestScopeOption scope,
  required String title,
  int rowCount = 0,
}) => YorksV1BoqGroup(
  id: id,
  projectId: _projectId,
  name: title,
  worksheetTitle: title,
  displayOrder: 1,
  isCustom: false,
  isArchived: false,
  version: 1,
  rowCount: rowCount,
  columnCount: 4,
  updatedAt: DateTime.utc(2026, 8, 8),
  scopeId: scope.id,
  scopeKind: scope.kind,
  scopeName: scope.name,
);
