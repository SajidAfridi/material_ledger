import 'yorks_v1_item_description.dart';
import 'yorks_v1_logistics.dart';

enum YorksV1InventoryStockAction {
  openingBalance('opening_balance', 'Opening Balance'),
  addStock('add_stock', 'Add Stock'),
  removeStock('remove_stock', 'Remove Stock'),
  correctionIncrease('correction_increase', 'Correction (+)'),
  correctionDecrease('correction_decrease', 'Correction (-)'),
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

enum YorksV1InventoryImportStage {
  uploadFile,
  mapColumns,
  reviewValidate,
  supplierReceipt,
  importSummary,
}

/// Import-level attention that is not attributable to one workbook row.
/// Presentation layers map these stable codes to localized guidance.
enum YorksV1InventoryImportNoticeCode {
  openingBalanceAsOfDateRequired,
  workbookTreatedAsOpeningBalance,
}

const yorksV1InventoryControlledUnits = <String>[
  'Nos',
  'Meter',
  'Cm',
  'Length',
  'Set',
  'Pairs',
  'Roll',
  'Box',
  'Each',
  'Ton',
  'Boxes',
  'Kg',
  'Litre',
  'Pack',
  'Lot',
  'Mtr',
  'Cartridge',
  'Coil',
  'Cylinder',
  'Drum',
  'Sheet',
  'Tin',
];

enum YorksV1InventorySourceType {
  openingBalance('opening_balance', 'Opening Balance'),
  externalSupplier('external_supplier', 'External Supplier'),
  materialReturn('material_return', 'Material Return'),
  correction('correction', 'Correction'),
  internalTransfer('internal_transfer', 'Internal Transfer'),
  noStockChange('no_stock_change', 'No Stock Change');

  const YorksV1InventorySourceType(this.wireValue, this.displayName);

  final String wireValue;
  final String displayName;

  static YorksV1InventorySourceType? parse(String value) {
    final key = _searchKey(value);
    for (final type in values) {
      if (_searchKey(type.displayName) == key ||
          _searchKey(type.wireValue) == key) {
        return type;
      }
    }
    return null;
  }
}

/// The controlled R38.9 import fields. A mapping always identifies a source
/// column by its position; header text is evidence and is never used as a
/// mutable row key.
enum YorksV1InventoryControlledField {
  sequence('S:No', false, ['sno', 'serial', 'row']),
  itemCode('Item Code *', false, ['itemcode', 'sku', 'materialcode']),
  category('Category *', true, [
    'category',
    'warehousecategory',
    'materialcategory',
  ]),
  description('Item Description *', true, [
    'itemdescription',
    'description',
    'itemname',
    'materialdescription',
  ]),
  sizeText('Size (If Any)', false, ['size', 'sizetext', 'dimensions']),
  modelTag('Model / Tag', false, [
    'modeltag',
    'model',
    'equipmenttag',
    'modelreference',
  ]),
  serialNumber('Serial No', false, [
    'serialno',
    'serialnumber',
    'manufacturerserialnumber',
  ]),
  brandOrigin('Brand / Origin', false, [
    'brandorigin',
    'brand',
    'manufacturerorigin',
  ]),
  ralColour('RAL Colour', false, ['ralcolour', 'ralcolor', 'colour', 'color']),
  // Source is derived from Stock Action for the controlled Yorks import
  // format. Historical files containing this column remain readable as
  // evidence, but users must not add or maintain it in the template.
  sourceType('Source Type', false, ['sourcetype', 'source']),
  stockAction('Stock Action *', true, ['stockaction', 'action']),
  quantity('Quantity *', true, ['quantity', 'qty']),
  unit('Unit *', true, ['unit', 'uom', 'unitofmeasure']),
  // The streamlined controlled template has one optional Notes column. It is
  // used as the auditable reason only for stock-removing/correction actions;
  // older files with a dedicated Reason column remain readable.
  reason('Reason', false, ['reason', 'stockreason']),
  minimumStock('Minimum Stock', false, [
    'minimumstock',
    'minstock',
    'reorderlevel',
  ]),
  locationShelf('Location / Shelf', false, [
    'locationshelf',
    'locationbin',
    'warehousebin',
    'shelf',
  ]),
  externalSupplierName('External Supplier Name', false, [
    'externalsuppliername',
    'externalsupplier',
    'supplier',
    'suppliername',
    'vendor',
    'vendorname',
  ]),
  supplierReference('Supplier Reference / Delivery Note', false, [
    'supplierreferencedeliverynote',
    'supplierreference',
    'supplierref',
    'deliverynote',
    'deliverynoteno',
    'deliverynotenumber',
  ]),
  receivedDate('Received Date', false, [
    'receiveddate',
    'receivedon',
    'deliverydate',
  ]),
  notes('Notes', false, ['notes', 'comments']),
  unitPrice('Unit Price', false, ['unitprice', 'unitcost', 'price']),
  totalPrice('Total Price', false, ['totalprice', 'totalcost', 'linevalue']);

  const YorksV1InventoryControlledField(
    this.displayName,
    this.isRequired,
    this.headerAliases,
  );

  final String displayName;
  final bool isRequired;
  final List<String> headerAliases;

  bool recognizesHeader(String header) {
    final key = _headerSearchKey(header);
    return headerAliases.any((alias) => _headerSearchKey(alias) == key) ||
        _headerSearchKey(displayName) == key;
  }
}

enum YorksV1InventoryColumnMappingIssueCode {
  missingRequiredField,
  duplicateSourceColumn,
  ambiguousSourceHeader,
}

class YorksV1InventoryColumnMappingIssue {
  const YorksV1InventoryColumnMappingIssue({
    required this.code,
    this.field,
    this.sourceColumnIndex,
  });

  final YorksV1InventoryColumnMappingIssueCode code;
  final YorksV1InventoryControlledField? field;
  final int? sourceColumnIndex;
}

class YorksV1InventorySourceColumn {
  YorksV1InventorySourceColumn({
    required this.index,
    required this.header,
    required List<String> sampleValues,
  }) : sampleValues = List.unmodifiable(sampleValues);

  final int index;
  final String header;
  final List<String> sampleValues;
}

class YorksV1InventoryWorkbookSource {
  YorksV1InventoryWorkbookSource({
    required this.fileName,
    required this.fileSha256,
    required this.headerRowIndex,
    required List<YorksV1InventorySourceColumn> columns,
    required List<List<String>> dataRows,
    this.worksheetName,
    List<String> availableWorksheetNames = const [],
    List<int>? sourceRowNumbers,
  }) : columns = List.unmodifiable(columns),
       availableWorksheetNames = List.unmodifiable(availableWorksheetNames),
       dataRows = List.unmodifiable([
         for (final row in dataRows) List<String>.unmodifiable(row),
       ]),
       sourceRowNumbers = List.unmodifiable(
         sourceRowNumbers ??
             List<int>.generate(
               dataRows.length,
               (index) => headerRowIndex + index + 2,
             ),
       ) {
    if (this.sourceRowNumbers.length != this.dataRows.length) {
      throw ArgumentError('Every source row must retain its workbook row.');
    }
  }

  final String fileName;
  final String fileSha256;
  final String? worksheetName;
  final List<String> availableWorksheetNames;
  final int headerRowIndex;
  final List<YorksV1InventorySourceColumn> columns;
  final List<List<String>> dataRows;
  final List<int> sourceRowNumbers;

  int get rowCount => dataRows.length;
}

class YorksV1InventoryColumnMapping {
  YorksV1InventoryColumnMapping({
    required this.source,
    required Map<YorksV1InventoryControlledField, int> indexes,
    required List<YorksV1InventoryColumnMappingIssue> issues,
    this.requiresR38_9Fields = true,
    this.treatWorkbookAsOpeningBalance = false,
    List<YorksV1InventoryUnitMappingDecision> unitMappings = const [],
    List<YorksV1InventoryCellEdit> cellEdits = const [],
  }) : indexes = Map.unmodifiable(indexes),
       issues = List.unmodifiable(issues),
       unitMappings = List.unmodifiable(unitMappings),
       cellEdits = List.unmodifiable(cellEdits);

  final YorksV1InventoryWorkbookSource source;
  final Map<YorksV1InventoryControlledField, int> indexes;
  final List<YorksV1InventoryColumnMappingIssue> issues;
  final bool requiresR38_9Fields;
  final bool treatWorkbookAsOpeningBalance;
  final List<YorksV1InventoryUnitMappingDecision> unitMappings;
  final List<YorksV1InventoryCellEdit> cellEdits;

  bool get canContinue => issues.isEmpty;

  int? sourceIndex(YorksV1InventoryControlledField field) => indexes[field];

  List<String> samplesFor(YorksV1InventoryControlledField field) {
    final index = sourceIndex(field);
    if (index == null) return const [];
    for (final column in source.columns) {
      if (column.index == index) return column.sampleValues;
    }
    return const [];
  }

  String? controlledUnitFor(String sourceUnitText) {
    final key = yorksV1InventorySearchKey(sourceUnitText);
    for (final decision in unitMappings) {
      if (decision.sourceKey == key) return decision.controlledUnit;
    }
    return null;
  }

  YorksV1InventoryCellEdit? cellEditFor(
    int sourceRowNumber,
    YorksV1InventoryControlledField field,
  ) {
    for (final edit in cellEdits.reversed) {
      if (edit.sourceRowNumber == sourceRowNumber && edit.field == field) {
        return edit;
      }
    }
    return null;
  }
}

/// The deliberately narrow set of fields that may be corrected in the local
/// review draft. Quantity, unit, action, source type and prices are excluded;
/// their dedicated reviewed controls remain authoritative.
const yorksV1InventorySafeEditableFields = <YorksV1InventoryControlledField>{
  YorksV1InventoryControlledField.itemCode,
  YorksV1InventoryControlledField.category,
  YorksV1InventoryControlledField.description,
  YorksV1InventoryControlledField.sizeText,
  YorksV1InventoryControlledField.modelTag,
  YorksV1InventoryControlledField.serialNumber,
  YorksV1InventoryControlledField.brandOrigin,
  YorksV1InventoryControlledField.ralColour,
  YorksV1InventoryControlledField.reason,
  YorksV1InventoryControlledField.minimumStock,
  YorksV1InventoryControlledField.locationShelf,
  YorksV1InventoryControlledField.externalSupplierName,
  YorksV1InventoryControlledField.supplierReference,
  YorksV1InventoryControlledField.receivedDate,
  YorksV1InventoryControlledField.notes,
};

enum YorksV1InventoryCellEditOrigin { directEdit, searchAndReplace, safeFix }

class YorksV1InventoryCellEdit {
  const YorksV1InventoryCellEdit({
    required this.sourceRowNumber,
    required this.field,
    required this.originalValue,
    required this.value,
    required this.origin,
  });

  final int sourceRowNumber;
  final YorksV1InventoryControlledField field;
  final String originalValue;
  final String value;
  final YorksV1InventoryCellEditOrigin origin;
}

class YorksV1InventoryBulkEditResult {
  const YorksV1InventoryBulkEditResult({
    required this.mapping,
    required this.affectedRows,
  });

  final YorksV1InventoryColumnMapping mapping;
  final int affectedRows;
}

class YorksV1InventoryUnitMappingDecision {
  const YorksV1InventoryUnitMappingDecision({
    required this.sourceUnitText,
    required this.controlledUnit,
  });

  final String sourceUnitText;
  final String controlledUnit;

  String get sourceKey => yorksV1InventorySearchKey(sourceUnitText);
}

class YorksV1InventoryUnitReviewGroup {
  const YorksV1InventoryUnitReviewGroup({
    required this.sourceUnitText,
    required this.rowCount,
  });

  final String sourceUnitText;
  final int rowCount;
  String get sourceKey => yorksV1InventorySearchKey(sourceUnitText);
}

const yorksV1UnknownSupplierId = '00000000-0000-4000-8000-000000000389';
const yorksV1UnknownSupplierName = 'Unknown Supplier';

class YorksV1InventorySupplierMaster {
  YorksV1InventorySupplierMaster({
    required this.id,
    required this.name,
    this.isActive = true,
    this.isUnknownSupplier = false,
    List<String> aliases = const [],
  }) : aliases = List.unmodifiable(aliases);

  final String id;
  final String name;
  final bool isActive;
  final bool isUnknownSupplier;
  final List<String> aliases;
}

class YorksV1InventorySupplierSuggestion {
  const YorksV1InventorySupplierSuggestion({
    required this.supplier,
    required this.score,
  });

  final YorksV1InventorySupplierMaster supplier;
  final double score;
}

enum YorksV1InventorySupplierResolution { existing, createNew, unknownSupplier }

class YorksV1InventoryReceiptQuantities {
  const YorksV1InventoryReceiptQuantities({
    required this.accepted,
    required this.damaged,
    required this.rejected,
  });

  final String accepted;
  final String damaged;
  final String rejected;

  double? get delivered {
    final acceptedValue = double.tryParse(accepted);
    final damagedValue = double.tryParse(damaged);
    final rejectedValue = double.tryParse(rejected);
    if (acceptedValue == null ||
        damagedValue == null ||
        rejectedValue == null) {
      return null;
    }
    return acceptedValue + damagedValue + rejectedValue;
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
  duplicateSerialNumber,
  duplicateReceiptLine,
  duplicateIdentity,
  removeRequiresExistingItem,
  removeExceedsAvailable,
  openingBalanceConflict,
  unitMismatch,
  categoryRequired,
  categoryDecisionRequired,
  newCategory,
  aliasMapping,
  sourceTypeRequired,
  sourceTypeInvalid,
  sourceActionMismatch,
  sourceTypeDefaultedToOpeningBalance,
  stockActionNormalizedToOpeningBalance,
  unitMapped,
  supplierMissingUsesUnknown,
  supplierDecisionRequired,
  supplierAliasMapping,
  newSupplier,
  supplierInactive,
  supplierIntegrityConflict,
  supplierUnexpectedForSource,
  supplierReferenceRequired,
  receivedDateRequired,
  receivedDateInvalid,
  unitPriceInvalid,
  totalPriceMismatch,
  receiptQuantityInvalid,
  receiptQuantityMismatch,
  trackingModeInvalid,
  reviewEditApplied,
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
    required String description,
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
    required this.requiresCategoryDecision,
    required List<YorksV1InventoryCategorySuggestion> suggestions,
    required List<YorksV1InventoryImportIssue> issues,
    this.sizeText = '',
    this.modelTag = '',
    this.serialNumber = '',
    this.ralColour = '',
    this.rawSourceType = '',
    this.sourceTypeWasDefaulted = false,
    this.stockActionWasNormalized = false,
    this.sourceType,
    this.rawUnit = '',
    this.unitWasMapped = false,
    this.rawSupplierName = '',
    this.rawSupplierReference = '',
    this.rawReceivedDate = '',
    this.editedSupplierName,
    this.editedSupplierReference,
    this.editedReceivedDate,
    this.supplierId,
    this.canonicalSupplierName,
    this.newSupplierName,
    this.supplierResolution,
    this.requiresSupplierDecision = false,
    List<YorksV1InventorySupplierSuggestion> supplierSuggestions = const [],
    this.unitPrice = '',
    this.importedTotalPrice = '',
    this.calculatedTotalPrice,
    this.acceptedQuantity,
    this.damagedQuantity = '0',
    this.rejectedQuantity = '0',
    this.trackingMode = 'bulk',
    this.batchLotNumber = '',
    this.currencyCode = 'AED',
    this.rawSourceWorksheetName,
    List<String> rawSourceHeaders = const [],
    List<String> rawSourceValues = const [],
    List<YorksV1InventoryCellEdit> appliedCellEdits = const [],
  }) : description = normalizeYorksV1ItemDescription(description),
       suggestions = List.unmodifiable(suggestions),
       supplierSuggestions = List.unmodifiable(supplierSuggestions),
       rawSourceHeaders = List.unmodifiable(rawSourceHeaders),
       rawSourceValues = List.unmodifiable(rawSourceValues),
       appliedCellEdits = List.unmodifiable(appliedCellEdits),
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
  final String sizeText;
  final String modelTag;
  final String serialNumber;
  final String ralColour;
  final String rawSourceType;
  final bool sourceTypeWasDefaulted;
  final bool stockActionWasNormalized;
  final YorksV1InventorySourceType? sourceType;
  final String rawUnit;
  final bool unitWasMapped;
  final String rawSupplierName;
  final String rawSupplierReference;
  final String rawReceivedDate;
  final String? editedSupplierName;
  final String? editedSupplierReference;
  final String? editedReceivedDate;
  final String? supplierId;
  final String? canonicalSupplierName;
  final String? newSupplierName;
  final YorksV1InventorySupplierResolution? supplierResolution;
  final bool requiresSupplierDecision;
  final List<YorksV1InventorySupplierSuggestion> supplierSuggestions;
  final String unitPrice;
  final String importedTotalPrice;
  final String? calculatedTotalPrice;
  final String? acceptedQuantity;
  final String damagedQuantity;
  final String rejectedQuantity;
  final String trackingMode;
  final String batchLotNumber;
  final String currencyCode;
  final String? rawSourceWorksheetName;
  final List<String> rawSourceHeaders;
  final List<String> rawSourceValues;
  final List<YorksV1InventoryCellEdit> appliedCellEdits;
  final String? inventoryItemId;
  final String? categoryId;
  final String? newCategoryName;

  /// True when the source workbook category was neither an exact master name
  /// nor a saved alias. This remains true after Procurement makes a choice so
  /// the preview can keep that choice visible and reversible until commit.
  final bool requiresCategoryDecision;
  final List<YorksV1InventoryCategorySuggestion> suggestions;
  final List<YorksV1InventoryImportIssue> issues;

  bool get hasErrors => issues.any((issue) => !issue.isWarning);
  bool get hasWarnings => issues.any((issue) => issue.isWarning);
  bool get isNewItem => inventoryItemId == null;
  String get categorySourceKey => _searchKey(sourceCategory);
  String get supplierSourceText => editedSupplierName ?? rawSupplierName;
  String get supplierReference =>
      editedSupplierReference ?? rawSupplierReference;
  String get receivedDate => editedReceivedDate ?? rawReceivedDate;
  String get supplierSourceKey => _searchKey(supplierSourceText);
  bool get usesUnknownSupplier =>
      supplierResolution == YorksV1InventorySupplierResolution.unknownSupplier;
  bool get isReceiptAction =>
      stockAction == YorksV1InventoryStockAction.openingBalance ||
      stockAction == YorksV1InventoryStockAction.addStock;

  YorksV1InventoryReceiptQuantities get receiptQuantities =>
      YorksV1InventoryReceiptQuantities(
        accepted: acceptedQuantity ?? quantity,
        damaged: damagedQuantity,
        rejected: rejectedQuantity,
      );

  YorksV1InventoryImportRow copyWith({
    String? unit,
    String? categoryId,
    String? newCategoryName,
    bool? requiresCategoryDecision,
    bool clearCategoryId = false,
    bool clearNewCategoryName = false,
    List<YorksV1InventoryImportIssue>? issues,
    String? supplierId,
    String? canonicalSupplierName,
    String? newSupplierName,
    YorksV1InventorySupplierResolution? supplierResolution,
    bool? requiresSupplierDecision,
    List<YorksV1InventorySupplierSuggestion>? supplierSuggestions,
    bool clearSupplierId = false,
    bool clearCanonicalSupplierName = false,
    bool clearNewSupplierName = false,
    String? acceptedQuantity,
    String? damagedQuantity,
    String? rejectedQuantity,
  }) => YorksV1InventoryImportRow(
    sourceRowNumber: sourceRowNumber,
    itemCode: itemCode,
    description: description,
    sourceCategory: sourceCategory,
    brandOrigin: brandOrigin,
    unit: unit ?? this.unit,
    stockAction: stockAction,
    quantity: quantity,
    reason: reason,
    minimumStock: minimumStock,
    locationBin: locationBin,
    notes: notes,
    sizeText: sizeText,
    modelTag: modelTag,
    serialNumber: serialNumber,
    ralColour: ralColour,
    rawSourceType: rawSourceType,
    sourceTypeWasDefaulted: sourceTypeWasDefaulted,
    stockActionWasNormalized: stockActionWasNormalized,
    sourceType: sourceType,
    rawUnit: rawUnit,
    unitWasMapped: unitWasMapped,
    rawSupplierName: rawSupplierName,
    rawSupplierReference: rawSupplierReference,
    rawReceivedDate: rawReceivedDate,
    editedSupplierName: editedSupplierName,
    editedSupplierReference: editedSupplierReference,
    editedReceivedDate: editedReceivedDate,
    supplierId: clearSupplierId ? null : supplierId ?? this.supplierId,
    canonicalSupplierName: clearCanonicalSupplierName
        ? null
        : canonicalSupplierName ?? this.canonicalSupplierName,
    newSupplierName: clearNewSupplierName
        ? null
        : newSupplierName ?? this.newSupplierName,
    supplierResolution: supplierResolution ?? this.supplierResolution,
    requiresSupplierDecision:
        requiresSupplierDecision ?? this.requiresSupplierDecision,
    supplierSuggestions: supplierSuggestions ?? this.supplierSuggestions,
    unitPrice: unitPrice,
    importedTotalPrice: importedTotalPrice,
    calculatedTotalPrice: calculatedTotalPrice,
    acceptedQuantity: acceptedQuantity ?? this.acceptedQuantity,
    damagedQuantity: damagedQuantity ?? this.damagedQuantity,
    rejectedQuantity: rejectedQuantity ?? this.rejectedQuantity,
    trackingMode: trackingMode,
    batchLotNumber: batchLotNumber,
    currencyCode: currencyCode,
    rawSourceWorksheetName: rawSourceWorksheetName,
    rawSourceHeaders: rawSourceHeaders,
    rawSourceValues: rawSourceValues,
    appliedCellEdits: appliedCellEdits,
    inventoryItemId: inventoryItemId,
    categoryId: clearCategoryId ? null : categoryId ?? this.categoryId,
    newCategoryName: clearNewCategoryName
        ? null
        : newCategoryName ?? this.newCategoryName,
    requiresCategoryDecision:
        requiresCategoryDecision ?? this.requiresCategoryDecision,
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
          : sourceType == YorksV1InventorySourceType.externalSupplier
          ? acceptedQuantity ?? quantity
          : quantity,
      reason: reason,
      minimumStock: minimumStock,
      locationBin: locationBin,
      notes: notes,
    );
  }

  /// Rich R38.9 evidence for the supplier-aware transactional command. The
  /// legacy import RPC input above remains available during the rollout.
  Map<String, Object?> toR38_9RpcJson() {
    final action = stockAction;
    if (action == null || hasErrors) {
      throw StateError('The inventory import row is not ready to commit.');
    }
    return {
      ...toRpcInput().toRpcJson(),
      'source_type': sourceType?.wireValue,
      'source_type_text': rawSourceType,
      'size_text': _nullIfBlank(sizeText),
      'model_tag': _nullIfBlank(modelTag),
      'serial_number': _nullIfBlank(serialNumber),
      'ral_colour': _nullIfBlank(ralColour),
      'supplier_id': supplierId,
      'new_supplier_name': _nullIfBlank(newSupplierName),
      'external_supplier_name': _nullIfBlank(supplierSourceText),
      'supplier_name_snapshot': _nullIfBlank(
        canonicalSupplierName ?? newSupplierName ?? supplierSourceText,
      ),
      'source_supplier_text': _nullIfBlank(rawSupplierName),
      'supplier_reference': _nullIfBlank(supplierReference),
      'received_date': _nullIfBlank(receivedDate),
      'supplier_resolution': supplierResolution?.name,
      'delivered_quantity': isReceiptAction
          ? _decimalText(receiptQuantities.delivered)
          : quantity,
      'accepted_quantity': acceptedQuantity ?? quantity,
      'damaged_quantity': damagedQuantity,
      'rejected_quantity': rejectedQuantity,
      'tracking_mode': trackingMode,
      'batch_lot_number': _nullIfBlank(batchLotNumber),
      'unit_price': _nullIfBlank(unitPrice),
      'total_price': calculatedTotalPrice,
      'currency_code': currencyCode,
      'calculated_total_price': calculatedTotalPrice,
      'imported_total_price': _nullIfBlank(importedTotalPrice),
      'raw_source_values': {
        'worksheet_name': _nullIfBlank(rawSourceWorksheetName),
        'headers': rawSourceHeaders,
        'values': rawSourceValues,
        'decisions': {
          if (sourceTypeWasDefaulted)
            'source_type_default':
                YorksV1InventorySourceType.openingBalance.wireValue,
          if (stockActionWasNormalized)
            'stock_action_normalized_from':
                YorksV1InventoryStockAction.addStock.wireValue,
          if (unitWasMapped)
            'unit_mapping': {'source': rawUnit, 'controlled': unit},
          if (appliedCellEdits.isNotEmpty)
            'safe_cell_edits': {
              for (final edit in appliedCellEdits)
                edit.field.name: {
                  'source': edit.originalValue,
                  'replacement': edit.value,
                  'origin': edit.origin.name,
                },
            },
        },
      },
    };
  }
}

class YorksV1InventoryImportPreview {
  YorksV1InventoryImportPreview({
    required this.fileName,
    required List<YorksV1InventoryImportRow> rows,
    this.fileSha256,
    this.mapping,
    this.strictImport = true,
  }) : rows = List.unmodifiable(rows);

  final String fileName;
  final String? fileSha256;
  final YorksV1InventoryColumnMapping? mapping;
  final bool strictImport;
  final List<YorksV1InventoryImportRow> rows;

  int get rowCount => rows.length;
  int get newItemCount => rows.where((row) => row.isNewItem).length;
  int get existingItemCount => rowCount - newItemCount;
  int get errorCount => rows.where((row) => row.hasErrors).length;
  int get warningCount => rows.where((row) => row.hasWarnings).length;
  bool get canCommit => rows.isNotEmpty && errorCount == 0;
  bool get hasOpeningBalanceRows => rows.any(
    (row) =>
        row.sourceType == YorksV1InventorySourceType.openingBalance ||
        row.stockAction == YorksV1InventoryStockAction.openingBalance,
  );
  bool get requiresOpeningBalanceAsOfDate => hasOpeningBalanceRows;
  bool get treatsWorkbookAsOpeningBalance =>
      mapping?.treatWorkbookAsOpeningBalance == true;
  List<YorksV1InventoryImportNoticeCode> get noticeCodes => [
    if (hasOpeningBalanceRows)
      YorksV1InventoryImportNoticeCode.openingBalanceAsOfDateRequired,
    if (treatsWorkbookAsOpeningBalance)
      YorksV1InventoryImportNoticeCode.workbookTreatedAsOpeningBalance,
  ];
  List<YorksV1InventoryUnitReviewGroup> get unresolvedUnitGroups {
    final groups = <String, ({String sourceText, int rowCount})>{};
    for (final row in rows) {
      if (!row.issues.any(
        (issue) => issue.code == YorksV1InventoryImportIssueCode.unitNotAllowed,
      )) {
        continue;
      }
      final sourceText = row.rawUnit.isEmpty ? row.unit : row.rawUnit;
      final key = yorksV1InventorySearchKey(sourceText);
      final current = groups[key];
      groups[key] = (
        sourceText: current?.sourceText ?? sourceText,
        rowCount: (current?.rowCount ?? 0) + 1,
      );
    }
    return [
      for (final group in groups.values)
        YorksV1InventoryUnitReviewGroup(
          sourceUnitText: group.sourceText,
          rowCount: group.rowCount,
        ),
    ]..sort(
      (left, right) => left.sourceUnitText.compareTo(right.sourceUnitText),
    );
  }

  YorksV1InventoryImportPreview copyWithRows(
    List<YorksV1InventoryImportRow> nextRows,
  ) => YorksV1InventoryImportPreview(
    fileName: fileName,
    fileSha256: fileSha256,
    mapping: mapping,
    strictImport: strictImport,
    rows: nextRows,
  );

  Map<String, Object?> toR38_9RpcPayload({String? openingBalanceAsOfDate}) {
    final fingerprint = fileSha256?.toLowerCase();
    final normalizedAsOfDate = _nullIfBlank(openingBalanceAsOfDate);
    if (!strictImport ||
        !canCommit ||
        fingerprint == null ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint) ||
        (hasOpeningBalanceRows &&
            !yorksV1InventoryIsIsoDate(normalizedAsOfDate))) {
      throw StateError('The R38.9 inventory import is not ready to commit.');
    }
    return {
      'file_name': fileName.trim(),
      'file_sha256': fingerprint,
      'import_mode': 'strict',
      'opening_balance_as_of_date': normalizedAsOfDate,
      'rows': [for (final row in rows) row.toR38_9RpcJson()],
    };
  }
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

String? yorksV1InventoryCanonicalUnit(String value) {
  const allowed = {
    'nos': 'Nos',
    'meter': 'Meter',
    'cm': 'Cm',
    'length': 'Length',
    'set': 'Set',
    'pairs': 'Pairs',
    'roll': 'Roll',
    'box': 'Box',
    'each': 'Each',
    'ton': 'Ton',
    'tons': 'Ton',
    'boxes': 'Boxes',
    'kg': 'Kg',
    'kilogram': 'Kg',
    'kilograms': 'Kg',
    'pack': 'Pack',
    'litre': 'Litre',
    'litres': 'Litre',
    'lot': 'Lot',
    'mtr': 'Mtr',
    'cartridge': 'Cartridge',
    'coil': 'Coil',
    'cylinder': 'Cylinder',
    'drum': 'Drum',
    'sheet': 'Sheet',
    'tin': 'Tin',
  };
  return allowed[yorksV1InventorySearchKey(value)];
}

bool yorksV1InventoryIsUnknownSupplierText(String? value) {
  final key = yorksV1InventorySearchKey(value ?? '');
  return key.isEmpty ||
      key == 'unknown' ||
      key == 'unknownsupplier' ||
      key == 'na';
}

/// Returns an empty value for conventional "not available" placeholders.
///
/// A manufacturer serial is evidence supplied by the manufacturer; Yorks must
/// never invent one. Historical stock sheets commonly use values such as N/A
/// or a dash for an unknown serial. Those values mean the line is bulk stock,
/// while the untouched source cell remains available in raw import evidence.
String yorksV1InventoryNormalizeOptionalSerial(String? value) {
  final trimmed = value?.trim() ?? '';
  final key = yorksV1InventorySearchKey(trimmed);
  const absent = {'na', 'notapplicable', 'unknown', 'none', 'nil'};
  return key.isEmpty || absent.contains(key) ? '' : trimmed;
}

String yorksV1InventorySafeSpreadsheetText(String value) =>
    value.isNotEmpty && RegExp(r'^[=+\-@]').hasMatch(value) ? "'$value" : value;

bool yorksV1InventoryIsIsoDate(String? value) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})$',
  ).firstMatch(value?.trim() ?? '');
  if (match == null) return false;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (year < 1) return false;
  final parsed = DateTime.utc(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day;
}

String _headerSearchKey(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'\(optional\)'), '')
    .replaceAll('*', '')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '');

String? _nullIfBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _decimalText(double? value) {
  if (value == null || !value.isFinite) return null;
  final fixed = value.toStringAsFixed(6);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _searchKey(String value) => value.toLowerCase().replaceAll(
  RegExp(r'[^\p{L}\p{N}]+', unicode: true),
  '',
);
