import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/yorks_v1_inventory_import_controller.dart';
import '../services/yorks_v1_inventory_workbook_service.dart';
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
      );
    });
