import '../models/material_item.dart';
import '../models/material_master.dart';

abstract final class MaterialCatalogueCsvExport {
  static String build({
    required List<MaterialItem> materials,
    required Map<String, MaterialCategoryMaster> categories,
    required Map<String, MaterialUnitMaster> units,
    required bool includeCommercials,
  }) {
    final headers = <String>[
      'Material code',
      'Material description',
      'Secondary description',
      'Category',
      'Size',
      'Make / brand',
      'Origin',
      'On hand',
      'Allocated',
      'Available',
      'Unit',
      'Store',
      if (includeCommercials) 'Unit cost AED',
      if (includeCommercials) 'Stock value AED',
    ];
    final rows = <List<Object?>>[
      headers,
      for (final material in materials)
        [
          material.id,
          material.name,
          material.urduName,
          categories[material.categoryMasterId]?.name ??
              material.category.label,
          material.size,
          material.brand,
          material.countryOfOrigin,
          _number(material.quantity),
          _number(material.reservedQty),
          _number(material.availableQty),
          units[material.unitMasterId]?.symbol ?? material.unit.symbol,
          material.storeLocation,
          if (includeCommercials) material.unitPrice.toStringAsFixed(2),
          if (includeCommercials) material.totalValue.toStringAsFixed(2),
        ],
    ];
    return rows.map((row) => row.map(_cell).join(',')).join('\n');
  }

  static String _number(double value) => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  static String _cell(Object? value) =>
      '"${(value ?? '').toString().replaceAll('"', '""')}"';
}
