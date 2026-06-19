import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/models/material_item.dart';
import 'package:material_ledger/shared/models/material_request.dart';
import 'package:material_ledger/shared/models/project.dart';
import 'package:material_ledger/shared/providers/inventory_provider.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/material_request_provider.dart';

/// Regression tests for the dispatch logic fix: procurement must never be able
/// to dispatch material that isn't physically in inventory (the "I dispatched
/// 10 items that weren't in inventory" bug), and a real line can never be
/// dispatched beyond what's on hand.
void main() {
  group('Dispatch logic', () {
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

    MaterialRequestsNotifier requests() =>
        container.read(materialRequestsProvider.notifier);
    MaterialsNotifier inventory() =>
        container.read(materialsProvider.notifier);

    MaterialItem? mat(String id) => inventory().byId(id);
    MaterialRequest reqById(String id) =>
        container.read(materialRequestsProvider).firstWhere((r) => r.id == id);

    test('a custom / un-stocked line can never be dispatched', () async {
      final onHandBefore = mat('mat-001')!.quantity;

      await requests().addRequest(
        projectName: 'Test',
        projectNameSecondary: '',
        itemCount: 2,
        lineItems: const [
          // Real seeded material.
          RequestLineItem(
            materialId: 'mat-001',
            materialName: 'Gate Valve 2" (Brass)',
            materialNameSecondary: '',
            quantity: 24,
            unitSymbol: 'pcs',
          ),
          // Custom item that does NOT exist in inventory.
          RequestLineItem(
            materialId: 'custom-001',
            materialName: 'Bespoke Bracket',
            materialNameSecondary: '',
            quantity: 10,
            unitSymbol: 'pcs',
          ),
        ],
      );
      final id = container.read(materialRequestsProvider).first.id;

      // Reservation is held only for the real material; the custom item holds none
      // (and must not crash for a missing material).
      expect(mat('mat-001')!.reservedQty, 24);
      expect(mat('custom-001'), isNull);

      // Try to dispatch BOTH lines fully — including the custom one.
      await requests().dispatch(id, [24, 10]);

      final req = reqById(id);
      final real = req.lineItems[0];
      final custom = req.lineItems[1];

      // Real line dispatched and stock physically left the store.
      expect(real.qtyDispatched, 24);
      expect(mat('mat-001')!.quantity, onHandBefore - 24);

      // Custom line could NOT be dispatched — nothing moved, nothing faked.
      expect(custom.qtyDispatched ?? 0, 0);
      expect(mat('custom-001'), isNull);

      // One line still outstanding → request is partial, not fully dispatched.
      expect(req.status, RequestStatus.partial);
    });

    test('a real line is capped at on-hand stock, never over-dispatched',
        () async {
      // A real material with only 5 on hand.
      final lowId = await inventory().addMaterial(
        name: 'Scarce Coupling',
        urduName: '',
        category: MaterialCategory.other,
        unit: MaterialUnit.pieces,
        quantity: 5,
        unitPrice: 0,
      );

      await requests().addRequest(
        projectName: 'Test',
        projectNameSecondary: '',
        itemCount: 1,
        lineItems: [
          RequestLineItem(
            materialId: lowId,
            materialName: 'Scarce Coupling',
            materialNameSecondary: '',
            quantity: 10,
            unitSymbol: 'pcs',
          ),
        ],
      );
      final id = container.read(materialRequestsProvider).first.id;

      // Ask to dispatch 10 though only 5 are on hand.
      await requests().dispatch(id, [10]);

      final req = reqById(id);
      // Only the 5 on hand moved; stock can never go negative.
      expect(mat(lowId)!.quantity, 0);
      expect(req.lineItems[0].qtyDispatched, 5);
      expect(req.lineItems[0].qtyOutstanding, 5);
      expect(req.status, RequestStatus.partial);
    });

    test('relinkLine makes a custom line a real, dispatchable item', () async {
      await requests().addRequest(
        projectName: 'Test',
        projectNameSecondary: '',
        itemCount: 1,
        lineItems: const [
          RequestLineItem(
            materialId: 'custom-002',
            materialName: 'Special Flange',
            materialNameSecondary: '',
            quantity: 8,
            unitSymbol: 'pcs',
          ),
        ],
      );
      final id = container.read(materialRequestsProvider).first.id;

      // Procurement receives it into inventory: a new real material is created
      // and stocked, then the line is re-pointed onto it.
      final newId = await inventory().addMaterial(
        name: 'Special Flange',
        urduName: '',
        category: MaterialCategory.other,
        unit: MaterialUnit.pieces,
        quantity: 20,
        unitPrice: 0,
      );
      await requests().relinkLine(
        id,
        'custom-002',
        newMaterialId: newId,
        newName: 'Special Flange',
      );

      // Line now points at the real material, which reserves the outstanding qty.
      expect(reqById(id).lineItems[0].materialId, newId);
      expect(mat(newId)!.reservedQty, 8);

      // And it can now be dispatched like normal stock.
      await requests().dispatch(id, [8]);
      final req = reqById(id);
      expect(req.lineItems[0].qtyDispatched, 8);
      expect(mat(newId)!.quantity, 12);
      expect(req.status, RequestStatus.dispatched);
    });
  });
}
