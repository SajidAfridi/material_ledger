import 'dart:convert';

import 'material_line_draft.dart';

enum PlanProposedSource {
  notReviewed('Not reviewed'),
  warehouse('Warehouse'),
  externalSupplier('External supplier'),
  mixed('Mixed');

  const PlanProposedSource(this.label);
  final String label;

  static PlanProposedSource fromJson(Object? value) =>
      PlanProposedSource.values.firstWhere(
        (source) => source.name == value || source.label == value,
        orElse: () => PlanProposedSource.notReviewed,
      );
}

/// Per-item arrangement status inside a Phase 1 material plan.
///
/// Retained for legacy snapshots. New Phase 1 review uses
/// [PlanItem.proposedSource]; availability remains advisory.
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
  procurementReview(
    'Under Procurement Review',
    'پروکیورمنٹ جائزہ جاری',
    'قيد مراجعة المشتريات',
    'खरीद समीक्षा में',
  ),
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
  ),
  superseded('Superseded', 'منسوخ شدہ ورژن', 'تم استبداله', 'अधिलिखित');

  const MaterialPlanStatus(this.label, this.urdu, this.arabic, this.hindi);

  final String label;
  final String urdu;
  final String arabic;
  final String hindi;

  static MaterialPlanStatus fromLabel(String l) {
    if (l == 'In review') return MaterialPlanStatus.procurementReview;
    return MaterialPlanStatus.values.firstWhere(
      (s) => s.label == l || s.name == l,
      orElse: () => MaterialPlanStatus.draft,
    );
  }
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
    // ─── Equipment-schedule / BOQ columns ───────────────────────────
    this.tagNo = '',
    this.mounting = '',
    this.airFlowLS,
    this.submittalRef = '',
    this.materialId,
    this.categoryId,
    this.buildingId = 'project-wide',
    this.modelSerial = '',
    this.makeOrigin = '',
    this.proposedSource = PlanProposedSource.notReviewed,
    this.onHandQtySnapshot,
    this.availableQtySnapshot,
    this.procurementNote = '',
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

  // ─── Equipment-schedule / BOQ columns (from the client's schedule) ──
  /// Equipment tag number, e.g. "MSD-01A", "SAR-01-04".
  final String tagNo;

  /// Mounting — "Slab" / "Wall".
  final String mounting;

  /// Design air flow in litres/second (grilles, registers, diffusers).
  final double? airFlowLS;

  /// Material-submittal reference (the schedule's "MASS" / MTS code).
  final String submittalRef;
  final String? materialId;
  final String? categoryId;
  final String buildingId;
  final String modelSerial;
  final String makeOrigin;
  final PlanProposedSource proposedSource;
  final double? onHandQtySnapshot;
  final double? availableQtySnapshot;
  final String procurementNote;

  /// Compact BOQ line for display: "Tag · Size · AirFlow · Submittal" (blanks
  /// omitted). Complements the existing brand/RAL/country spec.
  String get boqSummary => [
    if (tagNo.isNotEmpty) tagNo,
    if (mounting.isNotEmpty) mounting,
    if (airFlowLS != null) '${airFlowLS!.toStringAsFixed(0)} L/s',
    if (submittalRef.isNotEmpty) submittalRef,
  ].join(' · ');

  PlanItem copyWith({
    String? description,
    double? quantity,
    PlanItemStatus? status,
    String? note,
    String? ralColour,
    String? brand,
    String? countryOfOrigin,
    String? size,
    String? tagNo,
    String? mounting,
    double? airFlowLS,
    String? submittalRef,
    String? materialId,
    String? categoryId,
    String? buildingId,
    String? modelSerial,
    String? makeOrigin,
    PlanProposedSource? proposedSource,
    Object? onHandQtySnapshot = _unchanged,
    Object? availableQtySnapshot = _unchanged,
    String? procurementNote,
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
    tagNo: tagNo ?? this.tagNo,
    mounting: mounting ?? this.mounting,
    airFlowLS: airFlowLS ?? this.airFlowLS,
    submittalRef: submittalRef ?? this.submittalRef,
    materialId: materialId ?? this.materialId,
    categoryId: categoryId ?? this.categoryId,
    buildingId: buildingId ?? this.buildingId,
    modelSerial: modelSerial ?? this.modelSerial,
    makeOrigin: makeOrigin ?? this.makeOrigin,
    proposedSource: proposedSource ?? this.proposedSource,
    onHandQtySnapshot: identical(onHandQtySnapshot, _unchanged)
        ? this.onHandQtySnapshot
        : (onHandQtySnapshot as num?)?.toDouble(),
    availableQtySnapshot: identical(availableQtySnapshot, _unchanged)
        ? this.availableQtySnapshot
        : (availableQtySnapshot as num?)?.toDouble(),
    procurementNote: procurementNote ?? this.procurementNote,
  );

  MaterialLineDraft toMaterialLineDraft() => MaterialLineDraft(
    id: id,
    description: description,
    size: size,
    modelSerial: modelSerial.isNotEmpty ? modelSerial : tagNo,
    makeOrigin: makeOrigin.isNotEmpty
        ? makeOrigin
        : [
            brand,
            countryOfOrigin,
          ].where((value) => value.isNotEmpty).join(' / '),
    quantity: quantity,
    unitSymbol: unitSymbol,
    remarks: note,
  );

  factory PlanItem.fromMaterialLineDraft(
    MaterialLineDraft line, {
    PlanItem? previous,
  }) => PlanItem(
    id: line.id,
    description: line.description.trim(),
    descriptionSecondary: previous?.descriptionSecondary ?? '',
    brand: previous?.brand ?? '',
    countryOfOrigin: previous?.countryOfOrigin ?? '',
    size: line.size.trim(),
    quantity: line.quantity ?? 0,
    unitSymbol: line.unitSymbol.trim(),
    ralColour: previous?.ralColour ?? '',
    isCustom: previous?.isCustom ?? true,
    status: previous?.status ?? PlanItemStatus.pending,
    note: line.remarks.trim(),
    tagNo: previous?.tagNo ?? '',
    mounting: previous?.mounting ?? '',
    airFlowLS: previous?.airFlowLS,
    submittalRef: previous?.submittalRef ?? '',
    materialId: previous?.materialId,
    categoryId: previous?.categoryId,
    buildingId: previous?.buildingId ?? 'project-wide',
    modelSerial: line.modelSerial.trim(),
    makeOrigin: line.makeOrigin.trim(),
    proposedSource: previous?.proposedSource ?? PlanProposedSource.notReviewed,
    onHandQtySnapshot: previous?.onHandQtySnapshot,
    availableQtySnapshot: previous?.availableQtySnapshot,
    procurementNote: previous?.procurementNote ?? '',
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
    'tagNo': tagNo,
    'mounting': mounting,
    'airFlowLS': airFlowLS,
    'submittalRef': submittalRef,
    'materialId': materialId,
    'categoryId': categoryId,
    'buildingId': buildingId,
    'modelSerial': modelSerial,
    'makeOrigin': makeOrigin,
    'proposedSource': proposedSource.name,
    'onHandQtySnapshot': onHandQtySnapshot,
    'availableQtySnapshot': availableQtySnapshot,
    'procurementNote': procurementNote,
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
    tagNo: json['tagNo'] as String? ?? '',
    mounting: json['mounting'] as String? ?? '',
    airFlowLS: (json['airFlowLS'] as num?)?.toDouble(),
    submittalRef: json['submittalRef'] as String? ?? '',
    materialId: json['materialId'] as String?,
    categoryId: json['categoryId'] as String?,
    buildingId: json['buildingId'] as String? ?? 'project-wide',
    modelSerial: json['modelSerial'] as String? ?? '',
    makeOrigin: json['makeOrigin'] as String? ?? '',
    proposedSource: PlanProposedSource.fromJson(json['proposedSource']),
    onHandQtySnapshot: (json['onHandQtySnapshot'] as num?)?.toDouble(),
    availableQtySnapshot: (json['availableQtySnapshot'] as num?)?.toDouble(),
    procurementNote: json['procurementNote'] as String? ?? '',
  );
}

/// A comment in the engineer ⇄ procurement thread on a plan (FR-024).
class PlanComment {
  const PlanComment({
    this.id = '',
    this.authorUserId,
    required this.authorName,
    required this.authorRole,
    required this.text,
    required this.timestamp,
    this.lineItemId,
  });

  final String id;
  final String? authorUserId;
  final String authorName;
  final String authorRole;
  final String text;
  final DateTime timestamp;
  final String? lineItemId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorUserId': authorUserId,
    'authorName': authorName,
    'authorRole': authorRole,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'lineItemId': lineItemId,
  };

  factory PlanComment.fromJson(Map<String, dynamic> json) => PlanComment(
    id: json['id'] as String? ?? '',
    authorUserId: json['authorUserId'] as String?,
    authorName: json['authorName'] as String,
    authorRole: json['authorRole'] as String,
    text: json['text'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    lineItemId: json['lineItemId'] as String?,
  );
}

class MaterialPlanVersion {
  const MaterialPlanVersion({
    required this.version,
    required this.items,
    required this.createdAt,
    required this.createdByUserId,
    required this.createdByName,
    required this.createdByRole,
  });

  final int version;
  final List<PlanItem> items;
  final DateTime createdAt;
  final String? createdByUserId;
  final String createdByName;
  final String createdByRole;

  Map<String, dynamic> toJson() => {
    'version': version,
    'items': items.map((item) => item.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'createdByUserId': createdByUserId,
    'createdByName': createdByName,
    'createdByRole': createdByRole,
  };

  factory MaterialPlanVersion.fromJson(Map<String, dynamic> json) =>
      MaterialPlanVersion(
        version: (json['version'] as num?)?.toInt() ?? 1,
        items:
            (json['items'] as List<dynamic>?)
                ?.whereType<Map>()
                .map(
                  (item) => PlanItem.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false) ??
            const [],
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        createdByUserId: json['createdByUserId'] as String?,
        createdByName: json['createdByName'] as String? ?? 'Unknown',
        createdByRole: json['createdByRole'] as String? ?? 'Unknown',
      );
}

class MaterialPlanActivity {
  const MaterialPlanActivity({
    required this.action,
    required this.actorName,
    required this.actorRole,
    required this.timestamp,
    this.actorUserId,
    this.detail = '',
  });

  final String action;
  final String actorName;
  final String actorRole;
  final DateTime timestamp;
  final String? actorUserId;
  final String detail;

  Map<String, dynamic> toJson() => {
    'action': action,
    'actorName': actorName,
    'actorRole': actorRole,
    'timestamp': timestamp.toIso8601String(),
    'actorUserId': actorUserId,
    'detail': detail,
  };

  factory MaterialPlanActivity.fromJson(Map<String, dynamic> json) =>
      MaterialPlanActivity(
        action: json['action'] as String? ?? '',
        actorName: json['actorName'] as String? ?? 'Unknown',
        actorRole: json['actorRole'] as String? ?? 'Unknown',
        timestamp:
            DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        actorUserId: json['actorUserId'] as String?,
        detail: json['detail'] as String? ?? '',
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
    this.versions = const [],
    this.activity = const [],
    this.version = 1,
    this.submittedAt,
    this.reviewedAt,
    this.approvedAt,
    this.currentOwnerRole,
    this.currentOwnerUserId,
    this.updatedAt,
    this.updatedByUserId,
    // Soft-delete: the sync outbox only ever upserts, never issues a real SQL
    // DELETE — a physical local removal would resurrect on the next cloud
    // hydration. Deleting flips this instead (mirrors Project.deleted).
    this.deleted = false,
  });

  final String id;
  final String projectId;
  final List<PlanItem> items;

  /// Snapshot of the items as procurement last arranged them. Used to diff
  /// engineer edits made after arrangement (FR-030/031). Empty until arranged.
  final List<PlanItem> baselineItems;

  final MaterialPlanStatus status;
  final List<PlanComment> comments;
  final List<MaterialPlanVersion> versions;
  final List<MaterialPlanActivity> activity;
  final int version;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final DateTime? approvedAt;
  final String? currentOwnerRole;
  final String? currentOwnerUserId;
  final DateTime? updatedAt;
  final String? updatedByUserId;

  /// Soft-delete flag — see the constructor param doc.
  final bool deleted;
  static const Object _keep = Object();

  int get itemCount => items.length;

  /// True when every item is arranged or confirmed in stock (FR-026).
  bool get allArranged =>
      items.isNotEmpty &&
      items.every(
        (i) =>
            i.status == PlanItemStatus.arranged ||
            i.status == PlanItemStatus.ticked,
      );

  bool get allSourcesReviewed =>
      items.isNotEmpty &&
      items.every(
        (item) => item.proposedSource != PlanProposedSource.notReviewed,
      );

  bool get isReadyForApproval =>
      status == MaterialPlanStatus.pendingEngineerApproval;

  MaterialPlan copyWith({
    List<PlanItem>? items,
    List<PlanItem>? baselineItems,
    MaterialPlanStatus? status,
    List<PlanComment>? comments,
    List<MaterialPlanVersion>? versions,
    List<MaterialPlanActivity>? activity,
    int? version,
    Object? submittedAt = _keep,
    Object? reviewedAt = _keep,
    Object? approvedAt = _keep,
    Object? currentOwnerRole = _keep,
    Object? currentOwnerUserId = _keep,
    Object? updatedAt = _keep,
    Object? updatedByUserId = _keep,
    bool? deleted,
  }) => MaterialPlan(
    id: id,
    projectId: projectId,
    items: items ?? this.items,
    baselineItems: baselineItems ?? this.baselineItems,
    status: status ?? this.status,
    comments: comments ?? this.comments,
    versions: versions ?? this.versions,
    activity: activity ?? this.activity,
    version: version ?? this.version,
    submittedAt: identical(submittedAt, _keep)
        ? this.submittedAt
        : submittedAt as DateTime?,
    reviewedAt: identical(reviewedAt, _keep)
        ? this.reviewedAt
        : reviewedAt as DateTime?,
    approvedAt: identical(approvedAt, _keep)
        ? this.approvedAt
        : approvedAt as DateTime?,
    currentOwnerRole: identical(currentOwnerRole, _keep)
        ? this.currentOwnerRole
        : currentOwnerRole as String?,
    currentOwnerUserId: identical(currentOwnerUserId, _keep)
        ? this.currentOwnerUserId
        : currentOwnerUserId as String?,
    updatedAt: identical(updatedAt, _keep)
        ? this.updatedAt
        : updatedAt as DateTime?,
    updatedByUserId: identical(updatedByUserId, _keep)
        ? this.updatedByUserId
        : updatedByUserId as String?,
    deleted: deleted ?? this.deleted,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'items': items.map((e) => e.toJson()).toList(),
    'baselineItems': baselineItems.map((e) => e.toJson()).toList(),
    'status': status.label,
    'comments': comments.map((e) => e.toJson()).toList(),
    'versions': versions.map((e) => e.toJson()).toList(),
    'activity': activity.map((e) => e.toJson()).toList(),
    'version': version,
    'submittedAt': submittedAt?.toIso8601String(),
    'reviewedAt': reviewedAt?.toIso8601String(),
    'approvedAt': approvedAt?.toIso8601String(),
    'currentOwnerRole': currentOwnerRole,
    'currentOwnerUserId': currentOwnerUserId,
    'updatedAt': updatedAt?.toIso8601String(),
    'updatedByUserId': updatedByUserId,
    'deleted': deleted,
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
    versions:
        (json['versions'] as List<dynamic>?)
            ?.whereType<Map>()
            .map(
              (version) => MaterialPlanVersion.fromJson(
                Map<String, dynamic>.from(version),
              ),
            )
            .toList(growable: false) ??
        const [],
    activity:
        (json['activity'] as List<dynamic>?)
            ?.whereType<Map>()
            .map(
              (activity) => MaterialPlanActivity.fromJson(
                Map<String, dynamic>.from(activity),
              ),
            )
            .toList(growable: false) ??
        const [],
    version: json['version'] as int? ?? 1,
    submittedAt: json['submittedAt'] == null
        ? null
        : DateTime.parse(json['submittedAt'] as String),
    reviewedAt: json['reviewedAt'] == null
        ? null
        : DateTime.parse(json['reviewedAt'] as String),
    approvedAt: json['approvedAt'] == null
        ? null
        : DateTime.parse(json['approvedAt'] as String),
    currentOwnerRole: json['currentOwnerRole'] as String?,
    currentOwnerUserId: json['currentOwnerUserId'] as String?,
    updatedAt: json['updatedAt'] == null
        ? null
        : DateTime.parse(json['updatedAt'] as String),
    updatedByUserId: json['updatedByUserId'] as String?,
    deleted: json['deleted'] as bool? ?? false,
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

const Object _unchanged = Object();
