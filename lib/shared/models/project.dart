import 'dart:convert';

import 'project_building.dart';
import 'project_attachment.dart';
import 'project_party.dart';
import 'project_progress_stage.dart';

export 'project_building.dart';
export 'project_attachment.dart';
export 'project_party.dart';
export 'project_progress_stage.dart';

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

/// The stable V7 lifecycle. Legacy [ProjectState] remains available for the
/// current UI until its screens are migrated in a later batch.
enum ProjectLifecycleStatus {
  draft,
  planning,
  active,
  archived;

  static ProjectLifecycleStatus fromJson(Object? value) {
    if (value is String) {
      return ProjectLifecycleStatus.values.firstWhere(
        (status) => status.name == value.toLowerCase(),
        orElse: () => ProjectLifecycleStatus.planning,
      );
    }
    return ProjectLifecycleStatus.planning;
  }
}

/// Provenance retained when a legacy flat project is upgraded in memory.
class ProjectMigrationMetadata {
  const ProjectMigrationMetadata({
    required this.sourceDataVersion,
    this.legacyAuthorityRef,
    this.legacyBuildingName,
    this.legacyFloorNumbers,
  });

  final int sourceDataVersion;
  final String? legacyAuthorityRef;
  final String? legacyBuildingName;
  final String? legacyFloorNumbers;

  Map<String, dynamic> toJson() => {
    'sourceDataVersion': sourceDataVersion,
    'legacyAuthorityRef': legacyAuthorityRef,
    'legacyBuildingName': legacyBuildingName,
    'legacyFloorNumbers': legacyFloorNumbers,
  };

  factory ProjectMigrationMetadata.fromJson(Map<String, dynamic> json) =>
      ProjectMigrationMetadata(
        sourceDataVersion: (json['sourceDataVersion'] as num?)?.toInt() ?? 1,
        legacyAuthorityRef: json['legacyAuthorityRef'] as String?,
        legacyBuildingName: json['legacyBuildingName'] as String?,
        legacyFloorNumbers: json['legacyFloorNumbers'] as String?,
      );
}

/// A backward-compatible V7 project aggregate.
class Project {
  const Project({
    required this.id,
    required this.name,
    String? nameSecondary,
    String? secondaryName,
    this.yorksReference,
    this.siteLocation,
    this.clientName,
    this.buildingName,
    this.floorNumbers,
    this.startDate,
    this.expectedEndDate,
    this.siteNotes,
    this.phase,
    DateTime? lastUpdated,
    DateTime? updatedAt,
    this.awaitingApproval = false,
    this.openRequestCount = 0,
    this.allDispatched = false,
    this.acceptedByProcurement = false,
    this.acceptedAt,
    this.acceptedBy,
    this.deleted = false,
    String? jobNumber,
    String? contractOrJobNumber,
    this.mainContractor,
    this.authorityRef,
    this.consultant,
    this.contractValueAED,
    this.assignedEngineerId,
    this.subContractors = const [],
    this.otherContractors = const [],
    this.projectManagerUserId,
    this.designEngineerUserIds = const [],
    this.buildings = const [],
    this.attachments = const [],
    this.progressStages = const [],
    this.lifecycleStatus = ProjectLifecycleStatus.planning,
    this.createdAt,
    this.createdByUserId,
    this.createdByRole,
    this.updatedByUserId,
    this.updatedByRole,
    this.migrationMetadata,
    this.dataVersion = currentDataVersion,
  }) : secondaryName = secondaryName ?? nameSecondary,
       contractOrJobNumber = contractOrJobNumber ?? jobNumber,
       updatedAt = updatedAt ?? lastUpdated;

  static const int currentDataVersion = 4;
  static const Object _keep = Object();

  final int dataVersion;
  final String id;
  final String? yorksReference;
  final String name;
  final String? secondaryName;
  final String? siteLocation;
  final String? clientName;

  /// Legacy flat location fields. Kept until all current screens migrate.
  final String? buildingName;
  final String? floorNumbers;

  final DateTime? startDate;
  final DateTime? expectedEndDate;
  final String? siteNotes;
  final ProjectPhase? phase;
  final DateTime? updatedAt;
  final bool awaitingApproval;
  final int openRequestCount;
  final bool allDispatched;
  final bool acceptedByProcurement;
  final DateTime? acceptedAt;
  final String? acceptedBy;
  final bool deleted;
  final String? contractOrJobNumber;
  final String? mainContractor;
  final String? authorityRef;
  final String? consultant;
  final double? contractValueAED;

  /// Legacy single-engineer assignment. Multi-engineer access uses
  /// [designEngineerUserIds], while this remains readable by current screens.
  final String? assignedEngineerId;

  final List<ProjectParty> subContractors;
  final List<ProjectParty> otherContractors;
  final String? projectManagerUserId;
  final List<String> designEngineerUserIds;
  final List<ProjectBuilding> buildings;
  final List<ProjectAttachment> attachments;
  final List<ProjectProgressStage> progressStages;
  final ProjectLifecycleStatus lifecycleStatus;
  final DateTime? createdAt;
  final String? createdByUserId;
  final String? createdByRole;
  final String? updatedByUserId;
  final String? updatedByRole;
  final ProjectMigrationMetadata? migrationMetadata;

  /// Legacy aliases used by existing screens.
  String get nameSecondary => secondaryName ?? '';
  String? get jobNumber => contractOrJobNumber;
  DateTime? get lastUpdated => updatedAt;

  /// Projects created before configurable progress use the approved Yorks
  /// defaults until an Admin saves a project-specific stage set.
  List<ProjectProgressStage> get effectiveProgressStages =>
      progressStages.isEmpty ? standardProjectProgressStages : progressStages;

  double get weightedProgressPercent =>
      effectiveProgressStages.weightedProgress;

  bool get needsAction => awaitingApproval || openRequestCount > 0;

  Project copyWith({
    String? name,
    String? nameSecondary,
    String? secondaryName,
    String? yorksReference,
    String? siteLocation,
    String? clientName,
    String? buildingName,
    String? floorNumbers,
    DateTime? startDate,
    DateTime? expectedEndDate,
    String? siteNotes,
    ProjectPhase? phase,
    DateTime? lastUpdated,
    DateTime? updatedAt,
    bool? awaitingApproval,
    int? openRequestCount,
    bool? allDispatched,
    bool? acceptedByProcurement,
    DateTime? acceptedAt,
    String? acceptedBy,
    bool? deleted,
    String? jobNumber,
    String? contractOrJobNumber,
    String? mainContractor,
    String? authorityRef,
    String? consultant,
    Object? contractValueAED = _keep,
    String? assignedEngineerId,
    List<ProjectParty>? subContractors,
    List<ProjectParty>? otherContractors,
    String? projectManagerUserId,
    List<String>? designEngineerUserIds,
    List<ProjectBuilding>? buildings,
    List<ProjectAttachment>? attachments,
    List<ProjectProgressStage>? progressStages,
    ProjectLifecycleStatus? lifecycleStatus,
    DateTime? createdAt,
    String? createdByUserId,
    String? createdByRole,
    String? updatedByUserId,
    String? updatedByRole,
    ProjectMigrationMetadata? migrationMetadata,
  }) => Project(
    id: id,
    name: name ?? this.name,
    secondaryName: secondaryName ?? nameSecondary ?? this.secondaryName,
    yorksReference: yorksReference ?? this.yorksReference,
    siteLocation: siteLocation ?? this.siteLocation,
    clientName: clientName ?? this.clientName,
    buildingName: buildingName ?? this.buildingName,
    floorNumbers: floorNumbers ?? this.floorNumbers,
    startDate: startDate ?? this.startDate,
    expectedEndDate: expectedEndDate ?? this.expectedEndDate,
    siteNotes: siteNotes ?? this.siteNotes,
    phase: phase ?? this.phase,
    updatedAt: updatedAt ?? lastUpdated ?? this.updatedAt,
    awaitingApproval: awaitingApproval ?? this.awaitingApproval,
    openRequestCount: openRequestCount ?? this.openRequestCount,
    allDispatched: allDispatched ?? this.allDispatched,
    acceptedByProcurement: acceptedByProcurement ?? this.acceptedByProcurement,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    acceptedBy: acceptedBy ?? this.acceptedBy,
    deleted: deleted ?? this.deleted,
    contractOrJobNumber:
        contractOrJobNumber ?? jobNumber ?? this.contractOrJobNumber,
    mainContractor: mainContractor ?? this.mainContractor,
    authorityRef: authorityRef ?? this.authorityRef,
    consultant: consultant ?? this.consultant,
    contractValueAED: identical(contractValueAED, _keep)
        ? this.contractValueAED
        : contractValueAED as double?,
    assignedEngineerId: assignedEngineerId ?? this.assignedEngineerId,
    subContractors: subContractors ?? this.subContractors,
    otherContractors: otherContractors ?? this.otherContractors,
    projectManagerUserId: projectManagerUserId ?? this.projectManagerUserId,
    designEngineerUserIds: designEngineerUserIds ?? this.designEngineerUserIds,
    buildings: buildings ?? this.buildings,
    attachments: attachments ?? this.attachments,
    progressStages: progressStages ?? this.progressStages,
    lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
    createdAt: createdAt ?? this.createdAt,
    createdByUserId: createdByUserId ?? this.createdByUserId,
    createdByRole: createdByRole ?? this.createdByRole,
    updatedByUserId: updatedByUserId ?? this.updatedByUserId,
    updatedByRole: updatedByRole ?? this.updatedByRole,
    migrationMetadata: migrationMetadata ?? this.migrationMetadata,
  );

  Map<String, dynamic> toJson() => {
    'dataVersion': currentDataVersion,
    'id': id,
    'yorksReference': yorksReference,
    'name': name,
    'secondaryName': secondaryName,
    'nameSecondary': nameSecondary,
    'siteLocation': siteLocation,
    'clientName': clientName,
    'buildingName': buildingName,
    'floorNumbers': floorNumbers,
    'startDate': startDate?.toIso8601String(),
    'expectedEndDate': expectedEndDate?.toIso8601String(),
    'siteNotes': siteNotes,
    'phase': phase?.toJson(),
    'updatedAt': updatedAt?.toIso8601String(),
    'lastUpdated': lastUpdated?.toIso8601String(),
    'awaitingApproval': awaitingApproval,
    'openRequestCount': openRequestCount,
    'allDispatched': allDispatched,
    'acceptedByProcurement': acceptedByProcurement,
    'acceptedAt': acceptedAt?.toIso8601String(),
    'acceptedBy': acceptedBy,
    'deleted': deleted,
    'contractOrJobNumber': contractOrJobNumber,
    'jobNumber': jobNumber,
    'mainContractor': mainContractor,
    'authorityRef': authorityRef,
    'consultant': consultant,
    'contractValueAED': contractValueAED,
    'assignedEngineerId': assignedEngineerId,
    'subContractors': subContractors.map((party) => party.toJson()).toList(),
    'otherContractors': otherContractors
        .map((party) => party.toJson())
        .toList(),
    'projectManagerUserId': projectManagerUserId,
    'designEngineerUserIds': designEngineerUserIds,
    'buildings': buildings.map((building) => building.toJson()).toList(),
    'attachments': attachments
        .map((attachment) => attachment.toJson())
        .toList(),
    'progressStages': progressStages.map((stage) => stage.toJson()).toList(),
    'lifecycleStatus': lifecycleStatus.name,
    'createdAt': createdAt?.toIso8601String(),
    'createdByUserId': createdByUserId,
    'createdByRole': createdByRole,
    'updatedByUserId': updatedByUserId,
    'updatedByRole': updatedByRole,
    'migrationMetadata': migrationMetadata?.toJson(),
  };

  Map<String, dynamic> toOperationalJson() =>
      toJson()..remove('contractValueAED');

  Project withoutCommercials() => copyWith(contractValueAED: null);

  Project withCommercialTotal(double value) =>
      copyWith(contractValueAED: value);

  factory Project.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final sourceVersion = (json['dataVersion'] as num?)?.toInt() ?? 1;
    final assignedEngineerId = json['assignedEngineerId'] as String?;
    final designEngineerIds = _decodeStringList(json['designEngineerUserIds']);
    if (assignedEngineerId != null &&
        assignedEngineerId.isNotEmpty &&
        !designEngineerIds.contains(assignedEngineerId)) {
      designEngineerIds.add(assignedEngineerId);
    }

    final buildings = json['buildings'] is List
        ? _decodeBuildings(json['buildings'])
        : _migrateLegacyBuilding(
            projectId: id,
            buildingName: json['buildingName'] as String?,
            floorNumbers: json['floorNumbers'] as String?,
          );

    final phase = json['phase'] == null
        ? null
        : ProjectPhase.fromJson(
            Map<String, dynamic>.from(json['phase'] as Map),
          );

    return Project(
      id: id,
      yorksReference: json['yorksReference'] as String?,
      name: json['name'] as String,
      secondaryName:
          json['secondaryName'] as String? ?? json['nameSecondary'] as String?,
      siteLocation: json['siteLocation'] as String?,
      clientName: json['clientName'] as String?,
      buildingName: json['buildingName'] as String?,
      floorNumbers: json['floorNumbers'] as String?,
      startDate: _decodeDate(json['startDate']),
      expectedEndDate: _decodeDate(json['expectedEndDate']),
      siteNotes: json['siteNotes'] as String?,
      phase: phase,
      updatedAt: _decodeDate(json['updatedAt'] ?? json['lastUpdated']),
      awaitingApproval: json['awaitingApproval'] as bool? ?? false,
      openRequestCount: (json['openRequestCount'] as num?)?.toInt() ?? 0,
      allDispatched: json['allDispatched'] as bool? ?? false,
      // Records written before this field existed predate acceptance and are
      // grandfathered in instead of being retroactively queued.
      acceptedByProcurement: json['acceptedByProcurement'] as bool? ?? true,
      acceptedAt: _decodeDate(json['acceptedAt']),
      acceptedBy: json['acceptedBy'] as String?,
      deleted: json['deleted'] as bool? ?? false,
      contractOrJobNumber:
          json['contractOrJobNumber'] as String? ??
          json['jobNumber'] as String?,
      mainContractor: json['mainContractor'] as String?,
      authorityRef: json['authorityRef'] as String?,
      consultant: json['consultant'] as String?,
      contractValueAED: (json['contractValueAED'] as num?)?.toDouble(),
      assignedEngineerId: assignedEngineerId,
      subContractors: _decodeParties(
        json['subContractors'],
        projectId: id,
        roleKey: 'subcontractor',
      ),
      otherContractors: _decodeParties(
        json['otherContractors'],
        projectId: id,
        roleKey: 'other-contractor',
      ),
      projectManagerUserId: json['projectManagerUserId'] as String?,
      designEngineerUserIds: designEngineerIds,
      buildings: buildings,
      attachments: _decodeAttachments(json['attachments']),
      progressStages: _decodeProgressStages(json['progressStages']),
      lifecycleStatus: json.containsKey('lifecycleStatus')
          ? ProjectLifecycleStatus.fromJson(json['lifecycleStatus'])
          : _lifecycleFromLegacy(phase?.state, json['deleted'] as bool?),
      createdAt: _decodeDate(json['createdAt']),
      createdByUserId: json['createdByUserId'] as String?,
      createdByRole: json['createdByRole'] as String?,
      updatedByUserId: json['updatedByUserId'] as String?,
      updatedByRole: json['updatedByRole'] as String?,
      migrationMetadata: json['migrationMetadata'] is Map
          ? ProjectMigrationMetadata.fromJson(
              Map<String, dynamic>.from(json['migrationMetadata'] as Map),
            )
          : sourceVersion < 2
          ? ProjectMigrationMetadata(
              sourceDataVersion: sourceVersion,
              legacyAuthorityRef: json['authorityRef'] as String?,
              legacyBuildingName: json['buildingName'] as String?,
              legacyFloorNumbers: json['floorNumbers'] as String?,
            )
          : null,
    );
  }

  static String encodeList(List<Project> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<Project> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

DateTime? _decodeDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.parse(value);
}

List<String> _decodeStringList(Object? value) {
  if (value is! List) return <String>[];
  return value
      .whereType<Object>()
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: true);
}

List<ProjectParty> _decodeParties(
  Object? value, {
  required String projectId,
  required String roleKey,
}) {
  if (value is! List) return const [];
  final parties = <ProjectParty>[];
  for (var index = 0; index < value.length; index++) {
    final party = ProjectParty.decode(
      value[index],
      fallbackId: '$projectId-$roleKey-${index + 1}',
    );
    if (party != null) parties.add(party);
  }
  return parties;
}

List<ProjectBuilding> _decodeBuildings(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map(
        (building) =>
            ProjectBuilding.fromJson(Map<String, dynamic>.from(building)),
      )
      .toList(growable: false);
}

List<ProjectAttachment> _decodeAttachments(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map(
        (attachment) =>
            ProjectAttachment.fromJson(Map<String, dynamic>.from(attachment)),
      )
      .toList(growable: false);
}

List<ProjectProgressStage> _decodeProgressStages(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map(
        (stage) =>
            ProjectProgressStage.fromJson(Map<String, dynamic>.from(stage)),
      )
      .where((stage) => stage.id.isNotEmpty && stage.label.trim().isNotEmpty)
      .toList(growable: false);
}

List<ProjectBuilding> _migrateLegacyBuilding({
  required String projectId,
  required String? buildingName,
  required String? floorNumbers,
}) {
  final name = buildingName?.trim() ?? '';
  final floors = ProjectBuilding.floorsFromLegacy(floorNumbers);
  if (name.isEmpty && floors.isEmpty) return const [];

  return [
    ProjectBuilding(
      id: '$projectId-building-legacy',
      code: '',
      name: name,
      floorsOrLevels: floors,
    ),
  ];
}

ProjectLifecycleStatus _lifecycleFromLegacy(
  ProjectState? state,
  bool? deleted,
) {
  if (deleted ?? false) return ProjectLifecycleStatus.archived;
  return switch (state) {
    ProjectState.active => ProjectLifecycleStatus.active,
    ProjectState.completed => ProjectLifecycleStatus.archived,
    ProjectState.planning ||
    ProjectState.onHold ||
    null => ProjectLifecycleStatus.planning,
  };
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
