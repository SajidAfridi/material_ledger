import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/yorks_v1_boq.dart';

/// Device-local recovery for an uncommitted BOQ worksheet.
///
/// The server remains authoritative. Recovery is scoped to the authenticated
/// user and group, and commercial columns are deliberately excluded so a later
/// capability revocation cannot expose protected values from local storage.
class YorksV1BoqRecoveryStore {
  YorksV1BoqRecoveryStore({
    required SharedPreferences preferences,
    required String ownerAuthUserId,
  }) : _preferences = preferences,
       _ownerAuthUserId = ownerAuthUserId.trim();

  static const _prefix = 'yorks_v1_boq_recovery_v1';

  final SharedPreferences _preferences;
  final String _ownerAuthUserId;

  String _key(String groupId) => '$_prefix:$_ownerAuthUserId:${groupId.trim()}';

  Future<void> save(YorksV1BoqWorksheet worksheet) async {
    if (_ownerAuthUserId.isEmpty) return;
    final operationalColumns = worksheet.columns
        .where((column) => !column.isCommercial)
        .toList(growable: false);
    final operationalColumnIds = operationalColumns
        .map((column) => column.id)
        .toSet();
    await _preferences.setString(
      _key(worksheet.group.id),
      jsonEncode({
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'worksheet': {
          'group': _groupJson(worksheet.group),
          'columns': [
            for (final column in operationalColumns)
              {...column.toSaveJson(), 'record_version': column.version},
          ],
          'rows': [
            for (final row in worksheet.rows)
              {
                'id': row.id,
                'display_order': row.displayOrder,
                'raw_values': {
                  for (final entry in row.values.entries)
                    if (operationalColumnIds.contains(entry.key))
                      entry.key: entry.value,
                },
                'canonical_values': {
                  for (final entry in row.canonicalValues.entries)
                    if (YorksV1BoqCanonicalField.fromWireValue(
                          entry.key,
                        )?.isCommercial !=
                        true)
                      entry.key: entry.value,
                },
                'record_version': row.version,
              },
          ],
        },
      }),
    );
  }

  Future<YorksV1BoqWorksheet?> load(String groupId) async {
    if (_ownerAuthUserId.isEmpty) return null;
    final raw = _preferences.getString(_key(groupId));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('invalid recovery');
      final worksheet = decoded['worksheet'];
      if (worksheet is! Map) throw const FormatException('invalid worksheet');
      final result = YorksV1BoqWorksheet.fromRpcJson(
        Map<String, dynamic>.from(worksheet),
      );
      if (result.group.id != groupId) {
        throw const FormatException('wrong worksheet');
      }
      return result;
    } catch (_) {
      await clear(groupId);
      return null;
    }
  }

  Future<void> clear(String groupId) async {
    if (_ownerAuthUserId.isEmpty) return;
    await _preferences.remove(_key(groupId));
  }

  static Map<String, Object?> _groupJson(YorksV1BoqGroup group) => {
    'id': group.id,
    'project_id': group.projectId,
    'name': group.name,
    'worksheet_title': group.worksheetTitle,
    'display_order': group.displayOrder,
    'is_custom': group.isCustom,
    'is_archived': group.isArchived,
    'record_version': group.version,
    'row_count': group.rowCount,
    'column_count': group.columnCount,
    'document_count': group.documentCount,
    'linked_request_count': group.linkedRequestCount,
    'last_edited_by': group.lastEditedBy,
    'last_edited_role': group.lastEditedRole,
    'last_edited_at': group.lastEditedAt?.toUtc().toIso8601String(),
    'updated_at': group.updatedAt.toUtc().toIso8601String(),
    'scope_id': group.scopeId,
    'scope_kind': group.scopeKind,
    'scope_code': group.scopeCode,
    'scope_name': group.scopeName,
    'is_legacy_unassigned': group.isLegacyUnassigned,
  };
}
