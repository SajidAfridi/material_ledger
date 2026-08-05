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
  Future<void> _persistQueue = Future<void>.value();
  bool _connectedCommandInFlight = false;

  /// Read-only snapshot for UI callbacks that need to guard a deferred
  /// default (for example the Common scope) against a newer project choice.
  YorksV1MaterialRequestDraft get currentDraft => state.draft;

  /// Last connected-operation error exposed without making widgets reach into
  /// StateNotifier's protected [state] member.
  YorksV1DomainErrorCode? get lastErrorCode => state.errorCode;

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

  /// Changes the project only when the caller has explicitly confirmed that
  /// existing BOQ, Excel and custom rows may be removed.  This makes the
  /// destructive project/scope reset visible to the presentation layer.
  Future<bool> setProject(
    String? projectId, {
    bool discardExistingLines = false,
  }) async {
    final draft = state.draft;
    if (projectId == draft.projectId) return true;
    if (draft.lines.isNotEmpty && !discardExistingLines) return false;
    await update(
      (current) => current.copyWith(
        projectId: projectId,
        scopeId: null,
        lines: const [],
      ),
    );
    return true;
  }

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

  /// Restores a server-saved draft when it is opened from the request queue
  /// after local recovery has no copy. This is deliberately one-way and only
  /// applies to an untouched local draft; unsaved local edits must never be
  /// overwritten by a later refresh.
  Future<void> hydrateFromServer(YorksV1MaterialRequest request) async {
    final current = state.draft;
    if (request.id != _draftId ||
        !request.state.isDraft ||
        current.serverRecordVersion != 0 ||
        current.updatedAt.millisecondsSinceEpoch != 0) {
      return;
    }
    final hydrated = YorksV1MaterialRequestDraft(
      id: current.id,
      ownerAuthUserId: current.ownerAuthUserId,
      submissionIdempotencyKey: current.submissionIdempotencyKey,
      serverRecordVersion: request.recordVersion,
      projectId: request.projectId,
      scopeId: request.scopeId,
      title: request.title,
      timing: request.timing,
      scheduledDate: request.scheduledDate,
      deliveryNote: request.deliveryNote,
      lines: request.lines,
      updatedAt: request.updatedAt,
    );
    state = YorksV1MaterialRequestDraftState(
      draft: hydrated,
      status: YorksV1MaterialRequestDraftSyncStatus.saved,
    );
    await _persist(hydrated);
  }

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
            // Keep the editor immediately usable.  Engineers can still pick
            // another controlled unit from the row dropdown.
            unit: 'Nos',
          ),
        ],
      ),
    );
  }

  Future<void> addBlankLine() => addCustomLine();

  /// Inserts a directly editable copy of the last line without retaining a
  /// BOQ source pointer. This keeps a Similar Row useful for repeated items
  /// while preventing an accidental second request against the same source
  /// snapshot.
  Future<void> addSimilarLine() async {
    final draft = state.draft;
    final source = draft.lines.lastOrNull;
    if (source == null) return addBlankLine();
    await _replace(
      draft.copyWith(
        lines: [
          ...draft.lines,
          YorksV1MaterialRequestLine(
            id: _uuidFactory(),
            displayOrder: draft.lines.length + 1,
            source: YorksV1MaterialRequestLineSource.custom,
            description: source.description,
            brandOrigin: source.brandOrigin,
            size: source.size,
            // Model/tag and quantity identify the original equipment; a
            // Similar MR row must not accidentally request a second unit.
            quantity: '',
            unit: source.unit,
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
    final existingSourceRows = draft.lines
        .map((line) => line.sourceBoqRowId)
        .whereType<String>()
        .toSet();
    final additions = <YorksV1MaterialRequestLine>[];
    for (final row in worksheet.rows) {
      if (!selected.contains(row.id)) continue;
      // A BOQ row is a controlled source. Adding it twice must not silently
      // create a second request line or inflate the requested quantity.
      if (existingSourceRows.contains(row.id)) continue;
      final tag = _boqValue(
        worksheet,
        row,
        YorksV1BoqCanonicalField.equipmentTag,
        headingPattern: r'tag|equipment\s*tag|fan\s*tag',
      );
      final description = _boqValue(
        worksheet,
        row,
        YorksV1BoqCanonicalField.description,
        headingPattern: r'description|serving\s*area|location|equipment|item',
      );
      final explicitQuantity = _canonicalValue(
        worksheet,
        row,
        YorksV1BoqCanonicalField.quantity,
      );
      final hasSuggestedQuantity = explicitQuantity.isEmpty && tag.isNotEmpty;
      final rawModel = _boqValue(
        worksheet,
        row,
        YorksV1BoqCanonicalField.model,
        headingPattern: r'(^|\b)(model|fan\s*model)(\b|$)',
      );
      additions.add(
        YorksV1MaterialRequestLine(
          id: _uuidFactory(),
          displayOrder: draft.lines.length + additions.length + 1,
          source: YorksV1MaterialRequestLineSource.boq,
          sourceBoqGroupId: worksheet.group.id,
          sourceBoqRowId: row.id,
          description: _composeDescription(tag: tag, context: description),
          brandOrigin: _boqValue(
            worksheet,
            row,
            YorksV1BoqCanonicalField.brandOrigin,
            headingPattern: r'brand|make|manufacturer|origin',
          ),
          size: _boqValue(
            worksheet,
            row,
            YorksV1BoqCanonicalField.size,
            headingPattern: r'size|dimension',
          ),
          // A tag identifies equipment but is not a manufacturer model. Keep
          // it separate so PDFs and Procurement screens do not render the
          // same value twice as both Model and Tag.
          model: rawModel.isNotEmpty ? rawModel : null,
          equipmentTag: tag.isEmpty ? null : tag,
          planningModelTag: _canonicalValue(
            worksheet,
            row,
            YorksV1BoqCanonicalField.planningModelTag,
            nullable: true,
          ),
          quantity: hasSuggestedQuantity ? '1' : explicitQuantity,
          quantityIsSuggested: hasSuggestedQuantity,
          unit:
              _canonicalValue(
                worksheet,
                row,
                YorksV1BoqCanonicalField.unit,
              ).trim().isEmpty
              ? 'Nos'
              : _canonicalValue(worksheet, row, YorksV1BoqCanonicalField.unit),
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
          size: importedLines[index].size,
          model: importedLines[index].model,
          equipmentTag: importedLines[index].equipmentTag,
          planningModelTag: importedLines[index].planningModelTag,
          quantityIsSuggested: importedLines[index].quantityIsSuggested,
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
              size: remaining[index].size,
              model: remaining[index].model,
              equipmentTag: remaining[index].equipmentTag,
              planningModelTag: remaining[index].planningModelTag,
              quantityIsSuggested: remaining[index].quantityIsSuggested,
              quantity: remaining[index].quantity,
              unit: remaining[index].unit,
              sourceBoqGroupId: remaining[index].sourceBoqGroupId,
              sourceBoqRowId: remaining[index].sourceBoqRowId,
            ),
        ],
      ),
    );
  }

  /// Saves the current draft without pretending that an incomplete draft was
  /// accepted by the server.  Incomplete input is still durable on this
  /// device and can be reopened and edited later; complete input is synced
  /// through the versioned draft RPC.
  Future<YorksV1MaterialRequest?> saveDraft() async {
    final draft = state.draft;
    if (!draft.canSubmitLocally) {
      await _persist(draft);
      state = YorksV1MaterialRequestDraftState(
        draft: draft,
        status: YorksV1MaterialRequestDraftSyncStatus.local,
      );
      return null;
    }
    return saveConnected();
  }

  Future<YorksV1MaterialRequest?> saveConnected() async {
    if (_connectedCommandInFlight) return null;
    _connectedCommandInFlight = true;
    try {
      return await _saveConnected();
    } finally {
      _connectedCommandInFlight = false;
    }
  }

  Future<YorksV1MaterialRequest?> _saveConnected() async {
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
    } catch (error) {
      state = YorksV1MaterialRequestDraftState(
        draft: draft,
        status: YorksV1MaterialRequestDraftSyncStatus.failed,
        errorCode: YorksV1DomainErrorCode.backendUnavailable,
      );
      return null;
    }
  }

  Future<YorksV1MaterialRequest?> submit() async {
    if (_connectedCommandInFlight) return null;
    _connectedCommandInFlight = true;
    try {
      return await _submitConnected();
    } finally {
      _connectedCommandInFlight = false;
    }
  }

  Future<YorksV1MaterialRequest?> _submitConnected() async {
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
    YorksV1MaterialRequest? submitted;
    try {
      submitted = await _repository.saveAndSubmit(draft);
    } on YorksV1DomainException catch (error) {
      var nextDraft = draft;
      final shouldRefreshIdempotency =
          error.code != YorksV1DomainErrorCode.conflict &&
          error.serverCode != null &&
          (error.serverCode == '22023' || error.serverCode == '55P03');
      if (shouldRefreshIdempotency) {
        nextDraft = draft.copyWith(
          submissionIdempotencyKey: _uuidFactory(),
          updatedAt: DateTime.now().toUtc(),
        );
        state = YorksV1MaterialRequestDraftState(
          draft: nextDraft,
          status: YorksV1MaterialRequestDraftSyncStatus.failed,
          errorCode: error.code,
        );
        await _persist(nextDraft);
      }
      state = YorksV1MaterialRequestDraftState(
        draft: nextDraft,
        status: error.code == YorksV1DomainErrorCode.conflict
            ? YorksV1MaterialRequestDraftSyncStatus.conflict
            : YorksV1MaterialRequestDraftSyncStatus.failed,
        errorCode: error.code,
      );
      return null;
    } catch (error) {
      state = YorksV1MaterialRequestDraftState(
        draft: draft,
        status: YorksV1MaterialRequestDraftSyncStatus.failed,
        errorCode: YorksV1DomainErrorCode.backendUnavailable,
      );
      return null;
    }

    // The server transition has succeeded. Local cleanup is best effort and
    // must never turn an authoritative submission into a false failure state
    // (for example when browser storage is unavailable or a late draft write
    // is still draining).
    try {
      await discardLocal();
    } catch (_) {
      // The submitted server record remains authoritative; the next refresh
      // can safely reconcile any stale local recovery copy.
    }
    state = YorksV1MaterialRequestDraftState(
      draft: state.draft,
      status: YorksV1MaterialRequestDraftSyncStatus.submitted,
    );
    return submitted;
  }

  Future<void> discardLocal() async {
    // Complete edits that may still be flushing from a text field before the
    // confirmed submit removes the recoverable draft. Without this barrier a
    // late keystroke write could recreate a draft after submission.
    await _persistQueue;
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
    final updated = draft.copyWith(
      submissionIdempotencyKey: _uuidFactory(),
      updatedAt: DateTime.now().toUtc(),
    );
    // Update the in-memory state before awaiting device storage. Text-field
    // callbacks are intentionally fire-and-forget; waiting here made the
    // submit button observe the previous line values when a user typed and
    // submitted quickly.
    state = YorksV1MaterialRequestDraftState(draft: updated);
    await _persist(updated);
  }

  Future<void> _persist(YorksV1MaterialRequestDraft draft) async {
    final operation = _persistQueue.then((_) async {
      final all = _store.readAll();
      final replaced = <YorksV1MaterialRequestDraft>[];
      var found = false;
      for (final stored in all) {
        if (stored.id == _draftId &&
            stored.ownerAuthUserId == _ownerAuthUserId) {
          replaced.add(draft);
          found = true;
        } else {
          replaced.add(stored);
        }
      }
      if (!found) replaced.add(draft);
      await _store.writeAll(replaced);
    });
    // Keep the queue usable after an individual local-storage failure while
    // still returning the original error to the caller.
    _persistQueue = operation.catchError((_) {});
    await operation;
  }

  static String _canonicalValue(
    YorksV1BoqWorksheet worksheet,
    YorksV1BoqRow row,
    YorksV1BoqCanonicalField field, {
    bool nullable = false,
  }) {
    final value = row.canonicalValues[field.wireValue];
    if (value != null && '$value'.trim().isNotEmpty) return '$value'.trim();
    final column = worksheet.columns
        .where((item) => item.canonicalField == field)
        .firstOrNull;
    final fallback = column == null ? null : row.valueFor(column.id);
    final text = fallback?.toString().trim() ?? '';
    return nullable && text.isEmpty ? '' : text;
  }

  static String _boqValue(
    YorksV1BoqWorksheet worksheet,
    YorksV1BoqRow row,
    YorksV1BoqCanonicalField field, {
    required String headingPattern,
  }) {
    final canonical = _canonicalValue(worksheet, row, field, nullable: true);
    if (canonical.isNotEmpty) return canonical;
    final matcher = RegExp(headingPattern, caseSensitive: false);
    for (final column in worksheet.columns) {
      if (!matcher.hasMatch(column.heading)) continue;
      final value = row.valueFor(column.id)?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String _composeDescription({
    required String tag,
    required String context,
  }) {
    if (tag.isEmpty) return context;
    if (context.isEmpty || context.toLowerCase() == tag.toLowerCase()) {
      return tag;
    }
    return '$tag — $context';
  }
}
