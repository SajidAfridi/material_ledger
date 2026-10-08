import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_logistics.dart';
import '../repositories/yorks_v1_logistics_repository.dart';

/// Keeps an uncertain command immutable until the server resolves its outcome.
/// Retrying must replay both the payload and key, including expected version.
class YorksV1InventoryStockCommand {
  YorksV1InventoryAdjustmentInput? _pending;
  bool busy = false;
  bool get unresolved => _pending != null;

  Future<void> save(
    YorksV1LogisticsRepository repository,
    YorksV1InventoryAdjustmentInput Function() input,
  ) async {
    if (busy) return;
    final wasUnresolved = unresolved;
    busy = true;
    try {
      _pending ??= input();
      await repository.adjustInventory(_pending!);
      _pending = null;
    } on YorksV1DomainException catch (error) {
      if (!(wasUnresolved && error.code == YorksV1DomainErrorCode.offline) &&
          !{
            YorksV1DomainErrorCode.backendUnavailable,
            YorksV1DomainErrorCode.unexpectedResponse,
          }.contains(error.code)) {
        _pending = null;
      }
      rethrow;
    } finally {
      busy = false;
    }
  }
}
