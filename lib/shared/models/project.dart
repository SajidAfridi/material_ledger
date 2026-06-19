import 'dart:convert';

/// Lifecycle state of a project.
enum ProjectState {
  planning('Planning', 'پلاننگ', 'تخطيط', 'योजना'),
  active('Active', 'فعال', 'نشط', 'सक्रिय'),
  onHold('On Hold', 'رکا ہوا', 'متوقف', 'रुका हुआ'),
  completed('Completed', 'مکمل', 'مكتمل', 'पूर्ण');

  const ProjectState(this.label, this.urdu, this.arabic, this.hindi);

  final String label;
  final String urdu;
  final String arabic;
  final String hindi;

  static ProjectState fromLabel(String label) => ProjectState.values.firstWhere(
    (s) => s.label == label,
    orElse: () => ProjectState.active,
  );
}

/// A specific phase within a project lifecycle (e.g. "Phase 1 — Planning").
class ProjectPhase {
  const ProjectPhase({
    required this.number,
    required this.name,
    required this.nameSecondary,
    required this.state,
  });

  final int number;
  final String name;
  final String nameSecondary;
  final ProjectState state;

  /// Display "Phase N — Name"
  String get label => 'Phase $number — $name';

  Map<String, dynamic> toJson() => {
    'number': number,
    'name': name,
    'nameSecondary': nameSecondary,
    'state': state.label,
  };

  factory ProjectPhase.fromJson(Map<String, dynamic> json) => ProjectPhase(
    number: json['number'] as int,
    name: json['name'] as String,
    nameSecondary: json['nameSecondary'] as String? ?? '',
    state: ProjectState.fromLabel(json['state'] as String),
  );
}

/// An admin-created project that engineers can select and track.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.nameSecondary,
    this.siteLocation,
    this.clientName,
    this.buildingName,
    this.floorNumbers,
    this.startDate,
    this.expectedEndDate,
    this.siteNotes,
    this.phase,
    this.lastUpdated,
    this.awaitingApproval = false,
    this.openRequestCount = 0,
    this.allDispatched = false,
  });

  final String id;
  final String name;
  final String nameSecondary;
  final String? siteLocation;
  final String? clientName;
  final String? buildingName;
  final String? floorNumbers;
  final DateTime? startDate;
  final DateTime? expectedEndDate;
  final String? siteNotes;
  final ProjectPhase? phase;
  final DateTime? lastUpdated;
  final bool awaitingApproval;
  final int openRequestCount;
  final bool allDispatched;

  /// True when a project has any work item needing engineer attention.
  bool get needsAction => awaitingApproval || openRequestCount > 0;

  Project copyWith({
    String? name,
    String? nameSecondary,
    String? siteLocation,
    String? clientName,
    String? buildingName,
    String? floorNumbers,
    DateTime? startDate,
    DateTime? expectedEndDate,
    String? siteNotes,
    ProjectPhase? phase,
    DateTime? lastUpdated,
    bool? awaitingApproval,
    int? openRequestCount,
    bool? allDispatched,
  }) => Project(
    id: id,
    name: name ?? this.name,
    nameSecondary: nameSecondary ?? this.nameSecondary,
    siteLocation: siteLocation ?? this.siteLocation,
    clientName: clientName ?? this.clientName,
    buildingName: buildingName ?? this.buildingName,
    floorNumbers: floorNumbers ?? this.floorNumbers,
    startDate: startDate ?? this.startDate,
    expectedEndDate: expectedEndDate ?? this.expectedEndDate,
    siteNotes: siteNotes ?? this.siteNotes,
    phase: phase ?? this.phase,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    awaitingApproval: awaitingApproval ?? this.awaitingApproval,
    openRequestCount: openRequestCount ?? this.openRequestCount,
    allDispatched: allDispatched ?? this.allDispatched,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nameSecondary': nameSecondary,
    'siteLocation': siteLocation,
    'clientName': clientName,
    'buildingName': buildingName,
    'floorNumbers': floorNumbers,
    'startDate': startDate?.toIso8601String(),
    'expectedEndDate': expectedEndDate?.toIso8601String(),
    'siteNotes': siteNotes,
    'phase': phase?.toJson(),
    'lastUpdated': lastUpdated?.toIso8601String(),
    'awaitingApproval': awaitingApproval,
    'openRequestCount': openRequestCount,
    'allDispatched': allDispatched,
  };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'] as String,
    name: json['name'] as String,
    nameSecondary: json['nameSecondary'] as String? ?? '',
    siteLocation: json['siteLocation'] as String?,
    clientName: json['clientName'] as String?,
    buildingName: json['buildingName'] as String?,
    floorNumbers: json['floorNumbers'] as String?,
    startDate: json['startDate'] == null
        ? null
        : DateTime.parse(json['startDate'] as String),
    expectedEndDate: json['expectedEndDate'] == null
        ? null
        : DateTime.parse(json['expectedEndDate'] as String),
    siteNotes: json['siteNotes'] as String?,
    phase: json['phase'] == null
        ? null
        : ProjectPhase.fromJson(json['phase'] as Map<String, dynamic>),
    lastUpdated: json['lastUpdated'] == null
        ? null
        : DateTime.parse(json['lastUpdated'] as String),
    awaitingApproval: json['awaitingApproval'] as bool? ?? false,
    openRequestCount: json['openRequestCount'] as int? ?? 0,
    allDispatched: json['allDispatched'] as bool? ?? false,
  );

  static String encodeList(List<Project> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<Project> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// An item within a material requisition request.
/// Represents a specific material + requested quantity.
class RequestLineItem {
  const RequestLineItem({
    required this.materialId,
    required this.materialName,
    required this.materialNameSecondary,
    required this.quantity,
    required this.unitSymbol,
    this.spec = '',
    this.qtyReceived,
    this.qtyDispatched,
  });

  final String materialId;
  final String materialName;
  final String materialNameSecondary;
  final double quantity;
  final String unitSymbol;

  /// Short spec description, e.g. "OPC-43 Grade", "12mm / Grade 60"
  final String spec;

  /// Quantity the engineer confirmed actually arrived on site (FR-088).
  /// Null until receipt is confirmed.
  final double? qtyReceived;

  /// Quantity procurement has dispatched to site so far (FR — partial dispatch).
  /// Null/0 until first dispatch; equals [quantity] when fully dispatched.
  final double? qtyDispatched;

  /// True when a confirmed receipt is short of the requested quantity (FR-089).
  bool get hasShortfall => qtyReceived != null && qtyReceived! < quantity;

  /// Quantity still to be dispatched (partial fulfilment remainder).
  double get qtyOutstanding =>
      (quantity - (qtyDispatched ?? 0)).clamp(0, double.infinity).toDouble();

  RequestLineItem copyWith({
    String? materialId,
    String? materialName,
    double? quantity,
    double? qtyReceived,
    double? qtyDispatched,
  }) => RequestLineItem(
    materialId: materialId ?? this.materialId,
    materialName: materialName ?? this.materialName,
    materialNameSecondary: materialNameSecondary,
    quantity: quantity ?? this.quantity,
    unitSymbol: unitSymbol,
    spec: spec,
    qtyReceived: qtyReceived ?? this.qtyReceived,
    qtyDispatched: qtyDispatched ?? this.qtyDispatched,
  );

  Map<String, dynamic> toJson() => {
    'materialId': materialId,
    'materialName': materialName,
    'materialNameSecondary': materialNameSecondary,
    'quantity': quantity,
    'unitSymbol': unitSymbol,
    'spec': spec,
    'qtyReceived': qtyReceived,
    'qtyDispatched': qtyDispatched,
  };

  factory RequestLineItem.fromJson(Map<String, dynamic> json) =>
      RequestLineItem(
        materialId: json['materialId'] as String,
        materialName: json['materialName'] as String,
        materialNameSecondary: json['materialNameSecondary'] as String? ?? '',
        quantity: (json['quantity'] as num).toDouble(),
        unitSymbol: json['unitSymbol'] as String,
        spec: json['spec'] as String? ?? '',
        qtyReceived: (json['qtyReceived'] as num?)?.toDouble(),
        qtyDispatched: (json['qtyDispatched'] as num?)?.toDouble(),
      );
}
