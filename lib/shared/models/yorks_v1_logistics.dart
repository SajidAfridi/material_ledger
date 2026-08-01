import 'yorks_v1_domain_error.dart';

enum YorksV1LogisticsSource {
  warehouse('warehouse'),
  externalSupplier('external_supplier');

  const YorksV1LogisticsSource(this.wireValue);
  final String wireValue;

  static YorksV1LogisticsSource fromWireValue(Object? value) => switch (value) {
    'external_supplier' => YorksV1LogisticsSource.externalSupplier,
    _ => YorksV1LogisticsSource.warehouse,
  };
}

enum YorksV1DispatchState {
  receiptPending('receipt_pending'),
  partiallyReceived('partially_received'),
  received('received');

  const YorksV1DispatchState(this.wireValue);
  final String wireValue;

  static YorksV1DispatchState? fromWireValue(Object? value) {
    if (value is! String) return null;
    for (final state in values) {
      if (state.wireValue == value) return state;
    }
    return null;
  }
}

enum YorksV1ReceiptOutcome {
  received('received'),
  missing('missing'),
  damaged('damaged');

  const YorksV1ReceiptOutcome(this.wireValue);
  final String wireValue;

  static YorksV1ReceiptOutcome? fromWireValue(Object? value) {
    if (value is! String) return null;
    for (final outcome in values) {
      if (outcome.wireValue == value) return outcome;
    }
    return null;
  }
}

/// Operational-only warehouse item. This intentionally contains no supplier
/// commercial record, rate, unit cost or valuation field.
class YorksV1LogisticsInventoryItem {
  const YorksV1LogisticsInventoryItem({
    required this.id,
    required this.description,
    required this.unit,
    required this.isActive,
    required this.onHandQuantity,
    required this.reservedQuantity,
    required this.availableQuantity,
    required this.recordVersion,
    this.brandOrigin,
    this.movementCount,
    this.lastMovementAt,
  });

  final String id;
  final String description;
  final String? brandOrigin;
  final String unit;
  final bool isActive;
  final String onHandQuantity;
  final String reservedQuantity;
  final String availableQuantity;
  final int recordVersion;
  final int? movementCount;
  final DateTime? lastMovementAt;

  factory YorksV1LogisticsInventoryItem.fromRpcJson(Map<String, dynamic> json) {
    return YorksV1LogisticsInventoryItem(
      id: _requiredString(json, 'id'),
      description: _requiredString(json, 'item_description'),
      brandOrigin: _trimToNull(json['brand_origin']),
      unit: _requiredString(json, 'unit'),
      isActive: json['is_active'] != false,
      onHandQuantity: _string(json['on_hand_qty']),
      reservedQuantity: _string(json['reserved_qty']),
      availableQuantity: _string(json['available_qty']),
      recordVersion: _positiveInt(json['record_version']),
      movementCount: _nullableInt(json['movement_count']),
      lastMovementAt: _nullableDate(json['last_movement_at']),
    );
  }
}

class YorksV1InventoryMovement {
  const YorksV1InventoryMovement({
    required this.id,
    required this.movementType,
    required this.quantityDelta,
    required this.onHandAfterQuantity,
    required this.reason,
    required this.actorDisplayName,
    required this.createdAt,
    this.sourceEntityType,
    this.sourceEntityId,
  });

  final String id;
  final String movementType;
  final String quantityDelta;
  final String onHandAfterQuantity;
  final String reason;
  final String actorDisplayName;
  final DateTime createdAt;
  final String? sourceEntityType;
  final String? sourceEntityId;

  factory YorksV1InventoryMovement.fromRpcJson(Map<String, dynamic> json) {
    return YorksV1InventoryMovement(
      id: _requiredString(json, 'id'),
      movementType: _requiredString(json, 'movement_type'),
      quantityDelta: _string(json['quantity_delta']),
      onHandAfterQuantity: _string(json['on_hand_after_qty']),
      reason: _requiredString(json, 'reason'),
      actorDisplayName: _requiredString(json, 'actor_display_name'),
      createdAt: _requiredDate(json, 'created_at'),
      sourceEntityType: _trimToNull(json['source_entity_type']),
      sourceEntityId: _trimToNull(json['source_entity_id']),
    );
  }
}

class YorksV1InventoryItemDetail {
  YorksV1InventoryItemDetail({
    required this.item,
    required List<YorksV1InventoryMovement> movements,
  }) : movements = List.unmodifiable(movements);

  final YorksV1LogisticsInventoryItem item;
  final List<YorksV1InventoryMovement> movements;

  factory YorksV1InventoryItemDetail.fromRpcJson(Map<String, dynamic> json) {
    final rawItem = json['item'];
    final rawMovements = json['movements'];
    if (rawItem is! Map || rawMovements is! List) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1InventoryItemDetail(
      item: YorksV1LogisticsInventoryItem.fromRpcJson(
        Map<String, dynamic>.from(rawItem),
      ),
      movements: [
        for (final movement in rawMovements)
          if (movement is Map)
            YorksV1InventoryMovement.fromRpcJson(
              Map<String, dynamic>.from(movement),
            ),
      ],
    );
  }
}

class YorksV1DispatchCandidate {
  const YorksV1DispatchCandidate({
    required this.requestLineId,
    required this.displayOrder,
    required this.description,
    required this.unit,
    required this.approvedQuantity,
    required this.goodReceivedQuantity,
    required this.inTransitQuantity,
    required this.stillNeededQuantity,
    required this.source,
    this.brandOrigin,
    this.externalSupplier,
    this.inventoryItemId,
    this.reservedRemainingQuantity,
    this.warehouseAvailableQuantity,
  });

  final String requestLineId;
  final int displayOrder;
  final String description;
  final String? brandOrigin;
  final String unit;
  final String approvedQuantity;
  final String goodReceivedQuantity;
  final String inTransitQuantity;
  final String stillNeededQuantity;
  final YorksV1LogisticsSource source;
  final String? externalSupplier;
  final String? inventoryItemId;
  final String? reservedRemainingQuantity;
  final String? warehouseAvailableQuantity;

  factory YorksV1DispatchCandidate.fromRpcJson(Map<String, dynamic> json) {
    return YorksV1DispatchCandidate(
      requestLineId: _requiredString(json, 'request_line_id'),
      displayOrder: _positiveInt(json['display_order']),
      description: _requiredString(json, 'item_description'),
      brandOrigin: _trimToNull(json['brand_origin']),
      unit: _requiredString(json, 'unit'),
      approvedQuantity: _string(json['approved_qty']),
      goodReceivedQuantity: _string(json['good_received_qty']),
      inTransitQuantity: _string(json['in_transit_qty']),
      stillNeededQuantity: _string(json['still_needed_qty']),
      source: YorksV1LogisticsSource.fromWireValue(json['source_kind']),
      externalSupplier: _trimToNull(json['external_supplier']),
      inventoryItemId: _trimToNull(json['inventory_item_id']),
      reservedRemainingQuantity: _trimToNull(json['reserved_remaining_qty']),
      warehouseAvailableQuantity: _trimToNull(json['warehouse_available_qty']),
    );
  }
}

class YorksV1DispatchLine {
  const YorksV1DispatchLine({
    required this.id,
    required this.requestLineId,
    required this.description,
    required this.unit,
    required this.source,
    required this.dispatchedQuantity,
    required this.approvedQuantity,
    this.brandOrigin,
    this.externalSupplier,
    this.receiptOutcome,
    this.goodQuantity,
    this.exceptionQuantity,
    this.receiptNote,
  });

  final String id;
  final String requestLineId;
  final String description;
  final String? brandOrigin;
  final String unit;
  final YorksV1LogisticsSource source;
  final String dispatchedQuantity;
  final String approvedQuantity;
  final String? externalSupplier;
  final YorksV1ReceiptOutcome? receiptOutcome;
  final String? goodQuantity;
  final String? exceptionQuantity;
  final String? receiptNote;

  factory YorksV1DispatchLine.fromRpcJson(Map<String, dynamic> json) {
    return YorksV1DispatchLine(
      id: _requiredString(json, 'id'),
      requestLineId: _requiredString(json, 'request_line_id'),
      description: _requiredString(json, 'item_description'),
      brandOrigin: _trimToNull(json['brand_origin']),
      unit: _requiredString(json, 'unit'),
      source: YorksV1LogisticsSource.fromWireValue(json['source_kind']),
      dispatchedQuantity: _string(json['dispatched_qty']),
      approvedQuantity: _string(json['approved_qty_snapshot']),
      externalSupplier: _trimToNull(json['external_supplier']),
      receiptOutcome: YorksV1ReceiptOutcome.fromWireValue(
        json['receipt_outcome'],
      ),
      goodQuantity: _trimToNull(json['good_qty']),
      exceptionQuantity: _trimToNull(json['exception_qty']),
      receiptNote: _trimToNull(json['receipt_note']),
    );
  }
}

class YorksV1ReceiptReview {
  const YorksV1ReceiptReview({
    required this.id,
    required this.reviewedAt,
    required this.reviewedByDisplayName,
  });

  final String id;
  final DateTime reviewedAt;
  final String reviewedByDisplayName;

  factory YorksV1ReceiptReview.fromRpcJson(Map<String, dynamic> json) {
    return YorksV1ReceiptReview(
      id: _requiredString(json, 'id'),
      reviewedAt: _requiredDate(json, 'reviewed_at'),
      reviewedByDisplayName: _requiredString(json, 'reviewed_by_display_name'),
    );
  }
}

class YorksV1MaterialDispatch {
  YorksV1MaterialDispatch({
    required this.id,
    required this.number,
    required this.dispatchDate,
    required this.state,
    required this.recordVersion,
    required this.dispatchedByDisplayName,
    required this.dispatchedAt,
    required this.canConfirmReceipt,
    required List<YorksV1DispatchLine> lines,
    this.driverName,
    this.vehicleReference,
    this.receiptReview,
  }) : lines = List.unmodifiable(lines);

  final String id;
  final String number;
  final DateTime dispatchDate;
  final YorksV1DispatchState state;
  final int recordVersion;
  final String dispatchedByDisplayName;
  final DateTime dispatchedAt;
  final bool canConfirmReceipt;
  final String? driverName;
  final String? vehicleReference;
  final YorksV1ReceiptReview? receiptReview;
  final List<YorksV1DispatchLine> lines;

  factory YorksV1MaterialDispatch.fromRpcJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final state = YorksV1DispatchState.fromWireValue(json['state']);
    if (rawLines is! List || state == null) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    final rawReview = json['receipt_review'];
    return YorksV1MaterialDispatch(
      id: _requiredString(json, 'id'),
      number: _requiredString(json, 'dispatch_number'),
      dispatchDate: _requiredDate(json, 'dispatch_date'),
      state: state,
      recordVersion: _positiveInt(json['record_version']),
      dispatchedByDisplayName: _requiredString(
        json,
        'dispatched_by_display_name',
      ),
      dispatchedAt: _requiredDate(json, 'dispatched_at'),
      canConfirmReceipt: json['can_confirm_receipt'] == true,
      driverName: _trimToNull(json['driver_name']),
      vehicleReference: _trimToNull(json['vehicle_reference']),
      receiptReview: rawReview is Map
          ? YorksV1ReceiptReview.fromRpcJson(
              Map<String, dynamic>.from(rawReview),
            )
          : null,
      lines: [
        for (final line in rawLines)
          if (line is Map)
            YorksV1DispatchLine.fromRpcJson(Map<String, dynamic>.from(line)),
      ],
    );
  }
}

/// Role-safe request-level logistics workspace. General warehouse availability
/// is server-filtered and never derived from the client role label.
class YorksV1LogisticsWorkspace {
  YorksV1LogisticsWorkspace({
    required this.requestId,
    required this.requestState,
    required this.requestRecordVersion,
    required this.projectName,
    required this.scopeName,
    required this.canDispatch,
    required this.canConfirmReceipt,
    required List<YorksV1DispatchCandidate> dispatchCandidates,
    required List<YorksV1MaterialDispatch> dispatches,
    this.requestNumber,
  }) : dispatchCandidates = List.unmodifiable(dispatchCandidates),
       dispatches = List.unmodifiable(dispatches);

  final String requestId;
  final String? requestNumber;
  final String requestState;
  final int requestRecordVersion;
  final String projectName;
  final String scopeName;
  final bool canDispatch;
  final bool canConfirmReceipt;
  final List<YorksV1DispatchCandidate> dispatchCandidates;
  final List<YorksV1MaterialDispatch> dispatches;

  factory YorksV1LogisticsWorkspace.fromRpcJson(Map<String, dynamic> json) {
    final rawCandidates = json['dispatch_candidates'];
    final rawDispatches = json['dispatches'];
    if (rawCandidates is! List || rawDispatches is! List) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1LogisticsWorkspace(
      requestId: _requiredString(json, 'request_id'),
      requestNumber: _trimToNull(json['request_number']),
      requestState: _requiredString(json, 'request_state'),
      requestRecordVersion: _positiveInt(json['request_record_version']),
      projectName: _requiredString(json, 'project_name'),
      scopeName: _requiredString(json, 'scope_name'),
      canDispatch: json['can_dispatch'] == true,
      canConfirmReceipt: json['can_confirm_receipt'] == true,
      dispatchCandidates: [
        for (final candidate in rawCandidates)
          if (candidate is Map)
            YorksV1DispatchCandidate.fromRpcJson(
              Map<String, dynamic>.from(candidate),
            ),
      ],
      dispatches: [
        for (final dispatch in rawDispatches)
          if (dispatch is Map)
            YorksV1MaterialDispatch.fromRpcJson(
              Map<String, dynamic>.from(dispatch),
            ),
      ],
    );
  }
}

class YorksV1InventoryWorkspace {
  YorksV1InventoryWorkspace({
    required List<YorksV1LogisticsInventoryItem> items,
  }) : items = List.unmodifiable(items);

  final List<YorksV1LogisticsInventoryItem> items;

  factory YorksV1InventoryWorkspace.fromRpcJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1InventoryWorkspace(
      items: [
        for (final item in rawItems)
          if (item is Map)
            YorksV1LogisticsInventoryItem.fromRpcJson(
              Map<String, dynamic>.from(item),
            ),
      ],
    );
  }
}

class YorksV1InventoryAdjustmentInput {
  const YorksV1InventoryAdjustmentInput({
    required this.quantityDelta,
    required this.reason,
    required this.idempotencyKey,
    this.inventoryItemId,
    this.description,
    this.brandOrigin,
    this.unit,
  });

  final String quantityDelta;
  final String reason;
  final String idempotencyKey;
  final String? inventoryItemId;
  final String? description;
  final String? brandOrigin;
  final String? unit;

  Map<String, Object?> toRpcPayload() => {
    'inventory_item_id': _trimToNull(inventoryItemId),
    'item_description': _trimToNull(description),
    'brand_origin': _trimToNull(brandOrigin),
    'unit': _trimToNull(unit),
    'quantity_delta': quantityDelta.trim(),
    'reason': reason.trim(),
  };
}

class YorksV1InventoryItemStateInput {
  const YorksV1InventoryItemStateInput({
    required this.inventoryItemId,
    required this.expectedVersion,
    required this.isActive,
    required this.reason,
    required this.idempotencyKey,
  });

  final String inventoryItemId;
  final int expectedVersion;
  final bool isActive;
  final String reason;
  final String idempotencyKey;

  Map<String, Object?> toRpcPayload() => {
    'inventory_item_id': inventoryItemId,
    'expected_version': expectedVersion,
    'is_active': isActive,
    'reason': reason.trim(),
  };
}

class YorksV1DispatchLineInput {
  const YorksV1DispatchLineInput({
    required this.requestLineId,
    required this.dispatchQuantity,
  });

  final String requestLineId;
  final String dispatchQuantity;

  Map<String, Object?> toRpcJson() => {
    'request_line_id': requestLineId,
    'dispatch_qty': dispatchQuantity.trim(),
  };
}

class YorksV1DispatchInput {
  YorksV1DispatchInput({
    required this.requestId,
    required this.expectedRequestVersion,
    required this.dispatchDate,
    required List<YorksV1DispatchLineInput> lines,
    required this.idempotencyKey,
    this.driverName,
    this.vehicleReference,
  }) : lines = List.unmodifiable(lines);

  final String requestId;
  final int expectedRequestVersion;
  final DateTime dispatchDate;
  final List<YorksV1DispatchLineInput> lines;
  final String idempotencyKey;
  final String? driverName;
  final String? vehicleReference;

  Map<String, Object?> toRpcPayload() => {
    'request_id': requestId,
    'expected_version': expectedRequestVersion,
    'dispatch_date': _dateOnly(dispatchDate),
    'driver_name': _trimToNull(driverName),
    'vehicle_reference': _trimToNull(vehicleReference),
    'lines': [for (final line in lines) line.toRpcJson()],
  };
}

class YorksV1ReceiptLineInput {
  const YorksV1ReceiptLineInput({
    required this.dispatchLineId,
    required this.outcome,
    required this.goodQuantity,
    this.note,
  });

  final String dispatchLineId;
  final YorksV1ReceiptOutcome outcome;
  final String goodQuantity;
  final String? note;

  Map<String, Object?> toRpcJson() => {
    'dispatch_line_id': dispatchLineId,
    'outcome': outcome.wireValue,
    'good_qty': goodQuantity.trim(),
    'note': _trimToNull(note),
  };
}

class YorksV1ReceiptConfirmationInput {
  YorksV1ReceiptConfirmationInput({
    required this.requestId,
    required this.dispatchId,
    required this.expectedRequestVersion,
    required this.expectedDispatchVersion,
    required List<YorksV1ReceiptLineInput> lines,
    required this.idempotencyKey,
  }) : lines = List.unmodifiable(lines);

  final String requestId;
  final String dispatchId;
  final int expectedRequestVersion;
  final int expectedDispatchVersion;
  final List<YorksV1ReceiptLineInput> lines;
  final String idempotencyKey;

  Map<String, Object?> toRpcPayload() => {
    'request_id': requestId,
    'dispatch_id': dispatchId,
    'expected_request_version': expectedRequestVersion,
    'expected_dispatch_version': expectedDispatchVersion,
    'lines': [for (final line in lines) line.toRpcJson()],
  };
}

String _dateOnly(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String _string(Object? value) => switch (value) {
  String text => text,
  num number => number.toString(),
  _ => '',
};

String? _trimToNull(Object? value) {
  final text = _string(value).trim();
  return text.isEmpty ? null : text;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _trimToNull(json[key]);
  if (value == null) {
    throw const YorksV1DomainException(
      YorksV1DomainErrorCode.unexpectedResponse,
    );
  }
  return value;
}

int _positiveInt(Object? value) {
  final parsed = switch (value) {
    int integer => integer,
    num number => number.toInt(),
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };
  return parsed > 0 ? parsed : 1;
}

int? _nullableInt(Object? value) {
  return switch (value) {
    int integer => integer,
    num number => number.toInt(),
    String text => int.tryParse(text),
    _ => null,
  };
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final date = _nullableDate(json[key]);
  if (date == null) {
    throw const YorksV1DomainException(
      YorksV1DomainErrorCode.unexpectedResponse,
    );
  }
  return date;
}

DateTime? _nullableDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}
