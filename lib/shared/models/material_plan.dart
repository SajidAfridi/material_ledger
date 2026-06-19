import 'dart:convert';

/// Per-item arrangement status inside a Phase 1 material plan.
enum PlanItemStatus {
  pending('Pending', 'زیر التواء', 'معلق', 'लंबित'),
  arranged('Arranged', 'بندوبست شدہ', 'تم الترتيب', 'व्यवस्थित'),
  ticked('In stock', 'اسٹاک میں', 'متوفر', 'स्टॉक में'),
  lowStock('Low stock', 'کم اسٹاک', 'مخزون منخفض', 'कम स्टॉक'),
  rejected('Changes asked', 'تبدیلی درکار', 'مطلوب تغيير', 'बदलाव चाहिए');

  const PlanItemStatus(this.label, this.urdu, this.arabic, this.hindi);

  final String label;
  final String urdu;
  final String arabic;
  final String hindi;

  static PlanItemStatus fromLabel(String l) => PlanItemStatus.values.firstWhere(
    (s) => s.label == l,
    orElse: () => PlanItemStatus.pending,
  );
}

/// Lifecycle of the whole Phase 1 plan.
enum MaterialPlanStatus {
  draft('Draft', 'مسودہ', 'مسودة', 'ड्राफ्ट'),
  submitted('Submitted', 'جمع شدہ', 'تم الإرسال', 'सबमिट किया'),
  procurementReview('In review', 'زیرِ جائزہ', 'قيد المراجعة', 'समीक्षा में'),
  pendingEngineerApproval(
    'Ready for approval',
    'منظوری کے لیے تیار',
    'جاهز للموافقة',
    'अनुमोदन हेतु तैयार',
  ),
  approved('Approved', 'منظور شدہ', 'تمت الموافقة', 'अनुमोदित'),
  rejected(
    'Changes requested',
    'تبدیلیاں طلب',
    'طُلبت تغييرات',
    'बदलाव अनुरोधित',
  );

  const MaterialPlanStatus(this.label, this.urdu, this.arabic, this.hindi);

  final String label;
  final String urdu;
  final String arabic;
  final String hindi;

  static MaterialPlanStatus fromLabel(String l) => MaterialPlanStatus.values
      .firstWhere((s) => s.label == l, orElse: () => MaterialPlanStatus.draft);
}

/// A single line in a Phase 1 plan. Carries the full SRS item spec
/// (FR-018) including the RAL colour required for grilles/dampers (FR-054).
class PlanItem {
  const PlanItem({
    required this.id,
    required this.description,
    this.descriptionSecondary = '',
    this.brand = '',
    this.countryOfOrigin = '',
    this.size = '',
    required this.quantity,
    required this.unitSymbol,
    this.ralColour = '',
    this.isCustom = false,
    this.status = PlanItemStatus.pending,
    this.note = '',
  });

  final String id;
  final String description;
  final String descriptionSecondary;
  final String brand;
  final String countryOfOrigin;
  final String size;
  final double quantity;
  final String unitSymbol;
  final String ralColour;
  final bool isCustom;
  final PlanItemStatus status;
  final String note;

  PlanItem copyWith({
    String? description,
    double? quantity,
    PlanItemStatus? status,
    String? note,
    String? ralColour,
    String? brand,
    String? countryOfOrigin,
    String? size,
  }) => PlanItem(
    id: id,
    description: description ?? this.description,
    descriptionSecondary: descriptionSecondary,
    brand: brand ?? this.brand,
    countryOfOrigin: countryOfOrigin ?? this.countryOfOrigin,
    size: size ?? this.size,
    quantity: quantity ?? this.quantity,
    unitSymbol: unitSymbol,
    ralColour: ralColour ?? this.ralColour,
    isCustom: isCustom,
    status: status ?? this.status,
    note: note ?? this.note,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'descriptionSecondary': descriptionSecondary,
    'brand': brand,
    'countryOfOrigin': countryOfOrigin,
    'size': size,
    'quantity': quantity,
    'unitSymbol': unitSymbol,
    'ralColour': ralColour,
    'isCustom': isCustom,
    'status': status.label,
    'note': note,
  };

  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem(
    id: json['id'] as String,
    description: json['description'] as String,
    descriptionSecondary: json['descriptionSecondary'] as String? ?? '',
    brand: json['brand'] as String? ?? '',
    countryOfOrigin: json['countryOfOrigin'] as String? ?? '',
    size: json['size'] as String? ?? '',
    quantity: (json['quantity'] as num).toDouble(),
    unitSymbol: json['unitSymbol'] as String,
    ralColour: json['ralColour'] as String? ?? '',
    isCustom: json['isCustom'] as bool? ?? false,
    status: PlanItemStatus.fromLabel(json['status'] as String? ?? 'Pending'),
    note: json['note'] as String? ?? '',
  );
}

/// A comment in the engineer ⇄ procurement thread on a plan (FR-024).
class PlanComment {
  const PlanComment({
    required this.authorName,
    required this.authorRole,
    required this.text,
    required this.timestamp,
  });

  final String authorName;
  final String authorRole;
  final String text;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'authorName': authorName,
    'authorRole': authorRole,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
  };

  factory PlanComment.fromJson(Map<String, dynamic> json) => PlanComment(
    authorName: json['authorName'] as String,
    authorRole: json['authorRole'] as String,
    text: json['text'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

/// A Phase 1 material plan for a project (one per project).
class MaterialPlan {
  const MaterialPlan({
    required this.id,
    required this.projectId,
    this.items = const [],
    this.baselineItems = const [],
    this.status = MaterialPlanStatus.draft,
    this.comments = const [],
    this.version = 1,
    this.submittedAt,
    this.approvedAt,
  });

  final String id;
  final String projectId;
  final List<PlanItem> items;

  /// Snapshot of the items as procurement last arranged them. Used to diff
  /// engineer edits made after arrangement (FR-030/031). Empty until arranged.
  final List<PlanItem> baselineItems;

  final MaterialPlanStatus status;
  final List<PlanComment> comments;
  final int version;
  final DateTime? submittedAt;
  final DateTime? approvedAt;

  int get itemCount => items.length;

  /// True when every item is arranged or confirmed in stock (FR-026).
  bool get allArranged =>
      items.isNotEmpty &&
      items.every(
        (i) =>
            i.status == PlanItemStatus.arranged ||
            i.status == PlanItemStatus.ticked,
      );

  bool get isReadyForApproval =>
      status == MaterialPlanStatus.pendingEngineerApproval;

  MaterialPlan copyWith({
    List<PlanItem>? items,
    List<PlanItem>? baselineItems,
    MaterialPlanStatus? status,
    List<PlanComment>? comments,
    int? version,
    DateTime? submittedAt,
    DateTime? approvedAt,
  }) => MaterialPlan(
    id: id,
    projectId: projectId,
    items: items ?? this.items,
    baselineItems: baselineItems ?? this.baselineItems,
    status: status ?? this.status,
    comments: comments ?? this.comments,
    version: version ?? this.version,
    submittedAt: submittedAt ?? this.submittedAt,
    approvedAt: approvedAt ?? this.approvedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'items': items.map((e) => e.toJson()).toList(),
    'baselineItems': baselineItems.map((e) => e.toJson()).toList(),
    'status': status.label,
    'comments': comments.map((e) => e.toJson()).toList(),
    'version': version,
    'submittedAt': submittedAt?.toIso8601String(),
    'approvedAt': approvedAt?.toIso8601String(),
  };

  factory MaterialPlan.fromJson(Map<String, dynamic> json) => MaterialPlan(
    id: json['id'] as String,
    projectId: json['projectId'] as String,
    items:
        (json['items'] as List<dynamic>?)
            ?.map((e) => PlanItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    baselineItems:
        (json['baselineItems'] as List<dynamic>?)
            ?.map((e) => PlanItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    status: MaterialPlanStatus.fromLabel(json['status'] as String? ?? 'Draft'),
    comments:
        (json['comments'] as List<dynamic>?)
            ?.map((e) => PlanComment.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    version: json['version'] as int? ?? 1,
    submittedAt: json['submittedAt'] == null
        ? null
        : DateTime.parse(json['submittedAt'] as String),
    approvedAt: json['approvedAt'] == null
        ? null
        : DateTime.parse(json['approvedAt'] as String),
  );

  static String encodeList(List<MaterialPlan> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<MaterialPlan> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => MaterialPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
