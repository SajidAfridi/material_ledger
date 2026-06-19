import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/goods_receipt.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';
import '../sync/sync_engine.dart';
import 'inventory_provider.dart';

const _kGoodsReceiptsKey = 'goods_receipts_v1';
const _uuid = Uuid();

/// All goods-receipt notes (newest first). Recording a receipt increments
/// on-hand stock and rolls the unit cost into a weighted average (FR-090).
final goodsReceiptsProvider =
    StateNotifierProvider<GoodsReceiptsNotifier, List<GoodsReceipt>>((ref) {
      return GoodsReceiptsNotifier(
        ref,
        ref.watch(storageProvider).collection<GoodsReceipt>(
          _kGoodsReceiptsKey,
          toJson: (g) => g.toJson(),
          fromJson: GoodsReceipt.fromJson,
        ),
      );
    });

class GoodsReceiptsNotifier extends StateNotifier<List<GoodsReceipt>> {
  GoodsReceiptsNotifier(this._ref, this._store) : super([]) {
    state = _store.readAll();
  }

  final Ref _ref;
  final CollectionStore<GoodsReceipt> _store;

  /// Record a goods receipt and apply it to stock in one step.
  Future<GoodsReceipt> recordReceipt({
    required String materialId,
    required String materialName,
    required double quantity,
    required String unitSymbol,
    required double unitCostAED,
    required String supplier,
    required String receivedBy,
    String? note,
  }) async {
    final grn = GoodsReceipt(
      id: 'grn-${_uuid.v4().substring(0, 8)}',
      materialId: materialId,
      materialName: materialName,
      quantity: quantity,
      unitSymbol: unitSymbol,
      unitCostAED: unitCostAED,
      supplier: supplier,
      receivedBy: receivedBy,
      receivedAt: DateTime.now(),
      note: note,
    );
    // Apply to stock first (weighted-average cost), then append the GRN.
    await _ref
        .read(materialsProvider.notifier)
        .receiveStock(materialId, quantity, unitCostAED: unitCostAED);
    state = [grn, ...state];
    await _store.writeAll(state);
    // Increments on-hand stock → transactional (atomic on the server).
    await _ref.enqueueSync(
      collection: 'goodsReceipts',
      docId: grn.id,
      kind: 'goodsReceipt.create',
      label: 'Goods receipt',
      payload: grn.toJson(),
      transactional: true,
    );
    return grn;
  }
}
