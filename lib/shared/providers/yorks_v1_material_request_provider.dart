import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../controllers/yorks_v1_material_request_draft_controller.dart';
import '../models/yorks_v1_material_request.dart';
import '../models/yorks_v1_material_request_document.dart';
import '../models/yorks_v1_role.dart';
import '../repositories/storage.dart';
import 'yorks_v1_material_request_repository_provider.dart';
import 'language_provider.dart';

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

/// Refresh signal for the overview action queue.
///
/// V1 workflow transitions are still committed only by trusted RPCs. This
/// provider merely asks the same RLS-protected projection to refresh when a
/// notification arrives. The short polling fallback keeps the badge useful on
/// deployments where the Supabase Realtime publication has not been enabled
/// yet (and is disposed as soon as the overview is left).
final yorksV1MaterialRequestLiveRefreshProvider = Provider.autoDispose<void>((
  ref,
) {
  ref.watch(authSessionProvider);
  final client = ref.watch(supabaseClientProvider);
  final authUserId = client?.auth.currentUser?.id;
  if (client == null || authUserId == null) return;

  void refresh() => ref.invalidate(yorksV1MaterialRequestListProvider);

  final timer = Timer.periodic(const Duration(seconds: 10), (_) => refresh());
  final channel = client
      .channel('yorks-v1-action-indicator:$authUserId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'v1_notifications',
        callback: (_) => refresh(),
      )
      .subscribe();

  ref.onDispose(() {
    timer.cancel();
    unawaited(client.removeChannel(channel));
  });
});

/// Whether a request belongs in the signed-in role's action queue.
///
/// The owner role comes from the server projection, never from an editable
/// client field. Admin sees the active workflow queue for oversight; ordinary
/// roles see only requests currently owned by their exact V1 role.
bool yorksV1MaterialRequestNeedsAction(
  YorksV1MaterialRequest request,
  YorksV1Role? role,
) {
  if (role == null || request.state.isDraft) return false;
  if (request.state == YorksV1MaterialRequestState.received ||
      request.state == YorksV1MaterialRequestState.closed ||
      request.state == YorksV1MaterialRequestState.cancelled) {
    return false;
  }
  if (role == YorksV1Role.admin) return true;
  return request.currentActionOwnerRole == role.claimValue;
}

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
