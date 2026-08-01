import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../controllers/yorks_v1_project_creation_draft_controller.dart';
import '../models/yorks_v1_project_creation_draft.dart';
import '../repositories/storage.dart';

const _yorksV1ProjectCreationDraftKeyPrefix =
    'yorks_v1_project_creation_draft_v1';

/// A per-authenticated-user draft on the current device. The device boundary is
/// provided by local storage itself; the auth UUID key prevents a shared device
/// from restoring one user's unfinished data for another user.
final yorksV1ProjectCreationDraftProvider =
    StateNotifierProvider.family<
      YorksV1ProjectCreationDraftController,
      YorksV1ProjectCreationDraft,
      String
    >((ref, ownerAuthUserId) {
      final store = ref
          .watch(storageProvider)
          .collection<YorksV1ProjectCreationDraft>(
            '${_yorksV1ProjectCreationDraftKeyPrefix}_$ownerAuthUserId',
            toJson: (draft) => draft.toJson(),
            fromJson: YorksV1ProjectCreationDraft.fromJson,
          );
      const uuid = Uuid();
      return YorksV1ProjectCreationDraftController(
        ownerAuthUserId: ownerAuthUserId,
        store: store,
        idempotencyKeyFactory: uuid.v4,
      );
    });
