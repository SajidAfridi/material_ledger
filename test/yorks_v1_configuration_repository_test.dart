import 'package:flutter_test/flutter_test.dart';
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
