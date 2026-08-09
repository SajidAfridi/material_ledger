import 'yorks_v1_logistics.dart';

enum YorksV1InventoryStockAction {
  openingBalance('opening_balance', 'Opening Balance'),
  addStock('add_stock', 'Add Stock'),
  removeStock('remove_stock', 'Remove Stock'),
  noStockChange('no_stock_change', 'No Stock Change');

  const YorksV1InventoryStockAction(this.wireValue, this.displayName);

  final String wireValue;
  final String displayName;

  static YorksV1InventoryStockAction? parse(String value) {
    final key = _searchKey(value);
    for (final action in values) {
      if (_searchKey(action.displayName) == key ||
          _searchKey(action.wireValue) == key) {
        return action;
      }
    }
    return null;
  }
}

enum YorksV1InventoryImportIssueCode {
  descriptionRequired,
  unitRequired,
  unitNotAllowed,
  stockActionInvalid,
  quantityInvalid,
  quantityMustBePositive,
  noStockChangeQuantityIgnored,
  reasonRequired,
  minimumStockInvalid,
  duplicateItemCode,
  duplicateIdentity,
  removeRequiresExistingItem,
  removeExceedsAvailable,
  openingBalanceConflict,
  unitMismatch,
  categoryRequired,
  categoryDecisionRequired,
  newCategory,
  aliasMapping,
}

class YorksV1InventoryImportIssue {
  const YorksV1InventoryImportIssue({
    required this.code,
    this.detail,
    this.isWarning = false,
  });

  final YorksV1InventoryImportIssueCode code;
  final String? detail;
  final bool isWarning;
}

class YorksV1InventoryCategorySuggestion {
  const YorksV1InventoryCategorySuggestion({
    required this.category,
    required this.score,
  });

  final YorksV1InventoryCategory category;
  final double score;
}

class YorksV1InventoryImportRow {
  YorksV1InventoryImportRow({
    required this.sourceRowNumber,
    required this.itemCode,
    required this.description,
    required this.sourceCategory,
    required this.brandOrigin,
    required this.unit,
    required this.stockAction,
    required this.quantity,
    required this.reason,
    required this.minimumStock,
    required this.locationBin,
    required this.notes,
    required this.inventoryItemId,
    required this.categoryId,
    required this.newCategoryName,
    required List<YorksV1InventoryCategorySuggestion> suggestions,
    required List<YorksV1InventoryImportIssue> issues,
  }) : suggestions = List.unmodifiable(suggestions),
       issues = List.unmodifiable(issues);

  final int sourceRowNumber;
  final String itemCode;
  final String description;
  final String sourceCategory;
  final String brandOrigin;
  final String unit;
  final YorksV1InventoryStockAction? stockAction;
  final String quantity;
  final String reason;
  final String minimumStock;
  final String locationBin;
  final String notes;
  final String? inventoryItemId;
  final String? categoryId;
  final String? newCategoryName;
  final List<YorksV1InventoryCategorySuggestion> suggestions;
  final List<YorksV1InventoryImportIssue> issues;

  bool get hasErrors => issues.any((issue) => !issue.isWarning);
  bool get hasWarnings => issues.any((issue) => issue.isWarning);
  bool get isNewItem => inventoryItemId == null;
  String get categorySourceKey => _searchKey(sourceCategory);

  YorksV1InventoryImportRow copyWith({
    String? categoryId,
    String? newCategoryName,
    bool clearCategoryId = false,
    bool clearNewCategoryName = false,
    List<YorksV1InventoryImportIssue>? issues,
  }) => YorksV1InventoryImportRow(
    sourceRowNumber: sourceRowNumber,
    itemCode: itemCode,
    description: description,
    sourceCategory: sourceCategory,
    brandOrigin: brandOrigin,
    unit: unit,
    stockAction: stockAction,
    quantity: quantity,
    reason: reason,
    minimumStock: minimumStock,
    locationBin: locationBin,
    notes: notes,
    inventoryItemId: inventoryItemId,
    categoryId: clearCategoryId ? null : categoryId ?? this.categoryId,
    newCategoryName: clearNewCategoryName
        ? null
        : newCategoryName ?? this.newCategoryName,
    suggestions: suggestions,
    issues: issues ?? this.issues,
  );

  YorksV1InventoryImportRowInput toRpcInput() {
    final action = stockAction;
    if (action == null || hasErrors) {
      throw StateError('The inventory import row is not ready to commit.');
    }
    return YorksV1InventoryImportRowInput(
      sourceRowNumber: sourceRowNumber,
      inventoryItemId: inventoryItemId,
      itemCode: itemCode,
      description: description,
      categoryId: categoryId,
      newCategoryName: newCategoryName,
      sourceCategoryText: sourceCategory,
      brandOrigin: brandOrigin,
      unit: unit,
      stockAction: action.wireValue,
      quantity: action == YorksV1InventoryStockAction.noStockChange
          ? '0'
          : quantity,
      reason: reason,
      minimumStock: minimumStock,
      locationBin: locationBin,
      notes: notes,
    );
  }
}

class YorksV1InventoryImportPreview {
  YorksV1InventoryImportPreview({
    required this.fileName,
    required List<YorksV1InventoryImportRow> rows,
  }) : rows = List.unmodifiable(rows);

  final String fileName;
  final List<YorksV1InventoryImportRow> rows;

  int get rowCount => rows.length;
  int get newItemCount => rows.where((row) => row.isNewItem).length;
  int get existingItemCount => rowCount - newItemCount;
  int get errorCount => rows.where((row) => row.hasErrors).length;
  int get warningCount => rows.where((row) => row.hasWarnings).length;
  bool get canCommit => rows.isNotEmpty && errorCount == 0;

  YorksV1InventoryImportPreview copyWithRows(
    List<YorksV1InventoryImportRow> nextRows,
  ) => YorksV1InventoryImportPreview(fileName: fileName, rows: nextRows);
}

String yorksV1InventoryCategoryDisplayName(String value) {
  final compact = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (compact.isEmpty) return '';
  const acronyms = {
    'ac',
    'hvac',
    'gi',
    'pvc',
    'sed',
    'red',
    'vcd',
    'fd',
    'fsd',
    'msfd',
    'mfd',
    'msd',
    'mvcd',
    'ahu',
    'fcu',
    'fahu',
    'vrf',
  };
  return compact
      .split(' ')
      .map((word) {
        final pieces = word.split('-');
        return pieces
            .map((piece) {
              final lower = piece.toLowerCase();
              if (acronyms.contains(lower)) return lower.toUpperCase();
              if (piece == '&' || piece.isEmpty) return piece;
              return '${lower[0].toUpperCase()}${lower.substring(1)}';
            })
            .join('-');
      })
      .join(' ');
}

String yorksV1InventorySearchKey(String value) => _searchKey(value);

String _searchKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
