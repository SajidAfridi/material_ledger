import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/models/material_item.dart';
import 'package:material_ledger/shared/models/material_request.dart';
import 'package:material_ledger/shared/models/project.dart';
import 'package:material_ledger/shared/providers/inventory_provider.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/material_request_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
  });

  MaterialRequestsNotifier requests() =>
      container.read(materialRequestsProvider.notifier);
  MaterialsNotifier inventory() => container.read(materialsProvider.notifier);
  MaterialItem mat(String id) => inventory().byId(id)!;
  MaterialRequest reqById(String id) =>
      container.read(materialRequestsProvider).firstWhere((r) => r.id == id);

  /// A fresh material with known stock + a request line against it.
  Future<(String matId, String reqId)> seedReq(double stock, double reqQty) async {
    final matId = await inventory().addMaterial(
      name: 'Widget',
      urduName: '',
      category: MaterialCategory.other,
      unit: MaterialUnit.pieces,
      quantity: stock,
      unitPrice: 0,
    );
    await requests().addRequest(
      projectName: 'P',
      projectNameSecondary: '',
      itemCount: 1,
      lineItems: [
        RequestLineItem(
          materialId: matId,
          materialName: 'Widget',
          materialNameSecondary: '',
          quantity: reqQty,
          unitSymbol: 'pcs',
        ),
      ],
    );
    final reqId = container.read(materialRequestsProvider).first.id;
    return (matId, reqId);
  }

  group('Request comments', () {
    test('addRequestComment appends to the thread', () async {
      final (_, reqId) = await seedReq(100, 10);
      await requests().addRequestComment(
        reqId,
        text: 'Only 30 in stock — please advise',
        authorName: 'Proc',
        authorRole: 'Procurement',
      );
      final c = reqById(reqId).comments;
      expect(c.length, 1);
      expect(c.first.authorRole, 'Procurement');
      expect(c.first.text, 'Only 30 in stock — please advise');
    });

    test('blank comments are ignored', () async {
      final (_, reqId) = await seedReq(100, 10);
      await requests().addRequestComment(
        reqId,
        text: '   ',
        authorName: 'X',
        authorRole: 'Engineer',
      );
      expect(reqById(reqId).comments, isEmpty);
    });
  });

  group('Engineer edit request', () {
    test('reducing a line releases the reservation by the delta', () async {
      final (matId, reqId) = await seedReq(100, 40);
      expect(mat(matId).reservedQty, 40);

      await requests().updateRequestLine(reqId, matId, 25);

      expect(reqById(reqId).lineItems.first.quantity, 25);
      expect(mat(matId).reservedQty, 25); // released 15
    });

    test('a line can never be reduced below what was already dispatched',
        () async {
      final (matId, reqId) = await seedReq(100, 40);
      await requests().dispatch(reqId, [10]); // 10 of 40 out, 30 reserved
      expect(mat(matId).reservedQty, 30);

      await requests().updateRequestLine(reqId, matId, 5); // try below dispatched

      final line = reqById(reqId).lineItems.first;
      expect(line.quantity, 10); // clamped up to the 10 dispatched
      expect(line.qtyOutstanding, 0);
      expect(mat(matId).reservedQty, 0); // released the remaining 30
    });

    test('removing a line releases its reservation and drops the item count',
        () async {
      final (matId, reqId) = await seedReq(100, 40);
      expect(mat(matId).reservedQty, 40);

      await requests().removeRequestLine(reqId, matId);

      final req = reqById(reqId);
      expect(req.lineItems, isEmpty);
      expect(req.itemCount, 0);
      expect(mat(matId).reservedQty, 0); // fully released
    });
  });
}
