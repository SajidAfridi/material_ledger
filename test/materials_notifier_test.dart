import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_ledger/shared/models/material_item.dart';
import 'package:material_ledger/shared/providers/commercial_records_provider.dart';
import 'package:material_ledger/shared/providers/inventory_provider.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/users_provider.dart';

const _testLocalPassword = 'test-only-local-password';

void main() {
  group('MaterialsNotifier Tests', () {
    late SharedPreferences prefs;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localDemoPasswordProvider.overrideWithValue(_testLocalPassword),
        ],
      );
      addTearDown(container.dispose);
    });

    MaterialsNotifier notifier() => container.read(materialsProvider.notifier);

    test(
      'Loads HVAC seed materials initially when SharedPreferences is empty',
      () {
        final n = notifier();

        // Seed materials should be populated.
        expect(n.state.isNotEmpty, true);

        // Verify a specific seed material.
        final gateValve = n.state.firstWhere((item) => item.id == 'mat-001');
        expect(gateValve.name, 'Gate Valve 2" (Brass)');
        expect(gateValve.category, MaterialCategory.valves);
        expect(gateValve.unit, MaterialUnit.pieces);
        expect(gateValve.quantity, 120.0);
        expect(gateValve.unitPrice, 0);
        expect(gateValve.minStockLevel, 20.0);
        final stored =
            jsonDecode(prefs.getString('materials_list_v3')!) as List;
        expect((stored.first as Map).containsKey('unitPrice'), isFalse);
      },
    );

    test(
      'addMaterial inserts a new item, modifies state, and persists to SharedPreferences',
      () async {
        final n = notifier();
        final initialCount = n.state.length;

        final id = await n.addMaterial(
          name: 'Test Valve',
          urduName: 'ٹیسٹ والو',
          category: MaterialCategory.valves,
          unit: MaterialUnit.pieces,
          quantity: 50.0,
          unitPrice: 0,
          minStockLevel: 5.0,
        );

        expect(n.state.length, initialCount + 1);
        final addedItem = n.state.firstWhere((item) => item.id == id);
        expect(addedItem.name, 'Test Valve');
        expect(addedItem.quantity, 50.0);
        expect(addedItem.unitPrice, 0);

        // Verify persistence (same key + JSON, now written via the store).
        final savedJson = prefs.getString('materials_list_v3');
        expect(savedJson, isNotNull);
        final decodedList = MaterialItem.decodeList(savedJson!);
        expect(decodedList.length, initialCount + 1);
        expect(decodedList.any((item) => item.id == id), true);
        final stored = jsonDecode(savedJson) as List;
        expect(
          stored.cast<Map>().every((item) => !item.containsKey('unitPrice')),
          isTrue,
        );
      },
    );

    test(
      'updateMaterial changes fields and persists to SharedPreferences',
      () async {
        final n = notifier();

        final item = n.state.firstWhere((item) => item.id == 'mat-001');
        final updatedItem = item.copyWith(
          name: 'Updated Gate Valve',
          minStockLevel: 25.0,
        );

        await n.updateMaterial(updatedItem);

        final currentItem = n.state.firstWhere((i) => i.id == 'mat-001');
        expect(currentItem.name, 'Updated Gate Valve');
        expect(currentItem.unitPrice, 0);
        expect(currentItem.minStockLevel, 25.0);

        final savedJson = prefs.getString('materials_list_v3');
        expect(savedJson, isNotNull);
        final persistedItem = MaterialItem.decodeList(
          savedJson!,
        ).firstWhere((i) => i.id == 'mat-001');
        expect(persistedItem.name, 'Updated Gate Valve');
        expect(
          (jsonDecode(savedJson) as List).cast<Map>().every(
            (entry) => !entry.containsKey('unitPrice'),
          ),
          isTrue,
        );
      },
    );

    test(
      'deleteMaterial removes item and persists to SharedPreferences',
      () async {
        final n = notifier();
        final initialCount = n.state.length;
        expect(n.state.any((item) => item.id == 'mat-001'), true);

        await n.deleteMaterial('mat-001');

        expect(n.state.length, initialCount - 1);
        expect(n.state.any((item) => item.id == 'mat-001'), false);

        final savedJson = prefs.getString('materials_list_v3');
        final decodedList = MaterialItem.decodeList(savedJson!);
        expect(decodedList.any((item) => item.id == 'mat-001'), false);
      },
    );

    test(
      'adjustQuantity increases and decreases quantity and persists changes',
      () async {
        final n = notifier();
        final initialQty = n.state
            .firstWhere((i) => i.id == 'mat-001')
            .quantity;

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
      },
    );

    test(
      'adjustQuantity clamps quantity to 0 when negative adjustment exceeds stock',
      () async {
        final n = notifier();
        final initialQty = n.state
            .firstWhere((i) => i.id == 'mat-001')
            .quantity;

        await n.adjustQuantity('mat-001', -(initialQty + 100.0));

        expect(n.state.firstWhere((i) => i.id == 'mat-001').quantity, 0.0);

        final savedJson = prefs.getString('materials_list_v3');
        final decodedList = MaterialItem.decodeList(savedJson!);
        expect(decodedList.firstWhere((i) => i.id == 'mat-001').quantity, 0.0);
      },
    );

    test('deleteMaterial on an unknown id is a safe no-op', () async {
      final n = notifier();
      final initialCount = n.state.length;

      await n.deleteMaterial('does-not-exist');

      expect(n.state.length, initialCount);
    });

    test(
      'authorised Admin receives in-memory costs, never shared-cache cost',
      () async {
        await container
            .read(authControllerProvider)
            .signIn(email: 'owner@gmail.com', password: _testLocalPassword);

        final shared = container.read(materialsProvider);
        await Future<void>.delayed(Duration.zero);
        final enriched = container.read(materialsWithCommercialsProvider);
        expect(shared.firstWhere((m) => m.id == 'mat-001').unitPrice, 0);
        expect(enriched.firstWhere((m) => m.id == 'mat-001').unitPrice, 45);
        expect(container.read(materialUnitCostProvider('mat-001')), 45);

        final stored =
            jsonDecode(prefs.getString('materials_list_v3')!) as List;
        expect(
          stored.cast<Map>().every((entry) => !entry.containsKey('unitPrice')),
          isTrue,
        );
      },
    );

    test(
      'denied session cannot write cost and has no commercial cache',
      () async {
        final n = notifier();
        await expectLater(
          n.addMaterial(
            name: 'Denied Cost',
            urduName: '',
            category: MaterialCategory.other,
            unit: MaterialUnit.pieces,
            quantity: 1,
            unitPrice: 25,
          ),
          throwsA(isA<CommercialAccessDenied>()),
        );
        expect(prefs.containsKey(commercialLocalDevelopmentCacheKey), isFalse);
      },
    );
  });

  group('Soft delete (MaterialItem.deleted)', () {
    test('defaults to false and round-trips true', () {
      final fresh = MaterialItem(
        id: 'mi1',
        name: 'Fresh',
        urduName: '',
        category: MaterialCategory.other,
        unit: MaterialUnit.pieces,
        quantity: 1,
        unitPrice: 1,
      );
      expect(fresh.deleted, false);

      final tombstone = fresh.copyWith(deleted: true);
      final r = MaterialItem.fromJson(tombstone.toJson());
      expect(r.deleted, true);
    });

    test('a record predating this field decodes as not-deleted', () {
      final r = MaterialItem.fromJson({
        'id': 'mi2',
        'name': 'Legacy',
        'urduName': '',
        'category': 'Other',
        'unit': 'pcs',
        'quantity': 1,
        'unitPrice': 1,
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2025, 1, 1).toIso8601String(),
      });
      expect(r.deleted, false);
    });

    test(
      'a soft-deleted row already in local storage (e.g. re-hydrated from '
      'the cloud after another device deleted it) never surfaces in state',
      () async {
        final now = DateTime(2026, 1, 1).toIso8601String();
        SharedPreferences.setMockInitialValues({
          'materials_list_v3': jsonEncode([
            {
              'id': 'mi-live',
              'name': 'Still here',
              'urduName': '',
              'category': 'Other',
              'unit': 'pcs',
              'quantity': 1,
              'unitPrice': 1,
              'deleted': false,
              'createdAt': now,
              'updatedAt': now,
            },
            {
              'id': 'mi-tombstone',
              'name': 'Ghost',
              'urduName': '',
              'category': 'Other',
              'unit': 'pcs',
              'quantity': 1,
              'unitPrice': 1,
              'deleted': true,
              'createdAt': now,
              'updatedAt': now,
            },
          ]),
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        final materials = container.read(materialsProvider);
        expect(materials.any((m) => m.id == 'mi-live'), isTrue);
        expect(materials.any((m) => m.id == 'mi-tombstone'), isFalse);
      },
    );
  });
}
