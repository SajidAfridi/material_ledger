import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../controllers/yorks_v1_project_creation_draft_controller.dart';
import '../controllers/yorks_v1_legacy_project_creation_draft_controller.dart';
import '../models/yorks_v1_project_creation_draft.dart';
import '../repositories/yorks_v1_project_draft_storage_platform.dart';
import '../repositories/yorks_v1_project_draft_store.dart';
import '../services/analytics_service.dart';
import '../repositories/storage.dart';
import 'language_provider.dart';

/// Exact configured backend identity, never an editable project field. Tests
/// can override this to exercise staging/production isolation on one device.
final yorksV1ProjectDraftBackendIdentityProvider = Provider<String>((ref) {
  const configured = String.fromEnvironment('SUPABASE_URL');
  if (configured.trim().isEmpty) return 'local';
  return configured.trim().replaceFirst(RegExp(r'/+$'), '');
});

final yorksV1ProjectDraftAtomicStorageProvider =
    Provider<ProjectDraftAtomicStorage>(
      (ref) =>
          createProjectDraftAtomicStorage(ref.watch(sharedPreferencesProvider)),
    );

String yorksV1ProjectDraftStorageKey({
  required String backendIdentity,
  required String ownerAuthUserId,
  required YorksV1ProjectDraftMode mode,
  String? projectId,
}) {
  final context = jsonEncode([
    backendIdentity,
    ownerAuthUserId,
    mode.name,
    projectId,
  ]);
  return 'yorks_project_setup_v2_${sha256.convert(utf8.encode(context))}';
}

final yorksV1ProjectSetupCreationDraftProvider =
    StateNotifierProvider.family<
      YorksV1ProjectCreationDraftController,
      YorksV1ProjectCreationDraft,
      String
    >(
      (ref, ownerAuthUserId) => _controller(
        ref,
        ownerAuthUserId: ownerAuthUserId,
        mode: YorksV1ProjectDraftMode.create,
      ),
    );

class YorksV1ProjectEditDraftContext {
  const YorksV1ProjectEditDraftContext({
    required this.ownerAuthUserId,
    required this.projectId,
  });
  final String ownerAuthUserId;
  final String projectId;

  @override
  bool operator ==(Object other) =>
      other is YorksV1ProjectEditDraftContext &&
      other.ownerAuthUserId == ownerAuthUserId &&
      other.projectId == projectId;
  @override
  int get hashCode => Object.hash(ownerAuthUserId, projectId);
}

final yorksV1ProjectEditDraftProvider =
    StateNotifierProvider.family<
      YorksV1ProjectCreationDraftController,
      YorksV1ProjectCreationDraft,
      YorksV1ProjectEditDraftContext
    >(
      (ref, context) => _controller(
        ref,
        ownerAuthUserId: context.ownerAuthUserId,
        mode: YorksV1ProjectDraftMode.edit,
        projectId: context.projectId,
      ),
    );

YorksV1ProjectCreationDraftController _controller(
  Ref ref, {
  required String ownerAuthUserId,
  required YorksV1ProjectDraftMode mode,
  String? projectId,
}) {
  final backend = ref.watch(yorksV1ProjectDraftBackendIdentityProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  const uuid = Uuid();
  return YorksV1ProjectCreationDraftController(
    ownerAuthUserId: ownerAuthUserId,
    backendIdentity: backend,
    mode: mode,
    projectId: projectId,
    storage: ref.watch(yorksV1ProjectDraftAtomicStorageProvider),
    storageKey: yorksV1ProjectDraftStorageKey(
      backendIdentity: backend,
      ownerAuthUserId: ownerAuthUserId,
      mode: mode,
      projectId: projectId,
    ),
    // This raw read bypasses legacy row-skipping. Unverified data is preserved
    // for explicit reconciliation instead of silently restored to a backend.
    legacyRaw: mode == YorksV1ProjectDraftMode.create
        ? prefs.getString('yorks_v1_project_creation_draft_v1_$ownerAuthUserId')
        : null,
    idempotencyKeyFactory: uuid.v4,
    analytics: ref.watch(analyticsServiceProvider),
  );
}

/// Accepted R35 recovery stays on its original key while the new setup flag is
/// off. It does not unexpectedly quarantine existing users' local input.
final yorksV1ProjectCreationDraftProvider =
    StateNotifierProvider.family<
      YorksV1LegacyProjectCreationDraftController,
      YorksV1ProjectCreationDraft,
      String
    >((ref, ownerAuthUserId) {
      final store = ref
          .watch(storageProvider)
          .collection<YorksV1ProjectCreationDraft>(
            'yorks_v1_project_creation_draft_v1_$ownerAuthUserId',
            toJson: (draft) => draft.toJson(),
            fromJson: YorksV1ProjectCreationDraft.fromJson,
          );
      const uuid = Uuid();
      return YorksV1LegacyProjectCreationDraftController(
        ownerAuthUserId: ownerAuthUserId,
        store: store,
        idempotencyKeyFactory: uuid.v4,
      );
    });
