import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_inventory_workbook.dart';
import '../models/yorks_v1_logistics.dart';
import '../repositories/yorks_v1_logistics_repository.dart';
import '../services/yorks_v1_inventory_workbook_service.dart';

enum YorksV1InventoryImportStatus {
  idle,
  selecting,
  preview,
  committing,
  succeeded,
  failed,
}

class YorksV1InventoryImportState {
  const YorksV1InventoryImportState({
    this.status = YorksV1InventoryImportStatus.idle,
    this.preview,
    this.result,
    this.errorCode,
  });

  final YorksV1InventoryImportStatus status;
  final YorksV1InventoryImportPreview? preview;
  final YorksV1InventoryImportResult? result;
  final YorksV1DomainErrorCode? errorCode;

  bool get isBusy =>
      status == YorksV1InventoryImportStatus.selecting ||
      status == YorksV1InventoryImportStatus.committing;
}

class YorksV1InventoryImportController
    extends StateNotifier<YorksV1InventoryImportState> {
  YorksV1InventoryImportController({
    required YorksV1LogisticsRepository repository,
    required YorksV1InventoryWorkbookFileService fileService,
    YorksV1InventoryWorkbookCodec codec = const YorksV1InventoryWorkbookCodec(),
    String Function()? uuidFactory,
  }) : _repository = repository,
       _fileService = fileService,
       _codec = codec,
       _uuidFactory = uuidFactory ?? const Uuid().v4,
       super(const YorksV1InventoryImportState());

  final YorksV1LogisticsRepository _repository;
  final YorksV1InventoryWorkbookFileService _fileService;
  final YorksV1InventoryWorkbookCodec _codec;
  final String Function() _uuidFactory;
  String? _idempotencyKey;

  Future<void> chooseFile(YorksV1InventoryWorkspace workspace) async {
    if (state.isBusy) return;
    state = YorksV1InventoryImportState(
      status: YorksV1InventoryImportStatus.selecting,
      preview: state.preview,
    );
    try {
      final selected = await _fileService.selectWorkbook();
      if (selected == null) {
        state = YorksV1InventoryImportState(
          status: state.preview == null
              ? YorksV1InventoryImportStatus.idle
              : YorksV1InventoryImportStatus.preview,
          preview: state.preview,
        );
        return;
      }
      prepareSelected(selected, workspace);
    } on YorksV1DomainException catch (error) {
      state = YorksV1InventoryImportState(
        status: YorksV1InventoryImportStatus.failed,
        preview: state.preview,
        errorCode: error.code,
      );
    } catch (_) {
      state = YorksV1InventoryImportState(
        status: YorksV1InventoryImportStatus.failed,
        preview: state.preview,
        errorCode: YorksV1DomainErrorCode.invalidInput,
      );
    }
  }

  void prepareSelected(
    YorksV1InventorySelectedWorkbook selected,
    YorksV1InventoryWorkspace workspace,
  ) {
    final preview = _codec.decode(
      workbook: selected,
      categories: workspace.categories,
      inventoryItems: workspace.items,
    );
    _idempotencyKey = _uuidFactory();
    state = YorksV1InventoryImportState(
      status: YorksV1InventoryImportStatus.preview,
      preview: preview,
    );
  }

  void selectExistingCategory({
    required String sourceCategory,
    required String categoryId,
  }) {
    final preview = state.preview;
    if (preview == null || state.isBusy) return;
    state = YorksV1InventoryImportState(
      status: YorksV1InventoryImportStatus.preview,
      preview: _codec.applyCategoryDecision(
        preview: preview,
        sourceCategory: sourceCategory,
        categoryId: categoryId,
      ),
    );
  }

  void createNewCategory(String sourceCategory) {
    final preview = state.preview;
    if (preview == null || state.isBusy) return;
    state = YorksV1InventoryImportState(
      status: YorksV1InventoryImportStatus.preview,
      preview: _codec.applyCategoryDecision(
        preview: preview,
        sourceCategory: sourceCategory,
        createNew: true,
      ),
    );
  }

  Future<YorksV1InventoryImportResult?> commit() async {
    final preview = state.preview;
    final idempotencyKey = _idempotencyKey;
    if (preview == null ||
        !preview.canCommit ||
        idempotencyKey == null ||
        state.isBusy) {
      return null;
    }
    state = YorksV1InventoryImportState(
      status: YorksV1InventoryImportStatus.committing,
      preview: preview,
    );
    try {
      final result = await _repository.importInventory(
        YorksV1InventoryImportInput(
          fileName: preview.fileName,
          rows: [for (final row in preview.rows) row.toRpcInput()],
          idempotencyKey: idempotencyKey,
        ),
      );
      state = YorksV1InventoryImportState(
        status: YorksV1InventoryImportStatus.succeeded,
        preview: preview,
        result: result,
      );
      return result;
    } on YorksV1DomainException catch (error) {
      state = YorksV1InventoryImportState(
        status: YorksV1InventoryImportStatus.failed,
        preview: preview,
        errorCode: error.code,
      );
    } catch (_) {
      state = YorksV1InventoryImportState(
        status: YorksV1InventoryImportStatus.failed,
        preview: preview,
        errorCode: YorksV1DomainErrorCode.backendUnavailable,
      );
    }
    return null;
  }

  void reset() {
    if (state.isBusy) return;
    _idempotencyKey = null;
    state = const YorksV1InventoryImportState();
  }
}
