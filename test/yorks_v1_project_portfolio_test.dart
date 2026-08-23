import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/projects/presentation/screens/yorks_v1_projects_screen.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_project.dart';
import 'package:material_ledger/shared/models/yorks_v1_project_portfolio.dart';
import 'package:material_ledger/shared/models/yorks_v1_project_strings.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_portfolio_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_project_portfolio_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('project references use natural YRA ordering', () {
    final references = ['YRA-100', 'YRA-9', 'YRA-21', 'YRA-2'];

    references.sort(compareYorksProjectReferences);

    expect(references, ['YRA-2', 'YRA-9', 'YRA-21', 'YRA-100']);
  });

  test(
    'portfolio composes only authorized non-commercial project context',
    () async {
      final repository = YorksV1SupabaseProjectPortfolioRepository(
        featureFlags: _enabledFlags,
        dataClient: _FakePortfolioDataClient(),
      );

      final portfolio = await repository.listPortfolio();

      expect(portfolio, hasLength(1));
      expect(portfolio.single.project.reference, 'YRK-2601');
      expect(portfolio.single.clientName, 'Yorks Client');
      expect(portfolio.single.activeBuildingCount, 2);
      expect(portfolio.single.activeProjectEngineerCount, 1);
      expect(portfolio.single.activeSiteEngineerCount, 1);
      expect(portfolio.single.activeTeamCount, 2);
    },
  );

  test(
    'portfolio fails closed while the project rollout is disabled',
    () async {
      final repository = YorksV1SupabaseProjectPortfolioRepository(
        featureFlags: const YorksV1FeatureFlags(),
        dataClient: _FakePortfolioDataClient(),
      );

      await expectLater(
        repository.listPortfolio(),
        throwsA(
          isA<YorksV1DomainException>().having(
            (error) => error.code,
            'code',
            YorksV1DomainErrorCode.featureDisabled,
          ),
        ),
      );
    },
  );

  testWidgets('R35 portfolio is responsive and procurement is view only', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final item = _portfolioItem;

    for (final size in [const Size(1366, 768), const Size(360, 800)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            yorksV1CurrentRoleProvider.overrideWithValue(
              YorksV1Role.procurement,
            ),
            yorksV1ProjectPortfolioProvider.overrideWith((ref) async => [item]),
          ],
          child: const MaterialApp(home: YorksV1ProjectsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(item.project.name), findsOneWidget);
      expect(
        find.text(YorksV1ProjectStrings.viewOnlyPortfolio.primary),
        findsOneWidget,
      );
      expect(
        find.text(YorksV1ProjectStrings.createProject.primary),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

const _enabledFlags = YorksV1FeatureFlags(foundation: true, projects: true);

final _portfolioItem = YorksV1ProjectPortfolioItem(
  project: YorksV1Project(
    id: 'project-1',
    reference: 'YRK-2601',
    name: 'Harbour Tower HVAC',
    state: YorksV1ProjectLifecycle.active,
    version: 3,
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 8, 1),
    siteLocation: 'Abu Dhabi',
    currentActionOwnerRole: 'procurement',
  ),
  clientName: 'Yorks Client',
  activeBuildingCount: 2,
  activeProjectEngineerCount: 1,
  activeSiteEngineerCount: 1,
);

class _FakePortfolioDataClient implements YorksV1ProjectPortfolioDataClient {
  @override
  Future<List<Map<String, dynamic>>> listProjectMembers(
    List<String> projectIds,
  ) async => [
    {
      'project_id': 'project-1',
      'project_role': 'project_engineer',
      'effective_from': '2020-01-01T00:00:00.000Z',
      'effective_to': null,
    },
    {
      'project_id': 'project-1',
      'project_role': 'site_engineer',
      'effective_from': '2020-01-01T00:00:00.000Z',
      'effective_to': null,
    },
    {
      'project_id': 'project-1',
      'project_role': 'site_engineer',
      'effective_from': '2020-01-01T00:00:00.000Z',
      'effective_to': '2021-01-01T00:00:00.000Z',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> listProjectParties(
    List<String> projectIds,
  ) async => [
    {
      'project_id': 'project-1',
      'party_kind': 'client',
      'party_order': 0,
      'party_name': 'Yorks Client',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> listProjectScopes(
    List<String> projectIds,
  ) async => [
    {'project_id': 'project-1', 'scope_kind': 'building', 'is_active': true},
    {'project_id': 'project-1', 'scope_kind': 'building', 'is_active': true},
  ];

  @override
  Future<List<Map<String, dynamic>>> listProjects() async => [
    {
      'id': 'project-1',
      'project_ref': 'YRK-2601',
      'name': 'Harbour Tower HVAC',
      'project_site': 'Abu Dhabi',
      'state': 'active',
      'current_action_owner_role': 'procurement',
      'record_version': 3,
      'created_at': '2026-07-01T00:00:00.000Z',
      'updated_at': '2026-08-01T00:00:00.000Z',
    },
  ];
}
