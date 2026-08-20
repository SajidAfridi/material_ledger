import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/yorks_v1_inventory_supplier.dart';
import '../repositories/yorks_v1_inventory_supplier_repository.dart';
import '../repositories/yorks_v1_material_request_repository.dart';
import '../sync/connectivity_service.dart';
import 'language_provider.dart';
import 'yorks_v1_feature_flags_provider.dart';
import 'yorks_v1_material_request_provider.dart';

final yorksV1InventorySupplierRpcClientProvider =
    Provider<YorksV1MaterialRequestRpcClient?>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return client == null
          ? null
          : SupabaseYorksV1MaterialRequestRpcClient(client);
    });

final yorksV1InventorySupplierRepositoryProvider =
    Provider<YorksV1InventorySupplierRepository>((ref) {
      return YorksV1SupabaseInventorySupplierRepository(
        featureFlags: ref.watch(yorksV1FeatureFlagsProvider),
        connectivity: ref.watch(connectivityProvider),
        rpcClient: ref.watch(yorksV1InventorySupplierRpcClientProvider),
      );
    });

class YorksV1InventorySupplierDirectoryQuery {
  const YorksV1InventorySupplierDirectoryQuery({
    this.search,
    this.status,
    this.limit = 30,
    this.offset = 0,
  });

  final String? search;
  final YorksV1InventorySupplierStatus? status;
  final int limit;
  final int offset;

  @override
  bool operator ==(Object other) =>
      other is YorksV1InventorySupplierDirectoryQuery &&
      other.search == search &&
      other.status == status &&
      other.limit == limit &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(search, status, limit, offset);
}

final yorksV1InventorySupplierDirectoryProvider = FutureProvider.autoDispose
    .family<
      YorksV1InventorySupplierDirectoryWorkspace,
      YorksV1InventorySupplierDirectoryQuery
    >((ref, query) {
      _listenForSupplierProjectionRevision(ref);
      return ref
          .watch(yorksV1InventorySupplierRepositoryProvider)
          .getDirectory(
            search: query.search,
            status: query.status,
            limit: query.limit,
            offset: query.offset,
          );
    });

class YorksV1InventorySupplierFolderQuery {
  const YorksV1InventorySupplierFolderQuery({
    required this.supplierId,
    required this.section,
    this.limit = 50,
    this.offset = 0,
  });

  final String supplierId;
  final YorksV1InventorySupplierFolderSection section;
  final int limit;
  final int offset;

  @override
  bool operator ==(Object other) =>
      other is YorksV1InventorySupplierFolderQuery &&
      other.supplierId == supplierId &&
      other.section == section &&
      other.limit == limit &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(supplierId, section, limit, offset);
}

final yorksV1InventorySupplierFolderProvider = FutureProvider.autoDispose
    .family<
      YorksV1InventorySupplierFolderWorkspace,
      YorksV1InventorySupplierFolderQuery
    >((ref, query) {
      _listenForSupplierProjectionRevision(ref);
      return ref
          .watch(yorksV1InventorySupplierRepositoryProvider)
          .getFolder(
            supplierId: query.supplierId,
            section: query.section,
            limit: query.limit,
            offset: query.offset,
          );
    });

class YorksV1InventorySupplierItemTrailQuery {
  const YorksV1InventorySupplierItemTrailQuery({
    required this.supplierId,
    required this.inventoryItemId,
    this.section = YorksV1InventorySupplierItemTrailSection.receiptLines,
    this.limit = 50,
    this.offset = 0,
  });

  final String supplierId;
  final String inventoryItemId;
  final YorksV1InventorySupplierItemTrailSection section;
  final int limit;
  final int offset;

  @override
  bool operator ==(Object other) =>
      other is YorksV1InventorySupplierItemTrailQuery &&
      other.supplierId == supplierId &&
      other.inventoryItemId == inventoryItemId &&
      other.section == section &&
      other.limit == limit &&
      other.offset == offset;

  @override
  int get hashCode =>
      Object.hash(supplierId, inventoryItemId, section, limit, offset);
}

final yorksV1InventorySupplierItemTrailProvider = FutureProvider.autoDispose
    .family<
      YorksV1InventorySupplierItemTrailWorkspace,
      YorksV1InventorySupplierItemTrailQuery
    >((ref, query) {
      _listenForSupplierProjectionRevision(ref);
      return ref
          .watch(yorksV1InventorySupplierRepositoryProvider)
          .getItemTrail(
            supplierId: query.supplierId,
            inventoryItemId: query.inventoryItemId,
            section: query.section,
            limit: query.limit,
            offset: query.offset,
          );
    });

class YorksV1InventorySupplierReceiptBatchDetailQuery {
  const YorksV1InventorySupplierReceiptBatchDetailQuery({
    required this.supplierId,
    required this.receiptBatchId,
    this.section = YorksV1InventorySupplierReceiptBatchDetailSection.lines,
    this.limit = 50,
    this.offset = 0,
  });

  final String supplierId;
  final String receiptBatchId;
  final YorksV1InventorySupplierReceiptBatchDetailSection section;
  final int limit;
  final int offset;

  @override
  bool operator ==(Object other) =>
      other is YorksV1InventorySupplierReceiptBatchDetailQuery &&
      other.supplierId == supplierId &&
      other.receiptBatchId == receiptBatchId &&
      other.section == section &&
      other.limit == limit &&
      other.offset == offset;

  @override
  int get hashCode =>
      Object.hash(supplierId, receiptBatchId, section, limit, offset);
}

final yorksV1InventorySupplierReceiptBatchDetailProvider = FutureProvider
    .autoDispose
    .family<
      YorksV1InventorySupplierReceiptBatchDetailWorkspace,
      YorksV1InventorySupplierReceiptBatchDetailQuery
    >((ref, query) {
      _listenForSupplierProjectionRevision(ref);
      return ref
          .watch(yorksV1InventorySupplierRepositoryProvider)
          .getReceiptBatchDetail(
            supplierId: query.supplierId,
            receiptBatchId: query.receiptBatchId,
            section: query.section,
            limit: query.limit,
            offset: query.offset,
          );
    });

void _listenForSupplierProjectionRevision(Ref ref) {
  // Realtime carries no supplier, quantity, receipt or return data. It only
  // invalidates the role-safe RPC snapshot so changes made on another device
  // converge through the authoritative repository projection.
  ref.listen<int>(yorksV1MaterialRequestRealtimeRevisionProvider, (
    previous,
    next,
  ) {
    if (previous != null && previous != next) ref.invalidateSelf();
  });
}

final yorksV1InventorySupplierCommandProvider =
    StateNotifierProvider.autoDispose<
      YorksV1InventorySupplierCommandController,
      AsyncValue<void>
    >((ref) => YorksV1InventorySupplierCommandController(ref));

class YorksV1InventorySupplierCommandController
    extends StateNotifier<AsyncValue<void>> {
  YorksV1InventorySupplierCommandController(this._ref)
    : super(const AsyncValue.data(null));

  final Ref _ref;
  static const _uuid = Uuid();

  Future<YorksV1InventorySupplierDirectoryEntry?> createSupplier({
    required String name,
    required String? description,
    required List<String> aliases,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _ref
          .read(yorksV1InventorySupplierRepositoryProvider)
          .createSupplier(
            YorksV1InventorySupplierCreateInput(
              name: name,
              description: description,
              aliases: aliases,
              idempotencyKey: _uuid.v4(),
            ),
          );
      _ref.invalidate(yorksV1InventorySupplierDirectoryProvider);
      state = const AsyncValue.data(null);
      return result;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      return null;
    }
  }

  Future<YorksV1InventorySupplierImportResult?> importInventory(
    YorksV1InventorySupplierImportInput input,
  ) async {
    state = const AsyncValue.loading();
    try {
      final result = await _ref
          .read(yorksV1InventorySupplierRepositoryProvider)
          .importInventory(input);
      _ref.invalidate(yorksV1InventorySupplierDirectoryProvider);
      _ref.invalidate(yorksV1InventorySupplierFolderProvider);
      state = const AsyncValue.data(null);
      return result;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      return null;
    }
  }
}
