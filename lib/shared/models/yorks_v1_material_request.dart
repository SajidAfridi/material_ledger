import 'yorks_v1_domain_error.dart';
import 'yorks_v1_item_description.dart';

const Object _keep = Object();

/// Keeps controlled Material Request and Delivery Order descriptions legible
/// without changing the remainder of a user-entered material name.
String normalizeYorksV1MaterialRequestItemDescription(String value) {
  return normalizeYorksV1ItemDescription(value);
}

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
  awaitingRequestApproval('awaiting_request_approval'),
  changesRequested('changes_requested'),
  approvedForArrangement('approved_for_arrangement'),
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

class YorksV1MaterialRequestMention {
  const YorksV1MaterialRequestMention({
    required this.authUserId,
    required this.displayName,
    required this.exactRole,
  });

  final String authUserId;
  final String displayName;
  final String exactRole;

  factory YorksV1MaterialRequestMention.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksV1MaterialRequestMention(
    authUserId: _requiredString(json, 'auth_user_id'),
    displayName: _requiredString(json, 'display_name'),
    exactRole: _requiredString(json, 'exact_role'),
  );
}

class YorksV1MaterialRequestComment {
  YorksV1MaterialRequestComment({
    required this.id,
    required this.requestId,
    required this.body,
    required this.authorAuthUserId,
    required this.authorRole,
    required this.authorExactRole,
    required this.authorDisplayName,
    required this.createdAt,
    required List<YorksV1MaterialRequestMention> mentions,
  }) : mentions = List.unmodifiable(mentions);

  final String id;
  final String requestId;
  final String body;
  final String authorAuthUserId;
  final String authorRole;
  final String authorExactRole;
  final String authorDisplayName;
  final DateTime createdAt;
  final List<YorksV1MaterialRequestMention> mentions;

  factory YorksV1MaterialRequestComment.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksV1MaterialRequestComment(
    id: _requiredString(json, 'id'),
    requestId: _requiredString(json, 'request_id'),
    body: _requiredString(json, 'body'),
    authorAuthUserId: _requiredString(json, 'author_auth_user_id'),
    authorRole: _requiredString(json, 'author_role'),
    authorExactRole: _requiredString(json, 'author_exact_role'),
    authorDisplayName: _requiredString(json, 'author_display_name'),
    createdAt: _requiredDate(json, 'created_at'),
    mentions: _maps(
      json['mentions'],
    ).map(YorksV1MaterialRequestMention.fromRpcJson).toList(growable: false),
  );
}

class YorksV1MaterialRequestDecision {
  const YorksV1MaterialRequestDecision({
    required this.id,
    required this.decision,
    required this.requestRecordVersion,
    required this.decidedByDisplayName,
    required this.decidedByRole,
    required this.decidedByExactRole,
    required this.decidedAt,
    this.reason,
  });

  final String id;
  final String decision;
  final String? reason;
  final int requestRecordVersion;
  final String decidedByDisplayName;
  final String decidedByRole;
  final String decidedByExactRole;
  final DateTime decidedAt;

  factory YorksV1MaterialRequestDecision.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksV1MaterialRequestDecision(
    id: _requiredString(json, 'id'),
    decision: _requiredString(json, 'decision'),
    reason: _trimToNull(json['reason']),
    requestRecordVersion: _positiveInt(json['request_record_version']),
    decidedByDisplayName: _requiredString(json, 'decided_by_display_name'),
    decidedByRole: _requiredString(json, 'decided_by_role'),
    decidedByExactRole: _requiredString(json, 'decided_by_exact_role'),
    decidedAt: _requiredDate(json, 'decided_at'),
  );
}

class YorksV1MaterialRequestInventorySuggestion {
  const YorksV1MaterialRequestInventorySuggestion({
    required this.id,
    required this.description,
    required this.unit,
    this.itemCode,
    this.brandOrigin,
    this.size,
    this.model,
  });

  final String id;
  final String? itemCode;
  final String description;
  final String? brandOrigin;
  final String? size;
  final String? model;
  final String unit;

  factory YorksV1MaterialRequestInventorySuggestion.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksV1MaterialRequestInventorySuggestion(
    id: _requiredString(json, 'id'),
    itemCode: _trimToNull(json['item_code']),
    description: _requiredString(json, 'item_description'),
    brandOrigin: _trimToNull(json['brand_origin']),
    size: _trimToNull(json['size']),
    model: _trimToNull(json['model']),
    unit: _requiredString(json, 'unit'),
  );
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
    this.size,
    this.model,
    this.equipmentTag,
    this.planningModelTag,
    this.quantityIsSuggested = false,
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

  /// Non-commercial technical context copied from BOQ/import rows. A model or
  /// equipment tag is intentionally separate from the manufacturer serial
  /// captured during receipt/asset registration.
  final String? size;
  final String? model;
  final String? equipmentTag;

  /// Compatibility field for pre-R35-size/model/tag records. New records use
  /// [model] and [equipmentTag] so source semantics are not collapsed.
  final String? planningModelTag;
  final bool quantityIsSuggested;
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
    Object? size = _keep,
    Object? model = _keep,
    Object? equipmentTag = _keep,
    Object? planningModelTag = _keep,
    String? quantity,
    String? unit,
    bool? quantityIsSuggested,
  }) => YorksV1MaterialRequestLine(
    id: id,
    displayOrder: displayOrder,
    source: source,
    description: description == null
        ? this.description
        : normalizeYorksV1MaterialRequestItemDescription(description),
    brandOrigin: identical(brandOrigin, _keep)
        ? this.brandOrigin
        : normalizeYorksV1OptionalItemText(brandOrigin),
    size: identical(size, _keep)
        ? this.size
        : normalizeYorksV1OptionalItemText(size),
    model: identical(model, _keep)
        ? this.model
        : normalizeYorksV1OptionalItemText(model),
    equipmentTag: identical(equipmentTag, _keep)
        ? this.equipmentTag
        : normalizeYorksV1OptionalItemText(equipmentTag),
    planningModelTag: identical(planningModelTag, _keep)
        ? this.planningModelTag
        : normalizeYorksV1OptionalItemText(planningModelTag),
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    quantityIsSuggested:
        quantityIsSuggested ??
        (quantity != null && quantity.trim() != this.quantity.trim()
            ? false
            : this.quantityIsSuggested),
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
    'description': normalizeYorksV1MaterialRequestItemDescription(description),
    'brandOrigin': normalizeYorksV1OptionalItemText(brandOrigin),
    'size': normalizeYorksV1OptionalItemText(size),
    'model': normalizeYorksV1OptionalItemText(model),
    'equipmentTag': normalizeYorksV1OptionalItemText(equipmentTag),
    'planningModelTag': normalizeYorksV1OptionalItemText(planningModelTag),
    'quantityIsSuggested': quantityIsSuggested,
    'quantity': quantity,
    'unit': unit,
    'sourceBoqGroupId': sourceBoqGroupId,
    'sourceBoqRowId': sourceBoqRowId,
  };

  Map<String, dynamic> toRpcJson() {
    final safeSize = normalizeYorksV1OptionalItemText(size);
    final safeModel = normalizeYorksV1OptionalItemText(model);
    final safeEquipmentTag = normalizeYorksV1OptionalItemText(equipmentTag);
    final safePlanningModelTag = normalizeYorksV1OptionalItemText(
      planningModelTag,
    );

    // The normalized RPC preserves every canonical technical value selected
    // from BOQ. Unknown worksheet-only columns remain in the BOQ worksheet and
    // are deliberately not promoted into this controlled MR schema.
    final technicalAttributes = <String, dynamic>{};
    if (safeSize != null) {
      technicalAttributes['size'] = safeSize;
    }
    if (safeModel != null) {
      technicalAttributes['model'] = safeModel;
    }
    if (safeEquipmentTag != null) {
      technicalAttributes['equipment_tag'] = safeEquipmentTag;
    }
    if (safePlanningModelTag != null) {
      technicalAttributes['planning_model_tag'] = safePlanningModelTag;
    }
    if (source == YorksV1MaterialRequestLineSource.boq) {
      technicalAttributes['quantity_suggested'] = quantityIsSuggested;
    }
    return {
      'id': id.trim(),
      'display_order': displayOrder,
      'source_kind': source.wireValue,
      'source_boq_group_id': _trimToNull(sourceBoqGroupId),
      'source_boq_row_id': _trimToNull(sourceBoqRowId),
      'item_description': normalizeYorksV1MaterialRequestItemDescription(
        description,
      ),
      'brand_origin': normalizeYorksV1OptionalItemText(brandOrigin),
      // Always send the object because the deployed function validates that it
      // exists even when empty.
      'technical_attributes': technicalAttributes,
      'requested_qty': quantity.trim(),
      'unit': unit.trim(),
    };
  }

  factory YorksV1MaterialRequestLine.fromDraftJson(Map<String, dynamic> json) {
    return YorksV1MaterialRequestLine(
      id: _string(json['id']),
      displayOrder: _positiveInt(json['displayOrder'] ?? json['display_order']),
      source: YorksV1MaterialRequestLineSource.fromWireValue(json['source']),
      description: normalizeYorksV1MaterialRequestItemDescription(
        _string(json['description'] ?? json['item_description']),
      ),
      brandOrigin: normalizeYorksV1OptionalItemText(
        json['brandOrigin'] ?? json['brand_origin'],
      ),
      size: normalizeYorksV1OptionalItemText(
        _technicalText(json['technical_attributes'], 'size') ?? json['size'],
      ),
      model: normalizeYorksV1OptionalItemText(
        _technicalText(json['technical_attributes'], 'model') ?? json['model'],
      ),
      equipmentTag: normalizeYorksV1OptionalItemText(
        _technicalText(json['technical_attributes'], 'equipment_tag') ??
            json['equipmentTag'] ??
            json['equipment_tag'],
      ),
      planningModelTag: normalizeYorksV1OptionalItemText(
        _technicalText(json['technical_attributes'], 'planning_model_tag') ??
            json['planningModelTag'] ??
            json['planning_model_tag'],
      ),
      quantityIsSuggested:
          _technicalText(json['technical_attributes'], 'quantity_suggested') ==
              'true' ||
          json['quantityIsSuggested'] == true ||
          json['quantity_suggested'] == true,
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
      description: normalizeYorksV1MaterialRequestItemDescription(
        _requiredString(json, 'item_description'),
      ),
      brandOrigin: normalizeYorksV1OptionalItemText(json['brand_origin']),
      size: normalizeYorksV1OptionalItemText(
        _technicalText(json['technical_attributes'], 'size'),
      ),
      model: normalizeYorksV1OptionalItemText(
        _technicalText(json['technical_attributes'], 'model'),
      ),
      equipmentTag: normalizeYorksV1OptionalItemText(
        _technicalText(json['technical_attributes'], 'equipment_tag'),
      ),
      planningModelTag: normalizeYorksV1OptionalItemText(
        _technicalText(json['technical_attributes'], 'planning_model_tag'),
      ),
      quantityIsSuggested:
          _technicalText(json['technical_attributes'], 'quantity_suggested') ==
          'true',
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

String? _technicalText(Object? attributes, String key) {
  if (attributes is! Map) return null;
  return _trimToNull(attributes[key]);
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
    this.canEditBeforeApproval = false,
    this.canDecideRequest = false,
    this.requestDecision,
    this.comments = const [],
    this.requestNumber,
    this.jobContractReference,
    this.title,
    this.scheduledDate,
    this.deliveryNote,
    this.requesterDisplayName,
    this.requesterProjectRole,
    this.requesterExactRole,
    this.documentIdentityVerified = false,
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
  final String? jobContractReference;
  final String scopeId;
  final String scopeName;
  final YorksV1MaterialRequestState state;
  final int recordVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final YorksV1MaterialRequestTiming timing;
  final bool canEditBeforeApproval;
  final bool canDecideRequest;
  final YorksV1MaterialRequestDecision? requestDecision;
  final List<YorksV1MaterialRequestComment> comments;
  final List<YorksV1MaterialRequestLine> lines;
  final String? requestNumber;
  final String? title;
  final DateTime? scheduledDate;
  final String? deliveryNote;
  final String? requesterDisplayName;
  final String? requesterProjectRole;

  /// The immutable exact server-controlled Auth role captured at submission.
  /// [requesterProjectRole] remains the normalized workflow role.
  final String? requesterExactRole;
  final bool documentIdentityVerified;
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
      jobContractReference: _trimToNull(json['job_contract_reference']),
      scopeId: _requiredString(json, 'scope_id'),
      scopeName: _requiredString(json, 'scope_name'),
      state: state,
      recordVersion: _positiveInt(json['record_version']),
      createdAt: _requiredDate(json, 'created_at'),
      updatedAt: _requiredDate(json, 'updated_at'),
      timing: timing,
      canEditBeforeApproval: json['can_edit_before_approval'] == true,
      canDecideRequest: json['can_decide_request'] == true,
      requestDecision: json['request_decision'] is Map
          ? YorksV1MaterialRequestDecision.fromRpcJson(
              Map<String, dynamic>.from(json['request_decision'] as Map),
            )
          : null,
      comments: _maps(
        json['comments'],
      ).map(YorksV1MaterialRequestComment.fromRpcJson).toList(growable: false),
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
      requesterExactRole: _trimToNull(json['requester_exact_role']),
      documentIdentityVerified: json['document_identity_verified'] == true,
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
    Object? submissionIdempotencyKey = _keep,
    YorksV1MaterialRequestTiming? timing,
    Object? scheduledDate = _keep,
    Object? deliveryNote = _keep,
    List<YorksV1MaterialRequestLine>? lines,
    DateTime? updatedAt,
  }) => YorksV1MaterialRequestDraft(
    id: id,
    ownerAuthUserId: ownerAuthUserId,
    submissionIdempotencyKey: identical(submissionIdempotencyKey, _keep)
        ? this.submissionIdempotencyKey
        : submissionIdempotencyKey as String,
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

  /// A draft is recoverable even before the server has enough information to
  /// accept it.  Save Draft therefore never uses submission validation as its
  /// gate; the controller persists this model locally and only sends it to
  /// the server once the server-side draft contract can be satisfied.
  bool get canSaveLocally => true;

  /// Local-only drafts are intentionally recoverable before they satisfy the
  /// connected save/submit contract.  Keep an empty, never-edited editor out
  /// of the resume list, but retain every meaningful field or line entered by
  /// its owner on this device.
  bool get hasRecoverableContent =>
      _trimToNull(projectId) != null ||
      _trimToNull(scopeId) != null ||
      _trimToNull(title) != null ||
      _trimToNull(deliveryNote) != null ||
      scheduledDate != null ||
      lines.isNotEmpty;

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

class YorksV1UpdateMaterialRequestForApprovalInput {
  const YorksV1UpdateMaterialRequestForApprovalInput({
    required this.draft,
    required this.idempotencyKey,
  });

  final YorksV1MaterialRequestDraft draft;
  final String idempotencyKey;

  Map<String, dynamic> toRpcPayload() => draft.toSaveInput().toRpcPayload();
}

enum YorksV1MaterialRequestReviewDecision {
  approved('approved'),
  returned('returned');

  const YorksV1MaterialRequestReviewDecision(this.wireValue);
  final String wireValue;
}

class YorksV1DecideMaterialRequestInput {
  const YorksV1DecideMaterialRequestInput({
    required this.requestId,
    required this.expectedVersion,
    required this.decision,
    required this.idempotencyKey,
    this.reason,
  });

  final String requestId;
  final int expectedVersion;
  final YorksV1MaterialRequestReviewDecision decision;
  final String? reason;
  final String idempotencyKey;

  Map<String, dynamic> toRpcPayload() => {
    'request_id': requestId.trim(),
    'expected_version': expectedVersion,
    'decision': decision.wireValue,
    'reason': _trimToNull(reason),
  };
}

class YorksV1AddMaterialRequestCommentInput {
  const YorksV1AddMaterialRequestCommentInput({
    required this.requestId,
    required this.body,
    required this.idempotencyKey,
    this.mentionedAuthUserIds = const [],
  });

  final String requestId;
  final String body;
  final String idempotencyKey;
  final List<String> mentionedAuthUserIds;

  Map<String, dynamic> toRpcPayload() => {
    'request_id': requestId.trim(),
    'body': body.trim(),
    'mentioned_auth_user_ids': [
      for (final id in mentionedAuthUserIds) id.trim(),
    ],
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

class YorksV1CloseMaterialRequestInput {
  const YorksV1CloseMaterialRequestInput({
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
