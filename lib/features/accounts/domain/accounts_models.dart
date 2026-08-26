import 'accounts_decimal.dart';

enum YorksAccountsReviewStatus {
  notRequired('not_required'),
  pending('pending'),
  approved('approved'),
  returned('returned');

  const YorksAccountsReviewStatus(this.wireValue);
  final String wireValue;

  static YorksAccountsReviewStatus? tryParse(Object? raw) {
    final value = raw?.toString().trim().toLowerCase();
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }
}

final class YorksAccountsCapabilities {
  const YorksAccountsCapabilities({
    required this.canView,
    required this.canViewValues,
    required this.canConfigure,
    required this.canSuggest,
    required this.canConfirm,
    required this.canReview,
  });

  final bool canView;
  final bool canViewValues;
  final bool canConfigure;
  final bool canSuggest;
  final bool canConfirm;
  final bool canReview;

  factory YorksAccountsCapabilities.fromRpcJson(Map<String, dynamic> json) {
    return YorksAccountsCapabilities(
      canView: _bool(json, 'can_view'),
      canViewValues: _bool(json, 'can_view_values'),
      canConfigure: _bool(json, 'can_configure'),
      canSuggest: _bool(json, 'can_suggest'),
      canConfirm: _bool(json, 'can_confirm'),
      canReview: _bool(json, 'can_review'),
    );
  }
}

final class YorksAccountsCommandAvailability {
  YorksAccountsCommandAvailability._(Map<String, bool> values)
    : _values = Map.unmodifiable(values);

  final Map<String, bool> _values;

  factory YorksAccountsCommandAvailability.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final values = <String, bool>{};
    for (final entry in json.entries) {
      final value = entry.value;
      if (value is bool) values[entry.key] = value;
    }
    return YorksAccountsCommandAvailability._(values);
  }

  bool allows(String command) => _values[command] ?? false;
  Map<String, bool> get values => _values;
}

final class YorksAccountsManagementReviewPolicy {
  YorksAccountsManagementReviewPolicy({
    required this.alwaysRequired,
    required this.thresholdAmount,
    required List<String> confirmingExactRoles,
  }) : confirmingExactRoles = List.unmodifiable(confirmingExactRoles);

  final bool alwaysRequired;
  final YorksAccountsDecimal? thresholdAmount;
  final List<String> confirmingExactRoles;

  bool get isValid =>
      (thresholdAmount == null ||
          (thresholdAmount!.isPositive &&
              thresholdAmount!.fractionDigits <= 2)) &&
      confirmingExactRoles.every(_isReviewRole) &&
      confirmingExactRoles.toSet().length == confirmingExactRoles.length;

  factory YorksAccountsManagementReviewPolicy.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    const allowedKeys = {
      'always_required',
      'threshold_amount',
      'confirming_exact_roles',
    };
    if (json.keys.any((key) => !allowedKeys.contains(key))) {
      throw const FormatException('Unknown management review policy field.');
    }
    final alwaysRequired = json['always_required'];
    if (alwaysRequired is! bool) {
      throw FormatException(
        'always_required must be a boolean.',
        alwaysRequired,
      );
    }
    final policy = YorksAccountsManagementReviewPolicy(
      alwaysRequired: alwaysRequired,
      thresholdAmount: _optionalDecimal(json, 'threshold_amount'),
      confirmingExactRoles: _stringList(json['confirming_exact_roles']),
    );
    if (!policy.isValid) {
      throw const FormatException('Invalid management review policy.');
    }
    return policy;
  }

  Map<String, Object?> toRpcJson() => {
    'always_required': alwaysRequired,
    'threshold_amount': thresholdAmount?.postgresText,
    'confirming_exact_roles': confirmingExactRoles,
  };
}

final class YorksAccountsBaselineRevision {
  const YorksAccountsBaselineRevision({
    required this.revisionId,
    required this.revisionNumber,
    required this.recordVersion,
    required this.status,
    required this.contractValue,
    required this.currencyCode,
    required this.vatRate,
    required this.paymentTermsDays,
    required this.reminderLeadDays,
    required this.reason,
    required this.createdAt,
    required this.createdBy,
    required this.managementReviewPolicy,
  });

  final String revisionId;
  final int revisionNumber;
  final int recordVersion;
  final String status;
  final YorksAccountsDecimal? contractValue;
  final String? currencyCode;
  final YorksAccountsDecimal? vatRate;
  final int? paymentTermsDays;
  final int? reminderLeadDays;
  final String? reason;
  final DateTime? createdAt;
  final String? createdBy;
  final YorksAccountsManagementReviewPolicy? managementReviewPolicy;

  factory YorksAccountsBaselineRevision.fromRpcJson(
    Map<String, dynamic> json, {
    required bool canViewValues,
  }) {
    return YorksAccountsBaselineRevision(
      revisionId: _requiredStringAny(json, const ['revision_id', 'id']),
      revisionNumber: _requiredIntAny(json, const [
        'revision_number',
        'baseline_revision_number',
      ]),
      recordVersion: _requiredIntAny(json, const ['record_version', 'version']),
      status: _requiredString(json, 'status'),
      contractValue: _protectedDecimal(json, 'contract_value', canViewValues),
      currencyCode: _protectedString(json, 'currency_code', canViewValues),
      vatRate: _protectedDecimal(json, 'vat_rate', canViewValues),
      paymentTermsDays: _protectedInt(
        json,
        'payment_terms_days',
        canViewValues,
      ),
      reminderLeadDays: _protectedInt(
        json,
        'reminder_lead_days',
        canViewValues,
      ),
      reason: _optionalString(json['reason']),
      createdAt: _optionalDateTime(json['created_at']),
      createdBy: _optionalString(json['created_by']),
      managementReviewPolicy: _protectedReviewPolicy(json, canViewValues),
    );
  }

  YorksAccountsBaselineRevision withoutProtectedValues() {
    return YorksAccountsBaselineRevision(
      revisionId: revisionId,
      revisionNumber: revisionNumber,
      recordVersion: recordVersion,
      status: status,
      contractValue: null,
      currencyCode: null,
      vatRate: null,
      paymentTermsDays: null,
      reminderLeadDays: null,
      reason: reason,
      createdAt: createdAt,
      createdBy: createdBy,
      managementReviewPolicy: null,
    );
  }
}

final class YorksAccountsBuildingAllocation {
  const YorksAccountsBuildingAllocation({
    required this.allocationId,
    required this.buildingScopeId,
    required this.buildingName,
    required this.allocationPercent,
    required this.allocatedValue,
  });

  final String allocationId;
  final String buildingScopeId;
  final String? buildingName;
  final YorksAccountsDecimal allocationPercent;
  final YorksAccountsDecimal? allocatedValue;

  factory YorksAccountsBuildingAllocation.fromRpcJson(
    Map<String, dynamic> json, {
    required bool canViewValues,
  }) {
    return YorksAccountsBuildingAllocation(
      allocationId: _requiredStringAny(json, const ['allocation_id', 'id']),
      buildingScopeId: _requiredString(json, 'building_scope_id'),
      buildingName: _optionalString(json['building_name']),
      allocationPercent: _requiredDecimal(json, 'allocation_percent'),
      allocatedValue: _protectedDecimal(json, 'allocated_value', canViewValues),
    );
  }

  YorksAccountsBuildingAllocation withoutProtectedValues() =>
      YorksAccountsBuildingAllocation(
        allocationId: allocationId,
        buildingScopeId: buildingScopeId,
        buildingName: buildingName,
        allocationPercent: allocationPercent,
        allocatedValue: null,
      );
}

/// Active physical project scope available to the commercial baseline editor.
///
/// This is deliberately separate from an allocation: a project without a
/// baseline still needs a protected, server-authoritative list of buildings,
/// while Common / All Buildings must never become a commercial allocation.
final class YorksAccountsPhysicalBuilding {
  const YorksAccountsPhysicalBuilding({
    required this.buildingScopeId,
    required this.buildingName,
    required this.scopeCode,
  });

  final String buildingScopeId;
  final String buildingName;
  final String scopeCode;

  factory YorksAccountsPhysicalBuilding.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksAccountsPhysicalBuilding(
    buildingScopeId: _requiredString(json, 'building_scope_id'),
    buildingName: _requiredString(json, 'building_name'),
    scopeCode: _requiredString(json, 'scope_code'),
  );
}

final class YorksAccountsStageAllocation {
  const YorksAccountsStageAllocation({
    required this.allocationId,
    required this.stageKey,
    required this.stageLabel,
    required this.position,
    required this.allocationPercent,
    required this.stageValue,
  });

  final String allocationId;
  final String stageKey;
  final String? stageLabel;
  final int position;
  final YorksAccountsDecimal allocationPercent;
  final YorksAccountsDecimal? stageValue;

  factory YorksAccountsStageAllocation.fromRpcJson(
    Map<String, dynamic> json, {
    required bool canViewValues,
  }) {
    return YorksAccountsStageAllocation(
      allocationId: _requiredStringAny(json, const ['allocation_id', 'id']),
      stageKey: _requiredString(json, 'stage_key'),
      stageLabel: _optionalString(json['stage_label']),
      position: _requiredIntAny(json, const ['position', 'sort_order']),
      allocationPercent: _requiredDecimal(json, 'allocation_percent'),
      stageValue: _protectedDecimal(json, 'stage_value', canViewValues),
    );
  }

  YorksAccountsStageAllocation withoutProtectedValues() =>
      YorksAccountsStageAllocation(
        allocationId: allocationId,
        stageKey: stageKey,
        stageLabel: stageLabel,
        position: position,
        allocationPercent: allocationPercent,
        stageValue: null,
      );
}

final class YorksAccountsStageTemplate {
  const YorksAccountsStageTemplate({
    required this.stageKey,
    required this.stageLabel,
    required this.position,
    required this.allocationPercent,
  });

  final String stageKey;
  final String stageLabel;
  final int position;
  final YorksAccountsDecimal allocationPercent;

  factory YorksAccountsStageTemplate.fromRpcJson(Map<String, dynamic> json) =>
      YorksAccountsStageTemplate(
        stageKey: _requiredString(json, 'stage_key'),
        stageLabel: _requiredString(json, 'stage_label'),
        position: _requiredIntAny(json, const ['position']),
        allocationPercent: _requiredDecimal(json, 'allocation_percent'),
      );
}

final class YorksAccountsBaselineProjection {
  YorksAccountsBaselineProjection({
    required this.schemaVersion,
    required this.projectId,
    required this.baseline,
    required List<YorksAccountsPhysicalBuilding> physicalBuildings,
    required List<YorksAccountsStageTemplate> stageTemplates,
    required List<YorksAccountsBuildingAllocation> buildingAllocations,
    required List<YorksAccountsStageAllocation> stageAllocations,
    required this.capabilities,
    required this.commands,
  }) : physicalBuildings = List.unmodifiable(physicalBuildings),
       stageTemplates = List.unmodifiable(stageTemplates),
       buildingAllocations = List.unmodifiable(buildingAllocations),
       stageAllocations = List.unmodifiable(stageAllocations);

  final String projectId;
  final int schemaVersion;
  final YorksAccountsBaselineRevision? baseline;
  final List<YorksAccountsPhysicalBuilding> physicalBuildings;
  final List<YorksAccountsStageTemplate> stageTemplates;
  final List<YorksAccountsBuildingAllocation> buildingAllocations;
  final List<YorksAccountsStageAllocation> stageAllocations;
  final YorksAccountsCapabilities capabilities;
  final YorksAccountsCommandAvailability commands;

  factory YorksAccountsBaselineProjection.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final schemaVersion = _schemaVersion(json);
    final capabilities = YorksAccountsCapabilities.fromRpcJson(
      _requiredMap(json, 'capabilities'),
    );
    if (!capabilities.canViewValues) {
      _rejectProtectedKeys(json);
    }
    final baselineJson = json['baseline'];
    return YorksAccountsBaselineProjection(
      schemaVersion: schemaVersion,
      projectId: _requiredString(json, 'project_id'),
      baseline: baselineJson == null
          ? null
          : YorksAccountsBaselineRevision.fromRpcJson(
              _asMap(baselineJson, 'baseline'),
              canViewValues: capabilities.canViewValues,
            ),
      physicalBuildings: _mapList(
        json['physical_buildings'],
      ).map(YorksAccountsPhysicalBuilding.fromRpcJson).toList(growable: false),
      stageTemplates: _mapList(
        json['stage_templates'],
      ).map(YorksAccountsStageTemplate.fromRpcJson).toList(growable: false),
      buildingAllocations: _mapList(json['building_allocations'])
          .map(
            (item) => YorksAccountsBuildingAllocation.fromRpcJson(
              item,
              canViewValues: capabilities.canViewValues,
            ),
          )
          .toList(growable: false),
      stageAllocations: _mapList(json['stage_allocations'])
          .map(
            (item) => YorksAccountsStageAllocation.fromRpcJson(
              item,
              canViewValues: capabilities.canViewValues,
            ),
          )
          .toList(growable: false),
      capabilities: capabilities,
      commands: YorksAccountsCommandAvailability.fromRpcJson(
        _optionalMap(json['commands']),
      ),
    );
  }

  YorksAccountsBaselineProjection withoutProtectedValues() =>
      YorksAccountsBaselineProjection(
        schemaVersion: schemaVersion,
        projectId: projectId,
        baseline: baseline?.withoutProtectedValues(),
        physicalBuildings: physicalBuildings,
        stageTemplates: stageTemplates,
        buildingAllocations: buildingAllocations
            .map((item) => item.withoutProtectedValues())
            .toList(growable: false),
        stageAllocations: stageAllocations
            .map((item) => item.withoutProtectedValues())
            .toList(growable: false),
        capabilities: YorksAccountsCapabilities(
          canView: capabilities.canView,
          canViewValues: false,
          canConfigure: false,
          canSuggest: false,
          canConfirm: false,
          canReview: false,
        ),
        commands: YorksAccountsCommandAvailability.fromRpcJson(const {}),
      );
}

/// Compact immutable history carried with each progress register row.
///
/// The dedicated revision projection below carries the complete before/after
/// audit record. Keeping the two wire shapes distinct prevents a compact
/// register response from being silently interpreted as a full audit record.
final class YorksAccountsProgressRevisionSummary {
  const YorksAccountsProgressRevisionSummary({
    required this.revisionNumber,
    required this.action,
    required this.suggestedPercent,
    required this.confirmedPercent,
    required this.reason,
    required this.actorAuthUserId,
    required this.createdAt,
  });

  final int revisionNumber;
  final String action;
  final YorksAccountsDecimal suggestedPercent;
  final YorksAccountsDecimal confirmedPercent;
  final String? reason;
  final String? actorAuthUserId;
  final DateTime? createdAt;

  factory YorksAccountsProgressRevisionSummary.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksAccountsProgressRevisionSummary(
    revisionNumber: _requiredIntAny(json, const ['revision_number']),
    action: _requiredString(json, 'action'),
    suggestedPercent: _requiredDecimal(json, 'suggested_percent'),
    confirmedPercent: _requiredDecimal(json, 'confirmed_percent'),
    reason: _optionalString(json['reason']),
    actorAuthUserId: _optionalString(json['actor_auth_user_id']),
    createdAt: _optionalDateTime(json['created_at']),
  );
}

final class YorksAccountsProgressRevision {
  YorksAccountsProgressRevision({
    required this.revisionId,
    required this.revisionNumber,
    required this.action,
    required this.previousSuggestedPercent,
    required this.newSuggestedPercent,
    required this.previousConfirmedPercent,
    required this.newConfirmedPercent,
    required this.previousReviewStatus,
    required this.newReviewStatus,
    required this.evidenceSummary,
    required List<String> evidenceDocumentIds,
    required this.reason,
    required this.actorAuthUserId,
    required this.actorRole,
    required this.actorExactRole,
    required this.occurredAt,
  }) : evidenceDocumentIds = List.unmodifiable(evidenceDocumentIds);

  final String revisionId;
  final int revisionNumber;
  final String action;
  final YorksAccountsDecimal previousSuggestedPercent;
  final YorksAccountsDecimal newSuggestedPercent;
  final YorksAccountsDecimal previousConfirmedPercent;
  final YorksAccountsDecimal newConfirmedPercent;
  final YorksAccountsReviewStatus previousReviewStatus;
  final YorksAccountsReviewStatus newReviewStatus;
  final String? evidenceSummary;
  final List<String> evidenceDocumentIds;
  final String? reason;
  final String? actorAuthUserId;
  final String? actorRole;
  final String? actorExactRole;
  final DateTime? occurredAt;

  factory YorksAccountsProgressRevision.fromRpcJson(Map<String, dynamic> json) {
    final previousReviewStatus = YorksAccountsReviewStatus.tryParse(
      json['previous_review_status'],
    );
    final newReviewStatus = YorksAccountsReviewStatus.tryParse(
      json['new_review_status'],
    );
    if (previousReviewStatus == null || newReviewStatus == null) {
      throw const FormatException('Invalid progress revision review status.');
    }
    return YorksAccountsProgressRevision(
      revisionId: _requiredStringAny(json, const ['revision_id', 'id']),
      revisionNumber: _requiredIntAny(json, const [
        'revision_number',
        'version',
      ]),
      action: _requiredString(json, 'action'),
      previousSuggestedPercent: _requiredDecimal(
        json,
        'previous_suggested_percent',
      ),
      newSuggestedPercent: _requiredDecimal(json, 'new_suggested_percent'),
      previousConfirmedPercent: _requiredDecimal(
        json,
        'previous_confirmed_percent',
      ),
      newConfirmedPercent: _requiredDecimal(json, 'new_confirmed_percent'),
      previousReviewStatus: previousReviewStatus,
      newReviewStatus: newReviewStatus,
      evidenceSummary: _optionalString(json['evidence_summary']),
      evidenceDocumentIds: _stringList(json['evidence_document_ids']),
      reason: _optionalString(json['reason']),
      actorAuthUserId: _optionalString(json['actor_auth_user_id']),
      actorRole: _optionalString(json['actor_role']),
      actorExactRole: _optionalString(json['actor_exact_role']),
      occurredAt: _optionalDateTime(json['occurred_at']),
    );
  }
}

final class YorksAccountsProgressRevisionProjection {
  YorksAccountsProgressRevisionProjection({
    required this.schemaVersion,
    required this.projectId,
    required this.progressEntryId,
    required List<YorksAccountsProgressRevision> revisions,
    required this.nextCursor,
    required this.capabilities,
  }) : revisions = List.unmodifiable(revisions);

  final String projectId;
  final int schemaVersion;
  final String progressEntryId;
  final List<YorksAccountsProgressRevision> revisions;
  final int? nextCursor;
  final YorksAccountsCapabilities capabilities;

  factory YorksAccountsProgressRevisionProjection.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final schemaVersion = _requiredIntAny(json, const ['schema_version']);
    if (schemaVersion != 2) {
      throw FormatException(
        'Unsupported Accounts schema version.',
        schemaVersion,
      );
    }
    final capabilities = YorksAccountsCapabilities.fromRpcJson(
      _requiredMap(json, 'capabilities'),
    );
    if (!capabilities.canViewValues) _rejectProtectedKeys(json);
    return YorksAccountsProgressRevisionProjection(
      schemaVersion: schemaVersion,
      projectId: _requiredString(json, 'project_id'),
      progressEntryId: _requiredString(json, 'progress_entry_id'),
      revisions: _mapList(
        json['revisions'],
      ).map(YorksAccountsProgressRevision.fromRpcJson).toList(growable: false),
      nextCursor: _optionalInt(json['next_cursor']),
      capabilities: capabilities,
    );
  }
}

final class YorksAccountsNextAction {
  const YorksAccountsNextAction({
    required this.code,
    required this.entityId,
    required this.ownerRole,
    required this.blockingReasonCode,
    required this.isAvailable,
  });

  final String code;
  final String? entityId;
  final String? ownerRole;
  final String? blockingReasonCode;
  final bool isAvailable;

  factory YorksAccountsNextAction.fromRpcJson(Map<String, dynamic> json) {
    return YorksAccountsNextAction(
      code: _requiredString(json, 'code'),
      entityId: _optionalString(json['entity_id']),
      ownerRole: _optionalString(json['owner_role']),
      blockingReasonCode: _optionalString(json['blocking_reason_code']),
      isAvailable: json['is_available'] is bool
          ? json['is_available'] as bool
          : true,
    );
  }
}

final class YorksAccountsProgressEntry {
  YorksAccountsProgressEntry({
    required this.progressEntryId,
    required this.projectId,
    required this.baselineRevisionId,
    required this.buildingScopeId,
    required this.buildingName,
    required this.stageKey,
    required this.stageLabel,
    required this.stagePosition,
    required this.recordVersion,
    required this.suggestedPercent,
    required this.confirmedPercent,
    required this.reviewStatus,
    required this.evidenceSummary,
    required List<String> evidenceDocumentIds,
    required this.actionOwner,
    required this.stageValue,
    required this.confirmedEligible,
    required this.previouslyClaimedAmount,
    required this.availableToClaim,
    required List<YorksAccountsProgressRevisionSummary> revisions,
    required List<YorksAccountsNextAction> nextActions,
    required this.updatedAt,
  }) : evidenceDocumentIds = List.unmodifiable(evidenceDocumentIds),
       revisions = List.unmodifiable(revisions),
       nextActions = List.unmodifiable(nextActions);

  final String progressEntryId;
  final String projectId;
  final String baselineRevisionId;
  final String buildingScopeId;
  final String? buildingName;
  final String stageKey;
  final String? stageLabel;
  final int stagePosition;
  final int recordVersion;
  final YorksAccountsDecimal suggestedPercent;
  final YorksAccountsDecimal confirmedPercent;
  final YorksAccountsReviewStatus reviewStatus;
  final String? evidenceSummary;
  final List<String> evidenceDocumentIds;
  final String actionOwner;
  final YorksAccountsDecimal? stageValue;
  final YorksAccountsDecimal? confirmedEligible;
  final YorksAccountsDecimal? previouslyClaimedAmount;
  final YorksAccountsDecimal? availableToClaim;
  final List<YorksAccountsProgressRevisionSummary> revisions;
  final List<YorksAccountsNextAction> nextActions;
  final DateTime? updatedAt;

  factory YorksAccountsProgressEntry.fromRpcJson(
    Map<String, dynamic> json, {
    required bool canViewValues,
  }) {
    final reviewStatus = YorksAccountsReviewStatus.tryParse(
      json['review_status'],
    );
    if (reviewStatus == null) {
      throw FormatException('Invalid review_status.', json['review_status']);
    }
    return YorksAccountsProgressEntry(
      progressEntryId: _requiredStringAny(json, const [
        'progress_entry_id',
        'id',
      ]),
      projectId: _requiredString(json, 'project_id'),
      baselineRevisionId: _requiredString(json, 'baseline_revision_id'),
      buildingScopeId: _requiredString(json, 'building_scope_id'),
      buildingName: _optionalString(json['building_name']),
      stageKey: _requiredString(json, 'stage_key'),
      stageLabel: _optionalString(json['stage_label']),
      stagePosition: _requiredIntAny(json, const ['stage_position']),
      recordVersion: _requiredIntAny(json, const ['record_version', 'version']),
      suggestedPercent: _requiredDecimal(json, 'suggested_percent'),
      confirmedPercent: _requiredDecimal(json, 'confirmed_percent'),
      reviewStatus: reviewStatus,
      evidenceSummary: _optionalString(json['evidence_summary']),
      evidenceDocumentIds: _stringList(json['evidence_document_ids']),
      actionOwner: _requiredString(json, 'action_owner'),
      stageValue: _protectedDecimal(json, 'stage_value', canViewValues),
      confirmedEligible: _protectedDecimal(
        json,
        'confirmed_eligible',
        canViewValues,
      ),
      previouslyClaimedAmount: _protectedDecimal(
        json,
        'previously_claimed_amount',
        canViewValues,
      ),
      availableToClaim: _protectedDecimal(
        json,
        'available_to_claim',
        canViewValues,
      ),
      revisions: _mapList(json['revisions'])
          .map(YorksAccountsProgressRevisionSummary.fromRpcJson)
          .toList(growable: false),
      nextActions: _mapList(
        json['next_actions'],
      ).map(YorksAccountsNextAction.fromRpcJson).toList(growable: false),
      updatedAt: _optionalDateTime(json['updated_at']),
    );
  }

  YorksAccountsProgressEntry withoutProtectedValues() =>
      YorksAccountsProgressEntry(
        progressEntryId: progressEntryId,
        projectId: projectId,
        baselineRevisionId: baselineRevisionId,
        buildingScopeId: buildingScopeId,
        buildingName: buildingName,
        stageKey: stageKey,
        stageLabel: stageLabel,
        stagePosition: stagePosition,
        recordVersion: recordVersion,
        suggestedPercent: suggestedPercent,
        confirmedPercent: confirmedPercent,
        reviewStatus: reviewStatus,
        evidenceSummary: evidenceSummary,
        evidenceDocumentIds: evidenceDocumentIds,
        actionOwner: actionOwner,
        stageValue: null,
        confirmedEligible: null,
        previouslyClaimedAmount: null,
        availableToClaim: null,
        revisions: revisions,
        nextActions: const [],
        updatedAt: updatedAt,
      );
}

final class YorksAccountsProgressTotals {
  const YorksAccountsProgressTotals({
    required this.confirmedPercent,
    required this.contractValue,
    required this.confirmedEligible,
    required this.availableToClaim,
  });

  final YorksAccountsDecimal confirmedPercent;
  final YorksAccountsDecimal? contractValue;
  final YorksAccountsDecimal? confirmedEligible;
  final YorksAccountsDecimal? availableToClaim;

  factory YorksAccountsProgressTotals.fromRpcJson(
    Map<String, dynamic> json, {
    required bool canViewValues,
  }) {
    return YorksAccountsProgressTotals(
      confirmedPercent: _requiredDecimal(json, 'confirmed_percent'),
      contractValue: _protectedDecimal(json, 'contract_value', canViewValues),
      confirmedEligible: _protectedDecimal(
        json,
        'confirmed_eligible',
        canViewValues,
      ),
      availableToClaim: _protectedDecimal(
        json,
        'available_to_claim',
        canViewValues,
      ),
    );
  }

  YorksAccountsProgressTotals withoutProtectedValues() =>
      YorksAccountsProgressTotals(
        confirmedPercent: confirmedPercent,
        contractValue: null,
        confirmedEligible: null,
        availableToClaim: null,
      );
}

final class YorksAccountsProgressProjection {
  YorksAccountsProgressProjection({
    required this.schemaVersion,
    required this.projectId,
    required this.baselineRevisionId,
    required this.baselineRevisionNumber,
    required List<YorksAccountsProgressEntry> progress,
    required this.totals,
    required this.capabilities,
    required this.commands,
    required List<YorksAccountsNextAction> nextActions,
  }) : progress = List.unmodifiable(progress),
       nextActions = List.unmodifiable(nextActions);

  final String projectId;
  final int schemaVersion;
  final String? baselineRevisionId;
  final int? baselineRevisionNumber;
  final List<YorksAccountsProgressEntry> progress;
  final YorksAccountsProgressTotals? totals;
  final YorksAccountsCapabilities capabilities;
  final YorksAccountsCommandAvailability commands;
  final List<YorksAccountsNextAction> nextActions;

  factory YorksAccountsProgressProjection.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final schemaVersion = _schemaVersion(json);
    final capabilities = YorksAccountsCapabilities.fromRpcJson(
      _requiredMap(json, 'capabilities'),
    );
    if (!capabilities.canViewValues) {
      _rejectProtectedKeys(json);
    }
    final totalsJson = json['totals'];
    return YorksAccountsProgressProjection(
      schemaVersion: schemaVersion,
      projectId: _requiredString(json, 'project_id'),
      baselineRevisionId: _optionalString(json['baseline_revision_id']),
      baselineRevisionNumber: _optionalInt(json['baseline_revision_number']),
      progress: _mapList(json['progress'])
          .map(
            (item) => YorksAccountsProgressEntry.fromRpcJson(
              item,
              canViewValues: capabilities.canViewValues,
            ),
          )
          .toList(growable: false),
      totals: totalsJson == null
          ? null
          : YorksAccountsProgressTotals.fromRpcJson(
              _asMap(totalsJson, 'totals'),
              canViewValues: capabilities.canViewValues,
            ),
      capabilities: capabilities,
      commands: YorksAccountsCommandAvailability.fromRpcJson(
        _optionalMap(json['commands']),
      ),
      nextActions: _mapList(
        json['next_actions'],
      ).map(YorksAccountsNextAction.fromRpcJson).toList(growable: false),
    );
  }

  YorksAccountsProgressProjection withoutProtectedValues() =>
      YorksAccountsProgressProjection(
        schemaVersion: schemaVersion,
        projectId: projectId,
        baselineRevisionId: baselineRevisionId,
        baselineRevisionNumber: baselineRevisionNumber,
        progress: progress
            .map((item) => item.withoutProtectedValues())
            .toList(growable: false),
        totals: totals?.withoutProtectedValues(),
        capabilities: YorksAccountsCapabilities(
          canView: capabilities.canView,
          canViewValues: false,
          canConfigure: false,
          canSuggest: false,
          canConfirm: false,
          canReview: false,
        ),
        commands: YorksAccountsCommandAvailability.fromRpcJson(const {}),
        nextActions: const [],
      );
}

final class YorksAccountsCommandResult {
  const YorksAccountsCommandResult({
    required this.replayed,
    required this.projectId,
    required this.entityId,
    required this.recordVersion,
    required this.baselineRevisionNumber,
    required this.status,
    required this.updatedAt,
  });

  final bool replayed;
  final String projectId;
  final String entityId;
  final int recordVersion;
  final int? baselineRevisionNumber;
  final String? status;
  final DateTime? updatedAt;

  factory YorksAccountsCommandResult.fromRpcJson(Map<String, dynamic> json) {
    return YorksAccountsCommandResult(
      replayed: _bool(json, 'replayed'),
      projectId: _requiredString(json, 'project_id'),
      entityId: _requiredString(json, 'entity_id'),
      recordVersion: _requiredIntAny(json, const ['record_version', 'version']),
      baselineRevisionNumber: _optionalInt(json['baseline_revision_number']),
      status: _optionalString(json['status']),
      updatedAt: _optionalDateTime(json['updated_at']),
    );
  }
}

const _protectedKeys = <String>{
  'contract_value',
  'currency_code',
  'vat_rate',
  'payment_terms_days',
  'reminder_lead_days',
  'management_review_policy',
  'allocated_value',
  'stage_value',
  'confirmed_eligible',
  'previously_claimed_amount',
  'available_to_claim',
  'cumulative_confirmed_eligible',
  'commercial_progress_value',
  'claimable_value',
};

const _reviewRoles = <String>{
  'project_engineer',
  'senior_mechanical_engineer',
  'project_manager',
  'workshop_in_charge',
  'document_controller',
};

bool _isReviewRole(String role) => _reviewRoles.contains(role.trim());

int _schemaVersion(Map<String, dynamic> json) {
  final version = _requiredIntAny(json, const ['schema_version']);
  if (version != 2) {
    throw FormatException('Unsupported Accounts schema version.', version);
  }
  return version;
}

void _rejectProtectedKeys(Object? value) {
  if (value is Map) {
    for (final entry in value.entries) {
      if (_protectedKeys.contains(entry.key.toString())) {
        throw FormatException(
          'Protected commercial field appeared in a redacted projection.',
          entry.key,
        );
      }
      _rejectProtectedKeys(entry.value);
    }
  } else if (value is Iterable) {
    for (final item in value) {
      _rejectProtectedKeys(item);
    }
  }
}

bool _bool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('$key must be a boolean.', value);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _optionalString(json[key]);
  if (value != null) return value;
  throw FormatException('$key must be a non-empty string.', json[key]);
}

String _requiredStringAny(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _optionalString(json[key]);
    if (value != null) return value;
  }
  throw FormatException('${keys.join('/')} must be a non-empty string.');
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String) throw FormatException('Expected a string.', value);
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _requiredIntAny(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _optionalInt(json[key]);
    if (value != null) return value;
  }
  throw FormatException('${keys.join('/')} must be an integer.');
}

int? _optionalInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  throw FormatException('Expected an integer.', value);
}

YorksAccountsDecimal _requiredDecimal(Map<String, dynamic> json, String key) =>
    YorksAccountsDecimal.fromRpcValue(json[key], key: key);

YorksAccountsDecimal? _optionalDecimal(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key) || json[key] == null) return null;
  return YorksAccountsDecimal.fromRpcValue(json[key], key: key);
}

YorksAccountsDecimal? _protectedDecimal(
  Map<String, dynamic> json,
  String key,
  bool canViewValues,
) {
  if (!canViewValues) {
    if (json.containsKey(key)) {
      throw FormatException('$key must be omitted for this response shape.');
    }
    return null;
  }
  return _optionalDecimal(json, key);
}

String? _protectedString(
  Map<String, dynamic> json,
  String key,
  bool canViewValues,
) {
  if (!canViewValues) {
    if (json.containsKey(key)) {
      throw FormatException('$key must be omitted for this response shape.');
    }
    return null;
  }
  return _optionalString(json[key]);
}

int? _protectedInt(Map<String, dynamic> json, String key, bool canViewValues) {
  if (!canViewValues) {
    if (json.containsKey(key)) {
      throw FormatException('$key must be omitted for this response shape.');
    }
    return null;
  }
  return _optionalInt(json[key]);
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) =>
    _asMap(json[key], key);

Map<String, dynamic> _optionalMap(Object? value) =>
    value == null ? <String, dynamic>{} : _asMap(value, 'value');

Map<String, dynamic> _asMap(Object? value, String key) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('$key must be an object.', value);
}

YorksAccountsManagementReviewPolicy? _protectedReviewPolicy(
  Map<String, dynamic> json,
  bool canViewValues,
) {
  const key = 'management_review_policy';
  if (!canViewValues) {
    if (json.containsKey(key)) {
      throw FormatException('$key must be omitted for this response shape.');
    }
    return null;
  }
  final value = json[key];
  if (value == null) return null;
  return YorksAccountsManagementReviewPolicy.fromRpcJson(_asMap(value, key));
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value == null) return const [];
  if (value is! List) throw FormatException('Expected a list.', value);
  return value.map((item) => _asMap(item, 'list item')).toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value == null) return const [];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('Expected a string list.', value);
  }
  return value
      .cast<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

DateTime? _optionalDateTime(Object? value) {
  final raw = _optionalString(value);
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) throw FormatException('Invalid timestamp.', value);
  return parsed.toUtc();
}
