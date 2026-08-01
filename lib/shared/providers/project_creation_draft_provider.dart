import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/project_creation_draft.dart';
import '../models/project.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';

const _uuid = Uuid();
const _draftKeyPrefix = 'project_creation_draft_v1';

/// A draft is isolated by stable application user id so switching personas on
/// a shared device never exposes another person's unfinished project.
final projectCreationDraftProvider =
    StateNotifierProvider.family<
      ProjectCreationDraftNotifier,
      ProjectCreationDraft,
      String
    >((ref, userId) {
      final store = ref
          .watch(storageProvider)
          .collection<ProjectCreationDraft>(
            '${_draftKeyPrefix}_$userId',
            toJson: (draft) => draft.toJson(),
            fromJson: ProjectCreationDraft.fromJson,
          );
      return ProjectCreationDraftNotifier(userId, store);
    });

class ProjectCreationDraftNotifier extends StateNotifier<ProjectCreationDraft> {
  ProjectCreationDraftNotifier(this.userId, this._store)
    : super(_load(userId, _store));

  final String userId;
  final CollectionStore<ProjectCreationDraft> _store;

  static ProjectCreationDraft _load(
    String userId,
    CollectionStore<ProjectCreationDraft> store,
  ) {
    final stored = store.readAll();
    if (stored.isNotEmpty && stored.first.ownerUserId == userId) {
      final draft = stored.first;
      if (draft.buildings.isNotEmpty) return draft;
      return draft.copyWith(
        buildings: [ProjectBuilding(id: _uuid.v4(), code: '', name: '')],
      );
    }
    return ProjectCreationDraft.empty(
      ownerUserId: userId,
      initialBuildingId: _uuid.v4(),
    );
  }

  Future<void> save(ProjectCreationDraft draft) async {
    final stamped = draft.copyWith(updatedAt: DateTime.now().toUtc());
    state = stamped;
    await _store.writeAll([stamped]);
  }

  Future<void> discard() async {
    state = ProjectCreationDraft.empty(
      ownerUserId: userId,
      initialBuildingId: _uuid.v4(),
    );
    await _store.writeAll(const []);
  }
}
