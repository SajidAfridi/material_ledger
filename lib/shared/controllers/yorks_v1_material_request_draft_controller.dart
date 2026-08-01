import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/yorks_v1_boq.dart';
import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_material_request.dart';
import '../repositories/collection_store.dart';
import '../repositories/yorks_v1_material_request_repository.dart';

enum YorksV1MaterialRequestDraftSyncStatus {
  local,
  saving,
  saved,
  submitting,
  submitted,
  conflict,
  failed,
}

class YorksV1MaterialRequestDraftState {
  const YorksV1MaterialRequestDraftState({
    required this.draft,
    this.status = YorksV1MaterialRequestDraftSyncStatus.local,
    this.errorCode,
  });

  final YorksV1MaterialRequestDraft draft;
  final YorksV1MaterialRequestDraftSyncStatus status;
  final YorksV1DomainErrorCode? errorCode;
}

/// Local-recovery plus connected-command controller. Editing remains private
/// on the device until a Save/Submit operation reaches the normalized server.
/// Only Submit is an idempotent critical workflow transition.
class YorksV1MaterialRequestDraftController
    extends StateNotifier<YorksV1MaterialRequestDraftState> {
  YorksV1MaterialRequestDraftController({
    required String ownerAuthUserId,
    required String draftId,
    required CollectionStore<YorksV1MaterialRequestDraft> store,
    required YorksV1MaterialRequestRepository repository,
    String Function()? uuidFactory,
  }) : _ownerAuthUserId = ownerAuthUserId,
       _draftId = draftId,
       _store = store,
       _repository = repository,
       _uuidFactory = uuidFactory ?? const Uuid().v4,
       super(
         YorksV1MaterialRequestDraftState(
           draft: _restoreOrEmpty(
             ownerAuthUserId: ownerAuthUserId,
             draftId: draftId,
             store: store,
             uuidFactory: uuidFactory ?? const Uuid().v4,
           ),
         ),
       );

  final String _ownerAuthUserId;
  final String _draftId;
  final CollectionStore<YorksV1MaterialRequestDraft> _store;
  final YorksV1MaterialRequestRepository _repository;
  final String Function() _uuidFactory;

  static YorksV1MaterialRequestDraft _restoreOrEmpty({
    required String ownerAuthUserId,
    required String draftId,
    required CollectionStore<YorksV1MaterialRequestDraft> store,
    required String Function() uuidFactory,
  }) {
    for (final draft in store.readAll()) {
      if (draft.id == draftId && draft.ownerAuthUserId == ownerAuthUserId) {
        if (draft.submissionIdempotencyKey.trim().isNotEmpty) return draft;
        return YorksV1MaterialRequestDraft(
          id: draft.id,
          ownerAuthUserId: draft.ownerAuthUserId,
          submissionIdempotencyKey: uuidFactory(),
          serverRecordVersion: draft.serverRecordVersion,
          projectId: draft.projectId,
          scopeId: draft.scopeId,
          title: draft.title,
          timing: draft.timing,
          scheduledDate: draft.scheduledDate,
          deliveryNote: draft.deliveryNote,
          lines: draft.lines,
          updatedAt: draft.updatedAt,
        );
      }
    }
    return YorksV1MaterialRequestDraft.empty(
      id: draftId,
      ownerAuthUserId: ownerAuthUserId,
      submissionIdempotencyKey: uuidFactory(),
    );
  }

  Future<void> update(
    YorksV1MaterialRequestDraft Function(YorksV1MaterialRequestDraft current)
    transform,
  ) => _replace(transform(state.draft));

  Future<void> setProject(String? projectId) => update(
    (draft) =>
        draft.copyWith(projectId: projectId, scopeId: null, lines: const []),
  );

  Future<void> setScope(String? scopeId) =>
      update((draft) => draft.copyWith(scopeId: scopeId));

  Future<void> setTitle(String? title) =>
      update((draft) => draft.copyWith(title: title));

  Future<void> setTiming(YorksV1MaterialRequestTiming timing) => update(
    (draft) => draft.copyWith(
      timing: timing,
      scheduledDate: timing == YorksV1MaterialRequestTiming.scheduled
          ? draft.scheduledDate
          : null,
    ),
  );

  Future<void> setScheduledDate(DateTime? scheduledDate) =>
      update((draft) => draft.copyWith(scheduledDate: scheduledDate));

  Future<void> setDeliveryNote(String? deliveryNote) =>
      update((draft) => draft.copyWith(deliveryNote: deliveryNote));

  Future<void> addCustomLine() async {
    final draft = state.draft;
    await _replace(
      draft.copyWith(
        lines: [
          ...draft.lines,
          YorksV1MaterialRequestLine(
            id: _uuidFactory(),
            displayOrder: draft.lines.length + 1,
            source: YorksV1MaterialRequestLineSource.custom,
            description: '',
            quantity: '',
            unit: '',
          ),
        ],
      ),
    );
  }

  Future<void> addBoqRows({
    required YorksV1BoqWorksheet worksheet,
    required Iterable<String> rowIds,
  }) async {
    final selected = rowIds.toSet();
    if (selected.isEmpty) return;
    final draft = state.draft;
    final additions = <YorksV1MaterialRequestLine>[];
    for (final row in worksheet.rows) {
      if (!selected.contains(row.id)) continue;
      additions.add(
        YorksV1MaterialRequestLine(
          id: _uuidFactory(),
          displayOrder: draft.lines.length + additions.length + 1,
          source: YorksV1MaterialRequestLineSource.boq,
          sourceBoqGroupId: worksheet.group.id,
          sourceBoqRowId: row.id,
          description: row.canonicalValues['description']?.toString() ?? '',
          brandOrigin: row.canonicalValues['brand_origin']?.toString(),
          quantity: row.canonicalValues['quantity']?.toString() ?? '',
          unit: row.canonicalValues['unit']?.toString() ?? '',
        ),
      );
    }
    if (additions.isEmpty) return;
    await _replace(draft.copyWith(lines: [...draft.lines, ...additions]));
  }

  Future<void> addExcelLines(
    Iterable<YorksV1MaterialRequestLine> imported,
  ) async {
    final draft = state.draft;
    final importedLines = imported.toList(growable: false);
    final additions = [
      for (var index = 0; index < importedLines.length; index++)
        YorksV1MaterialRequestLine(
          id: _uuidFactory(),
          displayOrder: draft.lines.length + index + 1,
          source: YorksV1MaterialRequestLineSource.excel,
          description: importedLines[index].description,
          brandOrigin: importedLines[index].brandOrigin,
          quantity: importedLines[index].quantity,
          unit: importedLines[index].unit,
        ),
    ];
    if (additions.isEmpty) return;
    await _replace(draft.copyWith(lines: [...draft.lines, ...additions]));
  }

  Future<void> updateLine(
    String lineId,
    YorksV1MaterialRequestLine Function(YorksV1MaterialRequestLine line)
    transform,
  ) async {
    final draft = state.draft;
    await _replace(
      draft.copyWith(
        lines: [
          for (final line in draft.lines)
            line.id == lineId ? transform(line) : line,
        ],
      ),
    );
  }

  Future<void> removeLine(String lineId) async {
    final remaining = state.draft.lines
        .where((line) => line.id != lineId)
        .toList(growable: false);
    await _replace(
      state.draft.copyWith(
        lines: [
          for (var index = 0; index < remaining.length; index++)
            YorksV1MaterialRequestLine(
              id: remaining[index].id,
              displayOrder: index + 1,
              source: remaining[index].source,
              description: remaining[index].description,
              brandOrigin: remaining[index].brandOrigin,
              quantity: remaining[index].quantity,
              unit: remaining[index].unit,
              sourceBoqGroupId: remaining[index].sourceBoqGroupId,
              sourceBoqRowId: remaining[index].sourceBoqRowId,
            ),
        ],
      ),
    );
  }

  Future<YorksV1MaterialRequest?> saveConnected() async {
    final draft = state.draft;
    if (!draft.canSubmitLocally) {
      state = YorksV1MaterialRequestDraftState(
        draft: draft,
        status: YorksV1MaterialRequestDraftSyncStatus.failed,
        errorCode: YorksV1DomainErrorCode.invalidInput,
      );
      return null;
    }
    state = YorksV1MaterialRequestDraftState(
      draft: draft,
      status: YorksV1MaterialRequestDraftSyncStatus.saving,
    );
    try {
      final saved = await _repository.saveDraft(draft.toSaveInput());
      final updated = draft.copyWith(
        serverRecordVersion: saved.recordVersion,
        updatedAt: DateTime.now().toUtc(),
      );
      await _persist(updated);
      state = YorksV1MaterialRequestDraftState(
        draft: updated,
        status: YorksV1MaterialRequestDraftSyncStatus.saved,
      );
      return saved;
    } on YorksV1DomainException catch (error) {
      state = YorksV1MaterialRequestDraftState(
        draft: draft,
        status: error.code == YorksV1DomainErrorCode.conflict
            ? YorksV1MaterialRequestDraftSyncStatus.conflict
            : YorksV1MaterialRequestDraftSyncStatus.failed,
        errorCode: error.code,
      );
      return null;
    }
  }

  Future<YorksV1MaterialRequest?> submit() async {
    final draft = state.draft;
    if (!draft.canSubmitLocally) {
      state = YorksV1MaterialRequestDraftState(
        draft: draft,
        status: YorksV1MaterialRequestDraftSyncStatus.failed,
        errorCode: YorksV1DomainErrorCode.invalidInput,
      );
      return null;
    }
    state = YorksV1MaterialRequestDraftState(
      draft: draft,
      status: YorksV1MaterialRequestDraftSyncStatus.submitting,
    );
    try {
      // A connected draft save supplies the exact version that the submit RPC
      // locks. No client-side transition is shown before this second command.
      final saved = await _repository.saveDraft(draft.toSaveInput());
      final submitted = await _repository.submit(
        YorksV1SubmitMaterialRequestInput(
          requestId: draft.id,
          expectedVersion: saved.recordVersion,
          idempotencyKey: draft.submissionIdempotencyKey,
        ),
      );
      await discardLocal();
      state = YorksV1MaterialRequestDraftState(
        draft: state.draft,
        status: YorksV1MaterialRequestDraftSyncStatus.submitted,
      );
      return submitted;
    } on YorksV1DomainException catch (error) {
      state = YorksV1MaterialRequestDraftState(
        draft: draft,
        status: error.code == YorksV1DomainErrorCode.conflict
            ? YorksV1MaterialRequestDraftSyncStatus.conflict
            : YorksV1MaterialRequestDraftSyncStatus.failed,
        errorCode: error.code,
      );
      return null;
    }
  }

  Future<void> discardLocal() async {
    final all = _store
        .readAll()
        .where(
          (draft) =>
              draft.id != _draftId || draft.ownerAuthUserId != _ownerAuthUserId,
        )
        .toList(growable: false);
    await _store.writeAll(all);
  }

  Future<void> _replace(YorksV1MaterialRequestDraft draft) async {
    final updated = draft.copyWith(updatedAt: DateTime.now().toUtc());
    await _persist(updated);
    state = YorksV1MaterialRequestDraftState(draft: updated);
  }

  Future<void> _persist(YorksV1MaterialRequestDraft draft) async {
    final all = _store.readAll();
    final replaced = <YorksV1MaterialRequestDraft>[];
    var found = false;
    for (final stored in all) {
      if (stored.id == _draftId && stored.ownerAuthUserId == _ownerAuthUserId) {
        replaced.add(draft);
        found = true;
      } else {
        replaced.add(stored);
      }
    }
    if (!found) replaced.add(draft);
    await _store.writeAll(replaced);
  }
}
