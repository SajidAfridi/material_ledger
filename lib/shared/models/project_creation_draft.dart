import 'project.dart';

/// Recoverable, per-user input for the V7 three-stage project creation flow.
class ProjectCreationDraft {
  const ProjectCreationDraft({
    required this.ownerUserId,
    required this.currentStep,
    required this.yorksReference,
    required this.name,
    required this.secondaryName,
    required this.clientName,
    required this.contractOrJobNumber,
    required this.siteLocation,
    required this.startDate,
    required this.expectedEndDate,
    required this.siteNotes,
    required this.consultant,
    required this.mainContractor,
    required this.projectManagerUserId,
    required this.designEngineerUserIds,
    required this.subContractorNames,
    required this.otherContractorNames,
    required this.buildings,
    required this.attachments,
    required this.updatedAt,
  });

  factory ProjectCreationDraft.empty({
    required String ownerUserId,
    required String initialBuildingId,
  }) {
    return ProjectCreationDraft(
      ownerUserId: ownerUserId,
      currentStep: 0,
      yorksReference: '',
      name: '',
      secondaryName: '',
      clientName: '',
      contractOrJobNumber: '',
      siteLocation: '',
      startDate: null,
      expectedEndDate: null,
      siteNotes: '',
      consultant: '',
      mainContractor: '',
      projectManagerUserId: null,
      designEngineerUserIds: const [],
      subContractorNames: const [],
      otherContractorNames: const [],
      buildings: [ProjectBuilding(id: initialBuildingId, code: '', name: '')],
      attachments: const [],
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  static const Object _keep = Object();

  final String ownerUserId;
  final int currentStep;
  final String yorksReference;
  final String name;
  final String secondaryName;
  final String clientName;
  final String contractOrJobNumber;
  final String siteLocation;
  final DateTime? startDate;
  final DateTime? expectedEndDate;
  final String siteNotes;
  final String consultant;
  final String mainContractor;
  final String? projectManagerUserId;
  final List<String> designEngineerUserIds;
  final List<String> subContractorNames;
  final List<String> otherContractorNames;
  final List<ProjectBuilding> buildings;
  final List<ProjectAttachment> attachments;
  final DateTime updatedAt;

  bool get hasMeaningfulContent {
    return [
          yorksReference,
          name,
          secondaryName,
          clientName,
          contractOrJobNumber,
          siteLocation,
          siteNotes,
          consultant,
          mainContractor,
          ...subContractorNames,
          ...otherContractorNames,
        ].any((value) => value.trim().isNotEmpty) ||
        startDate != null ||
        expectedEndDate != null ||
        projectManagerUserId != null ||
        buildings.any(
          (building) =>
              building.code.trim().isNotEmpty ||
              building.name.trim().isNotEmpty ||
              building.floorsOrLevels.isNotEmpty ||
              building.hasFrpRoom ||
              (building.notes?.trim().isNotEmpty ?? false),
        ) ||
        attachments.isNotEmpty;
  }

  ProjectCreationDraft copyWith({
    int? currentStep,
    String? yorksReference,
    String? name,
    String? secondaryName,
    String? clientName,
    String? contractOrJobNumber,
    String? siteLocation,
    Object? startDate = _keep,
    Object? expectedEndDate = _keep,
    String? siteNotes,
    String? consultant,
    String? mainContractor,
    Object? projectManagerUserId = _keep,
    List<String>? designEngineerUserIds,
    List<String>? subContractorNames,
    List<String>? otherContractorNames,
    List<ProjectBuilding>? buildings,
    List<ProjectAttachment>? attachments,
    DateTime? updatedAt,
  }) {
    return ProjectCreationDraft(
      ownerUserId: ownerUserId,
      currentStep: currentStep ?? this.currentStep,
      yorksReference: yorksReference ?? this.yorksReference,
      name: name ?? this.name,
      secondaryName: secondaryName ?? this.secondaryName,
      clientName: clientName ?? this.clientName,
      contractOrJobNumber: contractOrJobNumber ?? this.contractOrJobNumber,
      siteLocation: siteLocation ?? this.siteLocation,
      startDate: identical(startDate, _keep)
          ? this.startDate
          : startDate as DateTime?,
      expectedEndDate: identical(expectedEndDate, _keep)
          ? this.expectedEndDate
          : expectedEndDate as DateTime?,
      siteNotes: siteNotes ?? this.siteNotes,
      consultant: consultant ?? this.consultant,
      mainContractor: mainContractor ?? this.mainContractor,
      projectManagerUserId: identical(projectManagerUserId, _keep)
          ? this.projectManagerUserId
          : projectManagerUserId as String?,
      designEngineerUserIds:
          designEngineerUserIds ?? this.designEngineerUserIds,
      subContractorNames: subContractorNames ?? this.subContractorNames,
      otherContractorNames: otherContractorNames ?? this.otherContractorNames,
      buildings: buildings ?? this.buildings,
      attachments: attachments ?? this.attachments,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Project toProject({
    required String projectId,
    required DateTime createdAt,
    required String actorUserId,
    required String actorRole,
    required String commonBuildingId,
  }) {
    final physicalBuildings = [
      for (final building in buildings)
        building.copyWith(
          code: building.code.trim(),
          name: building.name.trim(),
          scope: ProjectBuildingScope.physical,
          notes: _trimToNull(building.notes),
        ),
    ];
    final firstBuilding = physicalBuildings.first;
    final officeCreated = actorRole == 'procurement' || actorRole == 'admin';

    return Project(
      id: projectId,
      yorksReference: yorksReference.trim(),
      name: name.trim(),
      secondaryName: _trimToNull(secondaryName),
      contractOrJobNumber: _trimToNull(contractOrJobNumber),
      clientName: clientName.trim(),
      siteLocation: siteLocation.trim(),
      buildingName: firstBuilding.name,
      floorNumbers: firstBuilding.floorsOrLevels.join(', '),
      startDate: startDate,
      expectedEndDate: expectedEndDate,
      siteNotes: _trimToNull(siteNotes),
      phase: const ProjectPhase(
        number: 1,
        name: 'Material Planning',
        nameSecondary: 'تخطيط المواد',
        state: ProjectState.planning,
      ),
      acceptedByProcurement: officeCreated,
      acceptedAt: officeCreated ? createdAt : null,
      acceptedBy: officeCreated ? actorUserId : null,
      mainContractor: _trimToNull(mainContractor),
      authorityRef: null,
      consultant: _trimToNull(consultant),
      assignedEngineerId: designEngineerUserIds.first,
      subContractors: _parties(projectId, 'subcontractor', subContractorNames),
      otherContractors: _parties(
        projectId,
        'other-contractor',
        otherContractorNames,
      ),
      projectManagerUserId: projectManagerUserId,
      designEngineerUserIds: List.unmodifiable(designEngineerUserIds),
      buildings: [
        ProjectBuilding(
          id: commonBuildingId,
          code: 'COMMON',
          name: 'Project-wide / Common',
          scope: ProjectBuildingScope.common,
        ),
        ...physicalBuildings,
      ],
      attachments: [
        for (final attachment in attachments)
          ProjectAttachment(
            id: attachment.id,
            fileName: attachment.fileName.trim(),
            documentType: attachment.documentType.trim(),
            reference: _trimToNull(attachment.reference),
            buildingId: attachment.buildingId,
            addedAt: attachment.addedAt,
            addedByUserId: attachment.addedByUserId,
            addedByRole: attachment.addedByRole,
          ),
      ],
      lifecycleStatus: ProjectLifecycleStatus.draft,
      createdAt: createdAt,
      createdByUserId: actorUserId,
      createdByRole: actorRole,
      updatedAt: createdAt,
      updatedByUserId: actorUserId,
      updatedByRole: actorRole,
    );
  }

  Map<String, dynamic> toJson() => {
    'ownerUserId': ownerUserId,
    'currentStep': currentStep,
    'yorksReference': yorksReference,
    'name': name,
    'secondaryName': secondaryName,
    'clientName': clientName,
    'contractOrJobNumber': contractOrJobNumber,
    'siteLocation': siteLocation,
    'startDate': startDate?.toIso8601String(),
    'expectedEndDate': expectedEndDate?.toIso8601String(),
    'siteNotes': siteNotes,
    'consultant': consultant,
    'mainContractor': mainContractor,
    'projectManagerUserId': projectManagerUserId,
    'designEngineerUserIds': designEngineerUserIds,
    'subContractorNames': subContractorNames,
    'otherContractorNames': otherContractorNames,
    'buildings': buildings.map((building) => building.toJson()).toList(),
    'attachments': attachments
        .map((attachment) => attachment.toJson())
        .toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ProjectCreationDraft.fromJson(Map<String, dynamic> json) {
    return ProjectCreationDraft(
      ownerUserId: json['ownerUserId'] as String? ?? '',
      currentStep: ((json['currentStep'] as num?)?.toInt() ?? 0).clamp(0, 2),
      yorksReference: json['yorksReference'] as String? ?? '',
      name: json['name'] as String? ?? '',
      secondaryName: json['secondaryName'] as String? ?? '',
      clientName: json['clientName'] as String? ?? '',
      contractOrJobNumber: json['contractOrJobNumber'] as String? ?? '',
      siteLocation: json['siteLocation'] as String? ?? '',
      startDate: _date(json['startDate']),
      expectedEndDate: _date(json['expectedEndDate']),
      siteNotes: json['siteNotes'] as String? ?? '',
      consultant: json['consultant'] as String? ?? '',
      mainContractor: json['mainContractor'] as String? ?? '',
      projectManagerUserId: json['projectManagerUserId'] as String?,
      designEngineerUserIds: _strings(json['designEngineerUserIds']),
      subContractorNames: _strings(json['subContractorNames']),
      otherContractorNames: _strings(json['otherContractorNames']),
      buildings: _buildings(json['buildings']),
      attachments: _attachments(json['attachments']),
      updatedAt:
          _date(json['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

List<ProjectParty> _parties(
  String projectId,
  String roleKey,
  List<String> names,
) {
  final cleaned = names
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
  return [
    for (var index = 0; index < cleaned.length; index++)
      ProjectParty(
        id: '$projectId-$roleKey-${index + 1}',
        name: cleaned[index],
      ),
  ];
}

String? _trimToNull(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

List<String> _strings(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Object>()
      .map((item) => item.toString())
      .toList(growable: false);
}

List<ProjectBuilding> _buildings(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => ProjectBuilding.fromJson(Map<String, dynamic>.from(item)))
      .where((building) => !building.isProjectWide)
      .toList(growable: false);
}

List<ProjectAttachment> _attachments(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map(
        (item) => ProjectAttachment.fromJson(Map<String, dynamic>.from(item)),
      )
      .toList(growable: false);
}
