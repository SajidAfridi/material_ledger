import 'yorks_v1_domain_error.dart';

/// The only source options in Yorks V1. Supplier text is intentionally a
/// lightweight external source; RFQ, quotation and PO flows are deferred.
enum YorksV1ArrangementSource {
  warehouse('warehouse'),
  externalSupplier('external_supplier');

  const YorksV1ArrangementSource(this.wireValue);
  final String wireValue;

  static YorksV1ArrangementSource fromWireValue(Object? value) =>
      switch (value) {
        'external_supplier' => YorksV1ArrangementSource.externalSupplier,
        _ => YorksV1ArrangementSource.warehouse,
      };
}

enum YorksV1ArrangementDecision {
  full('full'),
  partial('partial'),
  unavailable('unavailable');

  const YorksV1ArrangementDecision(this.wireValue);
  final String wireValue;

  static YorksV1ArrangementDecision? fromWireValue(Object? value) {
    if (value is! String) return null;
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }
}

enum YorksV1ArrangementStatus {
  working('working'),
  awaitingApproval('awaiting_approval'),
  approved('approved'),
  returned('returned'),
  superseded('superseded'),
  cancelled('cancelled');

  const YorksV1ArrangementStatus(this.wireValue);
  final String wireValue;

  static YorksV1ArrangementStatus? fromWireValue(Object? value) {
    if (value is! String) return null;
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }
}

enum YorksV1ArrangementReviewDecision {
  approved('approved'),
  returned('returned');

  const YorksV1ArrangementReviewDecision(this.wireValue);
  final String wireValue;
}

/// Operational warehouse context only. It carries no cost, supplier commercial
/// record or movement ledger data and is exposed solely to Procurement/Admin.
class YorksV1InventoryItem {
  const YorksV1InventoryItem({
    required this.id,
    required this.description,
    required this.unit,
    required this.onHandQuantity,
    required this.reservedQuantity,
    required this.availableQuantity,
    required this.recordVersion,
    this.brandOrigin,
  });

  final String id;
  final String description;
  final String? brandOrigin;
  final String unit;
  final String onHandQuantity;
  final String reservedQuantity;
  final String availableQuantity;
  final int recordVersion;

  factory YorksV1InventoryItem.fromRpcJson(Map<String, dynamic> json) {
    return YorksV1InventoryItem(
      id: _requiredString(json, 'id'),
      description: _requiredString(json, 'item_description'),
      brandOrigin: _trimToNull(json['brand_origin']),
      unit: _requiredString(json, 'unit'),
      onHandQuantity: _string(json['on_hand_qty']),
      reservedQuantity: _string(json['reserved_qty']),
      availableQuantity: _string(json['available_qty']),
      recordVersion: _positiveInt(json['record_version']),
    );
  }
}

class YorksV1ArrangementLine {
  const YorksV1ArrangementLine({
    required this.id,
    required this.requestLineId,
    required this.displayOrder,
    required this.description,
    required this.requestedQuantity,
    required this.unit,
    required this.source,
    this.brandOrigin,
    this.externalSupplier,
    this.decision,
    this.arrangedQuantity,
    this.reason,
    this.unitCost,
    this.inventoryItemId,
    this.inventoryItemDescription,
    this.warehouseAvailableAtSave,
    this.reservationState,
    this.reservedQuantity,
  });

  final String id;
  final String requestLineId;
  final int displayOrder;
  final String description;
  final String? brandOrigin;
  final String requestedQuantity;
  final String unit;
  final YorksV1ArrangementSource source;
  final String? externalSupplier;
  final YorksV1ArrangementDecision? decision;
  final String? arrangedQuantity;
  final String? reason;

  /// Procurement-only commercial input. The database deliberately omits this
  /// field from non-commercial arrangement projections.
  final String? unitCost;
  final String? inventoryItemId;
  final String? inventoryItemDescription;
  final String? warehouseAvailableAtSave;
  final String? reservationState;
  final String? reservedQuantity;

  factory YorksV1ArrangementLine.fromRpcJson(Map<String, dynamic> json) {
    return YorksV1ArrangementLine(
      id: _requiredString(json, 'id'),
      requestLineId: _requiredString(json, 'request_line_id'),
      displayOrder: _positiveInt(json['display_order']),
      description: _requiredString(json, 'item_description'),
      brandOrigin: _trimToNull(json['brand_origin']),
      requestedQuantity: _string(json['requested_qty']),
      unit: _requiredString(json, 'unit'),
      source: YorksV1ArrangementSource.fromWireValue(json['source_kind']),
      externalSupplier: _trimToNull(json['external_supplier']),
      decision: YorksV1ArrangementDecision.fromWireValue(json['decision']),
      arrangedQuantity: _trimToNull(json['arranged_qty']),
      reason: _trimToNull(json['reason']),
      unitCost: _trimToNull(json['unit_cost']),
      inventoryItemId: _trimToNull(json['inventory_item_id']),
      inventoryItemDescription: _trimToNull(json['inventory_item_description']),
      warehouseAvailableAtSave: _trimToNull(
        json['warehouse_available_at_save'],
      ),
      reservationState: _trimToNull(json['reservation_state']),
      reservedQuantity: _trimToNull(json['reserved_qty']),
    );
  }
}

class YorksV1ProcurementArrangement {
  YorksV1ProcurementArrangement({
    required this.id,
    required this.version,
    required this.status,
    required this.isCurrent,
    required this.recordVersion,
    required this.startedByDisplayName,
    required this.startedAt,
    required List<YorksV1ArrangementLine> lines,
    this.savedAt,
    this.savedByDisplayName,
    this.reviewDecision,
    this.reviewReason,
    this.procurementNote,
  }) : lines = List.unmodifiable(lines);

  final String id;
  final int version;
  final YorksV1ArrangementStatus status;
  final bool isCurrent;
  final int recordVersion;
  final String startedByDisplayName;
  final DateTime startedAt;
  final DateTime? savedAt;
  final String? savedByDisplayName;
  final YorksV1ArrangementReviewDecision? reviewDecision;
  final String? reviewReason;

  /// Procurement-only overall arrangement context; never inferred from lines.
  final String? procurementNote;
  final List<YorksV1ArrangementLine> lines;

  factory YorksV1ProcurementArrangement.fromRpcJson(Map<String, dynamic> json) {
    final status = YorksV1ArrangementStatus.fromWireValue(json['status']);
    if (status == null || json['lines'] is! List) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    final reviewDecision = switch (json['decision']) {
      'approved' => YorksV1ArrangementReviewDecision.approved,
      'returned' => YorksV1ArrangementReviewDecision.returned,
      _ => null,
    };
    return YorksV1ProcurementArrangement(
      id: _requiredString(json, 'id'),
      version: _positiveInt(json['arrangement_version']),
      status: status,
      isCurrent: json['is_current'] == true,
      recordVersion: _positiveInt(json['record_version']),
      startedByDisplayName: _requiredString(json, 'started_by_display_name'),
      startedAt: _requiredDate(json, 'started_at'),
      savedAt: _nullableDate(json['saved_at']),
      savedByDisplayName: _trimToNull(json['saved_by_display_name']),
      reviewDecision: reviewDecision,
      reviewReason: _trimToNull(json['decision_reason']),
      procurementNote: _trimToNull(json['procurement_note']),
      lines: [
        for (final line in json['lines'] as List)
          if (line is Map)
            YorksV1ArrangementLine.fromRpcJson(Map<String, dynamic>.from(line)),
      ],
    );
  }
}

/// Role-safe view of the complete arrangement history for one Material Request.
class YorksV1ArrangementWorkspace {
  YorksV1ArrangementWorkspace({
    required this.requestId,
    required this.requestState,
    required this.requestRecordVersion,
    required this.canBegin,
    required this.canSave,
    required this.canDecide,
    required List<YorksV1ProcurementArrangement> arrangements,
    this.requestNumber,
  }) : arrangements = List.unmodifiable(arrangements);

  final String requestId;
  final String? requestNumber;
  final String requestState;
  final int requestRecordVersion;
  final bool canBegin;
  final bool canSave;
  final bool canDecide;
  final List<YorksV1ProcurementArrangement> arrangements;

  YorksV1ProcurementArrangement? get workingArrangement {
    for (final arrangement in arrangements) {
      if (arrangement.status == YorksV1ArrangementStatus.working) {
        return arrangement;
      }
    }
    return null;
  }

  YorksV1ProcurementArrangement? get currentArrangement {
    for (final arrangement in arrangements) {
      if (arrangement.isCurrent) return arrangement;
    }
    return null;
  }

  factory YorksV1ArrangementWorkspace.fromRpcJson(Map<String, dynamic> json) {
    final rawArrangements = json['arrangements'];
    if (rawArrangements is! List) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1ArrangementWorkspace(
      requestId: _requiredString(json, 'request_id'),
      requestNumber: _trimToNull(json['request_number']),
      requestState: _requiredString(json, 'request_state'),
      requestRecordVersion: _positiveInt(json['request_record_version']),
      canBegin: json['can_begin'] == true,
      canSave: json['can_save'] == true,
      canDecide: json['can_decide'] == true,
      arrangements: [
        for (final arrangement in rawArrangements)
          if (arrangement is Map)
            YorksV1ProcurementArrangement.fromRpcJson(
              Map<String, dynamic>.from(arrangement),
            ),
      ],
    );
  }
}

class YorksV1ArrangementLineInput {
  const YorksV1ArrangementLineInput({
    required this.arrangementLineId,
    required this.source,
    required this.decision,
    required this.arrangedQuantity,
    this.externalSupplier,
    this.inventoryItemId,
    this.reason,
    this.unitCost,
  });

  final String arrangementLineId;
  final YorksV1ArrangementSource source;
  final YorksV1ArrangementDecision decision;
  final String arrangedQuantity;
  final String? externalSupplier;
  final String? inventoryItemId;
  final String? reason;
  final String? unitCost;

  Map<String, Object?> toRpcJson() => {
    'arrangement_line_id': arrangementLineId,
    'source_kind': source.wireValue,
    'external_supplier': _trimToNull(externalSupplier),
    'inventory_item_id': _trimToNull(inventoryItemId),
    'decision': decision.wireValue,
    'arranged_qty': arrangedQuantity.trim(),
    'reason': _trimToNull(reason),
    'unit_cost': _trimToNull(unitCost),
  };
}

class YorksV1BeginArrangementInput {
  const YorksV1BeginArrangementInput({
    required this.requestId,
    required this.expectedRequestVersion,
    required this.idempotencyKey,
  });

  final String requestId;
  final int expectedRequestVersion;
  final String idempotencyKey;

  Map<String, Object?> toRpcPayload() => {
    'request_id': requestId,
    'expected_version': expectedRequestVersion,
  };
}

class YorksV1SaveArrangementInput {
  YorksV1SaveArrangementInput({
    required this.requestId,
    required this.arrangementId,
    required this.expectedRequestVersion,
    required this.expectedArrangementVersion,
    required List<YorksV1ArrangementLineInput> lines,
    required this.idempotencyKey,
    this.procurementNote,
  }) : lines = List.unmodifiable(lines);

  final String requestId;
  final String arrangementId;
  final int expectedRequestVersion;
  final int expectedArrangementVersion;
  final List<YorksV1ArrangementLineInput> lines;
  final String idempotencyKey;
  final String? procurementNote;

  Map<String, Object?> toRpcPayload() => {
    'request_id': requestId,
    'arrangement_id': arrangementId,
    'expected_request_version': expectedRequestVersion,
    'expected_arrangement_version': expectedArrangementVersion,
    'procurement_note': _trimToNull(procurementNote),
    'lines': [for (final line in lines) line.toRpcJson()],
  };
}

class YorksV1DecideArrangementInput {
  const YorksV1DecideArrangementInput({
    required this.requestId,
    required this.arrangementId,
    required this.expectedRequestVersion,
    required this.expectedArrangementVersion,
    required this.decision,
    required this.idempotencyKey,
    this.reason,
  });

  final String requestId;
  final String arrangementId;
  final int expectedRequestVersion;
  final int expectedArrangementVersion;
  final YorksV1ArrangementReviewDecision decision;
  final String idempotencyKey;
  final String? reason;

  Map<String, Object?> toRpcPayload() => {
    'request_id': requestId,
    'arrangement_id': arrangementId,
    'expected_request_version': expectedRequestVersion,
    'expected_arrangement_version': expectedArrangementVersion,
    'decision': decision.wireValue,
    'reason': _trimToNull(reason),
  };
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
