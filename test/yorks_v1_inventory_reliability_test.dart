import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:material_ledger/shared/services/yorks_v1_inventory_workbook_service.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/controllers/yorks_v1_inventory_stock_command.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_logistics.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_logistics_repository.dart';

void main() {
  YorksV1InventoryAdjustmentInput input(String key, [String quantity = '1']) =>
      YorksV1InventoryAdjustmentInput(
        quantityDelta: quantity,
        reason: 'Count',
        idempotencyKey: key,
        inventoryItemId: 'item',
        expectedVersion: 3,
      );

  test('movement workbook exports signed facts without formula execution', () {
    final rows = [
      YorksV1InventoryMovement(
        id: 'movement',
        movementType: 'correction',
        quantityDelta: '-1.25',
        onHandAfterQuantity: '8.75',
        reason: 'Counted',
        actorDisplayName: 'Warehouse',
        createdAt: DateTime.utc(2026, 10, 8),
        itemDescription: '=not a formula',
        unit: 'Kg',
        sourceEntityId: 'reference',
      ),
    ];
    final bytes =
        YorksV1PlatformInventoryWorkbookFileService.buildMovementRegisterWorkbook(
          rows,
        );
    final archive = ZipDecoder().decodeBytes(bytes);
    final xml = utf8.decode(
      archive.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
    );
    expect(xml, contains('Quantity Change'));
    expect(xml, contains('-1.25'));
    expect(xml, contains('Counted'));
    expect(xml, contains('reference'));
    expect(xml, isNot(contains('<f>')));
    expect(xml, isNot(contains('Minimum Stock')));
  });

  test(
    'uncertain retry preserves original payload and identity, including offline retry',
    () async {
      final repo = _Repository();
      final command = YorksV1InventoryStockCommand();
      repo.failure = StateError('response lost');
      await expectLater(
        command.save(repo, () => input('original')),
        throwsStateError,
      );
      expect(command.unresolved, isTrue);
      repo.failure = const YorksV1DomainException(
        YorksV1DomainErrorCode.offline,
      );
      await expectLater(
        command.save(repo, () => input('changed', '99')),
        throwsA(isA<YorksV1DomainException>()),
      );
      expect(command.unresolved, isTrue);
      repo.failure = null;
      await command.save(repo, () => input('third', '22'));
      expect(
        repo.inputs.map((e) => e.idempotencyKey),
        everyElement('original'),
      );
      expect(repo.inputs.map((e) => e.quantityDelta), everyElement('1'));
      expect(command.unresolved, isFalse);
    },
  );

  test(
    'confirmed rejection releases command so corrected input uses a new key',
    () async {
      final repo = _Repository()
        ..failure = const YorksV1DomainException(
          YorksV1DomainErrorCode.invalidInput,
        );
      final command = YorksV1InventoryStockCommand();
      await expectLater(
        command.save(repo, () => input('bad')),
        throwsA(isA<YorksV1DomainException>()),
      );
      expect(command.unresolved, isFalse);
      repo.failure = null;
      await command.save(repo, () => input('corrected', '-1'));
      expect(repo.inputs.last.idempotencyKey, 'corrected');
      expect(repo.inputs.last.quantityDelta, '-1');
    },
  );

  test('double submit makes only one repository call', () async {
    final repo = _Repository()..completion = Completer<void>();
    final command = YorksV1InventoryStockCommand();
    final first = command.save(repo, () => input('first'));
    await command.save(repo, () => input('second'));
    expect(repo.inputs, hasLength(1));
    repo.completion!.complete();
    await first;
    expect(command.busy, isFalse);
  });
}

class _Repository implements YorksV1LogisticsRepository {
  final inputs = <YorksV1InventoryAdjustmentInput>[];
  Object? failure;
  Completer<void>? completion;
  @override
  Future<YorksV1LogisticsInventoryItem> adjustInventory(
    YorksV1InventoryAdjustmentInput input,
  ) async {
    inputs.add(input);
    if (completion != null) await completion!.future;
    if (failure != null) throw failure!;
    return const YorksV1LogisticsInventoryItem(
      id: 'item',
      isActive: true,
      description: 'Item',
      unit: 'Nos',
      onHandQuantity: '2',
      reservedQuantity: '0',
      availableQuantity: '2',
      recordVersion: 4,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
