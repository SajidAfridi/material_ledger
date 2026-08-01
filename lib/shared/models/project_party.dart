/// A named contractor attached to a project.
///
/// The minimal value object gives parties stable IDs without adding contact or
/// commercial fields that are outside the V7 MVP.
class ProjectParty {
  const ProjectParty({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  static ProjectParty? decode(Object? value, {required String fallbackId}) {
    if (value is String) {
      final name = value.trim();
      if (name.isEmpty) return null;
      return ProjectParty(id: fallbackId, name: name);
    }
    if (value is Map) {
      final json = Map<String, dynamic>.from(value);
      final name = (json['name'] as String? ?? '').trim();
      if (name.isEmpty) return null;
      final decodedId = (json['id'] as String? ?? '').trim();
      return ProjectParty(
        id: decodedId.isEmpty ? fallbackId : decodedId,
        name: name,
      );
    }
    return null;
  }
}
