import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_configuration.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_configuration_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_material_request_repository.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';

void main() {
  test(
    'stage setting sends the trusted draft command with concurrency data',
    () async {
      final rpc = _RecordingRpc({'draft_revision': 4});
      final repository = YorksV1SupabaseConfigurationRepository(
        connectivity: DefaultConnectivity(),
        rpcClient: rpc,
      );

      await repository.stageSetting(
        settingKey: 'notifications.push_enabled',
        value: false,
        expectedRevision: 3,
        idempotencyKey: 'setting-command-1',
      );

      expect(rpc.functionName, 'v1_stage_configuration_setting');
      expect(rpc.parameters, {
        'p_setting_key': 'notifications.push_enabled',
        'p_value': false,
        'p_expected_revision': 3,
        'p_idempotency_key': 'setting-command-1',
      });
    },
  );

  test('publish returns only the server-confirmed version', () async {
    final rpc = _RecordingRpc({'version_label': 'v1.4.0'});
    final repository = YorksV1SupabaseConfigurationRepository(
      connectivity: DefaultConnectivity(),
      rpcClient: rpc,
    );

    final version = await repository.publish(
      reason: 'Enable controlled alerts for the production workspace.',
      expectedRevision: 8,
      idempotencyKey: 'publish-command-1',
    );

    expect(version, 'v1.4.0');
    expect(rpc.functionName, 'v1_publish_configuration');
    expect(rpc.parameters?['p_expected_revision'], 8);
    expect(rpc.parameters?['p_idempotency_key'], 'publish-command-1');
  });

  test('active unit register comes only from the controlled RPC', () async {
    final rpc = _RecordingRpc(['Nos', 'Meter', 'Set']);
    final repository = YorksV1SupabaseConfigurationRepository(
      connectivity: DefaultConnectivity(),
      rpcClient: rpc,
    );

    expect(await repository.getActiveUnitCodes(), ['Nos', 'Meter', 'Set']);
    expect(rpc.functionName, 'v1_list_configuration_units');
    expect(rpc.parameters, isEmpty);
  });

  test(
    'Admin centre accepts only the control-plane response contract',
    () async {
      final rpc = _RecordingRpc(_configurationCentreResponse());
      final repository = YorksV1SupabaseConfigurationRepository(
        connectivity: DefaultConnectivity(),
        rpcClient: rpc,
      );

      final centre = await repository.getConfigurationCentre();

      expect(rpc.functionName, 'v1_get_configuration_centre');
      expect(centre.settings.single.isOperational, isTrue);
      expect(centre.operationalHealth.activeDeviceCount, 3);
    },
  );

  test(
    'Admin centre fails closed against an older metadata-free backend',
    () async {
      final response = _configurationCentreResponse();
      (response['settings'] as List).first.remove('control_mode');
      final repository = YorksV1SupabaseConfigurationRepository(
        connectivity: DefaultConnectivity(),
        rpcClient: _RecordingRpc(response),
      );

      await expectLater(
        repository.getConfigurationCentre(),
        throwsA(
          isA<YorksV1DomainException>().having(
            (error) => error.code,
            'code',
            YorksV1DomainErrorCode.unexpectedResponse,
          ),
        ),
      );
    },
  );

  test(
    'runtime configuration comes from the role-safe published RPC',
    () async {
      final rpc = _RecordingRpc({
        'schema_version': 'R38.5 / 1.1',
        'published_version': 5,
        'published_label': 'v1.4.0',
        'published_at': '2026-08-24T08:30:00Z',
        'default_timing': 'scheduled',
        'urgent_enabled': true,
        'allow_authorized_creator_self_approval': true,
        'require_external_source_readiness': false,
        'push_enabled': true,
      });
      final repository = YorksV1SupabaseConfigurationRepository(
        connectivity: DefaultConnectivity(),
        rpcClient: rpc,
      );

      final runtime = await repository.getRuntimeConfiguration();

      expect(rpc.functionName, 'v1_get_runtime_configuration');
      expect(rpc.parameters, isEmpty);
      expect(runtime.publishedVersion, 5);
      expect(runtime.defaultTiming, 'scheduled');
      expect(runtime.allowAuthorizedCreatorSelfApproval, isTrue);
      expect(runtime.requireExternalSourceReadiness, isFalse);
      expect(runtime.pushEnabled, isTrue);
    },
  );

  test('publication detail uses only the selected publication id', () async {
    final rpc = _RecordingRpc({
      'publication': {
        'id': 'publication-5',
        'version_number': 5,
        'version_label': 'v1.4.0',
        'reason': 'Enable production notification delivery.',
        'affected_areas': ['notifications'],
        'published_at': '2026-08-24T08:30:00Z',
        'published_by': 'Owner',
        'published_by_exact_role': 'admin',
        'change_count': 1,
      },
      'changes': [
        {
          'id': 'change-1',
          'setting_key': 'notifications.push_enabled',
          'area': 'notifications',
          'before_value': false,
          'after_value': true,
          'change_kind': 'setting',
        },
      ],
    });
    final repository = YorksV1SupabaseConfigurationRepository(
      connectivity: DefaultConnectivity(),
      rpcClient: rpc,
    );

    final detail = await repository.getPublicationDetail(
      publicationId: ' publication-5 ',
    );

    expect(rpc.functionName, 'v1_get_configuration_publication_detail');
    expect(rpc.parameters, {'p_publication_id': 'publication-5'});
    expect(detail.publication.versionLabel, 'v1.4.0');
    expect(detail.changes, hasLength(1));
    expect(detail.changes.single.area, YorksV1ConfigurationArea.notifications);
    expect(detail.changes.single.afterValue, isTrue);
  });

  test('publication detail rejects an empty id without an RPC', () async {
    final rpc = _RecordingRpc(const <String, Object?>{});
    final repository = YorksV1SupabaseConfigurationRepository(
      connectivity: DefaultConnectivity(),
      rpcClient: rpc,
    );

    await expectLater(
      repository.getPublicationDetail(publicationId: '   '),
      throwsA(
        isA<YorksV1DomainException>().having(
          (error) => error.code,
          'code',
          YorksV1DomainErrorCode.invalidInput,
        ),
      ),
    );
    expect(rpc.functionName, isNull);
  });

  test(
    'runtime configuration fails closed when a control is omitted',
    () async {
      final repository = YorksV1SupabaseConfigurationRepository(
        connectivity: DefaultConnectivity(),
        rpcClient: _RecordingRpc({
          'schema_version': 'R38.5 / 1.1',
          'published_version': 5,
          'published_label': 'v1.4.0',
          'published_at': '2026-08-24T08:30:00Z',
          'default_timing': 'normal',
          'urgent_enabled': true,
          'allow_authorized_creator_self_approval': true,
          'require_external_source_readiness': false,
        }),
      );

      await expectLater(
        repository.getRuntimeConfiguration(),
        throwsA(
          isA<YorksV1DomainException>().having(
            (error) => error.code,
            'code',
            YorksV1DomainErrorCode.unexpectedResponse,
          ),
        ),
      );
    },
  );

  test('publication detail rejects incomplete history', () async {
    final repository = YorksV1SupabaseConfigurationRepository(
      connectivity: DefaultConnectivity(),
      rpcClient: _RecordingRpc({
        'publication': {
          'id': 'publication-5',
          'version_number': 5,
          'version_label': 'v1.4.0',
          'reason': 'Enable production notification delivery.',
          'affected_areas': ['notifications'],
          'published_at': '2026-08-24T08:30:00Z',
          'published_by': 'Owner',
          'published_by_exact_role': 'admin',
          'change_count': 2,
        },
        'changes': [
          {
            'id': 'change-1',
            'setting_key': 'notifications.push_enabled',
            'area': 'notifications',
            'before_value': false,
            'after_value': true,
            'change_kind': 'setting',
          },
        ],
      }),
    );

    await expectLater(
      repository.getPublicationDetail(publicationId: 'publication-5'),
      throwsA(
        isA<YorksV1DomainException>().having(
          (error) => error.code,
          'code',
          YorksV1DomainErrorCode.unexpectedResponse,
        ),
      ),
    );
  });

  test('critical configuration commands fail closed while offline', () async {
    final rpc = _RecordingRpc({'draft_revision': 2});
    final repository = YorksV1SupabaseConfigurationRepository(
      connectivity: DefaultConnectivity(online: false),
      rpcClient: rpc,
    );

    await expectLater(
      repository.restoreDefaults(
        expectedRevision: 1,
        idempotencyKey: 'restore-command-1',
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

  test('publish rejects a response without a confirmed version', () async {
    final repository = YorksV1SupabaseConfigurationRepository(
      connectivity: DefaultConnectivity(),
      rpcClient: _RecordingRpc({'published': true}),
    );

    await expectLater(
      repository.publish(
        reason: 'Publish a valid controlled draft to production.',
        expectedRevision: 2,
        idempotencyKey: 'publish-command-2',
      ),
      throwsA(
        isA<YorksV1DomainException>().having(
          (error) => error.code,
          'code',
          YorksV1DomainErrorCode.unexpectedResponse,
        ),
      ),
    );
  });
}

Map<String, dynamic> _configurationCentreResponse() => {
  'schema_version': 'R38.6 / 1.1',
  'published_version': 5,
  'published_label': 'v1.4.0',
  'published_at': '2026-08-24T08:30:00Z',
  'published_by': 'Owner',
  'draft_revision': 8,
  'draft_base_version': 5,
  'draft_updated_at': '2026-08-24T08:30:00Z',
  'draft_updated_by': 'Owner',
  'settings': [
    {
      'key': 'notifications.push_enabled',
      'area': 'notifications',
      'type': 'boolean',
      'published_value': true,
      'draft_value': null,
      'effective_value': true,
      'changed': false,
      'control_mode': 'operational',
      'impact_scope': ['notifications'],
      'enforcement_target': 'Notification push outbox enqueue trigger',
    },
  ],
  'master_actions': <Object?>[],
  'material_categories': <Object?>[],
  'material_units': <Object?>[],
  'boq_group_templates': <Object?>[],
  'history': <Object?>[],
  'operational_health': {
    'push_enabled': true,
    'active_device_count': 3,
    'pending_delivery_count': 0,
    'recent_failure_count': 0,
    'last_successful_delivery_at': '2026-08-24T08:20:00Z',
  },
  'validation': {
    'status': 'ready',
    'blocking': <Object?>[],
    'recommendations': <Object?>[],
  },
};

class _RecordingRpc implements YorksV1MaterialRequestRpcClient {
  _RecordingRpc(this.response);

  final Object? response;
  String? functionName;
  Map<String, Object?>? parameters;

  @override
  Future<Object?> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    this.functionName = functionName;
    this.parameters = parameters;
    return response;
  }
}
