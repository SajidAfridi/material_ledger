import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/material_item.dart';
import 'package:material_ledger/shared/models/material_plan.dart';

void main() {
  test('PlanItem round-trips the equipment-schedule BOQ columns', () {
    const item = PlanItem(
      id: 'pi1',
      description: 'Motorized Smoke Damper',
      quantity: 4,
      unitSymbol: 'Nos',
      tagNo: 'MSD-01A',
      mounting: 'Slab',
      airFlowLS: 708,
      submittalRef: 'MTS-0063',
    );
    final r = PlanItem.fromJson(item.toJson());
    expect(r.tagNo, 'MSD-01A');
    expect(r.mounting, 'Slab');
    expect(r.airFlowLS, 708);
    expect(r.submittalRef, 'MTS-0063');
    expect(r.boqSummary, 'MSD-01A · Slab · 708 L/s · MTS-0063');
    // copyWith preserves them.
    expect(item.copyWith(quantity: 5).submittalRef, 'MTS-0063');
  });

  test('old PlanItem JSON without BOQ columns still decodes', () {
    final r = PlanItem.fromJson({
      'id': 'x',
      'description': 'Legacy',
      'quantity': 1,
      'unitSymbol': 'Nos',
    });
    expect(r.tagNo, '');
    expect(r.airFlowLS, isNull);
    expect(r.boqSummary, '');
  });

  test('MaterialItem round-trips store location', () {
    final m = MaterialItem(
      id: 'm1',
      name: 'Supply Grille',
      urduName: '',
      category: MaterialCategory.supplyGrille,
      unit: MaterialUnit.pieces,
      quantity: 10,
      unitPrice: 25,
      storeLocation: 'Rack B-3',
    );
    final r = MaterialItem.fromJson(m.toJson());
    expect(r.storeLocation, 'Rack B-3');
    expect(r.category, MaterialCategory.supplyGrille);
  });
}
