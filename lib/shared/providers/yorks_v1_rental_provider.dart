import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/yorks_v1_rental.dart';
import '../models/yorks_v1_rental_workbook.dart';
import '../repositories/yorks_v1_material_request_repository.dart';
import '../repositories/yorks_v1_rental_repository.dart';
import '../services/yorks_v1_rental_workbook_service.dart';
import '../sync/connectivity_service.dart';
import 'language_provider.dart';
import 'yorks_v1_feature_flags_provider.dart';

final yorksV1RentalRpcClientProvider =
    Provider<YorksV1MaterialRequestRpcClient?>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return client == null
          ? null
          : SupabaseYorksV1MaterialRequestRpcClient(client);
    });

final yorksV1RentalRepositoryProvider = Provider<YorksV1RentalRepository>((
  ref,
) {
  return YorksV1SupabaseRentalRepository(
    featureFlags: ref.watch(yorksV1FeatureFlagsProvider),
    connectivity: ref.watch(connectivityProvider),
    rpcClient: ref.watch(yorksV1RentalRpcClientProvider),
  );
});

final yorksV1RentalWorkbookFileServiceProvider =
    Provider<YorksV1RentalWorkbookFileService>(
      (ref) => const YorksV1PlatformRentalWorkbookFileService(),
    );

final yorksV1RentalWorkbookCodecProvider = Provider<YorksV1RentalWorkbookCodec>(
  (ref) => const YorksV1RentalWorkbookCodec(),
);

final yorksV1RentalPortfolioProvider =
    FutureProvider.autoDispose<YorksV1RentalPortfolio>((ref) {
      return ref.watch(yorksV1RentalRepositoryProvider).getPortfolio();
    });

final yorksV1RentalPropertyProvider = FutureProvider.autoDispose
    .family<YorksV1RentalPropertyDetail, String>((ref, propertyId) {
      return ref.watch(yorksV1RentalRepositoryProvider).getProperty(propertyId);
    });

final yorksV1RentalCommandProvider =
    StateNotifierProvider.autoDispose<
      YorksV1RentalCommandController,
      AsyncValue<void>
    >((ref) => YorksV1RentalCommandController(ref));

class YorksV1RentalCommandController extends StateNotifier<AsyncValue<void>> {
  YorksV1RentalCommandController(this._ref)
    : super(const AsyncValue.data(null));

  final Ref _ref;
  static const _uuid = Uuid();

  Future<YorksV1RentalPropertyDetail?> saveProperty(
    YorksV1RentalPropertyInput input, {
    required int? expectedVersion,
  }) async {
    state = const AsyncValue.loading();
    try {
      final detail = await _ref
          .read(yorksV1RentalRepositoryProvider)
          .saveProperty(
            input,
            expectedVersion: expectedVersion,
            idempotencyKey: _uuid.v4(),
          );
      _invalidate(detail.property.id);
      state = const AsyncValue.data(null);
      return detail;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      return null;
    }
  }

  Future<bool> recordPayment({
    required String propertyId,
    required String periodId,
    required double amount,
    required DateTime paymentDate,
    required String paymentMethod,
    String? reference,
    String? note,
  }) => _run(propertyId, (repository) {
    return repository.recordPayment(
      periodId: periodId,
      amount: amount,
      paymentDate: paymentDate,
      paymentMethod: paymentMethod,
      reference: reference,
      note: note,
      idempotencyKey: _uuid.v4(),
    );
  });

  Future<bool> saveCheque({
    required String propertyId,
    required Map<String, Object?> payload,
    required int? expectedVersion,
  }) => _run(propertyId, (repository) {
    return repository.saveCheque(
      payload: payload,
      expectedVersion: expectedVersion,
      idempotencyKey: _uuid.v4(),
    );
  });

  Future<bool> transitionCheque({
    required String propertyId,
    required YorksV1RentalCheque cheque,
    required YorksV1RentalChequeStatus nextStatus,
    String? reason,
  }) => _run(propertyId, (repository) {
    return repository.transitionCheque(
      chequeId: cheque.id,
      expectedVersion: cheque.recordVersion,
      nextStatus: nextStatus,
      reason: reason,
      idempotencyKey: _uuid.v4(),
    );
  });

  Future<bool> archiveProperty({
    required YorksV1RentalProperty property,
    required String reason,
  }) => _run(property.id, (repository) {
    return repository.archiveProperty(
      propertyId: property.id,
      expectedVersion: property.recordVersion,
      reason: reason,
      idempotencyKey: _uuid.v4(),
    );
  });

  Future<bool> importWorkbook(YorksV1RentalImportPreview preview) async {
    state = const AsyncValue.loading();
    try {
      await _ref
          .read(yorksV1RentalRepositoryProvider)
          .importWorkbook(
            payload: preview.toRpcPayload(),
            idempotencyKey: preview.commandId,
          );
      _ref.invalidate(yorksV1RentalPortfolioProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      return false;
    }
  }

  Future<bool> _run(
    String propertyId,
    Future<void> Function(YorksV1RentalRepository repository) operation,
  ) async {
    state = const AsyncValue.loading();
    try {
      await operation(_ref.read(yorksV1RentalRepositoryProvider));
      _invalidate(propertyId);
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      return false;
    }
  }

  void _invalidate(String propertyId) {
    _ref.invalidate(yorksV1RentalPortfolioProvider);
    _ref.invalidate(yorksV1RentalPropertyProvider(propertyId));
  }
}
