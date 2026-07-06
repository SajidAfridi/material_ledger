import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/models/material_return.dart';
import 'package:material_ledger/shared/models/project.dart';
import 'package:material_ledger/shared/models/stock_movement.dart';
import 'package:material_ledger/shared/providers/inventory_provider.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/material_request_provider.dart';
import 'package:material_ledger/shared/providers/material_return_provider.dart';
import 'package:material_ledger/shared/providers/stock_movement_provider.dart';

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

  test('dispatch appends a signed ledger entry with the resulting balance',
      () async {
    final startQty =
        container.read(materialsProvider).firstWhere((m) => m.id == 'mat-001').quantity;
    final notifier = container.read(materialRequestsProvider.notifier);
    await notifier.addRequest(
      projectName: 'Ledger Test',
      projectNameSecondary: '',
      itemCount: 1,
      lineItems: const [
        RequestLineItem(
          materialId: 'mat-001',
          materialName: 'Gate Valve 2" (Brass)',
          materialNameSecondary: '',
          quantity: 10,
          unitSymbol: 'pcs',
        ),
      ],
    );
    final reqId = container.read(materialRequestsProvider).first.id;
    await notifier.dispatch(reqId, [10]);

    final moves = container
        .read(stockMovementsProvider.notifier)
        .forMaterial('mat-001');
    expect(moves, isNotEmpty);
    final dispatchMove = moves.first;
    expect(dispatchMove.type, MovementType.dispatch);
    expect(dispatchMove.delta, -10);
    expect(dispatchMove.resultingBalance, startQty - 10);
    expect(dispatchMove.refId, reqId);
  });

  test('a return appends a positive returnIn entry', () async {
    final notifier = container.read(materialRequestsProvider.notifier);
    await notifier.addRequest(
      projectName: 'Ledger Return',
      projectNameSecondary: '',
      itemCount: 1,
      lineItems: const [
        RequestLineItem(
          materialId: 'mat-002',
          materialName: 'Ball Valve 1" (SS 304)',
          materialNameSecondary: '',
          quantity: 4,
          unitSymbol: 'pcs',
        ),
      ],
    );
    final reqId = container.read(materialRequestsProvider).first.id;
    await notifier.dispatch(reqId, [4]);

    await container.read(returnsProvider.notifier).addReturn(
      projectName: 'Ledger Return',
      projectNameSecondary: '',
      items: const [
        ReturnItem(
          description: 'Ball Valve 1" (SS 304)',
          quantity: 4,
          unitSymbol: 'pcs',
          materialId: 'mat-002',
          reason: ReturnReason.surplus,
        ),
      ],
    );

    final moves = container
        .read(stockMovementsProvider.notifier)
        .forMaterial('mat-002');
    expect(moves.first.type, MovementType.returnIn);
    expect(moves.first.delta, 4);
  });

  test('receiveStock appends a receipt entry', () async {
    final before =
        container.read(materialsProvider).firstWhere((m) => m.id == 'mat-003').quantity;
    await container
        .read(materialsProvider.notifier)
        .receiveStock('mat-003', 8, unitCostAED: 100);
    final moves = container
        .read(stockMovementsProvider.notifier)
        .forMaterial('mat-003');
    expect(moves.first.type, MovementType.receipt);
    expect(moves.first.delta, 8);
    expect(moves.first.resultingBalance, before + 8);
  });

  test('a zero-delta change is not ledgered', () async {
    await container.read(materialsProvider.notifier).adjustQuantity('mat-004', 0);
    expect(
      container.read(stockMovementsProvider.notifier).forMaterial('mat-004'),
      isEmpty,
    );
  });
}
