/// Operational material-line fields shared by plans and requests.
///
/// Commercial values deliberately do not live in this model. A denied session
/// can therefore receive and cache [MaterialLineDraft] values without ever
/// receiving Unit Cost or Total Cost.
class MaterialLineDraft {
  const MaterialLineDraft({
    required this.id,
    this.description = '',
    this.size = '',
    this.modelSerial = '',
    this.makeOrigin = '',
    this.quantity,
    this.unitSymbol = 'Nos',
    this.remarks = '',
  });

  final String id;
  final String description;
  final String size;
  final String modelSerial;
  final String makeOrigin;
  final double? quantity;
  final String unitSymbol;
  final String remarks;

  MaterialLineDraft copyWith({
    String? description,
    String? size,
    String? modelSerial,
    String? makeOrigin,
    Object? quantity = _unchanged,
    String? unitSymbol,
    String? remarks,
  }) {
    return MaterialLineDraft(
      id: id,
      description: description ?? this.description,
      size: size ?? this.size,
      modelSerial: modelSerial ?? this.modelSerial,
      makeOrigin: makeOrigin ?? this.makeOrigin,
      quantity: identical(quantity, _unchanged)
          ? this.quantity
          : quantity as double?,
      unitSymbol: unitSymbol ?? this.unitSymbol,
      remarks: remarks ?? this.remarks,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'size': size,
    'modelSerial': modelSerial,
    'makeOrigin': makeOrigin,
    'quantity': quantity,
    'unitSymbol': unitSymbol,
    'remarks': remarks,
  };

  factory MaterialLineDraft.fromJson(Map<String, dynamic> json) =>
      MaterialLineDraft(
        id: json['id'] as String? ?? '',
        description: json['description'] as String? ?? '',
        size: json['size'] as String? ?? '',
        modelSerial: json['modelSerial'] as String? ?? '',
        makeOrigin: json['makeOrigin'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble(),
        unitSymbol: json['unitSymbol'] as String? ?? 'Nos',
        remarks: json['remarks'] as String? ?? '',
      );
}

/// Protected commercial payload for one material line.
///
/// This object is supplied only to a controller created for an authorised
/// session. Total Cost remains derived from quantity × Unit Cost.
class MaterialLineCommercial {
  const MaterialLineCommercial({
    required this.lineId,
    required this.unitCostAED,
  });

  final String lineId;
  final double unitCostAED;

  double totalCostAED(double? quantity) => (quantity ?? 0) * unitCostAED;

  MaterialLineCommercial copyWith({double? unitCostAED}) =>
      MaterialLineCommercial(
        lineId: lineId,
        unitCostAED: unitCostAED ?? this.unitCostAED,
      );
}

enum MaterialLineField {
  description,
  size,
  modelSerial,
  makeOrigin,
  quantity,
  unit,
  remarks,
  unitCost,
}

enum MaterialSizeMode { rectangular, circular, linear, nominalPipe, custom }

abstract final class MaterialSizeFormatter {
  static String rectangular({
    required num width,
    required num height,
    String unit = 'mm',
  }) => '${_number(width)} x ${_number(height)} $unit';

  static String circular({required num diameter, String unit = 'mm'}) =>
      'Ø${_number(diameter)} $unit';

  static String linear({required num length, String unit = 'm'}) =>
      '${_number(length)} $unit';

  static String nominalPipe(String value) => value.trim();

  static String custom(String value) => value.trim();

  static String _number(num value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}

const Object _unchanged = Object();
