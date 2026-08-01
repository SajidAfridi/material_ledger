/// A physical building or clearly identified common scope within a project.
///
/// Floors/levels are optional because some projects are managed at building
/// level only. FRP-room applicability is deliberately a boolean.
enum ProjectBuildingScope {
  physical,
  common;

  static ProjectBuildingScope fromJson(Object? value) {
    if (value is String) {
      return ProjectBuildingScope.values.firstWhere(
        (scope) => scope.name == value.toLowerCase(),
        orElse: () => ProjectBuildingScope.physical,
      );
    }
    return ProjectBuildingScope.physical;
  }
}

class ProjectBuilding {
  const ProjectBuilding({
    required this.id,
    required this.code,
    required this.name,
    this.scope = ProjectBuildingScope.physical,
    this.floorsOrLevels = const [],
    this.hasFrpRoom = false,
    this.notes,
    this.active = true,
    this.archivedAt,
    this.archivedByUserId,
  });

  final String id;
  final String code;
  final String name;
  final ProjectBuildingScope scope;
  final List<String> floorsOrLevels;
  final bool hasFrpRoom;
  final String? notes;
  final bool active;
  final DateTime? archivedAt;
  final String? archivedByUserId;

  bool get isProjectWide => scope == ProjectBuildingScope.common;

  ProjectBuilding copyWith({
    String? id,
    String? code,
    String? name,
    ProjectBuildingScope? scope,
    List<String>? floorsOrLevels,
    bool? hasFrpRoom,
    String? notes,
    bool? active,
    DateTime? archivedAt,
    String? archivedByUserId,
  }) {
    return ProjectBuilding(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      scope: scope ?? this.scope,
      floorsOrLevels: floorsOrLevels ?? this.floorsOrLevels,
      hasFrpRoom: hasFrpRoom ?? this.hasFrpRoom,
      notes: notes ?? this.notes,
      active: active ?? this.active,
      archivedAt: archivedAt ?? this.archivedAt,
      archivedByUserId: archivedByUserId ?? this.archivedByUserId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'scope': scope.name,
    'floorsOrLevels': floorsOrLevels,
    'hasFrpRoom': hasFrpRoom,
    'notes': notes,
    'active': active,
    'archivedAt': archivedAt?.toIso8601String(),
    'archivedByUserId': archivedByUserId,
  };

  factory ProjectBuilding.fromJson(Map<String, dynamic> json) {
    final rawFloors =
        json['floorsOrLevels'] ?? json['floors'] ?? json['floorNumbers'];

    return ProjectBuilding(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      scope: ProjectBuildingScope.fromJson(json['scope']),
      floorsOrLevels: _decodeFloors(rawFloors),
      hasFrpRoom:
          json['hasFrpRoom'] as bool? ?? json['hasFRP'] as bool? ?? false,
      notes: json['notes'] as String?,
      active: json['active'] as bool? ?? true,
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String),
      archivedByUserId: json['archivedByUserId'] as String?,
    );
  }

  static List<String> floorsFromLegacy(String? value) => _decodeFloors(value);

  static List<String> _decodeFloors(Object? value) {
    if (value is List) {
      return value
          .whereType<Object>()
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String) {
      return value
          .split(RegExp(r'[,;\n]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }
}
