import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_inventory_workbook.dart';
import '../models/yorks_v1_logistics.dart';
import 'yorks_v1_boq_workbook_service.dart';
import 'yorks_v1_inventory_workbook_template.dart';

class YorksV1InventorySelectedWorkbook {
  const YorksV1InventorySelectedWorkbook({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
}

abstract interface class YorksV1InventoryWorkbookFileService {
  Future<YorksV1InventorySelectedWorkbook?> selectWorkbook();

  Future<bool> saveImportTemplate();

  Future<bool> saveStockRegister({
    required YorksV1InventoryWorkspace workspace,
    required String suggestedName,
  });
}

class YorksV1PlatformInventoryWorkbookFileService
    implements YorksV1InventoryWorkbookFileService {
  const YorksV1PlatformInventoryWorkbookFileService();

  static const _xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const _xlsx = XTypeGroup(
    label: 'Excel workbook',
    extensions: ['xlsx'],
    mimeTypes: [_xlsxMime],
  );
  static const _csv = XTypeGroup(
    label: 'CSV data',
    extensions: ['csv'],
    mimeTypes: ['text/csv'],
  );

  @override
  Future<YorksV1InventorySelectedWorkbook?> selectWorkbook() async {
    final file = await openFile(acceptedTypeGroups: const [_xlsx, _csv]);
    if (file == null) return null;
    final name = _fileName(file.name);
    final extension = name.toLowerCase().split('.').last;
    if (extension != 'xlsx' && extension != 'csv') {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.lengthInBytes > 15 * 1024 * 1024) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    return YorksV1InventorySelectedWorkbook(fileName: name, bytes: bytes);
  }

  @override
  Future<bool> saveImportTemplate() => _save(
    bytes: base64Decode(yorksV1InventoryWorkbookTemplateBase64),
    name: 'Yorks_Warehouse_Inventory_Import_Template.xlsx',
    type: _xlsx,
    mimeType: _xlsxMime,
  );

  @override
  Future<bool> saveStockRegister({
    required YorksV1InventoryWorkspace workspace,
    required String suggestedName,
  }) {
    final rows = <List<Object?>>[
      const [
        'Item Code',
        'Item Description',
        'Category',
        'Brand / Origin',
        'Unit',
        'On Hand',
        'Reserved',
        'Available',
        'Minimum Stock',
        'Location / Bin',
        'Status',
        'Last Updated',
      ],
      for (final item in workspace.items)
        [
          item.itemCode ?? '',
          item.description,
          item.categoryName ?? 'Uncategorized',
          item.brandOrigin ?? '',
          item.unit,
          item.onHandQuantity,
          item.reservedQuantity,
          item.availableQuantity,
          item.minimumStock ?? '',
          item.locationBin ?? '',
          item.isActive
              ? item.isOutOfStock
                    ? 'Out of Stock'
                    : item.isLowStock
                    ? 'Low Stock'
                    : 'Active'
              : 'Inactive',
          item.updatedAt?.toIso8601String() ?? '',
        ],
    ];
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    return _save(
      bytes: Uint8List.fromList(utf8.encode('\ufeff$csv')),
      name: suggestedName,
      type: _csv,
      mimeType: 'text/csv',
    );
  }

  static Future<bool> _save({
    required Uint8List bytes,
    required String name,
    required XTypeGroup type,
    required String mimeType,
  }) async {
    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [type],
    );
    if (location == null) return false;
    await XFile.fromData(
      bytes,
      name: name,
      mimeType: mimeType,
    ).saveTo(location.path);
    return true;
  }

  static String _fileName(String pathOrName) {
    final normalized = pathOrName.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash < 0 ? normalized : normalized.substring(slash + 1);
  }

  static String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }
}

class YorksV1InventoryCategoryMatcher {
  const YorksV1InventoryCategoryMatcher();

  YorksV1InventoryCategory? exact(
    String value,
    List<YorksV1InventoryCategory> categories,
  ) {
    final key = yorksV1InventorySearchKey(value);
    if (key.isEmpty) return null;
    for (final category in categories) {
      if (yorksV1InventorySearchKey(category.name) == key ||
          category.aliases.any(
            (alias) => yorksV1InventorySearchKey(alias) == key,
          )) {
        return category;
      }
    }
    return null;
  }

  List<YorksV1InventoryCategorySuggestion> rank(
    String value,
    List<YorksV1InventoryCategory> categories,
  ) {
    final result =
        <YorksV1InventoryCategorySuggestion>[
          for (final category in categories)
            YorksV1InventoryCategorySuggestion(
              category: category,
              score: math.max(
                _similarity(value, category.name),
                category.aliases.fold<double>(
                  0,
                  (best, alias) => math.max(best, _similarity(value, alias)),
                ),
              ),
            ),
        ]..sort((a, b) {
          final score = b.score.compareTo(a.score);
          return score != 0
              ? score
              : a.category.name.compareTo(b.category.name);
        });
    return result.take(5).toList(growable: false);
  }

  static double _similarity(String left, String right) {
    final leftKey = yorksV1InventorySearchKey(left);
    final rightKey = yorksV1InventorySearchKey(right);
    if (leftKey.isEmpty || rightKey.isEmpty) return 0;
    if (leftKey == rightKey) return 1;
    final direct = _normalizedLevenshtein(leftKey, rightKey);
    final sortedLeft = _tokenKey(left);
    final sortedRight = _tokenKey(right);
    return math.max(direct, _normalizedLevenshtein(sortedLeft, sortedRight));
  }

  static String _tokenKey(String value) {
    final tokens =
        value
            .toLowerCase()
            .split(RegExp(r'[^a-z0-9]+'))
            .where((token) => token.isNotEmpty)
            .map(
              (token) => token.length > 3 && token.endsWith('s')
                  ? token.substring(0, token.length - 1)
                  : token,
            )
            .toList()
          ..sort();
    return tokens.join();
  }

  static double _normalizedLevenshtein(String left, String right) {
    final longest = math.max(left.length, right.length);
    if (longest == 0) return 1;
    final previous = List<int>.generate(right.length + 1, (index) => index);
    final current = List<int>.filled(right.length + 1, 0);
    for (var leftIndex = 1; leftIndex <= left.length; leftIndex++) {
      current[0] = leftIndex;
      for (var rightIndex = 1; rightIndex <= right.length; rightIndex++) {
        final substitution =
            previous[rightIndex - 1] +
            (left.codeUnitAt(leftIndex - 1) == right.codeUnitAt(rightIndex - 1)
                ? 0
                : 1);
        current[rightIndex] = math.min(
          math.min(previous[rightIndex] + 1, current[rightIndex - 1] + 1),
          substitution,
        );
      }
      for (var index = 0; index < previous.length; index++) {
        previous[index] = current[index];
      }
    }
    return 1 - (previous[right.length] / longest);
  }
}

class YorksV1InventoryWorkbookCodec {
  const YorksV1InventoryWorkbookCodec({
    this.matcher = const YorksV1InventoryCategoryMatcher(),
  });

  final YorksV1InventoryCategoryMatcher matcher;

  YorksV1InventoryImportPreview decode({
    required YorksV1InventorySelectedWorkbook workbook,
    required List<YorksV1InventoryCategory> categories,
    required List<YorksV1LogisticsInventoryItem> inventoryItems,
  }) {
    final lowerName = workbook.fileName.toLowerCase();
    final rows = lowerName.endsWith('.csv')
        ? _decodeCsv(workbook.bytes)
        : _decodeXlsx(workbook);
    return previewFromMatrix(
      fileName: workbook.fileName,
      matrix: rows,
      categories: categories,
      inventoryItems: inventoryItems,
    );
  }

  YorksV1InventoryImportPreview previewFromMatrix({
    required String fileName,
    required List<List<String>> matrix,
    required List<YorksV1InventoryCategory> categories,
    required List<YorksV1LogisticsInventoryItem> inventoryItems,
  }) {
    final mapping = _headerMapping(matrix);
    final rows = <_RawInventoryRow>[];
    for (
      var index = mapping.headerRowIndex + 1;
      index < matrix.length;
      index++
    ) {
      final source = matrix[index];
      if (source.every((value) => value.trim().isEmpty)) continue;
      rows.add(
        _RawInventoryRow(
          sourceRowNumber: index + 1,
          itemCode: mapping.value(source, 'itemCode'),
          description: mapping.value(source, 'description'),
          sourceCategory: mapping.value(source, 'category'),
          brandOrigin: mapping.value(source, 'brandOrigin'),
          unit: mapping.value(source, 'unit'),
          action: mapping.value(source, 'action'),
          quantity: mapping.value(source, 'quantity'),
          reason: mapping.value(source, 'reason'),
          minimumStock: mapping.value(source, 'minimumStock'),
          locationBin: mapping.value(source, 'locationBin'),
          notes: mapping.value(source, 'notes'),
        ),
      );
    }
    if (rows.isEmpty || rows.length > 5000) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    final codeCounts = <String, int>{};
    final identityCounts = <String, int>{};
    for (final row in rows) {
      final code = yorksV1InventorySearchKey(row.itemCode);
      if (code.isNotEmpty) codeCounts[code] = (codeCounts[code] ?? 0) + 1;
      final identity = _identity(row.description, row.brandOrigin, row.unit);
      identityCounts[identity] = (identityCounts[identity] ?? 0) + 1;
    }
    return YorksV1InventoryImportPreview(
      fileName: fileName,
      rows: [
        for (final row in rows)
          _validate(
            row,
            categories: categories,
            inventoryItems: inventoryItems,
            duplicateCode:
                (codeCounts[yorksV1InventorySearchKey(row.itemCode)] ?? 0) > 1,
            duplicateIdentity:
                (identityCounts[_identity(
                      row.description,
                      row.brandOrigin,
                      row.unit,
                    )] ??
                    0) >
                1,
          ),
      ],
    );
  }

  YorksV1InventoryImportPreview applyCategoryDecision({
    required YorksV1InventoryImportPreview preview,
    required String sourceCategory,
    String? categoryId,
    bool createNew = false,
  }) {
    final key = yorksV1InventorySearchKey(sourceCategory);
    final selectedName = createNew
        ? yorksV1InventoryCategoryDisplayName(sourceCategory)
        : null;
    return preview.copyWithRows([
      for (final row in preview.rows)
        if (row.categorySourceKey != key)
          row
        else
          row.copyWith(
            categoryId: categoryId,
            newCategoryName: selectedName,
            clearCategoryId: createNew,
            clearNewCategoryName: !createNew,
            issues: [
              for (final issue in row.issues)
                if (issue.code !=
                        YorksV1InventoryImportIssueCode
                            .categoryDecisionRequired &&
                    issue.code != YorksV1InventoryImportIssueCode.newCategory &&
                    issue.code != YorksV1InventoryImportIssueCode.aliasMapping)
                  issue,
              if (createNew)
                YorksV1InventoryImportIssue(
                  code: YorksV1InventoryImportIssueCode.newCategory,
                  detail: selectedName,
                  isWarning: true,
                )
              else
                const YorksV1InventoryImportIssue(
                  code: YorksV1InventoryImportIssueCode.aliasMapping,
                  isWarning: true,
                ),
            ],
          ),
    ]);
  }

  YorksV1InventoryImportRow _validate(
    _RawInventoryRow row, {
    required List<YorksV1InventoryCategory> categories,
    required List<YorksV1LogisticsInventoryItem> inventoryItems,
    required bool duplicateCode,
    required bool duplicateIdentity,
  }) {
    final issues = <YorksV1InventoryImportIssue>[];
    final action = YorksV1InventoryStockAction.parse(row.action);
    final quantity = double.tryParse(row.quantity);
    final minimum = row.minimumStock.isEmpty
        ? null
        : double.tryParse(row.minimumStock);
    final unit = _canonicalUnit(row.unit);
    final item = _matchItem(row, inventoryItems);
    if (row.description.isEmpty) {
      issues.add(
        const YorksV1InventoryImportIssue(
          code: YorksV1InventoryImportIssueCode.descriptionRequired,
        ),
      );
    }
    if (row.unit.isEmpty) {
      issues.add(
        const YorksV1InventoryImportIssue(
          code: YorksV1InventoryImportIssueCode.unitRequired,
        ),
      );
    } else if (unit == null) {
      issues.add(
        const YorksV1InventoryImportIssue(
          code: YorksV1InventoryImportIssueCode.unitNotAllowed,
        ),
      );
    }
    if (action == null) {
      issues.add(
        const YorksV1InventoryImportIssue(
          code: YorksV1InventoryImportIssueCode.stockActionInvalid,
        ),
      );
    }
    if (quantity == null || quantity < 0) {
      issues.add(
        const YorksV1InventoryImportIssue(
          code: YorksV1InventoryImportIssueCode.quantityInvalid,
        ),
      );
    } else if (action != null &&
        action != YorksV1InventoryStockAction.noStockChange &&
        quantity <= 0) {
      issues.add(
        const YorksV1InventoryImportIssue(
          code: YorksV1InventoryImportIssueCode.quantityMustBePositive,
        ),
      );
    } else if (action == YorksV1InventoryStockAction.noStockChange &&
        quantity != 0) {
      issues.add(
        const YorksV1InventoryImportIssue(
          code: YorksV1InventoryImportIssueCode.noStockChangeQuantityIgnored,
          isWarning: true,
        ),
      );
    }
    if (row.reason.isEmpty) {
      issues.add(
        const YorksV1InventoryImportIssue(
          code: YorksV1InventoryImportIssueCode.reasonRequired,
        ),
      );
    }
    if (row.minimumStock.isNotEmpty && (minimum == null || minimum < 0)) {
      issues.add(
        const YorksV1InventoryImportIssue(
          code: YorksV1InventoryImportIssueCode.minimumStockInvalid,
        ),
      );
    }
    if (duplicateCode && row.itemCode.isNotEmpty) {
      issues.add(
        const YorksV1InventoryImportIssue(
          code: YorksV1InventoryImportIssueCode.duplicateItemCode,
        ),
      );
    }
    if (duplicateIdentity && row.itemCode.isEmpty) {
      issues.add(
        const YorksV1InventoryImportIssue(
          code: YorksV1InventoryImportIssueCode.duplicateIdentity,
          isWarning: true,
        ),
      );
    }
    if (action == YorksV1InventoryStockAction.removeStock && item == null) {
      issues.add(
        const YorksV1InventoryImportIssue(
          code: YorksV1InventoryImportIssueCode.removeRequiresExistingItem,
        ),
      );
    }
    if (action == YorksV1InventoryStockAction.removeStock &&
        item != null &&
        quantity != null &&
        quantity > (double.tryParse(item.availableQuantity) ?? 0)) {
      issues.add(
        YorksV1InventoryImportIssue(
          code: YorksV1InventoryImportIssueCode.removeExceedsAvailable,
          detail: item.availableQuantity,
        ),
      );
    }
    if (action == YorksV1InventoryStockAction.openingBalance &&
        item != null &&
        (double.tryParse(item.onHandQuantity) ?? 0) > 0) {
      issues.add(
        const YorksV1InventoryImportIssue(
          code: YorksV1InventoryImportIssueCode.openingBalanceConflict,
        ),
      );
    }
    if (item != null &&
        unit != null &&
        yorksV1InventorySearchKey(item.unit) !=
            yorksV1InventorySearchKey(unit)) {
      issues.add(
        YorksV1InventoryImportIssue(
          code: YorksV1InventoryImportIssueCode.unitMismatch,
          detail: item.unit,
        ),
      );
    }

    String? categoryId;
    String? newCategoryName;
    List<YorksV1InventoryCategorySuggestion> suggestions = const [];
    if (row.sourceCategory.isEmpty) {
      categoryId = item?.categoryId;
      if (categoryId == null) {
        issues.add(
          const YorksV1InventoryImportIssue(
            code: YorksV1InventoryImportIssueCode.categoryRequired,
          ),
        );
      }
    } else if (matcher.exact(row.sourceCategory, categories)
        case final exact?) {
      categoryId = exact.id;
      if (yorksV1InventorySearchKey(row.sourceCategory) !=
          yorksV1InventorySearchKey(exact.name)) {
        issues.add(
          YorksV1InventoryImportIssue(
            code: YorksV1InventoryImportIssueCode.aliasMapping,
            detail: exact.name,
            isWarning: true,
          ),
        );
      }
    } else {
      suggestions = matcher.rank(row.sourceCategory, categories);
      if (suggestions.isNotEmpty && suggestions.first.score >= .55) {
        issues.add(
          const YorksV1InventoryImportIssue(
            code: YorksV1InventoryImportIssueCode.categoryDecisionRequired,
          ),
        );
      } else {
        newCategoryName = yorksV1InventoryCategoryDisplayName(
          row.sourceCategory,
        );
        issues.add(
          YorksV1InventoryImportIssue(
            code: YorksV1InventoryImportIssueCode.newCategory,
            detail: newCategoryName,
            isWarning: true,
          ),
        );
      }
    }
    return YorksV1InventoryImportRow(
      sourceRowNumber: row.sourceRowNumber,
      itemCode: row.itemCode,
      description: row.description,
      sourceCategory: row.sourceCategory,
      brandOrigin: row.brandOrigin,
      unit: unit ?? row.unit,
      stockAction: action,
      quantity: row.quantity,
      reason: row.reason,
      minimumStock: row.minimumStock,
      locationBin: row.locationBin,
      notes: row.notes,
      inventoryItemId: item?.id,
      categoryId: categoryId,
      newCategoryName: newCategoryName,
      suggestions: suggestions,
      issues: issues,
    );
  }

  static YorksV1LogisticsInventoryItem? _matchItem(
    _RawInventoryRow row,
    List<YorksV1LogisticsInventoryItem> inventoryItems,
  ) {
    final code = yorksV1InventorySearchKey(row.itemCode);
    if (code.isNotEmpty) {
      for (final item in inventoryItems) {
        if (yorksV1InventorySearchKey(item.itemCode ?? '') == code) return item;
      }
      return null;
    }
    final identity = _identity(row.description, row.brandOrigin, row.unit);
    for (final item in inventoryItems) {
      if (_identity(item.description, item.brandOrigin ?? '', item.unit) ==
          identity) {
        return item;
      }
    }
    return null;
  }

  static String _identity(String description, String brand, String unit) =>
      '${yorksV1InventorySearchKey(description)}|'
      '${yorksV1InventorySearchKey(brand)}|'
      '${yorksV1InventorySearchKey(unit)}';

  static String? _canonicalUnit(String value) {
    const allowed = {
      'nos': 'Nos',
      'meter': 'Meter',
      'cm': 'Cm',
      'length': 'Length',
      'set': 'Set',
      'pairs': 'Pairs',
      'roll': 'Roll',
      'box': 'Box',
    };
    return allowed[yorksV1InventorySearchKey(value)];
  }

  static List<List<String>> _decodeXlsx(
    YorksV1InventorySelectedWorkbook workbook,
  ) {
    final parsed = const YorksV1BoqWorkbookCodec().decode(
      bytes: workbook.bytes,
      fileName: workbook.fileName,
    );
    for (final sheet in parsed.sheets) {
      if (yorksV1InventorySearchKey(sheet.name) == 'inventoryimport') {
        return sheet.rows;
      }
    }
    return parsed.sheets.first.rows;
  }

  static List<List<String>> _decodeCsv(Uint8List bytes) {
    final text = utf8
        .decode(bytes, allowMalformed: false)
        .replaceFirst('\ufeff', '');
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    for (var index = 0; index < text.length; index++) {
      final char = text[index];
      if (quoted) {
        if (char == '"') {
          if (index + 1 < text.length && text[index + 1] == '"') {
            field.write('"');
            index++;
          } else {
            quoted = false;
          }
        } else {
          field.write(char);
        }
      } else if (char == '"' && field.isEmpty) {
        quoted = true;
      } else if (char == ',') {
        row.add(field.toString());
        field = StringBuffer();
      } else if (char == '\n' || char == '\r') {
        if (char == '\r' &&
            index + 1 < text.length &&
            text[index + 1] == '\n') {
          index++;
        }
        row.add(field.toString());
        field = StringBuffer();
        rows.add(row);
        row = <String>[];
      } else {
        field.write(char);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }

  static _HeaderMapping _headerMapping(List<List<String>> matrix) {
    for (var rowIndex = 0; rowIndex < math.min(10, matrix.length); rowIndex++) {
      final indexes = <String, int>{};
      for (var column = 0; column < matrix[rowIndex].length; column++) {
        final key = _headerKey(matrix[rowIndex][column]);
        final field = _headers[key];
        if (field != null) indexes[field] = column;
      }
      const required = {
        'description',
        'category',
        'unit',
        'action',
        'quantity',
        'reason',
      };
      if (indexes.keys.toSet().containsAll(required)) {
        return _HeaderMapping(headerRowIndex: rowIndex, indexes: indexes);
      }
    }
    throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
  }

  static String _headerKey(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\(optional\)'), '')
      .replaceAll('*', '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');

  static const _headers = {
    'itemcode': 'itemCode',
    'itemdescription': 'description',
    'category': 'category',
    'warehousecategory': 'category',
    'materialcategory': 'category',
    'brandorigin': 'brandOrigin',
    'unit': 'unit',
    'stockaction': 'action',
    'quantity': 'quantity',
    'qty': 'quantity',
    'reason': 'reason',
    'minimumstock': 'minimumStock',
    'locationbin': 'locationBin',
    'notes': 'notes',
  };
}

class _HeaderMapping {
  const _HeaderMapping({required this.headerRowIndex, required this.indexes});

  final int headerRowIndex;
  final Map<String, int> indexes;

  String value(List<String> row, String field) {
    final index = indexes[field];
    return index == null || index >= row.length ? '' : row[index].trim();
  }
}

class _RawInventoryRow {
  const _RawInventoryRow({
    required this.sourceRowNumber,
    required this.itemCode,
    required this.description,
    required this.sourceCategory,
    required this.brandOrigin,
    required this.unit,
    required this.action,
    required this.quantity,
    required this.reason,
    required this.minimumStock,
    required this.locationBin,
    required this.notes,
  });

  final int sourceRowNumber;
  final String itemCode;
  final String description;
  final String sourceCategory;
  final String brandOrigin;
  final String unit;
  final String action;
  final String quantity;
  final String reason;
  final String minimumStock;
  final String locationBin;
  final String notes;
}
