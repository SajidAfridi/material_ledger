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
  final ProjectPhase? phase;
  final DateTime? lastUpdated;
  final bool awaitingApproval;
  final int openRequestCount;
  final bool allDispatched;

  /// True when a project has any work item needing engineer attention.
  bool get needsAction => awaitingApproval || openRequestCount > 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nameSecondary': nameSecondary,
    'siteLocation': siteLocation,
    'clientName': clientName,
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
  });

  final String materialId;
  final String materialName;
  final String materialNameSecondary;
  final double quantity;
  final String unitSymbol;

  /// Short spec description, e.g. "OPC-43 Grade", "12mm / Grade 60"
  final String spec;

  RequestLineItem copyWith({double? quantity}) => RequestLineItem(
    materialId: materialId,
    materialName: materialName,
    materialNameSecondary: materialNameSecondary,
    quantity: quantity ?? this.quantity,
    unitSymbol: unitSymbol,
    spec: spec,
  );

  Map<String, dynamic> toJson() => {
    'materialId': materialId,
    'materialName': materialName,
    'materialNameSecondary': materialNameSecondary,
    'quantity': quantity,
    'unitSymbol': unitSymbol,
    'spec': spec,
  };

  factory RequestLineItem.fromJson(Map<String, dynamic> json) =>
      RequestLineItem(
        materialId: json['materialId'] as String,
        materialName: json['materialName'] as String,
        materialNameSecondary: json['materialNameSecondary'] as String? ?? '',
        quantity: (json['quantity'] as num).toDouble(),
        unitSymbol: json['unitSymbol'] as String,
        spec: json['spec'] as String? ?? '',
      );
}
