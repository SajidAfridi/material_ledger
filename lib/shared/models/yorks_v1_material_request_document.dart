import 'yorks_v1_material_request.dart';
import 'yorks_v1_quantity.dart';

/// Server-aggregated, role-safe source for every rendering of a controlled
/// Material Request.  The app never reconstructs approval, dispatch or
/// receipt facts from local state, so preview, download, print and stored PDF
/// use the same immutable view of the request.
class YorksV1MaterialRequestDocumentModel {
  const YorksV1MaterialRequestDocumentModel({
    required this.request,
    this.projectEngineerNames = const [],
    this.arrangement,
    this.approval,
    this.dispatch,
    this.receiptStatuses = const {},
    this.lineLifecycles = const {},
    this.showLineStatus = false,
  });

  final YorksV1MaterialRequest request;
  final List<String> projectEngineerNames;
  final YorksV1MaterialRequestDocumentActor? arrangement;
  final YorksV1MaterialRequestDocumentActor? approval;
  final YorksV1MaterialRequestDocumentActor? dispatch;
  final Map<String, String> receiptStatuses;
  final Map<String, YorksV1MaterialRequestLineLifecycle> lineLifecycles;
  final bool showLineStatus;

  factory YorksV1MaterialRequestDocumentModel.fromRequest(
    YorksV1MaterialRequest request,
  ) => YorksV1MaterialRequestDocumentModel(request: request);

  factory YorksV1MaterialRequestDocumentModel.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final engineerNames = (json['project_engineers'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => _text(value['display_name']))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final lifecycleEntries = <String, YorksV1MaterialRequestLineLifecycle>{};
    final hasCanonicalLifecycle = json['line_lifecycle'] is List;
    final rawLifecycles = json['line_lifecycle'] as List? ?? const [];
    for (final value in rawLifecycles) {
      if (value is! Map) continue;
      final lifecycle = YorksV1MaterialRequestLineLifecycle.fromRpcJson(
        Map<String, dynamic>.from(value),
      );
      if (lifecycle.requestLineId.isNotEmpty) {
        lifecycleEntries[lifecycle.requestLineId] = lifecycle;
      }
    }
    final statusEntries = hasCanonicalLifecycle
        ? {
            for (final entry in lifecycleEntries.entries)
              entry.key: entry.value.compactSummary,
          }
        : _legacyReceiptStatuses(json['receipt_statuses']);
    return YorksV1MaterialRequestDocumentModel(
      request: YorksV1MaterialRequest.fromRpcJson(
        Map<String, dynamic>.from(json['request'] as Map),
      ),
      projectEngineerNames: engineerNames,
      arrangement: YorksV1MaterialRequestDocumentActor.fromNullableJson(
        json['arrangement'],
      ),
      approval: YorksV1MaterialRequestDocumentActor.fromNullableJson(
        json['approval'],
      ),
      dispatch: YorksV1MaterialRequestDocumentActor.fromNullableJson(
        json['dispatch'],
      ),
      receiptStatuses: Map.unmodifiable(statusEntries),
      lineLifecycles: Map.unmodifiable(lifecycleEntries),
      showLineStatus: json['show_line_status'] == true,
    );
  }
}

Map<String, String> _legacyReceiptStatuses(Object? raw) {
  final statuses = <String, String>{};
  for (final value in raw is List ? raw : const []) {
    if (value is! Map) continue;
    final id = _text(value['request_line_id']);
    if (id.isEmpty) continue;
    final requested = yorksV1DisplayQuantity(_quantity(value['requested_qty']));
    final fulfilled = yorksV1DisplayQuantity(_quantity(value['fulfilled_qty']));
    final status = _text(value['status']);
    statuses[id] =
        '$fulfilled / $requested${status.isEmpty ? '' : ' · $status'}';
  }
  return statuses;
}

class YorksV1MaterialRequestLineLifecycle {
  const YorksV1MaterialRequestLineLifecycle({
    required this.requestLineId,
    required this.requestedQuantity,
    required this.arrangedQuantity,
    required this.cannotProvideQuantity,
    required this.approvedQuantity,
    required this.dispatchedQuantity,
    required this.inTransitQuantity,
    required this.goodQuantity,
    required this.missingQuantity,
    required this.damagedQuantity,
    required this.remainingApprovedQuantity,
    required this.replacementEligibleQuantity,
    required this.ordinaryOutstandingQuantity,
    required this.status,
    this.arrangementDecision,
    this.arrangementStatus,
    this.sourceKind,
    this.arrangementReason,
  });

  final String requestLineId;
  final String requestedQuantity;
  final String arrangedQuantity;
  final String cannotProvideQuantity;
  final String approvedQuantity;
  final String dispatchedQuantity;
  final String inTransitQuantity;
  final String goodQuantity;
  final String missingQuantity;
  final String damagedQuantity;
  final String remainingApprovedQuantity;
  final String replacementEligibleQuantity;
  final String ordinaryOutstandingQuantity;
  final String status;
  final String? arrangementDecision;
  final String? arrangementStatus;
  final String? sourceKind;
  final String? arrangementReason;

  factory YorksV1MaterialRequestLineLifecycle.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksV1MaterialRequestLineLifecycle(
    requestLineId: _text(json['request_line_id']),
    requestedQuantity: _quantity(json['requested_qty']),
    arrangedQuantity: _quantity(json['arranged_qty']),
    cannotProvideQuantity: _quantity(json['cannot_provide_qty']),
    approvedQuantity: _quantity(json['approved_qty']),
    dispatchedQuantity: _quantity(json['dispatched_qty']),
    inTransitQuantity: _quantity(json['in_transit_qty']),
    goodQuantity: _quantity(json['reviewed_good_qty'] ?? json['good_qty']),
    missingQuantity: _quantity(
      json['reviewed_missing_qty'] ?? json['missing_qty'],
    ),
    damagedQuantity: _quantity(
      json['reviewed_damaged_qty'] ?? json['damaged_qty'],
    ),
    remainingApprovedQuantity: _quantity(json['remaining_approved_qty']),
    replacementEligibleQuantity: _quantity(json['replacement_eligible_qty']),
    ordinaryOutstandingQuantity: _quantity(json['ordinary_outstanding_qty']),
    status: _text(json['status']),
    arrangementDecision: _nullableText(json['arrangement_decision']),
    arrangementStatus: _nullableText(json['arrangement_status']),
    sourceKind: _nullableText(json['source_kind']),
    arrangementReason: _nullableText(json['arrangement_reason']),
  );

  String get compactSummary {
    final facts = <String>[
      if (arrangementStatus != null)
        '${yorksV1DisplayQuantity(arrangedQuantity)} / '
            '${yorksV1DisplayQuantity(requestedQuantity)} arranged',
      if (_isPositive(cannotProvideQuantity))
        '${yorksV1DisplayQuantity(cannotProvideQuantity)} cannot provide',
      if (_isPositive(approvedQuantity))
        '${yorksV1DisplayQuantity(approvedQuantity)} approved',
      '${yorksV1DisplayQuantity(dispatchedQuantity)} / '
          '${yorksV1DisplayQuantity(approvedQuantity)} dispatched',
      if (_isPositive(goodQuantity))
        '${yorksV1DisplayQuantity(goodQuantity)} good',
      if (_isPositive(missingQuantity))
        '${yorksV1DisplayQuantity(missingQuantity)} missing',
      if (_isPositive(damagedQuantity))
        '${yorksV1DisplayQuantity(damagedQuantity)} damaged',
      if (_isPositive(inTransitQuantity))
        '${yorksV1DisplayQuantity(inTransitQuantity)} in transit',
      if (_isPositive(remainingApprovedQuantity))
        '${yorksV1DisplayQuantity(remainingApprovedQuantity)} remaining',
      if (_isPositive(replacementEligibleQuantity))
        '${yorksV1DisplayQuantity(replacementEligibleQuantity)} replacement',
      ?sourceKind?.replaceAll('_', ' '),
      ?arrangementReason,
    ];
    if (status.isNotEmpty) facts.add(status);
    return facts.join(' · ');
  }
}

class YorksV1MaterialRequestDocumentActor {
  const YorksV1MaterialRequestDocumentActor({
    required this.displayName,
    required this.role,
    required this.reference,
    required this.actedAt,
  });

  final String displayName;
  final String role;
  final String reference;
  final DateTime? actedAt;

  static YorksV1MaterialRequestDocumentActor? fromNullableJson(Object? value) {
    if (value is! Map) return null;
    final displayName = _text(value['display_name']);
    if (displayName.isEmpty) return null;
    return YorksV1MaterialRequestDocumentActor(
      displayName: displayName,
      role: _text(value['role']),
      reference: _text(value['reference']),
      actedAt: DateTime.tryParse(_text(value['acted_at']))?.toUtc(),
    );
  }
}

String _text(Object? value) => value?.toString().trim() ?? '';

String? _nullableText(Object? value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}

String _quantity(Object? value) {
  final text = _text(value);
  return text.isEmpty ? '0' : text;
}

bool _isPositive(String value) =>
    YorksV1DecimalQuantity.tryParse(value)?.isPositive == true;
