import 'dart:convert';

/// Units of measurement for materials.
enum MaterialUnit {
  kg('kg', 'Kilograms', 'کلوگرام'),
  tons('tons', 'Tons', 'ٹن'),
  bags('bags', 'Bags', 'بوریاں'),
  pieces('pcs', 'Pieces', 'ٹکڑے'),
  meters('m', 'Meters', 'میٹر'),
  sqft('sqft', 'Square Feet', 'مربع فٹ'),
  liters('L', 'Liters', 'لیٹر'),
  cubic('m³', 'Cubic Meters', 'مکعب میٹر'),
  rods('rods', 'Rods', 'سریے'),
  sheets('sheets', 'Sheets', 'شیٹس'),
  sets('sets', 'Sets', 'سیٹس'),
  boxes('boxes', 'Boxes', 'ڈبے'),
  rolls('rolls', 'Rolls', 'رولز'),
  feet('ft', 'Feet', 'فٹ'),
  inches('in', 'Inches', 'انچ');

  const MaterialUnit(this.symbol, this.label, this.urduLabel);

  final String symbol;
  final String label;
  final String urduLabel;

  static MaterialUnit fromSymbol(String symbol) {
    return MaterialUnit.values.firstWhere(
      (u) => u.symbol == symbol,
      orElse: () => MaterialUnit.pieces,
    );
  }
}

/// Categories for materials.
///
/// Optimized for HVAC supply companies — valves, pipes, fittings,
/// fasteners, ducts, insulation, electrical controls, etc.
enum MaterialCategory {
  valves('Valves', 'والوز'),
  pipes('Pipes & Tubing', 'پائپ اور ٹیوبنگ'),
  fittings('Fittings & Connectors', 'فٹنگز اور کنیکٹرز'),
  fasteners('Fasteners', 'نٹ بولٹ'),
  ducts('Ducts & Dampers', 'ڈکٹس اور ڈیمپرز'),
  insulation('Insulation', 'انسولیشن'),
  electrical('Electrical & Controls', 'الیکٹریکل اور کنٹرولز'),
  copper('Copper & Brass', 'تانبا اور پیتل'),
  tools('Tools & Equipment', 'اوزار اور آلات'),
  other('Other', 'دیگر');

  const MaterialCategory(this.label, this.urduLabel);

  final String label;
  final String urduLabel;

  static MaterialCategory fromLabel(String label) {
    return MaterialCategory.values.firstWhere(
      (c) => c.label == label,
      orElse: () => MaterialCategory.other,
    );
  }
}

/// Stock status derived from quantity.
enum StockStatus { inStock, lowStock, outOfStock }

/// A single material item in the warehouse inventory.
class MaterialItem {
  MaterialItem({
    required this.id,
    required this.name,
    required this.urduName,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    this.minStockLevel = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final String urduName;
  final MaterialCategory category;
  final MaterialUnit unit;
  final double quantity;
  final double unitPrice;
  final double minStockLevel;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Total value of this item in stock.
  double get totalValue => quantity * unitPrice;

  /// Current stock status.
  StockStatus get stockStatus {
    if (quantity <= 0) return StockStatus.outOfStock;
    if (minStockLevel > 0 && quantity <= minStockLevel) {
      return StockStatus.lowStock;
    }
    return StockStatus.inStock;
  }

  /// Formatted quantity with unit symbol.
  String get formattedQuantity =>
      '${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 2)} ${unit.symbol}';

  MaterialItem copyWith({
    String? name,
    String? urduName,
    MaterialCategory? category,
    MaterialUnit? unit,
    double? quantity,
    double? unitPrice,
    double? minStockLevel,
    DateTime? updatedAt,
  }) {
    return MaterialItem(
      id: id,
      name: name ?? this.name,
      urduName: urduName ?? this.urduName,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'urduName': urduName,
    'category': category.label,
    'unit': unit.symbol,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'minStockLevel': minStockLevel,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MaterialItem.fromJson(Map<String, dynamic> json) => MaterialItem(
    id: json['id'] as String,
    name: json['name'] as String,
    urduName: json['urduName'] as String? ?? '',
    category: MaterialCategory.fromLabel(json['category'] as String),
    unit: MaterialUnit.fromSymbol(json['unit'] as String),
    quantity: (json['quantity'] as num).toDouble(),
    unitPrice: (json['unitPrice'] as num).toDouble(),
    minStockLevel: (json['minStockLevel'] as num?)?.toDouble() ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  /// Encode a list for SharedPreferences storage.
  static String encodeList(List<MaterialItem> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  /// Decode a list from SharedPreferences storage.
  static List<MaterialItem> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => MaterialItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
