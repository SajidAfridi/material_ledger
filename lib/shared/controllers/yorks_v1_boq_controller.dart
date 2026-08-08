import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/yorks_v1_boq.dart';
import '../models/yorks_v1_boq_workbook.dart';
import '../models/yorks_v1_domain_error.dart';
import '../repositories/yorks_v1_boq_repository.dart';

enum YorksV1BoqSyncStatus {
  loading,
  ready,
  dirty,
  saving,
  saved,
  conflict,
  failed,
}

class YorksV1BoqWorksheetState {
  const YorksV1BoqWorksheetState({
    this.status = YorksV1BoqSyncStatus.loading,
    this.worksheet,
    this.errorCode,
  });

  final YorksV1BoqSyncStatus status;
  final YorksV1BoqWorksheet? worksheet;
  final YorksV1DomainErrorCode? errorCode;

  bool get hasUnsavedChanges => status == YorksV1BoqSyncStatus.dirty;
  bool get isReadOnly => worksheet?.group.isArchived ?? false;
}

/// Client-side BOQ editor state.  The server remains the authority: this
/// controller only stages a worksheet snapshot and commits it via a
/// version-checked, idempotent RPC when the user saves.
class YorksV1BoqWorksheetController
    extends StateNotifier<YorksV1BoqWorksheetState> {
  YorksV1BoqWorksheetController({
    required String groupId,
    required YorksV1BoqRepository repository,
    String Function()? uuidFactory,
  }) : _groupId = groupId,
       _repository = repository,
       _uuidFactory = uuidFactory ?? const Uuid().v4,
       super(const YorksV1BoqWorksheetState());

  final String _groupId;
  final YorksV1BoqRepository _repository;
  final String Function() _uuidFactory;

  Future<void> load() async {
    state = const YorksV1BoqWorksheetState(
      status: YorksV1BoqSyncStatus.loading,
    );
    try {
      final worksheet = await _repository.getWorksheet(_groupId);
      state = YorksV1BoqWorksheetState(
        status: YorksV1BoqSyncStatus.ready,
        worksheet: worksheet,
      );
    } on YorksV1DomainException catch (error) {
      state = YorksV1BoqWorksheetState(
        status: YorksV1BoqSyncStatus.failed,
        errorCode: error.code,
      );
    }
  }

  void updateTitle(String value) {
    final worksheet = _editableWorksheet();
    _replace(
      worksheet.copyWith(
        group: YorksV1BoqGroup(
          id: worksheet.group.id,
          projectId: worksheet.group.projectId,
          name: worksheet.group.name,
          worksheetTitle: value,
          displayOrder: worksheet.group.displayOrder,
          isCustom: worksheet.group.isCustom,
          isArchived: worksheet.group.isArchived,
          version: worksheet.group.version,
          rowCount: worksheet.group.rowCount,
          columnCount: worksheet.group.columnCount,
          updatedAt: worksheet.group.updatedAt,
          scopeId: worksheet.group.scopeId,
          scopeKind: worksheet.group.scopeKind,
          scopeCode: worksheet.group.scopeCode,
          scopeName: worksheet.group.scopeName,
          isLegacyUnassigned: worksheet.group.isLegacyUnassigned,
        ),
      ),
    );
  }

  void addColumn({
    required String heading,
    YorksV1BoqCanonicalField? canonicalField,
  }) {
    final worksheet = _editableWorksheet();
    final cleanHeading = heading.trim();
    if (cleanHeading.isEmpty) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    _replace(
      worksheet.copyWith(
        columns: [
          ...worksheet.columns,
          YorksV1BoqColumn(
            id: _uuidFactory(),
            heading: cleanHeading,
            displayOrder: worksheet.columns.length + 1,
            canonicalField: canonicalField,
          ),
        ],
      ),
    );
  }

  void renameColumn(String columnId, String heading) {
    final worksheet = _editableWorksheet();
    final cleanHeading = heading.trim();
    if (cleanHeading.isEmpty) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    _replace(
      worksheet.copyWith(
        columns: [
          for (final column in worksheet.columns)
            if (column.id == columnId)
              column.copyWith(heading: cleanHeading)
            else
              column,
        ],
      ),
    );
  }

  void removeColumn(String columnId) {
    final worksheet = _editableWorksheet();
    final next = worksheet.columns
        .where((column) => column.id != columnId)
        .toList(growable: false);
    if (next.length == worksheet.columns.length) return;
    _replace(
      worksheet.copyWith(
        columns: [
          for (var index = 0; index < next.length; index++)
            next[index].copyWith(displayOrder: index + 1),
        ],
      ),
    );
  }

  YorksV1BoqRow addBlankRow({String? afterRowId}) {
    final worksheet = _editableWorksheet();
    final index = _insertIndex(worksheet.rows, afterRowId);
    final row = YorksV1BoqRow(
      id: _uuidFactory(),
      displayOrder: index + 1,
      values: const {},
      canonicalValues: const {},
    );
    _replace(
      worksheet.copyWith(rows: _insertAndOrder(worksheet.rows, row, index)),
    );
    return row;
  }

  YorksV1BoqRow addSimilarRow({required String sourceRowId}) {
    final worksheet = _editableWorksheet();
    final sourceIndex = worksheet.rows.indexWhere(
      (row) => row.id == sourceRowId,
    );
    if (sourceIndex < 0) return addBlankRow(afterRowId: sourceRowId);
    final source = worksheet.rows[sourceIndex];
    final carriedValues = <String, Object?>{};
    final carriedCanonicalValues = <String, Object?>{};
    for (final column in worksheet.columns) {
      if (!_copiesToSimilarRow(column)) continue;
      final value = source.valueFor(column.id);
      if (value == null || value.toString().trim().isEmpty) continue;
      carriedValues[column.id] = value;
      final canonical = column.canonicalField;
      if (canonical != null) {
        carriedCanonicalValues[canonical.wireValue] = value;
      }
    }
    final row = YorksV1BoqRow(
      id: _uuidFactory(),
      displayOrder: sourceIndex + 2,
      values: carriedValues,
      canonicalValues: carriedCanonicalValues,
    );
    _replace(
      worksheet.copyWith(
        rows: _insertAndOrder(worksheet.rows, row, sourceIndex + 1),
      ),
    );
    return row;
  }

  /// R35 Similar Row deliberately carries only reusable material context.
  /// Tag/model, quantities, commercial values and arbitrary technical/status
  /// data are unique to the original equipment and must be reviewed again.
  static bool _copiesToSimilarRow(YorksV1BoqColumn column) {
    switch (column.canonicalField) {
      case YorksV1BoqCanonicalField.description:
      case YorksV1BoqCanonicalField.size:
      case YorksV1BoqCanonicalField.brandOrigin:
      case YorksV1BoqCanonicalField.unit:
        return true;
      case YorksV1BoqCanonicalField.model:
      case YorksV1BoqCanonicalField.equipmentTag:
      case YorksV1BoqCanonicalField.quantity:
      case YorksV1BoqCanonicalField.planningModelTag:
      case null:
        break;
    }
    final heading = column.heading.toLowerCase();
    return RegExp(
          r'(^|[^a-z])(description|item|size|dimension|make|brand|origin|unit)([^a-z]|$)',
        ).hasMatch(heading) &&
        !RegExp(
          r'tag|model|serial|qty|quantity|cost|price|mass|status|approval|amount',
        ).hasMatch(heading);
  }

  void updateCell({
    required String rowId,
    required String columnId,
    required String value,
  }) {
    final worksheet = _editableWorksheet();
    final column = worksheet.columns
        .where((item) => item.id == columnId)
        .firstOrNull;
    if (column == null) return;
    final canonicalValues = <String, Object?>{};
    for (final entry in worksheet.rows) {
      if (entry.id != rowId) {
        continue;
      }
      canonicalValues.addAll(entry.canonicalValues);
      final canonical = column.canonicalField;
      if (canonical != null) {
        final clean = value.trim();
        if (clean.isEmpty) {
          canonicalValues.remove(canonical.wireValue);
        } else {
          canonicalValues[canonical.wireValue] = clean;
        }
      }
    }
    _replace(
      worksheet.copyWith(
        rows: [
          for (final row in worksheet.rows)
            if (row.id == rowId)
              row.copyWith(
                values: {...row.values, columnId: value},
                canonicalValues: canonicalValues,
              )
            else
              row,
        ],
      ),
    );
  }

  void removeRow(String rowId) {
    final worksheet = _editableWorksheet();
    final remaining = worksheet.rows
        .where((row) => row.id != rowId)
        .toList(growable: false);
    if (remaining.length == worksheet.rows.length) return;
    _replace(
      worksheet.copyWith(
        rows: [
          for (var index = 0; index < remaining.length; index++)
            remaining[index].copyWith(displayOrder: index + 1),
        ],
      ),
    );
  }

  Future<bool> save() async {
    final worksheet = state.worksheet;
    if (worksheet == null || worksheet.group.isArchived) return false;
    if (worksheet.group.worksheetTitle.trim().isEmpty) {
      state = YorksV1BoqWorksheetState(
        status: YorksV1BoqSyncStatus.failed,
        worksheet: worksheet,
        errorCode: YorksV1DomainErrorCode.invalidInput,
      );
      return false;
    }
    state = YorksV1BoqWorksheetState(
      status: YorksV1BoqSyncStatus.saving,
      worksheet: worksheet,
    );
    try {
      final saved = await _repository.saveWorksheet(
        YorksV1SaveBoqWorksheetInput(
          worksheet: worksheet,
          worksheetTitle: worksheet.group.worksheetTitle,
          expectedVersion: worksheet.group.version,
          idempotencyKey: _uuidFactory(),
        ),
      );
      state = YorksV1BoqWorksheetState(
        status: YorksV1BoqSyncStatus.saved,
        worksheet: saved,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      state = YorksV1BoqWorksheetState(
        status: error.code == YorksV1DomainErrorCode.conflict
            ? YorksV1BoqSyncStatus.conflict
            : YorksV1BoqSyncStatus.failed,
        worksheet: worksheet,
        errorCode: error.code,
      );
      return false;
    }
  }

  /// Commits a reviewed local XLSX preview as one server-side worksheet
  /// replacement. Parsing or previewing a file never reaches Supabase; this
  /// is the only import mutation boundary.
  Future<bool> importWorkbook(YorksV1BoqImportPreview preview) async {
    final current = state.worksheet;
    if (current == null || current.group.isArchived || !preview.isValid) {
      if (current != null) {
        state = YorksV1BoqWorksheetState(
          status: YorksV1BoqSyncStatus.failed,
          worksheet: current,
          errorCode: YorksV1DomainErrorCode.invalidInput,
        );
      }
      return false;
    }
    final title = preview.title.trim();
    if (title.isEmpty) {
      state = YorksV1BoqWorksheetState(
        status: YorksV1BoqSyncStatus.failed,
        worksheet: current,
        errorCode: YorksV1DomainErrorCode.invalidInput,
      );
      return false;
    }

    final columns = [
      for (var index = 0; index < preview.columns.length; index++)
        YorksV1BoqColumn(
          id: _uuidFactory(),
          heading: preview.columns[index].heading.trim(),
          displayOrder: index + 1,
          canonicalField: preview.columns[index].canonicalField,
        ),
    ];
    final rows = [
      for (var rowIndex = 0; rowIndex < preview.rows.length; rowIndex++)
        YorksV1BoqRow(
          id: _uuidFactory(),
          displayOrder: rowIndex + 1,
          values: {
            for (
              var columnIndex = 0;
              columnIndex < columns.length;
              columnIndex++
            )
              if (preview.rows[rowIndex]
                  .valueFor(preview.columns[columnIndex].sourceIndex)
                  .isNotEmpty)
                columns[columnIndex].id: preview.rows[rowIndex].valueFor(
                  preview.columns[columnIndex].sourceIndex,
                ),
          },
          canonicalValues: {
            for (
              var columnIndex = 0;
              columnIndex < columns.length;
              columnIndex++
            )
              if (preview.rows[rowIndex]
                      .valueFor(preview.columns[columnIndex].sourceIndex)
                      .trim()
                      .isNotEmpty &&
                  preview.columns[columnIndex].canonicalField != null)
                preview.columns[columnIndex].canonicalField!.wireValue: preview
                    .rows[rowIndex]
                    .valueFor(preview.columns[columnIndex].sourceIndex),
          },
        ),
    ];
    final imported = YorksV1BoqWorksheet(
      group: _groupWithTitle(current.group, title),
      columns: columns,
      rows: rows,
    );
    state = YorksV1BoqWorksheetState(
      status: YorksV1BoqSyncStatus.saving,
      worksheet: current,
    );
    try {
      final saved = await _repository.importWorksheet(
        YorksV1ImportBoqWorksheetInput(
          worksheet: imported,
          worksheetTitle: title,
          expectedVersion: current.group.version,
          idempotencyKey: _uuidFactory(),
          sourceFileName: preview.fileName,
          sourceWorksheetName: preview.worksheetName,
          sourceHeaderRowNumber: preview.headerRowNumber,
          sourceHeaderRowNumbers: preview.headerRowNumbers,
          sourceHeaderHierarchy: preview.headerHierarchy,
        ),
      );
      state = YorksV1BoqWorksheetState(
        status: YorksV1BoqSyncStatus.saved,
        worksheet: saved,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      state = YorksV1BoqWorksheetState(
        status: error.code == YorksV1DomainErrorCode.conflict
            ? YorksV1BoqSyncStatus.conflict
            : YorksV1BoqSyncStatus.failed,
        worksheet: current,
        errorCode: error.code,
      );
      return false;
    }
  }

  YorksV1BoqWorksheet _editableWorksheet() {
    final worksheet = state.worksheet;
    if (worksheet == null ||
        worksheet.group.isArchived ||
        worksheet.group.isLegacyUnassigned) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    return worksheet;
  }

  void _replace(YorksV1BoqWorksheet worksheet) {
    state = YorksV1BoqWorksheetState(
      status: YorksV1BoqSyncStatus.dirty,
      worksheet: worksheet,
    );
  }

  static YorksV1BoqGroup _groupWithTitle(YorksV1BoqGroup group, String title) =>
      YorksV1BoqGroup(
        id: group.id,
        projectId: group.projectId,
        name: group.name,
        worksheetTitle: title,
        displayOrder: group.displayOrder,
        isCustom: group.isCustom,
        isArchived: group.isArchived,
        version: group.version,
        rowCount: group.rowCount,
        columnCount: group.columnCount,
        updatedAt: group.updatedAt,
        scopeId: group.scopeId,
        scopeKind: group.scopeKind,
        scopeCode: group.scopeCode,
        scopeName: group.scopeName,
        isLegacyUnassigned: group.isLegacyUnassigned,
      );

  static int _insertIndex(List<YorksV1BoqRow> rows, String? afterRowId) {
    if (afterRowId == null) return rows.length;
    final index = rows.indexWhere((row) => row.id == afterRowId);
    return index < 0 ? rows.length : index + 1;
  }

  static List<YorksV1BoqRow> _insertAndOrder(
    List<YorksV1BoqRow> rows,
    YorksV1BoqRow row,
    int index,
  ) {
    final next = List<YorksV1BoqRow>.of(rows)..insert(index, row);
    return [
      for (var item = 0; item < next.length; item++)
        next[item].copyWith(displayOrder: item + 1),
    ];
  }
}
