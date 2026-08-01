import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/yorks_v1_project_controller.dart';
import 'yorks_v1_identity_provider.dart';
import 'yorks_v1_project_repository_provider.dart';

/// Controller used by the project creation/team/state presentation. It gets
/// the latest exact claim at command time; stale UI role state cannot widen it.
final yorksV1ProjectCommandControllerProvider =
    StateNotifierProvider<
      YorksV1ProjectCommandController,
      YorksV1ProjectCommandState
    >((ref) {
      return YorksV1ProjectCommandController(
        repository: ref.watch(yorksV1ProjectRepositoryProvider),
        currentRole: () => ref.read(yorksV1CurrentRoleProvider),
      );
    });
