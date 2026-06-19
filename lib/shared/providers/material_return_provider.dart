import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/material_return.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';
import '../sync/sync_engine.dart';
import 'inventory_provider.dart';

const _kReturnsKey = 'material_returns_list_v1';
const _uuid = Uuid();

/// All material returns raised by the engineer (FR-083).
final returnsProvider =
    StateNotifierProvider<ReturnsNotifier, List<MaterialReturn>>((ref) {
      return ReturnsNotifier(
        ref,
        ref.watch(storageProvider).collection<MaterialReturn>(
          _kReturnsKey,
          toJson: (r) => r.toJson(),
          fromJson: MaterialReturn.fromJson,
        ),
      );
    });

class ReturnsNotifier extends StateNotifier<List<MaterialReturn>> {
  ReturnsNotifier(this._ref, this._store) : super(_store.readAll());

  final Ref _ref;
  final CollectionStore<MaterialReturn> _store;

  Future<void> _persist() => _store.writeAll(state);

  /// Raise a return and restock the inventory for every line that maps to a
  /// known material (FR-083). Damaged stock is recorded but not put back on
  /// the shelf; surplus and wrong-item stock is restocked at existing cost.
  Future<void> addReturn({
    required String projectName,
    required String projectNameSecondary,
    required List<ReturnItem> items,
  }) async {
    final r = MaterialReturn(
      id: 'ret-${_uuid.v4().substring(0, 8)}',
      projectName: projectName,
      projectNameSecondary: projectNameSecondary,
      items: items,
      status: ReturnStatus.restocked,
      createdAt: DateTime.now(),
    );

    final inventory = _ref.read(materialsProvider.notifier);
    for (final item in items) {
      if (item.materialId == null) continue;
      if (item.reason == ReturnReason.damaged) continue; // not resalable
      // Restock at the current weighted-average cost (no cost change).
      await inventory.receiveStock(item.materialId!, item.quantity);
    }

    state = [r, ...state];
    await _persist();
    // Restocks inventory → transactional (atomic stock change on the server).
    await _ref.enqueueSync(
      collection: 'returns',
      docId: r.id,
      kind: 'return.create',
      label: 'Material return',
      payload: r.toJson(),
      transactional: true,
    );
  }
}
