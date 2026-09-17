import 'yorks_v1_material_request.dart';

/// Narrow company-use model. It intentionally has no project or BOQ fields:
/// a company need must never turn a nullable project reference into authority.
class YorksV1CompanyMaterialRequestPerson {
  const YorksV1CompanyMaterialRequestPerson({
    required this.authUserId,
    required this.displayName,
  });

  final String authUserId;
  final String displayName;

  factory YorksV1CompanyMaterialRequestPerson.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksV1CompanyMaterialRequestPerson(
    authUserId: _requiredText(json, 'auth_user_id'),
    displayName: _requiredText(json, 'display_name'),
  );
}

class YorksV1CompanyMaterialRequestDraftOption {
  const YorksV1CompanyMaterialRequestDraftOption({
    required this.categoryId,
    required this.categoryCode,
    required this.categoryName,
    required this.responsibleUnitId,
    required this.responsibleUnitCode,
    required this.responsibleUnitName,
    required this.beneficiaries,
    required this.receivers,
  });

  final String categoryId;
  final String categoryCode;
  final String categoryName;
  final String responsibleUnitId;
  final String responsibleUnitCode;
  final String responsibleUnitName;
  final List<YorksV1CompanyMaterialRequestPerson> beneficiaries;
  final List<YorksV1CompanyMaterialRequestPerson> receivers;

  factory YorksV1CompanyMaterialRequestDraftOption.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksV1CompanyMaterialRequestDraftOption(
    categoryId: _requiredText(json, 'category_id'),
    categoryCode: _requiredText(json, 'category_code'),
    categoryName: _requiredText(json, 'category_name'),
    responsibleUnitId: _requiredText(json, 'responsible_unit_id'),
    responsibleUnitCode: _requiredText(json, 'responsible_unit_code'),
    responsibleUnitName: _requiredText(json, 'responsible_unit_name'),
    beneficiaries: _maps(json['beneficiaries'])
        .map(YorksV1CompanyMaterialRequestPerson.fromRpcJson)
        .toList(growable: false),
    receivers: _maps(json['receivers'])
        .map(YorksV1CompanyMaterialRequestPerson.fromRpcJson)
        .toList(growable: false),
  );
}

class YorksV1CompanyMaterialRequestApprovalPreflight {
  const YorksV1CompanyMaterialRequestApprovalPreflight({
    required this.approvalRouteId,
    required this.policyVersion,
    required this.approver,
  });

  final String approvalRouteId;
  final String policyVersion;
  final YorksV1CompanyMaterialRequestPerson approver;

  factory YorksV1CompanyMaterialRequestApprovalPreflight.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksV1CompanyMaterialRequestApprovalPreflight(
    approvalRouteId: _requiredText(json, 'approval_route_id'),
    policyVersion: _requiredText(json, 'policy_version'),
    approver: YorksV1CompanyMaterialRequestPerson(
      authUserId: _requiredText(json, 'approver_auth_user_id'),
      displayName: _requiredText(json, 'approver_display_name'),
    ),
  );
}

class YorksV1CompanyMaterialRequestLine {
  const YorksV1CompanyMaterialRequestLine({
    required this.id,
    required this.displayOrder,
    required this.description,
    required this.quantity,
    required this.unit,
    this.brandOrigin,
    this.arrangedQuantity = '0',
    this.dispatchedQuantity = '0',
    this.goodReceivedQuantity = '0',
    this.handedOverQuantity = '0',
    this.returnedQuantity = '0',
    this.withdrawnQuantity = '0',
    this.withdrawableQuantity = '0',
  });

  final String id;
  final int displayOrder;
  final String description;
  final String quantity;
  final String unit;
  final String? brandOrigin;
  final String arrangedQuantity;
  final String dispatchedQuantity;
  final String goodReceivedQuantity;
  final String handedOverQuantity;
  final String returnedQuantity;
  final String withdrawnQuantity;
  final String withdrawableQuantity;

  bool get isValid =>
      description.trim().isNotEmpty &&
      unit.trim().isNotEmpty &&
      _positiveDecimal(quantity);

  YorksV1CompanyMaterialRequestLine copyWith({
    String? id,
    int? displayOrder,
    String? description,
    String? quantity,
    String? unit,
    String? brandOrigin,
    bool clearBrandOrigin = false,
  }) => YorksV1CompanyMaterialRequestLine(
    id: id ?? this.id,
    displayOrder: displayOrder ?? this.displayOrder,
    description: description ?? this.description,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    brandOrigin: clearBrandOrigin ? null : brandOrigin ?? this.brandOrigin,
  );

  Map<String, dynamic> toRpcJson() => {
    'id': id,
    'display_order': displayOrder,
    'item_description': description.trim(),
    'brand_origin': _trimToNull(brandOrigin),
    'requested_qty': quantity.trim(),
    'unit': unit.trim(),
  };

  factory YorksV1CompanyMaterialRequestLine.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksV1CompanyMaterialRequestLine(
    id: _requiredText(json, 'id'),
    displayOrder: _requiredInt(json, 'display_order'),
    description: _requiredText(json, 'item_description'),
    quantity: _requiredText(json, 'requested_qty'),
    unit: _requiredText(json, 'unit'),
    brandOrigin: _trimToNull(json['brand_origin']?.toString()),
    arrangedQuantity: json['arranged_qty']?.toString() ?? '0',
    dispatchedQuantity: json['dispatched_qty']?.toString() ?? '0',
    goodReceivedQuantity: json['good_received_qty']?.toString() ?? '0',
    handedOverQuantity: json['handed_over_qty']?.toString() ?? '0',
    returnedQuantity: json['returned_qty']?.toString() ?? '0',
    withdrawnQuantity: json['withdrawn_qty']?.toString() ?? '0',
    withdrawableQuantity: json['withdrawable_qty']?.toString() ?? '0',
  );
}

class YorksV1CompanyMaterialRequestDraft {
  const YorksV1CompanyMaterialRequestDraft({
    required this.id,
    required this.recordVersion,
    required this.submissionIdempotencyKey,
    required this.timing,
    required this.lines,
    this.categoryId,
    this.responsibleUnitId,
    this.purpose,
    this.scheduledDate,
    this.deliveryCollectionPoint,
    this.beneficiaryAuthUserId,
    this.authorizedReceiverAuthUserId,
  });

  final String id;
  final int recordVersion;
  final String submissionIdempotencyKey;
  final YorksV1MaterialRequestTiming timing;
  final List<YorksV1CompanyMaterialRequestLine> lines;
  final String? categoryId;
  final String? responsibleUnitId;
  final String? purpose;
  final DateTime? scheduledDate;
  final String? deliveryCollectionPoint;
  final String? beneficiaryAuthUserId;
  final String? authorizedReceiverAuthUserId;

  YorksV1CompanyMaterialRequestDraft copyWith({
    int? recordVersion,
    YorksV1MaterialRequestTiming? timing,
    List<YorksV1CompanyMaterialRequestLine>? lines,
    String? categoryId,
    String? responsibleUnitId,
    String? purpose,
    DateTime? scheduledDate,
    String? deliveryCollectionPoint,
    String? beneficiaryAuthUserId,
    String? authorizedReceiverAuthUserId,
    bool clearScheduledDate = false,
    bool clearBeneficiary = false,
    bool clearAuthorizedReceiver = false,
  }) => YorksV1CompanyMaterialRequestDraft(
    id: id,
    recordVersion: recordVersion ?? this.recordVersion,
    submissionIdempotencyKey: submissionIdempotencyKey,
    timing: timing ?? this.timing,
    lines: lines ?? this.lines,
    categoryId: categoryId ?? this.categoryId,
    responsibleUnitId: responsibleUnitId ?? this.responsibleUnitId,
    purpose: purpose ?? this.purpose,
    scheduledDate: clearScheduledDate
        ? null
        : scheduledDate ?? this.scheduledDate,
    deliveryCollectionPoint:
        deliveryCollectionPoint ?? this.deliveryCollectionPoint,
    beneficiaryAuthUserId: clearBeneficiary
        ? null
        : beneficiaryAuthUserId ?? this.beneficiaryAuthUserId,
    authorizedReceiverAuthUserId: clearAuthorizedReceiver
        ? null
        : authorizedReceiverAuthUserId ?? this.authorizedReceiverAuthUserId,
  );

  bool get canSave =>
      categoryId != null &&
      responsibleUnitId != null &&
      purpose?.trim().isNotEmpty == true &&
      deliveryCollectionPoint?.trim().isNotEmpty == true &&
      beneficiaryAuthUserId != null &&
      authorizedReceiverAuthUserId != null &&
      (timing != YorksV1MaterialRequestTiming.scheduled ||
          scheduledDate != null) &&
      lines.isNotEmpty &&
      lines.every((line) => line.isValid);

  Map<String, dynamic> toSavePayload() => {
    'request_id': id,
    'expected_version': recordVersion,
    'category_id': categoryId,
    'responsible_unit_id': responsibleUnitId,
    'purpose': purpose?.trim(),
    'timing': timing.wireValue,
    'scheduled_date': scheduledDate == null
        ? null
        : '${scheduledDate!.year.toString().padLeft(4, '0')}-${scheduledDate!.month.toString().padLeft(2, '0')}-${scheduledDate!.day.toString().padLeft(2, '0')}',
    'delivery_collection_point': deliveryCollectionPoint?.trim(),
    'beneficiary_auth_user_id': beneficiaryAuthUserId,
    'authorized_receiver_auth_user_id': authorizedReceiverAuthUserId,
    'lines': [for (final line in lines) line.toRpcJson()],
  };
}

enum YorksV1CompanyMaterialRequestDecisionType {
  approved('approved'),
  returned('returned'),
  rejected('rejected');

  const YorksV1CompanyMaterialRequestDecisionType(this.wireValue);

  final String wireValue;
}

class YorksV1CompanyMaterialRequestDecision {
  const YorksV1CompanyMaterialRequestDecision({
    required this.id,
    required this.decision,
    required this.requestRecordVersion,
    required this.decidedByDisplayName,
    required this.decidedByExactRole,
    required this.decidedAt,
    this.reason,
  });

  final String id;
  final String decision;
  final String? reason;
  final int requestRecordVersion;
  final String decidedByDisplayName;
  final String decidedByExactRole;
  final DateTime decidedAt;

  factory YorksV1CompanyMaterialRequestDecision.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksV1CompanyMaterialRequestDecision(
    id: _requiredText(json, 'id'),
    decision: _requiredText(json, 'decision'),
    reason: _trimToNull(json['reason']?.toString()),
    requestRecordVersion: _requiredInt(json, 'request_record_version'),
    decidedByDisplayName: _requiredText(json, 'decided_by_display_name'),
    decidedByExactRole: _requiredText(json, 'decided_by_exact_role'),
    decidedAt:
        _date(json['decided_at']) ??
        (throw const FormatException('Missing decided_at')),
  );
}

class YorksV1CompanyMaterialRequestApprovalInboxItem {
  const YorksV1CompanyMaterialRequestApprovalInboxItem({
    required this.id,
    required this.requestNumber,
    required this.recordVersion,
    required this.state,
    required this.categoryName,
    required this.responsibleUnitName,
    required this.purpose,
    required this.requesterDisplayName,
    required this.beneficiaryDisplayName,
    required this.submittedAt,
    required this.lineCount,
  });

  final String id;
  final String requestNumber;
  final int recordVersion;
  final String state;
  final String categoryName;
  final String responsibleUnitName;
  final String purpose;
  final String requesterDisplayName;
  final String beneficiaryDisplayName;
  final DateTime submittedAt;
  final int lineCount;

  factory YorksV1CompanyMaterialRequestApprovalInboxItem.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksV1CompanyMaterialRequestApprovalInboxItem(
    id: _requiredText(json, 'id'),
    requestNumber: _requiredText(json, 'request_number'),
    recordVersion: _requiredInt(json, 'record_version'),
    state: _requiredText(json, 'state'),
    categoryName: _requiredText(json, 'category_name'),
    responsibleUnitName: _requiredText(json, 'responsible_unit_name'),
    purpose: _requiredText(json, 'purpose'),
    requesterDisplayName: _requiredText(json, 'requester_display_name'),
    beneficiaryDisplayName: _requiredText(json, 'beneficiary_display_name'),
    submittedAt:
        _date(json['submitted_at']) ??
        (throw const FormatException('Missing submitted_at')),
    lineCount: _requiredInt(json, 'line_count'),
  );
}

enum YorksV1CompanyMaterialRequestRegisterView {
  requests('requests'),
  planning('planning'),
  issueHistory('issue_history');

  const YorksV1CompanyMaterialRequestRegisterView(this.wireValue);
  final String wireValue;
}

class YorksV1CompanyMaterialRequest {
  const YorksV1CompanyMaterialRequest({
    required this.id,
    required this.recordVersion,
    required this.state,
    required this.categoryName,
    required this.responsibleUnitName,
    required this.purpose,
    required this.timing,
    required this.deliveryCollectionPoint,
    required this.beneficiary,
    required this.authorizedReceiver,
    required this.requesterDisplayName,
    required this.requesterExactRole,
    required this.lines,
    this.canDecide = false,
    this.canPlan = false,
    this.canDispatch = false,
    this.canReceive = false,
    this.canHandover = false,
    this.canClose = false,
    this.canSubmitReturn = false,
    this.canDecideReturns = false,
    this.canRevise = false,
    this.canWithdrawRemainder = false,
    this.currentSupplyPlan,
    this.pendingDispatches = const [],
    this.unallocatedReceiptLines = const [],
    this.returnableHandoverLines = const [],
    this.pendingReturns = const [],
    this.decisions = const [],
    this.requestNumber,
    this.scheduledDate,
    this.approver,
    this.approvalPolicyVersion,
  });

  final String id;
  final int recordVersion;
  final String state;
  final String categoryName;
  final String responsibleUnitName;
  final String purpose;
  final YorksV1MaterialRequestTiming timing;
  final DateTime? scheduledDate;
  final String deliveryCollectionPoint;
  final YorksV1CompanyMaterialRequestPerson beneficiary;
  final YorksV1CompanyMaterialRequestPerson authorizedReceiver;
  final String requesterDisplayName;
  final String requesterExactRole;
  final YorksV1CompanyMaterialRequestPerson? approver;
  final String? approvalPolicyVersion;
  final String? requestNumber;
  final List<YorksV1CompanyMaterialRequestLine> lines;
  final bool canDecide;
  final bool canPlan;
  final bool canDispatch;
  final bool canReceive;
  final bool canHandover;
  final bool canClose;
  final bool canSubmitReturn;
  final bool canDecideReturns;
  final bool canRevise;
  final bool canWithdrawRemainder;
  final Map<String, dynamic>? currentSupplyPlan;
  final List<Map<String, dynamic>> pendingDispatches;
  final List<Map<String, dynamic>> unallocatedReceiptLines;
  final List<Map<String, dynamic>> returnableHandoverLines;
  final List<Map<String, dynamic>> pendingReturns;
  final List<YorksV1CompanyMaterialRequestDecision> decisions;

  factory YorksV1CompanyMaterialRequest.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksV1CompanyMaterialRequest(
    id: _requiredText(json, 'id'),
    recordVersion: _requiredInt(json, 'record_version'),
    state: _requiredText(json, 'state'),
    categoryName: _requiredText(json, 'category_name'),
    responsibleUnitName: _requiredText(json, 'responsible_unit_name'),
    purpose: _requiredText(json, 'purpose'),
    timing:
        YorksV1MaterialRequestTiming.fromWireValue(json['timing']) ??
        YorksV1MaterialRequestTiming.normal,
    scheduledDate: _date(json['scheduled_date']),
    deliveryCollectionPoint: _requiredText(json, 'delivery_collection_point'),
    beneficiary: YorksV1CompanyMaterialRequestPerson(
      authUserId: _requiredText(json, 'beneficiary_auth_user_id'),
      displayName: _requiredText(json, 'beneficiary_display_name'),
    ),
    authorizedReceiver: YorksV1CompanyMaterialRequestPerson(
      authUserId: _requiredText(json, 'authorized_receiver_auth_user_id'),
      displayName: _requiredText(json, 'authorized_receiver_display_name'),
    ),
    requesterDisplayName: _requiredText(json, 'requester_display_name'),
    requesterExactRole: _requiredText(json, 'requester_exact_role'),
    approver: _trimToNull(json['approver_auth_user_id']?.toString()) == null
        ? null
        : YorksV1CompanyMaterialRequestPerson(
            authUserId: _requiredText(json, 'approver_auth_user_id'),
            displayName: _requiredText(json, 'approver_display_name'),
          ),
    approvalPolicyVersion: _trimToNull(
      json['approval_policy_version']?.toString(),
    ),
    requestNumber: _trimToNull(json['request_number']?.toString()),
    canDecide: json['can_decide'] == true,
    canPlan: json['can_plan'] == true,
    canDispatch: json['can_dispatch'] == true,
    canReceive: json['can_receive'] == true,
    canHandover: json['can_handover'] == true,
    canClose: json['can_close'] == true,
    canSubmitReturn: json['can_submit_return'] == true,
    canDecideReturns: json['can_decide_returns'] == true,
    canRevise: json['can_revise'] == true,
    canWithdrawRemainder: json['can_withdraw_remainder'] == true,
    currentSupplyPlan: json['current_supply_plan'] is Map
        ? Map<String, dynamic>.from(json['current_supply_plan'] as Map)
        : null,
    pendingDispatches: _maps(json['pending_dispatches']),
    unallocatedReceiptLines: _maps(json['unallocated_receipt_lines']),
    returnableHandoverLines: _maps(json['returnable_handover_lines']),
    pendingReturns: _maps(json['pending_returns']),
    lines: _maps(json['lines'])
        .map(YorksV1CompanyMaterialRequestLine.fromRpcJson)
        .toList(growable: false),
    decisions: _maps(json['decisions'])
        .map(YorksV1CompanyMaterialRequestDecision.fromRpcJson)
        .toList(growable: false),
  );
}

bool _positiveDecimal(String raw) {
  final parsed = double.tryParse(raw.trim());
  return parsed != null && parsed.isFinite && parsed > 0;
}

String _requiredText(Map<String, dynamic> json, String key) {
  final value = _trimToNull(json[key]?.toString());
  if (value == null) throw FormatException('Missing $key');
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ??
      (throw FormatException('Missing $key'));
}

DateTime? _date(Object? raw) {
  final value = _trimToNull(raw?.toString());
  return value == null ? null : DateTime.tryParse(value);
}

String? _trimToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

List<Map<String, dynamic>> _maps(Object? raw) => raw is! List
    ? const []
    : [
        for (final item in raw)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
