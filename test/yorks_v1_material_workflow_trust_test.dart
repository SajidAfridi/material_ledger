import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/controllers/yorks_v1_material_workflow_command_controller.dart';
import 'package:material_ledger/shared/models/yorks_v1_logistics.dart';
import 'package:material_ledger/shared/models/yorks_v1_quantity.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_arrangement_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_logistics_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_material_request_repository.dart';
import 'package:material_ledger/shared/services/yorks_v1_critical_command_key_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('decimal quantity validation matches numeric(18,4) boundaries', () {
    final oneTenth = YorksV1DecimalQuantity.tryParse('0.1')!;
    final twoTenths = YorksV1DecimalQuantity.tryParse('0.2')!;

    expect((oneTenth + twoTenths).canonicalText, '0.3');
    expect(
      YorksV1DecimalQuantity.tryParse('99999999999999.9999')?.canonicalText,
      '99999999999999.9999',
    );
    expect(YorksV1DecimalQuantity.tryParse('0.00001'), isNull);
    expect(YorksV1DecimalQuantity.tryParse('100000000000000'), isNull);
    expect(yorksV1DisplayQuantity('1.0000'), '1');
  });

  test(
    'lost inventory-create response retries one persistent command key',
    () async {
      final preferences = await SharedPreferences.getInstance();
      var generatedKeys = 0;
      final logistics = _LostResponseLogisticsRepository();
      final controller = YorksV1MaterialWorkflowCommandController(
        materialRequests: _UnusedMaterialRequestRepository(),
        arrangements: _UnusedArrangementRepository(),
        logistics: logistics,
        commandKeys: YorksV1CriticalCommandKeyStore(
          preferences: preferences,
          actorAuthUserId: 'procurement-user',
          uuidFactory: () => 'retry-key-${++generatedKeys}',
        ),
      );
      const input = YorksV1InventoryAdjustmentInput(
        quantityDelta: '2.5000',
        reason: 'Created while arranging MR line',
        idempotencyKey: 'widget-key-must-be-replaced',
        description: 'Replacement damper',
        unit: 'Nos',
      );

      await expectLater(
        controller.createInventoryItem(requestLineId: 'line-1', input: input),
        throwsA(isA<TimeoutException>()),
      );
      final confirmed = await controller.createInventoryItem(
        requestLineId: 'line-1',
        input: input,
      );

      expect(confirmed.id, 'inventory-created');
      expect(logistics.idempotencyKeys, ['retry-key-1', 'retry-key-1']);
      expect(generatedKeys, 1);

      await controller.createInventoryItem(
        requestLineId: 'line-1',
        input: input,
      );
      expect(logistics.idempotencyKeys.last, 'retry-key-2');
      expect(generatedKeys, 2);
    },
  );
}

class _LostResponseLogisticsRepository implements YorksV1LogisticsRepository {
  final List<String> idempotencyKeys = [];
  var _responses = 0;

  @override
  Future<YorksV1LogisticsInventoryItem> adjustInventory(
    YorksV1InventoryAdjustmentInput input,
  ) async {
    idempotencyKeys.add(input.idempotencyKey);
    if (_responses++ == 0) {
      throw TimeoutException('The committed response was lost.');
    }
    return const YorksV1LogisticsInventoryItem(
      id: 'inventory-created',
      description: 'Replacement damper',
      unit: 'Nos',
      isActive: true,
      onHandQuantity: '2.5000',
      reservedQuantity: '0',
      availableQuantity: '2.5000',
      recordVersion: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedMaterialRequestRepository
    implements YorksV1MaterialRequestRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedArrangementRepository implements YorksV1ArrangementRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
