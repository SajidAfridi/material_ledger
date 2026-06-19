import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/inventory_transaction.dart';
import '../models/material_item.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';

const _kMaterialsKey = 'materials_list_v3';
const _kTransactionsKey = 'transactions_list';
const _uuid = Uuid();

// ─── Materials ───────────────────────────────────────────────────

/// All materials in the inventory.
final materialsProvider =
    StateNotifierProvider<MaterialsNotifier, List<MaterialItem>>((ref) {
      return MaterialsNotifier(
        ref.watch(storageProvider).collection<MaterialItem>(
          _kMaterialsKey,
          toJson: (m) => m.toJson(),
          fromJson: MaterialItem.fromJson,
        ),
      );
    });

class MaterialsNotifier extends StateNotifier<List<MaterialItem>> {
  MaterialsNotifier(this._store)
    : super(_store.isSeeded ? _store.readAll() : _seedMaterials) {
    if (!_store.isSeeded) _store.writeAll(state);
  }

  final CollectionStore<MaterialItem> _store;

  Future<void> _persist() => _store.writeAll(state);

  Future<String> addMaterial({
    required String name,
    required String urduName,
    required MaterialCategory category,
    required MaterialUnit unit,
    required double quantity,
    required double unitPrice,
    double minStockLevel = 0,
    String brand = '',
    String countryOfOrigin = '',
    String size = '',
    String ralColour = '',
  }) async {
    final id = _uuid.v4();
    final item = MaterialItem(
      id: id,
      name: name,
      urduName: urduName,
      category: category,
      unit: unit,
      quantity: quantity,
      unitPrice: unitPrice,
      minStockLevel: minStockLevel,
      brand: brand,
      countryOfOrigin: countryOfOrigin,
      size: size,
      ralColour: ralColour,
    );
    state = [...state, item];
    await _persist();
    return id;
  }

  Future<void> updateMaterial(MaterialItem updated) async {
    state = [
      for (final item in state)
        if (item.id == updated.id) updated else item,
    ];
    await _persist();
  }

  Future<void> deleteMaterial(String id) async {
    state = state.where((item) => item.id != id).toList();
    await _persist();
  }

  /// Adjust quantity (positive for incoming, negative for outgoing).
  Future<void> adjustQuantity(String id, double delta) async {
    state = [
      for (final item in state)
        if (item.id == id)
          item.copyWith(
            quantity: (item.quantity + delta).clamp(0, double.infinity),
          )
        else
          item,
    ];
    await _persist();
  }

  // ─── Atomic stock transactions (FR-094 reservation) ──────────────
  // These map 1:1 onto Firestore transactions when the repository layer is
  // swapped to Firebase; today they are single-threaded notifier mutations.

  /// Reserve [qty] of an item for an approved plan/request. Reserved stock is
  /// excluded from `availableQty` so it can't be promised twice.
  Future<void> reserve(String id, double qty) async {
    if (qty <= 0) return;
    state = [
      for (final item in state)
        if (item.id == id)
          item.copyWith(reservedQty: item.reservedQty + qty)
        else
          item,
    ];
    await _persist();
  }

  /// Release a prior reservation (e.g. plan rejected, request cancelled).
  Future<void> release(String id, double qty) async {
    if (qty <= 0) return;
    state = [
      for (final item in state)
        if (item.id == id)
          item.copyWith(
            reservedQty: (item.reservedQty - qty)
                .clamp(0, double.infinity)
                .toDouble(),
          )
        else
          item,
    ];
    await _persist();
  }

  /// Dispatch [qty] to site: decrement on-hand and free the matching
  /// reservation in one step. Returns false if there isn't enough on hand.
  Future<bool> dispatch(String id, double qty) async {
    if (qty <= 0) return true;
    final item = byId(id);
    if (item == null || item.quantity < qty) return false;
    state = [
      for (final i in state)
        if (i.id == id)
          i.copyWith(
            quantity: (i.quantity - qty).clamp(0, double.infinity).toDouble(),
            reservedQty: (i.reservedQty - qty)
                .clamp(0, double.infinity)
                .toDouble(),
          )
        else
          i,
    ];
    await _persist();
    return true;
  }

  /// Receive goods into the store (goods receipt). Increments on-hand and rolls
  /// the unit cost into a weighted average when an incoming cost is supplied.
  Future<void> receiveStock(
    String id,
    double qty, {
    double? unitCostAED,
  }) async {
    if (qty <= 0) return;
    state = [
      for (final item in state)
        if (item.id == id)
          item.copyWith(
            quantity: item.quantity + qty,
            unitPrice: unitCostAED == null
                ? item.unitPrice
                : _weightedAvg(
                    item.quantity,
                    item.unitPrice,
                    qty,
                    unitCostAED,
                  ),
          )
        else
          item,
    ];
    await _persist();
  }

  /// Weighted-average cost after receiving [inQty] @ [inCost].
  static double _weightedAvg(
    double onHand,
    double oldCost,
    double inQty,
    double inCost,
  ) {
    final total = onHand + inQty;
    if (total <= 0) return inCost;
    return (onHand * oldCost + inQty * inCost) / total;
  }

  MaterialItem? byId(String id) {
    for (final i in state) {
      if (i.id == id) return i;
    }
    return null;
  }
}

// ─── Transactions ────────────────────────────────────────────────

/// All recorded transactions.
final transactionsProvider =
    StateNotifierProvider<TransactionsNotifier, List<InventoryTransaction>>((
      ref,
    ) {
      return TransactionsNotifier(
        ref.watch(storageProvider).collection<InventoryTransaction>(
          _kTransactionsKey,
          toJson: (t) => t.toJson(),
          fromJson: InventoryTransaction.fromJson,
        ),
      );
    });

class TransactionsNotifier extends StateNotifier<List<InventoryTransaction>> {
  TransactionsNotifier(this._store) : super(_store.readAll());

  final CollectionStore<InventoryTransaction> _store;

  Future<void> _persist() => _store.writeAll(state);

  Future<void> addTransaction({
    required String materialId,
    required String materialName,
    required TransactionType type,
    required double quantity,
    required String unitSymbol,
    String notes = '',
  }) async {
    final txn = InventoryTransaction(
      id: _uuid.v4(),
      materialId: materialId,
      materialName: materialName,
      type: type,
      quantity: quantity,
      unitSymbol: unitSymbol,
      notes: notes,
    );
    // Insert at the beginning so newest is first.
    state = [txn, ...state];
    await _persist();
  }
}

// ─── Transaction Filter ──────────────────────────────────────────

/// Filter applied to the transactions list.
enum TransactionFilter { all, incoming, outgoing }

final transactionFilterProvider = StateProvider<TransactionFilter>(
  (ref) => TransactionFilter.all,
);

/// Inventory search query for the inventory screen.
final inventorySearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered transactions based on the active filter.
final filteredTransactionsProvider = Provider<List<InventoryTransaction>>((
  ref,
) {
  final filter = ref.watch(transactionFilterProvider);
  final all = ref.watch(transactionsProvider);
  return switch (filter) {
    TransactionFilter.all => all,
    TransactionFilter.incoming =>
      all.where((t) => t.type == TransactionType.incoming).toList(),
    TransactionFilter.outgoing =>
      all.where((t) => t.type == TransactionType.outgoing).toList(),
  };
});

/// Filtered materials based on search query.
final filteredMaterialsProvider = Provider<List<MaterialItem>>((ref) {
  final query = ref.watch(inventorySearchQueryProvider).toLowerCase().trim();
  final materials = ref.watch(materialsProvider);
  if (query.isEmpty) return materials;
  return materials
      .where(
        (m) =>
            m.name.toLowerCase().contains(query) ||
            m.urduName.toLowerCase().contains(query) ||
            m.category.label.toLowerCase().contains(query),
      )
      .toList();
});

// ─── Derived Providers ───────────────────────────────────────────

/// Total stock value across all materials.
final totalStockValueProvider = Provider<double>((ref) {
  final materials = ref.watch(materialsProvider);
  return materials.fold(0.0, (sum, item) => sum + item.totalValue);
});

/// Count of unique materials.
final materialCountProvider = Provider<int>((ref) {
  return ref.watch(materialsProvider).length;
});

/// Count of total transactions.
final transactionCountProvider = Provider<int>((ref) {
  return ref.watch(transactionsProvider).length;
});

/// Recent transactions (last 10).
final recentTransactionsProvider = Provider<List<InventoryTransaction>>((ref) {
  final all = ref.watch(transactionsProvider);
  return all.take(10).toList();
});

// ─── HVAC Seed Materials ─────────────────────────────────────────

final _seedMaterials = [
  // ─── Air Inlet & Outlet (client spec: Brand/Supplier, Country, Size, RAL) ──
  MaterialItem(
    id: 'mat-air-01',
    name: 'Supply Air Grille (double deflection)',
    urduName: 'سپلائی ایئر گرل',
    category: MaterialCategory.airInletOutlet,
    unit: MaterialUnit.pieces,
    quantity: 60,
    unitPrice: 42.00,
    minStockLevel: 15,
    brand: 'Systemair',
    countryOfOrigin: 'UAE',
    size: '600x300mm',
    ralColour: 'RAL 9010',
    createdAt: DateTime(2025, 11, 2),
    updatedAt: DateTime(2025, 12, 28),
  ),
  MaterialItem(
    id: 'mat-air-02',
    name: 'Return Air Grille (egg-crate)',
    urduName: 'ریٹرن ایئر گرل',
    category: MaterialCategory.airInletOutlet,
    unit: MaterialUnit.pieces,
    quantity: 48,
    unitPrice: 38.50,
    minStockLevel: 12,
    brand: 'TROX',
    countryOfOrigin: 'Germany',
    size: '600x600mm',
    ralColour: 'RAL 9010',
    createdAt: DateTime(2025, 11, 2),
    updatedAt: DateTime(2025, 12, 20),
  ),
  MaterialItem(
    id: 'mat-air-03',
    name: 'Square Ceiling Diffuser (4-way)',
    urduName: 'سکوائر سیلنگ ڈفیوزر',
    category: MaterialCategory.airInletOutlet,
    unit: MaterialUnit.pieces,
    quantity: 35,
    unitPrice: 55.00,
    minStockLevel: 10,
    brand: 'Holyaire',
    countryOfOrigin: 'UAE',
    size: '595x595mm',
    ralColour: 'RAL 9016',
    createdAt: DateTime(2025, 11, 5),
    updatedAt: DateTime(2025, 12, 22),
  ),
  MaterialItem(
    id: 'mat-air-04',
    name: 'Linear Slot Diffuser (2-slot)',
    urduName: 'لینیئر سلاٹ ڈفیوزر',
    category: MaterialCategory.airInletOutlet,
    unit: MaterialUnit.meters,
    quantity: 120,
    unitPrice: 68.00,
    minStockLevel: 20,
    brand: 'Systemair',
    countryOfOrigin: 'Sweden',
    size: '1200mm',
    ralColour: 'RAL 9005',
    createdAt: DateTime(2025, 11, 6),
    updatedAt: DateTime(2025, 12, 18),
  ),
  MaterialItem(
    id: 'mat-air-05',
    name: 'Door Transfer Grille',
    urduName: 'ڈور ٹرانسفر گرل',
    category: MaterialCategory.airInletOutlet,
    unit: MaterialUnit.pieces,
    quantity: 8,
    unitPrice: 30.00,
    minStockLevel: 10,
    brand: 'Holyaire',
    countryOfOrigin: 'UAE',
    size: '400x200mm',
    ralColour: 'RAL 9010',
    createdAt: DateTime(2025, 11, 7),
    updatedAt: DateTime(2025, 12, 15),
  ),

  // ─── Valves ──────────────────────────────────────────────
  MaterialItem(
    id: 'mat-001',
    name: 'Gate Valve 2" (Brass)',
    urduName: 'گیٹ والو 2 انچ (پیتل)',
    category: MaterialCategory.valves,
    unit: MaterialUnit.pieces,
    quantity: 120,
    unitPrice: 45.00,
    minStockLevel: 20,
    createdAt: DateTime(2025, 9, 1),
    updatedAt: DateTime(2025, 10, 20),
  ),
  MaterialItem(
    id: 'mat-002',
    name: 'Ball Valve 1" (SS 304)',
    urduName: 'بال والو 1 انچ (سٹینلیس)',
    category: MaterialCategory.valves,
    unit: MaterialUnit.pieces,
    quantity: 85,
    unitPrice: 32.50,
    minStockLevel: 15,
    createdAt: DateTime(2025, 9, 1),
    updatedAt: DateTime(2025, 10, 18),
  ),
  MaterialItem(
    id: 'mat-003',
    name: 'Butterfly Valve 4" (Wafer)',
    urduName: 'بٹر فلائی والو 4 انچ',
    category: MaterialCategory.valves,
    unit: MaterialUnit.pieces,
    quantity: 30,
    unitPrice: 125.00,
    minStockLevel: 8,
    createdAt: DateTime(2025, 9, 5),
    updatedAt: DateTime(2025, 10, 22),
  ),
  MaterialItem(
    id: 'mat-004',
    name: 'Check Valve 1.5" (Swing Type)',
    urduName: 'چیک والو 1.5 انچ (سوئنگ)',
    category: MaterialCategory.valves,
    unit: MaterialUnit.pieces,
    quantity: 55,
    unitPrice: 38.00,
    minStockLevel: 10,
    createdAt: DateTime(2025, 9, 8),
    updatedAt: DateTime(2025, 10, 15),
  ),
  MaterialItem(
    id: 'mat-005',
    name: 'Globe Valve 3" (CI)',
    urduName: 'گلوب والو 3 انچ (کاسٹ آئرن)',
    category: MaterialCategory.valves,
    unit: MaterialUnit.pieces,
    quantity: 18,
    unitPrice: 95.00,
    minStockLevel: 5,
    createdAt: DateTime(2025, 9, 10),
    updatedAt: DateTime(2025, 10, 21),
  ),
  MaterialItem(
    id: 'mat-006',
    name: 'Pressure Relief Valve 2"',
    urduName: 'پریشر ریلیف والو 2 انچ',
    category: MaterialCategory.valves,
    unit: MaterialUnit.pieces,
    quantity: 12,
    unitPrice: 180.00,
    minStockLevel: 5,
    createdAt: DateTime(2025, 9, 12),
    updatedAt: DateTime(2025, 10, 20),
  ),

  // ─── Pipes & Tubing ─────────────────────────────────────
  MaterialItem(
    id: 'mat-010',
    name: 'GI Pipe 1" (Schedule 40)',
    urduName: 'جی آئی پائپ 1 انچ',
    category: MaterialCategory.pipes,
    unit: MaterialUnit.feet,
    quantity: 2400,
    unitPrice: 3.50,
    minStockLevel: 500,
    createdAt: DateTime(2025, 9, 1),
    updatedAt: DateTime(2025, 10, 24),
  ),
  MaterialItem(
    id: 'mat-011',
    name: 'GI Pipe 2" (Schedule 40)',
    urduName: 'جی آئی پائپ 2 انچ',
    category: MaterialCategory.pipes,
    unit: MaterialUnit.feet,
    quantity: 1800,
    unitPrice: 6.75,
    minStockLevel: 400,
    createdAt: DateTime(2025, 9, 2),
    updatedAt: DateTime(2025, 10, 22),
  ),
  MaterialItem(
    id: 'mat-012',
    name: 'Copper Pipe 3/4" (Type L)',
    urduName: 'تانبے کا پائپ 3/4 انچ',
    category: MaterialCategory.pipes,
    unit: MaterialUnit.feet,
    quantity: 800,
    unitPrice: 12.50,
    minStockLevel: 200,
    createdAt: DateTime(2025, 9, 3),
    updatedAt: DateTime(2025, 10, 21),
  ),
  MaterialItem(
    id: 'mat-013',
    name: 'PVC Pipe 4" (Schedule 40)',
    urduName: 'پی وی سی پائپ 4 انچ',
    category: MaterialCategory.pipes,
    unit: MaterialUnit.feet,
    quantity: 3200,
    unitPrice: 2.25,
    minStockLevel: 600,
    createdAt: DateTime(2025, 9, 4),
    updatedAt: DateTime(2025, 10, 23),
  ),
  MaterialItem(
    id: 'mat-014',
    name: 'Black Steel Pipe 3" (Sch 40)',
    urduName: 'بلیک سٹیل پائپ 3 انچ',
    category: MaterialCategory.pipes,
    unit: MaterialUnit.feet,
    quantity: 600,
    unitPrice: 15.00,
    minStockLevel: 150,
    createdAt: DateTime(2025, 9, 5),
    updatedAt: DateTime(2025, 10, 19),
  ),
  MaterialItem(
    id: 'mat-015',
    name: 'Flexible Copper Tube 1/2"',
    urduName: 'لچکدار تانبے کی ٹیوب',
    category: MaterialCategory.pipes,
    unit: MaterialUnit.rolls,
    quantity: 45,
    unitPrice: 85.00,
    minStockLevel: 10,
    createdAt: DateTime(2025, 9, 6),
    updatedAt: DateTime(2025, 10, 18),
  ),

  // ─── Fittings & Connectors ──────────────────────────────
  MaterialItem(
    id: 'mat-020',
    name: 'Elbow 90° 1" (GI)',
    urduName: 'ایلبو 90 ڈگری 1 انچ',
    category: MaterialCategory.fittings,
    unit: MaterialUnit.pieces,
    quantity: 350,
    unitPrice: 4.50,
    minStockLevel: 50,
    createdAt: DateTime(2025, 9, 1),
    updatedAt: DateTime(2025, 10, 24),
  ),
  MaterialItem(
    id: 'mat-021',
    name: 'Tee Fitting 2" (GI)',
    urduName: 'ٹی فٹنگ 2 انچ',
    category: MaterialCategory.fittings,
    unit: MaterialUnit.pieces,
    quantity: 220,
    unitPrice: 7.25,
    minStockLevel: 40,
    createdAt: DateTime(2025, 9, 2),
    updatedAt: DateTime(2025, 10, 22),
  ),
  MaterialItem(
    id: 'mat-022',
    name: 'Reducer 2" x 1" (GI)',
    urduName: 'ریڈیوسر 2x1 انچ',
    category: MaterialCategory.fittings,
    unit: MaterialUnit.pieces,
    quantity: 180,
    unitPrice: 5.80,
    minStockLevel: 30,
    createdAt: DateTime(2025, 9, 3),
    updatedAt: DateTime(2025, 10, 20),
  ),
  MaterialItem(
    id: 'mat-023',
    name: 'Flange 2" (150# RF)',
    urduName: 'فلینج 2 انچ',
    category: MaterialCategory.fittings,
    unit: MaterialUnit.pieces,
    quantity: 60,
    unitPrice: 22.00,
    minStockLevel: 15,
    createdAt: DateTime(2025, 9, 5),
    updatedAt: DateTime(2025, 10, 21),
  ),
  MaterialItem(
    id: 'mat-024',
    name: 'Union Coupling 1" (Brass)',
    urduName: 'یونین کپلنگ 1 انچ',
    category: MaterialCategory.fittings,
    unit: MaterialUnit.pieces,
    quantity: 140,
    unitPrice: 9.50,
    minStockLevel: 25,
    createdAt: DateTime(2025, 9, 6),
    updatedAt: DateTime(2025, 10, 19),
  ),
  MaterialItem(
    id: 'mat-025',
    name: 'Nipple 1/2" x 4" (GI)',
    urduName: 'نپل 1/2 انچ',
    category: MaterialCategory.fittings,
    unit: MaterialUnit.pieces,
    quantity: 500,
    unitPrice: 1.80,
    minStockLevel: 100,
    createdAt: DateTime(2025, 9, 7),
    updatedAt: DateTime(2025, 10, 23),
  ),

  // ─── Fasteners ──────────────────────────────────────────
  MaterialItem(
    id: 'mat-030',
    name: 'Hex Bolt M10 x 40mm (SS)',
    urduName: 'ہیکس بولٹ M10 (سٹینلیس)',
    category: MaterialCategory.fasteners,
    unit: MaterialUnit.boxes,
    quantity: 75,
    unitPrice: 18.00,
    minStockLevel: 15,
    createdAt: DateTime(2025, 9, 1),
    updatedAt: DateTime(2025, 10, 24),
  ),
  MaterialItem(
    id: 'mat-031',
    name: 'Hex Nut M10 (SS 304)',
    urduName: 'ہیکس نٹ M10 (سٹینلیس)',
    category: MaterialCategory.fasteners,
    unit: MaterialUnit.boxes,
    quantity: 80,
    unitPrice: 12.00,
    minStockLevel: 15,
    createdAt: DateTime(2025, 9, 2),
    updatedAt: DateTime(2025, 10, 22),
  ),
  MaterialItem(
    id: 'mat-032',
    name: 'Flat Washer M10 (SS)',
    urduName: 'فلیٹ واشر M10',
    category: MaterialCategory.fasteners,
    unit: MaterialUnit.boxes,
    quantity: 90,
    unitPrice: 8.50,
    minStockLevel: 20,
    createdAt: DateTime(2025, 9, 3),
    updatedAt: DateTime(2025, 10, 20),
  ),
  MaterialItem(
    id: 'mat-033',
    name: 'Spring Washer M10 (GI)',
    urduName: 'سپرنگ واشر M10',
    category: MaterialCategory.fasteners,
    unit: MaterialUnit.boxes,
    quantity: 65,
    unitPrice: 9.00,
    minStockLevel: 15,
    createdAt: DateTime(2025, 9, 4),
    updatedAt: DateTime(2025, 10, 19),
  ),
  MaterialItem(
    id: 'mat-034',
    name: 'U-Bolt 2" (GI)',
    urduName: 'یو بولٹ 2 انچ',
    category: MaterialCategory.fasteners,
    unit: MaterialUnit.pieces,
    quantity: 300,
    unitPrice: 3.25,
    minStockLevel: 50,
    createdAt: DateTime(2025, 9, 5),
    updatedAt: DateTime(2025, 10, 21),
  ),
  MaterialItem(
    id: 'mat-035',
    name: 'Anchor Bolt 1/2" x 6"',
    urduName: 'اینکر بولٹ 1/2 انچ',
    category: MaterialCategory.fasteners,
    unit: MaterialUnit.boxes,
    quantity: 40,
    unitPrice: 24.00,
    minStockLevel: 10,
    createdAt: DateTime(2025, 9, 6),
    updatedAt: DateTime(2025, 10, 18),
  ),
  MaterialItem(
    id: 'mat-036',
    name: 'Self-Tapping Screw #10 x 1"',
    urduName: 'سیلف ٹیپنگ سکرو',
    category: MaterialCategory.fasteners,
    unit: MaterialUnit.boxes,
    quantity: 110,
    unitPrice: 6.50,
    minStockLevel: 25,
    createdAt: DateTime(2025, 9, 7),
    updatedAt: DateTime(2025, 10, 23),
  ),
  MaterialItem(
    id: 'mat-037',
    name: 'Threaded Rod M12 x 1m (GI)',
    urduName: 'تھریڈڈ راڈ M12',
    category: MaterialCategory.fasteners,
    unit: MaterialUnit.pieces,
    quantity: 200,
    unitPrice: 5.50,
    minStockLevel: 40,
    createdAt: DateTime(2025, 9, 8),
    updatedAt: DateTime(2025, 10, 22),
  ),

  // ─── Ducts & Dampers ────────────────────────────────────
  MaterialItem(
    id: 'mat-040',
    name: 'GI Duct Sheet 24G (4x8 ft)',
    urduName: 'جی آئی ڈکٹ شیٹ 24 گیج',
    category: MaterialCategory.ducts,
    unit: MaterialUnit.sheets,
    quantity: 150,
    unitPrice: 35.00,
    minStockLevel: 30,
    createdAt: DateTime(2025, 9, 1),
    updatedAt: DateTime(2025, 10, 24),
  ),
  MaterialItem(
    id: 'mat-041',
    name: 'Flexible Duct 8" (25ft roll)',
    urduName: 'فلیکسبل ڈکٹ 8 انچ',
    category: MaterialCategory.ducts,
    unit: MaterialUnit.rolls,
    quantity: 25,
    unitPrice: 48.00,
    minStockLevel: 8,
    createdAt: DateTime(2025, 9, 3),
    updatedAt: DateTime(2025, 10, 22),
  ),
  MaterialItem(
    id: 'mat-042',
    name: 'Volume Damper 12" (Round)',
    urduName: 'والیوم ڈیمپر 12 انچ',
    category: MaterialCategory.ducts,
    unit: MaterialUnit.pieces,
    quantity: 35,
    unitPrice: 28.00,
    minStockLevel: 8,
    createdAt: DateTime(2025, 9, 5),
    updatedAt: DateTime(2025, 10, 20),
  ),
  MaterialItem(
    id: 'mat-043',
    name: 'Fire Damper 24"x12"',
    urduName: 'فائر ڈیمپر',
    category: MaterialCategory.ducts,
    unit: MaterialUnit.pieces,
    quantity: 15,
    unitPrice: 145.00,
    minStockLevel: 5,
    createdAt: DateTime(2025, 9, 6),
    updatedAt: DateTime(2025, 10, 21),
  ),
  MaterialItem(
    id: 'mat-044',
    name: 'Supply Grille 24"x6" (Aluminium)',
    urduName: 'سپلائی گرل 24x6 انچ',
    category: MaterialCategory.ducts,
    unit: MaterialUnit.pieces,
    quantity: 80,
    unitPrice: 18.50,
    minStockLevel: 15,
    createdAt: DateTime(2025, 9, 7),
    updatedAt: DateTime(2025, 10, 19),
  ),
  MaterialItem(
    id: 'mat-045',
    name: 'Return Air Diffuser 24"x24"',
    urduName: 'ریٹرن ائیر ڈفیوزر',
    category: MaterialCategory.ducts,
    unit: MaterialUnit.pieces,
    quantity: 50,
    unitPrice: 32.00,
    minStockLevel: 10,
    createdAt: DateTime(2025, 9, 8),
    updatedAt: DateTime(2025, 10, 23),
  ),

  // ─── Insulation ─────────────────────────────────────────
  MaterialItem(
    id: 'mat-050',
    name: 'Pipe Insulation 1" (Armaflex)',
    urduName: 'پائپ انسولیشن 1 انچ',
    category: MaterialCategory.insulation,
    unit: MaterialUnit.meters,
    quantity: 500,
    unitPrice: 4.80,
    minStockLevel: 100,
    createdAt: DateTime(2025, 9, 1),
    updatedAt: DateTime(2025, 10, 24),
  ),
  MaterialItem(
    id: 'mat-051',
    name: 'Duct Insulation Board 25mm',
    urduName: 'ڈکٹ انسولیشن بورڈ 25mm',
    category: MaterialCategory.insulation,
    unit: MaterialUnit.sheets,
    quantity: 200,
    unitPrice: 22.00,
    minStockLevel: 40,
    createdAt: DateTime(2025, 9, 3),
    updatedAt: DateTime(2025, 10, 22),
  ),
  MaterialItem(
    id: 'mat-052',
    name: 'Aluminum Tape (2" x 50yd)',
    urduName: 'ایلومینیم ٹیپ',
    category: MaterialCategory.insulation,
    unit: MaterialUnit.rolls,
    quantity: 80,
    unitPrice: 12.00,
    minStockLevel: 20,
    createdAt: DateTime(2025, 9, 5),
    updatedAt: DateTime(2025, 10, 20),
  ),
  MaterialItem(
    id: 'mat-053',
    name: 'Insulation Adhesive (5L can)',
    urduName: 'انسولیشن چپکنے والا',
    category: MaterialCategory.insulation,
    unit: MaterialUnit.pieces,
    quantity: 30,
    unitPrice: 35.00,
    minStockLevel: 8,
    createdAt: DateTime(2025, 9, 6),
    updatedAt: DateTime(2025, 10, 21),
  ),
  MaterialItem(
    id: 'mat-054',
    name: 'Fiberglass Wrap 2" (50ft)',
    urduName: 'فائبرگلاس ریپ',
    category: MaterialCategory.insulation,
    unit: MaterialUnit.rolls,
    quantity: 40,
    unitPrice: 28.00,
    minStockLevel: 10,
    createdAt: DateTime(2025, 9, 7),
    updatedAt: DateTime(2025, 10, 19),
  ),

  // ─── Electrical & Controls ──────────────────────────────
  MaterialItem(
    id: 'mat-060',
    name: 'Thermostat (Digital, 24V)',
    urduName: 'تھرموسٹیٹ (ڈیجیٹل)',
    category: MaterialCategory.electrical,
    unit: MaterialUnit.pieces,
    quantity: 25,
    unitPrice: 85.00,
    minStockLevel: 8,
    createdAt: DateTime(2025, 9, 1),
    updatedAt: DateTime(2025, 10, 24),
  ),
  MaterialItem(
    id: 'mat-061',
    name: 'Contactor 3-Pole 40A',
    urduName: 'کنٹیکٹر 3 پول 40A',
    category: MaterialCategory.electrical,
    unit: MaterialUnit.pieces,
    quantity: 18,
    unitPrice: 45.00,
    minStockLevel: 5,
    createdAt: DateTime(2025, 9, 3),
    updatedAt: DateTime(2025, 10, 22),
  ),
  MaterialItem(
    id: 'mat-062',
    name: 'Control Cable 4-core (1.5 sqmm)',
    urduName: 'کنٹرول کیبل 4 کور',
    category: MaterialCategory.electrical,
    unit: MaterialUnit.meters,
    quantity: 1200,
    unitPrice: 2.80,
    minStockLevel: 200,
    createdAt: DateTime(2025, 9, 5),
    updatedAt: DateTime(2025, 10, 20),
  ),
  MaterialItem(
    id: 'mat-063',
    name: 'Pressure Gauge 0-100 PSI',
    urduName: 'پریشر گیج',
    category: MaterialCategory.electrical,
    unit: MaterialUnit.pieces,
    quantity: 40,
    unitPrice: 18.00,
    minStockLevel: 10,
    createdAt: DateTime(2025, 9, 6),
    updatedAt: DateTime(2025, 10, 21),
  ),
  MaterialItem(
    id: 'mat-064',
    name: 'Temperature Sensor (PT100)',
    urduName: 'ٹمپریچر سینسر',
    category: MaterialCategory.electrical,
    unit: MaterialUnit.pieces,
    quantity: 20,
    unitPrice: 32.00,
    minStockLevel: 5,
    createdAt: DateTime(2025, 9, 7),
    updatedAt: DateTime(2025, 10, 23),
  ),

  // ─── Copper & Brass ─────────────────────────────────────
  MaterialItem(
    id: 'mat-070',
    name: 'Copper Elbow 3/4" (90°)',
    urduName: 'تانبے کی ایلبو 3/4 انچ',
    category: MaterialCategory.copper,
    unit: MaterialUnit.pieces,
    quantity: 250,
    unitPrice: 6.50,
    minStockLevel: 50,
    createdAt: DateTime(2025, 9, 1),
    updatedAt: DateTime(2025, 10, 24),
  ),
  MaterialItem(
    id: 'mat-071',
    name: 'Copper Tee 1/2"',
    urduName: 'تانبے کی ٹی 1/2 انچ',
    category: MaterialCategory.copper,
    unit: MaterialUnit.pieces,
    quantity: 180,
    unitPrice: 8.00,
    minStockLevel: 30,
    createdAt: DateTime(2025, 9, 3),
    updatedAt: DateTime(2025, 10, 22),
  ),
  MaterialItem(
    id: 'mat-072',
    name: 'Brass Nipple 1/2" x 3"',
    urduName: 'پیتل نپل 1/2 انچ',
    category: MaterialCategory.copper,
    unit: MaterialUnit.pieces,
    quantity: 400,
    unitPrice: 3.50,
    minStockLevel: 80,
    createdAt: DateTime(2025, 9, 5),
    updatedAt: DateTime(2025, 10, 20),
  ),
  MaterialItem(
    id: 'mat-073',
    name: 'Brazing Rod (Silver, 2mm)',
    urduName: 'بریزنگ راڈ (سلور)',
    category: MaterialCategory.copper,
    unit: MaterialUnit.kg,
    quantity: 15,
    unitPrice: 120.00,
    minStockLevel: 3,
    createdAt: DateTime(2025, 9, 6),
    updatedAt: DateTime(2025, 10, 21),
  ),

  // ─── Tools & Equipment ──────────────────────────────────
  MaterialItem(
    id: 'mat-080',
    name: 'Pipe Wrench 18"',
    urduName: 'پائپ رینچ 18 انچ',
    category: MaterialCategory.tools,
    unit: MaterialUnit.pieces,
    quantity: 15,
    unitPrice: 55.00,
    minStockLevel: 3,
    createdAt: DateTime(2025, 9, 1),
    updatedAt: DateTime(2025, 10, 24),
  ),
  MaterialItem(
    id: 'mat-081',
    name: 'Tube Cutter (Copper, 1/8-1")',
    urduName: 'ٹیوب کٹر (تانبا)',
    category: MaterialCategory.tools,
    unit: MaterialUnit.pieces,
    quantity: 8,
    unitPrice: 42.00,
    minStockLevel: 2,
    createdAt: DateTime(2025, 9, 3),
    updatedAt: DateTime(2025, 10, 22),
  ),
  MaterialItem(
    id: 'mat-082',
    name: 'Thread Seal Tape (PTFE, 1/2")',
    urduName: 'تھریڈ سیل ٹیپ',
    category: MaterialCategory.tools,
    unit: MaterialUnit.rolls,
    quantity: 200,
    unitPrice: 1.50,
    minStockLevel: 50,
    createdAt: DateTime(2025, 9, 5),
    updatedAt: DateTime(2025, 10, 20),
  ),
  MaterialItem(
    id: 'mat-083',
    name: 'Pipe Thread Compound (250ml)',
    urduName: 'پائپ تھریڈ کمپاؤنڈ',
    category: MaterialCategory.tools,
    unit: MaterialUnit.pieces,
    quantity: 30,
    unitPrice: 12.00,
    minStockLevel: 8,
    createdAt: DateTime(2025, 9, 6),
    updatedAt: DateTime(2025, 10, 21),
  ),
  MaterialItem(
    id: 'mat-084',
    name: 'Flaring Tool Kit',
    urduName: 'فلیرنگ ٹول کٹ',
    category: MaterialCategory.tools,
    unit: MaterialUnit.sets,
    quantity: 5,
    unitPrice: 175.00,
    minStockLevel: 2,
    createdAt: DateTime(2025, 9, 7),
    updatedAt: DateTime(2025, 10, 19),
  ),
];
