import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_ledger/shared/models/material_item.dart';
import 'package:material_ledger/shared/providers/inventory_provider.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';

void main() {
  group('MaterialsNotifier Tests', () {
    late SharedPreferences prefs;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
    });

    MaterialsNotifier notifier() => container.read(materialsProvider.notifier);

    test('Loads HVAC seed materials initially when SharedPreferences is empty', () {
      final n = notifier();

      // Seed materials should be populated.
      expect(n.state.isNotEmpty, true);

      // Verify a specific seed material.
      final gateValve = n.state.firstWhere((item) => item.id == 'mat-001');
      expect(gateValve.name, 'Gate Valve 2" (Brass)');
      expect(gateValve.category, MaterialCategory.valves);
      expect(gateValve.unit, MaterialUnit.pieces);
      expect(gateValve.quantity, 120.0);
      expect(gateValve.unitPrice, 45.00);
      expect(gateValve.minStockLevel, 20.0);
    });

    test('addMaterial inserts a new item, modifies state, and persists to SharedPreferences', () async {
      final n = notifier();
      final initialCount = n.state.length;

      final id = await n.addMaterial(
        name: 'Test Valve',
        urduName: 'ٹیسٹ والو',
        category: MaterialCategory.valves,
        unit: MaterialUnit.pieces,
        quantity: 50.0,
        unitPrice: 10.0,
        minStockLevel: 5.0,
      );

      expect(n.state.length, initialCount + 1);
      final addedItem = n.state.firstWhere((item) => item.id == id);
      expect(addedItem.name, 'Test Valve');
      expect(addedItem.quantity, 50.0);
      expect(addedItem.unitPrice, 10.0);

      // Verify persistence (same key + JSON, now written via the store).
      final savedJson = prefs.getString('materials_list_v3');
      expect(savedJson, isNotNull);
      final decodedList = MaterialItem.decodeList(savedJson!);
      expect(decodedList.length, initialCount + 1);
      expect(decodedList.any((item) => item.id == id), true);
    });

    test('updateMaterial changes fields and persists to SharedPreferences', () async {
      final n = notifier();

      final item = n.state.firstWhere((item) => item.id == 'mat-001');
      final updatedItem = item.copyWith(
        name: 'Updated Gate Valve',
        unitPrice: 55.0,
        minStockLevel: 25.0,
      );

      await n.updateMaterial(updatedItem);

      final currentItem = n.state.firstWhere((i) => i.id == 'mat-001');
      expect(currentItem.name, 'Updated Gate Valve');
      expect(currentItem.unitPrice, 55.0);
      expect(currentItem.minStockLevel, 25.0);

      final savedJson = prefs.getString('materials_list_v3');
      expect(savedJson, isNotNull);
      final persistedItem = MaterialItem.decodeList(
        savedJson!,
      ).firstWhere((i) => i.id == 'mat-001');
      expect(persistedItem.name, 'Updated Gate Valve');
    });

    test('deleteMaterial removes item and persists to SharedPreferences', () async {
      final n = notifier();
      final initialCount = n.state.length;
      expect(n.state.any((item) => item.id == 'mat-001'), true);

      await n.deleteMaterial('mat-001');

      expect(n.state.length, initialCount - 1);
      expect(n.state.any((item) => item.id == 'mat-001'), false);

      final savedJson = prefs.getString('materials_list_v3');
      final decodedList = MaterialItem.decodeList(savedJson!);
      expect(decodedList.any((item) => item.id == 'mat-001'), false);
    });

    test('adjustQuantity increases and decreases quantity and persists changes', () async {
      final n = notifier();
      final initialQty = n.state.firstWhere((i) => i.id == 'mat-001').quantity;

      await n.adjustQuantity('mat-001', 30.0);
      expect(
        n.state.firstWhere((i) => i.id == 'mat-001').quantity,
        initialQty + 30.0,
      );

      await n.adjustQuantity('mat-001', -50.0);
      expect(
        n.state.firstWhere((i) => i.id == 'mat-001').quantity,
        initialQty + 30.0 - 50.0,
      );

      final savedJson = prefs.getString('materials_list_v3');
      final decodedList = MaterialItem.decodeList(savedJson!);
      expect(
        decodedList.firstWhere((i) => i.id == 'mat-001').quantity,
        initialQty + 30.0 - 50.0,
      );
    });

    test('adjustQuantity clamps quantity to 0 when negative adjustment exceeds stock', () async {
      final n = notifier();
      final initialQty = n.state.firstWhere((i) => i.id == 'mat-001').quantity;

      await n.adjustQuantity('mat-001', -(initialQty + 100.0));

      expect(n.state.firstWhere((i) => i.id == 'mat-001').quantity, 0.0);

      final savedJson = prefs.getString('materials_list_v3');
      final decodedList = MaterialItem.decodeList(savedJson!);
      expect(decodedList.firstWhere((i) => i.id == 'mat-001').quantity, 0.0);
    });
  });
}
