import 'dart:convert';

/// Type of material transaction.
enum TransactionType {
  incoming('Incoming', 'آمد', 'IN'),
  outgoing('Outgoing', 'روانگی', 'OUT');

  const TransactionType(this.label, this.urduLabel, this.code);

  final String label;
  final String urduLabel;
  final String code;

  static TransactionType fromCode(String code) {
    return TransactionType.values.firstWhere(
      (t) => t.code == code,
      orElse: () => TransactionType.incoming,
    );
  }
}

/// A single inventory transaction record.
class InventoryTransaction {
  InventoryTransaction({
    required this.id,
    required this.materialId,
    required this.materialName,
    required this.type,
    required this.quantity,
    required this.unitSymbol,
    this.notes = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String id;
  final String materialId;
  final String materialName;
  final TransactionType type;
  final double quantity;
  final String unitSymbol;
  final String notes;
  final DateTime timestamp;

  /// Formatted quantity string.
  String get formattedQuantity =>
      '${type == TransactionType.incoming ? '+' : '-'}${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 2)} $unitSymbol';

  Map<String, dynamic> toJson() => {
    'id': id,
    'materialId': materialId,
    'materialName': materialName,
    'type': type.code,
    'quantity': quantity,
    'unitSymbol': unitSymbol,
    'notes': notes,
    'timestamp': timestamp.toIso8601String(),
  };

  factory InventoryTransaction.fromJson(Map<String, dynamic> json) =>
      InventoryTransaction(
        id: json['id'] as String,
        materialId: json['materialId'] as String,
        materialName: json['materialName'] as String,
        type: TransactionType.fromCode(json['type'] as String),
        quantity: (json['quantity'] as num).toDouble(),
        unitSymbol: json['unitSymbol'] as String,
        notes: json['notes'] as String? ?? '',
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  /// Encode a list for SharedPreferences storage.
  static String encodeList(List<InventoryTransaction> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  /// Decode a list from SharedPreferences storage.
  static List<InventoryTransaction> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => InventoryTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
