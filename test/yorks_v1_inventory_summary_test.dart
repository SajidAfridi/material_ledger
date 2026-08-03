import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_logistics.dart';

void main() {
  test(
    'inventory summary reflects the authorized operational item projection',
    () {
      final summary = YorksV1InventorySummary.fromItems([
        _item(id: 'available', available: '4', reserved: '1'),
        _item(id: 'out', available: '0', reserved: '0'),
        _item(id: 'inactive', active: false, available: '0', reserved: '8'),
      ]);

      expect(summary.totalActiveItems, 2);
      expect(summary.outOfStockCount, 1);
      expect(summary.reservedCount, 1);
      expect(summary.lowStockCount, 0);
      expect(summary.incomingCount, 0);
      expect(summary.attentionCount, 1);
    },
  );
}

YorksV1LogisticsInventoryItem _item({
  required String id,
  bool active = true,
  required String available,
  required String reserved,
}) => YorksV1LogisticsInventoryItem(
  id: id,
  description: 'Item $id',
  unit: 'Nos',
  isActive: active,
  onHandQuantity: available,
  reservedQuantity: reserved,
  availableQuantity: available,
  recordVersion: 1,
);
