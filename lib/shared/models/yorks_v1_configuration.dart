enum YorksV1ConfigurationArea {
  overview('overview'),
  companyRegional('company_regional'),
  projectsTeams('projects_teams'),
  boqMaterials('boq_materials'),
  materialRequests('material_requests'),
  procurementInventory('procurement_inventory'),
  accounts('accounts'),
  documentsPrinting('documents_printing'),
  notifications('notifications'),
  securityAudit('security_audit'),
  numberingData('numbering_data'),
  history('history');

  const YorksV1ConfigurationArea(this.wireName);

  final String wireName;

  static YorksV1ConfigurationArea fromWireName(String? value) {
    return values.firstWhere(
      (area) => area.wireName == value,
      orElse: () => overview,
    );
  }
}

class YorksV1ConfigurationSetting {
  const YorksV1ConfigurationSetting({
    required this.key,
    required this.area,
    required this.type,
    required this.publishedValue,
    required this.draftValue,
    required this.effectiveValue,
    required this.changed,
  });

  final String key;
  final YorksV1ConfigurationArea area;
  final String type;
  final Object? publishedValue;
  final Object? draftValue;
  final Object? effectiveValue;
  final bool changed;

  factory YorksV1ConfigurationSetting.fromJson(Map<String, dynamic> json) {
    return YorksV1ConfigurationSetting(
      key: json['key']?.toString() ?? '',
      area: YorksV1ConfigurationArea.fromWireName(json['area']?.toString()),
      type: json['type']?.toString() ?? 'string',
      publishedValue: json['published_value'],
      draftValue: json['draft_value'],
      effectiveValue: json['effective_value'],
      changed: json['changed'] == true,
    );
  }
}

class YorksV1ConfigurationIssue {
  const YorksV1ConfigurationIssue({
    required this.code,
    required this.area,
    required this.message,
  });

  final String code;
  final YorksV1ConfigurationArea area;
  final String message;

  factory YorksV1ConfigurationIssue.fromJson(Map<String, dynamic> json) {
    return YorksV1ConfigurationIssue(
      code: json['code']?.toString() ?? '',
      area: YorksV1ConfigurationArea.fromWireName(json['area']?.toString()),
      message: json['message']?.toString() ?? '',
    );
  }
}

enum YorksV1ConfigurationValidationStatus { ready, recommendations, blocked }

class YorksV1ConfigurationValidation {
  const YorksV1ConfigurationValidation({
    required this.status,
    required this.blocking,
    required this.recommendations,
  });

  final YorksV1ConfigurationValidationStatus status;
  final List<YorksV1ConfigurationIssue> blocking;
  final List<YorksV1ConfigurationIssue> recommendations;

  bool get canPublish => blocking.isEmpty;

  factory YorksV1ConfigurationValidation.fromJson(Map<String, dynamic> json) {
    return YorksV1ConfigurationValidation(
      status: YorksV1ConfigurationValidationStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => YorksV1ConfigurationValidationStatus.blocked,
      ),
      blocking: _objectList(
        json['blocking'],
      ).map(YorksV1ConfigurationIssue.fromJson).toList(growable: false),
      recommendations: _objectList(
        json['recommendations'],
      ).map(YorksV1ConfigurationIssue.fromJson).toList(growable: false),
    );
  }
}

class YorksV1ConfigurationCategory {
  const YorksV1ConfigurationCategory({
    required this.id,
    required this.name,
    required this.parentCategoryId,
    required this.isSystem,
    required this.isActive,
    this.itemCount = 0,
  });

  final String id;
  final String name;
  final String? parentCategoryId;
  final bool isSystem;
  final bool isActive;
  final int itemCount;

  factory YorksV1ConfigurationCategory.fromJson(Map<String, dynamic> json) {
    return YorksV1ConfigurationCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      parentCategoryId: json['parent_category_id']?.toString(),
      isSystem: json['is_system'] == true,
      isActive: json['is_active'] != false,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class YorksV1ConfigurationBoqTemplate {
  const YorksV1ConfigurationBoqTemplate({
    required this.key,
    required this.name,
    required this.order,
    required this.isFrozen,
    required this.isActive,
  });

  final String key;
  final String name;
  final int order;
  final bool isFrozen;
  final bool isActive;

  factory YorksV1ConfigurationBoqTemplate.fromJson(Map<String, dynamic> json) {
    return YorksV1ConfigurationBoqTemplate(
      key: json['template_key']?.toString() ?? '',
      name: json['display_name']?.toString() ?? '',
      order: (json['display_order'] as num?)?.toInt() ?? 0,
      isFrozen: json['is_frozen'] == true,
      isActive: json['is_active'] != false,
    );
  }
}

class YorksV1ConfigurationUnit {
  const YorksV1ConfigurationUnit({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.unitType,
    required this.decimalPlaces,
    required this.isSystem,
    required this.isActive,
  });

  final String id;
  final String name;
  final String shortCode;
  final String unitType;
  final int decimalPlaces;
  final bool isSystem;
  final bool isActive;

  factory YorksV1ConfigurationUnit.fromJson(Map<String, dynamic> json) {
    return YorksV1ConfigurationUnit(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      shortCode: json['short_code']?.toString() ?? '',
      unitType: json['unit_type']?.toString() ?? 'other',
      decimalPlaces: (json['decimal_places'] as num?)?.toInt() ?? 0,
      isSystem: json['is_system'] == true,
      isActive: json['is_active'] != false,
    );
  }
}

class YorksV1ConfigurationMasterAction {
  const YorksV1ConfigurationMasterAction({
    required this.id,
    required this.entityKind,
    required this.actionKind,
    required this.targetId,
    required this.payload,
    required this.reason,
  });

  final String id;
  final String entityKind;
  final String actionKind;
  final String targetId;
  final Map<String, dynamic> payload;
  final String? reason;

  factory YorksV1ConfigurationMasterAction.fromJson(Map<String, dynamic> json) {
    return YorksV1ConfigurationMasterAction(
      id: json['id']?.toString() ?? '',
      entityKind: json['entity_kind']?.toString() ?? '',
      actionKind: json['action_kind']?.toString() ?? '',
      targetId: json['target_id']?.toString() ?? '',
      payload: _object(json['payload']),
      reason: json['reason']?.toString(),
    );
  }
}

class YorksV1ConfigurationPublication {
  const YorksV1ConfigurationPublication({
    required this.id,
    required this.versionNumber,
    required this.versionLabel,
    required this.reason,
    required this.affectedAreas,
    required this.publishedAt,
    required this.publishedBy,
    required this.publishedByExactRole,
    required this.changeCount,
  });

  final String id;
  final int versionNumber;
  final String versionLabel;
  final String reason;
  final List<YorksV1ConfigurationArea> affectedAreas;
  final DateTime publishedAt;
  final String publishedBy;
  final String publishedByExactRole;
  final int changeCount;

  factory YorksV1ConfigurationPublication.fromJson(Map<String, dynamic> json) {
    return YorksV1ConfigurationPublication(
      id: json['id']?.toString() ?? '',
      versionNumber: (json['version_number'] as num?)?.toInt() ?? 0,
      versionLabel: json['version_label']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      affectedAreas: (json['affected_areas'] as List? ?? const [])
          .map((area) => YorksV1ConfigurationArea.fromWireName(area.toString()))
          .toList(growable: false),
      publishedAt:
          DateTime.tryParse(
            json['published_at']?.toString() ?? '',
          )?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      publishedBy: json['published_by']?.toString() ?? '',
      publishedByExactRole: json['published_by_exact_role']?.toString() ?? '',
      changeCount: (json['change_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class YorksV1ConfigurationCentre {
  const YorksV1ConfigurationCentre({
    required this.schemaVersion,
    required this.environment,
    required this.publishedVersion,
    required this.publishedLabel,
    required this.publishedAt,
    required this.publishedBy,
    required this.draftRevision,
    required this.draftBaseVersion,
    required this.draftUpdatedAt,
    required this.settings,
    required this.masterActions,
    required this.categories,
    required this.units,
    required this.boqTemplates,
    required this.history,
    required this.validation,
  });

  final String schemaVersion;
  final String environment;
  final int publishedVersion;
  final String publishedLabel;
  final DateTime publishedAt;
  final String publishedBy;
  final int draftRevision;
  final int draftBaseVersion;
  final DateTime draftUpdatedAt;
  final List<YorksV1ConfigurationSetting> settings;
  final List<YorksV1ConfigurationMasterAction> masterActions;
  final List<YorksV1ConfigurationCategory> categories;
  final List<YorksV1ConfigurationUnit> units;
  final List<YorksV1ConfigurationBoqTemplate> boqTemplates;
  final List<YorksV1ConfigurationPublication> history;
  final YorksV1ConfigurationValidation validation;

  int get draftChangeCount =>
      settings.where((setting) => setting.changed).length +
      masterActions.length;

  bool get hasDraft => draftChangeCount > 0;

  Set<YorksV1ConfigurationArea> get affectedAreas => {
    for (final setting in settings)
      if (setting.changed) setting.area,
    if (masterActions.isNotEmpty) YorksV1ConfigurationArea.boqMaterials,
  };

  Object? value(String settingKey) {
    for (final setting in settings) {
      if (setting.key == settingKey) return setting.effectiveValue;
    }
    return null;
  }

  String stringValue(String settingKey, [String fallback = '']) =>
      value(settingKey)?.toString() ?? fallback;

  bool boolValue(String settingKey, [bool fallback = false]) =>
      value(settingKey) is bool ? value(settingKey)! as bool : fallback;

  int intValue(String settingKey, [int fallback = 0]) =>
      (value(settingKey) as num?)?.toInt() ?? fallback;

  List<String> stringListValue(
    String settingKey, [
    List<String> fallback = const [],
  ]) {
    final raw = value(settingKey);
    if (raw is! List) return fallback;
    return raw.map((entry) => entry.toString()).toList(growable: false);
  }

  Map<String, num> numberMapValue(String settingKey) {
    final raw = value(settingKey);
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value is num) entry.key.toString(): entry.value as num,
    };
  }

  factory YorksV1ConfigurationCentre.fromJson(Map<String, dynamic> json) {
    return YorksV1ConfigurationCentre(
      schemaVersion: json['schema_version']?.toString() ?? '',
      environment: json['environment']?.toString() ?? '',
      publishedVersion: (json['published_version'] as num?)?.toInt() ?? 0,
      publishedLabel: json['published_label']?.toString() ?? '',
      publishedAt:
          DateTime.tryParse(
            json['published_at']?.toString() ?? '',
          )?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      publishedBy: json['published_by']?.toString() ?? '',
      draftRevision: (json['draft_revision'] as num?)?.toInt() ?? 0,
      draftBaseVersion: (json['draft_base_version'] as num?)?.toInt() ?? 0,
      draftUpdatedAt:
          DateTime.tryParse(
            json['draft_updated_at']?.toString() ?? '',
          )?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      settings: _objectList(
        json['settings'],
      ).map(YorksV1ConfigurationSetting.fromJson).toList(growable: false),
      masterActions: _objectList(
        json['master_actions'],
      ).map(YorksV1ConfigurationMasterAction.fromJson).toList(growable: false),
      categories: _objectList(
        json['material_categories'],
      ).map(YorksV1ConfigurationCategory.fromJson).toList(growable: false),
      units: _objectList(
        json['material_units'],
      ).map(YorksV1ConfigurationUnit.fromJson).toList(growable: false),
      boqTemplates: _objectList(
        json['boq_group_templates'],
      ).map(YorksV1ConfigurationBoqTemplate.fromJson).toList(growable: false),
      history: _objectList(
        json['history'],
      ).map(YorksV1ConfigurationPublication.fromJson).toList(growable: false),
      validation: YorksV1ConfigurationValidation.fromJson(
        _object(json['validation']),
      ),
    );
  }
}

Map<String, dynamic> _object(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _objectList(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const <Map<String, dynamic>>[];
