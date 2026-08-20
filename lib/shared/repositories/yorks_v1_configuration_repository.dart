import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_configuration.dart';
import '../models/yorks_v1_domain_error.dart';
import '../sync/connectivity_service.dart';
import 'yorks_v1_material_request_repository.dart';

abstract interface class YorksV1ConfigurationRepository {
  Future<YorksV1ConfigurationCentre> getConfigurationCentre();

  Future<List<String>> getActiveUnitCodes();

  Future<void> stageSetting({
    required String settingKey,
    required Object value,
    required int expectedRevision,
    required String idempotencyKey,
  });

  Future<void> stageMasterAction({
    required String entityKind,
    required String actionKind,
    required String targetId,
    required Map<String, Object?> payload,
    required String? reason,
    required int expectedRevision,
    required String idempotencyKey,
  });

  Future<void> discardDraft({
    required int expectedRevision,
    required String idempotencyKey,
  });

  Future<void> restoreDefaults({
    required int expectedRevision,
    required String idempotencyKey,
  });

  Future<String> publish({
    required String reason,
    required int expectedRevision,
    required String idempotencyKey,
  });
}

class YorksV1SupabaseConfigurationRepository
    implements YorksV1ConfigurationRepository {
  const YorksV1SupabaseConfigurationRepository({
    required ConnectivityService connectivity,
    YorksV1MaterialRequestRpcClient? rpcClient,
    Duration timeout = const Duration(seconds: 25),
  }) : _connectivity = connectivity,
       _rpcClient = rpcClient,
       _timeout = timeout;

  final ConnectivityService _connectivity;
  final YorksV1MaterialRequestRpcClient? _rpcClient;
  final Duration _timeout;
  static const _buildEnvironment = String.fromEnvironment(
    'R35_ENVIRONMENT',
    defaultValue: 'unconfigured',
  );

  @override
  Future<YorksV1ConfigurationCentre> getConfigurationCentre() async {
    final response = _object(
      await _invoke(
        functionName: 'v1_get_configuration_centre',
        parameters: const {},
      ),
    );
    response['environment'] = _buildEnvironment;
    return YorksV1ConfigurationCentre.fromJson(response);
  }

  @override
  Future<List<String>> getActiveUnitCodes() async {
    final response = await _invoke(
      functionName: 'v1_list_configuration_units',
      parameters: const {},
    );
    if (response is! List) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    final values = response
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (values.isEmpty) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return values;
  }

  @override
  Future<void> stageSetting({
    required String settingKey,
    required Object value,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    await _invoke(
      functionName: 'v1_stage_configuration_setting',
      parameters: {
        'p_setting_key': settingKey,
        'p_value': value,
        'p_expected_revision': expectedRevision,
        'p_idempotency_key': idempotencyKey,
      },
    );
  }

  @override
  Future<void> stageMasterAction({
    required String entityKind,
    required String actionKind,
    required String targetId,
    required Map<String, Object?> payload,
    required String? reason,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    await _invoke(
      functionName: 'v1_stage_configuration_master_action',
      parameters: {
        'p_entity_kind': entityKind,
        'p_action_kind': actionKind,
        'p_target_id': targetId,
        'p_payload': payload,
        'p_reason': reason,
        'p_expected_revision': expectedRevision,
        'p_idempotency_key': idempotencyKey,
      },
    );
  }

  @override
  Future<void> discardDraft({
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    await _invoke(
      functionName: 'v1_discard_configuration_draft',
      parameters: {
        'p_expected_revision': expectedRevision,
        'p_idempotency_key': idempotencyKey,
      },
    );
  }

  @override
  Future<void> restoreDefaults({
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    await _invoke(
      functionName: 'v1_restore_configuration_defaults',
      parameters: {
        'p_expected_revision': expectedRevision,
        'p_idempotency_key': idempotencyKey,
      },
    );
  }

  @override
  Future<String> publish({
    required String reason,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    final response = _object(
      await _invoke(
        functionName: 'v1_publish_configuration',
        parameters: {
          'p_reason': reason,
          'p_expected_revision': expectedRevision,
          'p_idempotency_key': idempotencyKey,
        },
      ),
    );
    final version = response['version_label']?.toString();
    if (version == null || version.isEmpty) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return version;
  }

  Future<Object?> _invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    if (!_connectivity.isOnline) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.offline);
    }
    final rpc = _rpcClient;
    if (rpc == null) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
      );
    }
    try {
      return await rpc
          .invoke(functionName: functionName, parameters: parameters)
          .timeout(_timeout);
    } on YorksV1DomainException {
      rethrow;
    } on PostgrestException catch (error) {
      throw YorksV1DomainException(
        switch (error.code) {
          '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
          '40001' || '55P03' => YorksV1DomainErrorCode.conflict,
          '22023' ||
          '22P02' ||
          '23505' ||
          '23503' ||
          'P0002' => YorksV1DomainErrorCode.invalidInput,
          '23514' => YorksV1DomainErrorCode.invalidTransition,
          'PGRST002' || 'PGRST003' => YorksV1DomainErrorCode.backendUnavailable,
          _ => YorksV1DomainErrorCode.serverRejected,
        },
        serverCode: error.code,
        cause: error,
      );
    } on TimeoutException catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      );
    } catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      );
    }
  }

  static Map<String, dynamic> _object(Object? response) {
    if (response is! Map) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return Map<String, dynamic>.from(response);
  }
}
