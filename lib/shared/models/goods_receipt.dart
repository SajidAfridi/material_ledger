import 'dart:convert';

/// A goods-receipt note (GRN) — procurement records stock physically arriving
/// into the store, capturing quantity, unit cost (AED) and supplier. Receiving
/// a GRN increments on-hand inventory and rolls the unit cost into a weighted
/// average. See SRS v1.2 §B (goods receipt) / FR-090.
class GoodsReceipt {
  const GoodsReceipt({
    required this.id,
    required this.materialId,
    required this.materialName,
    required this.quantity,
    required this.unitSymbol,
    required this.unitCostAED,
    required this.supplier,
    required this.receivedBy,
    required this.receivedAt,
    this.note,
  });

  final String id;
  final String materialId;
  final String materialName;
  final double quantity;
  final String unitSymbol;
  final double unitCostAED;
  final String supplier;
  final String receivedBy;
  final DateTime receivedAt;
  final String? note;

  /// Total value of this receipt in AED.
  double get lineValueAED => quantity * unitCostAED;

  Map<String, dynamic> toJson() => {
    'id': id,
    'materialId': materialId,
    'materialName': materialName,
    'quantity': quantity,
    'unitSymbol': unitSymbol,
    'unitCostAED': unitCostAED,
    'supplier': supplier,
    'receivedBy': receivedBy,
    'receivedAt': receivedAt.toIso8601String(),
    if (note != null) 'note': note,
  };

  factory GoodsReceipt.fromJson(Map<String, dynamic> json) => GoodsReceipt(
    id: json['id'] as String,
    materialId: json['materialId'] as String,
    materialName: json['materialName'] as String,
    quantity: (json['quantity'] as num).toDouble(),
    unitSymbol: json['unitSymbol'] as String,
    unitCostAED: (json['unitCostAED'] as num).toDouble(),
    supplier: json['supplier'] as String,
    receivedBy: json['receivedBy'] as String,
    receivedAt: DateTime.parse(json['receivedAt'] as String),
    note: json['note'] as String?,
  );

  static String encodeList(List<GoodsReceipt> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<GoodsReceipt> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => GoodsReceipt.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
