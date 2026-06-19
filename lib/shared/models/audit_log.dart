// Append-only audit trail. Every create / edit / payment / leave / attendance /
// stock action is logged with actor, role, and timestamp. Client code may only
// append — entries are never edited or deleted (mirrored server-side by the
// Firestore Security Rules: activityLog denies all client writes & deletes).
// See SRS v1.3 §3 / Appendix F.

import 'user_role.dart';

/// The module an audited action belongs to (for filtering the trail).
enum AuditModule {
  materials('Materials'),
  rentals('Rentals'),
  people('People'),
  platform('Platform');

  const AuditModule(this.label);
  final String label;

  static AuditModule fromName(String name) => AuditModule.values.firstWhere(
    (m) => m.name == name,
    orElse: () => AuditModule.platform,
  );
}

/// A single, immutable audit-trail entry.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.actorName,
    required this.actorRole,
    required this.module,
    required this.timestamp,
    this.refId,
    this.detail,
  });

  /// Stable id (uuid in real data; deterministic for seeds).
  final String id;

  /// Short verb-phrase, e.g. "Plan approved", "Rent payment recorded".
  final String action;

  final String actorName;
  final UserRole actorRole;
  final AuditModule module;
  final DateTime timestamp;

  /// Id of the affected record (project, unit, employee, request…).
  final String? refId;

  /// Free-text human detail, e.g. "AED 4,500 for SHOP-02 / 2026-06".
  final String? detail;

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action,
    'actorName': actorName,
    'actorRole': actorRole.name,
    'module': module.name,
    'timestamp': timestamp.toIso8601String(),
    if (refId != null) 'refId': refId,
    if (detail != null) 'detail': detail,
  };

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
    id: json['id'] as String,
    action: json['action'] as String,
    actorName: json['actorName'] as String,
    actorRole: UserRole.fromName(json['actorRole'] as String),
    module: AuditModule.fromName(json['module'] as String),
    timestamp: DateTime.parse(json['timestamp'] as String),
    refId: json['refId'] as String?,
    detail: json['detail'] as String?,
  );
}
