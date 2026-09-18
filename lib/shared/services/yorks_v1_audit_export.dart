import 'dart:convert';

import '../models/yorks_v1_audit_workspace.dart';

/// CSV is consumed by spreadsheets: quoting alone does not disable formulas.
String yorksV1AuditCsvCell(String value) {
  final dangerous =
      RegExp(r'^[\s\u0000-\u001f]*[=+@-]').hasMatch(value) ||
      value.startsWith('\t') ||
      value.startsWith('\r') ||
      value.startsWith('\n');
  final safe = dangerous ? "'$value" : value;
  return '"${safe.replaceAll('"', '""')}"';
}

String yorksV1AuditCsv(
  YorksV1AuditWorkspace workspace,
  YorksV1AuditFilter filter,
) {
  final rows = <List<String>>[
    [
      'Yorks audit export',
      'UTC timestamps',
      'Generated',
      workspace.generatedAt.toUtc().toIso8601String(),
    ],
    [
      'As of',
      (workspace.asOf ?? workspace.generatedAt).toUtc().toIso8601String(),
      'Rows',
      '${workspace.events.length}',
    ],
    ['Filters', jsonEncode(filter.toRpcParameters())],
    [
      'Event ID',
      'Timestamp (UTC)',
      'Actor',
      'Role',
      'Action',
      'Module',
      'Entity',
      'Entity ID',
      'Reference',
      'Project',
      'Reason',
    ],
    for (final e in workspace.events)
      [
        e.id,
        e.occurredAt.toUtc().toIso8601String(),
        e.actorDisplayName,
        e.actorExactRole,
        e.eventType,
        e.module.wireValue,
        e.entityType,
        e.entityId,
        e.reference,
        e.projectRef ?? '',
        e.reason ?? '',
      ],
  ];
  return '\uFEFF${rows.map((row) => row.map(yorksV1AuditCsvCell).join(',')).join('\r\n')}\r\n';
}
