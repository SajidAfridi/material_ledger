import 'yorks_v1_domain_error.dart';

/// Procurement/Admin-only supplier state. `identityMissing` is reserved for
/// the immutable system Unknown Supplier folder.
enum YorksV1InventorySupplierStatus {
  active('active'),
  review('review'),
  inactive('inactive'),
  identityMissing('identity_missing');

  const YorksV1InventorySupplierStatus(this.wireValue);

  final String wireValue;

  static YorksV1InventorySupplierStatus? fromWire(Object? value) {
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }
}

enum YorksV1InventorySupplierFolderSection {
  overview('overview'),
  itemsReceived('items_received'),
  receiptBatches('receipt_batches'),
  documents('documents'),
  destinations('destinations'),
  activityAudit('activity_audit');

  const YorksV1InventorySupplierFolderSection(this.wireValue);

  final String wireValue;
}

enum YorksV1InventorySupplierItemTrailSection {
  receiptLines('receipt_lines'),
  movements('movements'),
  reservations('reservations'),
  destinations('destinations'),
  provenanceGaps('provenance_gaps'),
  activity('activity');

  const YorksV1InventorySupplierItemTrailSection(this.wireValue);

  final String wireValue;

  static YorksV1InventorySupplierItemTrailSection? fromWire(Object? value) {
    for (final section in values) {
      if (section.wireValue == value) return section;
    }
    return null;
  }
}

enum YorksV1InventorySupplierReceiptBatchDetailSection {
  lines('lines'),
  documents('documents'),
  activity('activity');

  const YorksV1InventorySupplierReceiptBatchDetailSection(this.wireValue);

  final String wireValue;

  static YorksV1InventorySupplierReceiptBatchDetailSection? fromWire(
    Object? value,
  ) {
    for (final section in values) {
      if (section.wireValue == value) return section;
    }
    return null;
  }
}

class YorksV1InventorySupplierDirectorySummary {
  const YorksV1InventorySupplierDirectorySummary({
    required this.activeSuppliers,
    required this.receiptBatches,
    required this.distinctItems,
    required this.documentsMissing,
    required this.inactiveOrReview,
    required this.identityMissing,
  });

  final int activeSuppliers;
  final int receiptBatches;
  final int distinctItems;
  final int documentsMissing;
  final int inactiveOrReview;
  final int identityMissing;

  factory YorksV1InventorySupplierDirectorySummary.fromJson(
    Map<String, dynamic> json,
  ) => YorksV1InventorySupplierDirectorySummary(
    activeSuppliers: _nonNegativeInt(json['active_suppliers']),
    receiptBatches: _nonNegativeInt(json['receipt_batches']),
    distinctItems: _nonNegativeInt(json['distinct_items']),
    documentsMissing: _nonNegativeInt(json['documents_missing']),
    inactiveOrReview: _nonNegativeInt(json['inactive_or_review']),
    identityMissing: _nonNegativeInt(json['identity_missing']),
  );
}

class YorksV1InventorySupplierDirectoryEntry {
  YorksV1InventorySupplierDirectoryEntry({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.status,
    required this.isSystemUnknown,
    required this.receiptBatchCount,
    required this.distinctItemCount,
    required this.missingDocumentCount,
    required this.reconciliationCount,
    required this.lastReceiptAt,
    required List<String> aliases,
    required this.recordVersion,
  }) : aliases = List.unmodifiable(aliases);

  final String id;
  final String code;
  final String name;
  final String? description;
  final YorksV1InventorySupplierStatus status;
  final bool isSystemUnknown;
  final int receiptBatchCount;
  final int distinctItemCount;
  final int missingDocumentCount;
  final int reconciliationCount;
  final DateTime? lastReceiptAt;
  final List<String> aliases;
  final int recordVersion;

  factory YorksV1InventorySupplierDirectoryEntry.fromJson(
    Map<String, dynamic> json,
  ) {
    final status = YorksV1InventorySupplierStatus.fromWire(json['status']);
    if (status == null) _unexpected();
    return YorksV1InventorySupplierDirectoryEntry(
      id: _requiredString(json, 'id'),
      code: _requiredString(json, 'supplier_code'),
      name: _requiredString(json, 'canonical_name'),
      description: _nullableString(json['description']),
      status: status,
      isSystemUnknown: json['is_system_unknown'] == true,
      receiptBatchCount: _nonNegativeInt(json['receipt_batch_count']),
      distinctItemCount: _nonNegativeInt(json['distinct_item_count']),
      missingDocumentCount: _nonNegativeInt(json['missing_document_count']),
      reconciliationCount: _nonNegativeInt(json['reconciliation_count']),
      lastReceiptAt: _nullableDate(json['last_receipt_at']),
      aliases: _stringList(json['aliases']),
      recordVersion: _positiveInt(json['record_version']),
    );
  }
}

class YorksV1InventorySupplierDirectoryWorkspace {
  YorksV1InventorySupplierDirectoryWorkspace({
    required this.summary,
    required List<YorksV1InventorySupplierUnitTotal> unitTotals,
    required List<YorksV1InventorySupplierDirectoryEntry> suppliers,
    required this.totalCount,
    required this.limit,
    required this.offset,
  }) : unitTotals = List.unmodifiable(unitTotals),
       suppliers = List.unmodifiable(suppliers);

  final YorksV1InventorySupplierDirectorySummary summary;
  final List<YorksV1InventorySupplierUnitTotal> unitTotals;
  final List<YorksV1InventorySupplierDirectoryEntry> suppliers;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + suppliers.length < totalCount;

  factory YorksV1InventorySupplierDirectoryWorkspace.fromJson(
    Map<String, dynamic> json,
  ) => YorksV1InventorySupplierDirectoryWorkspace(
    summary: YorksV1InventorySupplierDirectorySummary.fromJson(
      _requiredObject(json, 'summary'),
    ),
    unitTotals: _objectList(
      json['unit_totals'],
    ).map(YorksV1InventorySupplierUnitTotal.fromJson).toList(),
    suppliers: _objectList(
      json['suppliers'],
    ).map(YorksV1InventorySupplierDirectoryEntry.fromJson).toList(),
    totalCount: _nonNegativeInt(json['total_count']),
    limit: _positiveInt(json['limit']),
    offset: _nonNegativeInt(json['offset']),
  );
}

class YorksV1InventorySupplierUnitTotal {
  const YorksV1InventorySupplierUnitTotal({
    required this.unit,
    required this.acceptedQuantity,
    required this.damagedQuantity,
    required this.rejectedQuantity,
    this.deliveredQuantity,
  });

  final String unit;
  final String? deliveredQuantity;
  final String acceptedQuantity;
  final String damagedQuantity;
  final String rejectedQuantity;

  factory YorksV1InventorySupplierUnitTotal.fromJson(
    Map<String, dynamic> json,
  ) => YorksV1InventorySupplierUnitTotal(
    unit: _requiredString(json, 'unit'),
    deliveredQuantity: json['delivered_quantity'] == null
        ? null
        : _quantityString(json['delivered_quantity']),
    acceptedQuantity: _quantityString(
      json['accepted_quantity'] ?? json['accepted_qty'],
    ),
    damagedQuantity: _quantityString(
      json['damaged_quantity'] ?? json['damaged_qty'],
    ),
    rejectedQuantity: _quantityString(
      json['rejected_quantity'] ?? json['rejected_qty'],
    ),
  );
}

class YorksV1InventorySupplierItemReceipt {
  const YorksV1InventorySupplierItemReceipt({
    required this.inventoryItemId,
    required this.itemCode,
    required this.description,
    required this.size,
    required this.modelTag,
    required this.unit,
    required this.acceptedQuantity,
    required this.currentOnHand,
    required this.receiptBatchCount,
    required this.lastReceiptAt,
  });

  final String inventoryItemId;
  final String itemCode;
  final String description;
  final String? size;
  final String? modelTag;
  final String unit;
  final String acceptedQuantity;
  final String currentOnHand;
  final int receiptBatchCount;
  final DateTime? lastReceiptAt;

  factory YorksV1InventorySupplierItemReceipt.fromJson(
    Map<String, dynamic> json,
  ) => YorksV1InventorySupplierItemReceipt(
    inventoryItemId: _requiredString(json, 'inventory_item_id'),
    itemCode: _requiredString(json, 'item_code'),
    description: _requiredString(json, 'item_description'),
    size: _nullableString(json['size']),
    modelTag: _nullableString(json['model_tag']),
    unit: _requiredString(json, 'unit'),
    acceptedQuantity: _quantityString(json['accepted_quantity']),
    currentOnHand: _quantityString(json['current_on_hand']),
    receiptBatchCount: _nonNegativeInt(json['receipt_batch_count']),
    lastReceiptAt: _nullableDate(json['last_receipt_at']),
  );
}

class YorksV1InventorySupplierReceiptBatch {
  YorksV1InventorySupplierReceiptBatch({
    required this.id,
    required this.receiptNumber,
    required this.sourceType,
    required this.supplierReference,
    required this.receivedDate,
    required this.location,
    required this.status,
    required this.lineCount,
    required this.documentCount,
    required this.deliveredQuantity,
    required this.acceptedQuantity,
    required this.damagedQuantity,
    required this.rejectedQuantity,
    required this.unit,
    required this.receivedByDisplayName,
    required this.createdAt,
    List<YorksV1InventorySupplierUnitTotal> unitTotals = const [],
  }) : unitTotals = List.unmodifiable(unitTotals);

  final String id;
  final String receiptNumber;
  final String sourceType;
  final String? supplierReference;
  final DateTime receivedDate;
  final String location;
  final String status;
  final int lineCount;
  final int documentCount;
  final String deliveredQuantity;
  final String acceptedQuantity;
  final String damagedQuantity;
  final String rejectedQuantity;
  final String unit;
  final String receivedByDisplayName;
  final DateTime createdAt;
  final List<YorksV1InventorySupplierUnitTotal> unitTotals;

  bool get hasMultipleUnits => unitTotals.length > 1;

  factory YorksV1InventorySupplierReceiptBatch.fromJson(
    Map<String, dynamic> json,
  ) {
    final unitTotals = _objectList(
      json['unit_totals'],
    ).map(YorksV1InventorySupplierUnitTotal.fromJson).toList(growable: false);
    final singleUnit = unitTotals.length == 1 ? unitTotals.single : null;
    String legacyQuantity(String key, String? nestedValue) {
      if (json[key] != null) return _quantityString(json[key]);
      return nestedValue ?? '—';
    }

    return YorksV1InventorySupplierReceiptBatch(
      id: _requiredString(json, 'id'),
      receiptNumber: _requiredString(json, 'receipt_number'),
      sourceType: _requiredString(json, 'source_type'),
      supplierReference: _nullableString(json['supplier_reference']),
      receivedDate: _requiredDate(json, 'received_date'),
      location: _requiredString(json, 'warehouse_location'),
      status: _requiredString(json, 'status'),
      lineCount: _positiveInt(json['line_count']),
      documentCount: _nonNegativeInt(json['document_count']),
      deliveredQuantity: legacyQuantity(
        'delivered_quantity',
        singleUnit?.deliveredQuantity,
      ),
      acceptedQuantity: legacyQuantity(
        'accepted_quantity',
        singleUnit?.acceptedQuantity,
      ),
      damagedQuantity: legacyQuantity(
        'damaged_quantity',
        singleUnit?.damagedQuantity,
      ),
      rejectedQuantity: legacyQuantity(
        'rejected_quantity',
        singleUnit?.rejectedQuantity,
      ),
      unit: json['unit'] == null
          ? (singleUnit?.unit ?? 'Multiple units')
          : _requiredString(json, 'unit'),
      receivedByDisplayName: _requiredString(json, 'received_by_display_name'),
      createdAt: _requiredDate(json, 'created_at'),
      unitTotals: unitTotals,
    );
  }
}

class YorksV1InventorySupplierDocument {
  const YorksV1InventorySupplierDocument({
    required this.documentId,
    required this.versionId,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.revisionNumber,
    required this.classification,
    required this.uploadedAt,
    required this.uploadedByDisplayName,
    required this.receiptBatchId,
  });

  final String documentId;
  final String versionId;
  final String fileName;
  final String mimeType;
  final int byteSize;
  final int revisionNumber;
  final String classification;
  final DateTime uploadedAt;
  final String uploadedByDisplayName;
  final String? receiptBatchId;

  factory YorksV1InventorySupplierDocument.fromJson(
    Map<String, dynamic> json,
  ) => YorksV1InventorySupplierDocument(
    documentId: _requiredString(json, 'document_id'),
    versionId: _requiredString(json, 'version_id'),
    fileName: _requiredString(json, 'file_name'),
    mimeType: _requiredString(json, 'mime_type'),
    byteSize: _positiveInt(json['byte_size']),
    revisionNumber: _positiveInt(json['revision_number']),
    classification: _requiredString(json, 'classification'),
    uploadedAt: _requiredDate(json, 'uploaded_at'),
    uploadedByDisplayName: _requiredString(json, 'uploaded_by_display_name'),
    receiptBatchId: _nullableString(json['receipt_batch_id']),
  );
}

class YorksV1InventorySupplierDestination {
  const YorksV1InventorySupplierDestination({
    required this.id,
    required this.supplierId,
    required this.inventoryItemId,
    required this.receiptLineId,
    required this.receiptBatchId,
    required this.dispatchLineId,
    required this.dispatchId,
    required this.requestId,
    required this.projectId,
    required this.scopeId,
    required this.itemDescription,
    required this.quantity,
    required this.unit,
    required this.projectReference,
    required this.projectName,
    required this.scopeName,
    required this.requestNumber,
    required this.dispatchNumber,
    required this.state,
    required this.dispatchedAt,
    this.receiptReviewId,
    this.materialReturnIds = const [],
    this.receiptOutcome,
    this.goodReceivedQuantity = '0',
    this.exceptionQuantity = '0',
    this.confirmedReturnQuantity = '0',
    this.provenanceState = 'receipt_pending',
    this.provenanceReason,
    this.dispatchGapQuantity = '0',
    this.unprovenGoodQuantity = '0',
    this.unprovenExceptionQuantity = '0',
    this.unprovenReturnQuantity = '0',
  });

  final String id;
  final String supplierId;
  final String inventoryItemId;
  final String receiptLineId;
  final String receiptBatchId;
  final String dispatchLineId;
  final String dispatchId;
  final String requestId;
  final String projectId;
  final String scopeId;
  final String itemDescription;
  final String quantity;
  final String unit;
  final String projectReference;
  final String projectName;
  final String scopeName;
  final String requestNumber;
  final String dispatchNumber;
  final String state;
  final DateTime dispatchedAt;
  final String? receiptReviewId;
  final List<String> materialReturnIds;
  final String? receiptOutcome;
  final String goodReceivedQuantity;
  final String exceptionQuantity;
  final String confirmedReturnQuantity;
  final String provenanceState;
  final String? provenanceReason;
  final String dispatchGapQuantity;
  final String unprovenGoodQuantity;
  final String unprovenExceptionQuantity;
  final String unprovenReturnQuantity;

  factory YorksV1InventorySupplierDestination.fromJson(
    Map<String, dynamic> json,
  ) => YorksV1InventorySupplierDestination(
    id: _requiredString(json, 'id'),
    supplierId: _requiredString(json, 'supplier_id'),
    inventoryItemId: _requiredString(json, 'inventory_item_id'),
    receiptLineId: _requiredString(json, 'receipt_line_id'),
    receiptBatchId: _requiredString(json, 'receipt_batch_id'),
    dispatchLineId: _requiredString(json, 'dispatch_line_id'),
    dispatchId: _requiredString(json, 'dispatch_id'),
    requestId: _requiredString(json, 'request_id'),
    projectId: _requiredString(json, 'project_id'),
    scopeId: _requiredString(json, 'scope_id'),
    itemDescription: _requiredString(json, 'item_description'),
    quantity: _quantityString(json['quantity']),
    unit: _requiredString(json, 'unit'),
    projectReference: _requiredString(json, 'project_reference'),
    projectName: _requiredString(json, 'project_name'),
    scopeName: _requiredString(json, 'scope_name'),
    requestNumber: _requiredString(json, 'request_number'),
    dispatchNumber: _requiredString(json, 'dispatch_number'),
    state: _requiredString(json, 'state'),
    dispatchedAt: _requiredDate(json, 'dispatched_at'),
    receiptReviewId: _nullableString(json['receipt_review_id']),
    materialReturnIds: _stringList(json['material_return_ids']),
    receiptOutcome: _nullableString(json['receipt_outcome']),
    goodReceivedQuantity: _quantityString(
      json['good_received_quantity'] ?? '0',
    ),
    exceptionQuantity: _quantityString(json['exception_quantity'] ?? '0'),
    confirmedReturnQuantity: _quantityString(
      json['confirmed_return_quantity'] ?? '0',
    ),
    provenanceState:
        _nullableString(json['provenance_state']) ?? 'receipt_pending',
    provenanceReason: _nullableString(json['provenance_reason']),
    dispatchGapQuantity: _quantityString(json['dispatch_gap_quantity'] ?? '0'),
    unprovenGoodQuantity: _quantityString(
      json['unproven_good_quantity'] ?? '0',
    ),
    unprovenExceptionQuantity: _quantityString(
      json['unproven_exception_quantity'] ?? '0',
    ),
    unprovenReturnQuantity: _quantityString(
      json['unproven_return_quantity'] ?? '0',
    ),
  );
}

class YorksV1InventorySupplierActivity {
  const YorksV1InventorySupplierActivity({
    required this.id,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.actorDisplayName,
    required this.actorRole,
    required this.reason,
    required this.occurredAt,
  });

  final String id;
  final String eventType;
  final String entityType;
  final String entityId;
  final String actorDisplayName;
  final String actorRole;
  final String? reason;
  final DateTime occurredAt;

  factory YorksV1InventorySupplierActivity.fromJson(
    Map<String, dynamic> json,
  ) => YorksV1InventorySupplierActivity(
    id: _requiredString(json, 'id'),
    eventType: _requiredString(json, 'event_type'),
    entityType: _requiredString(json, 'entity_type'),
    entityId: _requiredString(json, 'entity_id'),
    actorDisplayName: _requiredString(json, 'actor_display_name'),
    actorRole: _requiredString(json, 'actor_role'),
    reason: _nullableString(json['reason']),
    occurredAt: _requiredDate(json, 'occurred_at'),
  );
}

class YorksV1InventorySupplierFolderWorkspace {
  YorksV1InventorySupplierFolderWorkspace({
    required this.supplier,
    required List<YorksV1InventorySupplierUnitTotal> unitTotals,
    required List<YorksV1InventorySupplierItemReceipt> items,
    required List<YorksV1InventorySupplierReceiptBatch> batches,
    required List<YorksV1InventorySupplierDocument> documents,
    required List<YorksV1InventorySupplierDestination> destinations,
    required List<YorksV1InventorySupplierActivity> activity,
    required this.totalCount,
    required this.limit,
    required this.offset,
  }) : unitTotals = List.unmodifiable(unitTotals),
       items = List.unmodifiable(items),
       batches = List.unmodifiable(batches),
       documents = List.unmodifiable(documents),
       destinations = List.unmodifiable(destinations),
       activity = List.unmodifiable(activity);

  final YorksV1InventorySupplierDirectoryEntry supplier;
  final List<YorksV1InventorySupplierUnitTotal> unitTotals;
  final List<YorksV1InventorySupplierItemReceipt> items;
  final List<YorksV1InventorySupplierReceiptBatch> batches;
  final List<YorksV1InventorySupplierDocument> documents;
  final List<YorksV1InventorySupplierDestination> destinations;
  final List<YorksV1InventorySupplierActivity> activity;
  final int totalCount;
  final int limit;
  final int offset;

  factory YorksV1InventorySupplierFolderWorkspace.fromJson(
    Map<String, dynamic> json,
  ) => YorksV1InventorySupplierFolderWorkspace(
    supplier: YorksV1InventorySupplierDirectoryEntry.fromJson(
      _requiredObject(json, 'supplier'),
    ),
    unitTotals: _objectList(
      json['unit_totals'],
    ).map(YorksV1InventorySupplierUnitTotal.fromJson).toList(),
    items: _objectList(
      json['items'],
    ).map(YorksV1InventorySupplierItemReceipt.fromJson).toList(),
    batches: _objectList(
      json['batches'],
    ).map(YorksV1InventorySupplierReceiptBatch.fromJson).toList(),
    documents: _objectList(
      json['documents'],
    ).map(YorksV1InventorySupplierDocument.fromJson).toList(),
    destinations: _objectList(
      json['destinations'],
    ).map(YorksV1InventorySupplierDestination.fromJson).toList(),
    activity: _objectList(
      json['activity'],
    ).map(YorksV1InventorySupplierActivity.fromJson).toList(),
    totalCount: _nonNegativeInt(json['total_count']),
    limit: _positiveInt(json['limit']),
    offset: _nonNegativeInt(json['offset']),
  );
}

/// One inventory item as seen inside a Procurement/Admin-only supplier trail.
/// The quantities are server-formatted decimals so the client never performs
/// authoritative stock arithmetic with binary doubles.
class YorksV1InventorySupplierTrailItem {
  const YorksV1InventorySupplierTrailItem({
    required this.id,
    required this.itemCode,
    required this.description,
    required this.brandOrigin,
    required this.size,
    required this.modelTag,
    required this.unit,
    required this.currentOnHand,
    required this.reservedQuantity,
    required this.availableQuantity,
  });

  final String id;
  final String itemCode;
  final String description;
  final String? brandOrigin;
  final String? size;
  final String? modelTag;
  final String unit;
  final String currentOnHand;
  final String reservedQuantity;
  final String availableQuantity;

  factory YorksV1InventorySupplierTrailItem.fromJson(
    Map<String, dynamic> json,
  ) => YorksV1InventorySupplierTrailItem(
    id: _requiredString(json, 'id'),
    itemCode: _requiredString(json, 'item_code'),
    description: _requiredString(json, 'item_description'),
    brandOrigin: _nullableString(json['brand_origin']),
    size: _nullableString(json['size']),
    modelTag: _nullableString(json['model_tag']),
    unit: _requiredString(json, 'unit'),
    currentOnHand: _quantityString(json['current_on_hand']),
    reservedQuantity: _quantityString(json['reserved_quantity']),
    availableQuantity: _quantityString(json['available_quantity']),
  );
}

class YorksV1InventorySupplierTrailReceiptLine {
  const YorksV1InventorySupplierTrailReceiptLine({
    required this.id,
    required this.receiptBatchId,
    required this.receiptNumber,
    required this.sourceType,
    required this.supplierReference,
    required this.receivedDate,
    required this.location,
    required this.sourceRowNumber,
    required this.deliveredQuantity,
    required this.acceptedQuantity,
    required this.damagedQuantity,
    required this.rejectedQuantity,
    required this.allocatedQuantity,
    required this.remainingAcceptedQuantity,
    required this.unit,
    required this.trackingMode,
    required this.serialNumber,
    required this.batchLotNumber,
    this.returnedQuantity = '0',
  });

  final String id;
  final String receiptBatchId;
  final String receiptNumber;
  final String sourceType;
  final String supplierReference;
  final DateTime receivedDate;
  final String location;
  final int sourceRowNumber;
  final String deliveredQuantity;
  final String acceptedQuantity;
  final String damagedQuantity;
  final String rejectedQuantity;
  final String allocatedQuantity;
  final String returnedQuantity;
  final String remainingAcceptedQuantity;
  final String unit;
  final String trackingMode;
  final String? serialNumber;
  final String? batchLotNumber;

  factory YorksV1InventorySupplierTrailReceiptLine.fromJson(
    Map<String, dynamic> json,
  ) => YorksV1InventorySupplierTrailReceiptLine(
    id: _requiredString(json, 'id'),
    receiptBatchId: _requiredString(json, 'receipt_batch_id'),
    receiptNumber: _requiredString(json, 'receipt_number'),
    sourceType: _requiredString(json, 'source_type'),
    supplierReference: _requiredString(json, 'supplier_reference'),
    receivedDate: _requiredDate(json, 'received_date'),
    location: _requiredString(json, 'warehouse_location'),
    sourceRowNumber: _positiveInt(json['source_row_number']),
    deliveredQuantity: _quantityString(json['delivered_quantity']),
    acceptedQuantity: _quantityString(json['accepted_quantity']),
    damagedQuantity: _quantityString(json['damaged_quantity']),
    rejectedQuantity: _quantityString(json['rejected_quantity']),
    allocatedQuantity: _quantityString(json['allocated_quantity']),
    returnedQuantity: _quantityString(json['returned_quantity'] ?? '0'),
    remainingAcceptedQuantity: _quantityString(
      json['remaining_accepted_quantity'],
    ),
    unit: _requiredString(json, 'unit'),
    trackingMode: _requiredString(json, 'tracking_mode'),
    serialNumber: _nullableString(json['serial_number']),
    batchLotNumber: _nullableString(json['batch_lot_number']),
  );
}

class YorksV1InventorySupplierTrailMovement {
  const YorksV1InventorySupplierTrailMovement({
    required this.id,
    required this.movementType,
    required this.quantityDelta,
    required this.onHandAfterQuantity,
    required this.sourceEntityType,
    required this.sourceEntityId,
    required this.reason,
    required this.actorDisplayName,
    required this.createdAt,
  });

  final String id;
  final String movementType;
  final String quantityDelta;
  final String onHandAfterQuantity;
  final String? sourceEntityType;
  final String? sourceEntityId;
  final String reason;
  final String actorDisplayName;
  final DateTime createdAt;

  factory YorksV1InventorySupplierTrailMovement.fromJson(
    Map<String, dynamic> json,
  ) => YorksV1InventorySupplierTrailMovement(
    id: _requiredString(json, 'id'),
    movementType: _requiredString(json, 'movement_type'),
    quantityDelta: _quantityString(json['quantity_delta']),
    onHandAfterQuantity: _quantityString(json['on_hand_after_quantity']),
    sourceEntityType: _nullableString(json['source_entity_type']),
    sourceEntityId: _nullableString(json['source_entity_id']),
    reason: _requiredString(json, 'reason'),
    actorDisplayName: _requiredString(json, 'actor_display_name'),
    createdAt: _requiredDate(json, 'created_at'),
  );
}

class YorksV1InventorySupplierTrailReservation {
  const YorksV1InventorySupplierTrailReservation({
    required this.id,
    required this.requestId,
    required this.requestNumber,
    required this.projectId,
    required this.projectReference,
    required this.projectName,
    required this.scopeId,
    required this.scopeName,
    required this.reservedQuantity,
    required this.consumedQuantity,
    required this.remainingQuantity,
    required this.unit,
    required this.state,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final String requestNumber;
  final String projectId;
  final String projectReference;
  final String projectName;
  final String scopeId;
  final String scopeName;
  final String reservedQuantity;
  final String consumedQuantity;
  final String remainingQuantity;
  final String unit;
  final String state;
  final DateTime createdAt;

  factory YorksV1InventorySupplierTrailReservation.fromJson(
    Map<String, dynamic> json,
  ) => YorksV1InventorySupplierTrailReservation(
    id: _requiredString(json, 'id'),
    requestId: _requiredString(json, 'request_id'),
    requestNumber: _requiredString(json, 'request_number'),
    projectId: _requiredString(json, 'project_id'),
    projectReference: _requiredString(json, 'project_reference'),
    projectName: _requiredString(json, 'project_name'),
    scopeId: _requiredString(json, 'scope_id'),
    scopeName: _requiredString(json, 'scope_name'),
    reservedQuantity: _quantityString(json['reserved_quantity']),
    consumedQuantity: _quantityString(json['consumed_quantity']),
    remainingQuantity: _quantityString(json['remaining_quantity']),
    unit: _requiredString(json, 'unit'),
    state: _requiredString(json, 'state'),
    createdAt: _requiredDate(json, 'created_at'),
  );
}

class YorksV1InventorySupplierTrailDestination {
  const YorksV1InventorySupplierTrailDestination({
    required this.allocationId,
    required this.receiptLineId,
    required this.receiptBatchId,
    required this.dispatchLineId,
    required this.dispatchId,
    required this.dispatchNumber,
    required this.requestId,
    required this.requestNumber,
    required this.projectId,
    required this.projectReference,
    required this.projectName,
    required this.scopeId,
    required this.scopeName,
    required this.allocatedQuantity,
    required this.unit,
    required this.allocationMethod,
    required this.overrideReason,
    required this.dispatchState,
    required this.dispatchedAt,
    required this.siteReceiptOutcome,
    required this.goodReceivedQuantity,
    required this.exceptionQuantity,
    required this.confirmedReturnQuantity,
    this.materialReturnIds = const [],
    this.provenanceState = 'receipt_pending',
    this.provenanceReason,
    this.dispatchGapQuantity = '0',
    this.unprovenGoodQuantity = '0',
    this.unprovenExceptionQuantity = '0',
    this.unprovenReturnQuantity = '0',
  });

  final String allocationId;
  final String receiptLineId;
  final String receiptBatchId;
  final String dispatchLineId;
  final String dispatchId;
  final String dispatchNumber;
  final String requestId;
  final String requestNumber;
  final String projectId;
  final String projectReference;
  final String projectName;
  final String scopeId;
  final String scopeName;
  final String allocatedQuantity;
  final String unit;
  final String allocationMethod;
  final String? overrideReason;
  final String dispatchState;
  final DateTime dispatchedAt;
  final String? siteReceiptOutcome;
  final String goodReceivedQuantity;
  final String exceptionQuantity;
  final String confirmedReturnQuantity;
  final List<String> materialReturnIds;
  final String provenanceState;
  final String? provenanceReason;
  final String dispatchGapQuantity;
  final String unprovenGoodQuantity;
  final String unprovenExceptionQuantity;
  final String unprovenReturnQuantity;

  factory YorksV1InventorySupplierTrailDestination.fromJson(
    Map<String, dynamic> json,
  ) => YorksV1InventorySupplierTrailDestination(
    allocationId: _requiredString(json, 'allocation_id'),
    receiptLineId: _requiredString(json, 'receipt_line_id'),
    receiptBatchId: _requiredString(json, 'receipt_batch_id'),
    dispatchLineId: _requiredString(json, 'dispatch_line_id'),
    dispatchId: _requiredString(json, 'dispatch_id'),
    dispatchNumber: _requiredString(json, 'dispatch_number'),
    requestId: _requiredString(json, 'request_id'),
    requestNumber: _requiredString(json, 'request_number'),
    projectId: _requiredString(json, 'project_id'),
    projectReference: _requiredString(json, 'project_reference'),
    projectName: _requiredString(json, 'project_name'),
    scopeId: _requiredString(json, 'scope_id'),
    scopeName: _requiredString(json, 'scope_name'),
    allocatedQuantity: _quantityString(json['allocated_quantity']),
    unit: _requiredString(json, 'unit'),
    allocationMethod: _requiredString(json, 'allocation_method'),
    overrideReason: _nullableString(json['override_reason']),
    dispatchState: _requiredString(json, 'dispatch_state'),
    dispatchedAt: _requiredDate(json, 'dispatched_at'),
    siteReceiptOutcome: _nullableString(json['site_receipt_outcome']),
    goodReceivedQuantity: _quantityString(json['good_received_quantity']),
    exceptionQuantity: _quantityString(json['exception_quantity']),
    confirmedReturnQuantity: _quantityString(json['confirmed_return_quantity']),
    materialReturnIds: _stringList(json['material_return_ids']),
    provenanceState:
        _nullableString(json['provenance_state']) ?? 'receipt_pending',
    provenanceReason: _nullableString(json['provenance_reason']),
    dispatchGapQuantity: _quantityString(json['dispatch_gap_quantity'] ?? '0'),
    unprovenGoodQuantity: _quantityString(
      json['unproven_good_quantity'] ?? '0',
    ),
    unprovenExceptionQuantity: _quantityString(
      json['unproven_exception_quantity'] ?? '0',
    ),
    unprovenReturnQuantity: _quantityString(
      json['unproven_return_quantity'] ?? '0',
    ),
  );
}

class YorksV1InventorySupplierTrailGap {
  const YorksV1InventorySupplierTrailGap({
    required this.dispatchLineId,
    required this.dispatchId,
    required this.dispatchNumber,
    required this.requestNumber,
    required this.projectReference,
    required this.projectName,
    required this.scopeName,
    required this.unallocatedQuantity,
    required this.unit,
    required this.reasonCode,
    required this.recordedAt,
    this.siteReceiptOutcome,
    this.goodReceivedQuantity = '0',
    this.exceptionQuantity = '0',
    this.confirmedReturnQuantity = '0',
    this.provenanceState = 'receipt_pending_unproven',
  });

  final String dispatchLineId;
  final String dispatchId;
  final String dispatchNumber;
  final String requestNumber;
  final String projectReference;
  final String projectName;
  final String scopeName;
  final String unallocatedQuantity;
  final String unit;
  final String reasonCode;
  final DateTime recordedAt;
  final String? siteReceiptOutcome;
  final String goodReceivedQuantity;
  final String exceptionQuantity;
  final String confirmedReturnQuantity;
  final String provenanceState;

  factory YorksV1InventorySupplierTrailGap.fromJson(
    Map<String, dynamic> json,
  ) => YorksV1InventorySupplierTrailGap(
    dispatchLineId: _requiredString(json, 'dispatch_line_id'),
    dispatchId: _requiredString(json, 'dispatch_id'),
    dispatchNumber: _requiredString(json, 'dispatch_number'),
    requestNumber: _requiredString(json, 'request_number'),
    projectReference: _requiredString(json, 'project_reference'),
    projectName: _requiredString(json, 'project_name'),
    scopeName: _requiredString(json, 'scope_name'),
    unallocatedQuantity: _quantityString(json['unallocated_quantity']),
    unit: _requiredString(json, 'unit'),
    reasonCode: _requiredString(json, 'reason_code'),
    recordedAt: _requiredDate(json, 'recorded_at'),
    siteReceiptOutcome: _nullableString(json['site_receipt_outcome']),
    goodReceivedQuantity: _quantityString(
      json['good_received_quantity'] ?? '0',
    ),
    exceptionQuantity: _quantityString(json['exception_quantity'] ?? '0'),
    confirmedReturnQuantity: _quantityString(
      json['confirmed_return_quantity'] ?? '0',
    ),
    provenanceState:
        _nullableString(json['provenance_state']) ?? 'receipt_pending_unproven',
  );
}

class YorksV1InventorySupplierItemTrailWorkspace {
  YorksV1InventorySupplierItemTrailWorkspace({
    required this.supplier,
    required this.item,
    required List<YorksV1InventorySupplierTrailReceiptLine> receiptLines,
    required List<YorksV1InventorySupplierTrailMovement> movements,
    required List<YorksV1InventorySupplierTrailReservation> reservations,
    required List<YorksV1InventorySupplierTrailDestination> destinations,
    required List<YorksV1InventorySupplierTrailGap> provenanceGaps,
    required List<YorksV1InventorySupplierActivity> activity,
    this.section = YorksV1InventorySupplierItemTrailSection.receiptLines,
    this.totalCount = 0,
    this.limit = 50,
    this.offset = 0,
  }) : receiptLines = List.unmodifiable(receiptLines),
       movements = List.unmodifiable(movements),
       reservations = List.unmodifiable(reservations),
       destinations = List.unmodifiable(destinations),
       provenanceGaps = List.unmodifiable(provenanceGaps),
       activity = List.unmodifiable(activity);

  final YorksV1InventorySupplierDirectoryEntry supplier;
  final YorksV1InventorySupplierTrailItem item;
  final List<YorksV1InventorySupplierTrailReceiptLine> receiptLines;
  final List<YorksV1InventorySupplierTrailMovement> movements;
  final List<YorksV1InventorySupplierTrailReservation> reservations;
  final List<YorksV1InventorySupplierTrailDestination> destinations;
  final List<YorksV1InventorySupplierTrailGap> provenanceGaps;
  final List<YorksV1InventorySupplierActivity> activity;
  final YorksV1InventorySupplierItemTrailSection section;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + _selectedLength < totalCount;

  int get _selectedLength => switch (section) {
    YorksV1InventorySupplierItemTrailSection.receiptLines =>
      receiptLines.length,
    YorksV1InventorySupplierItemTrailSection.movements => movements.length,
    YorksV1InventorySupplierItemTrailSection.reservations =>
      reservations.length,
    YorksV1InventorySupplierItemTrailSection.destinations =>
      destinations.length,
    YorksV1InventorySupplierItemTrailSection.provenanceGaps =>
      provenanceGaps.length,
    YorksV1InventorySupplierItemTrailSection.activity => activity.length,
  };

  factory YorksV1InventorySupplierItemTrailWorkspace.fromJson(
    Map<String, dynamic> json,
  ) {
    final section = YorksV1InventorySupplierItemTrailSection.fromWire(
      json['section'],
    );
    if (section == null) _unexpected();
    return YorksV1InventorySupplierItemTrailWorkspace(
      supplier: YorksV1InventorySupplierDirectoryEntry.fromJson(
        _requiredObject(json, 'supplier'),
      ),
      item: YorksV1InventorySupplierTrailItem.fromJson(
        _requiredObject(json, 'item'),
      ),
      receiptLines: _objectList(
        json['receipt_lines'],
      ).map(YorksV1InventorySupplierTrailReceiptLine.fromJson).toList(),
      movements: _objectList(
        json['movements'],
      ).map(YorksV1InventorySupplierTrailMovement.fromJson).toList(),
      reservations: _objectList(
        json['reservations'],
      ).map(YorksV1InventorySupplierTrailReservation.fromJson).toList(),
      destinations: _objectList(
        json['destinations'],
      ).map(YorksV1InventorySupplierTrailDestination.fromJson).toList(),
      provenanceGaps: _objectList(
        json['provenance_gaps'],
      ).map(YorksV1InventorySupplierTrailGap.fromJson).toList(),
      activity: _objectList(
        json['activity'],
      ).map(YorksV1InventorySupplierActivity.fromJson).toList(),
      section: section,
      totalCount: _nonNegativeInt(json['total_count']),
      limit: _positiveInt(json['limit']),
      offset: _nonNegativeInt(json['offset']),
    );
  }
}

class YorksV1InventorySupplierReceiptBatchDetailHeader {
  YorksV1InventorySupplierReceiptBatchDetailHeader({
    required this.id,
    required this.receiptNumber,
    required this.sourceType,
    required this.supplierReference,
    required this.receivedDate,
    required this.location,
    required this.status,
    required this.lineCount,
    required this.documentCount,
    required this.receivedByAuthUserId,
    required this.receivedByDisplayName,
    required this.receivedByRole,
    required this.createdAt,
    required List<YorksV1InventorySupplierUnitTotal> unitTotals,
  }) : unitTotals = List.unmodifiable(unitTotals);

  final String id;
  final String receiptNumber;
  final String sourceType;
  final String supplierReference;
  final DateTime receivedDate;
  final String location;
  final String status;
  final int lineCount;
  final int documentCount;
  final String receivedByAuthUserId;
  final String receivedByDisplayName;
  final String receivedByRole;
  final DateTime createdAt;
  final List<YorksV1InventorySupplierUnitTotal> unitTotals;

  factory YorksV1InventorySupplierReceiptBatchDetailHeader.fromJson(
    Map<String, dynamic> json,
  ) => YorksV1InventorySupplierReceiptBatchDetailHeader(
    id: _requiredString(json, 'id'),
    receiptNumber: _requiredString(json, 'receipt_number'),
    sourceType: _requiredString(json, 'source_type'),
    supplierReference: _requiredString(json, 'supplier_reference'),
    receivedDate: _requiredDate(json, 'received_date'),
    location: _requiredString(json, 'warehouse_location'),
    status: _requiredString(json, 'status'),
    lineCount: _positiveInt(json['line_count']),
    documentCount: _nonNegativeInt(json['document_count']),
    receivedByAuthUserId: _requiredString(json, 'received_by_auth_user_id'),
    receivedByDisplayName: _requiredString(json, 'received_by_display_name'),
    receivedByRole: _requiredString(json, 'received_by_role'),
    createdAt: _requiredDate(json, 'created_at'),
    unitTotals: _objectList(
      json['unit_totals'],
    ).map(YorksV1InventorySupplierUnitTotal.fromJson).toList(),
  );
}

class YorksV1InventorySupplierReceiptBatchDetailLine {
  const YorksV1InventorySupplierReceiptBatchDetailLine({
    required this.id,
    required this.inventoryItemId,
    required this.sourceRowNumber,
    required this.itemCode,
    required this.description,
    required this.categoryName,
    required this.brandOrigin,
    required this.size,
    required this.modelTag,
    required this.unit,
    required this.deliveredQuantity,
    required this.acceptedQuantity,
    required this.damagedQuantity,
    required this.rejectedQuantity,
    required this.currentOnHand,
    required this.allocatedQuantity,
    required this.trackingMode,
    required this.serialNumber,
    required this.batchLotNumber,
    required this.location,
    required this.notes,
  });

  final String id;
  final String inventoryItemId;
  final int sourceRowNumber;
  final String itemCode;
  final String description;
  final String? categoryName;
  final String? brandOrigin;
  final String? size;
  final String? modelTag;
  final String unit;
  final String deliveredQuantity;
  final String acceptedQuantity;
  final String damagedQuantity;
  final String rejectedQuantity;
  final String currentOnHand;
  final String allocatedQuantity;
  final String trackingMode;
  final String? serialNumber;
  final String? batchLotNumber;
  final String? location;
  final String? notes;

  factory YorksV1InventorySupplierReceiptBatchDetailLine.fromJson(
    Map<String, dynamic> json,
  ) => YorksV1InventorySupplierReceiptBatchDetailLine(
    id: _requiredString(json, 'id'),
    inventoryItemId: _requiredString(json, 'inventory_item_id'),
    sourceRowNumber: _positiveInt(json['source_row_number']),
    itemCode: _requiredString(json, 'item_code'),
    description: _requiredString(json, 'item_description'),
    categoryName: _nullableString(json['category_name']),
    brandOrigin: _nullableString(json['brand_origin']),
    size: _nullableString(json['size']),
    modelTag: _nullableString(json['model_tag']),
    unit: _requiredString(json, 'unit'),
    deliveredQuantity: _quantityString(json['delivered_quantity']),
    acceptedQuantity: _quantityString(json['accepted_quantity']),
    damagedQuantity: _quantityString(json['damaged_quantity']),
    rejectedQuantity: _quantityString(json['rejected_quantity']),
    currentOnHand: _quantityString(json['current_on_hand']),
    allocatedQuantity: _quantityString(json['allocated_quantity']),
    trackingMode: _requiredString(json, 'tracking_mode'),
    serialNumber: _nullableString(json['serial_number']),
    batchLotNumber: _nullableString(json['batch_lot_number']),
    location: _nullableString(json['location']),
    notes: _nullableString(json['notes']),
  );
}

class YorksV1InventorySupplierReceiptBatchDetailWorkspace {
  YorksV1InventorySupplierReceiptBatchDetailWorkspace({
    required this.supplier,
    required this.batch,
    required List<YorksV1InventorySupplierReceiptBatchDetailLine> lines,
    required List<YorksV1InventorySupplierDocument> documents,
    required List<YorksV1InventorySupplierActivity> activity,
    this.section = YorksV1InventorySupplierReceiptBatchDetailSection.lines,
    this.totalCount = 0,
    this.limit = 50,
    this.offset = 0,
  }) : lines = List.unmodifiable(lines),
       documents = List.unmodifiable(documents),
       activity = List.unmodifiable(activity);

  final YorksV1InventorySupplierDirectoryEntry supplier;
  final YorksV1InventorySupplierReceiptBatchDetailHeader batch;
  final List<YorksV1InventorySupplierReceiptBatchDetailLine> lines;
  final List<YorksV1InventorySupplierDocument> documents;
  final List<YorksV1InventorySupplierActivity> activity;
  final YorksV1InventorySupplierReceiptBatchDetailSection section;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + _selectedLength < totalCount;

  int get _selectedLength => switch (section) {
    YorksV1InventorySupplierReceiptBatchDetailSection.lines => lines.length,
    YorksV1InventorySupplierReceiptBatchDetailSection.documents =>
      documents.length,
    YorksV1InventorySupplierReceiptBatchDetailSection.activity =>
      activity.length,
  };

  factory YorksV1InventorySupplierReceiptBatchDetailWorkspace.fromJson(
    Map<String, dynamic> json,
  ) {
    final section = YorksV1InventorySupplierReceiptBatchDetailSection.fromWire(
      json['section'],
    );
    if (section == null) _unexpected();
    return YorksV1InventorySupplierReceiptBatchDetailWorkspace(
      supplier: YorksV1InventorySupplierDirectoryEntry.fromJson(
        _requiredObject(json, 'supplier'),
      ),
      batch: YorksV1InventorySupplierReceiptBatchDetailHeader.fromJson(
        _requiredObject(json, 'batch'),
      ),
      lines: _objectList(
        json['lines'],
      ).map(YorksV1InventorySupplierReceiptBatchDetailLine.fromJson).toList(),
      documents: _objectList(
        json['documents'],
      ).map(YorksV1InventorySupplierDocument.fromJson).toList(),
      activity: _objectList(
        json['activity'],
      ).map(YorksV1InventorySupplierActivity.fromJson).toList(),
      section: section,
      totalCount: _nonNegativeInt(json['total_count']),
      limit: _positiveInt(json['limit']),
      offset: _nonNegativeInt(json['offset']),
    );
  }
}

class YorksV1InventorySupplierCreateInput {
  const YorksV1InventorySupplierCreateInput({
    required this.name,
    required this.description,
    required this.aliases,
    required this.idempotencyKey,
  });

  final String name;
  final String? description;
  final List<String> aliases;
  final String idempotencyKey;

  Map<String, Object?> toRpcPayload() => {
    'canonical_name': name.trim(),
    'description': description?.trim(),
    'aliases': aliases.map((value) => value.trim()).toList(growable: false),
  };
}

/// Final stage-4 payload. Parsed rows stay local and quantity-neutral until
/// this object is sent to the trusted server command.
class YorksV1InventorySupplierImportInput {
  YorksV1InventorySupplierImportInput({
    required this.fileName,
    required this.fileSha256,
    this.importMode = 'strict',
    this.openingBalanceAsOfDate,
    required List<Map<String, Object?>> rows,
    required this.idempotencyKey,
  }) : rows = List.unmodifiable(
         rows.map((row) => Map<String, Object?>.unmodifiable(row)),
       );

  final String fileName;
  final String fileSha256;
  final String importMode;
  final DateTime? openingBalanceAsOfDate;
  final List<Map<String, Object?>> rows;
  final String idempotencyKey;

  Map<String, Object?> toRpcPayload() => {
    'file_name': fileName,
    'file_sha256': fileSha256,
    'import_mode': importMode,
    'opening_balance_as_of_date': openingBalanceAsOfDate
        ?.toIso8601String()
        .split('T')
        .first,
    'rows': rows,
  };
}

class YorksV1InventorySupplierImportResult {
  const YorksV1InventorySupplierImportResult({
    required this.importBatchId,
    required this.rowCount,
    required this.createdItems,
    required this.updatedItems,
    required this.createdSuppliers,
    required this.createdCategories,
    required this.receiptBatches,
    required this.movements,
    required this.warningCount,
    required this.excludedCount,
    this.unknownSupplierRows = 0,
    this.unitTotals = const [],
  });

  final String importBatchId;
  final int rowCount;
  final int createdItems;
  final int updatedItems;
  final int createdSuppliers;
  final int createdCategories;
  final int receiptBatches;
  final int movements;
  final int warningCount;
  final int excludedCount;
  final int unknownSupplierRows;
  final List<YorksV1InventorySupplierUnitTotal> unitTotals;

  factory YorksV1InventorySupplierImportResult.fromJson(
    Map<String, dynamic> json,
  ) => YorksV1InventorySupplierImportResult(
    importBatchId: _requiredString(json, 'import_batch_id'),
    rowCount: _positiveInt(json['row_count']),
    createdItems: _nonNegativeInt(json['created_items']),
    updatedItems: _nonNegativeInt(json['updated_items']),
    createdSuppliers: _nonNegativeInt(json['created_suppliers']),
    createdCategories: _nonNegativeInt(json['created_categories'] ?? 0),
    receiptBatches: _nonNegativeInt(json['receipt_batches']),
    movements: _nonNegativeInt(json['movements']),
    warningCount: _nonNegativeInt(json['warning_count']),
    excludedCount: _nonNegativeInt(json['excluded_count']),
    unknownSupplierRows: _nonNegativeInt(json['unknown_supplier_rows'] ?? 0),
    unitTotals: json['unit_totals'] == null
        ? const []
        : _objectList(json['unit_totals'])
              .map(YorksV1InventorySupplierUnitTotal.fromJson)
              .toList(growable: false),
  );
}

Map<String, dynamic> _requiredObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) return Map<String, dynamic>.from(value);
  _unexpected();
}

List<Map<String, dynamic>> _objectList(Object? value) {
  if (value is! List) _unexpected();
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item) else _unexpected(),
  ];
}

List<String> _stringList(Object? value) {
  if (value == null) return const [];
  if (value is! List) _unexpected();
  return [
    for (final item in value)
      if (item is String) item else _unexpected(),
  ];
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  _unexpected();
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  if (value is! String) _unexpected();
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String _quantityString(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || num.tryParse(text) == null) _unexpected();
  return text;
}

int _positiveInt(Object? value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed < 1) _unexpected();
  return parsed;
}

int _nonNegativeInt(Object? value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed < 0) _unexpected();
  return parsed;
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _nullableDate(json[key]);
  if (value == null) _unexpected();
  return value;
}

DateTime? _nullableDate(Object? value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) _unexpected();
  return parsed;
}

Never _unexpected() => throw const YorksV1DomainException(
  YorksV1DomainErrorCode.unexpectedResponse,
);
