import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/yorks_v1_calculator_controller.dart';
import 'language_provider.dart';
import '../repositories/yorks_v1_calculator_repository.dart';
import 'yorks_v1_project_repository_provider.dart';
import 'yorks_v1_identity_provider.dart';
import 'yorks_v1_permission_provider.dart';

final yorksCalculatorWorkspaceEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment(
    'YORKS_V1_CALCULATOR_WORKSPACE',
    defaultValue: false,
  ),
);
final yorksCalculatorRepositoryProvider = Provider<YorksCalculatorRepository>((
  ref,
) {
  ref.watch(yorksV1AuthUserIdProvider);
  ref.watch(yorksV1CurrentRoleProvider);
  ref.watch(
    yorksV1CurrentPermissionSnapshotProvider.select(
      (s) => s.snapshot?.revision,
    ),
  );
  return YorksCalculatorRepository(ref.watch(yorksV1ProjectRpcClientProvider));
});

final yorksCalculatorControllerProvider = Provider.autoDispose
    .family<YorksCalculatorController, String>((ref, key) {
      final controller = YorksCalculatorController(
        ref.watch(yorksCalculatorRepositoryProvider),
        preferences: ref.watch(sharedPreferencesProvider),
        identity:
            '${const String.fromEnvironment('SUPABASE_URL')}|${ref.watch(yorksV1AuthUserIdProvider)}|$key',
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

class YorksCalculatorExitGuard {
  Future<bool> Function()? check;
}

final yorksCalculatorExitGuardProvider = Provider<YorksCalculatorExitGuard>(
  (ref) => YorksCalculatorExitGuard(),
);
