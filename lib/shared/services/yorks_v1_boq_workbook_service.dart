import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:xml/xml.dart';

import '../models/yorks_v1_boq.dart';
import '../models/yorks_v1_boq_workbook.dart';
import '../models/yorks_v1_domain_error.dart';

/// Licensed, pure-Dart XLSX gateway. File selection and saving use Flutter's
/// maintained cross-platform selector; parsing and generation work only on
/// scalar worksheet cells so this service remains suitable for web and Android.
abstract interface class YorksV1BoqWorkbookFileService {
  Future<YorksV1BoqSelectedWorkbook?> selectWorkbook();

  Future<bool> saveWorkbook({
    required Uint8List bytes,
    required String suggestedName,
  });
}

class YorksV1BoqSelectedWorkbook {
  const YorksV1BoqSelectedWorkbook({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
}

class YorksV1PlatformBoqWorkbookFileService
    implements YorksV1BoqWorkbookFileService {
  const YorksV1PlatformBoqWorkbookFileService();

  static const _xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const _xlsxType = XTypeGroup(
    label: 'Excel workbook',
    extensions: ['xlsx'],
    mimeTypes: [_xlsxMimeType],
  );

  @override
  Future<YorksV1BoqSelectedWorkbook?> selectWorkbook() async {
    final file = await openFile(acceptedTypeGroups: const [_xlsxType]);
    if (file == null) return null;
    final name = _fileName(file.name);
    if (!name.toLowerCase().endsWith('.xlsx')) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    return YorksV1BoqSelectedWorkbook(
      fileName: name,
      bytes: await file.readAsBytes(),
    );
  }

  @override
  Future<bool> saveWorkbook({
    required Uint8List bytes,
    required String suggestedName,
  }) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [_xlsxType],
    );
    if (location == null) return false;
    final file = XFile.fromData(
      bytes,
      name: suggestedName,
      mimeType: _xlsxMimeType,
    );
    await file.saveTo(location.path);
    return true;
  }

  static String _fileName(String pathOrName) {
    final normalized = pathOrName.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash < 0 ? normalized : normalized.substring(slash + 1);
  }
}

/// XLSX codec for the BOQ interchange contract. It intentionally accepts
/// `.xlsx` only, limits untrusted workbook dimensions, detects a usable title
/// and header row, and exports a current worksheet as a standalone workbook.
class YorksV1BoqWorkbookCodec {
  const YorksV1BoqWorkbookCodec();

  static const _maxWorkbookBytes = 15 * 1024 * 1024;
  static const _maxSheets = 32;
  static const _maxRowsPerSheet = 10000;
  static const _maxColumnsPerSheet = 256;

  YorksV1BoqParsedWorkbook decode({
    required Uint8List bytes,
    required String fileName,
  }) {
    if (bytes.isEmpty || bytes.lengthInBytes > _maxWorkbookBytes) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final entries = <String, ArchiveFile>{
        for (final file in archive)
          if (file.isFile) file.name.replaceAll('\\', '/'): file,
      };
      final workbookXml = _readText(entries, 'xl/workbook.xml');
      final relationshipsXml = _readText(entries, 'xl/_rels/workbook.xml.rels');
      final sharedStrings = _decodeSharedStrings(entries);
      final relationships = _decodeRelationships(relationshipsXml);
      final workbook = XmlDocument.parse(workbookXml);
      final sheets = <YorksV1BoqWorkbookSheet>[];
      for (final element in workbook.findAllElements('sheet')) {
        if (sheets.length >= _maxSheets) {
          throw const YorksV1DomainException(
            YorksV1DomainErrorCode.invalidInput,
          );
        }
        final name = _attribute(element, 'name')?.trim() ?? '';
        final relationshipId = _attribute(element, 'id')?.trim() ?? '';
        final target = relationships[relationshipId];
        if (name.isEmpty || target == null) continue;
        final sheetPath = _worksheetPath(target);
        final sheetXml = _readText(entries, sheetPath);
        sheets.add(
          YorksV1BoqWorkbookSheet(
            name: name,
            rows: _decodeSheetRows(sheetXml, sharedStrings),
          ),
        );
      }
      if (sheets.isEmpty) {
        throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
      }
      return YorksV1BoqParsedWorkbook(fileName: fileName, sheets: sheets);
    } on YorksV1DomainException {
      rethrow;
    } catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.invalidInput,
        cause: error,
      );
    }
  }

  YorksV1BoqImportPreview preview({
    required YorksV1BoqParsedWorkbook workbook,
    required YorksV1BoqWorkbookSheet sheet,
    required String fallbackTitle,
    int? headerRowIndex,
  }) {
    final headerRowIndexes = _resolveHeaderRows(
      sheet,
      requestedHeaderRowIndex: headerRowIndex,
    );
    if (headerRowIndexes.isEmpty) {
      return YorksV1BoqImportPreview(
        fileName: workbook.fileName,
        worksheetName: sheet.name,
        title: fallbackTitle,
        headerRowIndex: 0,
        headerRowIndexes: const [],
        columns: const [],
        rows: const [],
        validationIssues: const [
          YorksV1BoqImportValidationIssue(
            code: YorksV1BoqImportValidationCode.noColumns,
          ),
        ],
      );
    }
    final resolvedHeaderIndex = headerRowIndexes.first;
    final lastHeaderRowIndex = headerRowIndexes.last;
    final sourceIndexes = _sourceColumnIndexes(
      sheet.rows,
      firstHeaderRowIndex: resolvedHeaderIndex,
    );
    final headerHierarchy = _headerHierarchy(
      sheet.rows,
      headerRowIndexes: headerRowIndexes,
      sourceIndexes: sourceIndexes,
    );
    final columns = [
      for (final path in headerHierarchy)
        YorksV1BoqImportColumn(
          sourceIndex: path.sourceIndex,
          heading: path.combinedLabel,
          canonicalField: _suggestCanonicalField(path.combinedLabel),
        ),
    ];
    final rows = <YorksV1BoqImportRow>[];
    for (
      var index = lastHeaderRowIndex + 1;
      index < sheet.rows.length;
      index++
    ) {
      final source = sheet.rows[index];
      final values = <int, String>{
        for (final sourceIndex in sourceIndexes)
          if (sourceIndex < source.length && source[sourceIndex].isNotEmpty)
            sourceIndex: source[sourceIndex],
      };
      if (values.isNotEmpty) {
        rows.add(
          YorksV1BoqImportRow(sourceRowNumber: index + 1, values: values),
        );
      }
    }
    return YorksV1BoqImportPreview(
      fileName: workbook.fileName,
      worksheetName: sheet.name,
      title: _detectTitle(sheet, resolvedHeaderIndex, fallbackTitle),
      headerRowIndex: resolvedHeaderIndex,
      headerRowIndexes: headerRowIndexes,
      headerHierarchy: headerHierarchy,
      columns: columns,
      rows: rows,
      validationIssues: validatePreviewColumns(columns),
    );
  }

  List<YorksV1BoqImportValidationIssue> validatePreviewColumns(
    List<YorksV1BoqImportColumn> columns,
  ) {
    if (columns.isEmpty) {
      return const [
        YorksV1BoqImportValidationIssue(
          code: YorksV1BoqImportValidationCode.noColumns,
        ),
      ];
    }
    final issues = <YorksV1BoqImportValidationIssue>[];
    final seenHeadings = <String>{};
    final seenCanonical = <YorksV1BoqCanonicalField>{};
    for (final column in columns) {
      final heading = column.heading.trim();
      if (heading.isEmpty) {
        issues.add(
          YorksV1BoqImportValidationIssue(
            code: YorksV1BoqImportValidationCode.blankHeading,
            sourceColumnIndex: column.sourceIndex,
          ),
        );
      } else if (!seenHeadings.add(heading.toLowerCase())) {
        issues.add(
          YorksV1BoqImportValidationIssue(
            code: YorksV1BoqImportValidationCode.duplicateHeading,
            sourceColumnIndex: column.sourceIndex,
          ),
        );
      }
      final canonicalField = column.canonicalField;
      if (canonicalField != null && !seenCanonical.add(canonicalField)) {
        issues.add(
          YorksV1BoqImportValidationIssue(
            code: YorksV1BoqImportValidationCode.duplicateCanonicalMapping,
            sourceColumnIndex: column.sourceIndex,
          ),
        );
      }
    }
    return issues;
  }

  Uint8List encodeWorksheet(YorksV1BoqWorksheet worksheet) =>
      encodeWorksheets([worksheet]);

  /// Encodes a complete project BOQ workbook. Each group remains a separate
  /// worksheet so arbitrary BOQ columns are preserved and can be re-imported
  /// without flattening the project into a single table.
  Uint8List encodeWorksheets(List<YorksV1BoqWorksheet> worksheets) {
    if (worksheets.isEmpty || worksheets.length > _maxSheets) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          '[Content_Types].xml',
          _contentTypesXmlFor(worksheets.length),
        ),
      )
      ..addFile(ArchiveFile.string('_rels/.rels', _rootRelationshipsXml))
      ..addFile(
        ArchiveFile.string(
          'xl/_rels/workbook.xml.rels',
          _workbookRelationshipsXmlFor(worksheets.length),
        ),
      )
      ..addFile(
        ArchiveFile.string('xl/workbook.xml', _workbookXmlFor(worksheets)),
      );
    for (var index = 0; index < worksheets.length; index++) {
      final worksheet = worksheets[index];
      archive.addFile(
        ArchiveFile.string(
          'xl/worksheets/sheet${index + 1}.xml',
          _worksheetXml(_worksheetRows(worksheet)),
        ),
      );
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static List<List<String>> _worksheetRows(YorksV1BoqWorksheet worksheet) => [
    [worksheet.group.effectiveTitle],
    [for (final column in worksheet.columns) column.heading],
    for (final row in worksheet.rows)
      [
        for (final column in worksheet.columns)
          _scalarText(row.valueFor(column.id)),
      ],
  ];

  static String _readText(Map<String, ArchiveFile> entries, String path) {
    final file = entries[path];
    final content = file?.readBytes();
    if (content == null) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    return utf8.decode(content, allowMalformed: false);
  }

  static List<String> _decodeSharedStrings(Map<String, ArchiveFile> entries) {
    final file = entries['xl/sharedStrings.xml'];
    final content = file?.readBytes();
    if (content == null) return const [];
    final document = XmlDocument.parse(
      utf8.decode(content, allowMalformed: false),
    );
    return [
      for (final item in document.findAllElements('si')) _elementText(item),
    ];
  }

  static Map<String, String> _decodeRelationships(String relationshipsXml) {
    final document = XmlDocument.parse(relationshipsXml);
    return {
      for (final relationship in document.findAllElements('Relationship'))
        if (_attribute(relationship, 'Id') != null &&
            _attribute(relationship, 'Target') != null)
          _attribute(relationship, 'Id')!: _attribute(relationship, 'Target')!,
    };
  }

  static String _worksheetPath(String target) {
    if (target.contains('..')) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    final normalized = target.replaceAll('\\', '/');
    if (normalized.startsWith('/')) return normalized.substring(1);
    return 'xl/$normalized';
  }

  List<List<String>> _decodeSheetRows(
    String sheetXml,
    List<String> sharedStrings,
  ) {
    final document = XmlDocument.parse(sheetXml);
    final cells = <int, Map<int, String>>{};
    var maxRow = -1;
    var maxColumn = -1;
    for (final row in document.findAllElements('row')) {
      final rowIndex = (_integer(_attribute(row, 'r')) ?? (maxRow + 2)) - 1;
      if (rowIndex < 0 || rowIndex >= _maxRowsPerSheet) {
        throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
      }
      var nextColumn = 0;
      for (final cell in row.findElements('c')) {
        final reference = _attribute(cell, 'r');
        final column = reference == null
            ? nextColumn
            : _columnIndexFromReference(reference);
        if (column < 0 || column >= _maxColumnsPerSheet) {
          throw const YorksV1DomainException(
            YorksV1DomainErrorCode.invalidInput,
          );
        }
        cells.putIfAbsent(rowIndex, () => {})[column] = _decodeCell(
          cell,
          sharedStrings,
        );
        nextColumn = column + 1;
        maxColumn = math.max(maxColumn, column);
      }
      maxRow = math.max(maxRow, rowIndex);
    }
    if (maxRow < 0 || maxColumn < 0) return const [];
    return [
      for (var row = 0; row <= maxRow; row++)
        [
          for (var column = 0; column <= maxColumn; column++)
            cells[row]?[column] ?? '',
        ],
    ];
  }

  static String _decodeCell(XmlElement cell, List<String> sharedStrings) {
    final type = _attribute(cell, 't');
    if (type == 'inlineStr') {
      final inline = _firstElement(cell, 'is');
      return inline == null ? '' : _elementText(inline);
    }
    final value = _firstElement(cell, 'v');
    final raw = value == null ? '' : _elementText(value);
    if (type == 's') {
      final index = _integer(raw);
      return index != null && index >= 0 && index < sharedStrings.length
          ? sharedStrings[index]
          : '';
    }
    if (type == 'b') return raw == '1' ? 'TRUE' : 'FALSE';
    return raw;
  }

  static int _detectHeaderRow(YorksV1BoqWorkbookSheet sheet) {
    var bestIndex = -1;
    var bestScore = -1;
    final upperBound = math.min(sheet.rows.length, 20);
    for (var index = 0; index < upperBound; index++) {
      final values = sheet.rows[index]
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      if (values.isEmpty) continue;
      final distinct = values.map(_normalizedHeader).toSet().length;
      final recognized = values
          .where((value) => _suggestCanonicalField(value) != null)
          .length;
      final score = distinct + (recognized * 4) + (values.length > 1 ? 1 : 0);
      if (score > bestScore) {
        bestScore = score;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  static List<int> _resolveHeaderRows(
    YorksV1BoqWorkbookSheet sheet, {
    required int? requestedHeaderRowIndex,
  }) {
    final primary = requestedHeaderRowIndex ?? _detectHeaderRow(sheet);
    if (primary < 0 || primary >= sheet.rows.length) return const [];

    // A reviewer can select either row of a detected parent/child pair. Keep
    // both paths so rows begin after the child header rather than treating its
    // "Calculated / Selected" labels as material data.
    if (primary > 0 &&
        _looksLikeChildHeader(
          parent: sheet.rows[primary - 1],
          child: sheet.rows[primary],
        )) {
      return [primary - 1, primary];
    }
    if (primary + 1 < sheet.rows.length &&
        _looksLikeChildHeader(
          parent: sheet.rows[primary],
          child: sheet.rows[primary + 1],
        )) {
      return [primary, primary + 1];
    }
    return [primary];
  }

  static bool _looksLikeChildHeader({
    required List<String> parent,
    required List<String> child,
  }) {
    final childValues = child
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (childValues.length < 2) return false;

    var continuationCount = 0;
    final width = math.max(parent.length, child.length);
    for (var index = 0; index < width; index++) {
      final parentValue = index < parent.length ? parent[index].trim() : '';
      final childValue = index < child.length ? child[index].trim() : '';
      if (parentValue.isEmpty && childValue.isNotEmpty) continuationCount++;
    }
    if (continuationCount < 2) return false;

    // Multi-level schedule children are typically short repeated labels such
    // as "Calculated" and "Selected". The check deliberately rejects normal
    // data rows, which are not a header continuation and commonly contain
    // numeric/item identifiers instead.
    final normalized = childValues.map(_normalizedHeader).toList();
    final repeated = normalized.toSet().length < normalized.length;
    final labelledChild = normalized.any(
      (value) => value == 'calculated' || value == 'selected',
    );
    return repeated || labelledChild;
  }

  static List<int> _sourceColumnIndexes(
    List<List<String>> rows, {
    required int firstHeaderRowIndex,
  }) {
    var first = -1;
    var last = -1;
    for (
      var rowIndex = firstHeaderRowIndex;
      rowIndex < rows.length;
      rowIndex++
    ) {
      final row = rows[rowIndex];
      for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
        if (row[columnIndex].trim().isEmpty) continue;
        if (first < 0) first = columnIndex;
        // Rows in equipment schedules are commonly sparse at the right edge:
        // the first record may contain MASS/STATUS while later records leave
        // those cells blank. Keep the furthest coordinate seen anywhere in
        // the header/data region rather than letting a later sparse row pull
        // the import boundary left and silently drop source columns.
        last = math.max(last, columnIndex);
      }
    }
    if (first < 0 || last < first) return const [];
    // Only fully empty *outer* columns are trimmed. Empty inner coordinates
    // are retained so source columns and values never shift on import.
    return [for (var index = first; index <= last; index++) index];
  }

  static List<YorksV1BoqHeaderPath> _headerHierarchy(
    List<List<String>> rows, {
    required List<int> headerRowIndexes,
    required List<int> sourceIndexes,
  }) {
    if (headerRowIndexes.length == 1) {
      final header = rows[headerRowIndexes.single];
      return [
        for (final sourceIndex in sourceIndexes)
          YorksV1BoqHeaderPath(
            sourceIndex: sourceIndex,
            labels: [if (sourceIndex < header.length) header[sourceIndex]],
          ),
      ];
    }

    final parent = rows[headerRowIndexes.first];
    final child = rows[headerRowIndexes.last];
    String activeParent = '';
    final result = <YorksV1BoqHeaderPath>[];
    for (final sourceIndex in sourceIndexes) {
      final parentLabel = sourceIndex < parent.length
          ? parent[sourceIndex].trim()
          : '';
      if (parentLabel.isNotEmpty) activeParent = parentLabel;
      final childLabel = sourceIndex < child.length
          ? child[sourceIndex].trim()
          : '';
      final labels = <String>[
        if (activeParent.isNotEmpty) activeParent,
        if (childLabel.isNotEmpty && childLabel != activeParent) childLabel,
      ];
      result.add(
        YorksV1BoqHeaderPath(sourceIndex: sourceIndex, labels: labels),
      );
    }
    return result;
  }

  static String _detectTitle(
    YorksV1BoqWorkbookSheet sheet,
    int headerRowIndex,
    String fallbackTitle,
  ) {
    for (var index = headerRowIndex - 1; index >= 0; index--) {
      final title = sheet.rows[index]
          .map((value) => value.trim())
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      if (title.isNotEmpty) return title;
    }
    return fallbackTitle.trim();
  }

  static YorksV1BoqCanonicalField? _suggestCanonicalField(String heading) {
    final normalized = _normalizedHeader(heading);
    if (normalized.startsWith('size') || normalized.startsWith('dimension')) {
      return YorksV1BoqCanonicalField.size;
    }
    return switch (normalized) {
      'itemdescription' ||
      'description' ||
      'item' ||
      'materialdescription' ||
      'materialitem' ||
      'itemname' ||
      'equipmentdescription' ||
      'equipmentname' ||
      'unitreference' ||
      // A common spelling in the supplied Package Unit worksheet.
      'unitrefrence' => YorksV1BoqCanonicalField.description,
      'brandorigin' ||
      'makeorigin' ||
      'brand' ||
      'make' ||
      'fanmake' ||
      'manufacturer' ||
      'manufacturerorigin' => YorksV1BoqCanonicalField.brandOrigin,
      'size' ||
      'dimension' ||
      'dimensions' ||
      'equipmentsize' => YorksV1BoqCanonicalField.size,
      'qty' ||
      'quantity' ||
      'qnty' ||
      'fanqty' ||
      'unitqty' ||
      'equipmentqty' ||
      'requestedqty' ||
      'quantityrequested' ||
      'requestedquantity' ||
      'qtyrequested' => YorksV1BoqCanonicalField.quantity,
      'unit' ||
      'units' ||
      'uom' ||
      'unitofmeasure' => YorksV1BoqCanonicalField.unit,
      'unitcost' ||
      'unitprice' ||
      'unitrate' => YorksV1BoqCanonicalField.unitCost,
      'totalcost' ||
      'totalprice' ||
      'totalamount' => YorksV1BoqCanonicalField.totalCost,
      'model' ||
      'fanmodel' ||
      'equipmentmodel' => YorksV1BoqCanonicalField.model,
      'equipmenttag' ||
      'equipmenttagno' ||
      'tag' ||
      'tagno' ||
      'fantag' ||
      'fantagno' ||
      'putag' ||
      'putagno' => YorksV1BoqCanonicalField.equipmentTag,
      'modelserialno' ||
      'modelserialnumber' ||
      'modeltag' ||
      'modeltagno' ||
      'serialno' ||
      'serialnumber' ||
      'planningmodeltag' => YorksV1BoqCanonicalField.planningModelTag,
      _ => null,
    };
  }

  static String _normalizedHeader(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  static int _columnIndexFromReference(String reference) {
    final match = RegExp(r'^([A-Za-z]+)').firstMatch(reference);
    final letters = match?.group(1);
    if (letters == null) return -1;
    var result = 0;
    for (final codeUnit in letters.toUpperCase().codeUnits) {
      result = (result * 26) + codeUnit - 64;
    }
    return result - 1;
  }

  static String _columnName(int index) {
    var value = index + 1;
    final result = StringBuffer();
    while (value > 0) {
      value--;
      result.writeCharCode(65 + (value % 26));
      value ~/= 26;
    }
    return result.toString().split('').reversed.join();
  }

  static int? _integer(String? value) =>
      value == null ? null : int.tryParse(value);

  static String? _attribute(XmlElement element, String localName) {
    for (final attribute in element.attributes) {
      if (attribute.name.local == localName) return attribute.value;
    }
    return null;
  }

  static XmlElement? _firstElement(XmlElement element, String localName) {
    for (final descendant in element.findAllElements(localName)) {
      return descendant;
    }
    return null;
  }

  static String _elementText(XmlElement element) => element.innerText;

  static String _scalarText(Object? value) => switch (value) {
    null => '',
    String value => value,
    _ => value.toString(),
  };

  static String _worksheetXml(List<List<String>> rows) {
    final output = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetData>',
    );
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      output.write('<row r="${rowIndex + 1}">');
      final row = rows[rowIndex];
      for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
        final value = row[columnIndex];
        if (value.isEmpty) continue;
        final reference = '${_columnName(columnIndex)}${rowIndex + 1}';
        final preserve = value.trim() != value ? ' xml:space="preserve"' : '';
        output.write(
          '<c r="$reference" t="inlineStr"><is><t$preserve>'
          '${_xmlEscape(value)}</t></is></c>',
        );
      }
      output.write('</row>');
    }
    output.write('</sheetData></worksheet>');
    return output.toString();
  }

  static String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static const _rootRelationshipsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';
  static String _contentTypesXmlFor(int count) {
    final output = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
    );
    for (var index = 1; index <= count; index++) {
      output.write(
        '<Override PartName="/xl/worksheets/sheet$index.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
      );
    }
    output.write('</Types>');
    return output.toString();
  }

  static String _workbookXmlFor(List<YorksV1BoqWorksheet> worksheets) {
    final output = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets>',
    );
    final usedNames = <String>{};
    for (var index = 0; index < worksheets.length; index++) {
      final base = _safeSheetName(worksheets[index].group.effectiveTitle);
      var name = base;
      var suffix = 2;
      while (!usedNames.add(name.toLowerCase())) {
        final suffixText = ' ($suffix)';
        name =
            '${base.substring(0, (31 - suffixText.length).clamp(1, 31))}$suffixText';
        suffix++;
      }
      output.write(
        '<sheet name="${_xmlEscape(name)}" sheetId="${index + 1}" '
        'r:id="rId${index + 1}"/>',
      );
    }
    output.write('</sheets></workbook>');
    return output.toString();
  }

  static String _workbookRelationshipsXmlFor(int count) {
    final output = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    );
    for (var index = 0; index < count; index++) {
      output.write(
        '<Relationship Id="rId${index + 1}" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
        'Target="worksheets/sheet${index + 1}.xml"/>',
      );
    }
    output.write('</Relationships>');
    return output.toString();
  }

  static String _safeSheetName(String source) {
    final cleaned = source.replaceAll(RegExp(r'[\\/:?*\[\]]+'), ' ').trim();
    final value = cleaned.isEmpty ? 'BOQ' : cleaned;
    return value.length > 31 ? value.substring(0, 31) : value;
  }
}
