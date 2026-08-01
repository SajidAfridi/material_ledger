import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_project_team_directory_member.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_team_directory_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_project_team_directory_repository.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';

void main() {
  group('Yorks V1 safe project team directory model', () {
    test('keeps only the safe selection projection', () {
      final member = YorksV1ProjectTeamDirectoryMember.fromRpcJson({
        'auth_user_id': 'auth-project-engineer',
        'display_name': 'Amina Project Engineer',
        'eligible_role': 'project_engineer',
        // A malformed server response may contain more fields, but the typed
        // model has no path to expose them to application state or widgets.
        'email': 'never-exposed@example.test',
        'legacy_app_user_id': 'legacy-never-exposed',
      });

      expect(member.authUserId, 'auth-project-engineer');
      expect(member.displayName, 'Amina Project Engineer');
      expect(member.eligibleRole, YorksV1Role.projectEngineer);
    });

    test('rejects an invalid directory role', () {
      expect(
        () => YorksV1ProjectTeamDirectoryMember.fromRpcJson({
          'auth_user_id': 'auth-procurement',
          'display_name': 'Procurement User',
          'eligible_role': 'procurement',
        }),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );
    });

    test('normalizes an email-like directory label to the UUID fallback', () {
      const authUserId = '00000000-0000-4000-8000-000000000042';
      final member = YorksV1ProjectTeamDirectoryMember.fromRpcJson({
        'auth_user_id': authUserId,
        'display_name': 'Amina <amina@example.test>',
        'eligible_role': 'project_engineer',
      });

      expect(member.displayName, authUserId);
      expect(
        YorksV1ProjectTeamDirectoryMember.isEmailLikeDisplayName(
          'amina@example.test',
        ),
        isTrue,
      );
    });

    test('rejects a non-list or malformed safe-directory wire response', () {
      expect(
        () => SupabaseYorksV1ProjectTeamDirectoryRpcClient.parseResponse({}),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );
      expect(
        () => SupabaseYorksV1ProjectTeamDirectoryRpcClient.parseResponse([
          'not-a-row',
        ]),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );
    });
  });

  group('Yorks V1 safe project team directory repository', () {
    test('maps the protected RPC list without a local fallback', () async {
      final rpc = _FakeDirectoryRpc(_safeDirectoryRows);
      final repository = YorksV1SupabaseProjectTeamDirectoryRepository(
        featureFlags: const YorksV1FeatureFlags(
          foundation: true,
          projects: true,
        ),
        connectivity: DefaultConnectivity(),
        rpcClient: rpc,
      );

      final members = await repository.listActiveMembers();

      expect(rpc.calls, 1);
      expect(members, hasLength(2));
      expect(members.first.displayName, 'Amina Project Engineer');
      expect(members.last.eligibleRole, YorksV1Role.siteEngineer);
    });

    test('fails closed while Projects are disabled or offline', () async {
      final disabledRpc = _FakeDirectoryRpc(_safeDirectoryRows);
      final disabled = YorksV1SupabaseProjectTeamDirectoryRepository(
        featureFlags: const YorksV1FeatureFlags(foundation: true),
        connectivity: DefaultConnectivity(),
        rpcClient: disabledRpc,
      );
      await expectLater(
        disabled.listActiveMembers(),
        throwsA(_domainCode(YorksV1DomainErrorCode.featureDisabled)),
      );
      expect(disabledRpc.calls, 0);

      final offlineRpc = _FakeDirectoryRpc(_safeDirectoryRows);
      final offline = YorksV1SupabaseProjectTeamDirectoryRepository(
        featureFlags: const YorksV1FeatureFlags(
          foundation: true,
          projects: true,
        ),
        connectivity: DefaultConnectivity(online: false),
        rpcClient: offlineRpc,
      );
      await expectLater(
        offline.listActiveMembers(),
        throwsA(_domainCode(YorksV1DomainErrorCode.offline)),
      );
      expect(offlineRpc.calls, 0);
    });
  });

  group('Yorks V1 safe project team directory provider', () {
    test(
      'exposes the safe projection only to a signed-in project creator',
      () async {
        final repository = _FakeDirectoryRepository(_safeDirectoryMembers);
        final container = ProviderContainer(
          overrides: [
            yorksV1AuthUserIdProvider.overrideWithValue('creator-auth-user'),
            yorksV1CurrentRoleProvider.overrideWithValue(
              YorksV1Role.projectEngineer,
            ),
            yorksV1ProjectTeamDirectoryRepositoryProvider.overrideWithValue(
              repository,
            ),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          yorksV1ActiveProjectTeamDirectoryProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        final members = await container.read(
          yorksV1ActiveProjectTeamDirectoryProvider.future,
        );

        expect(members, _safeDirectoryMembers);
        expect(repository.calls, 1);
      },
    );

    test('does not load a team list for a non-creator role', () async {
      final repository = _FakeDirectoryRepository(_safeDirectoryMembers);
      final container = ProviderContainer(
        overrides: [
          yorksV1AuthUserIdProvider.overrideWithValue('procurement-auth-user'),
          yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.procurement),
          yorksV1ProjectTeamDirectoryRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        yorksV1ActiveProjectTeamDirectoryProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await expectLater(
        container.read(yorksV1ActiveProjectTeamDirectoryProvider.future),
        throwsA(_domainCode(YorksV1DomainErrorCode.unauthorized)),
      );
      expect(repository.calls, 0);
    });
  });
}

const _safeDirectoryRows = [
  {
    'auth_user_id': 'auth-project-engineer',
    'display_name': 'Amina Project Engineer',
    'eligible_role': 'project_engineer',
  },
  {
    'auth_user_id': 'auth-site-engineer',
    'display_name': 'Bilal Site Engineer',
    'eligible_role': 'site_engineer',
  },
];

final _safeDirectoryMembers = [
  const YorksV1ProjectTeamDirectoryMember(
    authUserId: 'auth-project-engineer',
    displayName: 'Amina Project Engineer',
    eligibleRole: YorksV1Role.projectEngineer,
  ),
  const YorksV1ProjectTeamDirectoryMember(
    authUserId: 'auth-site-engineer',
    displayName: 'Bilal Site Engineer',
    eligibleRole: YorksV1Role.siteEngineer,
  ),
];

class _FakeDirectoryRpc implements YorksV1ProjectTeamDirectoryRpcClient {
  _FakeDirectoryRpc(this.rows);

  final List<Map<String, dynamic>> rows;
  var calls = 0;

  @override
  Future<List<Map<String, dynamic>>> listActiveMembers() async {
    calls++;
    return rows;
  }
}

class _FakeDirectoryRepository
    implements YorksV1ProjectTeamDirectoryRepository {
  _FakeDirectoryRepository(this.members);

  final List<YorksV1ProjectTeamDirectoryMember> members;
  var calls = 0;

  @override
  Future<List<YorksV1ProjectTeamDirectoryMember>> listActiveMembers() async {
    calls++;
    return members;
  }
}

Matcher _domainCode(YorksV1DomainErrorCode code) {
  return isA<YorksV1DomainException>().having(
    (error) => error.code,
    'code',
    code,
  );
}
