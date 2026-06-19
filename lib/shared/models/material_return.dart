import 'dart:convert';

/// Why material is being returned to store (FR-083).
enum ReturnReason {
  surplus('Surplus', 'فاضل', 'فائض', 'अधिशेष'),
  wrongItem('Wrong item', 'غلط چیز', 'صنف خاطئ', 'गलत वस्तु'),
  damaged('Damaged', 'خراب', 'تالف', 'क्षतिग्रस्त');

  const ReturnReason(this.label, this.urdu, this.arabic, this.hindi);

  final String label;
  final String urdu;
  final String arabic;
  final String hindi;

  static ReturnReason fromLabel(String l) => ReturnReason.values.firstWhere(
    (r) => r.label == l,
    orElse: () => ReturnReason.surplus,
  );
}

/// Lifecycle of a return.
enum ReturnStatus {
  pending('Pending', 'زیر التواء', 'معلق', 'लंबित'),
  restocked('Restocked', 'دوبارہ اسٹاک', 'أعيد للمخزون', 'पुनः स्टॉक');

  const ReturnStatus(this.label, this.urdu, this.arabic, this.hindi);

  final String label;
  final String urdu;
  final String arabic;
  final String hindi;

  static ReturnStatus fromLabel(String l) => ReturnStatus.values.firstWhere(
    (r) => r.label == l,
    orElse: () => ReturnStatus.pending,
  );
}

class ReturnItem {
  const ReturnItem({
    required this.description,
    this.descriptionSecondary = '',
    required this.quantity,
    required this.unitSymbol,
    this.reason = ReturnReason.surplus,
    this.materialId,
  });

  final String description;
  final String descriptionSecondary;
  final double quantity;
  final String unitSymbol;
  final ReturnReason reason;

  /// Inventory item this return maps to, when picked from stock. Lets the
  /// return be restocked precisely and valued for the project cost roll-up.
  /// Null for free-text/custom returns.
  final String? materialId;

  ReturnItem copyWith({double? quantity, ReturnReason? reason}) => ReturnItem(
    description: description,
    descriptionSecondary: descriptionSecondary,
    quantity: quantity ?? this.quantity,
    unitSymbol: unitSymbol,
    reason: reason ?? this.reason,
    materialId: materialId,
  );

  Map<String, dynamic> toJson() => {
    'description': description,
    'descriptionSecondary': descriptionSecondary,
    'quantity': quantity,
    'unitSymbol': unitSymbol,
    'reason': reason.label,
    if (materialId != null) 'materialId': materialId,
  };

  factory ReturnItem.fromJson(Map<String, dynamic> json) => ReturnItem(
    description: json['description'] as String,
    descriptionSecondary: json['descriptionSecondary'] as String? ?? '',
    quantity: (json['quantity'] as num).toDouble(),
    unitSymbol: json['unitSymbol'] as String,
    reason: ReturnReason.fromLabel(json['reason'] as String? ?? 'Surplus'),
    materialId: json['materialId'] as String?,
  );
}

/// A material return raised by an engineer against a project (FR-083).
class MaterialReturn {
  const MaterialReturn({
    required this.id,
    required this.projectName,
    this.projectNameSecondary = '',
    required this.items,
    this.status = ReturnStatus.pending,
    required this.createdAt,
  });

  final String id;
  final String projectName;
  final String projectNameSecondary;
  final List<ReturnItem> items;
  final ReturnStatus status;
  final DateTime createdAt;

  int get itemCount => items.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectName': projectName,
    'projectNameSecondary': projectNameSecondary,
    'items': items.map((e) => e.toJson()).toList(),
    'status': status.label,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MaterialReturn.fromJson(Map<String, dynamic> json) => MaterialReturn(
    id: json['id'] as String,
    projectName: json['projectName'] as String,
    projectNameSecondary: json['projectNameSecondary'] as String? ?? '',
    items:
        (json['items'] as List<dynamic>?)
            ?.map((e) => ReturnItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    status: ReturnStatus.fromLabel(json['status'] as String? ?? 'Pending'),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  static String encodeList(List<MaterialReturn> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<MaterialReturn> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => MaterialReturn.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
