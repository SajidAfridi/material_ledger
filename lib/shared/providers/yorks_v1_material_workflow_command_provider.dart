import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/yorks_v1_material_workflow_command_controller.dart';
import '../services/yorks_v1_critical_command_key_store.dart';
import 'language_provider.dart';
import 'yorks_v1_arrangement_repository_provider.dart';
import 'yorks_v1_identity_provider.dart';
import 'yorks_v1_logistics_repository_provider.dart';
import 'yorks_v1_material_request_repository_provider.dart';

final yorksV1MaterialWorkflowCommandControllerProvider =
    Provider<YorksV1MaterialWorkflowCommandController>((ref) {
      final actorAuthUserId = ref.watch(yorksV1AuthUserIdProvider) ?? '';
      return YorksV1MaterialWorkflowCommandController(
        materialRequests: ref.watch(yorksV1MaterialRequestRepositoryProvider),
        arrangements: ref.watch(yorksV1ArrangementRepositoryProvider),
        logistics: ref.watch(yorksV1LogisticsRepositoryProvider),
        commandKeys: YorksV1CriticalCommandKeyStore(
          preferences: ref.watch(sharedPreferencesProvider),
          actorAuthUserId: actorAuthUserId,
        ),
      );
    });
