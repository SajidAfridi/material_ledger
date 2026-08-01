import 'yorks_v1_domain_error.dart';

const Object _keep = Object();

/// A controlled request timing value. The server independently enforces the
/// scheduled-date rule; this enum is only a typed client representation.
enum YorksV1MaterialRequestTiming {
  urgent('urgent'),
  normal('normal'),
  scheduled('scheduled');

  const YorksV1MaterialRequestTiming(this.wireValue);

  final String wireValue;

  static YorksV1MaterialRequestTiming? fromWireValue(Object? value) {
    if (value is! String) return null;
    for (final timing in values) {
      if (timing.wireValue == value) return timing;
    }
    return null;
  }
}

/// The immutable state machine for normalized Yorks material requests.
enum YorksV1MaterialRequestState {
  draft('draft'),
  submitted('submitted'),
  arranging('arranging'),
  awaitingApproval('awaiting_approval'),
  approved('approved'),
  partiallyDispatched('partially_dispatched'),
  dispatched('dispatched'),
  partiallyReceived('partially_received'),
  received('received'),
  closed('closed'),
  cancelled('cancelled');

  const YorksV1MaterialRequestState(this.wireValue);

  final String wireValue;

  static YorksV1MaterialRequestState? fromWireValue(Object? value) {
    if (value is! String) return null;
    for (final state in values) {
      if (state.wireValue == value) return state;
    }
    return null;
  }

  bool get isDraft => this == YorksV1MaterialRequestState.draft;
  bool get isSubmittedOrLater => !isDraft;
}

/// The source snapshot is retained for traceability only. BOQ changes after a
/// line is copied never rewrite this request line.
enum YorksV1MaterialRequestLineSource {
  boq('boq'),
  excel('excel'),
  custom('custom');

  const YorksV1MaterialRequestLineSource(this.wireValue);

  final String wireValue;

  static YorksV1MaterialRequestLineSource fromWireValue(Object? value) {
    if (value is String) {
      for (final source in values) {
        if (source.wireValue == value) return source;
      }
    }
    return YorksV1MaterialRequestLineSource.custom;
  }
}

/// Minimal non-commercial project picker record for MR drafting. It is not a
/// project workspace projection and intentionally carries no party/cost data.
class YorksV1MaterialRequestProjectOption {
  const YorksV1MaterialRequestProjectOption({
    required this.id,
    required this.reference,
    required this.name,
    required this.state,
  });

  final String id;
  final String reference;
  final String name;
  final String state;

  factory YorksV1MaterialRequestProjectOption.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksV1MaterialRequestProjectOption(
    id: _requiredString(json, 'id'),
    reference: _requiredString(json, 'project_ref'),
    name: _requiredString(json, 'name'),
    state: _requiredString(json, 'state'),
  );
}

/// Minimal scope picker record. Common is an explicit system-provided scope,
/// never an instruction to multiply the same line across physical buildings.
class YorksV1MaterialRequestScopeOption {
  const YorksV1MaterialRequestScopeOption({
    required this.id,
    required this.projectId,
    required this.name,
    required this.kind,
    this.deliveryAddress,
  });

  final String id;
  final String projectId;
  final String name;
  final String kind;
  final String? deliveryAddress;

  bool get isCommon => kind == 'common';

  factory YorksV1MaterialRequestScopeOption.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksV1MaterialRequestScopeOption(
    id: _requiredString(json, 'id'),
    projectId: _requiredString(json, 'project_id'),
    name: _requiredString(json, 'name'),
    kind: _requiredString(json, 'scope_kind'),
    deliveryAddress: _trimToNull(json['delivery_address']),
  );
}

/// One controlled MR line. Quantities are decimal text on the client to avoid
/// treating a Dart binary double as a commercial or transaction authority.
class YorksV1MaterialRequestLine {
  const YorksV1MaterialRequestLine({
    required this.id,
    required this.displayOrder,
    required this.source,
    required this.description,
    required this.quantity,
    required this.unit,
    this.brandOrigin,
    this.sourceBoqGroupId,
    this.sourceBoqRowId,
    this.unitCost,
    this.totalCost,
    this.currencyCode,
  });

  final String id;
  final int displayOrder;
  final YorksV1MaterialRequestLineSource source;
  final String description;
  final String? brandOrigin;
  final String quantity;
  final String unit;
  final String? sourceBoqGroupId;
  final String? sourceBoqRowId;

  /// These fields are present only in a server-authorized commercial
  /// projection. They are never persisted in a local engineering draft.
  final String? unitCost;
  final String? totalCost;
  final String? currencyCode;

  YorksV1MaterialRequestLine copyWith({
    String? description,
    Object? brandOrigin = _keep,
    String? quantity,
    String? unit,
  }) => YorksV1MaterialRequestLine(
    id: id,
    displayOrder: displayOrder,
    source: source,
    description: description ?? this.description,
    brandOrigin: identical(brandOrigin, _keep)
        ? this.brandOrigin
        : brandOrigin as String?,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    sourceBoqGroupId: sourceBoqGroupId,
    sourceBoqRowId: sourceBoqRowId,
    unitCost: unitCost,
    totalCost: totalCost,
    currencyCode: currencyCode,
  );

  bool get hasValidOperationalValues =>
      description.trim().isNotEmpty &&
      unit.trim().isNotEmpty &&
      _isPositiveDecimal(quantity);

  Map<String, dynamic> toDraftJson() => {
    'id': id,
    'displayOrder': displayOrder,
    'source': source.wireValue,
    'description': description,
    'brandOrigin': _trimToNull(brandOrigin),
    'quantity': quantity,
    'unit': unit,
    'sourceBoqGroupId': sourceBoqGroupId,
    'sourceBoqRowId': sourceBoqRowId,
  };

  Map<String, dynamic> toRpcJson() => {
    'id': id.trim(),
    'display_order': displayOrder,
    'source_kind': source.wireValue,
    'source_boq_group_id': _trimToNull(sourceBoqGroupId),
    'source_boq_row_id': _trimToNull(sourceBoqRowId),
    'item_description': description.trim(),
    'brand_origin': _trimToNull(brandOrigin),
    'requested_qty': quantity.trim(),
    'unit': unit.trim(),
  };

  factory YorksV1MaterialRequestLine.fromDraftJson(Map<String, dynamic> json) {
    return YorksV1MaterialRequestLine(
      id: _string(json['id']),
      displayOrder: _positiveInt(json['displayOrder'] ?? json['display_order']),
      source: YorksV1MaterialRequestLineSource.fromWireValue(json['source']),
      description: _string(json['description'] ?? json['item_description']),
      brandOrigin: _trimToNull(json['brandOrigin'] ?? json['brand_origin']),
      quantity: _string(json['quantity'] ?? json['requested_qty']),
      unit: _string(json['unit']),
      sourceBoqGroupId: _trimToNull(
        json['sourceBoqGroupId'] ?? json['source_boq_group_id'],
      ),
      sourceBoqRowId: _trimToNull(
        json['sourceBoqRowId'] ?? json['source_boq_row_id'],
      ),
    );
  }

  factory YorksV1MaterialRequestLine.fromRpcJson(Map<String, dynamic> json) {
    return YorksV1MaterialRequestLine(
      id: _requiredString(json, 'id'),
      displayOrder: _positiveInt(json['display_order']),
      source: YorksV1MaterialRequestLineSource.fromWireValue(
        json['source_kind'],
      ),
      description: _requiredString(json, 'item_description'),
      brandOrigin: _trimToNull(json['brand_origin']),
      quantity: _string(json['requested_qty']),
      unit: _requiredString(json, 'unit'),
      sourceBoqGroupId: _trimToNull(json['source_boq_group_id']),
      sourceBoqRowId: _trimToNull(json['source_boq_row_id']),
      unitCost: _trimToNull(json['unit_cost']),
      totalCost: _trimToNull(json['total_cost']),
      currencyCode: _trimToNull(json['currency_code']),
    );
  }
}

/// The server-authoritative request projection. For an unauthorized user, the
/// raw response has no commercial keys; [YorksV1MaterialRequestLine] therefore
/// carries null commercial values rather than masked or zeroed costs.
class YorksV1MaterialRequest {
  YorksV1MaterialRequest({
    required this.id,
    required this.projectId,
    required this.projectReference,
    required this.projectName,
    required this.scopeId,
    required this.scopeName,
    required this.state,
    required this.recordVersion,
    required this.createdAt,
    required this.updatedAt,
    required List<YorksV1MaterialRequestLine> lines,
    required this.timing,
    this.requestNumber,
    this.title,
    this.scheduledDate,
    this.deliveryNote,
    this.requesterDisplayName,
    this.requesterProjectRole,
    this.currentActionOwnerRole,
    this.currentActionCode,
    this.submittedAt,
    this.cancelledAt,
    this.cancellationReason,
  }) : lines = List.unmodifiable(lines);

  final String id;
  final String projectId;
  final String projectReference;
  final String projectName;
  final String scopeId;
  final String scopeName;
  final YorksV1MaterialRequestState state;
  final int recordVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final YorksV1MaterialRequestTiming timing;
  final List<YorksV1MaterialRequestLine> lines;
  final String? requestNumber;
  final String? title;
  final DateTime? scheduledDate;
  final String? deliveryNote;
  final String? requesterDisplayName;
  final String? requesterProjectRole;
  final String? currentActionOwnerRole;
  final String? currentActionCode;
  final DateTime? submittedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  factory YorksV1MaterialRequest.fromRpcJson(Map<String, dynamic> json) {
    final state = YorksV1MaterialRequestState.fromWireValue(json['state']);
    final timing = YorksV1MaterialRequestTiming.fromWireValue(json['timing']);
    if (state == null || timing == null) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    final rawLines = json['lines'];
    if (rawLines is! List) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1MaterialRequest(
      id: _requiredString(json, 'id'),
      projectId: _requiredString(json, 'project_id'),
      projectReference: _requiredString(json, 'project_ref'),
      projectName: _requiredString(json, 'project_name'),
      scopeId: _requiredString(json, 'scope_id'),
      scopeName: _requiredString(json, 'scope_name'),
      state: state,
      recordVersion: _positiveInt(json['record_version']),
      createdAt: _requiredDate(json, 'created_at'),
      updatedAt: _requiredDate(json, 'updated_at'),
      timing: timing,
      lines: [
        for (final line in rawLines)
          if (line is Map)
            YorksV1MaterialRequestLine.fromRpcJson(
              Map<String, dynamic>.from(line),
            ),
      ],
      requestNumber: _trimToNull(json['request_number']),
      title: _trimToNull(json['title']),
      scheduledDate: _nullableDate(json['scheduled_date']),
      deliveryNote: _trimToNull(json['delivery_note']),
      requesterDisplayName: _trimToNull(json['requester_display_name']),
      requesterProjectRole: _trimToNull(json['requester_project_role']),
      currentActionOwnerRole: _trimToNull(json['current_action_owner_role']),
      currentActionCode: _trimToNull(json['current_action_code']),
      submittedAt: _nullableDate(json['submitted_at']),
      cancelledAt: _nullableDate(json['cancelled_at']),
      cancellationReason: _trimToNull(json['cancellation_reason']),
    );
  }
}

/// Per-user/device recoverable input. It deliberately excludes commercial
/// values and survives an interrupted submission until the server confirms it.
class YorksV1MaterialRequestDraft {
  const YorksV1MaterialRequestDraft({
    required this.id,
    required this.ownerAuthUserId,
    required this.submissionIdempotencyKey,
    required this.updatedAt,
    this.serverRecordVersion = 0,
    this.projectId,
    this.scopeId,
    this.title,
    this.timing = YorksV1MaterialRequestTiming.normal,
    this.scheduledDate,
    this.deliveryNote,
    this.lines = const [],
  });

  static const Object _keep = Object();

  final String id;
  final String ownerAuthUserId;
  final String submissionIdempotencyKey;
  final int serverRecordVersion;
  final String? projectId;
  final String? scopeId;
  final String? title;
  final YorksV1MaterialRequestTiming timing;
  final DateTime? scheduledDate;
  final String? deliveryNote;
  final List<YorksV1MaterialRequestLine> lines;
  final DateTime updatedAt;

  factory YorksV1MaterialRequestDraft.empty({
    required String id,
    required String ownerAuthUserId,
    required String submissionIdempotencyKey,
  }) => YorksV1MaterialRequestDraft(
    id: id,
    ownerAuthUserId: ownerAuthUserId,
    submissionIdempotencyKey: submissionIdempotencyKey,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  YorksV1MaterialRequestDraft copyWith({
    int? serverRecordVersion,
    Object? projectId = _keep,
    Object? scopeId = _keep,
    Object? title = _keep,
    YorksV1MaterialRequestTiming? timing,
    Object? scheduledDate = _keep,
    Object? deliveryNote = _keep,
    List<YorksV1MaterialRequestLine>? lines,
    DateTime? updatedAt,
  }) => YorksV1MaterialRequestDraft(
    id: id,
    ownerAuthUserId: ownerAuthUserId,
    submissionIdempotencyKey: submissionIdempotencyKey,
    serverRecordVersion: serverRecordVersion ?? this.serverRecordVersion,
    projectId: identical(projectId, _keep)
        ? this.projectId
        : projectId as String?,
    scopeId: identical(scopeId, _keep) ? this.scopeId : scopeId as String?,
    title: identical(title, _keep) ? this.title : title as String?,
    timing: timing ?? this.timing,
    scheduledDate: identical(scheduledDate, _keep)
        ? this.scheduledDate
        : scheduledDate as DateTime?,
    deliveryNote: identical(deliveryNote, _keep)
        ? this.deliveryNote
        : deliveryNote as String?,
    lines: List.unmodifiable(lines ?? this.lines),
    updatedAt: updatedAt ?? this.updatedAt,
  );

  bool get canSubmitLocally =>
      _trimToNull(projectId) != null &&
      _trimToNull(scopeId) != null &&
      (timing != YorksV1MaterialRequestTiming.scheduled ||
          scheduledDate != null) &&
      lines.isNotEmpty &&
      lines.every((line) => line.hasValidOperationalValues);

  YorksV1SaveMaterialRequestDraftInput toSaveInput() =>
      YorksV1SaveMaterialRequestDraftInput(draft: this);

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerAuthUserId': ownerAuthUserId,
    'submissionIdempotencyKey': submissionIdempotencyKey,
    'serverRecordVersion': serverRecordVersion,
    'projectId': projectId,
    'scopeId': scopeId,
    'title': _trimToNull(title),
    'timing': timing.wireValue,
    'scheduledDate': _calendarDateText(scheduledDate),
    'deliveryNote': _trimToNull(deliveryNote),
    'lines': [for (final line in lines) line.toDraftJson()],
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory YorksV1MaterialRequestDraft.fromJson(Map<String, dynamic> json) {
    return YorksV1MaterialRequestDraft(
      id: _string(json['id']),
      ownerAuthUserId: _string(json['ownerAuthUserId']),
      submissionIdempotencyKey: _string(json['submissionIdempotencyKey']),
      serverRecordVersion: _nonNegativeInt(json['serverRecordVersion']),
      projectId: _trimToNull(json['projectId']),
      scopeId: _trimToNull(json['scopeId']),
      title: _trimToNull(json['title']),
      timing:
          YorksV1MaterialRequestTiming.fromWireValue(json['timing']) ??
          YorksV1MaterialRequestTiming.normal,
      scheduledDate: _calendarDate(json['scheduledDate']),
      deliveryNote: _trimToNull(json['deliveryNote']),
      lines: _maps(
        json['lines'],
      ).map(YorksV1MaterialRequestLine.fromDraftJson).toList(growable: false),
      updatedAt:
          _nullableDate(json['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class YorksV1SaveMaterialRequestDraftInput {
  const YorksV1SaveMaterialRequestDraftInput({required this.draft});

  final YorksV1MaterialRequestDraft draft;

  Map<String, dynamic> toRpcPayload() => {
    'request_id': draft.id,
    'expected_version': draft.serverRecordVersion,
    'project_id': _trimToNull(draft.projectId),
    'scope_id': _trimToNull(draft.scopeId),
    'title': _trimToNull(draft.title),
    'timing': draft.timing.wireValue,
    'scheduled_date': _calendarDateText(draft.scheduledDate),
    'delivery_note': _trimToNull(draft.deliveryNote),
    'lines': [for (final line in draft.lines) line.toRpcJson()],
  };
}

class YorksV1SubmitMaterialRequestInput {
  const YorksV1SubmitMaterialRequestInput({
    required this.requestId,
    required this.expectedVersion,
    required this.idempotencyKey,
  });

  final String requestId;
  final int expectedVersion;
  final String idempotencyKey;

  Map<String, dynamic> toRpcPayload() => {
    'request_id': requestId.trim(),
    'expected_version': expectedVersion,
  };
}

class YorksV1CancelMaterialRequestInput {
  const YorksV1CancelMaterialRequestInput({
    required this.requestId,
    required this.expectedVersion,
    required this.reason,
    required this.idempotencyKey,
  });

  final String requestId;
  final int expectedVersion;
  final String reason;
  final String idempotencyKey;

  Map<String, dynamic> toRpcPayload() => {
    'request_id': requestId.trim(),
    'expected_version': expectedVersion,
    'reason': reason.trim(),
  };
}

String _string(Object? value) => switch (value) {
  String text => text,
  num number => number.toString(),
  _ => '',
};

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _trimToNull(json[key]);
  if (value == null) {
    throw const YorksV1DomainException(
      YorksV1DomainErrorCode.unexpectedResponse,
    );
  }
  return value;
}

String? _trimToNull(Object? value) {
  final text = _string(value).trim();
  return text.isEmpty ? null : text;
}

int _nonNegativeInt(Object? value) => switch (value) {
  int integer when integer >= 0 => integer,
  num number when number >= 0 => number.toInt(),
  String text => int.tryParse(text) ?? 0,
  _ => 0,
};

int _positiveInt(Object? value) {
  final parsed = _nonNegativeInt(value);
  return parsed > 0 ? parsed : 1;
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _nullableDate(json[key]);
  if (value == null) {
    throw const YorksV1DomainException(
      YorksV1DomainErrorCode.unexpectedResponse,
    );
  }
  return value;
}

DateTime? _nullableDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}

DateTime? _calendarDate(Object? value) {
  if (value is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value.trim());
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

String? _calendarDateText(DateTime? value) {
  if (value == null) return null;
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

bool _isPositiveDecimal(String value) {
  final normalized = value.trim();
  if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(normalized)) return false;
  return (num.tryParse(normalized) ?? 0) > 0;
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return [
    for (final entry in value)
      if (entry is Map) Map<String, dynamic>.from(entry),
  ];
}
