import 'accounts_decimal.dart';
import 'accounts_models.dart';

final class YorksAccountsBuildingAllocationInput {
  const YorksAccountsBuildingAllocationInput({
    required this.buildingScopeId,
    required this.allocationPercent,
    required this.isCommonScope,
  });

  final String buildingScopeId;
  final YorksAccountsDecimal allocationPercent;
  final bool isCommonScope;

  Map<String, Object?> toRpcJson() => {
    'building_scope_id': buildingScopeId.trim(),
    'allocation_percent': allocationPercent.postgresText,
  };
}

final class YorksAccountsStageAllocationInput {
  const YorksAccountsStageAllocationInput({
    required this.stageKey,
    required this.stageLabel,
    required this.position,
    required this.allocationPercent,
  });

  final String stageKey;
  final String stageLabel;
  final int position;
  final YorksAccountsDecimal allocationPercent;

  Map<String, Object?> toRpcJson() => {
    'stage_key': stageKey.trim(),
    'stage_label': stageLabel.trim(),
    'position': position,
    'allocation_percent': allocationPercent.postgresText,
  };
}

final class YorksAccountsBaselineInput {
  YorksAccountsBaselineInput({
    required this.projectId,
    required this.contractValue,
    required this.currencyCode,
    required this.vatRate,
    required this.paymentTermsDays,
    required this.reminderLeadDays,
    required List<YorksAccountsBuildingAllocationInput> buildingAllocations,
    required List<YorksAccountsStageAllocationInput> stageAllocations,
    required this.managementReviewPolicy,
    required this.reason,
    this.expectedBaselineVersion,
  }) : buildingAllocations = List.unmodifiable(buildingAllocations),
       stageAllocations = List.unmodifiable(stageAllocations);

  final String projectId;
  final YorksAccountsDecimal contractValue;
  final String currencyCode;
  final YorksAccountsDecimal vatRate;
  final int paymentTermsDays;
  final int reminderLeadDays;
  final List<YorksAccountsBuildingAllocationInput> buildingAllocations;
  final List<YorksAccountsStageAllocationInput> stageAllocations;
  final YorksAccountsManagementReviewPolicy managementReviewPolicy;
  final String reason;
  final int? expectedBaselineVersion;

  bool get isRevision => expectedBaselineVersion != null;

  bool get isValid {
    if (projectId.trim().isEmpty ||
        !contractValue.isPositive ||
        contractValue.fractionDigits > 2) {
      return false;
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currencyCode.trim().toUpperCase())) {
      return false;
    }
    if (vatRate.isNegative ||
        vatRate.fractionDigits > 4 ||
        vatRate.compareTo(YorksAccountsDecimal.hundred) > 0) {
      return false;
    }
    if (paymentTermsDays < 1 || reminderLeadDays < 0) return false;
    if (reminderLeadDays > paymentTermsDays || reason.trim().isEmpty) {
      return false;
    }
    if (isRevision && expectedBaselineVersion! < 1) return false;
    if (buildingAllocations.isEmpty ||
        stageAllocations.isEmpty ||
        !managementReviewPolicy.isValid) {
      return false;
    }
    if (buildingAllocations.any(
      (item) =>
          item.buildingScopeId.trim().isEmpty ||
          item.isCommonScope ||
          !item.allocationPercent.isPositive ||
          item.allocationPercent.fractionDigits > 4,
    )) {
      return false;
    }
    final buildingIds = buildingAllocations
        .map((item) => item.buildingScopeId.trim())
        .toSet();
    if (buildingIds.length != buildingAllocations.length) return false;
    if (_sum(buildingAllocations.map((item) => item.allocationPercent)) !=
        YorksAccountsDecimal.hundred) {
      return false;
    }
    if (stageAllocations.any(
      (item) =>
          !_stageKeyPattern.hasMatch(item.stageKey.trim()) ||
          item.stageLabel.trim().isEmpty ||
          item.position < 1 ||
          !item.allocationPercent.isPositive ||
          item.allocationPercent.fractionDigits > 4,
    )) {
      return false;
    }
    final stageKeys = stageAllocations
        .map((item) => item.stageKey.trim())
        .toSet();
    if (stageKeys.length != stageAllocations.length) return false;
    final stagePositions = stageAllocations
        .map((item) => item.position)
        .toSet();
    if (stagePositions.length != stageAllocations.length) return false;
    return _sum(stageAllocations.map((item) => item.allocationPercent)) ==
        YorksAccountsDecimal.hundred;
  }

  Map<String, Object?> idempotencyPayload() => {
    'project_id': projectId.trim(),
    if (expectedBaselineVersion != null)
      'expected_baseline_version': expectedBaselineVersion,
    'contract_value': contractValue.postgresText,
    'currency_code': currencyCode.trim().toUpperCase(),
    'vat_rate': vatRate.postgresText,
    'payment_terms_days': paymentTermsDays,
    'reminder_lead_days': reminderLeadDays,
    'building_allocations': buildingAllocations
        .map((item) => item.toRpcJson())
        .toList(growable: false),
    'stage_allocations': stageAllocations
        .map((item) => item.toRpcJson())
        .toList(growable: false),
    'management_review_policy': managementReviewPolicy.toRpcJson(),
    'reason': reason.trim(),
  };
}

final class YorksAccountsProgressInput {
  YorksAccountsProgressInput({
    required this.projectId,
    required this.progressEntryId,
    required this.expectedVersion,
    required this.percent,
    required this.evidenceSummary,
    required List<String> evidenceDocumentIds,
    required this.reason,
  }) : evidenceDocumentIds = List.unmodifiable(evidenceDocumentIds);

  final String projectId;
  final String progressEntryId;
  final int expectedVersion;
  final YorksAccountsDecimal percent;
  final String evidenceSummary;
  final List<String> evidenceDocumentIds;
  final String reason;

  bool get _isCoreValid {
    if (projectId.trim().isEmpty || progressEntryId.trim().isEmpty) {
      return false;
    }
    if (expectedVersion < 1 ||
        percent.isNegative ||
        percent.fractionDigits > 4) {
      return false;
    }
    if (percent.compareTo(YorksAccountsDecimal.hundred) > 0) return false;
    return reason.trim().isNotEmpty &&
        evidenceDocumentIds.every((id) => id.trim().isNotEmpty);
  }

  /// A site suggestion must carry either an operational evidence summary or
  /// at least one document reference before it is sent to the server.
  bool get isValidSuggestion =>
      _isCoreValid &&
      (evidenceSummary.trim().isNotEmpty || evidenceDocumentIds.isNotEmpty);

  /// Confirmation evidence depends on the authoritative current percentage.
  ///
  /// The client cannot safely decide whether this command is an increase, so
  /// it validates only the common command shape. The RPC remains responsible
  /// for requiring an authorized document when the confirmed value increases.
  bool get isValidConfirmation => _isCoreValid;

  /// Retained for callers that still treat a progress input as a suggestion.
  bool get isValid => isValidSuggestion;

  Map<String, Object?> idempotencyPayload() => {
    'project_id': projectId.trim(),
    'progress_entry_id': progressEntryId.trim(),
    'expected_version': expectedVersion,
    'percent': percent.postgresText,
    'evidence_summary': evidenceSummary.trim(),
    'evidence_document_ids': evidenceDocumentIds
        .map((id) => id.trim())
        .toList(growable: false),
    'reason': reason.trim(),
  };
}

enum YorksAccountsReviewDecision {
  approved('approved'),
  returned('returned');

  const YorksAccountsReviewDecision(this.wireValue);
  final String wireValue;
}

final class YorksAccountsReviewInput {
  const YorksAccountsReviewInput({
    required this.projectId,
    required this.progressEntryId,
    required this.expectedVersion,
    required this.decision,
    required this.reason,
  });

  final String projectId;
  final String progressEntryId;
  final int expectedVersion;
  final YorksAccountsReviewDecision decision;
  final String reason;

  bool get isValid =>
      projectId.trim().isNotEmpty &&
      progressEntryId.trim().isNotEmpty &&
      expectedVersion > 0 &&
      reason.trim().isNotEmpty;

  Map<String, Object?> idempotencyPayload() => {
    'project_id': projectId.trim(),
    'progress_entry_id': progressEntryId.trim(),
    'expected_version': expectedVersion,
    'decision': decision.wireValue,
    'reason': reason.trim(),
  };
}

YorksAccountsDecimal _sum(Iterable<YorksAccountsDecimal> values) =>
    values.fold(YorksAccountsDecimal.zero, (total, value) => total + value);

final RegExp _stageKeyPattern = RegExp(r'^[a-z][a-z0-9_]*$');
