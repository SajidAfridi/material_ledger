enum CommercialSubjectType {
  material('material'),
  goodsReceipt('goods_receipt'),
  project('project');

  const CommercialSubjectType(this.databaseValue);

  final String databaseValue;

  static CommercialSubjectType fromDatabaseValue(String value) =>
      CommercialSubjectType.values.firstWhere(
        (type) => type.databaseValue == value,
        orElse: () => CommercialSubjectType.material,
      );
}

/// A commercially protected value stored separately from operational records.
class CommercialRecord {
  const CommercialRecord({
    required this.subjectType,
    required this.subjectId,
    this.unitCostAED,
    this.totalCostAED,
    this.currencyCode = 'AED',
    required this.updatedAt,
    this.updatedByAppUserId,
  });

  final CommercialSubjectType subjectType;
  final String subjectId;
  final double? unitCostAED;
  final double? totalCostAED;
  final String currencyCode;
  final DateTime updatedAt;
  final String? updatedByAppUserId;

  String get key => '${subjectType.databaseValue}:$subjectId';

  Map<String, dynamic> toDatabaseJson() => {
    'subject_type': subjectType.databaseValue,
    'subject_id': subjectId,
    'unit_cost_aed': unitCostAED,
    'total_cost_aed': totalCostAED,
    'currency_code': currencyCode,
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'updated_by_app_user_id': updatedByAppUserId,
  };

  Map<String, dynamic> toLocalJson() => {
    'subjectType': subjectType.databaseValue,
    'subjectId': subjectId,
    'unitCostAED': unitCostAED,
    'totalCostAED': totalCostAED,
    'currencyCode': currencyCode,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'updatedByAppUserId': updatedByAppUserId,
  };

  factory CommercialRecord.fromDatabaseJson(Map<String, dynamic> json) =>
      CommercialRecord(
        subjectType: CommercialSubjectType.fromDatabaseValue(
          json['subject_type'] as String? ?? '',
        ),
        subjectId: json['subject_id'] as String? ?? '',
        unitCostAED: (json['unit_cost_aed'] as num?)?.toDouble(),
        totalCostAED: (json['total_cost_aed'] as num?)?.toDouble(),
        currencyCode: json['currency_code'] as String? ?? 'AED',
        updatedAt:
            DateTime.tryParse(json['updated_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedByAppUserId: json['updated_by_app_user_id'] as String?,
      );

  factory CommercialRecord.fromLocalJson(Map<String, dynamic> json) =>
      CommercialRecord(
        subjectType: CommercialSubjectType.fromDatabaseValue(
          json['subjectType'] as String? ?? '',
        ),
        subjectId: json['subjectId'] as String? ?? '',
        unitCostAED: (json['unitCostAED'] as num?)?.toDouble(),
        totalCostAED: (json['totalCostAED'] as num?)?.toDouble(),
        currencyCode: json['currencyCode'] as String? ?? 'AED',
        updatedAt:
            DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedByAppUserId: json['updatedByAppUserId'] as String?,
      );
}
