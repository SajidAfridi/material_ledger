import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/yorks_v1_inventory_stock_command.dart';
import 'yorks_v1_identity_provider.dart';

/// One in-session stock command, scoped to the signed-in authority. The route
/// guard and editor consult the same pending payload before allowing exit.
final yorksV1InventoryStockCommandProvider =
    Provider<YorksV1InventoryStockCommand>((ref) {
      ref.watch(yorksV1AuthUserIdProvider);
      ref.watch(yorksV1CurrentRoleProvider);
      return YorksV1InventoryStockCommand();
    });
