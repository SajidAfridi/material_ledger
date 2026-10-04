import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../controllers/yorks_v1_project_setup_coordinator.dart';
import '../models/yorks_v1_project_setup_operation.dart';
import '../models/yorks_v1_project_creation_draft.dart';
import '../repositories/yorks_v1_project_repository.dart';
import '../repositories/yorks_v1_project_setup_journal_store.dart';
import '../services/analytics_service.dart';
import 'yorks_v1_project_creation_draft_provider.dart';
import 'yorks_v1_identity_provider.dart';
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
      final draftController = ref.watch(
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
        restoreConfirmedFollowUps: false,
        updateLatestOperation: draftController.currentDraftId == scope.draftId,
        atomicOwned: <T>(work) {
          if (ref.read(yorksV1AuthUserIdProvider) != scope.ownerAuthUserId ||
              !draftController.hasCrossProcessOwnership) {
            throw const YorksV1ProjectSetupRecoveryException(
              YorksV1ProjectSetupRecoveryError.recoveryBlocked,
            );
          }
          return draftController.atomicOwned((tx) {
            // A claim/lock wait may outlive the picker or signed-in context.
            // Recheck inside the fenced transaction before changing history.
            if (ref.read(yorksV1AuthUserIdProvider) != scope.ownerAuthUserId) {
              throw const YorksV1ProjectSetupRecoveryException(
                YorksV1ProjectSetupRecoveryError.recoveryBlocked,
              );
            }
            return work(tx);
          });
        },
      );
      return YorksV1ProjectSetupCoordinator(
        store: store,
        repository: ref.watch(yorksV1ProjectReviewedCommandRepositoryProvider),
        keyFactory: const Uuid().v4,
        analytics: ref.watch(analyticsServiceProvider),
      );
    });

typedef YorksV1ProjectSetupPendingProjectContext = ({
  String ownerAuthUserId,
  String projectId,
});

typedef YorksV1ProjectSetupPendingOperation = ({
  YorksV1ProjectSetupScope scope,
  YorksV1ProjectSetupOperation operation,
});

/// Owner-scoped discovery only. The existing authorized project route must
/// guard presentation; mutations still use the exact historical coordinator
/// scope and the active local writer fence, never a reconstructed file intent.
final yorksV1ProjectSetupPendingOperationsProvider =
    Provider.family<
      List<YorksV1ProjectSetupPendingOperation>,
      YorksV1ProjectSetupPendingProjectContext
    >((ref, context) {
      if (ref.watch(yorksV1AuthUserIdProvider) != context.ownerAuthUserId) {
        return const [];
      }
      final backend = ref.watch(yorksV1ProjectDraftBackendIdentityProvider);
      final storage = ref.watch(yorksV1ProjectDraftAtomicStorageProvider);
      final operations = <YorksV1ProjectSetupPendingOperation>[];
      for (final mode in YorksV1ProjectSetupMode.values) {
        final editing = mode == YorksV1ProjectSetupMode.edit;
        final scopeKey = yorksV1ProjectDraftStorageKey(
          backendIdentity: backend,
          ownerAuthUserId: context.ownerAuthUserId,
          mode: editing
              ? YorksV1ProjectDraftMode.edit
              : YorksV1ProjectDraftMode.create,
          projectId: editing ? context.projectId : null,
        );
        for (final operation
            in YorksV1ProjectSetupJournalStore.completedForProject(
              storage: storage,
              scopeKey: scopeKey,
              backendIdentity: backend,
              ownerAuthUserId: context.ownerAuthUserId,
              projectId: context.projectId,
              mode: mode,
            )) {
          operations.add((
            scope: (
              ownerAuthUserId: context.ownerAuthUserId,
              draftId: operation.draftId,
              projectId: editing ? context.projectId : null,
            ),
            operation: operation,
          ));
        }
      }
      return List.unmodifiable(operations);
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
