/// Metadata for a document attached while a project is created.
///
/// The binary object is intentionally outside the project aggregate. A later
/// storage-backed document slice can add its object path without changing the
/// project creation workflow or losing this traceability metadata.
class ProjectAttachment {
  const ProjectAttachment({
    required this.id,
    required this.fileName,
    required this.documentType,
    required this.addedAt,
    required this.addedByUserId,
    required this.addedByRole,
    this.reference,
    this.buildingId,
  });

  final String id;
  final String fileName;
  final String documentType;
  final String? reference;

  /// Null means the document applies to the whole project.
  final String? buildingId;

  final DateTime addedAt;
  final String addedByUserId;
  final String addedByRole;

  bool get isProjectWide => buildingId == null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'documentType': documentType,
    'reference': reference,
    'buildingId': buildingId,
    'addedAt': addedAt.toIso8601String(),
    'addedByUserId': addedByUserId,
    'addedByRole': addedByRole,
  };

  factory ProjectAttachment.fromJson(Map<String, dynamic> json) {
    return ProjectAttachment(
      id: json['id'] as String? ?? '',
      fileName: json['fileName'] as String? ?? json['name'] as String? ?? '',
      documentType:
          json['documentType'] as String? ?? json['type'] as String? ?? '',
      reference: json['reference'] as String?,
      buildingId: json['buildingId'] as String?,
      addedAt:
          _decodeDate(json['addedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      addedByUserId: json['addedByUserId'] as String? ?? '',
      addedByRole: json['addedByRole'] as String? ?? '',
    );
  }
}

DateTime? _decodeDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
