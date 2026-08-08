import 'yorks_v1_domain_error.dart';

/// Canonical meanings are stored independently of the editable worksheet
/// headings.  This makes an imported/custom heading searchable without
/// turning it into a fixed visible BOQ column.
enum YorksV1BoqCanonicalField {
  description('description'),
  size('size'),
  model('model'),
  equipmentTag('equipment_tag'),
  brandOrigin('brand_origin'),
  quantity('quantity'),
  unit('unit'),

  /// Legacy combined mapping retained so previously imported worksheets keep
  /// their meaning while new imports preserve model and tag separately.
  planningModelTag('planning_model_tag');

  const YorksV1BoqCanonicalField(this.wireValue);

  final String wireValue;

  static YorksV1BoqCanonicalField? fromWireValue(Object? value) {
    if (value is! String) return null;
    for (final field in values) {
      if (field.wireValue == value) return field;
    }
    return null;
  }
}

/// A BOQ folder owned by one persisted Common/building scope. The All selector
/// is an aggregate presentation only, never a value stored in this record.
class YorksV1BoqGroup {
  const YorksV1BoqGroup({
    required this.id,
    required this.projectId,
    required this.name,
    required this.worksheetTitle,
    required this.displayOrder,
    required this.isCustom,
    required this.isArchived,
    required this.version,
    required this.rowCount,
    required this.columnCount,
    required this.updatedAt,
    this.scopeId,
    this.scopeKind,
    this.scopeCode,
    this.scopeName,
    this.isLegacyUnassigned = false,
  });

  final String id;
  final String projectId;
  final String name;
  final String worksheetTitle;
  final int displayOrder;
  final bool isCustom;
  final bool isArchived;
  final int version;
  final int rowCount;
  final int columnCount;
  final DateTime updatedAt;
  final String? scopeId;
  final String? scopeKind;
  final String? scopeCode;
  final String? scopeName;

  /// Pre-R38 project-level groups are retained with no inferred destination.
  /// They can be viewed in All and require an explicit scope-assignment command
  /// before worksheet edits, imports, exports or MR use.
  final bool isLegacyUnassigned;

  bool get isScopeAssigned =>
      !isLegacyUnassigned && (scopeId?.trim().isNotEmpty ?? false);

  String get effectiveTitle =>
      worksheetTitle.trim().isEmpty ? name : worksheetTitle.trim();

  factory YorksV1BoqGroup.fromRpcJson(Map<String, dynamic> json) {
    return YorksV1BoqGroup(
      id: _requiredString(json, 'id'),
      projectId: _requiredString(json, 'project_id'),
      name: _requiredString(json, 'name'),
      worksheetTitle: _string(json['worksheet_title']),
      displayOrder: _integer(json['display_order']),
      isCustom: json['is_custom'] == true,
      isArchived: json['is_archived'] == true,
      version: _integer(json['record_version']),
      rowCount: _integer(json['row_count']),
      columnCount: _integer(json['column_count']),
      updatedAt: _date(json['updated_at']),
      scopeId: _nullableString(json['scope_id']),
      scopeKind: _nullableString(json['scope_kind']),
      scopeCode: _nullableString(json['scope_code']),
      scopeName: _nullableString(json['scope_name']),
      isLegacyUnassigned: json['is_legacy_unassigned'] == true,
    );
  }
}

/// A visible BOQ worksheet column.  Commercial columns are never returned to
/// a user without the server-controlled capability; the normal editor only
/// handles the operational projection.
class YorksV1BoqColumn {
  const YorksV1BoqColumn({
    required this.id,
    required this.heading,
    required this.displayOrder,
    this.canonicalField,
    this.isCommercial = false,
    this.version = 1,
  });

  final String id;
  final String heading;
  final int displayOrder;
  final YorksV1BoqCanonicalField? canonicalField;
  final bool isCommercial;
  final int version;

  YorksV1BoqColumn copyWith({
    String? heading,
    int? displayOrder,
    YorksV1BoqCanonicalField? canonicalField,
    bool clearCanonicalField = false,
    bool? isCommercial,
    int? version,
  }) {
    return YorksV1BoqColumn(
      id: id,
      heading: heading ?? this.heading,
      displayOrder: displayOrder ?? this.displayOrder,
      canonicalField: clearCanonicalField
          ? null
          : canonicalField ?? this.canonicalField,
      isCommercial: isCommercial ?? this.isCommercial,
      version: version ?? this.version,
    );
  }

  factory YorksV1BoqColumn.fromRpcJson(Map<String, dynamic> json) {
    return YorksV1BoqColumn(
      id: _requiredString(json, 'id'),
      heading: _requiredString(json, 'heading'),
      displayOrder: _integer(json['display_order']),
      canonicalField: YorksV1BoqCanonicalField.fromWireValue(
        json['canonical_field'],
      ),
      isCommercial: json['is_commercial'] == true,
      version: _integer(json['record_version']),
    );
  }

  Map<String, Object?> toSaveJson() => {
    'id': id,
    'heading': heading.trim(),
    'display_order': displayOrder,
    'canonical_field': canonicalField?.wireValue,
    'is_commercial': isCommercial,
  };
}

/// One ordered BOQ worksheet row.  Values are keyed by stable column IDs so a
/// heading rename cannot rewrite historical value associations.
class YorksV1BoqRow {
  YorksV1BoqRow({
    required this.id,
    required this.displayOrder,
    required Map<String, Object?> values,
    required Map<String, Object?> canonicalValues,
    this.version = 1,
  }) : values = Map.unmodifiable(values),
       canonicalValues = Map.unmodifiable(canonicalValues);

  final String id;
  final int displayOrder;
  final Map<String, Object?> values;
  final Map<String, Object?> canonicalValues;
  final int version;

  Object? valueFor(String columnId) => values[columnId];

  YorksV1BoqRow copyWith({
    int? displayOrder,
    Map<String, Object?>? values,
    Map<String, Object?>? canonicalValues,
    int? version,
  }) {
    return YorksV1BoqRow(
      id: id,
      displayOrder: displayOrder ?? this.displayOrder,
      values: values ?? this.values,
      canonicalValues: canonicalValues ?? this.canonicalValues,
      version: version ?? this.version,
    );
  }

  factory YorksV1BoqRow.fromRpcJson(Map<String, dynamic> json) {
    return YorksV1BoqRow(
      id: _requiredString(json, 'id'),
      displayOrder: _integer(json['display_order']),
      values: _objectMap(json['raw_values']),
      canonicalValues: _objectMap(json['canonical_values']),
      version: _integer(json['record_version']),
    );
  }

  Map<String, Object?> toSaveJson() => {
    'id': id,
    'display_order': displayOrder,
    'raw_values': values,
  };
}

/// The complete, role-safe editable worksheet projection.
class YorksV1BoqWorksheet {
  YorksV1BoqWorksheet({
    required this.group,
    required List<YorksV1BoqColumn> columns,
    required List<YorksV1BoqRow> rows,
  }) : columns = List.unmodifiable(columns),
       rows = List.unmodifiable(rows);

  final YorksV1BoqGroup group;
  final List<YorksV1BoqColumn> columns;
  final List<YorksV1BoqRow> rows;

  YorksV1BoqWorksheet copyWith({
    YorksV1BoqGroup? group,
    List<YorksV1BoqColumn>? columns,
    List<YorksV1BoqRow>? rows,
  }) => YorksV1BoqWorksheet(
    group: group ?? this.group,
    columns: columns ?? this.columns,
    rows: rows ?? this.rows,
  );

  factory YorksV1BoqWorksheet.fromRpcJson(Map<String, dynamic> json) {
    final groupJson = _requiredMap(json, 'group');
    return YorksV1BoqWorksheet(
      group: YorksV1BoqGroup.fromRpcJson(groupJson),
      columns: _mapList(
        json['columns'],
      ).map(YorksV1BoqColumn.fromRpcJson).toList(growable: false),
      rows: _mapList(
        json['rows'],
      ).map(YorksV1BoqRow.fromRpcJson).toList(growable: false),
    );
  }
}

class YorksV1SaveBoqWorksheetInput {
  YorksV1SaveBoqWorksheetInput({
    required this.worksheet,
    required this.worksheetTitle,
    required this.expectedVersion,
    required this.idempotencyKey,
    this.reason = 'Worksheet edit',
  });

  final YorksV1BoqWorksheet worksheet;
  final String worksheetTitle;
  final int expectedVersion;
  final String idempotencyKey;
  final String reason;

  Map<String, Object?> toRpcPayload() => {
    'group_id': worksheet.group.id,
    'expected_version': expectedVersion,
    'worksheet_title': worksheetTitle.trim(),
    'columns': [for (final column in worksheet.columns) column.toSaveJson()],
    'rows': [for (final row in worksheet.rows) row.toSaveJson()],
    'reason': reason.trim(),
  };
}

class YorksV1CreateBoqGroupInput {
  const YorksV1CreateBoqGroupInput({
    required this.projectId,
    required this.scopeId,
    required this.name,
    required this.idempotencyKey,
  });

  final String projectId;
  final String scopeId;
  final String name;
  final String idempotencyKey;

  Map<String, Object?> toRpcPayload() => {
    'project_id': projectId,
    'scope_id': scopeId,
    'name': name.trim(),
  };
}

class YorksV1AssignLegacyBoqGroupScopeInput {
  const YorksV1AssignLegacyBoqGroupScopeInput({
    required this.groupId,
    required this.scopeId,
    required this.expectedVersion,
    required this.idempotencyKey,
  });

  final String groupId;
  final String scopeId;
  final int expectedVersion;
  final String idempotencyKey;

  Map<String, Object?> toRpcPayload() => {
    'group_id': groupId,
    'scope_id': scopeId,
    'expected_version': expectedVersion,
  };
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw const YorksV1DomainException(YorksV1DomainErrorCode.unexpectedResponse);
}

String _string(Object? value) => value is String ? value : '';

String? _nullableString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

int _integer(Object? value) => switch (value) {
  int value => value,
  num value => value.toInt(),
  String value => int.tryParse(value) ?? 0,
  _ => 0,
};

DateTime _date(Object? value) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) {
    throw const YorksV1DomainException(
      YorksV1DomainErrorCode.unexpectedResponse,
    );
  }
  return parsed.toUtc();
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const YorksV1DomainException(YorksV1DomainErrorCode.unexpectedResponse);
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) return const {};
  return {for (final entry in value.entries) entry.key.toString(): entry.value};
}
