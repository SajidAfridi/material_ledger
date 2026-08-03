import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../controllers/yorks_v1_material_request_draft_controller.dart';
import '../models/yorks_v1_material_request.dart';
import '../models/yorks_v1_material_request_document.dart';
import '../repositories/storage.dart';
import 'yorks_v1_material_request_repository_provider.dart';

const _yorksV1MaterialRequestDraftKeyPrefix =
    'yorks_v1_material_request_drafts_v1';

class YorksV1MaterialRequestDraftKey {
  const YorksV1MaterialRequestDraftKey({
    required this.ownerAuthUserId,
    required this.draftId,
  });

  final String ownerAuthUserId;
  final String draftId;

  @override
  bool operator ==(Object other) =>
      other is YorksV1MaterialRequestDraftKey &&
      other.ownerAuthUserId == ownerAuthUserId &&
      other.draftId == draftId;

  @override
  int get hashCode => Object.hash(ownerAuthUserId, draftId);
}

final yorksV1MaterialRequestDraftControllerProvider =
    StateNotifierProvider.family<
      YorksV1MaterialRequestDraftController,
      YorksV1MaterialRequestDraftState,
      YorksV1MaterialRequestDraftKey
    >((ref, key) {
      final store = ref
          .watch(storageProvider)
          .collection<YorksV1MaterialRequestDraft>(
            '${_yorksV1MaterialRequestDraftKeyPrefix}_${key.ownerAuthUserId}',
            toJson: (draft) => draft.toJson(),
            fromJson: YorksV1MaterialRequestDraft.fromJson,
          );
      const uuid = Uuid();
      return YorksV1MaterialRequestDraftController(
        ownerAuthUserId: key.ownerAuthUserId,
        draftId: key.draftId,
        store: store,
        repository: ref.watch(yorksV1MaterialRequestRepositoryProvider),
        uuidFactory: uuid.v4,
      );
    });

final yorksV1MaterialRequestListProvider = FutureProvider.autoDispose
    .family<List<YorksV1MaterialRequest>, String?>((ref, projectId) {
      return ref
          .watch(yorksV1MaterialRequestRepositoryProvider)
          .listRequests(projectId: projectId);
    });

final yorksV1MaterialRequestDraftProjectsProvider =
    FutureProvider.autoDispose<List<YorksV1MaterialRequestProjectOption>>((
      ref,
    ) {
      return ref
          .watch(yorksV1MaterialRequestRepositoryProvider)
          .listDraftProjects();
    });

final yorksV1MaterialRequestScopesProvider = FutureProvider.autoDispose
    .family<List<YorksV1MaterialRequestScopeOption>, String>((ref, projectId) {
      return ref
          .watch(yorksV1MaterialRequestRepositoryProvider)
          .listScopes(projectId);
    });

final yorksV1MaterialRequestDetailProvider = FutureProvider.autoDispose
    .family<YorksV1MaterialRequest, String>((ref, requestId) {
      return ref
          .watch(yorksV1MaterialRequestRepositoryProvider)
          .getRequest(requestId);
    });

final yorksV1MaterialRequestDocumentProvider = FutureProvider.autoDispose
    .family<YorksV1MaterialRequestDocumentModel, String>((ref, requestId) {
      return ref
          .watch(yorksV1MaterialRequestRepositoryProvider)
          .getDocumentModel(requestId);
    });
