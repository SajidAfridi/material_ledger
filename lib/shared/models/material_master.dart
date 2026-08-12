import 'dart:convert';

/// Stable V7 material-category record. Records are archived, never deleted, so
/// historical catalogue rows keep resolving after an Admin retires a choice.
class MaterialCategoryMaster {
  const MaterialCategoryMaster({
    required this.id,
    required this.name,
    this.secondaryName = '',
    required this.sortOrder,
    this.isCustom = false,
    this.archived = false,
    required this.updatedAt,
    required this.updatedBy,
  });

  final String id;
  final String name;
  final String secondaryName;
  final int sortOrder;
  final bool isCustom;
  final bool archived;
  final DateTime updatedAt;
  final String updatedBy;

  MaterialCategoryMaster copyWith({
    String? name,
    String? secondaryName,
    int? sortOrder,
    bool? archived,
    DateTime? updatedAt,
    String? updatedBy,
  }) => MaterialCategoryMaster(
    id: id,
    name: name ?? this.name,
    secondaryName: secondaryName ?? this.secondaryName,
    sortOrder: sortOrder ?? this.sortOrder,
    isCustom: isCustom,
    archived: archived ?? this.archived,
    updatedAt: updatedAt ?? DateTime.now(),
    updatedBy: updatedBy ?? this.updatedBy,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'secondaryName': secondaryName,
    'sortOrder': sortOrder,
    'isCustom': isCustom,
    'archived': archived,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'updatedBy': updatedBy,
  };

  factory MaterialCategoryMaster.fromJson(Map<String, dynamic> json) =>
      MaterialCategoryMaster(
        id: json['id'] as String,
        name: json['name'] as String,
        secondaryName: json['secondaryName'] as String? ?? '',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        isCustom: json['isCustom'] as bool? ?? false,
        archived: json['archived'] as bool? ?? false,
        updatedAt:
            DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedBy: json['updatedBy'] as String? ?? 'Migration',
      );
}

enum UnitReviewStatus {
  approved,
  pendingReview,
  archived;

  static UnitReviewStatus fromName(String? value) =>
      UnitReviewStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => UnitReviewStatus.pendingReview,
      );
}

/// Stable V7 unit record. Custom units can be proposed by Procurement but only
/// Admin can approve or archive them.
class MaterialUnitMaster {
  const MaterialUnitMaster({
    required this.id,
    required this.name,
    required this.symbol,
    this.secondaryName = '',
    required this.sortOrder,
    this.isCustom = false,
    required this.status,
    required this.updatedAt,
    required this.updatedBy,
  });

  final String id;
  final String name;
  final String symbol;
  final String secondaryName;
  final int sortOrder;
  final bool isCustom;
  final UnitReviewStatus status;
  final DateTime updatedAt;
  final String updatedBy;

  bool get isSelectable => status == UnitReviewStatus.approved;
  bool get archived => status == UnitReviewStatus.archived;

  MaterialUnitMaster copyWith({
    String? name,
    String? symbol,
    String? secondaryName,
    int? sortOrder,
    UnitReviewStatus? status,
    DateTime? updatedAt,
    String? updatedBy,
  }) => MaterialUnitMaster(
    id: id,
    name: name ?? this.name,
    symbol: symbol ?? this.symbol,
    secondaryName: secondaryName ?? this.secondaryName,
    sortOrder: sortOrder ?? this.sortOrder,
    isCustom: isCustom,
    status: status ?? this.status,
    updatedAt: updatedAt ?? DateTime.now(),
    updatedBy: updatedBy ?? this.updatedBy,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'symbol': symbol,
    'secondaryName': secondaryName,
    'sortOrder': sortOrder,
    'isCustom': isCustom,
    'status': status.name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'updatedBy': updatedBy,
  };

  factory MaterialUnitMaster.fromJson(Map<String, dynamic> json) =>
      MaterialUnitMaster(
        id: json['id'] as String,
        name: json['name'] as String,
        symbol: json['symbol'] as String,
        secondaryName: json['secondaryName'] as String? ?? '',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        isCustom: json['isCustom'] as bool? ?? false,
        status: UnitReviewStatus.fromName(json['status'] as String?),
        updatedAt:
            DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedBy: json['updatedBy'] as String? ?? 'Migration',
      );
}

String _slug(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (normalized.isNotEmpty) return normalized;
  return base64Url.encode(utf8.encode(value)).replaceAll('=', '').toLowerCase();
}

/// Deterministic migration from the legacy detailed enum label into the V7
/// Finder-style category rail.
String categoryMasterIdForLegacyLabel(String label) {
  const groups = <String, String>{
    'Air Inlet & Outlet': 'cat-air-terminals',
    'Supply Grilles & Registers': 'cat-air-terminals',
    'Return & Exhaust Grilles': 'cat-air-terminals',
    'Diffusers': 'cat-air-terminals',
    'Volume Control Dampers': 'cat-dampers-fire-control',
    'Fire & Smoke Dampers': 'cat-dampers-fire-control',
    'Ducts & Dampers': 'cat-ductwork-accessories',
    'Flexible Ducts': 'cat-ductwork-accessories',
    'Duct Accessories': 'cat-ductwork-accessories',
    'Sheet Metal': 'cat-ductwork-accessories',
    'Fans': 'cat-fans-equipment',
    'Duct Heaters': 'cat-fans-equipment',
    'FCU / AHU / Package Units': 'cat-fans-equipment',
    'Filters': 'cat-fans-equipment',
    'Valves': 'cat-piping-drain',
    'Pipes & Tubing': 'cat-piping-drain',
    'Fittings & Connectors': 'cat-piping-drain',
    'Copper & Brass': 'cat-piping-drain',
    'Refrigerant & Gas': 'cat-piping-drain',
    'Sealants & Adhesives': 'cat-piping-drain',
    'Gauges & Instruments': 'cat-piping-drain',
    'Electrical & Controls': 'cat-electrical-controls',
    'Insulation': 'cat-supports-insulation',
    'Hangers & Supports': 'cat-supports-insulation',
    'Fasteners': 'cat-supports-insulation',
    'Tools & Equipment': 'cat-general-custom',
    'Other': 'cat-general-custom',
  };
  return groups[label] ?? 'custom-category-${_slug(label)}';
}

/// Deterministic unit migration. Only exact approved equivalents are folded
/// together; unmatched legacy symbols remain distinct custom records.
String unitMasterIdForLegacySymbol(String symbol) {
  return switch (symbol.trim().toLowerCase()) {
    'pcs' || 'pc' || 'nos' || 'no' => 'unit-nos',
    'm' || 'meter' || 'metre' => 'unit-meter',
    'cm' => 'unit-cm',
    'length' || 'lengths' => 'unit-length',
    'set' || 'sets' => 'unit-set',
    'pair' || 'pairs' => 'unit-pairs',
    'roll' || 'rolls' => 'unit-roll',
    'box' => 'unit-box',
    'boxes' => 'unit-boxes',
    // Keep the historical plural master stable. New entries use the new
    // controlled singular Ton value; legacy records still resolve to their
    // original custom ID instead of being silently reclassified.
    'ton' => 'unit-ton',
    'tons' => 'custom-unit-tons',
    _ => 'custom-unit-${_slug(symbol)}',
  };
}

/// Legacy compatibility values used while older modules still accept enums.
/// The stable master IDs remain authoritative and prevent custom values from
/// being lost when a record passes through those older call sites.
String legacyCategoryLabelForMasterId(String id) {
  return switch (id) {
    'cat-air-terminals' => 'Air Inlet & Outlet',
    'cat-dampers-fire-control' => 'Volume Control Dampers',
    'cat-fans-equipment' => 'Fans',
    'cat-ductwork-accessories' => 'Ducts & Dampers',
    'cat-piping-drain' => 'Pipes & Tubing',
    'cat-electrical-controls' => 'Electrical & Controls',
    'cat-supports-insulation' => 'Hangers & Supports',
    _ => 'Other',
  };
}

String legacyUnitSymbolForMasterId(String id, {String fallback = 'pcs'}) {
  return switch (id) {
    'unit-nos' => 'pcs',
    'unit-meter' => 'm',
    'unit-set' => 'sets',
    'unit-roll' => 'rolls',
    'unit-box' => 'box',
    'unit-ton' => 'ton',
    'unit-boxes' => 'boxes',
    _ => fallback,
  };
}
