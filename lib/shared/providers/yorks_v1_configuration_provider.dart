import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/yorks_v1_configuration.dart';
import '../models/yorks_v1_domain_error.dart';
import '../repositories/yorks_v1_configuration_repository.dart';
import '../repositories/yorks_v1_material_request_repository.dart';
import '../sync/connectivity_service.dart';
import 'language_provider.dart';

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
    >((ref) => YorksV1ConfigurationCommandController(ref));

class YorksV1ConfigurationCommandController
    extends StateNotifier<AsyncValue<void>> {
  YorksV1ConfigurationCommandController(this._ref)
    : super(const AsyncValue.data(null));

  final Ref _ref;
  static const _uuid = Uuid();

  Future<bool> stageSetting({
    required String settingKey,
    required Object value,
    required int expectedRevision,
  }) {
    return _run(
      () => _ref
          .read(yorksV1ConfigurationRepositoryProvider)
          .stageSetting(
            settingKey: settingKey,
            value: value,
            expectedRevision: expectedRevision,
            idempotencyKey: _uuid.v4(),
          ),
    );
  }

  Future<bool> stageMasterAction({
    required String entityKind,
    required String actionKind,
    required String targetId,
    required Map<String, Object?> payload,
    required String? reason,
    required int expectedRevision,
  }) {
    return _run(
      () => _ref
          .read(yorksV1ConfigurationRepositoryProvider)
          .stageMasterAction(
            entityKind: entityKind,
            actionKind: actionKind,
            targetId: targetId,
            payload: payload,
            reason: reason,
            expectedRevision: expectedRevision,
            idempotencyKey: _uuid.v4(),
          ),
    );
  }

  Future<bool> discardDraft(int expectedRevision) {
    return _run(
      () => _ref
          .read(yorksV1ConfigurationRepositoryProvider)
          .discardDraft(
            expectedRevision: expectedRevision,
            idempotencyKey: _uuid.v4(),
          ),
    );
  }

  Future<bool> restoreDefaults(int expectedRevision) {
    return _run(
      () => _ref
          .read(yorksV1ConfigurationRepositoryProvider)
          .restoreDefaults(
            expectedRevision: expectedRevision,
            idempotencyKey: _uuid.v4(),
          ),
    );
  }

  Future<String?> publish({
    required String reason,
    required int expectedRevision,
  }) async {
    state = const AsyncValue.loading();
    try {
      final version = await _ref
          .read(yorksV1ConfigurationRepositoryProvider)
          .publish(
            reason: reason,
            expectedRevision: expectedRevision,
            idempotencyKey: _uuid.v4(),
          );
      _ref.invalidate(yorksV1ConfigurationCentreProvider);
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

  Future<bool> _run(Future<void> Function() operation) async {
    state = const AsyncValue.loading();
    try {
      await operation();
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
