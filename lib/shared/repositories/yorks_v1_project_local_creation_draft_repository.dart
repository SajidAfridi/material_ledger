import 'dart:convert';

import '../models/yorks_v1_project_creation_draft.dart';
import '../models/yorks_v1_project_local_creation_draft.dart';
import '../models/yorks_v1_project_setup_operation.dart';
import 'yorks_v1_project_draft_store.dart';
import 'yorks_v1_project_setup_journal_store.dart';

/// Read-only discovery of the one supported local Create slot. Reading never
/// claims a writer, creates IDs, repairs receipts, migrates or quarantines data.
class YorksV1ProjectLocalCreationDraftRepository {
  const YorksV1ProjectLocalCreationDraftRepository(this.storage);

  final ProjectDraftAtomicStorage storage;

  YorksV1ProjectLocalCreationDraftState read({
    required String storageKey,
    required String ownerAuthUserId,
    required String backendIdentity,
    String? legacyRaw,
  }) {
    try {
      final reader = _ReadOnlyDraftStorage(storage);
      final raw = reader.read(storageKey);
      YorksV1ProjectCreationDraft? draft;
      var retired = false;
      if (raw != null) {
        final record = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        if (record['recordVersion'] != 1 ||
            record['retired'] is! bool ||
            record['writerEpoch'] is! int ||
            record['ownerWriterId'] != null &&
                record['ownerWriterId'] is! String ||
            record['draft'] is! Map) {
          throw const FormatException('Unsupported local project record');
        }
        final json = Map<String, dynamic>.from(record['draft'] as Map);
        draft = YorksV1ProjectCreationDraft.fromJson(json);
        if (draft.ownerAuthUserId != ownerAuthUserId ||
            draft.backendIdentity != backendIdentity ||
            draft.mode != YorksV1ProjectDraftMode.create ||
            draft.projectId != null ||
            draft.draftId.isEmpty ||
            draft.creationIdempotencyKey.isEmpty ||
            draft.revision < 0 ||
            draft.acknowledgedRevision != draft.revision ||
            draft.writerEpoch < 0 ||
            record['writerEpoch'] != draft.writerEpoch ||
            json['updatedAt'] is! String ||
            DateTime.tryParse(json['updatedAt'] as String) == null) {
          throw const FormatException(
            'Local project scope or revision mismatch',
          );
        }
        retired = record['retired'] as bool;
      }

      // An exact current journal has priority, matching setup restoration. A
      // historical confirmed pointer never hides a different active proposal.
      var operation = draft == null
          ? null
          : _operation(
              storageKey,
              draft.draftId,
              ownerAuthUserId,
              backendIdentity,
            );
      if (operation == null) {
        final pointerRaw = reader.read('$storageKey:latest_operation');
        if (pointerRaw != null) {
          final pointer = jsonDecode(pointerRaw) as Map;
          final key = pointer['journal_key'];
          final prefix = '$storageKey:journal:';
          if (key is! String ||
              !key.startsWith(prefix) ||
              key.length == prefix.length) {
            throw const FormatException('Local project journal scope mismatch');
          }
          operation = _operation(
            storageKey,
            key.substring(prefix.length),
            ownerAuthUserId,
            backendIdentity,
          );
          if (operation == null) {
            throw const FormatException(
              'Missing local project recovery record',
            );
          }
        }
      }
      final matchingOperation =
          operation != null && operation.draftId == draft?.draftId;
      if (matchingOperation && operation.coreSucceeded) {
        return const YorksV1ProjectLocalCreationDraftState();
      }
      final uncertain =
          operation != null &&
          !operation.coreSucceeded &&
          operation.core.status.unresolved;
      final pendingIntent =
          operation != null &&
          !operation.coreSucceeded &&
          (matchingOperation || uncertain || operation.filesPending);
      if (draft == null || retired || !_meaningful(draft)) {
        if (pendingIntent ||
            reader.read('$storageKey:quarantine') != null ||
            legacyRaw != null && legacyRaw.isNotEmpty && legacyRaw != '[]') {
          return YorksV1ProjectLocalCreationDraftState(
            status: YorksV1ProjectLocalCreationDraftStatus.recoveryRequired,
            outcomeUncertain: uncertain,
          );
        }
        return const YorksV1ProjectLocalCreationDraftState();
      }
      return YorksV1ProjectLocalCreationDraftState(
        status: YorksV1ProjectLocalCreationDraftStatus.saved,
        summary: YorksV1ProjectLocalCreationDraftSummary(
          draftId: draft.draftId,
          reference: draft.reference,
          name: draft.name,
          currentStage: draft.currentStage,
          savedAt: draft.updatedAt,
          acknowledgedRevision: draft.acknowledgedRevision,
        ),
        outcomeUncertain: uncertain,
      );
    } on ProjectDraftStorageException {
      return const YorksV1ProjectLocalCreationDraftState(
        status: YorksV1ProjectLocalCreationDraftStatus.unavailable,
      );
    } catch (_) {
      // Unsupported/invalid bytes remain in place for the guarded recovery
      // route. A portfolio projection must not silently omit or reinterpret it.
      return const YorksV1ProjectLocalCreationDraftState(
        status: YorksV1ProjectLocalCreationDraftStatus.recoveryRequired,
      );
    }
  }

  YorksV1ProjectSetupOperation? _operation(
    String key,
    String draftId,
    String owner,
    String backend,
  ) => YorksV1ProjectSetupJournalStore(
    storage: _ReadOnlyDraftStorage(storage),
    journalKey: '$key:journal:$draftId',
    backendIdentity: backend,
    ownerAuthUserId: owner,
    draftId: draftId,
    expectedMode: YorksV1ProjectSetupMode.create,
    atomicOwned: <T>(_) => throw StateError('Read-only local project summary'),
  ).read();

  bool _meaningful(YorksV1ProjectCreationDraft draft) {
    final raw = Map<String, dynamic>.from(draft.rawEditorState)
      ..remove('sectionContext')
      ..remove('contactsExpanded')
      ..remove('buildingLocalId');
    return draft.copyWith(rawEditorState: raw).hasRecoverableContent;
  }
}

/// Browser storage denial is an availability failure, not evidence of corrupt
/// recovery bytes. Keep decoding/scope failures separate from unreadable data.
class _ReadOnlyDraftStorage implements ProjectDraftAtomicStorage {
  const _ReadOnlyDraftStorage(this.inner);
  final ProjectDraftAtomicStorage inner;

  @override
  String? read(String key) {
    try {
      return inner.read(key);
    } catch (_) {
      throw const ProjectDraftStorageException('read_unavailable');
    }
  }

  @override
  bool get supportsAtomicOwnership => false;

  @override
  Future<T> transaction<T>(
    String lockKey,
    T Function(ProjectDraftAtomicTransaction) work,
  ) => throw StateError('Read-only local project discovery');
}
