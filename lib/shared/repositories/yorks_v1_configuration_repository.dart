import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_configuration.dart';
import '../models/yorks_v1_domain_error.dart';
import '../sync/connectivity_service.dart';
import 'yorks_v1_material_request_repository.dart';

abstract interface class YorksV1ConfigurationRepository {
  Future<YorksV1ConfigurationCentre> getConfigurationCentre();

  Future<YorksV1RuntimeConfiguration> getRuntimeConfiguration();

  Future<YorksV1ConfigurationPublicationDetail> getPublicationDetail({
    required String publicationId,
  });

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
    if (!_isValidConfigurationCentre(response)) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    response['environment'] = _buildEnvironment;
    return YorksV1ConfigurationCentre.fromJson(response);
  }

  @override
  Future<YorksV1RuntimeConfiguration> getRuntimeConfiguration() async {
    final response = _object(
      await _invoke(
        functionName: 'v1_get_runtime_configuration',
        parameters: const {},
      ),
    );
    if (!_isValidRuntimeConfiguration(response)) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1RuntimeConfiguration.fromJson(response);
  }

  @override
  Future<YorksV1ConfigurationPublicationDetail> getPublicationDetail({
    required String publicationId,
  }) async {
    final normalizedPublicationId = publicationId.trim();
    if (normalizedPublicationId.isEmpty) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    final response = _object(
      await _invoke(
        functionName: 'v1_get_configuration_publication_detail',
        parameters: {'p_publication_id': normalizedPublicationId},
      ),
    );
    if (!_isValidPublicationDetail(response, normalizedPublicationId)) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    final detail = YorksV1ConfigurationPublicationDetail.fromJson(response);
    if (detail.publication.changeCount != detail.changes.length) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return detail;
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

  static bool _isValidRuntimeConfiguration(Map<String, dynamic> response) {
    const booleanKeys = <String>[
      'urgent_enabled',
      'allow_authorized_creator_self_approval',
      'require_external_source_readiness',
      'push_enabled',
    ];
    final defaultTiming = response['default_timing'];
    return response['schema_version'] is String &&
        (response['schema_version'] as String).trim().isNotEmpty &&
        response['published_version'] is num &&
        response['published_label'] is String &&
        (response['published_label'] as String).trim().isNotEmpty &&
        DateTime.tryParse(response['published_at']?.toString() ?? '') != null &&
        defaultTiming is String &&
        const {'urgent', 'normal', 'scheduled'}.contains(defaultTiming) &&
        booleanKeys.every((key) => response[key] is bool);
  }

  static bool _isValidConfigurationCentre(Map<String, dynamic> response) {
    const listKeys = <String>[
      'settings',
      'master_actions',
      'material_categories',
      'material_units',
      'boq_group_templates',
      'history',
    ];
    final settings = response['settings'];
    final health = response['operational_health'];
    final validation = response['validation'];
    if (response['schema_version'] is! String ||
        (response['schema_version'] as String).trim().isEmpty ||
        response['published_version'] is! num ||
        response['published_label'] is! String ||
        (response['published_label'] as String).trim().isEmpty ||
        DateTime.tryParse(response['published_at']?.toString() ?? '') == null ||
        response['draft_revision'] is! num ||
        response['draft_base_version'] is! num ||
        DateTime.tryParse(response['draft_updated_at']?.toString() ?? '') ==
            null ||
        listKeys.any((key) => response[key] is! List) ||
        settings is! List ||
        health is! Map ||
        validation is! Map) {
      return false;
    }
    final healthMap = Map<String, dynamic>.from(health);
    if (healthMap['push_enabled'] is! bool ||
        healthMap['active_device_count'] is! num ||
        healthMap['pending_delivery_count'] is! num ||
        healthMap['recent_failure_count'] is! num) {
      return false;
    }
    final validationMap = Map<String, dynamic>.from(validation);
    if (!const {
          'ready',
          'recommendations',
          'blocked',
        }.contains(validationMap['status']) ||
        validationMap['blocking'] is! List ||
        validationMap['recommendations'] is! List) {
      return false;
    }
    return settings.every((setting) {
      if (setting is! Map) return false;
      final settingMap = Map<String, dynamic>.from(setting);
      final key = settingMap['key']?.toString().trim() ?? '';
      final area = settingMap['area'];
      final mode = settingMap['control_mode'];
      final impactScope = settingMap['impact_scope'];
      final target = settingMap['enforcement_target'];
      return key.isNotEmpty &&
          YorksV1ConfigurationArea.values.any(
            (candidate) => candidate.wireName == area,
          ) &&
          const {'operational', 'protected', 'planned'}.contains(mode) &&
          impactScope is List &&
          impactScope.isNotEmpty &&
          impactScope.every(
            (area) => YorksV1ConfigurationArea.values.any(
              (candidate) => candidate.wireName == area,
            ),
          ) &&
          target is String &&
          target.trim().isNotEmpty;
    });
  }

  static bool _isValidPublicationDetail(
    Map<String, dynamic> response,
    String expectedPublicationId,
  ) {
    final publication = response['publication'];
    final changes = response['changes'];
    if (publication is! Map || changes is! List) return false;
    final publicationMap = Map<String, dynamic>.from(publication);
    if (publicationMap['id']?.toString() != expectedPublicationId ||
        publicationMap['version_number'] is! num ||
        (publicationMap['version_label']?.toString().trim().isEmpty ?? true) ||
        DateTime.tryParse(publicationMap['published_at']?.toString() ?? '') ==
            null ||
        publicationMap['change_count'] is! num ||
        publicationMap['affected_areas'] is! List) {
      return false;
    }
    return changes.every((change) {
      if (change is! Map) return false;
      final changeMap = Map<String, dynamic>.from(change);
      final id = changeMap['id']?.toString().trim() ?? '';
      final area = changeMap['area']?.toString();
      final kind = changeMap['change_kind']?.toString().trim() ?? '';
      return id.isNotEmpty &&
          kind.isNotEmpty &&
          YorksV1ConfigurationArea.values.any(
            (configurationArea) => configurationArea.wireName == area,
          );
    });
  }
}
