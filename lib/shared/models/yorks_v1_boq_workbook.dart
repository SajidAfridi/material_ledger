import 'yorks_v1_boq.dart';

/// A decoded workbook is intentionally an in-memory preview. Its source bytes
/// never enter local draft storage or a generic collection cache.
class YorksV1BoqParsedWorkbook {
  YorksV1BoqParsedWorkbook({
    required this.fileName,
    required List<YorksV1BoqWorkbookSheet> sheets,
  }) : sheets = List.unmodifiable(sheets);

  final String fileName;
  final List<YorksV1BoqWorkbookSheet> sheets;
}

/// The lossless scalar-cell view required for BOQ import. Formatting, formula
/// definitions and non-cell workbook features are deliberately out of scope:
/// the BOQ authority is its imported title, headings and row values.
class YorksV1BoqWorkbookSheet {
  YorksV1BoqWorkbookSheet({
    required this.name,
    required List<List<String>> rows,
  }) : rows = List.unmodifiable([
         for (final row in rows) List<String>.unmodifiable(row),
       ]);

  final String name;
  final List<List<String>> rows;

  List<int> get nonEmptyRowIndexes => [
    for (var index = 0; index < rows.length; index++)
      if (rows[index].any((value) => value.trim().isNotEmpty)) index,
  ];
}

/// One source column shown in the mapping preview. [sourceIndex] is a local
/// workbook coordinate, never persisted as a server entity ID.
class YorksV1BoqImportColumn {
  const YorksV1BoqImportColumn({
    required this.sourceIndex,
    required this.heading,
    this.canonicalField,
  });

  final int sourceIndex;
  final String heading;
  final YorksV1BoqCanonicalField? canonicalField;

  YorksV1BoqImportColumn copyWith({
    String? heading,
    YorksV1BoqCanonicalField? canonicalField,
    bool clearCanonicalField = false,
  }) => YorksV1BoqImportColumn(
    sourceIndex: sourceIndex,
    heading: heading ?? this.heading,
    canonicalField: clearCanonicalField
        ? null
        : canonicalField ?? this.canonicalField,
  );
}

/// A non-empty source data row keyed by its source-column coordinate.
class YorksV1BoqImportRow {
  YorksV1BoqImportRow({
    required this.sourceRowNumber,
    required Map<int, String> values,
  }) : values = Map.unmodifiable(values);

  /// One-based spreadsheet row number, retained for validation feedback only.
  final int sourceRowNumber;
  final Map<int, String> values;

  String valueFor(int sourceIndex) => values[sourceIndex] ?? '';
}

/// Stable, localized-by-presentation validation outcomes for a local workbook
/// preview. Raw parser exceptions and spreadsheet text are never surfaced as
/// user-facing copy.
enum YorksV1BoqImportValidationCode {
  noColumns,
  blankHeading,
  duplicateHeading,
  duplicateCanonicalMapping,
}

class YorksV1BoqImportValidationIssue {
  const YorksV1BoqImportValidationIssue({
    required this.code,
    this.sourceColumnIndex,
  });

  final YorksV1BoqImportValidationCode code;
  final int? sourceColumnIndex;
}

/// User-reviewable import proposal. It is never an authoritative worksheet
/// until the version-checked import command commits it on the server.
class YorksV1BoqImportPreview {
  YorksV1BoqImportPreview({
    required this.fileName,
    required this.worksheetName,
    required this.title,
    required this.headerRowIndex,
    required List<YorksV1BoqImportColumn> columns,
    required List<YorksV1BoqImportRow> rows,
    required List<YorksV1BoqImportValidationIssue> validationIssues,
  }) : columns = List.unmodifiable(columns),
       rows = List.unmodifiable(rows),
       validationIssues = List.unmodifiable(validationIssues);

  final String fileName;
  final String worksheetName;
  final String title;

  /// Zero-based index used only while editing this local preview.
  final int headerRowIndex;
  final List<YorksV1BoqImportColumn> columns;
  final List<YorksV1BoqImportRow> rows;
  final List<YorksV1BoqImportValidationIssue> validationIssues;

  int get headerRowNumber => headerRowIndex + 1;
  bool get isValid => validationIssues.isEmpty && columns.isNotEmpty;

  YorksV1BoqImportPreview copyWith({
    String? title,
    List<YorksV1BoqImportColumn>? columns,
    List<YorksV1BoqImportValidationIssue>? validationIssues,
  }) => YorksV1BoqImportPreview(
    fileName: fileName,
    worksheetName: worksheetName,
    title: title ?? this.title,
    headerRowIndex: headerRowIndex,
    columns: columns ?? this.columns,
    rows: rows,
    validationIssues: validationIssues ?? this.validationIssues,
  );
}

/// One explicit, server-audited XLSX import. The source metadata deliberately
/// excludes workbook bytes and values because those live in the normalized
/// BOQ records and their audit/revision history after a successful commit.
class YorksV1ImportBoqWorksheetInput {
  YorksV1ImportBoqWorksheetInput({
    required this.worksheet,
    required this.worksheetTitle,
    required this.expectedVersion,
    required this.idempotencyKey,
    required this.sourceFileName,
    required this.sourceWorksheetName,
    required this.sourceHeaderRowNumber,
  });

  final YorksV1BoqWorksheet worksheet;
  final String worksheetTitle;
  final int expectedVersion;
  final String idempotencyKey;
  final String sourceFileName;
  final String sourceWorksheetName;
  final int sourceHeaderRowNumber;

  Map<String, Object?> toRpcPayload() => {
    'group_id': worksheet.group.id,
    'expected_version': expectedVersion,
    'worksheet_title': worksheetTitle.trim(),
    'columns': [for (final column in worksheet.columns) column.toSaveJson()],
    'rows': [for (final row in worksheet.rows) row.toSaveJson()],
    'source': {
      'file_name': sourceFileName.trim(),
      'worksheet_name': sourceWorksheetName.trim(),
      'header_row_number': sourceHeaderRowNumber,
    },
  };
}
