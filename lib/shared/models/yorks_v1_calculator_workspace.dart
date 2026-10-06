import 'dart:convert';

/// Saved input snapshots retain unknown fields for forward-compatible imports.
class YorksCalculatorRecord {
  YorksCalculatorRecord(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'] as String;
  String get title => json['title'] as String;
  String get kind => json['kind'] as String;
  String? get projectId => json['project_id'] as String?;
  String? get projectName => json['project_name'] as String?;
  String get owner => json['owner_name'] as String? ?? '';
  String get updatedBy => json['updated_by_name'] as String? ?? owner;
  String get updatedAt => json['updated_at'] as String? ?? '';
  int get version => json['record_version'] as int;
  bool get canEdit => json['can_edit'] == true;
  bool get canManage => json['can_manage'] == true;
  bool get archived => json['archived'] == true;
  Map<String, dynamic> get payload =>
      Map<String, dynamic>.from(json['payload'] as Map? ?? {});
  List<Map<String, dynamic>> get grants => (json['grants'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

class YorksCalculatorDeviceImports {
  const YorksCalculatorDeviceImports(this.available, this.invalid);
  final Map<String, Map<String, dynamic>> available;
  final Set<String> invalid;
}

abstract final class YorksCalculatorFiles {
  static const maximumBytes = 1048576;
  static Map<String, dynamic> decode(String raw, {String? expectedKind}) {
    if (utf8.encode(raw).length > maximumBytes) {
      throw const FormatException('CALCULATOR_FILE_TOO_LARGE');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('CALCULATOR_INVALID_INPUT');
    }
    validate(decoded, expectedKind: expectedKind);
    return decoded;
  }

  static void validate(Map<String, dynamic> data, {String? expectedKind}) {
    if (utf8.encode(jsonEncode(data)).length > maximumBytes) {
      throw const FormatException('CALCULATOR_FILE_TOO_LARGE');
    }
    final app = data['app'];
    if (data['version'] != 1 ||
        !['duct-calc', 'esp-calc'].contains(app) ||
        (expectedKind != null &&
            app != '${expectedKind == 'duct' ? 'duct' : 'esp'}-calc')) {
      throw const FormatException('CALCULATOR_INVALID_INPUT');
    }
    if (app == 'duct-calc') {
      for (final key in [
        'flow',
        'width',
        'height',
        'diameter',
        'targetVelocity',
        'targetFriction',
        'equivalentDiameter',
        'aspectRatio',
      ]) {
        if (data[key] != null && data[key] is! String) {
          throw const FormatException('CALCULATOR_INVALID_INPUT');
        }
        final text = data[key] as String?;
        if (text != null &&
            text.isNotEmpty &&
            (double.tryParse(text.replaceAll(',', '.'))?.isFinite != true ||
                double.parse(text.replaceAll(',', '.')) < 0)) {
          throw const FormatException('CALCULATOR_INVALID_INPUT');
        }
      }
      if (data['unitSystem'] != null &&
          !['SI', 'Imperial'].contains(data['unitSystem'])) {
        throw const FormatException('CALCULATOR_INVALID_INPUT');
      }
      if (data['shape'] != null &&
          !['rectangular', 'circular'].contains(data['shape'])) {
        throw const FormatException('CALCULATOR_INVALID_INPUT');
      }
      if (data['mode'] != null &&
          ![
            'checkSize',
            'velocity',
            'friction',
            'equivalentDiameter',
          ].contains(data['mode'])) {
        throw const FormatException('CALCULATOR_INVALID_INPUT');
      }
      if (data['condition'] != null &&
          ![
            'Air at 15°C',
            '20°C Air STP',
            'Air at 25°C',
            'Air at 30°C',
          ].contains(data['condition'])) {
        throw const FormatException('CALCULATOR_INVALID_INPUT');
      }
      if (data['material'] != null &&
          ![
            'Galvanized steel',
            'Aluminium',
            'Black steel',
            'Flexible duct',
            'Concrete',
          ].contains(data['material'])) {
        throw const FormatException('CALCULATOR_INVALID_INPUT');
      }
    } else {
      final rows = data['rows'];
      if (rows is! List ||
          rows.length > 1000 ||
          rows.any((e) => e is! Map<String, dynamic>)) {
        throw const FormatException('CALCULATOR_INVALID_INPUT');
      }
      if (data['header'] != null && data['header'] is! Map<String, dynamic>) {
        throw const FormatException('CALCULATOR_INVALID_INPUT');
      }
      if (data['safetyFactor'] != null &&
          (data['safetyFactor'] is! String ||
              double.tryParse(data['safetyFactor'])?.isFinite != true ||
              double.parse(data['safetyFactor']) < 0)) {
        throw const FormatException('CALCULATOR_INVALID_INPUT');
      }
      final ids = <String>{};
      for (final row in rows.cast<Map<String, dynamic>>()) {
        for (final key in [
          'id',
          'fitting',
          'flow',
          'width',
          'height',
          'length',
          'diameter',
          'manualEsp',
        ]) {
          if (row[key] != null && row[key] is! String) {
            throw const FormatException('CALCULATOR_INVALID_INPUT');
          }
        }
        if (row['id'] != null && !ids.add(row['id'] as String)) {
          throw const FormatException('CALCULATOR_INVALID_INPUT');
        }
        for (final key in [
          'flow',
          'width',
          'height',
          'length',
          'diameter',
          'manualEsp',
        ]) {
          final value = row[key] as String?;
          if (value != null && value.trim().isNotEmpty) {
            final n = double.tryParse(value.replaceAll(',', '.'));
            if (n == null || !n.isFinite || n < 0) {
              throw const FormatException('CALCULATOR_INVALID_INPUT');
            }
          }
        }
      }
    }
  }

  static Map<String, dynamic> fresh(String kind) => kind == 'duct'
      ? {
          'app': 'duct-calc',
          'version': 1,
          'condition': '20°C Air STP',
          'unitSystem': 'SI',
          'material': 'Galvanized steel',
          'shape': 'rectangular',
          'mode': 'checkSize',
          'flow': '',
          'width': '',
          'height': '',
          'diameter': '',
          'targetVelocity': '2.50',
          'targetFriction': '0.800',
          'equivalentDiameter': '500',
          'aspectRatio': '1.0',
        }
      : {
          'app': 'esp-calc',
          'version': 1,
          'header': <String, dynamic>{},
          'safetyFactor': '10',
          'rows': <dynamic>[],
        };
  static String fingerprint(Map<String, dynamic> data) {
    Object? canonical(Object? v) => v is Map
        ? {
            for (final k in v.keys.map((e) => e.toString()).toList()..sort())
              if (k != 'savedAt') k: canonical(v[k]),
          }
        : v is List
        ? v.map(canonical).toList()
        : v;
    return jsonEncode(canonical(data));
  }
}
