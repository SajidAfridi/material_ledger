/// A project-specific reporting stage.
///
/// Progress stages are deliberately separate from workflow readiness and
/// approvals. They communicate physical/technical progress without unlocking
/// a project or changing any procurement transaction.
class ProjectProgressStage {
  const ProjectProgressStage({
    required this.id,
    required this.label,
    required this.weightPercent,
    this.progressPercent = 0,
    this.updatedAt,
    this.updatedByUserId,
  });

  final String id;
  final String label;
  final double weightPercent;
  final double progressPercent;
  final DateTime? updatedAt;
  final String? updatedByUserId;

  ProjectProgressStage copyWith({
    String? label,
    double? weightPercent,
    double? progressPercent,
    DateTime? updatedAt,
    String? updatedByUserId,
  }) => ProjectProgressStage(
    id: id,
    label: label ?? this.label,
    weightPercent: weightPercent ?? this.weightPercent,
    progressPercent: progressPercent ?? this.progressPercent,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedByUserId: updatedByUserId ?? this.updatedByUserId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'weightPercent': weightPercent,
    'progressPercent': progressPercent,
    'updatedAt': updatedAt?.toIso8601String(),
    'updatedByUserId': updatedByUserId,
  };

  factory ProjectProgressStage.fromJson(Map<String, dynamic> json) =>
      ProjectProgressStage(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        weightPercent: (json['weightPercent'] as num?)?.toDouble() ?? 0,
        progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0,
        updatedAt: switch (json['updatedAt']) {
          final String value when value.isNotEmpty => DateTime.tryParse(value),
          _ => null,
        },
        updatedByUserId: json['updatedByUserId'] as String?,
      );
}

const standardProjectProgressStages = <ProjectProgressStage>[
  ProjectProgressStage(
    id: 'cooling-load-design',
    label: 'Cooling Load Design',
    weightPercent: 10,
  ),
  ProjectProgressStage(
    id: 'material-supply',
    label: 'Material Supply',
    weightPercent: 50,
  ),
  ProjectProgressStage(
    id: 'progress-installation',
    label: 'Progress Installation',
    weightPercent: 30,
  ),
  ProjectProgressStage(
    id: 'commissioning-handover',
    label: 'Commissioning & Handover',
    weightPercent: 5,
  ),
  ProjectProgressStage(
    id: 'energizing-substation',
    label: 'Energizing Substation',
    weightPercent: 5,
  ),
];

extension ProjectProgressStageList on List<ProjectProgressStage> {
  double get totalWeight =>
      fold(0, (total, stage) => total + stage.weightPercent);

  double get weightedProgress {
    final weight = totalWeight;
    if (weight <= 0) return 0;
    final value = fold<double>(
      0,
      (total, stage) => total + (stage.progressPercent * stage.weightPercent),
    );
    return value / weight;
  }
}
