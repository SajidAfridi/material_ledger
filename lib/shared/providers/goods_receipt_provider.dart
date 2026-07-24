import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/commercial_record.dart';
import '../models/goods_receipt.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';
import '../sync/sync_engine.dart';
import 'commercial_records_provider.dart';
import 'inventory_provider.dart';

const _kGoodsReceiptsKey = 'goods_receipts_v2';
const _uuid = Uuid();

/// All goods-receipt notes (newest first). Recording a receipt increments
/// on-hand stock and rolls the unit cost into a weighted average (FR-090).
final goodsReceiptsProvider =
    StateNotifierProvider<GoodsReceiptsNotifier, List<GoodsReceipt>>((ref) {
      return GoodsReceiptsNotifier(
        ref,
        ref
            .watch(storageProvider)
            .collection<GoodsReceipt>(
              _kGoodsReceiptsKey,
              toJson: (g) => g.toSharedJson(),
              fromJson: GoodsReceipt.fromJson,
            ),
        ref.watch(commercialRecordsProvider.notifier),
      );
    });

class GoodsReceiptsNotifier extends StateNotifier<List<GoodsReceipt>> {
  GoodsReceiptsNotifier(this._ref, this._store, this._commercial) : super([]) {
    final completeSource = _store.readAll();
    _commercialReady = _commercial.importLegacyForLocalDevelopment([
      for (final receipt in completeSource)
        CommercialRecord(
          subjectType: CommercialSubjectType.goodsReceipt,
          subjectId: receipt.id,
          unitCostAED: receipt.unitCostAED,
          totalCostAED: receipt.lineValueAED,
          updatedAt: receipt.receivedAt.toUtc(),
        ),
    ]);
    state = [
      for (final receipt in completeSource) receipt.withoutCommercials(),
    ];
    _store.writeAll(state);
  }

  final Ref _ref;
  final CollectionStore<GoodsReceipt> _store;
  final CommercialRecordsNotifier _commercial;
  late final Future<void> _commercialReady;

  /// Record a goods receipt and apply it to stock in one step.
  Future<GoodsReceipt> recordReceipt({
    required String materialId,
    required String materialName,
    required double quantity,
    required String unitSymbol,
    double? unitCostAED,
    required String supplier,
    required String receivedBy,
    String? note,
  }) async {
    final receiptId = 'grn-${_uuid.v4().substring(0, 8)}';
    if (unitCostAED != null) {
      await _commercialReady;
      await _commercial.setGoodsReceiptCosts(
        receiptId: receiptId,
        unitCostAED: unitCostAED,
        quantity: quantity,
      );
    }
    final grn = GoodsReceipt(
      id: receiptId,
      materialId: materialId,
      materialName: materialName,
      quantity: quantity,
      unitSymbol: unitSymbol,
      unitCostAED: 0,
      supplier: supplier,
      receivedBy: receivedBy,
      receivedAt: DateTime.now(),
      note: note,
    );
    // Apply to stock first (weighted-average cost, ledgered as a receipt), then
    // append the GRN.
    await _ref
        .read(materialsProvider.notifier)
        .receiveStock(
          materialId,
          quantity,
          unitCostAED: unitCostAED,
          refId: grn.id,
        );
    state = [grn, ...state];
    await _store.writeAll(state);
    // Increments on-hand stock → transactional (atomic on the server).
    await _ref.enqueueSync(
      collection: 'goodsReceipts',
      docId: grn.id,
      kind: 'goodsReceipt.create',
      label: 'Goods receipt',
      payload: grn.toSharedJson(),
      transactional: true,
    );
    return grn;
  }
}
