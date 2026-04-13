import 'dart:convert';

/// An admin-created project that engineers can select when creating requests.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.nameSecondary,
    this.siteLocation,
  });

  final String id;
  final String name;
  final String nameSecondary;
  final String? siteLocation;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nameSecondary': nameSecondary,
    'siteLocation': siteLocation,
  };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'] as String,
    name: json['name'] as String,
    nameSecondary: json['nameSecondary'] as String? ?? '',
    siteLocation: json['siteLocation'] as String?,
  );

  static String encodeList(List<Project> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<Project> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// An item within a material requisition request.
/// Represents a specific material + requested quantity.
class RequestLineItem {
  const RequestLineItem({
    required this.materialId,
    required this.materialName,
    required this.materialNameSecondary,
    required this.quantity,
    required this.unitSymbol,
  });

  final String materialId;
  final String materialName;
  final String materialNameSecondary;
  final double quantity;
  final String unitSymbol;

  RequestLineItem copyWith({double? quantity}) => RequestLineItem(
    materialId: materialId,
    materialName: materialName,
    materialNameSecondary: materialNameSecondary,
    quantity: quantity ?? this.quantity,
    unitSymbol: unitSymbol,
  );

  Map<String, dynamic> toJson() => {
    'materialId': materialId,
    'materialName': materialName,
    'materialNameSecondary': materialNameSecondary,
    'quantity': quantity,
    'unitSymbol': unitSymbol,
  };

  factory RequestLineItem.fromJson(Map<String, dynamic> json) =>
      RequestLineItem(
        materialId: json['materialId'] as String,
        materialName: json['materialName'] as String,
        materialNameSecondary: json['materialNameSecondary'] as String? ?? '',
        quantity: (json['quantity'] as num).toDouble(),
        unitSymbol: json['unitSymbol'] as String,
      );
}
