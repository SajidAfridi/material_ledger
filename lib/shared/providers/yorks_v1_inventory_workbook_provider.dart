import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/yorks_v1_inventory_import_controller.dart';
import '../models/yorks_v1_logistics.dart';
import '../services/yorks_v1_inventory_workbook_service.dart';
import 'yorks_v1_feature_flags_provider.dart';
import 'yorks_v1_inventory_supplier_provider.dart';
import 'yorks_v1_logistics_repository_provider.dart';

final yorksV1InventoryWorkbookFileServiceProvider =
    Provider<YorksV1InventoryWorkbookFileService>(
      (_) => const YorksV1PlatformInventoryWorkbookFileService(),
    );

final yorksV1InventoryImportControllerProvider =
    StateNotifierProvider.autoDispose<
      YorksV1InventoryImportController,
      YorksV1InventoryImportState
    >((ref) {
      return YorksV1InventoryImportController(
        repository: ref.watch(yorksV1LogisticsRepositoryProvider),
        fileService: ref.watch(yorksV1InventoryWorkbookFileServiceProvider),
        r38_9Commit: ref.watch(yorksV1FeatureFlagsProvider).inventorySuppliers
            ? ({required payload, required idempotencyKey}) async {
                final result = await ref
                    .read(yorksV1InventorySupplierRepositoryProvider)
                    .importPrepared(
                      payload: payload,
                      idempotencyKey: idempotencyKey,
                    );
                return YorksV1InventoryImportResult(
                  importBatchId: result.importBatchId,
                  rowCount: result.rowCount,
                  createdItems: result.createdItems,
                  updatedItems: result.updatedItems,
                  createdCategories: result.createdCategories,
                  createdSuppliers: result.createdSuppliers,
                  receiptBatches: result.receiptBatches,
                  movements: result.movements,
                  warningCount: result.warningCount,
                  excludedCount: result.excludedCount,
                  unknownSupplierRows: result.unknownSupplierRows,
                  unitTotals: [
                    for (final total in result.unitTotals)
                      YorksV1InventoryImportUnitTotal(
                        unit: total.unit,
                        acceptedQuantity: total.acceptedQuantity,
                        damagedQuantity: total.damagedQuantity,
                        rejectedQuantity: total.rejectedQuantity,
                      ),
                  ],
                );
              }
            : null,
      );
    });
