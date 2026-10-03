import 'dart:convert';

import '../models/yorks_v1_project_setup_operation.dart';
import 'yorks_v1_project_draft_store.dart';

typedef YorksV1ProjectSetupOwnedTransaction =
    Future<T> Function<T>(T Function(ProjectDraftAtomicTransaction tx) work);

/// Journal writes share the proposal's atomic writer fence. The records have
/// separate keys so retiring a proposal never deletes unresolved follow-up.
class YorksV1ProjectSetupJournalStore {
  const YorksV1ProjectSetupJournalStore({
    required this.storage,
    required this.journalKey,
    required this.backendIdentity,
    required this.ownerAuthUserId,
    required this.draftId,
    required this.atomicOwned,
    this.latestOperationKey,
    this.expectedMode,
    this.projectId,
  });

  final ProjectDraftAtomicStorage storage;
  final String journalKey;
  final String backendIdentity;
  final String ownerAuthUserId;
  final String draftId;
  final String? latestOperationKey;
  final YorksV1ProjectSetupMode? expectedMode;
  final String? projectId;
  final YorksV1ProjectSetupOwnedTransaction atomicOwned;

  YorksV1ProjectSetupOperation? read() => _readFrom(storage.read);

  Future<YorksV1ProjectSetupOperation> change(
    YorksV1ProjectSetupOperation Function(YorksV1ProjectSetupOperation? current)
    transform,
  ) => atomicOwned((tx) {
    final current = _readFrom(tx.read);
    final next = transform(current);
    _verifyScope(next);
    if (current == null && next.draftId != draftId) {
      throw const FormatException('Project operation draft mismatch');
    }
    final key = next.draftId == draftId
        ? journalKey
        : '${journalKey.substring(0, journalKey.lastIndexOf(':journal:'))}:journal:${next.draftId}';
    tx.write(key, jsonEncode(next.toJson()));
    if (latestOperationKey != null) {
      tx.write(latestOperationKey!, jsonEncode({'journal_key': key}));
    }
    return next;
  });

  YorksV1ProjectSetupOperation? _readFrom(String? Function(String) read) {
    final current = _decode(read(journalKey), expectedDraftId: draftId);
    if (current != null) return current;
    final pointer = latestOperationKey == null
        ? null
        : read(latestOperationKey!);
    if (pointer == null) return null;
    final key = (jsonDecode(pointer) as Map)['journal_key'] as String;
    final prefix = journalKey.substring(0, journalKey.lastIndexOf(':journal:'));
    if (!key.startsWith('$prefix:journal:')) {
      throw const FormatException('Project operation pointer scope mismatch');
    }
    final prior = _decode(
      read(key),
      expectedDraftId: key.substring('$prefix:journal:'.length),
    );
    if (prior == null) {
      throw const FormatException('Project operation recovery record missing');
    }
    // A single unresolved follow-up stays discoverable after a proposal is
    // retired/replaced. This does not create a general multi-draft catalogue.
    return prior.hasUnresolvedCommand ||
            prior.filesPending ||
            (!prior.cleanupComplete && prior.coreSucceeded)
        ? prior
        : null;
  }

  YorksV1ProjectSetupOperation? _decode(
    String? raw, {
    String? expectedDraftId,
  }) {
    if (raw == null) return null;
    final decoded = YorksV1ProjectSetupOperation.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
    _verifyScope(decoded);
    if (expectedDraftId != null && decoded.draftId != expectedDraftId) {
      throw const FormatException('Project operation draft mismatch');
    }
    return decoded;
  }

  void _verifyScope(YorksV1ProjectSetupOperation operation) {
    if (operation.backendIdentity != backendIdentity ||
        operation.ownerAuthUserId != ownerAuthUserId ||
        (expectedMode != null && operation.mode != expectedMode) ||
        (operation.mode == YorksV1ProjectSetupMode.create &&
            operation.core.kind != YorksV1ProjectSetupCommandKind.create) ||
        (operation.mode == YorksV1ProjectSetupMode.edit &&
            (operation.core.kind != YorksV1ProjectSetupCommandKind.update ||
                (projectId != null &&
                    operation.core.payload['project_id'] != projectId))) ||
        (operation.activation != null &&
            operation.activation!.payload['project_id'] !=
                operation.core.project?.id)) {
      throw const FormatException('Project operation scope mismatch');
    }
  }
}
