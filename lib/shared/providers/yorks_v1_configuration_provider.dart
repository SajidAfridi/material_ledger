import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/yorks_v1_configuration.dart';
import '../models/yorks_v1_domain_error.dart';
import '../repositories/yorks_v1_configuration_repository.dart';
import '../repositories/yorks_v1_material_request_repository.dart';
import '../services/yorks_v1_critical_command_key_store.dart';
import '../sync/connectivity_service.dart';
import 'language_provider.dart';
import 'yorks_v1_identity_provider.dart';

final yorksV1ConfigurationRpcClientProvider =
    Provider<YorksV1MaterialRequestRpcClient?>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return client == null
          ? null
          : SupabaseYorksV1MaterialRequestRpcClient(client);
    });

final yorksV1ConfigurationRepositoryProvider =
    Provider<YorksV1ConfigurationRepository>((ref) {
      return YorksV1SupabaseConfigurationRepository(
        connectivity: ref.watch(connectivityProvider),
        rpcClient: ref.watch(yorksV1ConfigurationRpcClientProvider),
      );
    });

final yorksV1ConfigurationCentreProvider =
    FutureProvider.autoDispose<YorksV1ConfigurationCentre>((ref) {
      return ref
          .watch(yorksV1ConfigurationRepositoryProvider)
          .getConfigurationCentre();
    });

final yorksV1RuntimeConfigurationProvider =
    FutureProvider.autoDispose<YorksV1RuntimeConfiguration>((ref) {
      return ref
          .watch(yorksV1ConfigurationRepositoryProvider)
          .getRuntimeConfiguration();
    });

final yorksV1ConfigurationPublicationDetailProvider = FutureProvider.autoDispose
    .family<YorksV1ConfigurationPublicationDetail, String>((
      ref,
      publicationId,
    ) {
      return ref
          .watch(yorksV1ConfigurationRepositoryProvider)
          .getPublicationDetail(publicationId: publicationId);
    });

final yorksV1ConfigurationUnitCodesProvider =
    FutureProvider.autoDispose<List<String>>((ref) {
      return ref
          .watch(yorksV1ConfigurationRepositoryProvider)
          .getActiveUnitCodes();
    });

final yorksV1ConfigurationCommandProvider =
    StateNotifierProvider.autoDispose<
      YorksV1ConfigurationCommandController,
      AsyncValue<void>
    >((ref) {
      return YorksV1ConfigurationCommandController(
        ref,
        YorksV1CriticalCommandKeyStore(
          preferences: ref.watch(sharedPreferencesProvider),
          actorAuthUserId: ref.watch(yorksV1AuthUserIdProvider) ?? '',
        ),
      );
    });

class YorksV1ConfigurationCommandController
    extends StateNotifier<AsyncValue<void>> {
  YorksV1ConfigurationCommandController(this._ref, this._commandKeys)
    : super(const AsyncValue.data(null));

  final Ref _ref;
  final YorksV1CriticalCommandKeyStore _commandKeys;

  Future<bool> stageSetting({
    required String settingKey,
    required Object value,
    required int expectedRevision,
  }) {
    return _run(
      operation: 'stage_configuration_setting',
      entityId: settingKey,
      payload: {
        'setting_key': settingKey,
        'value': value,
        'expected_revision': expectedRevision,
      },
      invoke: (idempotencyKey) => _ref
          .read(yorksV1ConfigurationRepositoryProvider)
          .stageSetting(
            settingKey: settingKey,
            value: value,
            expectedRevision: expectedRevision,
            idempotencyKey: idempotencyKey,
          ),
    );
  }

  Future<bool> stageMasterAction({
    required String entityKind,
    required String actionKind,
    String? targetId,
    required Map<String, Object?> payload,
    required String? reason,
    required int expectedRevision,
  }) {
    final isCreate = actionKind == 'create';
    final normalizedTargetId = targetId?.trim() ?? '';
    return _run(
      operation: 'stage_configuration_master_$actionKind',
      // A create retry may reconstruct its dialog and must not depend on a
      // fresh widget UUID. Its persisted command key deterministically derives
      // the target UUID used by the trusted RPC.
      entityId: isCreate
          ? '$entityKind:create'
          : '$entityKind:$normalizedTargetId',
      payload: {
        'entity_kind': entityKind,
        'action_kind': actionKind,
        if (!isCreate) 'target_id': normalizedTargetId,
        'payload': payload,
        'reason': reason,
        'expected_revision': expectedRevision,
      },
      invoke: (idempotencyKey) {
        final commandTargetId = isCreate
            ? const Uuid().v5(
                Namespace.url.value,
                'yorks-v1-configuration-master:$idempotencyKey',
              )
            : normalizedTargetId;
        return _ref
            .read(yorksV1ConfigurationRepositoryProvider)
            .stageMasterAction(
              entityKind: entityKind,
              actionKind: actionKind,
              targetId: commandTargetId,
              payload: payload,
              reason: reason,
              expectedRevision: expectedRevision,
              idempotencyKey: idempotencyKey,
            );
      },
    );
  }

  Future<bool> discardDraft(int expectedRevision) {
    return _run(
      operation: 'discard_configuration_draft',
      entityId: 'configuration_draft',
      payload: {'expected_revision': expectedRevision},
      invoke: (idempotencyKey) => _ref
          .read(yorksV1ConfigurationRepositoryProvider)
          .discardDraft(
            expectedRevision: expectedRevision,
            idempotencyKey: idempotencyKey,
          ),
    );
  }

  Future<bool> restoreDefaults(int expectedRevision) {
    return _run(
      operation: 'restore_configuration_defaults',
      entityId: 'configuration_draft',
      payload: {'expected_revision': expectedRevision},
      invoke: (idempotencyKey) => _ref
          .read(yorksV1ConfigurationRepositoryProvider)
          .restoreDefaults(
            expectedRevision: expectedRevision,
            idempotencyKey: idempotencyKey,
          ),
    );
  }

  Future<String?> publish({
    required String reason,
    required int expectedRevision,
  }) async {
    state = const AsyncValue.loading();
    try {
      final payload = <String, Object?>{
        'reason': reason,
        'expected_revision': expectedRevision,
      };
      final idempotencyKey = await _commandKeys.acquire(
        operation: 'publish_configuration',
        entityId: 'configuration_draft',
        payload: payload,
      );
      final version = await _ref
          .read(yorksV1ConfigurationRepositoryProvider)
          .publish(
            reason: reason,
            expectedRevision: expectedRevision,
            idempotencyKey: idempotencyKey,
          );
      await _commandKeys.confirm(
        operation: 'publish_configuration',
        entityId: 'configuration_draft',
        idempotencyKey: idempotencyKey,
      );
      _ref.invalidate(yorksV1ConfigurationCentreProvider);
      _ref.invalidate(yorksV1RuntimeConfigurationProvider);
      _ref.invalidate(yorksV1ConfigurationUnitCodesProvider);
      state = const AsyncValue.data(null);
      return version;
    } catch (error, stack) {
      if (error is YorksV1DomainException &&
          error.code == YorksV1DomainErrorCode.conflict) {
        _ref.invalidate(yorksV1ConfigurationCentreProvider);
      }
      state = AsyncValue.error(error, stack);
      return null;
    }
  }

  Future<bool> _run({
    required String operation,
    required String entityId,
    required Map<String, Object?> payload,
    required Future<void> Function(String idempotencyKey) invoke,
  }) async {
    state = const AsyncValue.loading();
    try {
      final idempotencyKey = await _commandKeys.acquire(
        operation: operation,
        entityId: entityId,
        payload: payload,
      );
      await invoke(idempotencyKey);
      await _commandKeys.confirm(
        operation: operation,
        entityId: entityId,
        idempotencyKey: idempotencyKey,
      );
      _ref.invalidate(yorksV1ConfigurationCentreProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stack) {
      if (error is YorksV1DomainException &&
          error.code == YorksV1DomainErrorCode.conflict) {
        _ref.invalidate(yorksV1ConfigurationCentreProvider);
      }
      state = AsyncValue.error(error, stack);
      return false;
    }
  }
}
