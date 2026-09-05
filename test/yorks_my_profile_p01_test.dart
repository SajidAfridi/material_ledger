import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_my_profile.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/yorks_v1_my_profile_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_permission_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_my_profile_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_permission_repository.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const actor = '10000000-0000-4000-8000-000000000001';
const project = 'ba010000-0000-4000-8000-000000000001';

Map<String, dynamic> fixture({
  YorksV1Role role = YorksV1Role.projectEngineer,
}) => {
  'schema_version': 1,
  'generated_at': '2026-09-05T00:00:00Z',
  'next_transition_at': null,
  'permission_revision': 2,
  'account': <String, dynamic>{
    'auth_user_id': actor,
    'app_user_id': 'usr-local-project-engineer',
    'display_name': 'Local engineer',
    'email': 'local@example.test',
    'exact_role': role.claimValue,
    'status': 'active',
    'workspace_key': role.claimValue,
  },
  'work_identity': {
    'legacy_employee': {'state': 'not_projected'},
    'workforce_worker': {
      'state': 'unlinked',
      'worker_id': null,
      'grants_self_service': false,
    },
  },
  'projects': {
    'total': 1,
    'offset': 0,
    'has_more': false,
    'items': [
      {
        'project_id': project,
        'project_ref': 'P01',
        'project_name': 'Own project',
        'technical_access': true,
        'accounts_access': false,
        'memberships': [
          {
            'project_role': 'project_engineer',
            'effective_from': '2026-08-01T00:00:00Z',
            'effective_until': null,
          },
        ],
      },
    ],
  },
  'capabilities': [
    {
      'capability_key': 'projects.view',
      'authorization_mode': 'enforced',
      'requires_record_check': true,
      'organization': null,
      'projects': [
        {'project_id': project, 'effective': true, 'source': 'role_default'},
      ],
    },
  ],
  'actions': [
    {
      'action_id': 'open_projects',
      'capability_key': 'projects.view',
      'required_feature': 'projects',
      'kind': 'navigation',
    },
  ],
  'operational_summary_state': 'not_projected',
  'workforce_scope_state': 'requires_work_date_context',
};

class FakeRpc implements YorksV1PermissionRpcClient {
  Object? response = fixture();
  Object? error;
  String? function;
  Map<String, Object?>? params;
  Completer<Object?>? pending;
  @override
  Future<Object?> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    function = functionName;
    params = parameters;
    if (error != null) throw error!;
    return pending == null ? response : pending!.future;
  }
}

class DeferredRepository implements YorksV1MyProfileRepository {
  final calls = <Completer<YorksV1MyProfile>>[];
  @override
  Future<YorksV1MyProfile> load({
    required String expectedAuthUserId,
    required YorksV1Role expectedRole,
    int projectOffset = 0,
    int projectLimit = 25,
  }) {
    final result = Completer<YorksV1MyProfile>();
    calls.add(result);
    return result.future;
  }
}

class TestPermissionController
    extends YorksV1CurrentPermissionSnapshotController {
  TestPermissionController(ConnectivityService connection)
    : super(
        enabled: false,
        authUserId: null,
        client: null,
        repository: YorksV1SupabasePermissionRepository(
          featureFlags: const YorksV1FeatureFlags(),
          connectivity: connection,
        ),
      );
  void invalidateAccess() {
    state = const YorksV1CurrentPermissionSnapshotState(isStale: true);
  }
}

Matcher domain(YorksV1DomainErrorCode code) =>
    isA<YorksV1DomainException>().having((e) => e.code, 'code', code);

void main() {
  for (final role in YorksV1Role.values) {
    test('P01 preserves exact ${role.claimValue}', () {
      final result = YorksV1MyProfile.fromRpcJson(fixture(role: role));
      expect(result.exactRole, role);
      expect(result.authUserId, actor);
      expect(result.hasOperationalSummary, false);
      expect(result.hasLegacyEmployeeProjection, false);
      expect(result.workerLinkGrantsSelfService, false);
      expect(result.actions.single.id, 'open_projects');
      expect(() => result.projects.clear(), throwsUnsupportedError);
      expect(
        () => result.capabilities.single.projects.clear(),
        throwsUnsupportedError,
      );
    });
  }
  final corruptions = <String, void Function(Map<String, dynamic>)>{
    'missing account': (j) => j.remove('account'),
    'unknown commercial field': (j) => j['unit_cost'] = 99,
    'nested private data': (j) => j['account']['salary'] = 99,
    'legacy role': (j) => j['account']['exact_role'] = 'engineer',
    'inactive identity': (j) => j['account']['status'] = 'inactive',
    'workspace mismatch': (j) => j['account']['workspace_key'] = 'admin',
    'invented metrics': (j) => j['operational_summary_state'] = 'ready',
    'worker self privilege': (j) =>
        j['work_identity']['workforce_worker']['grants_self_service'] = true,
    'unknown action': (j) => j['actions'][0]['action_id'] = 'approve_request',
    'command masquerading as navigation': (j) =>
        j['actions'][0]['kind'] = 'command',
    'unauthorized action': (j) =>
        j['capabilities'][0]['projects'][0]['effective'] = false,
    'string bool': (j) =>
        j['capabilities'][0]['projects'][0]['effective'] = 'true',
    'foreign project': (j) =>
        j['capabilities'][0]['projects'][0]['project_id'] = actor,
    'duplicate project': (j) {
      j['projects']['items'].add(j['projects']['items'][0]);
      j['projects']['total'] = 2;
    },
    'false pagination': (j) => j['projects']['has_more'] = true,
    'negative revision': (j) => j['permission_revision'] = -1,
    'expired snapshot': (j) => j['next_transition_at'] = '2026-09-04T00:00:00Z',
    'local timestamp': (j) => j['generated_at'] = '2026-09-05T00:00:00',
    'shadow candidate payload': (j) =>
        j['capabilities'][0]['candidate'] = {'effective': true},
  };
  for (final entry in corruptions.entries) {
    test('P01 rejects ${entry.key}', () {
      final json = fixture();
      entry.value(json);
      expect(() => YorksV1MyProfile.fromRpcJson(json), throwsFormatException);
    });
  }
  test('Linked worker remains distinct from account identity', () {
    final json = fixture();
    json['work_identity']['workforce_worker'] = {
      'state': 'linked',
      'worker_id': project,
      'grants_self_service': false,
    };
    final result = YorksV1MyProfile.fromRpcJson(json);
    expect(result.workerId, project);
    expect(result.authUserId, actor);
    expect(result.workerLinkGrantsSelfService, false);
  });
  group('repository', () {
    late DefaultConnectivity connection;
    late FakeRpc rpc;
    late YorksV1SupabaseMyProfileRepository repository;
    setUp(() {
      connection = DefaultConnectivity();
      rpc = FakeRpc();
      repository = YorksV1SupabaseMyProfileRepository(
        enabled: true,
        connectivity: connection,
        rpc: rpc,
      );
    });
    tearDown(() => connection.dispose());
    Future<YorksV1MyProfile> load() => repository.load(
      expectedAuthUserId: actor,
      expectedRole: YorksV1Role.projectEngineer,
    );
    test('sends only page parameters, never actor identity', () async {
      expect((await load()).authUserId, actor);
      expect(rpc.function, 'v1_get_my_yorks_profile');
      expect(rpc.params, {'p_project_offset': 0, 'p_project_limit': 25});
    });
    test('offline never invokes backend', () async {
      connection.setOnline(false);
      await expectLater(
        load(),
        throwsA(domain(YorksV1DomainErrorCode.offline)),
      );
      expect(rpc.function, isNull);
    });
    test('disabled and unconfigured paths fail closed', () async {
      repository = YorksV1SupabaseMyProfileRepository(
        enabled: false,
        connectivity: connection,
        rpc: rpc,
      );
      await expectLater(
        load(),
        throwsA(domain(YorksV1DomainErrorCode.featureDisabled)),
      );
      repository = YorksV1SupabaseMyProfileRepository(
        enabled: true,
        connectivity: connection,
        rpc: null,
      );
      await expectLater(
        load(),
        throwsA(domain(YorksV1DomainErrorCode.backendUnavailable)),
      );
    });
    test('denied refresh is not converted to empty profile', () async {
      await load();
      rpc.error = const PostgrestException(message: 'denied', code: '42501');
      await expectLater(
        load(),
        throwsA(domain(YorksV1DomainErrorCode.unauthorized)),
      );
    });
    test('identity role and paging mismatches fail closed', () async {
      for (final change in <void Function(Map<String, dynamic>)>[
        (j) => j['account']['auth_user_id'] = project,
        (j) {
          j['account']['exact_role'] = 'admin';
          j['account']['workspace_key'] = 'admin';
        },
        (j) {
          j['projects'] = {
            'total': 0,
            'offset': 1,
            'has_more': false,
            'items': [],
          };
          j['capabilities'] = [];
          j['actions'] = [];
        },
      ]) {
        final json = fixture();
        change(json);
        rpc.response = json;
        await expectLater(
          load(),
          throwsA(domain(YorksV1DomainErrorCode.unexpectedResponse)),
        );
      }
    });
    test('timeout clears failure without logging payload', () async {
      rpc.pending = Completer<Object?>();
      repository = YorksV1SupabaseMyProfileRepository(
        enabled: true,
        connectivity: connection,
        rpc: rpc,
        timeout: Duration.zero,
      );
      await expectLater(
        load(),
        throwsA(domain(YorksV1DomainErrorCode.backendUnavailable)),
      );
      rpc.pending!.complete(fixture());
    });
  });
  test(
    'controller discards out-of-order results and denied stale data',
    () async {
      final repository = DeferredRepository();
      final controller = YorksV1MyProfileController(
        repository: repository,
        authUserId: actor,
        exactRole: YorksV1Role.projectEngineer,
      );
      final refresh = controller.refresh();
      repository.calls[1].complete(YorksV1MyProfile.fromRpcJson(fixture()));
      await refresh;
      expect(controller.state.hasValue, true);
      repository.calls[0].completeError(
        const YorksV1DomainException(YorksV1DomainErrorCode.unauthorized),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.hasValue, true);
      final denied = controller.refresh();
      expect(controller.state.hasValue, false);
      repository.calls[2].completeError(
        const YorksV1DomainException(YorksV1DomainErrorCode.unauthorized),
      );
      await denied;
      expect(controller.state.hasError, true);
      expect(controller.state.hasValue, false);
      controller.dispose();
    },
  );
  test('disposed controller ignores its pending identity response', () async {
    final repository = DeferredRepository();
    final controller = YorksV1MyProfileController(
      repository: repository,
      authUserId: actor,
      exactRole: YorksV1Role.projectEngineer,
    );
    controller.dispose();
    repository.calls.single.complete(YorksV1MyProfile.fromRpcJson(fixture()));
    await Future<void>.delayed(Duration.zero);
  });
  test('missing exact role never loads a legacy identity', () {
    final repository = DeferredRepository();
    final controller = YorksV1MyProfileController(
      repository: repository,
      authUserId: actor,
      exactRole: null,
    );
    expect(controller.state.hasError, true);
    expect(repository.calls, isEmpty);
    controller.dispose();
  });
  testWidgets('scheduled permission expiry refreshes and clears old evidence', (
    tester,
  ) async {
    final repository = DeferredRepository();
    final controller = YorksV1MyProfileController(
      repository: repository,
      authUserId: actor,
      exactRole: YorksV1Role.projectEngineer,
    );
    final json = fixture()..['next_transition_at'] = '2026-09-05T00:00:05Z';
    repository.calls.single.complete(YorksV1MyProfile.fromRpcJson(json));
    await tester.pump();
    expect(controller.state.hasValue, true);
    await tester.pump(const Duration(seconds: 5));
    expect(repository.calls.length, 2);
    expect(controller.state.hasValue, false);
    repository.calls.last.completeError(
      const YorksV1DomainException(YorksV1DomainErrorCode.unauthorized),
    );
    await tester.pump();
    expect(controller.state.hasError, true);
    controller.dispose();
  });
  test(
    'provider clears state on permission, session and identity invalidation',
    () async {
      final connection = DefaultConnectivity();
      final permissions = TestPermissionController(connection);
      final identity = StateProvider<String?>((ref) => actor);
      final repository = DeferredRepository();
      final container = ProviderContainer(
        overrides: [
          yorksV1AuthUserIdProvider.overrideWith((ref) => ref.watch(identity)),
          yorksV1CurrentRoleProvider.overrideWithValue(
            YorksV1Role.projectEngineer,
          ),
          connectivityProvider.overrideWithValue(connection),
          yorksV1CurrentPermissionSnapshotProvider.overrideWith(
            (ref) => permissions,
          ),
          yorksV1MyProfileRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final subscription = container.listen(
        yorksV1MyProfileProvider,
        (_, _) {},
      );
      repository.calls[0].complete(YorksV1MyProfile.fromRpcJson(fixture()));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(yorksV1MyProfileProvider).hasValue, true);
      permissions.invalidateAccess();
      expect(container.read(yorksV1MyProfileProvider).hasValue, false);
      expect(repository.calls.length, 2);
      container.read(authSessionRevisionProvider.notifier).bump();
      expect(container.read(yorksV1MyProfileProvider).hasValue, false);
      expect(repository.calls.length, 3);
      container.read(identity.notifier).state = null;
      expect(container.read(yorksV1MyProfileProvider).hasError, true);
      repository.calls[1].complete(YorksV1MyProfile.fromRpcJson(fixture()));
      repository.calls[2].complete(YorksV1MyProfile.fromRpcJson(fixture()));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(yorksV1MyProfileProvider).hasValue, false);
      subscription.close();
      container.dispose();
      connection.dispose();
    },
  );
}
