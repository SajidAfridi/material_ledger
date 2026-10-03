import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../controllers/yorks_v1_project_setup_coordinator.dart';
import '../models/yorks_v1_project_setup_operation.dart';
import '../repositories/yorks_v1_project_repository.dart';
import '../repositories/yorks_v1_project_setup_journal_store.dart';
import '../services/analytics_service.dart';
import 'yorks_v1_project_creation_draft_provider.dart';
import 'yorks_v1_project_repository_provider.dart';

final yorksV1ProjectReviewedCommandRepositoryProvider =
    Provider<YorksV1ProjectReviewedCommandRepository>((ref) {
      final repository = ref.watch(yorksV1ProjectRepositoryProvider);
      if (repository is YorksV1ProjectReviewedCommandRepository) {
        return repository as YorksV1ProjectReviewedCommandRepository;
      }
      throw StateError('Project repository does not support reviewed intents');
    });

typedef YorksV1ProjectSetupScope = ({
  String ownerAuthUserId,
  String draftId,
  String? projectId,
});

final yorksV1ProjectSetupCoordinatorProvider =
    StateNotifierProvider.family<
      YorksV1ProjectSetupCoordinator,
      YorksV1ProjectSetupState,
      YorksV1ProjectSetupScope
    >((ref, scope) {
      final draftController = ref.read(
        scope.projectId == null
            ? yorksV1ProjectSetupCreationDraftProvider(
                scope.ownerAuthUserId,
              ).notifier
            : yorksV1ProjectEditDraftProvider(
                YorksV1ProjectEditDraftContext(
                  ownerAuthUserId: scope.ownerAuthUserId,
                  projectId: scope.projectId!,
                ),
              ).notifier,
      );
      final store = YorksV1ProjectSetupJournalStore(
        storage: ref.watch(yorksV1ProjectDraftAtomicStorageProvider),
        journalKey: '${draftController.storageKey}:journal:${scope.draftId}',
        latestOperationKey: '${draftController.storageKey}:latest_operation',
        backendIdentity: ref.watch(yorksV1ProjectDraftBackendIdentityProvider),
        ownerAuthUserId: scope.ownerAuthUserId,
        draftId: scope.draftId,
        expectedMode: scope.projectId == null
            ? YorksV1ProjectSetupMode.create
            : YorksV1ProjectSetupMode.edit,
        projectId: scope.projectId,
        atomicOwned: <T>(work) {
          if (!draftController.hasCrossProcessOwnership) {
            throw const YorksV1ProjectSetupRecoveryException(
              YorksV1ProjectSetupRecoveryError.recoveryBlocked,
            );
          }
          return draftController.atomicOwned(work);
        },
      );
      return YorksV1ProjectSetupCoordinator(
        store: store,
        repository: ref.watch(yorksV1ProjectReviewedCommandRepositoryProvider),
        keyFactory: const Uuid().v4,
        analytics: ref.watch(analyticsServiceProvider),
      );
    });

/// Kept separate from lifecycle so presentation can identify known partial
/// success without treating an upload or activation error as a failed create.
String yorksV1ProjectSetupOutcome(YorksV1ProjectSetupOperation operation) =>
    operation.filesPending
    ? 'saved_files_pending'
    : operation.mode == YorksV1ProjectSetupMode.edit
    ? 'updated'
    : operation.project?.state.wireValue == 'active'
    ? 'active'
    : 'draft_pending_activation';
