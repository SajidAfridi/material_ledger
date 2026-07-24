import '../models/material_line_draft.dart';

abstract final class MaterialLineCsvExport {
  static const operationalHeaders = <String>[
    'S:No',
    'Item Description',
    'Size (If any)',
    'Model/Serial No.',
    'Make/Origin',
    'QTY',
    'Unit',
    'Remarks',
  ];

  static const commercialHeaders = <String>['Unit Cost', 'Total Cost'];

  static String build({
    required List<MaterialLineDraft> lines,
    Map<String, MaterialLineCommercial> commercials = const {},
    required bool includeCommercials,
  }) {
    final headers = [
      ...operationalHeaders,
      if (includeCommercials) ...commercialHeaders,
    ];
    final rows = <List<Object?>>[
      headers,
      for (var index = 0; index < lines.length; index++)
        _values(
          index,
          lines[index],
          includeCommercials ? commercials[lines[index].id] : null,
          includeCommercials: includeCommercials,
        ),
    ];
    return rows.map((row) => row.map(_escape).join(',')).join('\r\n');
  }

  static List<Object?> _values(
    int index,
    MaterialLineDraft line,
    MaterialLineCommercial? commercial, {
    required bool includeCommercials,
  }) => [
    index + 1,
    line.description,
    line.size,
    line.modelSerial,
    line.makeOrigin,
    line.quantity == null ? '' : _number(line.quantity!),
    line.unitSymbol,
    line.remarks,
    if (includeCommercials) _money(commercial?.unitCostAED),
    if (includeCommercials) _money(commercial?.totalCostAED(line.quantity)),
  ];

  static String _escape(Object? value) =>
      '"${(value ?? '').toString().replaceAll('"', '""')}"';

  static String _number(double value) =>
      value == value.truncateToDouble() ? value.toInt().toString() : '$value';

  static String _money(double? value) =>
      value == null ? '' : value.toStringAsFixed(2);
}
